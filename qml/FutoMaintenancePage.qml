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
