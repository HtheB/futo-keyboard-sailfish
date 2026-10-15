# Japanese and Chinese input attribution

The conversion workers are rebuilt from the Mozc and RIME sources pinned in
`UPSTREAM.md`. The Sailfish adapters are maintained in `composition/`.

## Native workers

- Mozc: Google BSD-3-Clause, including its NAIST/ICOT dictionary notice;
  `MOZC-BSD-LICENSE.txt`.
- Mozc's protobuf 31.1 dependency: `MOZC-PROTOBUF-LICENSE.txt`.
- protobuf's UTF-8 validation and zlib dependencies:
  `MOZC-UTF8-RANGE-LICENSE.txt` and `MOZC-ZLIB-LICENSE.txt`.
- Abseil 20250512.0: Apache-2.0, `MOZC-ABSEIL-LICENSE.txt`.
- FUTO RimeJni build integration: MIT, `RIME-JNI-MIT-LICENSE.txt`.
- librime 1.16.1: BSD-3-Clause, `RIME-RIME-LICENSE.txt`.
- librime-predict: BSD-3-Clause, `RIME-LIBRIME-PREDICT-LICENSE.txt`.
- Boost 1.89.0: BSL-1.0, `RIME-BOOST-LICENSE.txt`.
- LevelDB 1.23: BSD-3-Clause, `RIME-LEVELDB-LICENSE.txt`.
- marisa-trie 0.3.1: chosen BSD-2-Clause license,
  `RIME-MARISA-TRIE-LICENSE.txt`.
- OpenCC 1.1.9: Apache-2.0, `RIME-OPENCC-LICENSE.txt`.
- yaml-cpp 0.8.0: MIT, `RIME-YAML-CPP-LICENSE.txt`.
- GCC runtime libraries: GPL-3.0 with GCC Runtime Library Exception 3.1,
  `GCC-RUNTIME-EXCEPTION.txt`; the full GPL-3.0 text is included in
  `FUTO-SWIPE-GPL-3.0.txt`.

The workers do not build librime-lua or FUTO's Android JNI UI. Standard build
tools and Android wrappers are not bundled as applications in the RPM.

## Optional official language data

Unmodified official FUTO language data is downloaded separately from the
release mirror, with FUTO's server as a fallback. Downloads are verified against
the sizes and SHA-256 hashes in `content/composition-packs.json`.
The main RPM does not contain these datasets.

The Japanese catalogue lists Mozc (BSD-3-Clause), UT/Sudachi (Apache-2.0),
Wikipedia/EDICT2 (CC BY-SA 4.0), alt-cannadic/SKK-JISYO (GPL-2.0) and IPAdic
(NAIST 2003) among the dataset sources. See the original distribution and
https://keyboard.futo.tech/dictionaries for the data-specific notices.

The Chinese ZIP contains the upstream LICENSE and per-dictionary notices for
double-Pinyin (GPL-3.0), prelude/essay/luna-Pinyin/stroke (LGPL-3.0) and OpenCC
(Apache-2.0). Those files are retained without modification during extraction.

Private Chinese deployment patches disable adaptive user dictionaries, set
the Simplified/Traditional switch, and add the simplifier to the stroke schema.
Compiled public dictionary caches are removed with the language pack.
