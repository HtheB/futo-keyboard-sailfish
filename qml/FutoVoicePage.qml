import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import Nemo.DBus 2.0

Page {
    id: page
    allowedOrientations: Orientation.All
    property bool voiceContentReady: false
    property bool voiceModelInstalled: false
    property bool pendingVoiceDownloads: false

    onStatusChanged: {
        if (status === PageStatus.Active && pendingVoiceDownloads
                && !voiceDownloadNavigation.running)
            voiceDownloadNavigation.start()
    }

    Timer {
        id: voiceDownloadNavigation
        interval: 1
        repeat: false
        onTriggered: {
            page.pendingVoiceDownloads = false
            pageStack.push(Qt.resolvedUrl("FutoContentListPage.qml"), {
                "packKind": "voice",
                "pageTitle": qsTr("Offline voice"),
                "requestedPackId": "voice-multilingual-39"
            })
        }
    }

    function refreshVoiceContent() {
        if (helper.status !== DBusInterface.Available)
            return
        helper.typedCall("ContentStatus", [], function(resultJson) {
            var result
            try {
                result = JSON.parse(String(resultJson))
            } catch (error) {
                return
            }
            var installed = false
            var items = result.items || []
            for (var i = 0; i < items.length; ++i) {
                if (String(items[i].id) === "voice-multilingual-39") {
                    installed = !!items[i].installed
                    break
                }
            }
            page.voiceModelInstalled = installed
            page.voiceContentReady = true
            if (!installed && settings.voiceTypingEnabled)
                settings.voiceTypingEnabled = false
        })
    }

    function openVoiceDownloads() {
        var dialog = pageStack.push(Qt.resolvedUrl("FutoContentRequiredDialog.qml"), {
            "contentName": qsTr("offline voice model"),
            "explanation": qsTr("Voice typing needs the FUTO Multilingual-39 model. "
                                + "Open the Offline voice downloader to install it?")
        })
        dialog.accepted.connect(function() {
            page.pendingVoiceDownloads = true
        })
    }

    ConfigurationGroup {
        id: settings
        path: "/sailfish/text_input/futo_keyboard"
        property bool voiceTypingEnabled: false
        property bool voiceKeyVisible: true
		property bool voicePushToTalkEnabled: false
        property bool voiceLiveTranscriptionEnabled: true
        property bool voiceStopAfterSilence: true
        property int voiceSilenceTimeoutMs: 1300
    }

    DBusInterface {
        id: helper
        bus: DBus.SessionBus
        service: "org.hb.FutoKeyboard1"
        path: "/org/hb/FutoKeyboard1"
        iface: "org.hb.FutoKeyboard1"
        signalsEnabled: true
        watchServiceStatus: true

        function contentChanged(packId, state) {
            if (String(packId) === "voice-multilingual-39")
                page.refreshVoiceContent()
        }

        onStatusChanged: {
            if (status === DBusInterface.Available)
                page.refreshVoiceContent()
        }
    }

    Component.onCompleted: refreshVoiceContent()

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
            PageHeader { title: qsTr("Voice typing") }

            TextSwitch {
                width: parent.width
                enabled: page.voiceContentReady || settings.voiceTypingEnabled
                automaticCheck: false
                checked: settings.voiceTypingEnabled
                text: qsTr("Enable voice typing")
                description: qsTr("Speech recognition remains completely on this phone.")
                onClicked: {
                    if (!checked && !page.voiceModelInstalled)
                        page.openVoiceDownloads()
                    else
                        settings.voiceTypingEnabled = !checked
                }
            }

            TextSwitch {
                width: parent.width
                enabled: settings.voiceTypingEnabled
                automaticCheck: false
                checked: settings.voiceKeyVisible
                text: qsTr("Show the microphone key")
				description: qsTr("The 123-menu microphone is configured separately "
				                  + "under Quick settings. When this key is hidden, "
				                  + "hold comma to use voice input instead.")
                onClicked: settings.voiceKeyVisible = !checked
            }

			TextSwitch {
				width: parent.width
				enabled: settings.voiceTypingEnabled
				automaticCheck: false
				checked: settings.voicePushToTalkEnabled
				text: qsTr("Push to talk")
				description: settings.voiceKeyVisible
						? qsTr("Hold the microphone to record and release it to stop.")
						: qsTr("Hold comma to record and release it to stop.")
				onClicked: {
					var nextEnabled = !checked
					settings.voicePushToTalkEnabled = nextEnabled
					if (nextEnabled)
						settings.voiceStopAfterSilence = false
				}
			}

            TextSwitch {
                width: parent.width
                enabled: settings.voiceTypingEnabled
                automaticCheck: false
                checked: settings.voiceLiveTranscriptionEnabled
                text: qsTr("Live transcription")
                description: qsTr("Show recognized words in the active text field while "
                                  + "you speak.")
                onClicked: settings.voiceLiveTranscriptionEnabled = !checked
            }

            TextSwitch {
                width: parent.width
                enabled: settings.voiceTypingEnabled
						 && settings.voiceLiveTranscriptionEnabled
						 && !settings.voicePushToTalkEnabled
                automaticCheck: false
				checked: !settings.voicePushToTalkEnabled
				         && settings.voiceStopAfterSilence
                text: qsTr("Stop automatically after silence")
                description: qsTr("When disabled, a tap keeps listening until you tap the "
                                  + "microphone again. Push-to-talk always stops on release.")
                onClicked: settings.voiceStopAfterSilence = !checked
            }

            Slider {
                width: parent.width
                enabled: settings.voiceTypingEnabled
                         && settings.voiceLiveTranscriptionEnabled
						 && !settings.voicePushToTalkEnabled
                         && settings.voiceStopAfterSilence
                label: qsTr("Finish after silence")
                minimumValue: 800
                maximumValue: 2500
                stepSize: 100
                value: Math.max(minimumValue, Math.min(maximumValue,
                                                       settings.voiceSilenceTimeoutMs))
                valueText: (value / 1000).toFixed(1) + qsTr(" seconds")
                onReleased: settings.voiceSilenceTimeoutMs = Math.round(value / 100) * 100
            }

            SectionHeader { text: qsTr("Private and offline") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Speech recognition runs entirely on this phone with the FUTO "
                           + "Multilingual-39 model. Recordings are stored in a private temporary "
                           + "file and erased immediately after transcription or cancellation. "
                           + "The microphone is unavailable in password fields and stops "
                           + "after your configured pause, when released in push-to-talk, or "
                           + "when you tap it again in continuous mode.")
            }

            SectionHeader { text: qsTr("Languages") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Voice recognition follows the language or language group of the "
                           + "current FUTO letter layout. Change layouts from the held-123 menu "
                           + "when you want to constrain recognition to another language group.")
            }
        }
    }
}
