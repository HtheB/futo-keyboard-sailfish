import QtQuick 2.6
import Sailfish.Silica 1.0

CoverBackground {
    id: cover
    clip: true
    Icon {
        objectName: "coverAppIcon"
        anchors.centerIn: parent
        width: cover.width * 1.75; height: width
        source: "/usr/share/futo-keyboard-sailfish/icons/futo-keyboard-cover.svg"
        sourceSize.width: width
        sourceSize.height: height
        fillMode: Image.PreserveAspectFit
        color: Theme.primaryColor
        rotation: -18
        opacity: 0.10
        smooth: true
    }
    Column {
        objectName: "coverTitle"
        anchors.centerIn: parent
        width: cover.width * 0.9
        spacing: cover.width / 120
        Label {
            width: parent.width
            text: "FUTO"
            textFormat: Text.PlainText
            color: Theme.primaryColor
            font.pixelSize: cover.width / 6
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }
        Label {
            width: parent.width
            text: qsTr("Layout Editor")
            textFormat: Text.PlainText
            color: Theme.primaryColor
            font.pixelSize: cover.width * 27 / 240
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
