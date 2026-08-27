/* Organized FUTO Keyboard settings hub. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import Nemo.DBus 2.0

Page {
    id: page
    allowedOrientations: Orientation.All
    function enabledLanguageCount() {
        var raw = String(settings.enabledLanguages).split(",")
        var seen = []
        for (var i = 0; i < raw.length; ++i) {
            var code = raw[i].trim()
            if (code !== "" && seen.indexOf(code) < 0)
                seen.push(code)
        }
        return Math.max(1, seen.length)
    }

    function migrateSettings() {
        if (settings.settingsVersion < 4) {
            var migrated = []
            if (settings.languageEnglish)
                migrated.push("EN")
            if (settings.languageDutch)
                migrated.push("NL")
            if (settings.languageTurkish)
                migrated.push("TR")
            settings.enabledLanguages = migrated.length > 0 ? migrated.join(",") : "EN"
        }
        if (settings.settingsVersion < 8) {
            settings.voiceKeyVisible = settings.voiceTypingEnabled
            settings.settingsVersion = 8
        }
        if (settings.settingsVersion < 9) {
            var order = String(settings.quickSettingsOrder).split(",")
            var enabled = String(settings.quickSettingsEnabled).split(",")
            if (order.indexOf("keyboardmode") < 0) {
                var layoutPosition = order.indexOf("layouts")
                order.splice(layoutPosition >= 0 ? layoutPosition + 1 : 0,
                             0, "keyboardmode")
            }
            if (enabled.indexOf("keyboardmode") < 0)
                enabled.push("keyboardmode")
            settings.quickSettingsOrder = order.join(",")
            settings.quickSettingsEnabled = enabled.join(",")
            settings.settingsVersion = 9
        }
    }

    function resetDefaults() {
        settings.enabledLanguages = "EN,NL,TR"
        settings.automaticLanguageDetection = true
        settings.nextWordPredictionEnabled = true
        settings.predictionEnabled = true
        settings.autoCorrectionEnabled = false
        settings.correctionLevel = 0
        settings.personalLearningEnabled = true
        settings.urlHistoryEnabled = false
        settings.passwordSavingEnabled = true
        settings.autoSpaceAfterSuggestion = true
        settings.showTypedWord = true
        settings.centerPredictions = false
        settings.suggestionCount = 12
        settings.smartPunctuationEnabled = true
        settings.doubleSpacePeriodEnabled = true
        settings.autoCapitalizationEnabled = true
        settings.undoCorrectionEnabled = true
        settings.incognitoMode = false
        settings.incognitoOnPrivacySwitch = false
        settings.hideKeyPreviewsInIncognito = false
        settings.numberRowEnabled = false
        settings.symbolNumberLayout = 0
        settings.secondarySymbolsEnabled = true
        settings.separatedKeysEnabled = true
        settings.keyGapScale = 1.0
        settings.keyFontScale = 1.0
        settings.keyPreviewEnabled = true
        settings.keyboardHeightScale = 1.0
        settings.portraitKeyboardMode = 0
        settings.landscapeKeyboardMode = 0
        settings.keyboardModeVersion = 1
        settings.portraitOneHandSide = 1
        settings.landscapeOneHandSide = 1
        settings.keepVirtualWithHardwareKeyboard = false
        settings.hardwareDeadKeysEnabled = false
        settings.spacebarCursorControlEnabled = true
        settings.swipeDeleteEnabled = true
        settings.swipeTypingEnabled = true
        settings.voiceTypingEnabled = false
        settings.voiceKeyVisible = true
		settings.voicePushToTalkEnabled = false
        settings.voiceLiveTranscriptionEnabled = true
        settings.voiceStopAfterSilence = true
        settings.voiceSilenceTimeoutMs = 1300
        settings.quickSettingsOrder =
                "language,layouts,keyboardmode,clipboard,emoji,microphone,incognito,settings"
        settings.quickSettingsEnabled =
                "language,layouts,keyboardmode,clipboard,emoji,microphone,incognito,settings"
        settings.emojiLongPressEnabled = true
        settings.emojiStyle = 0
        settings.emojiSkinTone = 0
        settings.emojiSizeScale = 1.0
        settings.layoutVariant = 0
        settings.layoutAssignments = '{"EN":0,"NL":0,"TR":3}'
        settings.layoutAssignmentVersion = 1
        settings.manualLayoutAssignments = '{}'
        settings.layoutDefaultsVersion = 1
        settings.clipboardHistoryEnabled = false
        settings.clipboardRetentionSeconds = 3600
        settings.clipboardReturnAfterPaste = true
        settings.keySoundEnabled = false
        settings.keySoundVolume = 0.5
        settings.keySoundMigrationDone = true
        settings.settingsVersion = 9
        // These two settings also have native side effects outside QML.
        // Restore those immediately instead of waiting for the helper's next
        // login-time synchronization.
        helper.typedCall("SetKeepVirtualKeyboardWithHardware", [
            { "type": "b", "value": false }
        ], function(applied) {}, function() {})
        helper.typedCall("SetHardwareDeadKeys", [
            { "type": "b", "value": false }
        ], function(variant) {}, function() {})
    }

    function openPendingVaultAuthentication() {
        helper.typedCall("PendingVaultAuthentication", [], function(nonce) {
            nonce = String(nonce)
            if (nonce !== "") {
                pageStack.push(Qt.resolvedUrl("FutoPasswordVaultPage.qml"), {
                    "brokerNonce": nonce
                }, PageStackAction.Immediate)
            }
        }, function() {})
    }

    ConfigurationGroup {
        id: settings
        path: "/sailfish/text_input/futo_keyboard"
        property bool languageEnglish: true
        property bool languageDutch: true
        property bool languageTurkish: true
        property string enabledLanguages: "EN,NL,TR"
        property int settingsVersion: 0
        property bool automaticLanguageDetection: true
        property bool nextWordPredictionEnabled: true
        property bool predictionEnabled: true
        property bool autoCorrectionEnabled: false
        property int correctionLevel: 0
        property bool personalLearningEnabled: true
        property bool urlHistoryEnabled: false
        property bool passwordSavingEnabled: true
        property bool autoSpaceAfterSuggestion: true
        property bool showTypedWord: true
        property bool centerPredictions: false
        property int suggestionCount: 12
        property bool smartPunctuationEnabled: true
        property bool doubleSpacePeriodEnabled: true
        property bool autoCapitalizationEnabled: true
        property bool undoCorrectionEnabled: true
        property bool incognitoMode: false
        property bool incognitoOnPrivacySwitch: false
        property bool hideKeyPreviewsInIncognito: false
        property bool numberRowEnabled: false
        property int symbolNumberLayout: 0
        property bool secondarySymbolsEnabled: true
        property bool separatedKeysEnabled: true
        property real keyGapScale: 1.0
        property real keyFontScale: 1.0
        property bool keyPreviewEnabled: true
        property real keyboardHeightScale: 1.0
        property int portraitKeyboardMode: 0
        property int landscapeKeyboardMode: 0
        property int keyboardModeVersion: 0
        property int portraitOneHandSide: 1
        property int landscapeOneHandSide: 1
        property bool keepVirtualWithHardwareKeyboard: false
        property bool hardwareDeadKeysEnabled: false
        property bool spacebarCursorControlEnabled: true
        property bool swipeDeleteEnabled: true
        property bool swipeTypingEnabled: true
        property bool voiceTypingEnabled: false
        property bool voiceKeyVisible: true
		property bool voicePushToTalkEnabled: false
        property bool voiceLiveTranscriptionEnabled: true
        property bool voiceStopAfterSilence: true
        property int voiceSilenceTimeoutMs: 1300
        property string quickSettingsOrder:
            "language,layouts,keyboardmode,clipboard,emoji,microphone,incognito,settings"
        property string quickSettingsEnabled:
            "language,layouts,keyboardmode,clipboard,emoji,microphone,incognito,settings"
        property bool emojiLongPressEnabled: true
        property int emojiStyle: 0
        property int emojiSkinTone: 0
        property real emojiSizeScale: 1.0
        property int layoutVariant: 0
        property string layoutAssignments: "{}"
        property int layoutAssignmentVersion: 0
        property string manualLayoutAssignments: "{}"
        property int layoutDefaultsVersion: 0
        property bool clipboardHistoryEnabled: false
        property int clipboardRetentionSeconds: 3600
        property bool clipboardReturnAfterPaste: true
        property bool keySoundEnabled: false
        property real keySoundVolume: 0.5
        property bool keySoundMigrationDone: false
    }

    Component.onCompleted: {
        migrateSettings()
        pendingVaultTimer.start()
    }

    DBusInterface {
        id: helper
        bus: DBus.SessionBus
        service: "org.hb.FutoKeyboard1"
        path: "/org/hb/FutoKeyboard1"
        iface: "org.hb.FutoKeyboard1"
        watchServiceStatus: true
    }

    Timer {
        id: pendingVaultTimer
        interval: 250
        repeat: false
        onTriggered: page.openPendingVaultAuthentication()
    }

    FutoSettingsTestPanel {
        id: testPanel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        pageItem: page
    }

    SilicaFlickable {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: testPanel.top
        contentHeight: content.height + Theme.paddingLarge
        clip: true
        VerticalScrollDecorator { flickable: parent }

        Column {
            id: content
            width: parent.width
            PageHeader { title: qsTr("FUTO Keyboard") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Settings are grouped to keep this page short. The keyboard test stays "
                           + "available at the bottom of every section.")
            }

            FutoSettingsMenuItem {
                width: parent.width
                text: qsTr("Languages and layouts")
                iconSource: "image://theme/icon-m-region"
                onClicked: pageStack.push(Qt.resolvedUrl("FutoLanguagesPage.qml"))
            }

            FutoSettingsMenuItem {
                width: parent.width
                text: qsTr("Typing and predictions")
                iconSource: "image://theme/icon-m-text-input"
                onClicked: pageStack.push(Qt.resolvedUrl("FutoTypingPage.qml"))
            }

            FutoSettingsMenuItem {
                width: parent.width
                text: qsTr("Privacy and learning")
                iconSource: "image://theme/icon-m-device-lock"
                onClicked: pageStack.push(Qt.resolvedUrl("FutoPrivacyPage.qml"))
            }

            FutoSettingsMenuItem {
                width: parent.width
                text: qsTr("Appearance and keys")
                iconSource: "image://theme/icon-m-font-size"
                onClicked: pageStack.push(Qt.resolvedUrl("FutoAppearancePage.qml"))
            }

            FutoSettingsMenuItem {
                width: parent.width
                text: qsTr("Typing gestures")
                iconSource: "image://theme/icon-m-gesture"
                onClicked: pageStack.push(Qt.resolvedUrl("FutoGesturesPage.qml"))
            }

            FutoSettingsMenuItem {
                width: parent.width
                text: qsTr("Voice typing")
                iconSource: "image://theme/icon-m-browser-microphone"
                onClicked: pageStack.push(Qt.resolvedUrl("FutoVoicePage.qml"))
            }

            FutoSettingsMenuItem {
                width: parent.width
                text: qsTr("Downloadable content")
                iconSource: "image://theme/icon-m-downloads"
                onClicked: pageStack.push(Qt.resolvedUrl("FutoContentPage.qml"))
            }

            FutoSettingsMenuItem {
                width: parent.width
                text: qsTr("Quick settings")
                iconSource: "image://theme/icon-m-setting"
                onClicked: pageStack.push(Qt.resolvedUrl("FutoQuickSettingsPage.qml"))
            }

            FutoSettingsMenuItem {
                width: parent.width
                text: qsTr("Emoji")
                iconSource: "file:///usr/share/futo-keyboard-sailfish/icons/icon-m-emoji.svg"
                onClicked: pageStack.push(Qt.resolvedUrl("FutoEmojiSettingsPage.qml"))
            }

            FutoSettingsMenuItem {
                width: parent.width
                text: qsTr("Clipboard")
                iconSource: "image://theme/icon-m-clipboard"
                // The theme clipboard glyph has more transparent padding than
                // the other menu artwork, so compensate without moving text.
                iconScale: 1.18
                onClicked: pageStack.push(Qt.resolvedUrl("FutoClipboardSettingsPage.qml"))
            }

            FutoSettingsMenuItem {
                width: parent.width
                text: qsTr("Sound and vibration")
                iconSource: "image://theme/icon-m-vibration"
                onClicked: pageStack.push(Qt.resolvedUrl("FutoFeedbackPage.qml"))
            }

            FutoSettingsMenuItem {
                width: parent.width
                text: qsTr("Maintenance")
                iconSource: "image://theme/icon-m-reset"
                onClicked: pageStack.push(Qt.resolvedUrl("FutoMaintenancePage.qml"), {
                    settingsPage: page
                })
            }

            FutoSettingsMenuItem {
                width: parent.width
                text: qsTr("About")
                iconSource: "image://theme/icon-m-about"
                onClicked: pageStack.push(Qt.resolvedUrl("FutoAboutPage.qml"))
            }
        }
    }
}
