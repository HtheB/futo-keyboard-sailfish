#!/usr/bin/env python3
"""Build the deterministic Arabic AOSP-format prediction word list."""

import argparse
import collections
import gzip
import os
import unicodedata


ARABIC_REPLACEMENTS = str.maketrans({
    "أ": "ا",
    "إ": "ا",
    "آ": "ا",
    "ٱ": "ا",
    "ئ": "ي",
    "ی": "ي",
    "ے": "ي",
    "ک": "ك",
    "ڪ": "ك",
})

# Letters printed on the Sailfish Arabic layout.  Characters that need a
# long-press are normalized to their swipeable base key above.
ARABIC_KEYS = frozenset("ضصثقفغعهخحجشسيبلاتنمكطذءؤرىةوزظد")


def arguments():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--frequency", required=True)
    parser.add_argument("--hunspell", required=True)
    parser.add_argument("--reference", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--max-entries", type=int, default=210000)
    return parser.parse_args()


def normalise_word(value):
    value = unicodedata.normalize("NFKC", value).translate(ARABIC_REPLACEMENTS)
    result = []
    for character in value.strip():
        if character == "ـ" or unicodedata.category(character) == "Mn":
            continue
        if character not in ARABIC_KEYS:
            return ""
        result.append(character)
    word = "".join(result)
    return word if 1 < len(word) <= 32 else ""


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
        for line in handle:
            value = line.strip()
            if not value or value.startswith("#"):
                continue
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
    ranked = sorted(counts, key=lambda word: (-counts[word], word))
    ranked.extend(sorted(hunspell.difference(counts)))
    ranked = ranked[:args.max_entries]
    reference = reference_frequencies(args.reference)
    if not ranked or not reference:
        raise SystemExit("empty Arabic input or reference frequency list")

    generated = int(os.environ.get("SOURCE_DATE_EPOCH", "0"))
    with open(args.output, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("dictionary=main:ar,locale=ar,description=العربية,"
                     f"date={generated},version=1\n")
        for index, word in enumerate(ranked):
            reference_index = min(len(reference) - 1,
                                  int(index * len(reference) / len(ranked)))
            handle.write(f" word={word},f={max(1, reference[reference_index])}\n")
    print(f"wrote {len(ranked)} Arabic entries ({len(counts)} ranked, "
          f"{len(hunspell)} Ayaspell forms)")


if __name__ == "__main__":
    main()
