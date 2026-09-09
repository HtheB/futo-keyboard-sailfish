/* Space-bar hold gestures for the Sailfish FUTO layout: the cursor pad, and
 * the language chooser that can take its place on the letter page.
 */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import com.meego.maliitquick 1.0
import ".."

SpacebarKey {
    id: spaceKey

    // Lift this key over its neighbours while the chooser is open; the row
    // lifts itself over the rows above for the same reason.
    z: languageMode ? 10 : 0

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
    // The second Space of a split landscape row is filler and carries no hint.
    property bool hintEligible: true

    property bool languageMode
    property bool languageAbandoned
    property var languageOptions: []
    property int languageIndex: -1
    property int languageStartIndex: -1

    readonly property Item ownerLayout: keyboard.layout
    // Hold on the 123 and {&= pages always reaches the cursor pad. Only the
    // letter page follows the setting, because only it has a language.
    readonly property bool onLetterPage: !attributes.inSymView
    readonly property int holdAction: {
        var configured = Number(gestureSettings.spacebarHoldAction)
        if (!isFinite(configured) || configured < 0)
            return gestureSettings.spacebarCursorControlEnabled ? 1 : 0
        return Math.max(0, Math.min(2, Math.round(configured)))
    }
    readonly property bool languageSwitchOffered: onLetterPage && holdAction === 2
            && ownerLayout && ownerLayout.languageSwitchEntries !== undefined
    readonly property bool languageSwitchArmed: languageSwitchOffered
            && ownerLayout.languageSwitchEntries().length > 1
    readonly property bool cursorControlOffered: !onLetterPage || holdAction === 1

    readonly property bool hintsVisible: visualSettings.secondarySymbolsEnabled
            && hintEligible && !incognitoIndicatorVisible

    ConfigurationGroup {
        id: gestureSettings
        path: "/sailfish/text_input/futo_keyboard"
        property int spacebarHoldAction: -1
        property bool spacebarCursorControlEnabled: true
    }

    ConfigurationGroup {
        id: visualSettings
        path: "/sailfish/text_input/futo_keyboard"
        property bool secondarySymbolsEnabled: true
    }

	function activateLanguageMode() {
		if (!pointerDown || languageMode || cursorMode || keyboardDismissed)
			return
		languageOptions = ownerLayout.languageSwitchEntries()
		if (languageOptions.length < 2)
			return
		languageStartIndex = ownerLayout.currentLanguageSwitchIndex()
		languageIndex = languageStartIndex
		languageAbandoned = false
		languageMode = true
		gestureMoved = true
		languagePanel.placeOverLayout()
		ownerLayout.languagePopupActive = true
		if (keyboard.inputHandler && keyboard.inputHandler.playManualKeyFeedback)
			keyboard.inputHandler.playManualKeyFeedback(spaceKey, "option")
	}

	// Hovering a name chooses it. Dragging back below Space abandons the
	// choice while the gesture stays alive, so the finger can return to it.
	function languageIndexAt(pointerX, pointerY) {
		var items = languageFlow.children
		for (var i = 0; i < items.length; ++i) {
			var item = items[i]
			if (!item || item.optionIndex === undefined || !item.visible)
				continue
			var local = spaceKey.mapToItem(item, pointerX, pointerY)
			if (local.x >= 0 && local.y >= 0
					&& local.x < item.width && local.y < item.height)
				return item.optionIndex
		}
		return -1
	}

	function updateLanguageSelection(pointerX, pointerY) {
		if (!languageMode)
			return
		var count = languageOptions.length
		if (count < 1)
			return
		languageAbandoned = pointerY > height * 1.5
		if (languageAbandoned)
			return
		// Only the name actually under the finger is chosen. Anywhere else
		// leaves the last one standing, so crossing a gap changes nothing.
		var next = languageIndexAt(pointerX, pointerY)
		if (next < 0 || next >= count)
			return
		if (next === languageIndex)
			return
		languageIndex = next
		if (keyboard.inputHandler && keyboard.inputHandler.playManualKeyFeedback)
			keyboard.inputHandler.playManualKeyFeedback(spaceKey, "option")
	}

	function finishLanguageMode(commit) {
		if (!languageMode)
			return
		var chosen = languageIndex
		var start = languageStartIndex
		languageMode = false
		languageAbandoned = false
		languageIndex = -1
		languageStartIndex = -1
		languageOptions = []
		if (ownerLayout)
			ownerLayout.languagePopupActive = false
		if (commit && chosen >= 0 && chosen !== start)
			ownerLayout.applyLanguageSwitchIndex(chosen)
	}

	function activateCursorMode() {
		if (!pointerDown || cursorMode || languageMode || keyboardDismissed)
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
			if (spaceKey.languageSwitchArmed) {
				spaceKey.activateLanguageMode()
				spaceKey.updateLanguageSelection(spaceMouseArea.mouseX,
				                                 spaceMouseArea.mouseY)
				return
			}
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

    // What holding this particular Space does. Inside the cap rather than in
    // the corner the letter keys use: Space has no room above its own cap.
    // Drawn at the weight the letter keys give their secondary symbols.
    Icon {
        anchors {
            right: parent.right
            rightMargin: Theme.paddingLarge + spaceKey.rightPadding
            verticalCenter: parent.verticalCenter
        }
        width: Math.round(Theme.iconSizeExtraSmall * 0.72)
        height: width
        source: "image://theme/icon-m-region"
        color: spaceKey.palette.primaryColor
        opacity: 0.72
        visible: spaceKey.hintsVisible && spaceKey.languageSwitchArmed
    }

    // A drawn I-beam rather than a bundled icon: three rectangles need no
    // artwork, and they follow the key palette like every other mark here.
    Item {
        anchors {
            right: parent.right
            rightMargin: Theme.paddingLarge + spaceKey.rightPadding
            verticalCenter: parent.verticalCenter
        }
        width: Math.round(Theme.iconSizeExtraSmall * 0.4)
        height: Math.round(Theme.iconSizeExtraSmall * 0.72)
        opacity: 0.72
        visible: spaceKey.hintsVisible && !spaceKey.languageSwitchArmed
                 && spaceKey.cursorControlOffered

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(1, Math.round(parent.height / 12))
            height: parent.height
            color: spaceKey.palette.primaryColor
        }
        Repeater {
            model: 2
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: index === 0 ? 0 : parent.height - height
                width: parent.width
                height: Math.max(1, Math.round(parent.height / 12))
                color: spaceKey.palette.primaryColor
            }
        }
    }

    // The chooser covers the letter rows above Space, close to the width of
    // the keyboard, with the names flowing onto as many lines as they need.
    Rectangle {
        id: languagePanel

        z: 100
        visible: spaceKey.languageMode
        height: languageFlow.height + 2 * Theme.paddingLarge
        y: -height - Theme.paddingSmall
        radius: Theme.paddingLarge
        color: keyboard.popperBackgroundColor
        opacity: spaceKey.languageAbandoned ? 0.5 : 1

        // Space is narrower than the keyboard, so the panel is placed against
        // the layout rather than against this key. The keyboard does not move
        // while a finger is down, so once placed it stays put.
        function placeOverLayout() {
            var layoutItem = spaceKey.ownerLayout
            if (!layoutItem) {
                width = spaceKey.width
                x = 0
                return
            }
            var margin = Theme.paddingMedium
            width = Math.max(spaceKey.width, layoutItem.width - 2 * margin)
            x = layoutItem.mapToItem(spaceKey, margin, 0).x
        }

        Flow {
            id: languageFlow
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                topMargin: Theme.paddingLarge
                leftMargin: Theme.paddingLarge
                rightMargin: Theme.paddingLarge
            }
            spacing: Theme.paddingLarge

            Repeater {
                model: spaceKey.languageMode ? spaceKey.languageOptions : []

                Item {
                    property int optionIndex: index
                    readonly property bool current: index === spaceKey.languageIndex
                                                    && !spaceKey.languageAbandoned

                    width: optionLabel.width + 2 * Theme.paddingMedium
                    height: optionLabel.height + Theme.paddingMedium

                    Label {
                        id: optionLabel
                        anchors.centerIn: parent
                        font.pixelSize: Theme.fontSizeMedium
                        color: parent.current ? Theme.highlightColor
                                              : Theme.primaryColor
                        opacity: parent.current ? 1 : 0.6
                        text: modelData.name !== "" ? modelData.name : modelData.code
                    }

                    Rectangle {
                        anchors.top: optionLabel.bottom
                        anchors.topMargin: Math.round(Theme.paddingSmall / 2)
                        anchors.horizontalCenter: optionLabel.horizontalCenter
                        width: optionLabel.width
                        height: Math.max(1, Math.round(Theme.paddingSmall / 4))
                        color: Theme.highlightColor
                        visible: parent.current
                    }
                }
            }
        }
    }

    MouseArea {
		id: spaceMouseArea
        anchors.fill: parent
        enabled: spaceKey.cursorControlOffered || spaceKey.languageSwitchArmed
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
			spaceKey.languageMode = false
			spaceKey.keyboardDismissed = false
            spaceKey.pressed = true
			cursorHoldTimer.restart()
        }

        onPositionChanged: {
			if (spaceKey.languageMode) {
				spaceKey.updateLanguageSelection(mouse.x, mouse.y)
				return
			}
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
			// Keep the existing immediate horizontal gesture. With the chooser
			// on this key a sideways drag must wait for the hold instead, or it
			// would take the gesture away before the chooser could open.
			if (!spaceKey.cursorMode && !spaceKey.languageSwitchArmed
					&& spaceKey.cursorControlOffered
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
			spaceKey.finishLanguageMode(!spaceKey.languageAbandoned)
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
			spaceKey.finishLanguageMode(false)
			if (keyboard.inputHandler && keyboard.inputHandler.endSpacebarGesture)
				keyboard.inputHandler.endSpacebarGesture(true)
			spaceKey.cursorMode = false
		}
    }
}
