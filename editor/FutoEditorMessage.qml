import QtQuick 2.6
import Sailfish.Silica 1.0

Rectangle {
    id: banner
    property string text: ""
    property bool error: true
    property bool dismissible: false
    signal dismissed()
    implicitHeight: Math.max(caption.implicitHeight, error ? warning.height : 0,
                             dismissible ? closeButton.height : 0) + 2 * Theme.paddingSmall
    height: implicitHeight
    radius: Theme.paddingSmall
    color: error ? "#d9a02020" : "transparent"
    Icon {
        id: warning
        objectName: "editorErrorWarning"
        anchors.left: parent.left; anchors.leftMargin: Theme.paddingMedium
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconSizeSmall; height: width
        source: "image://theme/icon-s-warning"
        color: "white"
        visible: banner.error
    }
    Label {
        id: caption
        objectName: "editorMessageText"
        anchors.left: banner.error ? warning.right : parent.left
        anchors.leftMargin: Theme.paddingMedium
        anchors.right: banner.dismissible ? closeButton.left : parent.right
        anchors.rightMargin: Theme.paddingMedium
        anchors.verticalCenter: parent.verticalCenter
        text: banner.text; textFormat: Text.PlainText; wrapMode: Text.Wrap
        font.pixelSize: Theme.fontSizeExtraSmall
        color: banner.error ? "white" : Theme.secondaryColor
    }
    FutoEditorTool {
        id: closeButton
        objectName: "editorHintClose"
        anchors.right: parent.right; anchors.rightMargin: Theme.paddingSmall
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.itemSizeExtraSmall; height: width
        icon.source: "image://theme/icon-m-close"
        icon.width: Theme.iconSizeSmall; icon.height: Theme.iconSizeSmall
        icon.color: banner.error ? "white" : Theme.primaryColor
        visible: banner.dismissible
        actionId: "close"; description: qsTr("Dismiss message")
        onClicked: banner.dismissed()
    }
}
