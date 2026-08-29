#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ENGINE="$ROOT/build/futo-dictionary-compiler"

node --check < "$ROOT/packaging/polkit/49-futo-keyboard-secrets.rules"
node "$ROOT/scripts/check-symbol-data.js"
grep -Fq 'org.hb.futo.keyboard.saved-login' \
    "$ROOT/packaging/polkit/org.hb.futo.keyboard.policy"
grep -Fq '"--allow-user-interaction"' \
    "$ROOT/helper/cmd/futo-keyboard-helper/main.go"
! grep -Fq '"system_settings/system/futo_keyboard"' \
    "$ROOT/helper/cmd/futo-keyboard-helper/main.go"
grep -Fq 'futoParentPid(pid)' "$ROOT/packaging/polkit/49-futo-keyboard-secrets.rules"
grep -Fq '"/proc/" + String(pid) + "/" + name' \
    "$ROOT/packaging/polkit/49-futo-keyboard-secrets.rules"
! grep -Fq '"/bin/ps"' "$ROOT/packaging/polkit/49-futo-keyboard-secrets.rules"
grep -Fq '/futo-keyboard-helper.service' \
    "$ROOT/packaging/polkit/49-futo-keyboard-secrets.rules"
grep -Fq 'org.hb.FutoKeyboard.learned-key-v1' \
    "$ROOT/packaging/polkit/49-futo-keyboard-secrets.rules"
grep -Fq 'org.hb.FutoKeyboard.vault-key-v1' \
    "$ROOT/packaging/polkit/49-futo-keyboard-secrets.rules"
grep -Fq 'hasTrustedHelperParent()' "$ROOT/vault/futo-keyboard-secrets.cpp"
grep -Fq '/usr/libexec/futo-keyboard-helper' "$ROOT/vault/futo-keyboard-secrets.cpp"
grep -Fq 'LockCodeRequest::ProvideLockCode' "$ROOT/vault/futo-keyboard-secrets.cpp"
grep -Fq '/usr/libexec/futo-keyboard-keyring' "$ROOT/helper/cmd/futo-keyboard-helper/main.go"
grep -Fq 'trusted_parent()' "$ROOT/vault/futo-keyboard-keyring.c"
grep -Fq '/var/lib/futo-keyboard-sailfish' "$ROOT/vault/futo-keyboard-keyring.c"
grep -Fq '%attr(4755,root,root) %{_libexecdir}/futo-keyboard-keyring' \
    "$ROOT/packaging/rpm/futo-keyboard-sailfish.spec"
grep -Fq 'trusted_parent()' "$ROOT/vault/futo-keyboard-focus.c"
grep -Fq 'KEY_TAB' "$ROOT/vault/futo-keyboard-focus.c"
grep -Fq 'KEY_LEFTSHIFT' "$ROOT/vault/futo-keyboard-focus.c"
grep -Fq 'FocusCredentialField(sender dbus.Sender' \
    "$ROOT/helper/cmd/futo-keyboard-helper/main.go"
grep -Fq 'trustedNamedVaultCaller(sender, "com.jolla.keyboard")' \
    "$ROOT/helper/cmd/futo-keyboard-helper/main.go"
grep -Fq '%attr(4755,root,root) %{_libexecdir}/futo-keyboard-focus' \
    "$ROOT/packaging/rpm/futo-keyboard-sailfish.spec"
grep -Fq 'trusted_parent()' "$ROOT/vault/futo-keyboard-appsupport.c"
grep -Fq 'AlienKeyboardService"' "$ROOT/vault/futo-keyboard-appsupport.c"
grep -Fq 'ShowAndroidKeyboard()' \
    "$ROOT/helper/cmd/futo-keyboard-helper/main.go"
grep -Fq 'InjectAndroidKey' \
    "$ROOT/helper/cmd/futo-keyboard-helper/main.go"
grep -Fq 'InjectAndroidSwipe' \
    "$ROOT/helper/cmd/futo-keyboard-helper/main.go"
grep -Fq 'EndAndroidKeyboard' \
    "$ROOT/helper/cmd/futo-keyboard-helper/main.go"
