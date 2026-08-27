/* Swipe Backspace left to delete complete words. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import ".."

BackspaceKey {
    id: backspaceKey

    property real pressX
    property bool gestureMoved
    property bool repeatTriggered
    property bool holdActive
    property double holdStartedAt
    readonly property int wordRepeatDelay: 3000
    property bool manualFeedbackOnPress: true

    ConfigurationGroup {
        id: gestureSettings
        path: "/sailfish/text_input/futo_keyboard"
        property bool swipeDeleteEnabled: true
    }

    function triggerBackspace() {
        if (!keyboard.inputHandler)
            return
        keyboard.inputHandler._handleKeyPress(backspaceKey)
        keyboard.inputHandler._handleKeyClick(backspaceKey)
        keyboard.inputHandler._handleKeyRelease()
        backspaceKey.clicked()
    }

    function continueHoldRepeat() {
        if (!backspaceKey.holdActive || backspaceKey.gestureMoved)
            return

        var elapsed = Date.now() - backspaceKey.holdStartedAt
        backspaceKey.repeatTriggered = true

        // Begin with characters, accelerating smoothly from roughly 9 to
        // 22 deletions per second.  A longer hold changes to whole words and
        // continues accelerating, without making that transition abrupt.
        if (elapsed < backspaceKey.wordRepeatDelay) {
            backspaceKey.triggerBackspace()
            repeatTimer.interval = Math.max(45,
                    Math.round(115 - Math.max(0, elapsed - 420) * 0.027))
        } else {
            if (keyboard.inputHandler && keyboard.inputHandler.deletePreviousWord) {
                keyboard.inputHandler.deletePreviousWord()
                if (keyboard.inputHandler.playManualKeyFeedback)
                    keyboard.inputHandler.playManualKeyFeedback(backspaceKey, "option")
            }
            repeatTimer.interval = Math.max(90,
                    Math.round(320 - Math.max(0,
                            elapsed - backspaceKey.wordRepeatDelay) * 0.075))
        }

        repeatTimer.restart()
    }

    Timer {
        id: repeatTimer
        interval: 420
        repeat: false
        onTriggered: backspaceKey.continueHoldRepeat()
    }

    MouseArea {
        anchors.fill: parent
        enabled: gestureSettings.swipeDeleteEnabled
        preventStealing: true

        onPressed: {
            if (keyboard.inputHandler && keyboard.inputHandler.playManualKeyFeedback)
                keyboard.inputHandler.playManualKeyFeedback(backspaceKey, "option")
            backspaceKey.pressX = mouse.x
            backspaceKey.gestureMoved = false
            backspaceKey.repeatTriggered = false
            backspaceKey.holdActive = true
            backspaceKey.holdStartedAt = Date.now()
            backspaceKey.pressed = true
            repeatTimer.interval = 420
            repeatTimer.restart()
        }

        onPositionChanged: {
            var threshold = Math.max(Theme.itemSizeSmall, width * 0.8)
			// One left-swipe is one command, regardless of how far the finger
			// continues across the keyboard.  Accelerated character/word deletion
			// remains available only through the separate hold-repeat path.
			if (!backspaceKey.gestureMoved
					&& backspaceKey.pressX - mouse.x >= threshold) {
                repeatTimer.stop()
                backspaceKey.gestureMoved = true
				if (keyboard.inputHandler && keyboard.inputHandler.deletePreviousWord)
					keyboard.inputHandler.deletePreviousWord()
            }
        }

        onReleased: {
            repeatTimer.stop()
            backspaceKey.holdActive = false
            backspaceKey.pressed = false
            if (!backspaceKey.gestureMoved && !backspaceKey.repeatTriggered)
                backspaceKey.triggerBackspace()
        }

        onCanceled: {
            repeatTimer.stop()
            backspaceKey.holdActive = false
            backspaceKey.pressed = false
        }
    }
}
