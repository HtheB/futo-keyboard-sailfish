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
		languagePanel.build()
		ownerLayout.languagePopupActive = true
		if (keyboard.inputHandler && keyboard.inputHandler.playManualKeyFeedback)
			keyboard.inputHandler.playManualKeyFeedback(spaceKey, "option")
	}

	// Hovering a name chooses it. Dragging back below Space abandons the
	// choice while the gesture stays alive, so the finger can return to it.
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
		var next = languagePanel.indexAt(pointerX, pointerY)
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

    // What holding this particular Space does. The cap is inset from the key
    // by paddingMedium, so the mark clears that before finding its corner.
    Icon {
        anchors {
            top: parent.top
            right: parent.right
            topMargin: Theme.paddingMedium + Math.round(Theme.paddingSmall / 2)
            rightMargin: Theme.paddingMedium + Theme.paddingSmall
                         + spaceKey.rightPadding
        }
        width: Theme.iconSizeExtraSmall
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
            top: parent.top
            right: parent.right
            topMargin: Theme.paddingMedium + Math.round(Theme.paddingSmall / 2)
            rightMargin: Theme.paddingMedium + Theme.paddingSmall
                         + spaceKey.rightPadding
        }
        // Drawn at the size the comma key's microphone and the dot key's
        // ",!?" are drawn at: a fraction of the key's own text, not an icon.
        height: Math.max(Theme.dp(8), Math.round(Theme.fontSizeSmall * 0.6))
        width: Math.round(height * 0.5)
        opacity: 0.72
        visible: spaceKey.hintsVisible && !spaceKey.languageSwitchArmed
                 && spaceKey.cursorControlOffered

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(1, Math.round(Theme.dp(1)))
            height: parent.height
            color: spaceKey.palette.primaryColor
        }
        Repeater {
            model: 2
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: index === 0 ? 0 : parent.height - height
                width: parent.width
                height: Math.max(1, Math.round(Theme.dp(1)))
                color: spaceKey.palette.primaryColor
            }
        }
    }

    // Built the way Sailfish builds its own language chooser: cells sized to
    // their text, grouped into rows that are centred one under the other, on
    // the keyboard's popup background. Flow cannot do this - the short row has
    // to come first and every row has to be centred - which is why the stock
    // popup lays its rows out by hand too.
    Rectangle {
        id: languagePanel

        z: 100
        visible: spaceKey.languageMode
        height: contentColumn.height + Theme.paddingLarge
        y: -height - Theme.paddingLarge
        radius: geometry.popperRadius
        color: keyboard.popperBackgroundColor
        opacity: spaceKey.languageAbandoned ? 0.5 : 1

        Column {
            id: contentColumn
            width: parent.width
            anchors.verticalCenter: parent.verticalCenter
        }

        Component {
            id: rowComponent
            Row {
                x: parent ? Math.round((parent.width - width) / 2) : 0
                height: Theme.itemSizeSmall
            }
        }

        Component {
            id: cellComponent
            SilicaItem {
                property int optionIndex
                property alias text: cellLabel.text
                readonly property bool active:
                        spaceKey.languageIndex === optionIndex
                        && !spaceKey.languageAbandoned

                width: cellLabel.paintedWidth
                       + geometry.languageSelectionCellMargin * 2
                height: Theme.itemSizeSmall

                Label {
                    id: cellLabel
                    anchors.centerIn: parent
                    color: parent.active ? parent.palette.primaryColor
                                         : parent.palette.secondaryColor
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                    font.bold: parent.active
                }

                Rectangle {
                    color: parent.palette.primaryColor
                    height: Math.round(Theme.dp(2))
                    width: cellLabel.paintedWidth
                    anchors.top: cellLabel.bottom
                    anchors.horizontalCenter: cellLabel.horizontalCenter
                    visible: parent.active
                }
            }
        }

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
            var available = layoutItem.width - Theme.paddingSmall * 2
            width = Math.min(available, geometry.languageSelectionPopupMaxWidth)
            x = layoutItem.mapToItem(spaceKey,
                                     (layoutItem.width - width) / 2, 0).x
        }

        // Cells are measured from the last name backwards, so a row that
        // cannot be filled ends up at the top rather than the bottom.
        function build() {
            contentColumn.children = []
            var options = spaceKey.languageOptions
            var contentWidth = width - geometry.languageSelectionPopupContentMargins
            var cells = []
            var itemsPerRow = []
            var itemsInRow = 0
            var rowWidth = 0
            var i

            for (i = options.length - 1; i >= 0; --i) {
                var cell = cellComponent.createObject(
                            null, { "optionIndex": i,
                                    "text": options[i].name !== ""
                                            ? options[i].name : options[i].code })
                cells.push(cell)
                if (rowWidth + cell.width > contentWidth && itemsInRow > 0) {
                    itemsPerRow.push(itemsInRow)
                    itemsInRow = 0
                    rowWidth = 0
                }
                ++itemsInRow
                rowWidth += cell.width
            }
            if (itemsInRow > 0)
                itemsPerRow.push(itemsInRow)

            // itemsPerRow counts backwards as well, so walking it in reverse
            // puts the names back in their proper order.
            var cellIndex = cells.length - 1
            for (i = itemsPerRow.length - 1; i >= 0; --i) {
                var row = rowComponent.createObject(contentColumn)
                for (var n = 0; n < itemsPerRow[i]; ++n)
                    cells[cellIndex--].parent = row
            }
        }

        function indexAt(pointerX, pointerY) {
            for (var r = 0; r < contentColumn.children.length; ++r) {
                var row = contentColumn.children[r]
                for (var c = 0; c < row.children.length; ++c) {
                    var cell = row.children[c]
                    if (!cell || cell.optionIndex === undefined)
                        continue
                    var local = spaceKey.mapToItem(cell, pointerX, pointerY)
                    if (local.x >= 0 && local.y >= 0
                            && local.x < cell.width && local.y < cell.height)
                        return cell.optionIndex
                }
            }
            return -1
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
