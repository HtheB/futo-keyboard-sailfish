/* A straight, non-staggered row for the optional number-pad symbol page. */
import QtQuick 2.0
import com.jolla.keyboard 1.0
import ".."

Item {
    id: numpadRow

    property Item targetLayout
    property var cells: []
    property int totalSpans: 10
    property int splitSpan: Math.ceil(totalSpans / 2)
    property bool followRowHeight: true

    function spanBefore(itemIndex) {
        var result = 0
        for (var i = 0; i < itemIndex && i < cells.length; ++i)
            result += Number(cells[i].span || 1)
        return result
    }

    Item {
        anchors.fill: parent

        Repeater {
            model: numpadRow.cells

            Item {
                id: cell
                property var definition: modelData
                readonly property real logicalStart: numpadRow.spanBefore(index)
                readonly property real logicalSpan: Number(definition.span || 1)
                readonly property bool split: numpadRow.targetLayout
                        && numpadRow.targetLayout.splitActive
                readonly property real gap: split
                        ? Number(numpadRow.targetLayout.avoidanceWidth) : 0
                readonly property real sideWidth: (numpadRow.width - gap) / 2
                readonly property bool onRight: split
                        && logicalStart >= numpadRow.splitSpan
                readonly property real sideSpans: onRight
                        ? numpadRow.totalSpans - numpadRow.splitSpan
                        : numpadRow.splitSpan
                x: !split
                   ? numpadRow.width * logicalStart / numpadRow.totalSpans
                   : onRight
                     ? numpadRow.width / 2 + gap / 2
                       + sideWidth * (logicalStart - numpadRow.splitSpan)
                         / sideSpans
                     : sideWidth * logicalStart / sideSpans
                width: !split
                       ? numpadRow.width * logicalSpan / numpadRow.totalSpans
                       : sideWidth * logicalSpan / sideSpans
                height: parent.height

                Loader {
                    anchors.fill: parent
                    sourceComponent: cell.definition.action === "backspace" ? backspaceComponent
                                   : cell.definition.action === "enter" ? enterComponent
                                   : cell.definition.action === "space" ? spaceComponent
                                   : cell.definition.action === "abc" ? symbolSwitchComponent
                                   : cell.definition.action === "tab" ? tabComponent
                                   : cell.definition.action === "extendedSymbols" ? extendedSymbolsComponent
                                   : cell.definition.action !== undefined ? functionComponent
                                   : characterComponent
                }

                Component {
                    id: characterComponent
                    FutoCharacterKey {
                        caption: String(cell.definition.text)
                        captionShifted: caption
                        symView: caption
                        symView2: caption
                        secondaryHintEligible: false
                        letterAccents: ""
                        letterAccentsShifted: ""
                    }
                }

                Component {
                    id: functionComponent
                    FunctionKey {
                        caption: String(cell.definition.text)
                        keyType: KeyType.SymbolKey
                        background.visible: false
                        onClicked: {
                            if (!numpadRow.targetLayout)
                                return
                            if (cell.definition.action === "page2")
                                numpadRow.targetLayout.showSecondSymbolPage()
                            else if (cell.definition.action === "page1")
                                numpadRow.targetLayout.showFirstSymbolPage()
                            else if (cell.definition.action === "desktopKeys"
                                     && numpadRow.targetLayout.showDesktopKeysPage)
                                numpadRow.targetLayout.showDesktopKeysPage()
                        }
                    }
                }

                Component {
                    id: extendedSymbolsComponent
                    FutoExtendedSymbolsKey { targetLayout: numpadRow.targetLayout }
                }

                Component {
                    id: tabComponent
                    FunctionKey {
                        caption: "⇥"
                        text: "\t"
                        key: Qt.Key_Tab
                        keyType: KeyType.SymbolKey
                        background.visible: false
                    }
                }

                Component {
                    id: symbolSwitchComponent
                    FutoSymbolKey { targetLayout: numpadRow.targetLayout }
                }

                Component {
                    id: backspaceComponent
                    FutoBackspaceKey {}
                }

                Component {
                    id: enterComponent
                    FutoEnterKey { targetLayout: numpadRow.targetLayout }
                }

                Component {
                    id: spaceComponent
                    FutoSpacebarKey { languageLabel: "" }
                }
            }
        }
    }
}
