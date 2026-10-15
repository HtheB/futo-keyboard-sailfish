/* Sailfish touch frontend for FUTO's canonical Japanese kana-flick layout. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import com.jolla.keyboard 1.0
import com.meego.maliitquick 1.0
import ".."
import "FutoLetterLayouts.js" as LetterLayouts
import "FutoFlickGesture.js" as Flick

SilicaItem {
    id: panel
    property Item targetLayout
    readonly property var rows: targetLayout
            ? LetterLayouts.flickRows(targetLayout.layoutVariant, targetLayout.compositionLatinMode) : []
    readonly property real rowHeight: targetLayout ? targetLayout.keyHeight : 0
    readonly property real thumbGap: targetLayout && targetLayout.thumbMode
            ? targetLayout.avoidanceWidth : 0
    readonly property real cellWidth: (width - thumbGap) / 5
    property int activeCell: -1
    property string selectedDirection: "primary"
    property var activeChoices: ({})
    height: rowHeight * 4
    opacity: targetLayout && targetLayout.cursorMoveMode ? 0 : 1
    onVisibleChanged: if (!visible) cancelGesture()
    onRowsChanged: cancelGesture()
    onWidthChanged: cancelGesture()
    onHeightChanged: cancelGesture()

    ConfigurationGroup {
        id: visualSettings
        path: "/sailfish/text_input/futo_keyboard"
        property bool separatedKeysEnabled: true
        property real keyGapScale: 1.0
    }

    function cancelGesture() {
        activeCell = -1
        activeChoices = ({})
        selectedDirection = "primary"
    }

    function cellX(column) {
        return column * cellWidth + (column >= 3 ? thumbGap : 0)
    }

    function sendChoice(choice) {
        if (!choice || !targetLayout || !targetLayout.handler) return
        // These are Mozc's 12-key codes, not committed kana or guessed romaji.
        targetLayout.handler.handleConversionKey({key: Qt.Key_unknown,
            keyType: KeyType.CharacterKey, text: String(choice.output)})
    }

    function action(name) {
        if (!targetLayout || !targetLayout.handler) return
        var handler = targetLayout.handler
        if (name === "latin") handler.toggleJapaneseLatinMode()
        else if (name === "symbols") {
            handler.finishConversion(function() { panel.targetLayout.attributes.inSymView = true })
        }
        else if (name === "emoji") {
            handler.finishConversion(function() { panel.targetLayout.showEmojiPicker() })
        } else if (name === "undo") {
            handler.finishConversion(function() {
                MInputMethodQuick.sendKey(Qt.Key_Z, Qt.ControlModifier, "", Maliit.KeyClick)
            })
        } else {
            var key = {"delete": Qt.Key_Backspace, left: Qt.Key_Left,
                       right: Qt.Key_Right, enter: Qt.Key_Return}[name]
            if (key !== undefined)
                handler.handleConversionKey({key: key, text: "",
                    keyType: KeyType.UnknownKey})
        }
    }

    Repeater {
        model: panel.rows.length * 5
        Item {
            id: cell
            readonly property var keyData: panel.rows[Math.floor(index / 5)][index % 5]
            readonly property var choices: keyData.choices || ({})
            readonly property string actionName: String(keyData.action || "")
            readonly property bool flickKey: keyData.kind === "flick"
            property bool held: false
            x: panel.cellX(index % 5)
            y: Math.floor(index / 5) * panel.rowHeight
            width: panel.cellWidth
            height: panel.rowHeight
            z: holdTool.item && holdTool.item.languageMode ? 100 : 0

            Rectangle {
                anchors.fill: parent
                anchors.margins: Math.max(1, Theme.paddingSmall / 3
                                        * Math.max(0.5, Math.min(2.0, visualSettings.keyGapScale)))
                radius: Theme.paddingSmall
                z: -2
                visible: cell.flickKey && visualSettings.separatedKeysEnabled
                color: Theme.rgba(panel.palette.primaryColor,
                                  panel.activeCell === index ? 0.24 : 0.12)
                border.width: 1
                border.color: Theme.rgba(panel.palette.primaryColor, 0.12)
            }
            Rectangle {
                anchors.fill: parent
                z: -1
                visible: cell.flickKey && panel.activeCell === index
                color: panel.palette.highlightBackgroundColor
                opacity: 0.5
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: Theme.paddingMedium
                radius: geometry.keyRadius
                z: -1
                visible: !cell.flickKey && panel.activeCell === index
                color: panel.palette.highlightBackgroundColor
                opacity: 0.6
            }
            Label {
                anchors.centerIn: parent
                width: Math.max(1, parent.width - 2 * Theme.paddingMedium)
                height: Math.max(1, parent.height - 2 * Theme.paddingSmall)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                fontSizeMode: Text.Fit
                minimumPixelSize: 1
                clip: true
                visible: cell.actionName !== "space"
                         && cell.actionName !== "emoji"
                         && !Flick.isKanaModifier(cell.choices.primary)
                         && !Flick.isKanaPunctuation(cell.choices.primary)
                text: cell.flickKey ? (cell.keyData.label || Flick.displayedCaption(cell.choices.primary))
                      : ({undo: "↶", "delete": "⌫", left: "←", right: "→",
                          emoji: "☺", latin: panel.targetLayout.compositionLatinMode ? "あ" : "ABC",
                          symbols: "123", enter: "↵"}[cell.actionName] || "")
                color: cell.flickKey ? panel.palette.primaryColor : Theme.highlightColor
                font.pixelSize: Math.min(Theme.fontSizeLarge, panel.rowHeight * 0.36)
            }
            FutoKanaModifierLabel {
                anchors.centerIn: parent
                width: Math.max(1, parent.width - 2 * Theme.paddingMedium)
                height: Math.max(1, parent.height * 0.82)
                kanaPixelSize: Math.min(Theme.fontSizeLarge, panel.rowHeight * 0.36)
                color: panel.palette.primaryColor
                visible: Flick.isKanaModifier(cell.choices.primary)
            }
            FutoKanaPunctuationLabel {
                anchors.centerIn: parent
                width: Math.max(1, parent.width - 2 * Theme.paddingMedium)
                height: Math.max(1, parent.height * 0.82)
                symbolPixelSize: Math.min(Theme.fontSizeLarge, panel.rowHeight * 0.36)
                color: panel.palette.primaryColor
                visible: Flick.isKanaPunctuation(cell.choices.primary)
            }
            Label {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.paddingMedium
                visible: cell.actionName === "latin"
                text: "⚙"
                opacity: 0.72
                font.pixelSize: Theme.fontSizeTiny
            }
            Loader {
                id: holdTool
                anchors.fill: parent
                active: cell.actionName === "space" || cell.actionName === "emoji"
                enabled: panel.activeCell < 0 && panel.targetLayout
                         && (!panel.targetLayout.handler
                             || !panel.targetLayout.handler.spacebarGestureActive
                             || (item && item.pointerDown))
                sourceComponent: Component {
                    FutoSpacebarKey {
                        languageLabel: ""
                        holdActionOverride: cell.actionName === "emoji" ? 2 : 1
                        alternateTapEnabled: cell.actionName === "emoji"
                        _normalOpacity: cell.actionName === "emoji" ? 0 : 0.07
                        _pressedOpacity: cell.actionName === "emoji" ? 0 : 0.6
                        onAlternateTapped: panel.action("emoji")

                        Label {
                            anchors.centerIn: parent
                            visible: cell.actionName === "emoji"
                            text: "☺"
                            color: Theme.highlightColor
                            font.pixelSize: Math.min(Theme.fontSizeLarge, panel.rowHeight * 0.36)
                        }
                        Item {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: parent.height * 0.20
                            visible: cell.actionName === "space"
                            width: Math.min(parent.width * 0.46, Theme.iconSizeMedium)
                            height: width * 0.22
                            opacity: 0.55
                            readonly property real strokeWidth: Math.max(1, Theme.dp(2))
                            Rectangle {
                                anchors.left: parent.left
                                width: parent.strokeWidth
                                height: parent.height
                                color: Theme.primaryColor
                            }
                            Rectangle {
                                anchors.right: parent.right
                                width: parent.strokeWidth
                                height: parent.height
                                color: Theme.primaryColor
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: parent.strokeWidth
                                color: Theme.primaryColor
                            }
                        }
                    }
                }
            }
            Timer {
                id: holdTimer
                interval: cell.actionName === "latin" ? 520 : 400
                repeat: cell.actionName === "delete"
                onTriggered: {
                    if (panel.activeCell !== index) { stop(); return }
                    cell.held = true
                    if (cell.actionName === "latin") panel.targetLayout.showControlStrip()
                    else if (cell.actionName === "delete") {
                        interval = 80
                        panel.action("delete")
                    }
                }
            }
            MouseArea {
                id: touch
                anchors.fill: parent
                enabled: cell.actionName !== "space"
                         && cell.actionName !== "emoji"
                         && panel.targetLayout && !panel.targetLayout.cursorMoveMode
                         && !(panel.targetLayout.handler
                              && panel.targetLayout.handler.spacebarGestureActive)
                preventStealing: true
                property real startX
                property real startY
                onPressed: {
                    if (panel.activeCell !== -1) { mouse.accepted = false; return }
                    panel.activeCell = index
                    panel.activeChoices = cell.choices
                    panel.selectedDirection = "primary"
                    startX = mouse.x
                    startY = mouse.y
                    cell.held = false
                    if (panel.targetLayout.handler.playManualKeyFeedback)
                        panel.targetLayout.handler.playManualKeyFeedback(null, "letter")
                    if (cell.actionName === "latin" || cell.actionName === "delete") {
                        holdTimer.interval = cell.actionName === "latin" ? 520 : 400
                        holdTimer.restart()
                    }
                }
                onPositionChanged: {
                    if (panel.activeCell !== index) return
                    if (cell.flickKey)
                        panel.selectedDirection = Flick.direction(mouse.x - startX,
                            mouse.y - startY, Math.min(width, height) * 0.24, cell.choices)
                    else if (Math.abs(mouse.x - startX) > Theme.startDragDistance
                             || Math.abs(mouse.y - startY) > Theme.startDragDistance) {
                        holdTimer.stop()
                        cell.held = true
                        if (mouse.y - startY > height * 0.65
                                && mouse.y - startY > Math.abs(mouse.x - startX))
                            MInputMethodQuick.userHide()
                    }
                }
                onReleased: {
                    holdTimer.stop()
                    if (panel.activeCell !== index) return
                    var chosen = cell.choices[panel.selectedDirection]
                    panel.cancelGesture()
                    if (cell.flickKey) panel.sendChoice(chosen)
                    else if (!cell.held) panel.action(cell.actionName)
                }
                onCanceled: {
                    holdTimer.stop()
                    if (panel.activeCell === index) panel.cancelGesture()
                }
            }
        }
    }

    // A cross popup follows the original key, never the neighbouring key the
    // finger has crossed. Its five cells retain their independent kana labels.
    Item {
        id: popup
        z: 1000
        visible: panel.activeCell >= 0 && !!panel.activeChoices.primary
        readonly property real cellSize: Math.min(panel.cellWidth * 0.75, panel.rowHeight * 0.7)
        width: cellSize * 3
        height: width
        x: Math.max(0, Math.min(panel.width - width,
             panel.cellX(panel.activeCell % 5) + panel.cellWidth / 2 - width / 2))
        y: Math.max(-panel.rowHeight * 0.8,
             Math.floor(panel.activeCell / 5) * panel.rowHeight - height * 0.72)
        Repeater {
            model: ["primary", "left", "up", "right", "down"]
            Rectangle {
                readonly property string direction: modelData
                readonly property var choice: panel.activeChoices[direction]
                width: popup.cellSize
                height: width
                x: ({primary: 1, left: 0, up: 1, right: 2, down: 1}[direction]) * width
                y: ({primary: 1, left: 1, up: 0, right: 1, down: 2}[direction]) * height
                visible: !!choice
                radius: Theme.paddingSmall
                color: keyboard.popperBackgroundColor
                Label {
                    anchors.centerIn: parent
                    width: Math.max(1, parent.width - Theme.paddingSmall)
                    height: Math.max(1, parent.height - Theme.paddingSmall)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    fontSizeMode: Text.Fit
                    minimumPixelSize: 1
                    clip: true
                    visible: !Flick.isKanaModifier(parent.choice)
                    text: Flick.displayedCaption(parent.choice)
                    font.pixelSize: Math.min(Theme.fontSizeLarge, popup.cellSize * 0.6)
                    color: panel.selectedDirection === parent.direction
                           ? panel.palette.primaryColor : panel.palette.secondaryColor
                    font.bold: panel.selectedDirection === parent.direction
                }
                FutoKanaModifierLabel {
                    anchors.centerIn: parent
                    width: Math.max(1, parent.width - Theme.paddingSmall)
                    height: Math.max(1, parent.height * 0.90)
                    kanaPixelSize: Math.min(Theme.fontSizeLarge, popup.cellSize * 0.6)
                    color: panel.selectedDirection === parent.direction
                           ? panel.palette.primaryColor : panel.palette.secondaryColor
                    visible: Flick.isKanaModifier(parent.choice)
                }
            }
        }
    }
}
