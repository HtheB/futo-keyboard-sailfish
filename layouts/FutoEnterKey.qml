/* Tap for Enter; hold to open FUTO's built-in emoji page. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import ".."

EnterKey {
    id: enterKey

    property Item targetLayout
    property bool held
    property bool manualFeedbackOnPress: true
    background.visible: false

    ConfigurationGroup {
        id: emojiSettings
        path: "/sailfish/text_input/futo_keyboard"
        property bool emojiLongPressEnabled: true
    }

    Label {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        // Match the gear hint on 123.  The smaller right inset keeps this
        // secondary hint away from the central Enter glyph.
        anchors.rightMargin: Theme.paddingMedium
        anchors.verticalCenterOffset: -parent.height * 0.22
        color: parent.palette.primaryColor
        font.pixelSize: Theme.fontSizeTiny
        text: "☺"
        visible: emojiSettings.emojiLongPressEnabled
                 && !(enterKey.targetLayout && enterKey.targetLayout.emojiMode)
                 && !(enterKey.targetLayout && enterKey.targetLayout.extendedSymbolMode)
        opacity: 0.72
    }

    function triggerEnter() {
        if (!keyboard.inputHandler)
            return
        keyboard.inputHandler._handleKeyPress(enterKey)
        keyboard.inputHandler._handleKeyClick(enterKey)
        keyboard.inputHandler._handleKeyRelease()
        enterKey.clicked()
    }

    Timer {
        id: holdTimer
        interval: 520
        onTriggered: {
            enterKey.held = true
            if (enterKey.targetLayout && enterKey.targetLayout.showEmojiPicker)
                enterKey.targetLayout.showEmojiPicker()
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: emojiSettings.emojiLongPressEnabled
                 && !(enterKey.targetLayout && enterKey.targetLayout.emojiMode)
                 && !(enterKey.targetLayout && enterKey.targetLayout.extendedSymbolMode)
        preventStealing: true

        onPressed: {
            if (keyboard.inputHandler && keyboard.inputHandler.playManualKeyFeedback)
                keyboard.inputHandler.playManualKeyFeedback(enterKey, "enter")
            enterKey.held = false
            enterKey.pressed = true
            holdTimer.restart()
        }
        onReleased: {
            holdTimer.stop()
            enterKey.pressed = false
            if (!enterKey.held)
                enterKey.triggerEnter()
        }
        onCanceled: {
            holdTimer.stop()
            enterKey.pressed = false
        }
    }
}
