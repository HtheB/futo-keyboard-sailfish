#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ENGINE="$ROOT/build/futo-dictionary-compiler"

node --check < "$ROOT/packaging/polkit/49-futo-keyboard-secrets.rules"
node "$ROOT/scripts/check-symbol-data.js"
echo '8decb0be8598af58ce4f3d38862da6387b99acee44626963f2363b8ec54f4f79  assets/fonts/FutoAndroidRiyal-Regular.ttf' |
    (cd "$ROOT" && sha256sum -c -)
echo 'c9a039ce48a477243c1eb7d561b13de115cfd651d8a83fa42e2f4d63c2e11b00  assets/fonts/NotoNaskhArabic-Regular.ttf' |
    (cd "$ROOT" && sha256sum -c -)
echo 'cd2550c0f4c05eb341bf97958211aaa39382bca96577ba3a67d4a3b4912c43c0  assets/fonts/Amiri-Regular.ttf' |
    (cd "$ROOT" && sha256sum -c -)
echo '7a0bd8b0481d3995196cf5161a1a290fd05ec23f3b5dafb47c06cc8acc832b93  assets/fonts/AmiriSailfishCompactRial-Regular.ttf' |
    (cd "$ROOT" && sha256sum -c -)
# Sailfish carries no Tibetan glyphs, so the Tibetan layout draws nothing
# without this face, exactly as Myanmar and Khmer did before theirs.
echo 'd334dd7823b53b41f9c14678971772ebce334b5f92c5bd7024454f75b3b47b17  assets/fonts/NotoSerifTibetan-Light.ttf' |
    (cd "$ROOT" && sha256sum -c -)
grep -Fq 'NotoSerifTibetan-Light.ttf' "$ROOT/packaging/Makefile"
# The About page states the version in its own words. It drifted silently
# through a release once; make a mismatch with the package a build failure.
spec_version=$(grep '^Version:' "$ROOT/packaging/rpm/futo-keyboard-sailfish.spec" |
    head -1 | awk '{print $2}')
about_version=$(grep -o 'keyboardVersion: "[^"]*"' "$ROOT/qml/FutoAboutPage.qml" |
    head -1 | cut -d'"' -f2)
if [ -z "$about_version" ] || [ "$spec_version" != "$about_version" ]; then
    echo "About page says '$about_version' but the package is '$spec_version'" >&2
    exit 1
fi
# Romanian's upstream list is dominated by its lowest frequency tier, which the
# engine would otherwise hold in memory for no benefit.
grep -Fq 'DICTIONARY_DROP_LOWEST=( [ro]=1 )' "$ROOT/scripts/build.sh"
grep -Fq "grep -v ',f=1,'" "$ROOT/scripts/build.sh"
# A rebuilt pack must carry a new version in both places, or the archive named
# by the manifest is not the archive the builder writes.
grep -Fq '[dictionary-ro]=0.4.2-2' "$ROOT/scripts/build-content-packs.sh"
grep -Fq '"dictionary-ro": "0.4.2-2"' "$ROOT/scripts/generate-content-manifest.js"
grep -Fq 'func (manager *contentManager) installedVersion(' \
    "$ROOT/helper/cmd/futo-keyboard-helper/content.go"
# A loaded dictionary costs its text plus one fixed record per word. Three
# allocations per word used to cost more than the spellings themselves.
grep -Fq 'uint32_t displayOffset;' "$ROOT/engine/futo_engine.cpp"
grep -Fq 'void appendEntry(' "$ROOT/engine/futo_engine.cpp"
if grep -q 'std::unordered_map<std::u32string, const Entry \*>' \
        "$ROOT/engine/futo_engine.cpp"; then
    echo "the exact-match index must not hold a second copy of every word" >&2
    exit 1
fi
# The compiled format is unchanged, so every published dictionary pack stays
# valid. Recompiling one must reproduce the file already shipped.
compiled_before=$(sha256sum "$ROOT/build/dictionaries/nl.fksidx" | cut -d' ' -f1)
"$ENGINE" --compile "$ROOT/build/dictionaries/nl.fksidx" \
    "$ROOT/build/dictionaries/nl.roundtrip.tmp" >/dev/null
