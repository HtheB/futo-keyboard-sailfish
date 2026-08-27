/* Bottom-left letters/symbols switch with a long-hold action strip. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."

SymbolKey {
    id: symbolKey

    property Item targetLayout
    property bool held
    property bool manualFeedbackOnPress: true

    caption: attributes.inSymView
             ? (targetLayout && targetLayout.letterPageLabel
                ? targetLayout.letterPageLabel() : "ABC")
                                  : (targetLayout && targetLayout.numberPageLabel
                                     ? targetLayout.numberPageLabel() : "123")
    background.visible: false
	// Keep this action comfortably tappable while giving the reclaimed width to
	// the expanding Space key immediately to its right.
	implicitWidth: Math.max(Theme.itemSizeSmall,
	                        Math.round(functionKeyWidth * 0.80))

    // Hint that holding 123 or ABC opens the keyboard's quick-action strip. Keep
    // this comfortably inside the key so it cannot be clipped by the edge of
    // the keyboard or collide with the main caption.
    Label {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        // The connected Arabic label is wider than ABC. Give it a dedicated
        // top-right position so the gear cannot crowd the final glyph.
        anchors.rightMargin: parent.caption === "أبج"
                             ? Math.max(1, Theme.paddingSmall / 2)
                             : Theme.paddingMedium
        anchors.verticalCenterOffset: -parent.height
                                      * (parent.caption === "أبج" ? 0.33 : 0.22)
        color: parent.palette.primaryColor
        font.pixelSize: Theme.fontSizeTiny
        text: "⚙"
        opacity: 0.72
    }

    function triggerSymbolSwitch() {
        if (!keyboard.inputHandler)
            return
        keyboard.inputHandler._handleKeyPress(symbolKey)
        keyboard.inputHandler._handleKeyClick(symbolKey)
        symbolKey.clicked()
        keyboard.inputHandler._handleKeyRelease()
    }

    Timer {
        id: holdTimer
        interval: 520
        onTriggered: {
            symbolKey.held = true
            if (symbolKey.targetLayout && symbolKey.targetLayout.showControlStrip)
                symbolKey.targetLayout.showControlStrip()
        }
    }

    MouseArea {
        anchors.fill: parent
        preventStealing: true

        onPressed: {
            if (keyboard.inputHandler && keyboard.inputHandler.playManualKeyFeedback)
                keyboard.inputHandler.playManualKeyFeedback(symbolKey, "option")
            symbolKey.held = false
            symbolKey.pressed = true
            holdTimer.restart()
        }
        onReleased: {
            holdTimer.stop()
            symbolKey.pressed = false
            if (!symbolKey.held)
                symbolKey.triggerSymbolSwitch()
        }
        onCanceled: {
            holdTimer.stop()
            symbolKey.pressed = false
        }
    }
}