grep -Fq 'restart", "maliit-server.service"' \
    "$ROOT/helper/cmd/futo-keyboard-helper/main.go"
grep -Fq 'KEYCODE_DEL' "$ROOT/vault/futo-keyboard-appsupport.c"
grep -Fq 'forcedAppSupportKeyEvents' "$ROOT/qml/FutoInputHandler.qml"
grep -Fq '"remote-method": "ShowAndroidKeyboard"' \
    "$ROOT/packaging/settings/futo-keyboard.json"
grep -Fq '%attr(4755,root,root) %{_libexecdir}/futo-keyboard-appsupport' \
    "$ROOT/packaging/rpm/futo-keyboard-sailfish.spec"
grep -Fq 'credentialAutofillStage === 0' "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'Authenticator.Fingerprint' "$ROOT/qml/FutoDeviceAuthentication.qml"
grep -Fq 'FutoDeviceLockInputPage.qml' "$ROOT/qml/FutoDeviceAuthentication.qml"
grep -Fq 'if (settings.personalDictionaryProtected)' "$ROOT/qml/FutoPrivacyPage.qml"
grep -Fq 'InitializeLearnedEncryption' "$ROOT/qml/FutoLearnedDataPage.qml"
grep -Fq '{ "id": "sound", "label": qsTr("Keyboard sounds")' \
    "$ROOT/qml/FutoQuickSettingsPage.qml"
grep -Fq 'keyboardSettings.keySoundEnabled = !keyboardSettings.keySoundEnabled' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'actionId === "sound"' "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'settings.settingsVersion = 10' "$ROOT/qml/FutoSettingsPage.qml"
grep -Fq 'settingsUi.call("showPage"' "$ROOT/qml/FutoInputHandler.qml"
! sed -n '/function openFutoSettings()/,/^    }/p' \
    "$ROOT/qml/FutoInputHandler.qml" | grep -Fq 'userHide()'
grep -Fq 'function moveCursor2D(horizontalSteps, verticalSteps)' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'Qt.Key_Up : Qt.Key_Down' "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'keyboard.inputHandler.beginCursorMoveMode()' \
    "$ROOT/layouts/FutoSpacebarKey.qml"
grep -Fq 'if (!pointerDown || cursorMode || keyboardDismissed)' \
    "$ROOT/layouts/FutoSpacebarKey.qml"
grep -Fq 'spaceKey.pointerDown = false' \
    "$ROOT/layouts/FutoSpacebarKey.qml"
! sed -n '/function beginCursorMoveMode()/,/^\t}/p' \
    "$ROOT/qml/FutoInputHandler.qml" | grep -Fq 'beginSpacebarGesture()'
grep -Fq 'Math.max(Theme.itemSizeLarge, height * 1.6)' \
    "$ROOT/layouts/FutoSpacebarKey.qml"
grep -Fq 'opacity: root.cursorMoveMode ? 0 : 1' \
    "$ROOT/layouts/FutoQwertyLayout.qml"
grep -Fq 'readonly property bool cursorStatusVisible: futoHandler.cursorMoveMode' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'Drag finger to move cursor' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'id: cursorMoveIcon' "$ROOT/qml/FutoInputHandler.qml"
grep -Fq '// Up and down.' "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'touchSource.maximumTouchPoints = swiping ? 1' \
    "$ROOT/layouts/FutoKeyboardLayout.qml"
grep -Fq 'keyboard.cancelTouchPoint(ids[i])' \
    "$ROOT/layouts/FutoKeyboardLayout.qml"
grep -Fq 'normalMaximumTouchPoints < 0' \
    "$ROOT/layouts/FutoKeyboardLayout.qml"
grep -Fq 'property bool gesturePreviewSuppressed' \
    "$ROOT/layouts/FutoCharacterKey.qml"
grep -Fq '&& !gesturePreviewSuppressed' \
    "$ROOT/layouts/FutoCharacterKey.qml"
grep -Fq 'keyboardLayout.handler.beginCursorSelection()' \
    "$ROOT/layouts/FutoKeyboardLayout.qml"