compiled_after=$(sha256sum "$ROOT/build/dictionaries/nl.roundtrip.tmp" | cut -d' ' -f1)
rm -f "$ROOT/build/dictionaries/nl.roundtrip.tmp"
if [ "$compiled_before" != "$compiled_after" ]; then
    echo "recompiling a dictionary changed it; published packs would not match" >&2
    exit 1
fi
grep -Fq 'layoutScript === "tibetan"' "$ROOT/layouts/FutoQwertyLayout.qml"
grep -Fq '0x0F00 && codepoint <= 0x0FFF' "$ROOT/layouts/FutoCharacterKey.qml"
grep -Fq '0xFDFC' "$ROOT/scripts/build-android-riyal-font.py"
grep -Fq 'RIAL_CODEPOINT = 0xFDFC' "$ROOT/scripts/build-amiri-riyal-font.py"
grep -Fq '65-futo-keyboard-symbols.conf' "$ROOT/packaging/Makefile"
node "$ROOT/scripts/check-generated-layouts.js"
node "$ROOT/scripts/check-punctuation-spacing.js"
node "$ROOT/scripts/check-symbol-popups.js"
node "$ROOT/scripts/check-qwerty-alternates.js"
node - "$ROOT/layouts/FutoLetterLayouts.js" <<'NODE'
const fs = require("fs")
const vm = require("vm")
const file = process.argv[2]
const directory = require("path").dirname(file)
function dataVariable(name, variable) {
    const source = fs.readFileSync(require("path").join(directory, name), "utf8")
        .replace(/^\.pragma library\s*/m, "")
    const context = {}
    vm.createContext(context)
    vm.runInContext(source, context, { filename: name })
    return context[variable]
}
const source = fs.readFileSync(file, "utf8")
    .replace(/^\.pragma library\s*/m, "")
    .replace(/^\.import .*$/gm, "")
const layoutData = {
    Generated: {
        layouts: dataVariable("FutoGeneratedLayouts.js", "layouts"),
        languageLayoutIds: dataVariable("FutoGeneratedLayouts.js", "languageLayoutIds"),
        languageAlternatives: dataVariable("FutoGeneratedLayouts.js", "languageAlternatives")
    },
    Catalogue: { languages: dataVariable("FutoLanguageCatalogue.js", "languages") }
}
vm.createContext(layoutData)
vm.runInContext(source, layoutData, { filename: file })

function assert(condition, message) {
    if (!condition)
        throw new Error(message)
}

assert(layoutData.legacyLayoutCount === 21, "persisted layout indices changed")
assert(layoutData.layouts.length === 118, "generated FUTO layouts missing")
assert(layoutData.layouts.some(layout => layout.name === "QWERTY"),
       "the established SwiftKey-style QWERTY entry must exist")
assert(layoutData.layouts.filter(layout => layout.name === "QWERTY").length >= 2,
       "the exact FUTO QWERTY entry must exist")
assert(layoutData.letter(2, 2, 6) === "'", "AZERTY does not match FUTO")
assert(layoutData.letter(13, 2, 0) === "ذ", "Arabic row is incomplete")
assert(layoutData.letter(19, 2, 0) === "ѕ"
       && layoutData.letter(19, 2, 7) === "ђ",
       "Serbian Cyrillic does not match FUTO South Slavic")
assert(layoutData.letter(20, 2, 2) === "ژ", "Persian row is incomplete")
assert(layoutData.shifted("ς", 14) === "ς", "Greek final sigma must not shift")
assert(layoutData.alternatives(15, "е", "RU", false) === "ё",
       "Russian ё alternative is missing")
assert(layoutData.alternatives(15, "ь", "RU", false) === "ъ",
       "Russian ъ alternative is missing")
assert(layoutData.alternatives(17, "d", "SL", false) === "đ",
       "Slovenian đ alternative is missing")
assert(layoutData.alternatives(0, "a", "PL", false).indexOf("ą") >= 0,
       "Polish QWERTY alternative is missing")
