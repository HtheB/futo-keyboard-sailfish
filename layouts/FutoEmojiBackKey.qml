/* Return to letters; hold to open FUTO's quick-action strip. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import com.jolla.keyboard 1.0
import ".."

FunctionKey {
    id: emojiBackKey

    property Item targetLayout
    property bool held
    property bool manualFeedbackOnPress: true

    caption: "ABC"
    implicitWidth: functionKeyWidth
    keyType: KeyType.SymbolKey
    background.visible: false

    Label {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: Theme.paddingMedium
        anchors.verticalCenterOffset: -parent.height * 0.22
        color: parent.palette.primaryColor
        font.pixelSize: Theme.fontSizeTiny
        text: "⚙"
        opacity: 0.72
    }

    Timer {
        id: holdTimer
        interval: 520
        onTriggered: {
            emojiBackKey.held = true
            if (emojiBackKey.targetLayout && emojiBackKey.targetLayout.showControlStrip)
                emojiBackKey.targetLayout.showControlStrip()
        }
    }

    MouseArea {
        anchors.fill: parent
        preventStealing: true

        onPressed: {
            if (keyboard.inputHandler && keyboard.inputHandler.playManualKeyFeedback)
                keyboard.inputHandler.playManualKeyFeedback(emojiBackKey, "option")
            emojiBackKey.held = false
            emojiBackKey.pressed = true
            holdTimer.restart()
        }
        onReleased: {
            holdTimer.stop()
            emojiBackKey.pressed = false
            if (!emojiBackKey.held && emojiBackKey.targetLayout) {
                if (emojiBackKey.targetLayout.extendedSymbolMode
                        && emojiBackKey.targetLayout.hideExtendedSymbolPicker)
                    emojiBackKey.targetLayout.hideExtendedSymbolPicker()
                else
                    emojiBackKey.targetLayout.hideEmojiPicker()
            }
        }
        onCanceled: {
            holdTimer.stop()
            emojiBackKey.pressed = false
        }
    }
}
