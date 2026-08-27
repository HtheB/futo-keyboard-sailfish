/* Port credit and the ten-tap entry point for the hidden memorial. */
import QtQuick 2.0
import Sailfish.Silica 1.0

Item {
    id: credit

    property Item memorial: null

    width: parent.width
    height: creditColumn.height + 3 * Theme.paddingLarge

    Column {
        id: creditColumn
        anchors.centerIn: parent
        spacing: Theme.paddingSmall

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Ported by")
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "HtheB"
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.highlightColor
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (credit.memorial)
                credit.memorial.registerTap()
        }
    }
}