grep -Fq 'property bool cursorSelectionMode: false' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'cursorSelectionMode ? Qt.ShiftModifier : 0' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'Drag finger to select text' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq '"٠١٢٣٤٥٦٧٨٩".charAt(index)' \
    "$ROOT/layouts/FutoQwertyLayout.qml"
grep -Fq 'case "١": return "1½¼¹⅛⅓"' \
    "$ROOT/layouts/FutoCharacterKey.qml"
grep -Fq 'arabicAlternatives ? "١½¼¹⅛⅓"' \
    "$ROOT/layouts/FutoCharacterKey.qml"
grep -Fq 'targetLayout.numberPageLabel()' \
    "$ROOT/layouts/FutoSymbolKey.qml"
grep -Fq 'targetLayout.letterPageLabel()' \
    "$ROOT/layouts/FutoSymbolKey.qml"
grep -Fq '"?r=" + revision' \
    "$ROOT/layouts/FutoQwertyLayout.qml"
grep -Fq 'SilicaListView {' \
    "$ROOT/layouts/FutoEmojiGrid.qml"
grep -Fq 'model: Math.ceil(emojiGrid.entries.length / emojiGrid.columns)' \
    "$ROOT/layouts/FutoEmojiGrid.qml"
grep -Fq 'emojiTabAssetPath(index)' "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'EMOJI_TAB_CODEPOINTS :=' "$ROOT/packaging/Makefile"
grep -Fq '1f550 1f600 1f44b 1f43b 1f354 1f697 26bd 1f4a1 2764 1f3f3' \
    "$ROOT/scripts/build-rpm.sh"
grep -Fq 'asynchronous: false' "$ROOT/layouts/FutoEmojiKey.qml"
grep -Fq 'signalsEnabled: true' "$ROOT/qml/FutoEmojiSettingsPage.qml"
grep -Fq 'function contentChanged(packId, state)' \
    "$ROOT/qml/FutoEmojiSettingsPage.qml"
grep -Fq 'status === PageStatus.Active' \
    "$ROOT/qml/FutoEmojiSettingsPage.qml"
grep -Fq 'Sailfish OS (built-in)' "$ROOT/qml/FutoEmojiSettingsPage.qml"
grep -Fq 'firstAvailableEmojiStyle(installed)' "$ROOT/qml/FutoEmojiSettingsPage.qml"
grep -Fq 'property int emojiStyle: 3' "$ROOT/layouts/FutoQwertyLayout.qml"
grep -Fq 'if (emojiStyle === 3)' "$ROOT/layouts/FutoEmojiKey.qml"
grep -Fq 'securezip.AES256Encryption' \
    "$ROOT/helper/cmd/futo-keyboard-helper/main.go"
grep -Fq 'ImportPasswordsFromFileWithPassword' \
    "$ROOT/qml/FutoPasswordImportPage.qml"
grep -Fq 'FutoPasswordExportPage.qml' "$ROOT/packaging/Makefile"
grep -Fq 'YEKA-ZIP-LICENSE.txt' "$ROOT/packaging/Makefile"
grep -Fq 'property real draggedKeyPointerY: 0' \
    "$ROOT/qml/FutoDesktopKeysPage.qml"
grep -Fq 'contentItem.parent = page' \
    "$ROOT/qml/FutoDesktopKeysPage.qml"
grep -Fq 'draggedKeyContent.mapToItem(draggedKeyOwner, 0, 0)' \
    "$ROOT/qml/FutoDesktopKeysPage.qml"
grep -Fq 'property real draggedKeyListStartY: 0' \
    "$ROOT/qml/FutoDesktopKeysPage.qml"
grep -Fq 'var listStartY = draggedKeyListStartY' \
    "$ROOT/qml/FutoDesktopKeysPage.qml"
grep -Fq 'var rowTop = draggedKeyPointerY - draggedKeyGrabY - listStartY' \
    "$ROOT/qml/FutoDesktopKeysPage.qml"
