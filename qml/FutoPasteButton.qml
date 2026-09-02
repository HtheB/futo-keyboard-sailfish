// Paste the current system clipboard, with an explicit two-step clear action.
import QtQuick 2.6
import Sailfish.Silica 1.0
import com.jolla.keyboard 1.0

IconButton {
    id: root

    property var handler
    property bool clearMode: false

    signal pasteRequested()

    visible: Clipboard.hasText
    icon.source: clearMode
            ? "image://theme/icon-m-input-remove"
            : "image://theme/icon-m-clipboard"

    function cancelClearMode() {
        clearTimer.stop()
        clearMode = false
    }

    function clearCurrentClipboard() {
        Clipboard.text = ""
        cancelClearMode()
    }

    onClicked: {
        if (clearMode)
            clearCurrentClipboard()
        else
            pasteRequested()
    }

    onPressAndHold: {
        if (Clipboard.hasText) {
            clearMode = true
            clearTimer.restart()
        }
    }

    Connections {
        target: Clipboard
        onTextChanged: {
            if (!Clipboard.hasText)
                root.cancelClearMode()
        }
    }

    Connections {
        target: root.handler
        ignoreUnknownSignals: true
        onTypingContinued: root.cancelClearMode()
    }

    Timer {
        id: clearTimer
        interval: 3000
        repeat: false
        onTriggered: root.cancelClearMode()
    }
}
