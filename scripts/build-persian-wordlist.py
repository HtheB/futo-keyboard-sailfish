#!/usr/bin/env python3
"""Build the deterministic Persian AOSP-format prediction word list.

The ranked source is the pinned Persian OpenSubtitles frequency list from
hermitdave/FrequencyWords.  The pinned Apache-2.0 Lilak Hunspell dictionary
supplies lower-frequency vocabulary that is missing from conversational
subtitles.  Persian/Arabic compatibility code points are normalised to the
letters printed on the keyboard before duplicate forms are combined.
"""

import argparse
import collections
import gzip
import os
import unicodedata


PERSIAN_REPLACEMENTS = str.maketrans({
    "ي": "ی",
    "ى": "ی",
    "ك": "ک",
    "ۀ": "هٔ",
})


def arguments():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--frequency", required=True)
    parser.add_argument("--hunspell", required=True)
    parser.add_argument("--reference", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--max-entries", type=int, default=210000)
    return parser.parse_args()


def normalise_word(value):
    value = unicodedata.normalize("NFC", value).translate(PERSIAN_REPLACEMENTS)
    value = value.strip("\u200c")
    if not value or len(value) > 32:
        return ""
    for character in value:
        if character == "\u200c":
            continue
        category = unicodedata.category(character)
        codepoint = ord(character)
        if category not in ("Lo", "Mn") or not (0x0600 <= codepoint <= 0x06FF):
            return ""
    return value


def load_frequency(path):
    counts = collections.Counter()
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            try:
                raw, count = line.rsplit(" ", 1)
                count = int(count)
            except ValueError:
                continue
            word = normalise_word(raw)
            if word:
                counts[word] += count
    return counts


def load_hunspell(path):
    words = set()
    with open(path, encoding="utf-8-sig") as handle:
        first = True
        for line in handle:
            value = line.strip()
            if first:
                first = False
                if value.isdigit():
                    continue
            # Lilak uses long alphabetic flags after a slash.  A literal slash
            # is not part of Persian orthography, so the first slash is safe.
            word = normalise_word(value.split("/", 1)[0])
            if word:
                words.add(word)
    return words


def reference_frequencies(path):
    opener = gzip.open if path.endswith(".gz") else open
    result = []
    with opener(path, "rt", encoding="utf-8") as handle:
        for line in handle:
            if not line.startswith(" word=") or ",f=" not in line:
                continue
            try:
                result.append(int(line.split(",f=", 1)[1].split(",", 1)[0]))
            except ValueError:
                pass
    return sorted(result, reverse=True)


def main():
    args = arguments()
    counts = load_frequency(args.frequency)
    hunspell = load_hunspell(args.hunspell)

    # Frequency words come first.  Dictionary-only words sort deterministically
    # below them, retaining useful spelling coverage without distorting common
    # conversational predictions.
    ranked = sorted(counts, key=lambda word: (-counts[word], word))
    ranked.extend(sorted(hunspell.difference(counts)))
    ranked = ranked[:args.max_entries]

    reference = reference_frequencies(args.reference)
    if not ranked or not reference:
        raise SystemExit("empty Persian input or reference frequency list")

    generated = int(os.environ.get("SOURCE_DATE_EPOCH", "0"))
    with open(args.output, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("dictionary=main:fa,locale=fa_IR,description=فارسی,"
                     f"date={generated},version=1\n")
        for index, word in enumerate(ranked):
            reference_index = min(len(reference) - 1,
                                  int(index * len(reference) / len(ranked)))
            handle.write(f" word={word},f={max(1, reference[reference_index])}\n")

    print(f"wrote {len(ranked)} Persian entries ({len(counts)} ranked, "
          f"{len(hunspell)} Hunspell forms)")


if __name__ == "__main__":
    main()