assert(layoutData.alternatives(0, "e", "NL+FR", false) === "éëêè",
       "same-layout language alternatives are not merged deterministically")
assert(layoutData.secondarySymbols[0].slice(0, 10).join("") === "1234567890",
       "QWERTY number shortcuts do not match the reference")
assert(layoutData.secondarySymbols[1].slice(0, 9).join("") === "@#&*-+=()",
       "QWERTY middle-row shortcuts do not match the reference")
assert(layoutData.secondarySymbols[2].slice(0, 7).join("") === "_€\"':;/",
       "QWERTY bottom-row shortcuts do not match the reference")
for (let layoutIndex = 0; layoutIndex < layoutData.legacyLayoutCount; ++layoutIndex) {
    const seen = new Set()
    const rows = layoutData.layouts[layoutIndex].rows
    for (let row = 0; row < rows.length; ++row) {
        for (let column = 0; column < rows[row].length; ++column) {
            const symbol = layoutData.secondarySymbol(row, column)
            assert(symbol !== "", "missing secondary shortcut")
            assert(!seen.has(symbol),
                   layoutData.layouts[layoutIndex].name
                   + " repeats secondary shortcut " + symbol)
            seen.add(symbol)
        }
    }
}
NODE
if [[ -x "$ROOT/build/host-swipe/futo-keyboard-swipe" \
        && -s "$ROOT/swipe/models/honorable_sturgeon/model_fp32.pte" ]]; then
    node "$ROOT/scripts/test-futo-swipe.js"
else
    printf 'Skipping optional FUTO Swipe model smoke test (host worker/model unavailable).\n'
fi
test -s "$ROOT/dictionaries/hu_wordlist.combined.gz"
gzip -t "$ROOT/dictionaries/hu_wordlist.combined.gz"
echo '4f597b3c05346521c3f1cf8e9a8a5def8f75e0fa0351be6cf4fc42a2c68c3f53  dictionaries/hu_wordlist.combined.gz' |
    (cd "$ROOT" && sha256sum -c -)
gzip -dc "$ROOT/dictionaries/hu_wordlist.combined.gz" | sed -n '1p' |
    grep -Fq 'dictionary=main:hu,locale=hu,description=Magyar'
grep -Fq '525f9b560de45753a5ea01069454e72e9aa541c6' \
    "$ROOT/dictionaries/README.md"
grep -Fq 'Creative Commons Attribution-ShareAlike 4.0 International' \
    "$ROOT/LICENSES/HUNGARIAN-DICTIONARY-ATTRIBUTION.md"
grep -Fq 'LICENSES/HUNGARIAN-DICTIONARY-ATTRIBUTION.md' \
    "$ROOT/packaging/Makefile"
grep -Fq '%license %{_licensedir}/%{name}/HUNGARIAN-DICTIONARY-ATTRIBUTION.md' \
    "$ROOT/packaging/rpm/futo-keyboard-sailfish.spec"
test -s "$ROOT/dictionaries/fa_wordlist.combined.gz"
gzip -t "$ROOT/dictionaries/fa_wordlist.combined.gz"
echo '4c47a8410f2a5fdeb057d01859f252159446fcdaa228bea535a6f85264f93a49  dictionaries/fa_wordlist.combined.gz' |
    (cd "$ROOT" && sha256sum -c -)
gzip -dc "$ROOT/dictionaries/fa_wordlist.combined.gz" | sed -n '1p' |
    grep -Fq 'dictionary=main:fa,locale=fa_IR,description=فارسی'
grep -Fq '8cfea406b505e4d7df52d5a19bce525df98c54ab' \
    "$ROOT/dictionaries/README.md"
grep -Fq 'LICENSES/PERSIAN-DICTIONARY-ATTRIBUTION.md' \
    "$ROOT/packaging/Makefile"
grep -Fq '%license %{_licensedir}/%{name}/PERSIAN-DICTIONARY-ATTRIBUTION.md' \
    "$ROOT/packaging/rpm/futo-keyboard-sailfish.spec"