! grep -Fq 'drag.target:' "$ROOT/qml/FutoDesktopKeysPage.qml"
! grep -Fq 'id: upButton' "$ROOT/qml/FutoDesktopKeysPage.qml"
! grep -Fq 'id: downButton' "$ROOT/qml/FutoDesktopKeysPage.qml"
grep -Fq 'anchors.left: keyBadge.left' "$ROOT/qml/FutoDesktopKeysPage.qml"
grep -Fq 'property real draggedActionPointerY: 0' \
    "$ROOT/qml/FutoQuickSettingsPage.qml"
grep -Fq 'contentItem.parent = page' \
    "$ROOT/qml/FutoQuickSettingsPage.qml"
grep -Fq 'draggedActionContent.mapToItem(draggedActionOwner, 0, 0)' \
    "$ROOT/qml/FutoQuickSettingsPage.qml"
grep -Fq 'property real draggedActionListStartY: 0' \
    "$ROOT/qml/FutoQuickSettingsPage.qml"
grep -Fq 'var listStartY = draggedActionListStartY' \
    "$ROOT/qml/FutoQuickSettingsPage.qml"
grep -Fq 'var rowTop = draggedActionPointerY - draggedActionGrabY - listStartY' \
    "$ROOT/qml/FutoQuickSettingsPage.qml"
! grep -Fq 'drag.target:' "$ROOT/qml/FutoQuickSettingsPage.qml"
! grep -Fq 'id: upButton' "$ROOT/qml/FutoQuickSettingsPage.qml"
! grep -Fq 'id: downButton' "$ROOT/qml/FutoQuickSettingsPage.qml"
grep -Fq 'anchors.left: actionIconItem.left' "$ROOT/qml/FutoQuickSettingsPage.qml"

serbian_latin_test=$(mktemp)
node "$ROOT/scripts/generate-serbian-latin-dictionary.js" \
    "$ROOT/upstream/dictionaries/sr_wordlist.combined.gz" \
    "$serbian_latin_test"
grep -Fq 'dictionary=main:sr_Latn,locale=sr_Latn,description=Srpski' \
    "$serbian_latin_test"
grep -Fq ' word=ljubav,' "$serbian_latin_test"
rm -f "$serbian_latin_test"

# Desktop/Fn page and optional extra-key row.
desktop_files=(
    layouts/FutoDesktopKey.qml
    layouts/FutoDesktopKeyData.js
    layouts/FutoDesktopKeyGrid.qml
    layouts/FutoDesktopKeyRow.qml
    layouts/FutoDesktopToolbar.qml
    layouts/FutoDesktopToolbarSide.qml
    qml/FutoDesktopKeysPage.qml
)
for desktop_file in "${desktop_files[@]}"; do
    [[ -f "$ROOT/$desktop_file" ]]
    grep -Fq "${desktop_file##*/}" "$ROOT/packaging/Makefile"
done
grep -Fq 'FutoDesktopKey.qml' \
    "$ROOT/packaging/rpm/futo-keyboard-sailfish.spec"
grep -Fq '%{_datadir}/jolla-settings/pages/futo-keyboard-sailfish/' \
    "$ROOT/packaging/rpm/futo-keyboard-sailfish.spec"
grep -Fq '? "Fn"' "$ROOT/layouts/FutoShiftKey.qml"
grep -Fq '{ "text": "Fn", "action": "desktopKeys" }' \
    "$ROOT/layouts/FutoNumpadLayout.qml"
grep -Fq 'function showDesktopKeysPage()' \
    "$ROOT/layouts/FutoQwertyLayout.qml"
grep -Fq '{ "id": "tab", "label": "Tab" }' \
    "$ROOT/layouts/FutoDesktopKeyData.js"
grep -Fq '{ "id": "tab" }' \
    "$ROOT/layouts/FutoDesktopKeyGrid.qml"
grep -Fq '{ "id": "tab" }, { "id": "f10" }, { "id": "f11" },' \
    "$ROOT/layouts/FutoDesktopKeyGrid.qml"
grep -Fq '{ "id": "numbers" }, { "id": "abc" }, { "id": "numlock" },' \
    "$ROOT/layouts/FutoDesktopKeyGrid.qml"
