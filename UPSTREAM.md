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
- `scripts/generate-futo-layout-catalogue.py` converts the corresponding pinned
  FUTO YAML definitions into the generated Sailfish catalogue. Primary rows,
  labels, committed text, shifted forms and explicit number rows are retained;
  Sailfish continues to supply its platform-specific bottom control row.
- The existing SwiftKey-style QWERTY remains available separately from the
  exact generated FUTO QWERTY. Existing layout indices stay stable so upgrades
  do not rewrite users' per-language choices.
- Language-specific long-press choices are taken from the locale data in the
  pinned Android Keyboard revision above. Generated popups retain separate
  display labels and committed text, including multi-codepoint Arabic output.

Native script fonts:

- The bundled Amiri 1.003 font used for Arabic ligatures is an unmodified
  upstream OFL binary. SHA-256:
  `cd2550c0f4c05eb341bf97958211aaa39382bca96577ba3a67d4a3b4912c43c0`.
- Sailfish OS 5.2's Amiri 0.107 is reproduced with only U+FDFC's outline and
  metrics replaced by Android AppSupport's compact Rial glyph. It is installed
  beside, and never overwrites, the OS font. Its earlier filename makes native
  Qt select this otherwise identical copy. Sailfish source SHA-256:
  `8d441c9b07d0ebc200c9752a5ec505eb41a61468fba985b4f6d7c8157cf02da0`.
  Derived SHA-256:
  `7a0bd8b0481d3995196cf5161a1a290fd05ec23f3b5dafb47c06cc8acc832b93`.
- Noto Sans Tifinagh, Noto Sans Sinhala, Noto Sans Myanmar, Noto Sans Khmer,
  and Noto Naskh Arabic are unmodified upstream font binaries from the
  corresponding Noto Project repositories listed in
  `LICENSES/NOTO-FONTS-OFL.txt`.
- License: SIL Open Font License 1.1.
- SHA-256:
  - Noto Sans Tifinagh: `0385b743cad34aa1681b8e1ffff43c93b9a626a0db348cdf0b86f2a7ffcc411b`
  - Noto Sans Sinhala Light: `c645fa43ca3c384cbee102d3f398ba69d00c014378f62068c29d889b65a94f4b`
  - Noto Sans Myanmar Light: `6a70b1fcd6756173e51567554e4164687f76a3da88f93a5ac48e56c005152f72`
  - Noto Sans Khmer Light: `fd21655895fcf5b16ba499671c0e06e8450faf093d8c65c9f9ced970aabe1e70`
  - Noto Naskh Arabic 2.021: `c9a039ce48a477243c1eb7d561b13de115cfd651d8a83fa42e2f4d63c2e11b00`
  - Android AppSupport compact Noto Naskh Arabic UI 1.08 source:
    `61e022fdf23df726b4fdf2e5022c166c97ec4b3846c5dbb76fc0922798a2083a`
  - Renamed `FUTO Android Riyal` font:
    `8decb0be8598af58ce4f3d38862da6387b99acee44626963f2363b8ec54f4f79`
- They provide native Sailfish rendering for layout scripts that are available
  through Android's private font collection but absent from the base Sailfish
  font installation. Noto Naskh Arabic is selected only for U+20C1, U+FDFB,
  and U+FDFC inside the keyboard; ordinary Arabic retains Sailfish's system
  typeface.
- `scripts/build-android-riyal-font.py` creates the renamed font from
  `/system/fonts/NotoNaskhArabicUI-Regular.ttf` in
  `appsupport15-system-unprivileged-15.0.0.17.5-1.4.1.jolla.aarch64`. This
  preserves Android's preferred Rial design without making that older font a
  fallback for any other text.
- `scripts/build-amiri-riyal-font.py` applies the outline to an exact copy of
  Sailfish's Amiri source. Native Qt resolves U+FDFC through that family even
  when fontconfig ranks the dedicated Rial family first.

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
