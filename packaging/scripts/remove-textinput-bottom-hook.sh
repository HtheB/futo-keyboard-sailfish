#!/bin/sh
set -eu

target=${FUTO_TEXTINPUT_TARGET:-/usr/share/jolla-settings/pages/text_input/textinput.qml}
comment='            // FUTO Keyboard: keep its settings entry last on this page.'
loader='            Loader {'
width='                width: parent.width'
source_marker='                source: "/usr/share/jolla-settings/pages/futo-keyboard-sailfish/FutoTextInputSettings.qml"'
close='            }'

if [ ! -f "$target" ] || ! grep -Fq "$source_marker" "$target"; then
    exit 0
fi

source_count=$(grep -Fc "$source_marker" "$target" || :)
if [ "$source_count" -ne 1 ]; then
    echo "FUTO Keyboard: cannot safely remove a non-unique Text input integration" >&2
    exit 1
fi

source_match=$(grep -Fn "$source_marker" "$target")
source_line=${source_match%%:*}
block_start=$((source_line - 4))
block_end=$((source_line + 1))
if [ "$block_start" -lt 1 ] \
        || [ -n "$(sed -n "${block_start}p" "$target")" ] \
        || [ "$(sed -n "$((block_start + 1))p" "$target")" != "$comment" ] \
        || [ "$(sed -n "$((block_start + 2))p" "$target")" != "$loader" ] \
        || [ "$(sed -n "$((block_start + 3))p" "$target")" != "$width" ] \
        || [ "$(sed -n "$((block_start + 4))p" "$target")" != "$source_marker" ] \
        || [ "$(sed -n "$((block_start + 5))p" "$target")" != "$close" ]; then
    echo "FUTO Keyboard: cannot safely remove the modified Text input integration" >&2
    exit 1
fi

temporary=${target}.futo.$$
trap 'rm -f "$temporary"' EXIT HUP INT TERM
rm -f "$temporary"
cp -p "$target" "$temporary"
sed "${block_start},${block_end}d" "$target" > "$temporary"

if grep -Fq "$source_marker" "$temporary"; then
    echo "FUTO Keyboard: could not verify removal of the Text input integration" >&2
    exit 1
fi

mv -f "$temporary" "$target"
trap - EXIT HUP INT TERM