grep -Fq '{ "id": "ctrl" }, { "id": "super" }, { "id": "alt" },' \
    "$ROOT/layouts/FutoDesktopKeyGrid.qml"
grep -Fq '{ "id": "space", "span": 3 }, { "id": "altgr" }, { "id": "left" },' \
    "$ROOT/layouts/FutoDesktopKeyGrid.qml"
grep -Fq '{ "id": "altgr", "label": "AltGr" }' \
    "$ROOT/layouts/FutoDesktopKeyData.js"
grep -Fq 'if (keyId === "altgr") return 0x40000000' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'if (keyId === "tab") return Qt.Key_Tab' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'function toggleDesktopModifier(keyId)' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'desktopLastModifierTapMs <= 430' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'property bool desktopToolbarEnabled: false' \
    "$ROOT/layouts/FutoDesktopToolbar.qml"
grep -Fq 'actionId === "desktopkeys"' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'FutoDesktopKeysPage.qml' "$ROOT/qml/FutoAppearancePage.qml"
grep -Fq 'id: keyScroller' "$ROOT/qml/FutoDesktopKeysPage.qml"
grep -Fq 'contentHeight: Math.max(height, contentColumn.height + Theme.paddingLarge)' \
    "$ROOT/qml/FutoDesktopKeysPage.qml"
grep -Fq 'pressDelay: 140' "$ROOT/qml/FutoDesktopKeysPage.qml"
grep -Fq 'VerticalScrollDecorator { flickable: keyScroller }' \
    "$ROOT/qml/FutoDesktopKeysPage.qml"
grep -Fq 'source: "image://theme/icon-m-sailfish"' \
    "$ROOT/qml/FutoDesktopKeysPage.qml"
grep -Fq 'id: quickSettingsHoldTimer' \
    "$ROOT/layouts/FutoDesktopKey.qml"
grep -Fq 'desktopKey.targetLayout.showControlStrip()' \
    "$ROOT/layouts/FutoDesktopKey.qml"
grep -Fq 'visible: desktopKey.keyId === "numbers"' \
    "$ROOT/layouts/FutoDesktopKey.qml"
grep -Fq 'preventStealing: false' \
    "$ROOT/layouts/FutoDesktopKey.qml"
grep -Fq 'pressDelay: 140' \
    "$ROOT/layouts/FutoDesktopToolbarSide.qml"
grep -Fq 'visible: desktopKey.keyId !== "numbers" && desktopKey.keyId !== "abc"' \
    "$ROOT/layouts/FutoDesktopKey.qml"
grep -Fq 'onDesktopToolbarEnabledChanged: resizeTimer.restart()' \
    "$ROOT/layouts/FutoDesktopToolbar.qml"
grep -Fq 'id: leftOverflowFade' \
    "$ROOT/layouts/FutoDesktopToolbarSide.qml"
grep -Fq 'id: quickSettingsRightOverflowFade' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'function switchToNextSailfishKeyboard()' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'canvas.layoutModel' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'canvas.switchLayout(index)' \
    "$ROOT/qml/FutoInputHandler.qml"
! grep -Fq 'keyboard.currentIndex = index' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'onPressAndHold:' \
    "$ROOT/qml/FutoInputHandler.qml"
! grep -Fq '!targetLayout.controlMode' \
    "$ROOT/layouts/FutoDesktopToolbar.qml"
grep -Fq 'onTriggered: root.hideControlStrip()' \
    "$ROOT/layouts/FutoQwertyLayout.qml"
grep -Fq 'readonly property bool immediateCommitField: !urlField' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'function terminalInputApplication()' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'if (immediateCommitField)' "$ROOT/qml/FutoInputHandler.qml"

if [[ ! -x "$ENGINE" ]]; then
    echo "Run scripts/build.sh before scripts/test.sh" >&2
    exit 1
fi

