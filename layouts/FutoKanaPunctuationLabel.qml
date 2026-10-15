/* Combined punctuation hint; the flick popup still shows each actual symbol. */
import QtQuick 2.0
import Sailfish.Silica 1.0

Item {
    id: mark
    property color color: Theme.primaryColor
    property real symbolPixelSize: height * 0.58
    clip: true

    Icon {
        anchors.centerIn: parent
        height: Math.min(parent.height, mark.symbolPixelSize * 1.15, parent.width * 80 / 100)
        width: height * 100 / 80
        sourceSize.width: width
        sourceSize.height: height
        source: "/usr/share/futo-keyboard-sailfish/icons/icon-m-kana-punctuation.svg"
        color: mark.color
    }
}
