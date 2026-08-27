/*
 * Ten quick taps on the HtheB credit reveal this memorial.  Its timing and
 * trailing-tap protection intentionally match the Live Wallpaper easter egg.
 */
import QtQuick 2.0
import Sailfish.Silica 1.0

Rectangle {
    id: memorial

    property int taps: 0
    property bool dismissable: false

    function registerTap() {
        taps = taps + 1
        tapReset.restart()
        if (taps >= 10) {
            taps = 0
            tapReset.stop()
            reveal()
        }
    }

    function reveal() {
        dismissable = false
        opacity = 1
        hideTimer.restart()
        armTimer.restart()
    }

    anchors.fill: parent
    color: Theme.rgba(Theme.overlayBackgroundColor, 0.92)
    opacity: 0
    visible: opacity > 0.01

    onOpacityChanged: {
        if (opacity <= 0.01)
            dismissable = false
    }

    Behavior on opacity {
        FadeAnimation { duration: 700 }
    }

    Timer {
        id: tapReset
        interval: 800
        onTriggered: memorial.taps = 0
    }

    Timer {
        id: armTimer
        interval: 2500
        onTriggered: memorial.dismissable = true
    }

    Timer {
        id: hideTimer
        interval: 6000
        onTriggered: memorial.opacity = 0
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.horizontalPageMargin
        spacing: Theme.paddingLarge

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("In Memoriam")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.secondaryHighlightColor
        }

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Kivi"
            font.pixelSize: Theme.fontSizeExtraLarge
            font.family: Theme.fontFamilyHeading
            color: Theme.highlightColor
        }

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "2014 – 2023"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.secondaryHighlightColor
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: memorial.opacity > 0.01
        onClicked: {
            if (memorial.dismissable)
                memorial.opacity = 0
        }
    }
}
