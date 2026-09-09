/* Confirmation asked before FUTO Keyboard removes itself. */
import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: dialog
    allowedOrientations: Orientation.All

    // Let the dialog do the navigating. Replacing the stack from an accepted
    // handler runs a second navigation against the one the dialog is already
    // performing, which leaves both pages on screen at once.
    acceptDestination: Qt.resolvedUrl("FutoUninstallProgressPage.qml")
    acceptDestinationAction: PageStackAction.Replace

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge

        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingLarge

            DialogHeader {
                acceptText: qsTr("Uninstall")
                cancelText: qsTr("Keep")
            }

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
                text: qsTr("The keyboard, its settings, and everything it has "
                           + "learned are removed from this device. Downloaded "
                           + "dictionaries, voice models and emoji are removed "
                           + "as well. Sailfish switches back to its own "
                           + "keyboard.")
            }

        }
    }
}
