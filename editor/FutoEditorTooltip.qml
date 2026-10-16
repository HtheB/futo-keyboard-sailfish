import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: hint
    objectName: "editorToolTip"
    anchors.fill: parent
    z: 1000
    property bool shown: false
    property var sourceItem: null
    property string text: ""
    visible: opacity > 0
    enabled: false
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
    onShownChanged: if (!shown) dismiss.stop()
    function show(source, label) {
        sourceItem = source; text = label
        var point = source.mapToItem(hint, 0, 0)
        bubble.x = Math.max(Theme.paddingSmall, Math.min(width - bubble.width - Theme.paddingSmall, point.x + (source.width - bubble.width) / 2))
        var above = point.y - bubble.height - Theme.paddingSmall
        bubble.y = Math.max(Theme.paddingSmall, Math.min(height - bubble.height - Theme.paddingSmall, above >= Theme.paddingSmall ? above : point.y + source.height + Theme.paddingSmall))
        shown = true; dismiss.restart()
    }
    onVisibleChanged: if (!visible) shown = false
    Connections {
        target: Qt.application
        onStateChanged: if (Qt.application.state !== Qt.ApplicationActive) hint.shown = false
    }
    Timer {
        id: dismiss
        interval: 1800
        onTriggered: {
            if (hint.sourceItem && (hint.sourceItem.pressed || hint.sourceItem.down)) restart()
            else hint.shown = false
        }
    }
    Rectangle {
        id: bubble
        width: Math.min(hint.width - 2 * Theme.paddingSmall, Math.max(Theme.itemSizeMedium, caption.implicitWidth + 2 * Theme.paddingLarge))
        height: caption.implicitHeight + 2 * Theme.paddingMedium
        radius: Theme.paddingSmall
        color: Theme.rgba(Theme.highlightDimmerColor, 1)
        border.width: 1; border.color: Theme.rgba(Theme.primaryColor, 0.25)
        Label {
            id: caption
            anchors.centerIn: parent
            width: Math.min(implicitWidth, hint.width - 2 * Theme.paddingSmall - 2 * Theme.paddingLarge)
            text: hint.text; textFormat: Text.PlainText; wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.primaryColor
        }
    }
}
