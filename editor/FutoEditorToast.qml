import QtQuick 2.6
import Sailfish.Silica 1.0

Rectangle {
    id: toast
    property string message: ""
    property bool presented: false
    property bool pageActive: true
    property int duration: 3000
    anchors.horizontalCenter: parent.horizontalCenter
    y: Theme.itemSizeSmall + Theme.paddingLarge
    z: 2000
    width: Math.min(parent.width - 2 * Theme.horizontalPageMargin, Theme.itemSizeLarge * 5)
    height: label.height + 2 * Theme.paddingMedium
    radius: Theme.paddingMedium
    color: Theme.highlightDimmerColor
    opacity: presented ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 180 } }
    function show(text) {
        if (!pageActive || !text) return
        message = text
        presented = true
        expiry.restart()
    }
    function dismiss() { expiry.stop(); presented = false }
    onPageActiveChanged: if (!pageActive) dismiss()
    Timer { id: expiry; interval: toast.duration; onTriggered: toast.presented = false }
    Label {
        id: label
        x: Theme.paddingMedium; y: Theme.paddingMedium
        width: parent.width - 2 * x
        text: toast.message; textFormat: Text.PlainText
        color: Theme.primaryColor; font.pixelSize: Theme.fontSizeSmall
        horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
    }
}