actual=$(printf '%s\n' \
    $'CORRECT\tEN\tteh' \
    $'CORRECT\tEN\twrod' \
    $'CORRECT\tEN\trecieve' \
    $'CORRECT\tEN\twierd' \
    $'CORRECT\tEN\thelo' \
    $'CORRECT\tEN\thello' \
    $'CORRECT\tEN\tNASA' \
    $'CORRECT\tNL\tneit' \
    $'CORRECT\tTR\tmerhba' \
    $'SUGGEST\tEN\t4\tteh' \
    $'ANALYZE\tNL\t4\tneit' \
    $'TOP\tEN\t4' \
    | "$ENGINE" \
        --dictionary "EN=$ROOT/build/dictionaries/en_US.fksidx" \
        --dictionary "NL=$ROOT/build/dictionaries/nl.fksidx" \
        --dictionary "TR=$ROOT/build/dictionaries/tr.fksidx" 2>/dev/null)

expected=$(cat <<'EOF'
OK	"the"
OK	"word"
OK	"receive"
OK	""
OK	""
OK	""
OK	""
OK	"niet"
OK	"merhaba"
OK	["teh","the","ETH","Tehran"]
OK	{"known":false,"knownScore":-1,"suggestions":[{"word":"niet","score":3383996000},{"word":"net","score":1952997000},{"word":"feit","score":1943996000},{"word":"nest","score":1919996000}],"corrections":[{"word":"niet","score":204},{"word":"net","score":153},{"word":"feit","score":144},{"word":"nest","score":120},{"word":"Neil","score":101},{"word":"geit","score":101},{"word":"neigt","score":94},{"word":"Veit","score":73}],"phrases":[]}
OK	["the","to","of","and"]
EOF
)

if [[ "$actual" != "$expected" ]]; then
    printf 'Dictionary test mismatch\n--- expected ---\n%s\n--- actual ---\n%s\n' \
        "$expected" "$actual" >&2
    exit 1
fi

phrase_output=$(printf '%s\n' \
    $'ANALYZE\tEN\t8\thowareyou' \
    $'ANALYZE\tEN\t8\tim' \
    $'ANALYZE\tEN\t8\timok' \
    | "$ENGINE" --dictionary "EN=$ROOT/build/dictionaries/en_US.fksidx" 2>/dev/null)
grep -Fq '"phrases":["how are you"]' <<<"$phrase_output"
grep -Fq "\"phrases\":[\"I'm\"]" <<<"$phrase_output"
grep -Fq "\"phrases\":[\"I'm ok\"]" <<<"$phrase_output"

swipe_geometry='113:0.05:0.10;119:0.15:0.10;101:0.25:0.10;114:0.35:0.10;116:0.45:0.10;121:0.55:0.10;117:0.65:0.10;105:0.75:0.10;111:0.85:0.10;112:0.95:0.10;97:0.05:0.50;115:0.15:0.50;100:0.25:0.50;102:0.35:0.50;103:0.45:0.50;104:0.55:0.50;106:0.65:0.50;107:0.75:0.50;108:0.85:0.50;122:0.15:0.90;120:0.25:0.90;99:0.35:0.90;118:0.45:0.90;98:0.55:0.90;110:0.65:0.90;109:0.75:0.90'
swipe_output=$(printf 'SWIPE\tEN\t5\t0\t%s\t%s\nSWIPE\tEN\t5\t0\t%s\t%s\nSWIPE\tEN\t5\t0\t%s\t%s\n' \
    '119:0.15:0.10;111:0.85:0.10;114:0.35:0.10;108:0.85:0.50;100:0.25:0.50' "$swipe_geometry" \
    '104:0.55:0.50;101:0.25:0.10;108:0.85:0.50;111:0.85:0.10' "$swipe_geometry" \
    '107:0.75:0.50;101:0.25:0.10;121:0.55:0.10;98:0.55:0.90;111:0.85:0.10;97:0.05:0.50;114:0.35:0.10;100:0.25:0.50' "$swipe_geometry" \
    | "$ENGINE" --dictionary "EN=$ROOT/build/dictionaries/en_US.fksidx" 2>/dev/null)
mapfile -t swipe_lines <<<"$swipe_output"
[[ ${swipe_lines[0]} == $'OK\t[{"word":"world",'* ]]
[[ ${swipe_lines[1]} == $'OK\t[{"word":"hello",'* ]]
[[ ${swipe_lines[2]} == $'OK\t[{"word":"keyboard",'* ]]

