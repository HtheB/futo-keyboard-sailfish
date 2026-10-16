import QtQuick 2.0
import Sailfish.Silica 1.0

BackgroundItem {
    id: root

    property alias text: menuLabel.text
    property alias iconSource: menuIcon.source
    property Component iconComponent
    property real iconScale: 1.0
    property bool showArrow: true

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
        visible: !customIcon.item
    }

    Loader {
        id: customIcon
        anchors.fill: menuIcon
        scale: root.iconScale
        active: root.iconComponent !== null
        sourceComponent: root.iconComponent
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
        visible: root.showArrow
        width: root.showArrow ? Theme.iconSizeMedium : 0
        height: width
        source: "image://theme/icon-m-right"
        highlighted: root.highlighted
    }
}
