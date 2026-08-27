import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0

Page {
    id: page
    allowedOrientations: Orientation.All

    ConfigurationGroup {
        id: settings
        path: "/sailfish/text_input/futo_keyboard"
        property bool spacebarCursorControlEnabled: true
        property bool swipeDeleteEnabled: true
        property bool swipeTypingEnabled: true
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
            PageHeader { title: qsTr("Typing gestures") }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.swipeTypingEnabled
                text: qsTr("Swipe across letters to type")
                description: qsTr("Release your finger to insert the best matching word. "
                                  + "Alternatives appear in the suggestion strip.")
                onClicked: settings.swipeTypingEnabled = !checked
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.spacebarCursorControlEnabled
                text: qsTr("Swipe Space to move the cursor")
                description: qsTr("Swipe downward on Space to close the keyboard.")
                onClicked: settings.spacebarCursorControlEnabled = !checked
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.swipeDeleteEnabled
                text: qsTr("Swipe Backspace to delete words")
                onClicked: settings.swipeDeleteEnabled = !checked
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Swiping never changes to another Sailfish keyboard. Horizontal layout "
                           + "swiping is available only inside FUTO's visual layout editor.")
            }
        }
    }
}
