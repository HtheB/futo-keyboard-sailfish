/* A saved-login offer that follows the finger and dismisses without opening it. */
import QtQuick 2.0
import Sailfish.Silica 1.0

Item {
    id: prompt
    property string text: ""
    property string contextKey: ""
    property bool dismissible: true
    property real swipeOffset: 0
    property bool dragging: false
    property bool dismissing: false
    property bool tapAbandoned: false
    property real pressX: 0
    property real pressY: 0
    property string pressedContextKey: ""
    signal activated()
    signal dismissRequested()
    clip: true

    function isHorizontalSwipe(dx, dy, startDistance) {
        return Math.abs(dx) >= startDistance && Math.abs(dx) > Math.abs(dy)
    }

    function dismissalReached(dx, availableWidth, startDistance) {
        return Math.abs(dx) >= Math.max(startDistance * 2, availableWidth * 0.22)
    }

    function resetGesture() {
        // Clear this before stop(): cancellation must never dismiss a new offer.
        dismissing = false
        slide.stop()
        swipeOffset = 0
        dragging = false
        tapAbandoned = false
        pressedContextKey = ""
    }

    onContextKeyChanged: resetGesture()
    onVisibleChanged: if (!visible) resetGesture()
    onDismissibleChanged: if (!dismissible) resetGesture()

    Item {
        x: prompt.swipeOffset
        width: parent.width
        height: parent.height
        opacity: 1 - Math.min(1, Math.abs(prompt.swipeOffset) / Math.max(1, width))

        Rectangle {
            anchors.fill: parent
            color: Theme.highlightBackgroundColor
            opacity: 0.18
            visible: touch.pressed && !prompt.dragging
        }
        Row {
            anchors.centerIn: parent
            spacing: Theme.paddingMedium
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconSizeSmall
                height: width
                source: "image://theme/icon-m-device-lock"
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: prompt.text
                color: touch.pressed && !prompt.dragging
                       ? Theme.highlightColor : Theme.primaryColor
            }
        }
    }

    NumberAnimation {
        id: slide
        target: prompt
        property: "swipeOffset"
        duration: 180
        easing.type: Easing.OutCubic
        onStopped: {
            if (!prompt.dismissing) return
            prompt.dismissing = false
            if (prompt.visible && prompt.dismissible
                    && prompt.pressedContextKey === prompt.contextKey)
                prompt.dismissRequested()
            else
                prompt.resetGesture()
        }
    }

    MouseArea {
        id: touch
        anchors.fill: parent
        preventStealing: true
        enabled: !slide.running
        onPressed: {
            prompt.pressX = mouse.x
            prompt.pressY = mouse.y
            prompt.pressedContextKey = prompt.contextKey
            prompt.tapAbandoned = false
            prompt.dragging = false
        }
        onPositionChanged: {
            var dx = mouse.x - prompt.pressX
            var dy = mouse.y - prompt.pressY
            if (Math.max(Math.abs(dx), Math.abs(dy)) >= Theme.startDragDistance)
                prompt.tapAbandoned = true
            if (prompt.dismissible && !prompt.dragging
                    && prompt.isHorizontalSwipe(dx, dy, Theme.startDragDistance))
                prompt.dragging = true
            if (prompt.dragging)
                prompt.swipeOffset = dx
        }
        onReleased: {
            if (prompt.pressedContextKey !== prompt.contextKey) return
            if (prompt.dragging) {
                prompt.dismissing = prompt.dismissible && prompt.dismissalReached(
                            prompt.swipeOffset, prompt.width, Theme.startDragDistance)
                slide.to = prompt.dismissing
                        ? (prompt.swipeOffset < 0 ? -prompt.width : prompt.width) : 0
                slide.restart()
            } else if (!prompt.tapAbandoned) {
                prompt.activated()
            }
        }
        onCanceled: prompt.resetGesture()
    }
}
