/* Maintenance actions for FUTO Keyboard settings. */
import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page
    allowedOrientations: Orientation.All

    property QtObject settingsPage
    property string statusText: ""


    FutoSettingsTestPanel {
        id: testPanel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        pageItem: page
    }

    SilicaFlickable {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: testPanel.top
        contentHeight: content.height + Theme.paddingLarge
        VerticalScrollDecorator { flickable: parent }

        Column {
            id: content
            width: parent.width

            PageHeader { title: qsTr("Maintenance") }

            BackgroundItem {
                width: parent.width
                height: Math.max(Theme.itemSizeLarge,
                                 resetLabels.height + 2 * Theme.paddingMedium)

                onClicked: Remorse.popupAction(page, qsTr("Restoring defaults"), function() {
                    if (page.settingsPage)
                        page.settingsPage.resetDefaults()
                    page.statusText = qsTr("Defaults restored")
                })

                Icon {
                    id: resetIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.iconSizeMedium
                    height: width
                    source: "image://theme/icon-m-refresh"
                    color: parent.highlighted ? Theme.highlightColor
                                              : Theme.primaryColor
                }

                Column {
                    id: resetLabels
                    anchors.left: resetIcon.right
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.paddingLarge
                    anchors.rightMargin: Theme.horizontalPageMargin

                    Label {
                        width: parent.width
                        text: qsTr("Restore default settings")
                        color: parent.parent.highlighted
                               ? Theme.highlightColor : Theme.primaryColor
                        truncationMode: TruncationMode.Fade
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Reset FUTO Keyboard options while keeping learned words and clipboard data.")
                        color: parent.parent.highlighted
                               ? Theme.secondaryHighlightColor : Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                        wrapMode: Text.Wrap
                    }
                }
            }


            BackgroundItem {
                width: parent.width
                height: Math.max(Theme.itemSizeLarge,
                                 uninstallLabels.height + 2 * Theme.paddingMedium)

                // The dialog replaces itself with the progress page when it
                // is accepted, so there is nothing to arrange here.
                onClicked: pageStack.push(
                               Qt.resolvedUrl("FutoUninstallDialog.qml"))

                Icon {
                    id: uninstallIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.iconSizeMedium
                    height: width
                    source: "image://theme/icon-m-reset"
                    color: parent.highlighted ? Theme.highlightColor
                                              : Theme.primaryColor
                }

                Column {
                    id: uninstallLabels
                    anchors.left: uninstallIcon.right
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.paddingLarge
                    anchors.rightMargin: Theme.horizontalPageMargin

                    Label {
                        width: parent.width
                        text: qsTr("Uninstall FUTO Keyboard")
                        color: parent.parent.highlighted
                               ? Theme.highlightColor : Theme.primaryColor
                        truncationMode: TruncationMode.Fade
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Remove the keyboard from this device. Sailfish asks you to "
                                   + "confirm, and switches back to its own keyboard.")
                        color: parent.parent.highlighted
                               ? Theme.secondaryHighlightColor : Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                        wrapMode: Text.Wrap
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                horizontalAlignment: Text.AlignHCenter
                color: Theme.highlightColor
                // Failures arrive as whole sentences from the package tools,
                // which run off the screen unless they are allowed to wrap.
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                text: page.statusText
                visible: text !== ""
            }
        }
    }
}
