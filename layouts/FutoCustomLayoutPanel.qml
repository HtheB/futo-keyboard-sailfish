import QtQuick 2.6
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import "FutoCustomLayouts.js" as Custom

Item {
    id: panel
    property Item targetLayout
    property var pageData: targetLayout ? targetLayout.customPage : null
    readonly property var boxes: pageData ? Custom.geometry(pageData.rows, width, height,
            targetLayout.thumbMode ? targetLayout.avoidanceWidth : 0) : []
    ConfigurationGroup {
        id: appearance
        path: "/sailfish/text_input/futo_keyboard"
        property bool separatedKeysEnabled: true
        property real keyGapScale: 1.0
    }

    Repeater {
        model: panel.boxes
        Item {
            id: cell
            x: modelData.x; y: modelData.y; width: modelData.width; height: modelData.height
            property var definition: panel.pageData.rows[modelData.row][modelData.column]
            property bool reserved: modelData.row === panel.pageData.rows.length - 1 && modelData.column === 0
            Rectangle {
                anchors.fill: parent
                anchors.margins: Math.max(1, Theme.paddingSmall / 3 * Math.max(0.5, Math.min(2, appearance.keyGapScale)))
                radius: Theme.paddingSmall
                visible: Custom.showsCard(cell.definition, appearance.separatedKeysEnabled)
                readonly property color foreground: keyLoader.item && keyLoader.item.palette ? keyLoader.item.palette.primaryColor : Theme.primaryColor
                color: Theme.rgba(foreground, keyLoader.item && keyLoader.item.pressed ? 0.24 : 0.12)
                border.width: 1
                border.color: Theme.rgba(foreground, 0.12)
            }
            Loader {
                id: keyLoader
                anchors.fill: parent
                sourceComponent: !cell.reserved && !cell.definition.holdAction && cell.definition.more.length === 0
                        ? cell.definition.action === "space" ? spaceComponent
                        : cell.definition.action === "backspace" && !cell.definition.label ? backspaceComponent : genericComponent : genericComponent
            }
            Component { id: genericComponent; FutoCustomKey { targetLayout: panel.targetLayout; definition: cell.definition; reservedQuickSettings: cell.reserved } }
            Component { id: spaceComponent; FutoSpacebarKey { _normalOpacity: 0; _pressedOpacity: 0; languageLabel: cell.definition.label || panel.targetLayout.currentLayoutLanguageCodes; incognitoIndicatorVisible: panel.targetLayout.effectiveIncognitoMode } }
            Component { id: backspaceComponent; FutoBackspaceKey {} }
        }
    }
}
