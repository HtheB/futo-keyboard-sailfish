import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: dialog

    property string contentName: ""
    property string explanation: ""

    canAccept: true

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height

        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingLarge

            DialogHeader {
                dialog: dialog
                acceptText: qsTr("Open downloads")
                cancelText: qsTr("Cancel")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeLarge
                text: qsTr("Download %1?").arg(dialog.contentName)
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                text: dialog.explanation
            }
        }

        VerticalScrollDecorator {}
    }
}
