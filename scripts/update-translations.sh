#!/bin/sh
# Refresh every translations/futo-keyboard-sailfish-<lang>.ts file from the
# qsTr() strings in the settings pages, keyboard layouts and layout editor.
# Existing translations are kept; new strings are marked unfinished.
set -eu
cd "$(dirname "$0")/.."
LUPDATE=${LUPDATE:-lupdate}
for ts in translations/futo-keyboard-sailfish-*.ts; do
    "$LUPDATE" -no-obsolete -locations relative qml layouts editor \
        -extensions qml,js -ts "$ts"
done
