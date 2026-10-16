import QtQuick 2.6
import Sailfish.Silica 1.0
import "FutoEditorHints.js" as Hints

IconButton {
    id: tool
    property string actionId
    property string description
    readonly property string hintLabel: actionId === "back" ? qsTr("Back")
        : actionId === "save-copy" ? qsTr("Save copy") : actionId === "test" ? qsTr("Test")
        : actionId === "clear" ? qsTr("Clear") : actionId === "characters" ? qsTr("Choose character") : description
    readonly property string themeIconName: {
        if (actionId === "clear" || actionId === "key-remove" || actionId === "row-remove" || actionId === "page-remove") return "icon-m-delete"
        if (actionId === "key-add" || actionId === "row-add" || actionId === "page-add" || actionId === "width-increase") return "icon-m-add"
        if (actionId === "width-decrease") return "icon-m-remove"
        if (actionId === "close") return "icon-m-close"
        if (actionId === "duplicate") return "icon-m-clipboard"
        if (actionId === "gap") return "icon-m-scale"
        if (["back", "up", "down", "left", "right"].indexOf(actionId) >= 0) return "icon-m-" + actionId
        return ""
    }
    width: Theme.itemSizeSmall
    height: Theme.itemSizeSmall
    Accessible.name: description
    Accessible.role: Accessible.Button
    onPressAndHold: Hints.show(tool, hintLabel)
    icon.source: themeIconName !== "" ? "image://theme/" + themeIconName : ""
    icon.rotation: actionId === "gap" ? 90 : 0
    FutoEditorGlyph {
        visible: tool.themeIconName === ""
        anchors.centerIn: parent
        width: Theme.iconSizeMedium; height: width
        actionId: tool.actionId
        color: tool.pressed ? Theme.highlightColor : Theme.primaryColor
        opacity: tool.enabled ? 1 : 0.35
    }
}
