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
grep -Fq 'credentialAutofillStage === 0' "$ROOT/qml/FutoInputHandler.qml"
grep -Fq 'Authenticator.Fingerprint' "$ROOT/qml/FutoDeviceAuthentication.qml"
grep -Fq 'FutoDeviceLockInputPage.qml' "$ROOT/qml/FutoDeviceAuthentication.qml"
grep -Fq 'if (settings.personalDictionaryProtected)' "$ROOT/qml/FutoPrivacyPage.qml"
grep -Fq 'InitializeLearnedEncryption' "$ROOT/qml/FutoLearnedDataPage.qml"
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

language_files=(
    EN=en_US.fksidx EN_GB=en_GB.fksidx NL=nl.fksidx TR=tr.fksidx
    DE=de.fksidx FR=fr.fksidx ES=es.fksidx IT=it.fksidx
    PT_BR=pt_BR.fksidx PT_PT=pt_PT.fksidx SV=sv.fksidx NB=nb.fksidx
    DA=da.fksidx FI=fi.fksidx PL=pl.fksidx CS=cs.fksidx
    RO=ro.fksidx SL=sl.fksidx HR=hr.fksidx LV=lv.fksidx LT=lt.fksidx
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