grep -Fq 'QLibraryInfo::location(QLibraryInfo::PluginsPath)' \
    "$ROOT/hardware/compose/futo_maliit_compose_wrapper.cpp"
! grep -Fq '/usr/lib64/qt5/plugins/platforminputcontexts' \
    "$ROOT/hardware/compose/futo_maliit_compose_wrapper.cpp"
grep -Fq 'm_maliitLoader.errorString()' \
    "$ROOT/hardware/compose/futo_maliit_compose_wrapper.cpp"
grep -Fq 'property string manualPredictionLanguage: ""' \
    "$ROOT/layouts/FutoQwertyLayout.qml"
grep -Fq 'property int languageSwitchCount:' \
    "$ROOT/layouts/FutoQwertyLayout.qml"
grep -Fq 'layoutSettings.manualPredictionLanguage = nextLanguage' \
    "$ROOT/layouts/FutoQwertyLayout.qml"
grep -Fq 'keyboard.layout.languageSwitchCount' \
    "$ROOT/qml/FutoInputHandler.qml"
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
grep -Fq 'word string, leadingSpace bool' \
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
grep -Fq 'setKeySoundMode((effectiveKeySoundMode() + 1) % 3)' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'actionId === "sound"' "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'keyboardLayout.beginControlInteraction()' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'function endControlInteraction()' \
    "$ROOT/layouts/FutoQwertyLayout.qml"
grep -Fq 'settings.settingsVersion = 11' "$ROOT/qml/FutoSettingsPage.qml"
grep -Fq 'settingsUi.call("showPage"' "$ROOT/qml/FutoInputHandler.qml"
! sed -n '/function openFutoSettings()/,/^    }/p' \
    "$ROOT/qml/FutoInputHandler.qml" | grep -Fq 'userHide()'
grep -Fq 'function moveCursor2D(horizontalSteps, verticalSteps)' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'Qt.Key_Up : Qt.Key_Down' "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'keyboard.inputHandler.beginCursorMoveMode()' \
    "$ROOT/layouts/FutoSpacebarKey.qml"
grep -Fq 'if (!pointerDown || cursorMode || languageMode || keyboardDismissed)' \
    "$ROOT/layouts/FutoSpacebarKey.qml"
# Holding Space either chooses a language or moves the cursor, never both,
# and the key says which by the mark it draws in its corner.
grep -Fq 'function languageSwitchEntries()' "$ROOT/layouts/FutoQwertyLayout.qml"
grep -Fq 'function applyLanguageSwitchIndex(index)' "$ROOT/layouts/FutoQwertyLayout.qml"
grep -Fq 'readonly property bool onLetterPage: !attributes.inSymView' \
    "$ROOT/layouts/FutoSpacebarKey.qml"
grep -Fq 'spaceKey.finishLanguageMode(!spaceKey.languageAbandoned)' \
    "$ROOT/layouts/FutoSpacebarKey.qml"
grep -Fq 'label: qsTr("Hold Space")' "$ROOT/qml/FutoGesturesPage.qml"
grep -Fq 'MenuItem { text: qsTr("Switch language") }' "$ROOT/qml/FutoGesturesPage.qml"
grep -Fq 'property int spacebarHoldAction: -1' "$ROOT/qml/FutoSettingsPage.qml"
# The 123 and {&= pages keep the cursor pad whatever the setting says.
grep -Fq 'readonly property bool cursorControlOffered: !onLetterPage || holdAction === 1' \
    "$ROOT/layouts/FutoSpacebarKey.qml"
# A stored value below zero predates the setting and still means what
# the old on/off switch meant.
grep -Fq 'gestureSettings.spacebarCursorControlEnabled ? 1 : 0' \
    "$ROOT/layouts/FutoSpacebarKey.qml"
grep -Fq 'spaceKey.pointerDown = false' \
    "$ROOT/layouts/FutoSpacebarKey.qml"
! sed -n '/function beginCursorMoveMode()/,/^\t}/p' \
    "$ROOT/qml/FutoInputHandler.qml" | grep -Fq 'beginSpacebarGesture()'
