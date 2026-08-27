#!/bin/sh
set -eu

target=/usr/share/jolla-settings/pages/text_input/textinput.qml
patch_file=/usr/share/futo-keyboard-sailfish/integration/textinput-bottom-settings.patch
marker='source: "/usr/share/jolla-settings/pages/futo-keyboard-sailfish/FutoTextInputSettings.qml"'

if [ ! -f "$target" ] || [ ! -f "$patch_file" ]; then
    echo "FUTO Keyboard: Sailfish Text input integration files are missing" >&2
    exit 1
fi

if grep -Fq "$marker" "$target"; then
    exit 0
fi

if ! patch --dry-run --silent --force "$target" "$patch_file"; then
    echo "FUTO Keyboard: this Sailfish Text input page is not compatible with the bottom-entry patch" >&2
    exit 1
fi

patch --silent --force "$target" "$patch_file"
