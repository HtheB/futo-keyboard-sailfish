/* Space-bar cursor gesture for the Sailfish FUTO layout. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import com.meego.maliitquick 1.0
import ".."

SpacebarKey {
    id: spaceKey

    property real pressX
    property real pressY
    property int cursorStepX
    property int cursorStepY
    property bool gestureMoved
	property bool cursorMode
	property bool keyboardDismissed
	// Keep a separate physical-touch flag.  A QML Timer callback can already be
	// queued when stop() is called during release/cancel; without this guard that
	// stale callback can re-enter cursor mode after the finger has gone away.
	property bool pointerDown
    property bool manualFeedbackOnPress: true
    property bool incognitoIndicatorVisible: false

    ConfigurationGroup {
        id: gestureSettings
        path: "/sailfish/text_input/futo_keyboard"
        property bool spacebarCursorControlEnabled: true
    }

	function activateCursorMode() {
		if (!pointerDown || cursorMode || keyboardDismissed)
			return
		cursorMode = true
		gestureMoved = true
		if (keyboard.inputHandler && keyboard.inputHandler.beginCursorMoveMode)
			keyboard.inputHandler.beginCursorMoveMode()
	}

	function updateCursorPosition(pointerX, pointerY) {
		if (!cursorMode || keyboardDismissed)
			return
		var horizontalThreshold = Math.max(Theme.paddingLarge, width / 12)
		// Vertical cursor movement changes whole lines, so it deliberately needs
		// much more travel than horizontal character movement.
		var verticalThreshold = Math.max(Theme.itemSizeLarge, height * 1.6)
		var nextStepX = Math.round((pointerX - pressX) / horizontalThreshold)
		var nextStepY = Math.round((pointerY - pressY) / verticalThreshold)
		var deltaX = nextStepX - cursorStepX
		var deltaY = nextStepY - cursorStepY
		if (deltaX === 0 && deltaY === 0)
			return
		cursorStepX = nextStepX
		cursorStepY = nextStepY
		if (keyboard.inputHandler && keyboard.inputHandler.moveCursor2D)
			keyboard.inputHandler.moveCursor2D(deltaX, deltaY)
		else if (deltaX !== 0 && keyboard.inputHandler
				&& keyboard.inputHandler.moveCursor)
			keyboard.inputHandler.moveCursor(deltaX)
	}

	Timer {
		id: cursorHoldTimer
		interval: 240
		repeat: false
		onTriggered: {
			spaceKey.activateCursorMode()
			spaceKey.updateCursorPosition(spaceMouseArea.mouseX,
			                              spaceMouseArea.mouseY)
		}
	}

    Icon {
        anchors {
            right: parent.right
            rightMargin: Theme.paddingMedium
            verticalCenter: parent.verticalCenter
        }
        z: 10
        width: Theme.iconSizeSmall
        height: width
        visible: spaceKey.incognitoIndicatorVisible
        source: "image://theme/icon-m-incognito"
        color: Theme.highlightColor
    }

    MouseArea {
		id: spaceMouseArea
        anchors.fill: parent
        enabled: gestureSettings.spacebarCursorControlEnabled
        preventStealing: true

        onPressed: {
			mouse.accepted = true
			spaceKey.pointerDown = true
            if (keyboard.inputHandler && keyboard.inputHandler.playManualKeyFeedback)
                keyboard.inputHandler.playManualKeyFeedback(spaceKey, "letter")
			if (keyboard.inputHandler && keyboard.inputHandler.beginSpacebarGesture)
				keyboard.inputHandler.beginSpacebarGesture()
            spaceKey.pressX = mouse.x
            spaceKey.pressY = mouse.y
            spaceKey.cursorStepX = 0
            spaceKey.cursorStepY = 0
            spaceKey.gestureMoved = false
			spaceKey.cursorMode = false
			spaceKey.keyboardDismissed = false
            spaceKey.pressed = true
			cursorHoldTimer.restart()
        }

        onPositionChanged: {
			var horizontalThreshold = Math.max(Theme.paddingLarge, width / 12)
			var horizontalDistance = mouse.x - spaceKey.pressX
			var verticalDistance = mouse.y - spaceKey.pressY
			// Preserve the ordinary quick downward swipe on Space. Holding first
			// enters the two-dimensional cursor pad instead.
			if (!spaceKey.cursorMode && !spaceKey.keyboardDismissed
					&& verticalDistance > Theme.startDragDistance * 2
					&& Math.abs(verticalDistance) > Math.abs(horizontalDistance)) {
                spaceKey.gestureMoved = true
				spaceKey.keyboardDismissed = true
				cursorHoldTimer.stop()
                MInputMethodQuick.userHide()
				return
            }
			// Keep the existing immediate horizontal gesture. Vertical movement is
			// enabled after the short hold, avoiding a conflict with swipe-to-hide.
			if (!spaceKey.cursorMode
					&& Math.abs(horizontalDistance) >= horizontalThreshold)
				spaceKey.activateCursorMode()
			spaceKey.updateCursorPosition(mouse.x, mouse.y)
        }

        onReleased: {
			// Clear this before stopping the Timer.  If its callback is already in
			// the event queue, activateCursorMode() will now reject it.
			spaceKey.pointerDown = false
			cursorHoldTimer.stop()
            spaceKey.pressed = false
            if (!spaceKey.gestureMoved && keyboard.inputHandler) {
				if (keyboard.inputHandler.endSpacebarGesture)
					keyboard.inputHandler.endSpacebarGesture(false)
                keyboard.inputHandler._handleKeyPress(spaceKey)
                keyboard.inputHandler._handleKeyClick(spaceKey)
                keyboard.inputHandler._handleKeyRelease()
                spaceKey.clicked()
			} else if (keyboard.inputHandler
					&& keyboard.inputHandler.endSpacebarGesture) {
				keyboard.inputHandler.endSpacebarGesture(true)
            }
			spaceKey.cursorMode = false
        }

		onCanceled: {
			spaceKey.pointerDown = false
			cursorHoldTimer.stop()
			spaceKey.pressed = false
			if (keyboard.inputHandler && keyboard.inputHandler.endSpacebarGesture)
				keyboard.inputHandler.endSpacebarGesture(true)
			spaceKey.cursorMode = false
		}
    }
}
