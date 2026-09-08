# FUTO Keyboard layout attribution

The layouts generated in `layouts/FutoGeneratedLayouts.js`, together with the
compatible legacy choices in `layouts/FutoLetterLayouts.js`, are adapted from the official
[futo-org/futo-keyboard-layouts](https://github.com/futo-org/futo-keyboard-layouts)
repository at commit `fb4dad270790d980c32417b60359104bd0c32c1c`.
Language-specific long-press choices are adapted from the locale data in the
official FUTO Android Keyboard repository at commit
`eaf0389f962b0dba07778d0feab6511e6e98c581`.

The Sailfish edition keeps its established SwiftKey-style QWERTY as a separate
choice. Generated FUTO choices preserve the primary rows, key labels, committed
text, shifted forms and language-specific long-press choices from the pinned
upstream data. Sailfish continues to provide its own fixed bottom control row.

The Turkish F key arrangement follows the established Turkish F layout as
recorded by the X.Org `xkeyboard-config` project in `symbols/tr` (original
Turkish layout contribution credited there to Nilgün Belma Bugüner, 2005).

Copyright belongs to the respective FUTO Keyboard layout contributors.  The
upstream layout repository is licensed under the Apache License, Version 2.0.
A complete copy of that license is included in this package as
`NOTO-EMOJI-SVG-LICENSE.txt` (the same Apache-2.0 license text also governing
the packaged Noto Emoji artwork).
