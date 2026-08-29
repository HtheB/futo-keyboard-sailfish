# Repository-maintained word lists

Word lists in this directory cover languages that the pinned upstream
FUTO/AOSP revision (`upstream/dictionaries/`) does not ship.  They use the
same AOSP `combined` text format and are compiled by `scripts/build.sh` with
the regular dictionary compiler.

## hu_wordlist.combined.gz — Hungarian (Magyar)

Built by `scripts/build-frequency-wordlist.py` (see its header for the exact
invocation) from these pinned inputs:

- OpenSubtitles 2018 Hungarian word counts from
  `hermitdave/FrequencyWords` commit
  `525f9b560de45753a5ea01069454e72e9aa541c6` (CC-BY-SA 4.0). Input SHA-256:
  `d97b4e6017f16b1c0fc5c9bbb8a89e013adffd966c258951ed9067e0e0439689`.
- `wordfreq` 3.1.1 Hungarian frequencies by Robyn Speer, which combine
  Wikipedia, OpenSubtitles, web crawl and other sources (data CC-BY-SA 4.0).
- OpenBoard `v1.4.5`, commit
  `6c7582aae8577f2953a597a547924bbea3d832f4`, used only to retain the original
  casing of proper nouns (Apache-2.0). Input gzip SHA-256:
  `a1d275f91b6bf05764224a201c32738972d8c7b0007985c4ed4e4880c086ce33`.
- The German reference-frequency list from the repository's pinned FUTO
  Keyboard upstream commit documented in `UPSTREAM.md`.

Generation uses `wordfreq` 3.1.1 and Hunspell 1.7.2 with the Ubuntu
`hunspell-hu` 24.2.1 dictionary. The exact Hunspell input hashes are:

- `hu_HU.aff`: `0de3872251cd546fe9d15a49e6d065760168ff8ccbd0fca697ca85481fbaa1ad`
- `hu_HU.dic`: `36e12a1274a0a3fcd0528c23091c5bcada097c2851bd0435fb81249a6c2367c2`

`SOURCE_DATE_EPOCH=1788013310` fixes the generated header timestamp. The
uncompressed result has SHA-256
`2a7520fa35897f6758d14c1ccca43e731bff6fa8eb9775cd6e9264831e921463`; deterministic
`gzip -9 -n` output has SHA-256
`4f597b3c05346521c3f1cf8e9a8a5def8f75e0fa0351be6cf4fc42a2c68c3f53`.

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
data and are distributed under CC-BY-SA 4.0 with the attributions above. The
complete notice and license links are in
`LICENSES/HUNGARIAN-DICTIONARY-ATTRIBUTION.md`.
