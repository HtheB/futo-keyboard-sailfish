/* Secure saved-account chooser shown inside the keyboard surface. */
import QtQuick 2.0
import Sailfish.Silica 1.0

Item {
    id: panel

    property Item targetLayout
    property QtObject targetHandler

    Rectangle {
        anchors.fill: parent
        // Match the normal raised keyboard surface instead of exposing the
        // compositor's solid black background while the key rows are hidden.
        color: Theme.rgba(Theme.primaryColor, 0.12)
    }

    Item {
        id: header
        anchors.top: parent.top
        width: parent.width
        height: targetLayout ? targetLayout.keyHeight : Theme.itemSizeSmall

        IconButton {
            id: backButton
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            icon.source: "image://theme/icon-m-back"
            onClicked: {
                if (targetHandler) {
                    targetHandler.playOptionFeedback()
                    targetHandler.cancelSavedCredentialChooser()
                } else if (targetLayout) {
                    targetLayout.hideSavedCredentialChooser()
                }
            }
        }

        Label {
            anchors.left: backButton.right
            anchors.right: keyboardButton.left
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("Saved logins")
            color: Theme.highlightColor
            font.pixelSize: Theme.fontSizeMedium
            truncationMode: TruncationMode.Fade
        }

        BackgroundItem {
            id: keyboardButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(Theme.itemSizeMedium, keyboardLabel.implicitWidth
                            + 2 * Theme.paddingMedium)
            height: parent.height
            onClicked: {
                if (targetHandler) {
                    targetHandler.playOptionFeedback()
                    targetHandler.cancelSavedCredentialChooser()
                } else if (targetLayout) {
                    targetLayout.hideSavedCredentialChooser()
                }
            }

            Label {
                id: keyboardLabel
                anchors.centerIn: parent
                text: qsTr("ABC")
                color: parent.highlighted ? Theme.highlightColor
                                          : Theme.primaryColor
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    SilicaListView {
        id: accountList
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: targetHandler ? targetHandler.savedCredentialModel : null

        delegate: BackgroundItem {
            id: accountDelegate
            width: accountList.width
            height: Math.max(Theme.itemSizeMedium,
                             usernameLabel.implicitHeight + Theme.paddingLarge)
            onClicked: {
                if (!targetHandler)
                    return
                targetHandler.playOptionFeedback()
                targetHandler.selectSavedCredential(model.entryId,
                                                    model.entryUsername)
            }

            Icon {
                id: accountIcon
                anchors.left: parent.left
                anchors.leftMargin: Theme.paddingLarge
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconSizeSmall
                height: width
                source: "image://theme/icon-m-device-lock"
                color: accountDelegate.highlighted ? Theme.highlightColor
                                                   : Theme.primaryColor
            }

            Label {
                id: usernameLabel
                anchors.left: accountIcon.right
                anchors.right: selectIcon.left
                anchors.leftMargin: Theme.paddingMedium
                anchors.rightMargin: Theme.paddingMedium
                anchors.verticalCenter: parent.verticalCenter
                text: model.entryText
                textFormat: Text.PlainText
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeMedium
                color: accountDelegate.highlighted ? Theme.highlightColor
                                                   : Theme.primaryColor
            }

            Icon {
                id: selectIcon
                anchors.right: parent.right
                anchors.rightMargin: Theme.paddingLarge
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconSizeSmall
                height: width
                source: "image://theme/icon-m-right"
                color: accountDelegate.highlighted ? Theme.highlightColor
                                                   : Theme.secondaryColor
            }
        }

        ViewPlaceholder {
            enabled: accountList.count === 0
            text: qsTr("No saved logins for this site or app")
            hintText: qsTr("Tap ABC to return to the keyboard")
        }

        VerticalScrollDecorator {}
    }
}
