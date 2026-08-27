/* Inline entry loaded by Sailfish's stock Settings -> Text input page. */
import QtQuick 2.0
import Sailfish.Silica 1.0

Column {
    width: parent.width
    height: childrenRect.height
    spacing: Theme.paddingSmall

    SectionHeader { text: qsTr("FUTO Keyboard") }

    FutoSettingsMenuItem {
        width: parent.width
        text: qsTr("FUTO Keyboard settings")
        iconSource: "image://theme/icon-m-keyboard"
        onClicked: pageStack.push(Qt.resolvedUrl("main.qml"))
    }
}
