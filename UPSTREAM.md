# Upstream record

- Repository: https://github.com/futo-org/android-keyboard
- Commit: `eaf0389f962b0dba07778d0feab6511e6e98c581`
- Commit date: 2026-08-11
- Source verification: clean checkout; commit matched `origin/master`
- Prediction dictionaries, including Greek (`el`), Russian (`ru`), and
  Serbian Cyrillic (`sr`), are compiled from the word lists in that same
  pinned upstream revision. Serbian Latin (`sr_Latn`) is deterministically
  transliterated from the pinned Serbian word list during the build.
- Hungarian (`hu`) is built from separately pinned frequency and casing data
  because the FUTO revision does not include it. Its exact sources, checksums,
  transformation and CC BY-SA 4.0 terms are documented in
  `dictionaries/README.md` and
  `LICENSES/HUNGARIAN-DICTIONARY-ATTRIBUTION.md`.
- Persian (`fa`) is built from separately pinned Persian frequency data and
  the Apache-2.0 Lilak Hunspell dictionary. Exact inputs, hashes, transformation
  and notices are documented in `dictionaries/README.md` and
  `LICENSES/PERSIAN-DICTIONARY-ATTRIBUTION.md`.
- Arabic (`ar`) is built from pinned Arabic frequency data and the Ayaspell
  Hunspell dictionary. Exact inputs, hashes, transformations and license choice
  are documented in `dictionaries/README.md` and
  `LICENSES/ARABIC-DICTIONARY-ATTRIBUTION.md`.

Keyboard layout definitions:

- Repository: https://github.com/futo-org/futo-keyboard-layouts
- Commit: `fb4dad270790d980c32417b60359104bd0c32c1c`
- License: Apache-2.0
- The Serbian Cyrillic arrangement follows the upstream South Slavic layout,
  with its primary keys limited to the modern Serbian alphabet (the obsolete
  Cyrillic Dze is not kept as an extra primary key).

Offline voice input:

- Repository: https://github.com/futo-org/voice-input
- Commit: `680562f1f80f3caf57b21c72930523ccd9241b86`
- Model: `tiny_acft_q8_0.bin` (FUTO Multilingual-39)
- Model SHA-256: `07aa4d514144deacf5ffec5cacb36c93dee272fda9e64ac33a801f8cd5cbd953`
- License: FUTO Source First License 1.0 (included separately)

FUTO Swipe:

- C++ library: https://gitlab.futo.org/keyboard/swipe-library.git at commit
  `1b13f2c85d6b347f6ea3fbc4b3aaf01fce42429a` (GPL-3.0-only).
- Universal encoder: https://huggingface.co/futo-org/futo-swipe at commit
  `18328c3042b066952c0936b3771d492fe2ec289a`.
- Encoder model SHA-256:
  `725242bab5d14345e96ff214e8de2bfbc1f962c232d320df9c24cb82ffd1fbaf`.
- Metadata SHA-256:
  `d2c5aecd89d97e21125046eb1f311b5aed1bdb5805e97316bba70b13f1c7be2c`.
- English QWERTY decoder (`magic_macaw/model_fp32.pte`) SHA-256:
  `01eaf16ac4bc0f1ed0698c240807f0e95e6d427bcf6de04983ffc50736744d85`.
- English context model (`hungry_jellyfish/context_lm.pte`) SHA-256:
  `74d29f56a513c0c60abcd43df3b16a6b68925cdf4e97e51b094a5275ec2810d7`.
- English context vocabulary SHA-256:
  `a7db66376783b5a23ee3d4a2aaa8f2499fd9b35f975e92bcb248664c2cf6ebd1`.
- Model license: FUTO Model Weights License 1.0. The unmodified model is an
  optional content download; its complete terms are included in the archive
  and in `LICENSES/FUTO-SWIPE-MODEL-WEIGHTS-LICENSE.md`.
- Runtime: ExecuTorch 1.2, built from the swipe-library's pinned submodule.

The Sailfish worker supplies the live key geometry and installed language trie
to the universal encoder. FUTO's decoder and context model are additionally
used for a single active English QWERTY language; they are not applied to
languages or layouts for which they were not trained. The worker runs as a
separate GPLv3 process and communicates with the keyboard helper through a
small line protocol.

The added Turkish F arrangement follows X.Org `xkeyboard-config`'s
`symbols/tr` Turkish F definition; only the visible three letter rows are used.

Password ZIP encryption:

- Repository: https://github.com/yeka/zip
- Revision: `03d6312748a9`
- Purpose: WinZip-compatible AES-256 encryption for portable password exports
- License: MIT (`LICENSES/YEKA-ZIP-LICENSE.txt`)

No exploratory prebuilt binaries are included. This project rebuilds its
required native components from the recorded source files.

Native Sailfish build dependencies:

- Qt Base 5.6.3: https://github.com/qt/qtbase at
  `e6f8b072d2bf15f8b82bede48ff29ce8ac8dbd9a`
- Sailfish Secrets 0.2.44: https://github.com/sailfishos/sailfish-secrets at
  `5a8d33e2eda2fe10a64acc42912dd3bedc736495`
- Target Qt, xkbcommon and Sailfish Secrets libraries/configuration headers are
  taken from the user's matching Sailfish SDK target by
  `scripts/prepare-build-environment.sh`. When xkbcommon development headers
  are absent from the target, the script stages the API headers from the host
  development package. Target binaries are never committed or placed in source
  archives.

The complete Unicode Emoji 17 data and artwork are regenerated with
`scripts/fetch-full-emoji-set.ps1` from the pinned Unicode, Twemoji, OpenMoji,
and Noto Emoji revisions recorded in `EMOJI-ATTRIBUTION.md`. Noto's supplied
PNG artwork is used directly; missing Noto 17 sequences are deterministically
rasterized from pinned Twemoji SVGs so no picker cell is blank on Sailfish.
