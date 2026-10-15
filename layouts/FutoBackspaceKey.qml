/* Swipe Backspace left to delete complete words. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import com.meego.maliitquick 1.0
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
    property int draggedWordCount: 0

    ConfigurationGroup {
        id: gestureSettings
        path: "/sailfish/text_input/futo_keyboard"
        property bool swipeDeleteEnabled: true
        property bool progressiveSwipeDeleteEnabled: false
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
        if (!MInputMethodQuick.active || !backspaceKey.holdActive
                || backspaceKey.gestureMoved) {
            repeatTimer.stop()
            backspaceKey.holdActive = false
            backspaceKey.pressed = false
            return
        }

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

    Connections {
        target: MInputMethodQuick
        onActiveChanged: {
            if (!MInputMethodQuick.active) {
                repeatTimer.stop()
                backspaceKey.holdActive = false
                backspaceKey.pressed = false
            }
        }
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
            backspaceKey.draggedWordCount = 0
            backspaceKey.repeatTriggered = false
            backspaceKey.holdActive = true
            backspaceKey.holdStartedAt = Date.now()
            backspaceKey.pressed = true
            repeatTimer.interval = 420
            repeatTimer.restart()
        }

        onPositionChanged: {
            var threshold = Math.max(Theme.itemSizeSmall, width * 0.8)
            var distance = backspaceKey.pressX - mouse.x
            var desired = distance >= threshold ? (gestureSettings.progressiveSwipeDeleteEnabled
                    ? 1 + Math.floor((distance - threshold) / Math.max(Theme.itemSizeSmall, width)) : 1) : 0
            if (desired > backspaceKey.draggedWordCount) {
                repeatTimer.stop()
                backspaceKey.gestureMoved = true
                if (keyboard.inputHandler && keyboard.inputHandler.deletePreviousWords)
                    keyboard.inputHandler.deletePreviousWords(desired - backspaceKey.draggedWordCount)
                backspaceKey.draggedWordCount = desired
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
