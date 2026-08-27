/* Tap for the second symbol page; hold for the full categorized picker. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import com.jolla.keyboard 1.0
import ".."

FunctionKey {
    id: extendedKey

    property Item targetLayout
    property bool held

    caption: "{&="
    keyType: KeyType.SymbolKey
    background.visible: false

    Label {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Theme.paddingSmall
        anchors.topMargin: Theme.paddingSmall / 2
        text: "☆"
        color: extendedKey.pressed ? Theme.highlightColor : Theme.secondaryColor
        font.family: "Symbola"
        font.pixelSize: Theme.fontSizeExtraSmall
    }

    ConfigurationGroup {
        id: holdSettings
        path: "/sailfish/text_input/futo_keyboard"
        property int secondaryKeyHoldMs: 500
    }

    Timer {
        id: holdTimer
        interval: Math.max(200, Math.min(1500,
                                        Number(holdSettings.secondaryKeyHoldMs)))
        onTriggered: {
            extendedKey.held = true
            if (extendedKey.targetLayout
                    && extendedKey.targetLayout.showExtendedSymbolPicker)
                extendedKey.targetLayout.showExtendedSymbolPicker()
        }
    }

    MouseArea {
        anchors.fill: parent
        preventStealing: true

        onPressed: {
            if (keyboard.inputHandler && keyboard.inputHandler.playManualKeyFeedback)
                keyboard.inputHandler.playManualKeyFeedback(extendedKey, "option")
            extendedKey.held = false
            extendedKey.pressed = true
            holdTimer.restart()
        }
        onReleased: {
            holdTimer.stop()
            extendedKey.pressed = false
            if (!extendedKey.held && extendedKey.targetLayout)
                extendedKey.targetLayout.showSecondSymbolPage()
        }
        onCanceled: {
            holdTimer.stop()
            extendedKey.pressed = false
        }
    }
}
