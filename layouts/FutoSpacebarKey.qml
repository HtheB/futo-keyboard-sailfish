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
    property int cursorStep
    property bool gestureMoved
	property bool cursorMode
	property bool keyboardDismissed
    property bool manualFeedbackOnPress: true
    property bool incognitoIndicatorVisible: false

    ConfigurationGroup {
        id: gestureSettings
        path: "/sailfish/text_input/futo_keyboard"
        property bool spacebarCursorControlEnabled: true
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
        anchors.fill: parent
        enabled: gestureSettings.spacebarCursorControlEnabled
        preventStealing: true

        onPressed: {
			mouse.accepted = true
            if (keyboard.inputHandler && keyboard.inputHandler.playManualKeyFeedback)
                keyboard.inputHandler.playManualKeyFeedback(spaceKey, "letter")
			if (keyboard.inputHandler && keyboard.inputHandler.beginSpacebarGesture)
				keyboard.inputHandler.beginSpacebarGesture()
            spaceKey.pressX = mouse.x
            spaceKey.pressY = mouse.y
            spaceKey.cursorStep = 0
            spaceKey.gestureMoved = false
			spaceKey.cursorMode = false
			spaceKey.keyboardDismissed = false
            spaceKey.pressed = true
        }

        onPositionChanged: {
            var threshold = Math.max(Theme.paddingLarge, width / 12)
			var horizontalDistance = mouse.x - spaceKey.pressX
			var verticalDistance = mouse.y - spaceKey.pressY
			var nextStep = Math.round(horizontalDistance / threshold)
            var delta = nextStep - spaceKey.cursorStep
            if (delta !== 0) {
                spaceKey.gestureMoved = true
				spaceKey.cursorMode = true
                spaceKey.cursorStep = nextStep
                if (keyboard.inputHandler && keyboard.inputHandler.moveCursor)
                    keyboard.inputHandler.moveCursor(delta)
            }
			// A direct downward swipe on Space still dismisses the keyboard.  Once
			// horizontal cursor control has begun, vertical movement is harmless so
			// the finger can roam over the entire keyboard without closing it.
			if (!spaceKey.cursorMode && !spaceKey.keyboardDismissed
					&& verticalDistance > Theme.startDragDistance * 2
					&& Math.abs(verticalDistance) > Math.abs(horizontalDistance)) {
                spaceKey.gestureMoved = true
				spaceKey.keyboardDismissed = true
                MInputMethodQuick.userHide()
            }
        }

        onReleased: {
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
        }

		onCanceled: {
			spaceKey.pressed = false
			if (keyboard.inputHandler && keyboard.inputHandler.endSpacebarGesture)
				keyboard.inputHandler.endSpacebarGesture(true)
		}
    }
}
