#!/usr/bin/env python3
"""Build an AOSP-format word list for the FUTO Keyboard Sailfish port.

Sources
  1. OpenSubtitles word counts (hermitdave/FrequencyWords, CC-BY-SA 4.0)
  2. wordfreq frequencies (Wikipedia, OpenSubtitles, web, news, ...; CC-BY-SA 4.0)
  3. an existing AOSP-format list (openboard/AOSP) used only for casing and as
     a "trusted" list in the English-loan filter
Validation: hunspell (one or more dictionaries; a word passes if any accepts
it), first lowercase, then capitalised for proper nouns / German nouns.
Frequencies: log-mean of the relative frequencies from sources 1 and 2, ranked
and quantile-mapped onto the f distribution of a reference AOSP list so the
engine's ranking weights stay comparable across languages.

Example (Hungarian):
  curl -LO https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/hu/hu_full.txt
  curl -L https://raw.githubusercontent.com/openboard-team/openboard/v1.4.5/dictionaries/hu_wordlist.combined.gz | gzip -dc > hu.combined
  gzip -dc upstream/dictionaries/de_wordlist.combined.gz > de.combined
  scripts/build-frequency-wordlist.py --language hu --letters 'a-záéíóöőúüű' \
      --subtitles hu_full.txt --wordfreq hu --hunspell hu_HU --casing hu.combined \
      --reference de.combined --description Magyar --output hu_wordlist.combined

Example (German, Austrian and German spelling both accepted):
  scripts/build-frequency-wordlist.py --language de --letters 'a-zäöüß' \
      --subtitles de_full.txt --wordfreq de --hunspell de_AT --hunspell de_DE \
      --casing de.combined --reference de.combined --description Deutsch \
      --max-entries 230000 --wordfreq-fallback-zipf 4.0 --output de_wordlist.combined
"""
import argparse
import collections
import math
import re
import subprocess
import sys
import time

from wordfreq import top_n_list, word_frequency, zipf_frequency


def parse_arguments():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--language", required=True, help="locale code, e.g. hu or de")
    parser.add_argument("--letters", required=True,
                        help="regex character class of lowercase letters, e.g. a-záéíóöőúüű")
    parser.add_argument("--subtitles", required=True, help="hermitdave <lang>_full.txt")
    parser.add_argument("--wordfreq", required=True, help="wordfreq language code")
    parser.add_argument("--hunspell", action="append", required=True,
                        help="hunspell dictionary name (repeatable), e.g. hu_HU")
    parser.add_argument("--casing", required=True, help="AOSP-format list used for casing")
    parser.add_argument("--reference", required=True,
                        help="AOSP-format list whose f distribution is copied")
    parser.add_argument("--description", required=True, help="dictionary description")
    parser.add_argument("--output", required=True)
    parser.add_argument("--max-entries", type=int, default=210000)
    parser.add_argument("--min-subtitle-count", type=int, default=2)
    parser.add_argument("--max-length", type=int, default=24)
    parser.add_argument("--wordfreq-limit", type=int, default=600000)
    parser.add_argument("--wordfreq-fallback-zipf", type=float, default=3.0,
                        help="minimum Zipf frequency for words that only wordfreq vouches "
                             "for (hunspell rejects them, the casing list lacks them); "
                             "use 4.0 or more for languages with case-insensitive noise")
    return parser.parse_args()


def hunspell_rejected(words, dictionaries):
    """Words rejected by every given hunspell dictionary."""
    rejected = None
    for dictionary in dictionaries:
        current = set()
        chunk = 100000
        for start in range(0, len(words), chunk):
            batch = words[start:start + chunk]
            result = subprocess.run(
                ["hunspell", "-d", dictionary, "-i", "utf-8", "-l"],
                input="\n".join(batch) + "\n", capture_output=True, text=True, check=True)
            current.update(line.strip() for line in result.stdout.splitlines() if line.strip())
        rejected = current if rejected is None else rejected & current
    return rejected or set()


def load_subtitles(path, pattern, max_length):
    counts = collections.Counter()
    total = 0
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            word, count = line.rsplit(" ", 1)
            count = int(count)
            total += count
            lowered = word.lower()
            if pattern.match(lowered) and len(lowered) <= max_length:
                counts[lowered] += count
    return counts, total


def load_aosp_list(path, pattern, max_length):
    """lowercase word -> {display form: f}"""
    entries = collections.defaultdict(dict)
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            if not line.startswith(" word=") or "not_a_word=true" in line \
                    or "flags=abbreviation" in line:
                continue
            body = line[6:].rstrip("\n")
            word, rest = body.split(",f=", 1)
            frequency = int(rest.split(",")[0])
            lowered = word.lower()
            if pattern.match(lowered) and len(lowered) <= max_length:
                entries[lowered][word] = frequency
    return entries