grep -Fq 'Math.max(Theme.itemSizeLarge, height * 1.6)' \
    "$ROOT/layouts/FutoSpacebarKey.qml"
grep -Fq 'opacity: root.cursorMoveMode ? 0 : 1' \
    "$ROOT/layouts/FutoQwertyLayout.qml"
grep -Fq 'opacity: targetLayout && targetLayout.cursorMoveMode ? 0 : 1' \
    "$ROOT/layouts/FutoNumpadLayout.qml"
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
grep -Fq 'usesPersianDigits ? "۰۱۲۳۴۵۶۷۸۹" : "٠١٢٣٤٥٦٧٨٩"' \
    "$ROOT/layouts/FutoQwertyLayout.qml"
grep -Fq 'case "١": return "1½¼¹⅛⅓"' \
    "$ROOT/layouts/FutoCharacterKey.qml"
grep -Fq 'case "۱": return "1½¼¹⅛⅓"' \
    "$ROOT/layouts/FutoCharacterKey.qml"
grep -Fq 'localizedAlternatives ? localizedDigits.charAt(1)' \
    "$ROOT/layouts/FutoCharacterKey.qml"
grep -Fq 'insertWordCharacter("\u200c")' "$ROOT/layouts/FutoShiftKey.qml"
grep -Fq 'character === "\u200c"' "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'argv[i] === "--search-only"' \
    "$ROOT/scripts/generate-full-emoji-set.js"
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
grep -Fq 'cacheBuffer: Math.ceil(cellHeight * 8)' "$ROOT/layouts/FutoEmojiGrid.qml"
grep -Fq 'emojiTabAssetPath(index)' "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'EMOJI_TAB_CODEPOINTS :=' "$ROOT/packaging/Makefile"
grep -Fq '1f550 1f600 1f44b 1f43b 1f354 1f697 26bd 1f4a1 2764 1f3f3' \
    "$ROOT/scripts/build-rpm.sh"
grep -Fq 'asynchronous: true' "$ROOT/layouts/FutoEmojiKey.qml"
grep -Fq 'cache: false' "$ROOT/layouts/FutoEmojiKey.qml"
grep -Fq 'source: "FutoEmojiPanel.qml"' "$ROOT/layouts/FutoQwertyLayout.qml"
! grep -Fq 'import "FutoEmojiData.js"' "$ROOT/layouts/FutoQwertyLayout.qml"
grep -Fq 'import "FutoEmojiData.js"' "$ROOT/layouts/FutoEmojiPanel.qml"
! grep -Fq 'FutoEmojiSearchData.js' "$ROOT/layouts/FutoEmojiPanel.qml"
grep -Fq 'SearchEmoji' "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'emoji-search-index.json.gz' "$ROOT/packaging/Makefile"
test -s "$ROOT/layouts/FutoEmojiSearchData.json.gz"
grep -Fq 'layouts/FutoEmojiPanel.qml' "$ROOT/packaging/Makefile"
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
grep -Fq 'function serializedSwipeTrace(startKey, endKey)' \
    "$ROOT/layouts/FutoKeyboardLayout.qml"
grep -Fq 'property var decoderPoints: []' \
    "$ROOT/layouts/FutoKeyboardLayout.qml"
grep -Fq 'keyboard.layout.serializedSwipeTrace(' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'helper.typedCall("AcceptSwipeCorrection"' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'property bool mergeSameLayoutLanguages: true' \
    "$ROOT/layouts/FutoQwertyLayout.qml"
grep -Fq 'Combine languages that use the same layout' \
    "$ROOT/qml/FutoLanguagesPage.qml"
grep -Fq 'readonly property real numberRowHeightScale: 1.0' \
    "$ROOT/layouts/FutoQwertyLayout.qml"
! grep -Fq 'sendCommit(word + " ")' "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'property bool swipeTypingEnabled: false' \
    "$ROOT/qml/FutoGesturesPage.qml"
grep -Fq 'function refreshSwipeContentStatus()' \
    "$ROOT/qml/FutoInputHandler.qml"
