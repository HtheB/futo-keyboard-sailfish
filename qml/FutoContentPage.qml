/* Clean category entry point for optional downloadable content. */
import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page
    allowedOrientations: Orientation.All

    function openCategory(kind, title) {
        pageStack.push(Qt.resolvedUrl("FutoContentListPage.qml"), {
            "packKind": kind,
            "pageTitle": title
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

        Column {
            id: content
            width: parent.width

            PageHeader { title: qsTr("Downloadable content") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Install only the content you use. Every pack can be removed "
                           + "and installed again later.")
            }

            SectionHeader { text: qsTr("Content packs") }

            FutoSettingsMenuItem {
                width: parent.width
                text: qsTr("Emoji styles")
                iconSource: "file:///usr/share/futo-keyboard-sailfish/icons/icon-m-emoji.svg"
                onClicked: page.openCategory("emoji", qsTr("Emoji styles"))
            }

            FutoSettingsMenuItem {
                width: parent.width
                text: qsTr("Dictionaries")
                iconSource: "image://theme/icon-m-text-input"
                onClicked: page.openCategory("dictionary", qsTr("Dictionaries"))
            }

            FutoSettingsMenuItem {
                width: parent.width
                text: qsTr("Offline voice")
                iconSource: "image://theme/icon-m-browser-microphone"
                onClicked: page.openCategory("voice", qsTr("Offline voice"))
            }
        }

        VerticalScrollDecorator {}
    }
}
