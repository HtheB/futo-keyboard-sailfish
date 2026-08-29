# Hungarian prediction dictionary attribution

The Hungarian source word list (`dictionaries/hu_wordlist.combined.gz`) and
the compiled downloadable `hu.fksidx` are adapted from the following data:

- OpenSubtitles 2018 Hungarian word frequencies from
  [hermitdave/FrequencyWords](https://github.com/hermitdave/FrequencyWords),
  commit `525f9b560de45753a5ea01069454e72e9aa541c6`.
- Hungarian frequency data from
  [wordfreq 3.1.1](https://github.com/rspeer/wordfreq/tree/v3.1.1), by Robyn
  Speer and its data contributors.

Those frequency datasets and this adapted dictionary are licensed under the
[Creative Commons Attribution-ShareAlike 4.0 International license](https://creativecommons.org/licenses/by-sa/4.0/legalcode.en).
The adaptation filters and validates Hungarian words, combines and remaps
frequency rankings, retains selected capitalization, and emits FUTO's AOSP
combined-dictionary format. FUTO Keyboard for Sailfish OS distributes the
adapted result under the same CC BY-SA 4.0 license.

Capitalization reference data comes from
[OpenBoard v1.4.5](https://github.com/openboard-team/openboard/tree/6c7582aae8577f2953a597a547924bbea3d832f4/dictionaries)
and is used under the
[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).

Exact input checksums and generation details are recorded in
`dictionaries/README.md`.
