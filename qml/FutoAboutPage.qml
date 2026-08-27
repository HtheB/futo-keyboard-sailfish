/* About page for the independent Sailfish OS FUTO Keyboard port. */
import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    readonly property string keyboardVersion: "0.1.0"

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: aboutColumn.height + Theme.paddingLarge

        VerticalScrollDecorator {}

        Column {
            id: aboutColumn
            width: page.width
            spacing: Theme.paddingMedium

            PageHeader { title: qsTr("About") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("FUTO Keyboard")
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.highlightColor
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Version %1").arg(page.keyboardVersion)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: qsTr("An independent native Sailfish OS port. This is not an official FUTO product.")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
            }

            FutoCredit { memorial: aboutMemorial }
        }
    }

    FutoMemorial { id: aboutMemorial }
}