# One pulse per touch, and never by reaching into the system setting: the
# keyboard silences the platform's own effect for the rest of the touch
# instead, which is why the settings application no longer sees the
# vibration option flickering while a word is swiped.
grep -Fq 'buttonPressEffect.effect = pressEffectNone' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'function restorePressEffect()' \
    "$ROOT/qml/FutoInputHandler.qml"
if grep -q 'touchscreenVibrationLevel *=' \
        "$ROOT/qml/FutoInputHandler.qml"; then
    echo "the input handler must not write the system vibration level" >&2
    exit 1
fi
# Whoever prefers a pulse on every letter a swipe crosses can keep the
# platform effect live; the switch that does it lives beside the other
# vibration setting.
grep -Fq 'if (!keyboardSettings.swipeVibrationEnabled)' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'property bool swipeVibrationEnabled: false' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'Vibrate while swiping' "$ROOT/qml/FutoFeedbackPage.qml"
# The period key sits in the row with Comma, Space and Enter, none of which
# draw a separated-key card.
grep -Fq 'separatedKeyCardEligible: false' "$ROOT/layouts/FutoPeriodKey.qml"
grep -Fq '&& futoKey.separatedKeyCardEligible' \
    "$ROOT/layouts/FutoCharacterKey.qml"
grep -Fq 'function visiblePrimaryCorrection()' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq '"primary": primary !== ""' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'var visibleCorrection = visiblePrimaryCorrection()' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'readonly property bool primarySuggestion: model.primary === true' \
    "$ROOT/qml/FutoHorizontalPredictionListView.qml"
grep -Fq 'readonly property bool primarySuggestion: model.primary === true' \
    "$ROOT/qml/FutoVerticalPredictionListView.qml"
grep -Fq 'MenuItem { text: qsTr("System default") }' \
    "$ROOT/qml/FutoFeedbackPage.qml"
! grep -Fq 'Follow Sailfish sound settings' "$ROOT/qml/FutoFeedbackPage.qml"
grep -Fq 'helper.typedCall("GetKeySoundMode"' \
    "$ROOT/qml/FutoFeedbackPage.qml"
grep -Fq 'Name: keySoundModeChangedSignal' \
    "$ROOT/helper/cmd/futo-keyboard-helper/main.go"
grep -Fq 'function keySoundActive()' "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'function systemKeySoundActive()' "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'systemFeedback.profile' "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'systemFeedback.ringerVolume' "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'Sailfish key tones and Silent mode' "$ROOT/qml/FutoFeedbackPage.qml"
grep -Fq 'function emojiStylePreviewSource(styleIndex, codepoint)' \
    "$ROOT/qml/FutoEmojiSettingsPage.qml"
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
grep -Fq 'readonly property bool passwordClipboardPasteVisible:' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'futoHandler.passwordField && Clipboard.hasText' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'id: passwordClipboardPasteButton' \
    "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'futoHandler.paste(Clipboard.text)' \
    "$ROOT/qml/FutoInputHandler.qml"
test -s "$ROOT/qml/FutoPasteButton.qml"
grep -Fq 'property bool clearMode: false' "$ROOT/qml/FutoPasteButton.qml"
grep -Fq 'Clipboard.text = ""' "$ROOT/qml/FutoPasteButton.qml"
grep -Fq 'interval: 3000' "$ROOT/qml/FutoPasteButton.qml"
grep -Fq 'FutoPasteButton {' "$ROOT/qml/FutoHorizontalPredictionListView.qml"
grep -Fq 'FutoPasteButton {' "$ROOT/qml/FutoVerticalPredictionListView.qml"
grep -Fq 'FutoPasteButton {' "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'qml/FutoPasteButton.qml' "$ROOT/packaging/Makefile"
grep -Fq '%{_datadir}/maliit/plugins/com/jolla/FutoPasteButton.qml' \
    "$ROOT/packaging/rpm/futo-keyboard-sailfish.spec"
