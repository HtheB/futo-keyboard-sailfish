/* One real desktop-key event, shared by the full page and optional toolbar. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import com.jolla.keyboard 1.0
import ".."

FunctionKey {
    id: desktopKey

    property Item targetLayout
    property string keyId: ""
    property bool compact: false
    property bool manualFeedbackOnPress: true
    property bool repeatStarted: false
    property bool quickSettingsHoldTriggered: false
    readonly property int modifierState: keyboard.inputHandler
            && keyboard.inputHandler.desktopModifierState
            ? keyboard.inputHandler.desktopModifierState(keyId) : 0
    readonly property bool repeatable: [
        "left", "right", "up", "down", "delete", "backspace",
        "pageup", "pagedown", "home", "end", "space"
    ].indexOf(keyId) >= 0

    caption: displayLabel()
    keyType: KeyType.UnknownKey
    background.visible: false
    showPopper: false

    function displayLabel() {
        if (keyId === "abc")
            return targetLayout && targetLayout.letterPageLabel
                    ? targetLayout.letterPageLabel() : "ABC"
        if (keyId === "numbers")
            return targetLayout && targetLayout.numberPageLabel
                    ? targetLayout.numberPageLabel() : "123"
        if (keyId === "left") return "←"
        if (keyId === "right") return "→"
        if (keyId === "up") return "↑"
        if (keyId === "down") return "↓"
        if (keyId === "backspace") return "⌫"
        if (keyId === "enter") return "↵"
        if (keyId === "space") return "␣"
        if (keyId === "tab") return "⇥"
        if (keyId === "altgr") return "AltGr"
        if (keyId === "super") return ""
        if (keyId === "print") return "PrtSc"
        if (keyId === "insert") return "Ins"
        if (keyId === "delete") return "Del"
        if (keyId === "pageup") return "PgUp"
        if (keyId === "pagedown") return "PgDn"
        if (keyId === "numlock") return "Num"
        if (keyId === "scrolllock") return "Scroll"
        return keyId.length > 0
                ? keyId.charAt(0).toUpperCase() + keyId.slice(1) : ""
    }

    function activate() {
        if (keyId === "abc") {
            if (targetLayout && targetLayout.exitSymbolMode)
                targetLayout.exitSymbolMode()
            return
        }
        if (keyId === "numbers") {
            if (targetLayout && targetLayout.showFirstSymbolPage)
                targetLayout.showFirstSymbolPage()
            return
        }
        if (keyboard.inputHandler && keyboard.inputHandler.activateDesktopKey)
            keyboard.inputHandler.activateDesktopKey(keyId)
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: Math.max(1, Theme.paddingSmall / 2)
        visible: desktopKey.keyId !== "numbers" && desktopKey.keyId !== "abc"
        radius: Theme.paddingSmall
        z: -1
        color: desktopKey.modifierState > 0
               ? Theme.rgba(Theme.highlightColor,
                            desktopKey.modifierState === 2 ? 0.42 : 0.25)
               : Theme.rgba(desktopKey.palette.primaryColor,
                            desktopKey.pressed ? 0.24 : 0.11)
        border.width: desktopKey.modifierState > 0 ? 2 : 1
        border.color: desktopKey.modifierState > 0
                      ? Theme.highlightColor
                      : Theme.rgba(desktopKey.palette.primaryColor, 0.12)
    }

    Icon {
        anchors.centerIn: parent
        width: compact ? Theme.iconSizeExtraSmall : Theme.iconSizeSmall
        height: width
        visible: desktopKey.keyId === "super"
        source: "image://theme/icon-m-sailfish"
        color: desktopKey.modifierState > 0
               ? Theme.highlightColor : desktopKey.palette.primaryColor
    }

    Label {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Theme.paddingSmall
        anchors.topMargin: Theme.paddingSmall / 2
        visible: desktopKey.modifierState === 1
        text: "1×"
        color: Theme.highlightColor
        font.pixelSize: Theme.fontSizeTiny
    }

    // Match the familiar 123 key on the letter/symbol pages: the gear is a
    // discoverability hint that holding this key opens Quick Settings.
    Label {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Theme.paddingMedium
        anchors.topMargin: Theme.paddingSmall
        visible: desktopKey.keyId === "numbers"
        text: "⚙"
        color: desktopKey.palette.primaryColor
        font.pixelSize: Theme.fontSizeTiny
        opacity: 0.72
    }

    Label {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Theme.paddingSmall
        anchors.topMargin: Theme.paddingSmall / 2
        visible: desktopKey.modifierState === 2
        text: "∞"
        color: Theme.highlightColor
        font.pixelSize: Theme.fontSizeTiny
    }

    Timer {
        id: quickSettingsHoldTimer
        interval: 520
        repeat: false
        onTriggered: {
            desktopKey.quickSettingsHoldTriggered = true
            if (desktopKey.targetLayout
                    && desktopKey.targetLayout.showControlStrip)
                desktopKey.targetLayout.showControlStrip()
        }
    }

    Timer {
        id: repeatDelay
        interval: 460
        repeat: false
        onTriggered: {
            desktopKey.repeatStarted = true
            desktopKey.activate()
            repeatTimer.start()
        }
    }

    Timer {
        id: repeatTimer
        interval: 85
        repeat: true
        onTriggered: desktopKey.activate()
    }

    MouseArea {
        anchors.fill: parent
        // Let the Extra Keys flickable steal horizontal movement and Sailfish
        // steal a downward close gesture on the full Fn page. Horizontal
        // keyboard paging remains disabled by FutoKeyboardLayout.
        preventStealing: false

        onPressed: {
            desktopKey.pressed = true
            desktopKey.repeatStarted = false
            desktopKey.quickSettingsHoldTriggered = false
            if (keyboard.inputHandler && keyboard.inputHandler.playManualKeyFeedback)
                keyboard.inputHandler.playManualKeyFeedback(desktopKey, "option")
            // 123 behaves consistently on every page: a tap changes page,
            // while a hold opens the quick settings without leaving Fn first.
            if (desktopKey.keyId === "numbers")
                quickSettingsHoldTimer.restart()
            if (desktopKey.repeatable && desktopKey.keyId !== "numbers")
                repeatDelay.restart()
        }
        onReleased: {
            quickSettingsHoldTimer.stop()
            repeatDelay.stop()
            repeatTimer.stop()
            desktopKey.pressed = false
            if (desktopKey.keyId === "numbers") {
                if (!desktopKey.quickSettingsHoldTriggered)
                    desktopKey.activate()
            } else if (!desktopKey.repeatStarted) {
                desktopKey.activate()
            }
        }
        onCanceled: {
            quickSettingsHoldTimer.stop()
            repeatDelay.stop()
            repeatTimer.stop()
            desktopKey.pressed = false
        }
    }
}
