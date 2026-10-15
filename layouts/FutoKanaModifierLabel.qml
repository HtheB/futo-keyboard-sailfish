/* Compact Japanese voicing/small-kana icon shared by the key and popup. */
import QtQuick 2.0
import Sailfish.Silica 1.0

Item {
    id: mark
    property color color: Theme.primaryColor
    property real kanaPixelSize: height * 0.58
    clip: true

    Icon {
        anchors.centerIn: parent
        height: Math.min(parent.height, mark.kanaPixelSize * 1.10, parent.width * 80 / 128)
        width: height * 128 / 80
        sourceSize.width: width
        sourceSize.height: height
        source: "/usr/share/futo-keyboard-sailfish/icons/icon-m-kana-modifier.svg"
        color: mark.color
    }
}
