import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page
    allowedOrientations: Orientation.LandscapeMask
    readonly property string donateUrl: "https://PayPal.me/HtheB"

    PageHeader { id: header; title: qsTr("About") }
    Item {
        id: branding
        objectName: "editorAboutBranding"
        anchors.left: parent.left; anchors.top: header.bottom; anchors.bottom: parent.bottom
        anchors.topMargin: Theme.paddingMedium; anchors.bottomMargin: Theme.paddingMedium
        width: parent.width * 0.46
        Column {
            id: brandColumn
            objectName: "editorAboutBrandColumn"
            anchors.centerIn: parent
            width: parent.width - 2 * Theme.horizontalPageMargin
            spacing: Theme.paddingMedium

            Icon {
                objectName: "editorAboutIcon"
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(Theme.iconSizeExtraLarge, branding.height * 0.27); height: width
                source: "/usr/share/futo-keyboard-sailfish/icons/futo-keyboard-cover.svg"
                sourceSize.width: Math.ceil(width * 3)
                sourceSize.height: Math.ceil(height * 3)
                fillMode: Image.PreserveAspectFit
                color: Theme.primaryColor
            }

            Label {
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("FUTO Layout Editor")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeLarge
                font.family: Theme.fontFamilyHeading
            }

            Item {
                objectName: "editorAuthorCredit"
                width: parent.width
                height: creditLabels.height + 2 * Theme.paddingMedium
                Column {
                    id: creditLabels
                    anchors.centerIn: parent
                    spacing: Theme.paddingSmall
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Made by")
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
                MouseArea { anchors.fill: parent; onClicked: memorial.registerTap() }
            }
        }
    }
    Item {
        id: details
        objectName: "editorAboutDetails"
        anchors.left: branding.right; anchors.right: parent.right
        anchors.top: header.bottom; anchors.bottom: parent.bottom
        anchors.topMargin: Theme.paddingMedium; anchors.bottomMargin: Theme.paddingMedium
        Column {
            objectName: "editorAboutDetailsColumn"
            anchors.centerIn: parent
            width: parent.width - 2 * Theme.horizontalPageMargin
            spacing: Theme.paddingLarge
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("Create, edit and share custom keyboard layouts for FUTO Keyboard on Sailfish OS.")
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeSmall
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("This editor is free.\nIf you enjoy it, you can support future work with a donation.")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
            }
            Button {
                objectName: "editorDonateButton"
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Donate")
                onClicked: Qt.openUrlExternally(page.donateUrl)
            }
        }
    }
    FutoMemorial { id: memorial }
}
