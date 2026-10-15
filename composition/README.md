# Native conversion input

Japanese QWERTY romaji and 12-key kana flick use Mozc's kana/kanji conversion. Simplified and
Traditional Chinese use RIME's Pinyin and stroke schemas. These are actual
conversion engines, independent of the ordinary dictionary/swipe predictor.
The exact source revisions and optional data hashes are in `UPSTREAM.md`.

Enable a language in **Languages and layouts**, download its conversion pack,
and select that language from the keyboard. Tap a candidate in the conversion
strip to commit it. Japanese has an ABC/あ switch for Latin typing; its 123 key
remains on the third row. Chinese keeps its Pinyin/stroke reading in the strip.
Choose **Kana flick (12-key)** in the Japanese layout selector for the upstream
four-row kana keyboard. Tap for the central kana, or drag left/up/right/down
for its directional kana. The 小゛゜ key changes voicing and small forms through
Mozc's original 12-key table. ABC opens FUTO's corresponding 12-key Latin page;
hold ABC for Quick Settings. Repeated taps cycle through kana or Latin letters,
unless **Flick input only** is enabled. Japanese QWERTY retains direct Latin
typing. Pinyin and Stroke are separate choices for both Chinese scripts.
**Japanese and Chinese** settings expose half-width Japanese spaces, fuzzy
Pinyin, six double-Pinyin schemes, and an independent output-script choice.
Tap the unfinished Chinese reading to move its cursor. Expand the candidate
strip to browse a scrollable grid; additional native candidates load in pages.

`futo-keyboard-mozc` and `futo-keyboard-rime` are supervised by the helper, not
loaded into Maliit. Sessions use an owner, random token and revision number.
Replies from an old editor cannot insert into a new one. Conversion learning
uses the existing device-bound learned-data encryption. Engine profiles are
decrypted only in private RAM-backed directories and removed when a session
ends. Incognito, disabled personal learning, and locked storage create isolated
non-learning profiles that cannot read past history. Chinese's one-time
dictionary preparation caches only public language data. Japanese next-word
candidates are provided by Mozc's zero-query suggestions.

## Building

`scripts/bootstrap-futo-composition.sh` retrieves the pinned sources.
`scripts/build-futo-composition.sh` builds both target workers using the
Sailfish SDK. Set `FUTO_ARCH`, `FUTO_TARGET_SYSROOT`, `FUTO_CXX`, `FUTO_CC`,
`FUTO_STRIP`, and, if needed, `FUTO_BAZEL`/`FUTO_BUILD_JOBS`. Mozc requires a
C++20-capable compiler and Bazel 8.2.1. Dependency archive hashes come from the
pinned FUTO RimeJni build. Static target runtime libraries avoid adding a
libatomic dependency on devices where that package is absent.

The ordinary test suite includes fake-worker protocol/privacy tests and the
production QML session controller. Set `FUTO_TEST_COMPOSITION_WORKERS` and
`FUTO_TEST_COMPOSITION_DATA` to run `TestCompositionNative` with rebuilt
workers and verified language packs. Tests cover real conversions, candidate
IDs, deletion, reset, session isolation, private-profile cleanup and warm starts.

Godan and CJK swiping are not currently exposed. Conversion is disabled in password, numeric, URL,
email and terminal fields; those use ordinary direct input.
