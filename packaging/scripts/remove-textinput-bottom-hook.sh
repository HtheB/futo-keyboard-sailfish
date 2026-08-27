#!/bin/sh
set -eu

target=/usr/share/jolla-settings/pages/text_input/textinput.qml
patch_file=/usr/share/futo-keyboard-sailfish/integration/textinput-bottom-settings.patch
marker='source: "/usr/share/jolla-settings/pages/futo-keyboard-sailfish/FutoTextInputSettings.qml"'

if [ ! -f "$target" ] || ! grep -Fq "$marker" "$target"; then
    exit 0
fi

if [ ! -f "$patch_file" ]; then
    echo "FUTO Keyboard: cannot remove the Text input integration because its patch file is missing" >&2
    exit 1
fi

if ! patch --dry-run --silent --force --reverse "$target" "$patch_file"; then
    echo "FUTO Keyboard: cannot safely remove the Text input integration from the modified system page" >&2
    exit 1
fi

patch --silent --force --reverse "$target" "$patch_file"
