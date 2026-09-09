/* Maintenance actions for FUTO Keyboard settings. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.DBus 2.0

Page {
    id: page
    allowedOrientations: Orientation.All

    property QtObject settingsPage
    property string statusText: ""


    DBusInterface {
        id: helper
        bus: DBus.SessionBus
        service: "org.hb.FutoKeyboard1"
        path: "/org/hb/FutoKeyboard1"
        iface: "org.hb.FutoKeyboard1"
    }

    // The removal takes this page away with it, so there is nothing to show on
    // success. A message means it did not happen, and the keyboard is still
    // here to show it.
    function uninstallKeyboard() {
        page.statusText = qsTr("Removing FUTO Keyboard")
        helper.typedCall("UninstallKeyboard", [], function(message) {
            page.statusText = String(message || "") === ""
                    ? qsTr("FUTO Keyboard removed")
                    : String(message)
        }, function() {
            page.statusText = qsTr("Could not remove FUTO Keyboard")
        })
    }

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

                Column {
                    id: resetLabels
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.horizontalPageMargin
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

                onClicked: Remorse.popupAction(page, qsTr("Removing"), function() {
                    page.uninstallKeyboard()
                })

                Column {
                    id: uninstallLabels
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.horizontalPageMargin
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
                text: page.statusText
                visible: text !== ""
            }
        }
    }
}
