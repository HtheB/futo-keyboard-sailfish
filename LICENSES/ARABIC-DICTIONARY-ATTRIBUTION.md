# Arabic prediction dictionary attribution

`ar_wordlist.combined.gz` is generated deterministically by
`scripts/build-arabic-wordlist.py` from these pinned inputs:

- Arabic word frequencies from `hermitdave/FrequencyWords` commit
  `525f9b560de45753a5ea01069454e72e9aa541c6` (MIT). Input SHA-256:
  `ebb36aeae78e609adc552b32ec91ff2490e1170f8b244d22eef9952d2096d610`.
- The Ayaspell Arabic Hunspell dictionary carried by LibreOffice Dictionaries
  commit `32b006a2c22a4ac7e8ed3f03346f7b3d85a970a4`. The original project offers
  GPL-2.0-or-later, LGPL-2.1-or-later, or MPL-1.1-or-later; this distribution
  uses the LGPL-2.1-or-later option. Input SHA-256 values:
  `ar.dic` `2a3e5367f61c1583734db9d66734f5603e6be5c2d227cf5c5cd7e4ca586e34fe`,
  `ar.aff` `cec30b8621001e49618feb05aec1984c5fcfbf7d2ec309901d5cbf66585217a3`.
- The German reference-frequency distribution from the pinned FUTO Keyboard
  revision in `UPSTREAM.md`, used only to map ranks to the existing engine's
  frequency scale.

Arabic compatibility forms and combining marks are normalized to the primary
characters available on the Sailfish Arabic layout. `SOURCE_DATE_EPOCH` is
fixed by the build. The result contains 210,000 entries. The uncompressed
output has SHA-256
`23c92a8059874011bb648963801ee58ed5a719ebb5bc582a4cb4c77e4e435797`;
deterministic `gzip -9 -n` output has SHA-256
`ee4941bab6bf53b92015421623bee893dba78c6b455c276a0afee5b00c09fd21`.

The resulting Arabic word list is distributed under LGPL-2.1-or-later.
