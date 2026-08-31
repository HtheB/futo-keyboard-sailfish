# Emoji data and artwork attribution

FUTO Keyboard for Sailfish OS 0.2.3 includes all 3,944 fully-qualified
sequences in the Unicode Emoji 17.0 test data. The picker presents 1,914 base
entries and keeps all 2,030 skin-tone sequences reachable through long-press
choices. Each user-selectable style contains an image for every sequence.

Unicode data source: <https://www.unicode.org/Public/17.0.0/emoji/emoji-test.txt>

- Unicode version: `17.0`
- SHA-256: `1d8a944f88d7952f7ef7c5167fef3c67995bcae24543949710231b03a201acda`

Search names and keywords for all 21 supported languages come from the
Unicode CLDR 48.2 annotation and derived-annotation datasets at
<https://github.com/unicode-org/cldr-json/tree/48.2.0>. They are distributed
under Unicode License v3; see `UNICODE-LICENSE.txt`.

Apart from normalized filenames and the Noto fallback described below, source
artwork is unchanged. Selecting a style changes only the keyboard rendering;
the corresponding standard Unicode sequence is inserted into the text field.

## Twemoji

- Source: <https://github.com/jdecked/twemoji>
- Release: `v17.0.3`
- Commit: `b6b55fef1e8636b540a6d016a4729ca8cdf2e60b`
- Artwork license: Creative Commons Attribution 4.0 International
- License copy: `TWEMOJI-GRAPHICS-LICENSE.txt`

Copyright for the original Twemoji artwork belongs to its respective Twemoji
contributors and rights holders.

## OpenMoji Color

- Source: <https://github.com/hfg-gmuend/openmoji>
- Release: `17.0.0`
- Commit: `f9fc506a3f913be9897ab0181d611d4c910a4104`
- Artwork license: Creative Commons Attribution-ShareAlike 4.0 International
- License copy: `OPENMOJI-LICENSE.txt`

OpenMoji is an open-source emoji and icon project of HfG Schwäbisch Gmünd.

## Noto Color Emoji

- Source: <https://github.com/googlefonts/noto-emoji>
- Release: `v2.051`
- Commit: `8998f5dd683424a73e2314a8c1f1e359c19e8742`
- Artwork license: Apache License 2.0
- License notice copy: `NOTO-EMOJI-SVG-LICENSE.txt`

Copyright 2013 Google, Inc. All Rights Reserved.

The pinned Noto release does not provide a directly matching PNG for 262 Emoji
17 sequences or aliases. Those 262 cells use deterministic PNG renderings of
the pinned Twemoji SVG artwork, under Twemoji's CC BY 4.0 license, rather than
showing blank or layered-black glyphs on Sailfish OS 5.2.