greek_swipe_geometry='59:0.05:0.10;962:0.15:0.10;949:0.25:0.10;961:0.35:0.10;964:0.45:0.10;965:0.55:0.10;952:0.65:0.10;953:0.75:0.10;959:0.85:0.10;960:0.95:0.10;945:0.10:0.50;963:0.20:0.50;948:0.30:0.50;966:0.40:0.50;947:0.50:0.50;951:0.60:0.50;958:0.70:0.50;954:0.80:0.50;955:0.90:0.50;950:0.20:0.90;967:0.30:0.90;968:0.40:0.90;969:0.50:0.90;946:0.60:0.90;957:0.70:0.90;956:0.80:0.90'
greek_swipe_output=$(printf 'SWIPE\tEL\t5\t0\t%s\t%s\n' \
    '954:0.80:0.50;945:0.10:0.50;953:0.75:0.10' "$greek_swipe_geometry" \
    | "$ENGINE" --dictionary "EL=$ROOT/build/dictionaries/el.fksidx" 2>/dev/null)
[[ $greek_swipe_output == $'OK\t[{"word":"και",'* ]]

russian_swipe_geometry='1081:0.05:0.10;1094:0.14:0.10;1091:0.23:0.10;1082:0.32:0.10;1077:0.41:0.10;1085:0.50:0.10;1075:0.59:0.10;1096:0.68:0.10;1097:0.77:0.10;1079:0.86:0.10;1093:0.95:0.10;1092:0.05:0.50;1099:0.14:0.50;1074:0.23:0.50;1072:0.32:0.50;1087:0.41:0.50;1088:0.50:0.50;1086:0.59:0.50;1083:0.68:0.50;1076:0.77:0.50;1078:0.86:0.50;1101:0.95:0.50;1103:0.10:0.90;1095:0.20:0.90;1089:0.30:0.90;1084:0.40:0.90;1080:0.50:0.90;1090:0.60:0.90;1100:0.70:0.90;1073:0.80:0.90;1102:0.90:0.90'
russian_swipe_output=$(printf 'SWIPE\tRU\t5\t0\t%s\t%s\n' \
    '1087:0.41:0.50;1088:0.50:0.50;1080:0.50:0.90;1074:0.23:0.50;1077:0.41:0.10;1090:0.60:0.90' "$russian_swipe_geometry" \
    | "$ENGINE" --dictionary "RU=$ROOT/build/dictionaries/ru.fksidx" 2>/dev/null)
[[ $russian_swipe_output == $'OK\t[{"word":"привет",'* ]]

language_files=(
    EN=en_US.fksidx EN_GB=en_GB.fksidx NL=nl.fksidx TR=tr.fksidx
    DE=de.fksidx FR=fr.fksidx ES=es.fksidx IT=it.fksidx
    PT_BR=pt_BR.fksidx PT_PT=pt_PT.fksidx SV=sv.fksidx NB=nb.fksidx
    DA=da.fksidx FI=fi.fksidx PL=pl.fksidx CS=cs.fksidx
    RO=ro.fksidx SL=sl.fksidx HR=hr.fksidx LV=lv.fksidx LT=lt.fksidx
    EL=el.fksidx RU=ru.fksidx SR=sr.fksidx SR_LATN=sr_Latn.fksidx
)
engine_arguments=()
top_requests=()
for mapping in "${language_files[@]}"; do
    code=${mapping%%=*}
    file=${mapping#*=}
    engine_arguments+=(--dictionary "$code=$ROOT/build/dictionaries/$file")
    top_requests+=("TOP"$'\t'"$code"$'\t1')
done
all_language_output=$(printf '%s\n' "${top_requests[@]}" |
    "$ENGINE" "${engine_arguments[@]}" 2>/dev/null)
if [[ $(grep -c '^OK' <<<"$all_language_output") -ne ${#language_files[@]} ]]; then
    echo "One or more compiled language packs could not be queried" >&2
    exit 1
fi

(
    cd "$ROOT/helper"
    go test ./...
    go vet ./...
)

echo "All FUTO Keyboard tests passed"
