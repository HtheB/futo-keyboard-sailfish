#!/bin/sh
set -eu

target=${FUTO_TEXTINPUT_TARGET:-/usr/share/jolla-settings/pages/text_input/textinput.qml}
source_marker='                source: "/usr/share/jolla-settings/pages/futo-keyboard-sailfish/FutoTextInputSettings.qml"'
anchor='value: enabledPhysicalLayoutModel.getLayoutIndex(currentPhysicalLayoutConfig.value)'

if [ ! -f "$target" ]; then
    echo "FUTO Keyboard: Sailfish Text input page is missing" >&2
    exit 1
fi

if grep -Fq "$source_marker" "$target"; then
    exit 0
fi

anchor_count=$(grep -Fc "$anchor" "$target" || :)
if [ "$anchor_count" -ne 1 ]; then
    echo "FUTO Keyboard: this Sailfish Text input page has no unique integration point" >&2
    exit 1
fi

anchor_match=$(grep -Fn "$anchor" "$target")
anchor_line=${anchor_match%%:*}
first_close=$(sed -n "$((anchor_line + 1))p" "$target")
second_close=$(sed -n "$((anchor_line + 2))p" "$target")
if [ "$first_close" != '                }' ] || [ "$second_close" != '            }' ]; then
    echo "FUTO Keyboard: this Sailfish Text input page is not compatible with the settings integration" >&2
    exit 1
fi

insert_after=$((anchor_line + 2))
continue_at=$((insert_after + 1))
temporary=${target}.futo.$$
trap 'rm -f "$temporary"' EXIT HUP INT TERM
rm -f "$temporary"
cp -p "$target" "$temporary"
sed -n "1,${insert_after}p" "$target" > "$temporary"
cat >> "$temporary" <<'EOF'

            // FUTO Keyboard: keep its settings entry last on this page.
            Loader {
                width: parent.width
                source: "/usr/share/jolla-settings/pages/futo-keyboard-sailfish/FutoTextInputSettings.qml"
            }
EOF
sed -n "${continue_at},\$p" "$target" >> "$temporary"

if [ "$(grep -Fc "$source_marker" "$temporary" || :)" -ne 1 ]; then
    echo "FUTO Keyboard: could not verify the updated Sailfish Text input page" >&2
    exit 1
fi

mv -f "$temporary" "$target"
trap - EXIT HUP INT TERM
