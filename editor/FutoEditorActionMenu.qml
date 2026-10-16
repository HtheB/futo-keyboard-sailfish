import QtQuick 2.6
import Sailfish.Silica 1.0
import "FutoEditorHints.js" as Hints

FutoEditorComboBox {
    id: actions
    property string actionGroup: "keys"
    property bool canAddKey: true
    property bool canAddRow: true
    property bool canDeleteRow: true
    property bool canMoveUp: true
    property bool canMoveDown: true
    property bool hintHeld: false
    readonly property var entries: actionGroup === "keys" ? [
        {action: "key-add", text: qsTr("Add key"), icon: "icon-m-add"},
        {action: "key-remove", text: qsTr("Delete key"), icon: "icon-m-delete"},
        {action: "duplicate", text: qsTr("Duplicate key"), icon: "icon-m-clipboard"},
        {action: "gap", text: qsTr("Add empty space"), icon: "icon-m-scale"}
    ] : [
        {action: "row-add", text: qsTr("Add row"), icon: "icon-m-add"},
        {action: "row-remove", text: qsTr("Delete row"), icon: "icon-m-delete"},
        {action: "up", text: qsTr("Move row up"), icon: "icon-m-up"},
        {action: "down", text: qsTr("Move row down"), icon: "icon-m-down"}
    ]
    signal actionRequested(string action)
    label: actionGroup === "keys" ? qsTr("Keys") : qsTr("Rows")
    height: minimumContentHeight
    value: ""
    selectedIndex: -1
    leftMargin: Theme.paddingMedium
    rightMargin: Theme.paddingMedium + Theme.iconSizeSmall
    labelColor: _menuOpen ? Theme.highlightColor : Theme.primaryColor
    onDownChanged: if (down) hintHeld = false
    onPressAndHold: { hintHeld = true; Hints.show(actions, label) }
    onClicked: if (!hintHeld) _controller.openMenu()
    Icon {
        anchors.right: parent.right; anchors.rightMargin: Theme.paddingMedium
        y: (actions.minimumContentHeight - height) / 2
        width: Theme.iconSizeSmall; height: width
        source: "image://theme/icon-s-down"
        color: actions._menuOpen ? Theme.highlightColor : Theme.secondaryColor
    }
    menu: ContextMenu {
        id: actionMenu
        x: 0
        y: actions.height
        anchors.bottom: undefined
        width: {
            var longest = 0
            for (var i = 0; i < actions.entries.length; i++)
                longest = Math.max(longest, actionFont.advanceWidth(actions.entries[i].text))
            return Math.max(actions.width, Math.ceil(longest + Theme.iconSizeMedium + Theme.paddingMedium + 2 * Theme.horizontalPageMargin))
        }
        backgroundColor: Theme.rgba(Theme.highlightDimmerColor, 1)
        FontMetrics { id: actionFont; font.pixelSize: Theme.fontSizeMedium }
        Rectangle {
            objectName: "editorActionMenuBackground"
            parent: actionMenu
            anchors.fill: parent
            z: -1
            color: Theme.rgba(Theme.highlightDimmerColor, 1)
            border.width: 1
            border.color: Theme.rgba(Theme.primaryColor, 0.25)
        }
        property bool hintHeld: false
        onPressAndHold: if (_highlightedItem && _highlightedItem.enabled) {
            hintHeld = true
            Hints.show(_highlightedItem, _highlightedItem.text)
        }
        Connections { target: actionMenu; onPressed: actionMenu.hintHeld = false }
        Repeater {
            model: actions.entries
            IconMenuItem {
                objectName: "editorAction-" + modelData.action
                text: modelData.text
                icon.source: "image://theme/" + modelData.icon
                icon.rotation: modelData.action === "gap" ? 90 : 0
                enabled: ["key-add", "duplicate", "gap"].indexOf(modelData.action) >= 0 ? actions.canAddKey
                    : modelData.action === "row-add" ? actions.canAddRow
                    : modelData.action === "row-remove" ? actions.canDeleteRow
                    : modelData.action === "up" ? actions.canMoveUp
                    : modelData.action === "down" ? actions.canMoveDown : true
                onClicked: if (!actionMenu.hintHeld) actions.actionRequested(modelData.action)
            }
        }
    }
}
