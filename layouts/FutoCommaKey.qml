/* Context-aware comma key that provides zero in the optional numpad view. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import ".."

ContextAwareCommaKey {
	id: commaKey

    property int symbolNumberLayout
	property bool pointerDown
	property bool heldForVoice
	property bool pushToTalkActive
	property bool voiceWasActiveAtPress
	property bool manualFeedbackOnPress: true
	readonly property var voiceHandler: keyboard && keyboard.inputHandler
			? keyboard.inputHandler : null
	readonly property bool fallbackVoiceEnabled: voiceSettings.voiceTypingEnabled
			&& !voiceSettings.voiceKeyVisible && voiceHandler
			&& !voiceHandler.passwordField && !attributes.inSymView
			&& String(caption) === ","
	readonly property bool fallbackVoiceActive: fallbackVoiceEnabled
			&& (voiceHandler.voiceRecording || voiceHandler.voiceBusy)

    symView: symbolNumberLayout === 1 ? "0" : ","
    symView2: ","
	keyText: fallbackVoiceActive ? ""
			 : (attributes.inSymView && symView.length > 0
			    ? (attributes.inSymView2 ? symView2 : symView)
			    : (attributes.isShifted ? captionShifted : caption))

	ConfigurationGroup {
		id: voiceSettings
		path: "/sailfish/text_input/futo_keyboard"
		property bool voiceTypingEnabled: false
		property bool voiceKeyVisible: true
		property bool voicePushToTalkEnabled: false
	}

	function triggerComma() {
		if (!voiceHandler)
			return
		voiceHandler._handleKeyPress(commaKey)
		voiceHandler._handleKeyClick(commaKey)
		voiceHandler._handleKeyRelease()
		commaKey.clicked()
	}

	Timer {
		id: voiceHoldTimer
		interval: 450
		repeat: false
		onTriggered: {
			if (!commaKey.pointerDown || !commaKey.voiceHandler
					|| commaKey.voiceHandler.voiceRecording
					|| commaKey.voiceHandler.voiceBusy)
				return
			commaKey.heldForVoice = true
			commaKey.pushToTalkActive = voiceSettings.voicePushToTalkEnabled
			commaKey.voiceHandler.startVoiceInput(commaKey.pushToTalkActive)
		}
	}

	// Hint above comma, matching the compact fallback placement used in the
	// reference keyboard when a dedicated microphone column is not requested.
	Icon {
		anchors.top: parent.top
		anchors.horizontalCenter: parent.horizontalCenter
		anchors.topMargin: Math.max(1, Theme.paddingSmall / 4)
		width: Theme.iconSizeExtraSmall
		height: width
		source: "image://theme/icon-m-browser-microphone"
		color: parent.palette.primaryColor
		opacity: 0.58
		visible: parent.fallbackVoiceEnabled && !parent.fallbackVoiceActive
	}

	Rectangle {
		anchors.centerIn: parent
		width: Theme.iconSizeMedium
		height: width
		radius: width / 2
		color: Theme.rgba(Theme.highlightColor, 0.28)
		visible: parent.fallbackVoiceActive && parent.voiceHandler.voiceRecording

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
		color: parent.voiceHandler && parent.voiceHandler.voiceRecording
		       ? Theme.highlightColor : parent.palette.primaryColor
		visible: parent.fallbackVoiceActive
				 && !(parent.voiceHandler && parent.voiceHandler.voiceBusy)
	}

	BusyIndicator {
		anchors.centerIn: parent
		size: BusyIndicatorSize.Small
		running: parent.fallbackVoiceActive && parent.voiceHandler.voiceBusy
		visible: running
	}

	MouseArea {
		anchors.fill: parent
		z: 20
		enabled: commaKey.fallbackVoiceEnabled
		preventStealing: true

		onPressed: {
			mouse.accepted = true
			commaKey.pointerDown = true
			commaKey.heldForVoice = false
			commaKey.pushToTalkActive = false
			commaKey.voiceWasActiveAtPress = commaKey.voiceHandler
					&& (commaKey.voiceHandler.voiceRecording
					    || commaKey.voiceHandler.voiceBusy)
			commaKey.pressed = true
			if (commaKey.voiceHandler && commaKey.voiceHandler.playManualKeyFeedback)
				commaKey.voiceHandler.playManualKeyFeedback(commaKey, "letter")
			if (!commaKey.voiceWasActiveAtPress)
				voiceHoldTimer.restart()
		}

		onReleased: {
			voiceHoldTimer.stop()
			commaKey.pointerDown = false
			commaKey.pressed = false
			if (!commaKey.voiceHandler)
				return
			if (commaKey.voiceWasActiveAtPress) {
				if (commaKey.voiceHandler.voiceRecording)
					commaKey.voiceHandler.stopVoiceInput()
			} else if (commaKey.heldForVoice) {
				if (commaKey.pushToTalkActive)
					commaKey.voiceHandler.releaseVoicePushToTalk()
			} else if (!commaKey.heldForVoice) {
				commaKey.triggerComma()
			}
			commaKey.pushToTalkActive = false
			commaKey.voiceWasActiveAtPress = false
		}

		onCanceled: {
			voiceHoldTimer.stop()
			commaKey.pointerDown = false
			commaKey.pressed = false
			if (commaKey.pushToTalkActive && commaKey.voiceHandler)
				commaKey.voiceHandler.releaseVoicePushToTalk()
			commaKey.pushToTalkActive = false
			commaKey.voiceWasActiveAtPress = false
		}
	}
}
