import QtQuick 2.0
import Sailfish.Silica 1.0

BackgroundItem {
    id: root

    property alias text: menuLabel.text
    property alias iconSource: menuIcon.source
    property real iconScale: 1.0

    height: Theme.itemSizeLarge

    Icon {
        id: menuIcon
        anchors {
            left: parent.left
            leftMargin: Theme.horizontalPageMargin
            verticalCenter: parent.verticalCenter
        }
        width: Theme.iconSizeMedium
        height: width
        scale: root.iconScale
        highlighted: root.highlighted
    }

    Label {
        id: menuLabel
        anchors {
            left: menuIcon.right
            leftMargin: Theme.paddingLarge
            right: disclosureIcon.left
            rightMargin: Theme.paddingMedium
            verticalCenter: parent.verticalCenter
        }
        color: root.highlighted ? Theme.highlightColor : Theme.primaryColor
        truncationMode: TruncationMode.Fade
    }

    Icon {
        id: disclosureIcon
        anchors {
            right: parent.right
            rightMargin: Theme.horizontalPageMargin
            verticalCenter: parent.verticalCenter
        }
        width: Theme.iconSizeMedium
        height: width
        source: "image://theme/icon-m-right"
        highlighted: root.highlighted
    }
}
