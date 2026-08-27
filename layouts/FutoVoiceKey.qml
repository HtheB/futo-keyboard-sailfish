/* Dedicated offline voice-input key for FUTO Keyboard. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import com.jolla.keyboard 1.0
import ".."

FunctionKey {
    id: voiceKey

    property bool manualFeedbackOnPress: true
    property bool pushToTalkActive: false
    property bool pointerDown: false
    property Item targetLayout
    readonly property bool microphoneVisible: voiceSettings.voiceTypingEnabled
            && voiceSettings.voiceKeyVisible
            && keyboard.inputHandler
            && !keyboard.inputHandler.passwordField
    implicitWidth: microphoneVisible ? Theme.itemSizeSmall : 0
    keyType: KeyType.UnknownKey
    caption: ""
    active: microphoneVisible
    visible: microphoneVisible

    onMicrophoneVisibleChanged: relayoutTimer.restart()

    ConfigurationGroup {
        id: voiceSettings
        path: "/sailfish/text_input/futo_keyboard"
        property bool voiceTypingEnabled: false
        property bool voiceKeyVisible: true
		property bool voicePushToTalkEnabled: false
    }

    Timer {
        id: relayoutTimer
        interval: 0
        repeat: false
        onTriggered: {
            // KeyboardRow imperatively hides inactive children.  Re-run the
            // row layout when this setting changes so the key is restored and
            // Space is resized without requiring a Maliit restart.
            var layout = voiceKey.targetLayout
            if (!layout && keyboard)
                layout = keyboard.layout
            if (layout && layout.updateSizes)
                layout.updateSizes()
        }
    }

    Timer {
        id: pushToTalkTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (!voiceKey.pointerDown || !keyboard.inputHandler
                    || keyboard.inputHandler.voiceRecording
                    || keyboard.inputHandler.voiceBusy)
                return
            voiceKey.pushToTalkActive = true
            keyboard.inputHandler.startVoiceInput(true)
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Theme.iconSizeMedium
        height: width
        radius: width / 2
        color: Theme.rgba(Theme.highlightColor, 0.28)
        visible: keyboard.inputHandler && keyboard.inputHandler.voiceRecording

        SequentialAnimation on opacity {
            running: parent.visible
            loops: Animation.Infinite
            NumberAnimation { from: 0.45; to: 1.0; duration: 500 }
            NumberAnimation { from: 1.0; to: 0.45; duration: 500 }
        }
    }

    Icon {
        anchors.centerIn: parent
        width: Theme.iconSizeSmallPlus
        height: width
        source: "image://theme/icon-m-browser-microphone"
        visible: !(keyboard.inputHandler && keyboard.inputHandler.voiceBusy)
        color: keyboard.inputHandler && keyboard.inputHandler.voiceRecording
               ? Theme.highlightColor : voiceKey.palette.primaryColor
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Small
        running: keyboard.inputHandler && keyboard.inputHandler.voiceBusy
        visible: running
    }

    MouseArea {
        anchors.fill: parent
        preventStealing: true
        onPressed: {
            voiceKey.pointerDown = true
            voiceKey.pushToTalkActive = false
            voiceKey.pressed = true
            if (keyboard.inputHandler && keyboard.inputHandler.playManualKeyFeedback)
                keyboard.inputHandler.playManualKeyFeedback(voiceKey, "option")
            if (keyboard.inputHandler && !keyboard.inputHandler.voiceRecording
					&& !keyboard.inputHandler.voiceBusy) {
				if (voiceSettings.voicePushToTalkEnabled) {
					voiceKey.pushToTalkActive = true
					keyboard.inputHandler.startVoiceInput(true)
				} else {
					pushToTalkTimer.restart()
				}
			}
        }
        onReleased: {
            pushToTalkTimer.stop()
            voiceKey.pointerDown = false
            voiceKey.pressed = false
            if (!keyboard.inputHandler)
                return
            if (voiceKey.pushToTalkActive) {
                keyboard.inputHandler.releaseVoicePushToTalk()
                voiceKey.pushToTalkActive = false
            } else if (keyboard.inputHandler.voiceRecording) {
                keyboard.inputHandler.stopVoiceInput()
            } else if (!keyboard.inputHandler.voiceBusy) {
                keyboard.inputHandler.startVoiceInput(false)
            }
        }
        onCanceled: {
            pushToTalkTimer.stop()
            voiceKey.pointerDown = false
            voiceKey.pressed = false
            if (voiceKey.pushToTalkActive && keyboard.inputHandler)
                keyboard.inputHandler.releaseVoicePushToTalk()
            voiceKey.pushToTalkActive = false
        }
    }
}
