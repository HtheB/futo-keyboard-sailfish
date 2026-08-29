# Repository-maintained word lists

Word lists in this directory cover languages that the pinned upstream
FUTO/AOSP revision (`upstream/dictionaries/`) does not ship.  They use the
same AOSP `combined` text format and are compiled by `scripts/build.sh` with
the regular dictionary compiler.

## hu_wordlist.combined.gz — Hungarian (Magyar)

Built by `scripts/build-frequency-wordlist.py` (see its header for the exact
invocation) from:

- OpenSubtitles 2018 word counts, `hermitdave/FrequencyWords`
  (CC-BY-SA 4.0)
- `wordfreq` Hungarian frequencies by Robyn Speer, which combine Wikipedia,
  OpenSubtitles, web crawl and Twitter data (data CC-BY-SA 4.0)
- the openboard `hu_wordlist.combined` (Apache-2.0), used only to keep the
  original casing of proper nouns

Every word was checked with hunspell `hu_HU`; words hunspell rejects in
lowercase but accepts capitalised are stored capitalised (proper nouns), and
a capitalised form that the openboard list also knows is kept as a second
entry.
English words that leaked in from subtitles are filtered by comparing English
and Hungarian frequencies.  Frequencies are the log-mean of the OpenSubtitles
and wordfreq relative frequencies, rank-mapped onto the `f` distribution of
the German AOSP list so that the engine's ranking weights stay comparable.
210,000 entries.

The resulting list and the compiled `hu.fksidx` are derived from CC-BY-SA 4.0
data and are distributed under CC-BY-SA 4.0 with the attributions above.
