/* Confirmation asked before FUTO Keyboard removes itself.
 *
 * This deliberately is a Page, not a Silica Dialog. Dialogs can be accepted
 * with Sailfish's forward navigation gesture, which is too easy to trigger
 * while reading a destructive-action warning. Removal starts only from the
 * explicit Uninstall button below.
 */
import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page
    allowedOrientations: Orientation.All
    property bool startingRemoval: false
    property bool removeSettings: true
    property bool removeLearned: true
    property bool removePasswords: true
    property bool removeContent: true

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge
        clip: true
        VerticalScrollDecorator { flickable: parent }

        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader { title: qsTr("Uninstall FUTO Keyboard") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.primaryColor
                text: qsTr("Uninstall FUTO Keyboard?")
                font.pixelSize: Theme.fontSizeLarge
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Choose which FUTO data should also be deleted. "
                           + "Anything you leave unchecked is kept for a future "
                           + "reinstall. Exported backups in Documents are "
                           + "always kept.")
            }

            SectionHeader { text: qsTr("Delete during uninstall") }

            Column {
                width: parent.width

                TextSwitch {
                    width: parent.width
                    automaticCheck: false
                    text: qsTr("Settings and interface preferences")
                    description: qsTr("Languages, layouts, gestures, appearance, emoji "
                                      + "history and other keyboard options")
                    checked: page.removeSettings
                    onClicked: page.removeSettings = !checked
                }

                TextSwitch {
                    width: parent.width
                    automaticCheck: false
                    text: qsTr("Learned data and clipboard history")
                    description: qsTr("Learned words, context, URLs and FUTO clipboard entries")
                    checked: page.removeLearned
                    onClicked: page.removeLearned = !checked
                }

                TextSwitch {
                    width: parent.width
                    automaticCheck: false
                    text: qsTr("Saved passwords")
                    description: qsTr("Accounts stored in FUTO's password vault")
                    checked: page.removePasswords
                    onClicked: page.removePasswords = !checked
                }

                TextSwitch {
                    width: parent.width
                    automaticCheck: false
                    text: qsTr("Downloaded content")
                    description: qsTr("Dictionaries, emoji styles, voice models, swipe data "
                                      + "and prediction models")
                    checked: page.removeContent
                    onClicked: page.removeContent = !checked
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("Sailfish switches back to its own keyboard. Save any open "
                           + "work before continuing: uninstalling FUTO restarts the "
                           + "Sailfish home screen and closes running applications.")
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Uninstall")
                enabled: !page.startingRemoval
                onClicked: {
                    if (page.startingRemoval)
                        return
                    Remorse.popupAction(
                                page,
                                qsTr("Uninstalling FUTO Keyboard"),
                                function() {
                                    page.startingRemoval = true
                                    pageStack.replace(Qt.resolvedUrl(
                                        "FutoUninstallProgressPage.qml"), {
                                        "removeSettings": page.removeSettings,
                                        "removeLearned": page.removeLearned,
                                        "removePasswords": page.removePasswords,
                                        "removeContent": page.removeContent
                                    })
                                })
                }
            }

        }
    }
}
