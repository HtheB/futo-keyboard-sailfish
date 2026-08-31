/* Shift key and the long-hold entry point for the extended symbol picker. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import ".."

ShiftKey {
    id: shiftKey

    property Item targetLayout
    property bool held
    readonly property bool persianLetterMode: targetLayout
            && targetLayout.usesPersianDigits !== undefined
            && targetLayout.usesPersianDigits
            && !attributes.inSymView

    caption: persianLetterMode ? "ن‌پ" : attributes.inSymView
             ? (attributes.inSymView2
                ? "Fn"
                : "{&=") : ""
    background.visible: false

    Label {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Theme.paddingSmall
        anchors.topMargin: Theme.paddingSmall / 2
        visible: shiftKey.caption === "{&="
        text: "☆"
        color: shiftKey.pressed ? Theme.highlightColor : Theme.secondaryColor
        font.family: "Symbola"
        font.pixelSize: Theme.fontSizeExtraSmall
    }

    ConfigurationGroup {
        id: holdSettings
        path: "/sailfish/text_input/futo_keyboard"
        property int secondaryKeyHoldMs: 500
    }

    Timer {
        id: symbolPickerTimer
        interval: Math.max(200, Math.min(1500,
                                        Number(holdSettings.secondaryKeyHoldMs)))
        onTriggered: {
            shiftKey.held = true
            if (shiftKey.targetLayout && shiftKey.targetLayout.showExtendedSymbolPicker)
                shiftKey.targetLayout.showExtendedSymbolPicker()
        }
    }

    MouseArea {
        anchors.fill: parent
        visible: attributes.inSymView || shiftKey.persianLetterMode
        preventStealing: true

        onPressed: {
            if (keyboard.inputHandler && keyboard.inputHandler.playManualKeyFeedback)
                keyboard.inputHandler.playManualKeyFeedback(shiftKey, "option")
            shiftKey.held = false
            shiftKey.pressed = true
            if (attributes.inSymView)
                symbolPickerTimer.restart()
        }
        onReleased: {
            symbolPickerTimer.stop()
            shiftKey.pressed = false
            if (shiftKey.persianLetterMode) {
                if (keyboard.inputHandler
                        && keyboard.inputHandler.insertWordCharacter)
                    keyboard.inputHandler.insertWordCharacter("\u200c")
            } else if (!shiftKey.held && shiftKey.targetLayout) {
                if (attributes.inSymView2
                        && shiftKey.targetLayout.showDesktopKeysPage)
                    shiftKey.targetLayout.showDesktopKeysPage()
                else
                    shiftKey.targetLayout.showSecondSymbolPage()
            }
        }
        onCanceled: {
            symbolPickerTimer.stop()
            shiftKey.pressed = false
        }
    }
}
