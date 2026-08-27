/* Opaque, reusable keyboard test field for every FUTO settings subpage. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Silica.Background 1.0
import Nemo.Configuration 1.0

Item {
    id: panel

    property bool resizeEnabled: false
    property Item pageItem
    height: handle.height + testInput.height
    z: 100

    ConfigurationGroup {
        id: settings
        path: "/sailfish/text_input/futo_keyboard"
        property real keyboardHeightScale: 1.0
    }

    KeyboardBackground {
        anchors.fill: parent
    }

    Item {
        id: handle
        anchors.top: parent.top
        width: parent.width
        height: panel.resizeEnabled ? Theme.itemSizeSmall / 2 : Theme.paddingSmall

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.horizontalPageMargin
            anchors.rightMargin: Theme.horizontalPageMargin
            height: panel.resizeEnabled ? 3 : 1
            radius: height / 2
            color: panel.resizeEnabled ? Theme.highlightColor : Theme.secondaryColor
        }

        Rectangle {
            anchors.centerIn: parent
            width: Theme.itemSizeSmall
            height: Theme.paddingSmall
            radius: height / 2
            color: Theme.highlightColor
            visible: panel.resizeEnabled
        }

        MouseArea {
            anchors.fill: parent
            enabled: panel.resizeEnabled
            property real startY
            property real startScale

            onPressed: {
                startY = mapToItem(panel.pageItem || panel.parent, mouse.x, mouse.y).y
                startScale = Number(settings.keyboardHeightScale)
            }
            onPositionChanged: {
                if (!pressed)
                    return
                var currentY = mapToItem(panel.pageItem || panel.parent, mouse.x, mouse.y).y
                var nextScale = startScale + (startY - currentY) / 300
				nextScale = Math.max(0.50, Math.min(1.30, nextScale))
                settings.keyboardHeightScale = Math.round(nextScale * 100) / 100
            }
        }
    }

    TextField {
        id: testInput
        anchors.top: handle.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        label: qsTr("Keyboard test")
        placeholderText: qsTr("Type here to test FUTO")
    }
}
