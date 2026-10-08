# FUTO community dictionary attribution

The optional Afrikaans, Azerbaijani, Belarusian, Bulgarian, Bengali, Catalan,
Esperanto, Estonian, Basque, Galician, Hindi, Hinglish, Armenian, Icelandic,
Indonesian, Georgian, Kabyle, Kazakh, Khmer, Kannada, Macedonian, Malayalam,
Marathi, Nepali, Punjabi, Slovak, Tamil, Telugu, Thai, Filipino, Toki Pona,
Ukrainian, Urdu and Standard Moroccan Tamazight prediction packs are converted
from the AOSP binary dictionaries published by the FUTO Keyboard dictionary
page:

- Catalogue: https://keyboard.futo.tech/dictionaries
- Collection: https://codeberg.org/Helium314/aosp-dictionaries
- Pinned collection revision: `795c8c4ab3de8286152f53855e006e8362a62103`

Stable source files are taken from `dictionaries/main_*.dict`. Afrikaans,
Estonian, Icelandic, Indonesian, Kabyle, Kazakh, Nepali, Slovak and Filipino
have no stable entry in that catalogue, so their clearly labelled
`dictionaries_experimental/main_*.dict` entries are used. Hebrew is
intentionally not included.

The collection catalogue is GPL-3.0. Individual dictionary data retains the
license and attribution recorded beside its entry on the FUTO page and in the
collection README. In particular:

- Afrikaans, Estonian, Icelandic, Indonesian, Kabyle, Kazakh, Nepali, Slovak
  and Filipino: CC BY 4.0 source data.
- Belarusian: CC BY-SA 4.0 GrammarDB data.
- Basque: Apache-2.0 AnySoftKeyboard language-pack data.
- Bengali, Hindi, Kannada, Malayalam, Marathi, Punjabi, Tamil, Telugu and
  Urdu: Indic Project dictionaries under GPL-2.0.
- Toki Pona: ilo Linku survey data under CC BY-SA 3.0 and 4.0.
- The remaining files retain the OpenBoard/AOSP or entry-specific terms and
  provenance named by the upstream catalogue.

The Sailfish conversion preserves words and their AOSP frequency tiers and
changes only the container from compiled `.dict` to the source-compatible
`combined` form consumed by this project's dictionary compiler. Very large
files are bounded at one million words to keep optional packs usable on
Sailfish devices.

This project claims no ownership over the word-list data. Please consult the
linked upstream catalogue for author names, original source URLs and the full
license metadata for each language.