grep -Fq '%{_datadir}/maliit/plugins/com/jolla/handlers/FutoPasteButton.qml' \
    "$ROOT/packaging/rpm/futo-keyboard-sailfish.spec"

# Public builds must be reproducible without the maintainer's private staging
# directories. Keep the documented setup, pinned source inputs and configurable
# host build directory covered by the regular test suite.
test -s "$ROOT/BUILDING.md"
grep -Fq '[BUILDING.md](BUILDING.md)' "$ROOT/README.md"
grep -Fq 'scripts/prepare-build-environment.sh' "$ROOT/BUILDING.md"
grep -Fq 'libmpc3' "$ROOT/BUILDING.md"
grep -Fq -- '--toolchain-lib-dir' "$ROOT/BUILDING.md"
grep -Fq -- '--xkb-include-root' "$ROOT/BUILDING.md"
grep -Fq 'compiler_smoke_test' "$ROOT/scripts/check-build-environment.sh"
grep -Fq -- '-c -o "$object_file"' "$ROOT/scripts/check-build-environment.sh"
grep -Fq 'install the libmpc3 package' "$ROOT/scripts/check-build-environment.sh"
grep -Fq '2379f234259c87ac87b7518243cc75c0bb6b8430d6c9f20d36052f4ad33bef1a' \
    "$ROOT/scripts/prepare-build-environment.sh"
grep -Fq 'aa1c07b1e8af5a692616160a48ac35114272e5efa2c3d106127ee3714c41ffe1' \
    "$ROOT/scripts/prepare-build-environment.sh"
grep -Fq 'FUTO_TOOLCHAIN_LIB_DIR' "$ROOT/scripts/prepare-build-environment.sh"
grep -Fq 'FUTO_TOOLCHAIN_SHIM' "$ROOT/scripts/prepare-build-environment.sh"
grep -Fq 'FUTO_XKBCOMMON_INCLUDE_ROOT' "$ROOT/scripts/prepare-build-environment.sh"
grep -Fq 'deb569c4a7c30b43e0ace19bbcc5d9f9f11803b7751ca9a9f134eabe4ce0fa7e' \
    "$ROOT/scripts/build-wayland-deadkey-hook.sh"
grep -Fq 'HOST_BUILD=${FUTO_HOST_BUILD_DIR:-$ROOT/build}' \
    "$ROOT/scripts/bootstrap-compose-moc.sh"
! grep -Fq 'futo-phone-sysroot' "$ROOT/scripts/build.sh" \
    "$ROOT/scripts/build-compose-plugin.sh" \
    "$ROOT/scripts/build-wayland-deadkey-hook.sh"
! git -C "$ROOT" grep -I -E \
    '([A-Za-z]:|/mnt/[a-z])[/\\]Users[/\\][^/\\]+|defaultuser@[0-9]+\.[0-9]+' -- . \
    ':(exclude)scripts/test.sh'

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

short_swipe_output=$(printf 'SWIPE\tEN\t5\t0\t%s\t%s\n' \
    '97:0.05:0.50;115:0.15:0.50' "$swipe_geometry" \
    | "$ENGINE" --dictionary "EN=$ROOT/build/dictionaries/en_US.fksidx" 2>/dev/null)
[[ $short_swipe_output == $'OK\t[{"word":"as",'* ]]

