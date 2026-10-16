import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Share 1.0

Page {
    id: page
    allowedOrientations: Orientation.LandscapeMask
    property string filePath: ""
    property bool shareImmediately: false
    function share() {
        if (!filePath) return
        shareAction.resources = [filePath]
        shareAction.trigger()
    }
    onStatusChanged: if (status === PageStatus.Active && shareImmediately) {
        shareImmediately = false
        openShare.restart()
    }
    Timer { id: openShare; interval: 0; onTriggered: page.share() }
    ShareAction {
        id: shareAction
        objectName: "layoutShareAction"
        title: qsTr("Share keyboard layout")
        mimeType: "application/octet-stream"
    }
    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge
        VerticalScrollDecorator {}
        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingLarge
            PageHeader { title: qsTr("Layout exported") }
            Label {
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                text: qsTr("Your layout is saved in Documents/FUTO-Keyboard/Layouts.")
                textFormat: Text.PlainText; wrapMode: Text.Wrap
                color: Theme.primaryColor
            }
            Label {
                objectName: "exportedLayoutPath"
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                text: page.filePath
                textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere
                font.pixelSize: Theme.fontSizeSmall; color: Theme.secondaryColor
            }
            Button {
                objectName: "shareExportedLayoutButton"
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Share"); enabled: page.filePath !== ""
                onClicked: page.share()
            }
        }
    }
}