def load_reference_frequencies(path):
    values = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            if line.startswith(" word="):
                marker = line.find(",f=")
                try:
                    values.append(int(line[marker + 3:].split(",")[0]))
                except ValueError:
                    pass
    values.sort(reverse=True)
    return values


def main():
    args = parse_arguments()
    started = time.time()
    pattern = re.compile("^[" + args.letters + "]+$")

    subs, subs_total = load_subtitles(args.subtitles, pattern, args.max_length)
    print(f"subtitles: {len(subs)} clean forms, {subs_total} tokens", file=sys.stderr)

    frequencies = {}
    for word in top_n_list(args.wordfreq, args.wordfreq_limit):
        if pattern.match(word) and len(word) <= args.max_length:
            frequencies[word] = word_frequency(word, args.wordfreq)
    print(f"wordfreq {args.wordfreq}: {len(frequencies)} forms", file=sys.stderr)

    casing = load_aosp_list(args.casing, pattern, args.max_length)
    print(f"casing list: {len(casing)} forms", file=sys.stderr)

    candidates = set(word for word, count in subs.items() if count >= args.min_subtitle_count)
    candidates |= set(frequencies)
    candidates |= set(casing)
    ordered = sorted(candidates)
    print(f"candidates: {len(ordered)}", file=sys.stderr)

    rejected_lower = hunspell_rejected(ordered, args.hunspell)
    needs_capital = [word for word in ordered if word in rejected_lower]
    rejected_capital = hunspell_rejected([word.capitalize() for word in needs_capital],
                                         args.hunspell)
    accepted_capital = set(word for word in needs_capital
                           if word.capitalize() not in rejected_capital)
    print(f"hunspell: {len(ordered) - len(rejected_lower)} lowercase ok, "
          f"{len(accepted_capital)} accepted capitalised", file=sys.stderr)

    def english_loan(word, trusted):
        # hunspell accepts real homographs and loanwords but rejects plain
        # English; lists such as openboard's contain English junk, so words
        # that only they or wordfreq vouch for get a stricter frequency test.
        if not word.isascii():
            return False
        english = zipf_frequency(word, "en")
        if english < 4.5:
            return False
        return english >= zipf_frequency(word, args.wordfreq) + (1.5 if trusted else 0.5)

    kept = []
    origin = collections.Counter()
    for word in ordered:
        displays = []
        if word not in rejected_lower:
            displays.append(word)
            source = "hunspell"
            # A capitalised form that the casing list also knows (German nouns
            # such as Essen next to essen) is kept as a second entry.
            capitalised = word.capitalize()
            if capitalised != word and capitalised in casing.get(word, {}):
                displays.append(capitalised)
        elif word in accepted_capital:
            displays.append(word.capitalize())
            source = "hunspell-capitalised"
        elif word in casing:
            displays.append(max(casing[word], key=casing[word].get))
            source = "casing-list"
        elif word in frequencies and zipf_frequency(word, args.wordfreq) >= args.wordfreq_fallback_zipf:
            displays.append(word)
            source = "wordfreq"
        else:
            origin["dropped"] += 1
            continue
        if english_loan(word, source.startswith("hunspell")):
            origin["dropped-english"] += 1
            continue

        logs = []
        if word in subs and subs[word] >= args.min_subtitle_count:
            logs.append(math.log10(subs[word] / subs_total))
        if word in frequencies and frequencies[word] > 0:
            logs.append(math.log10(frequencies[word]))
        if logs:
            score = sum(logs) / len(logs)
        else:
            # casing-list-only entries rank below every counted word
            score = -12.0 + max(casing[word].values()) / 255.0
        origin[source] += 1
        for index, display in enumerate(displays):
            # A capitalised twin ranks one step below the lowercase form so
            # that exact matches prefer the lowercase spelling.
            kept.append((score, display, index > 0))

    kept.sort(key=lambda item: (-item[0], item[1]))
    kept = kept[:args.max_entries]
    print(f"kept: {len(kept)} entries; origins: {dict(origin)}", file=sys.stderr)

    reference = load_reference_frequencies(args.reference)
    count = len(kept)
    with open(args.output, "w", encoding="utf-8") as handle:
        handle.write(f"dictionary=main:{args.language},locale={args.language},"
                     f"description={args.description},date={int(time.time())},version=1\n")
        for index, (score, display, twin) in enumerate(kept):
            reference_index = min(len(reference) - 1, int(index * len(reference) / count))
            frequency = max(1, reference[reference_index] - (1 if twin else 0))
            handle.write(f" word={display},f={frequency}\n")
    print(f"wrote {args.output} in {time.time() - started:.1f}s", file=sys.stderr)


if __name__ == "__main__":
    main()
