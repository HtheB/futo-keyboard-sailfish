/* One scrollable extended-symbol picker cell. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import ".."

CharacterKey {
    id: symbolCell

    property string symbolText
    property string arabicFontFamily
    property Item targetLayout
    property bool moved
    property bool favoriteHoldTriggered
    property real pressX
    property real pressY
    // Sailfish's native fallback fonts do not draw U+FDFB even though Android
    // AppSupport does. Use its Unicode compatibility decomposition for both
    // the key label and committed text so it renders consistently everywhere.
    readonly property string committedSymbolText: symbolText === "ﷻ"
            ? "جل جلاله" : symbolText

    caption: ""
    keyText: ""
    text: committedSymbolText
    showPopper: false

    ConfigurationGroup {
        id: visualSettings
        path: "/sailfish/text_input/futo_keyboard"
        property bool separatedKeysEnabled: true
        property real keyGapScale: 1.0
        property int secondaryKeyHoldMs: 430
    }

    function commitSymbol() {
        if (!keyboard.inputHandler || symbolText === "")
            return
        keyboard.inputHandler._handleKeyPress(symbolCell)
        keyboard.inputHandler._handleKeyClick(symbolCell)
        keyboard.inputHandler._handleKeyRelease()
        symbolCell.clicked()
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: Math.max(1, Theme.paddingSmall / 3
                                  * Math.max(0.5, Math.min(2.0,
                                                         visualSettings.keyGapScale)))
        radius: Theme.paddingSmall
        z: -2
        color: Theme.rgba(parent.palette.primaryColor, parent.pressed ? 0.24 : 0.12)
        border.width: 1
        border.color: Theme.rgba(parent.palette.primaryColor, 0.12)
        visible: visualSettings.separatedKeysEnabled
    }

    Label {
        anchors.fill: parent
        anchors.margins: Theme.paddingSmall
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: symbolCell.committedSymbolText
        textFormat: Text.PlainText
        color: symbolCell.pressed ? Theme.highlightColor : Theme.primaryColor
        font.family: {
            var codepoint = symbolCell.symbolText.length > 0
                    ? symbolCell.symbolText.codePointAt(0) : 0
            return codepoint >= 0xFDF0 && codepoint <= 0xFDFD
                    && symbolCell.arabicFontFamily !== ""
                    ? symbolCell.arabicFontFamily : Theme.fontFamily
        }
        font.pixelSize: Math.max(Theme.fontSizeSmall,
                                Math.min(parent.width, parent.height) * 0.46)
        minimumPixelSize: Theme.fontSizeExtraSmall
        fontSizeMode: Text.Fit
    }

    Label {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Theme.paddingSmall
        anchors.bottomMargin: Theme.paddingSmall / 2
        visible: symbolCell.targetLayout
                 && symbolCell.targetLayout.extendedSymbolPage !== 0
                 && symbolCell.targetLayout.isExtendedSymbolFavorite(
                        symbolCell.symbolText)
        text: "★"
        color: Theme.highlightColor
        font.pixelSize: Theme.fontSizeExtraSmall
    }

    Timer {
        id: favoriteHoldTimer
        // Favoriting is deliberately slower than ordinary secondary-key
        // activation so a vertical scroll cannot accidentally modify data.
        interval: Math.max(1000, visualSettings.secondaryKeyHoldMs + 500)
        repeat: false
        onTriggered: {
            if (!symbolCell.moved && symbolCell.targetLayout) {
                symbolCell.favoriteHoldTriggered = true
                symbolCell.targetLayout.toggleExtendedSymbolFavorite(
                            symbolCell.symbolText)
                if (keyboard.inputHandler
                        && keyboard.inputHandler.playOptionFeedback)
                    keyboard.inputHandler.playOptionFeedback()
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        preventStealing: false

        onPressed: {
            if (keyboard.inputHandler && keyboard.inputHandler.playManualKeyFeedback)
                keyboard.inputHandler.playManualKeyFeedback(symbolCell, "option")
            symbolCell.moved = false
            symbolCell.favoriteHoldTriggered = false
            symbolCell.pressX = mouse.x
            symbolCell.pressY = mouse.y
            symbolCell.pressed = true
            favoriteHoldTimer.restart()
        }
        onPositionChanged: {
            var dx = mouse.x - symbolCell.pressX
            var dy = mouse.y - symbolCell.pressY
            var cancelDistance = Math.max(4, Theme.startDragDistance * 0.35)
            if (dx * dx + dy * dy > cancelDistance * cancelDistance) {
                symbolCell.moved = true
                favoriteHoldTimer.stop()
            }
        }
        onReleased: {
            favoriteHoldTimer.stop()
            symbolCell.pressed = false
            if (!symbolCell.moved && !symbolCell.favoriteHoldTriggered)
                symbolCell.commitSymbol()
        }
        onCanceled: {
            favoriteHoldTimer.stop()
            symbolCell.pressed = false
            symbolCell.moved = true
        }
    }
}
