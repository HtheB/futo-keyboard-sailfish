#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
INSTALL_HOOK="$ROOT/packaging/scripts/install-textinput-bottom-hook.sh"
REMOVE_HOOK="$ROOT/packaging/scripts/remove-textinput-bottom-hook.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

target="$WORK/textinput.qml"
original="$WORK/textinput-original.qml"
cat > "$original" <<'EOF'
import QtQuick 2.0

Page {
    SilicaFlickable {
        Column {
            Item {
                ComboBox {
                    currentIndex: 0
                    value: enabledPhysicalLayoutModel.getLayoutIndex(currentPhysicalLayoutConfig.value)
                }
            }
        }
    }
}
EOF
cp "$original" "$target"
chmod 0644 "$target"

# A clean installation adds exactly one entry without an external patch tool.
FUTO_TEXTINPUT_TARGET="$target" "$INSTALL_HOOK"
test "$(grep -Fc 'FutoTextInputSettings.qml' "$target")" -eq 1
grep -Fq '// FUTO Keyboard: keep its settings entry last on this page.' "$target"
test "$(stat -c '%a' "$target")" = 644

# Running the upgrade hook again must be idempotent.
first_sum=$(sha256sum "$target")
FUTO_TEXTINPUT_TARGET="$target" "$INSTALL_HOOK"
test "$first_sum" = "$(sha256sum "$target")"

# Removal accepts the exact block installed by both the old patch and the new
# self-contained hook, restores the original, and is also idempotent.
FUTO_TEXTINPUT_TARGET="$target" "$REMOVE_HOOK"
cmp -s "$original" "$target"
FUTO_TEXTINPUT_TARGET="$target" "$REMOVE_HOOK"
cmp -s "$original" "$target"

# An unknown Sailfish page must be left untouched rather than edited at a
# guessed location.
printf '%s\n' 'Page { Item {} }' > "$target"
incompatible_sum=$(sha256sum "$target")
if FUTO_TEXTINPUT_TARGET="$target" "$INSTALL_HOOK" 2>/dev/null; then
    echo "incompatible Text input page was unexpectedly accepted" >&2
    exit 1
fi
test "$incompatible_sum" = "$(sha256sum "$target")"

echo "Text input settings hook tests passed"