# Dedicated German rows must retain their distinct umlaut key centres. Folding
# Ü/Ö/Ä onto U/O/A used to overwrite the base centres and made even an ideal
# "auto" gesture fail while unrelated long words could rank first.
german_swipe_geometry='113:0.04545:0.10000;119:0.13636:0.10000;101:0.22727:0.10000;114:0.31818:0.10000;116:0.40909:0.10000;122:0.50000:0.10000;117:0.59091:0.10000;105:0.68182:0.10000;111:0.77273:0.10000;112:0.86364:0.10000;252:0.95455:0.10000;97:0.04545:0.50000;115:0.13636:0.50000;100:0.22727:0.50000;102:0.31818:0.50000;103:0.40909:0.50000;104:0.50000:0.50000;106:0.59091:0.50000;107:0.68182:0.50000;108:0.77273:0.50000;246:0.86364:0.50000;228:0.95455:0.50000;121:0.07143:0.90000;120:0.21429:0.90000;99:0.35714:0.90000;118:0.50000:0.90000;98:0.64286:0.90000;110:0.78571:0.90000;109:0.92857:0.90000'
german_swipe_output=$(printf 'SWIPE\tDE\t5\t0\t%s\t%s\nSWIPE\tDE\t5\t0\t%s\t%s\n' \
    '97:0.04545:0.50000;117:0.59091:0.10000;116:0.40909:0.10000;111:0.77273:0.10000' "$german_swipe_geometry" \
    '100:0.22727:0.50000;97:0.04545:0.50000;110:0.78571:0.90000;107:0.68182:0.50000;101:0.22727:0.10000' "$german_swipe_geometry" \
    | "$ENGINE" --dictionary "DE=$ROOT/build/dictionaries/de.fksidx" 2>/dev/null)
mapfile -t german_swipe_lines <<<"$german_swipe_output"
[[ ${german_swipe_lines[0]} == $'OK\t[{"word":"auto",'* ]]
[[ ${german_swipe_lines[1]} == $'OK\t[{"word":"danke",'* ]]

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

russian_capital_swipe_output=$(printf 'SWIPE\tRU\t5\t1\t%s\t%s\n' \
    '1087:0.41:0.50;1088:0.50:0.50;1080:0.50:0.90;1074:0.23:0.50;1077:0.41:0.10;1090:0.60:0.90' "$russian_swipe_geometry" \
    | "$ENGINE" --dictionary "RU=$ROOT/build/dictionaries/ru.fksidx" 2>/dev/null)
[[ $russian_capital_swipe_output == $'OK\t[{"word":"Привет",'* ]]

hungarian_output=$(printf '%s\n' \
    $'SUGGEST\tHU\t8\tszia' \
    $'ANALYZE\tHU\t8\tmagyr' \
    | "$ENGINE" --dictionary "HU=$ROOT/build/dictionaries/hu.fksidx" 2>/dev/null)
grep -Fq $'OK\t["szia","Szia","sziasztok"' <<<"$hungarian_output"
grep -Fq '"corrections":[{"word":"magyar"' <<<"$hungarian_output"

persian_output=$(printf '%s\n' \
    $'SUGGEST\tFA\t8\tسلا' \
    $'ANALYZE\tFA\t8\tسلام' \
    | "$ENGINE" --dictionary "FA=$ROOT/build/dictionaries/fa.fksidx" 2>/dev/null)
grep -Fq $'OK\t["سلا","سال","سلام"' <<<"$persian_output"
grep -Fq '"known":true' <<<"$persian_output"

language_files=(
    EN=en_US.fksidx EN_GB=en_GB.fksidx NL=nl.fksidx TR=tr.fksidx
    DE=de.fksidx FR=fr.fksidx ES=es.fksidx IT=it.fksidx
    PT_BR=pt_BR.fksidx PT_PT=pt_PT.fksidx SV=sv.fksidx NB=nb.fksidx
    DA=da.fksidx FI=fi.fksidx PL=pl.fksidx CS=cs.fksidx
    RO=ro.fksidx SL=sl.fksidx HR=hr.fksidx HU=hu.fksidx LV=lv.fksidx LT=lt.fksidx
    EL=el.fksidx RU=ru.fksidx SR=sr.fksidx SR_LATN=sr_Latn.fksidx
    AR=ar.fksidx FA=fa.fksidx
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

# The Sailfish edition deliberately does not offer Hebrew. Keep generated or
# cached upstream artifacts from silently becoming a downloadable content pack.
! grep -Eqi 'dictionary-(he|iw)|iw\.fksidx|Hebrew' "$ROOT/content/manifest.json"
! grep -Eq '(^|[[:space:]])(he|iw)([[:space:]]|$)' "$ROOT/layouts/FutoLanguageData.js"

(
    cd "$ROOT/helper"
    go test ./...
    go vet ./...
)

echo "All FUTO Keyboard tests passed"
