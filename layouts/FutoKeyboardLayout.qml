/*
 * Based on Jolla's BSD-licensed KeyboardLayout.qml from Sailfish OS 5.2.
 * Modified for FUTO Keyboard for Sailfish OS with adjustable key height.
 */
import QtQuick 2.6
import Sailfish.Silica 1.0
import com.meego.maliitquick 1.0
import Nemo.Configuration 1.0
import Nemo.DBus 2.0

Column {
    id: keyboardLayout

    property string type: model ? model.type : ""
    property bool portraitMode
    property int keyHeight
    property int punctuationKeyWidth
    property int shiftKeyWidth
    property int functionKeyWidth
    property int shiftKeyWidthNarrow
    property int symbolKeyWidthNarrow
    property string languageCode: model ? model.languageCode : ""
    property string inputMode
    property int avoidanceWidth
    property bool splitActive
    property bool splitSupported
    // Split layouts normally use the handler's vertical center item.  Tool
    // pages can additionally request the regular horizontal header without
    // changing the selected keyboard mode or collapsing the split rows.
    property bool splitTopItemRequired: false
    property bool useTopItem: !splitActive || splitTopItemRequired
    property bool capsLockSupported: true
    property int layoutIndex: model ? model.index : -1
    // FUTO owns every horizontal gesture inside its surface.  Keeping this
    // false prevents the parent Jolla PagedView from switching keyboards from
    // the suggestion strip, emoji grid, symbol pages, or empty space.
    property bool allowSwipeGesture: false
    property bool loaderVisible

    // The visible trail deliberately keeps only a short fading tail.  Swipe
    // decoding needs the complete finger curve, exposed separately here so a
    // fast gesture is not reduced to the handful of key centres it crossed.
    function serializedSwipeTrace(startKey, endKey) {
        return swipeTrail.serializedDecoderPath(startKey, endKey)
    }
	readonly property int activeKeyboardMode: Math.max(0, Math.min(3,
			portraitMode ? modeSettings.portraitKeyboardMode
			             : modeSettings.landscapeKeyboardMode))
	readonly property bool thumbMode: activeKeyboardMode === 1
	readonly property bool oneHandedMode: activeKeyboardMode >= 2
	readonly property bool thumbLandscapeMode: thumbMode && !portraitMode
	readonly property int oneHandedSide: activeKeyboardMode === 3 ? 1 : 0
	readonly property real keyboardContentWidth: oneHandedMode
			? Math.round(width * (portraitMode ? 0.82 : 0.36)) : width
	readonly property real keyboardContentX: oneHandedMode && oneHandedSide === 1
			? width - keyboardContentWidth : 0
	property string pendingKeyboardModeOrientation: ""
	property int pendingKeyboardModeValue: 0
	property int pendingKeyboardModeAttempts: 0

	function configuredKeyboardMode(isPortrait) {
		return Math.max(0, Math.min(3, Number(isPortrait
				? modeSettings.portraitKeyboardMode
				: modeSettings.landscapeKeyboardMode)))
	}

    property Item handler: {
        var handlerName = (model && model.handler) ? model.handler : ""
        var advancedInputHandler = canvas.layoutModel.inputHandlers[handlerName]

        if (typeof(advancedInputHandler) === "undefined") {
            if (canvas.layoutModel.inputHandlersInitialized && handlerName !== "")
                console.warn("invalid inputhandler for " + handlerName + ", forcing paste input handler")
            advancedInputHandler = pasteInputHandler
        }

        if (handlerName === "") {
            return keyboard.pasteInputHandler
        } else if (type === "") {
            // FUTO's handler also owns password saving/filling, URL history,
            // clipboard, and its private-field behavior. Falling back to the
            // paste-only handler for password/email/URL editors leaves those
            // features running in an inactive handler that cannot draw its
            // top-strip controls.
            return advancedInputHandler
        }
        return advancedInputHandler
    }

    property QtObject attributes: QtObject {
        property bool isShifted
        property bool inSymView
        property bool inSymView2
        property bool isShiftLocked
        property bool chineseOverrideForEnter: keyboard.chineseOverrideForEnter
    }

    signal flashLanguageIndicator()

    ConfigurationGroup {
		id: modeSettings
        path: "/sailfish/text_input/futo_keyboard"
        property real keyboardHeightScale: 1.0
		property int portraitKeyboardMode: 0
		property int landscapeKeyboardMode: 0
		property int portraitOneHandSide: 1
		property int landscapeOneHandSide: 1
		property int keyboardModeVersion: 0
	}

	function migrateLegacyKeyboardModes() {
		if (modeSettings.keyboardModeVersion >= 1)
			return
		if (modeSettings.portraitKeyboardMode === 2
				&& modeSettings.portraitOneHandSide === 1)
			modeSettings.portraitKeyboardMode = 3
		if (modeSettings.landscapeKeyboardMode === 2
				&& modeSettings.landscapeOneHandSide === 1)
			modeSettings.landscapeKeyboardMode = 3
		modeSettings.keyboardModeVersion = 1
	}

	function applyKeyboardMode(orientation, mode) {
		mode = Math.max(0, Math.min(3, Math.round(Number(mode))))
		modeSettings.keyboardModeVersion = 1
		if (orientation === "portrait")
			modeSettings.portraitKeyboardMode = mode
		else if (orientation === "landscape")
			modeSettings.landscapeKeyboardMode = mode
		updateSizes()
	}

	function setCurrentKeyboardMode(mode) {
		var orientation = portraitMode ? "portrait" : "landscape"
		mode = Math.max(0, Math.min(3, Math.round(Number(mode))))
		// Dispatch the persistent write before changing split/one-handed
		// geometry. The geometry change can rebuild Maliit's top/vertical
		// surfaces and previously allowed the asynchronous call to be lost.
		pendingKeyboardModeOrientation = orientation
		pendingKeyboardModeValue = mode
		pendingKeyboardModeAttempts = 0
		persistPendingKeyboardMode()
		applyKeyboardMode(orientation, mode)
	}

	function persistPendingKeyboardMode() {
		if (pendingKeyboardModeOrientation === "")
			return
		var orientation = pendingKeyboardModeOrientation
		var mode = pendingKeyboardModeValue
		// Keep one delayed retry armed until the helper confirms that dconf was
		// written. SetKeyboardMode is idempotent, so retries are safe.
		modePersistenceTimer.restart()
		modeHelper.typedCall("SetKeyboardMode", [
			{ "type": "s", "value": orientation },
			{ "type": "i", "value": mode }
		], function(appliedMode) {
			if (keyboardLayout.pendingKeyboardModeOrientation === orientation
					&& keyboardLayout.pendingKeyboardModeValue === mode) {
				modePersistenceTimer.stop()
				keyboardLayout.pendingKeyboardModeOrientation = ""
				keyboardLayout.pendingKeyboardModeAttempts = 0
			}
			keyboardLayout.applyKeyboardMode(orientation, appliedMode)
		}, function() {
			// The armed timer retries if the helper was still starting.
		})
	}

	Timer {
		id: modePersistenceTimer
		interval: 350
		repeat: false
		onTriggered: {
			if (keyboardLayout.pendingKeyboardModeOrientation === "")
				return
			if (keyboardLayout.pendingKeyboardModeAttempts >= 4) {
				keyboardLayout.pendingKeyboardModeOrientation = ""
				return
			}
			keyboardLayout.pendingKeyboardModeAttempts++
			keyboardLayout.persistPendingKeyboardMode()
		}
	}

	DBusInterface {
		id: modeHelper
		bus: DBus.SessionBus
		service: "org.hb.FutoKeyboard1"
		path: "/org/hb/FutoKeyboard1"
		iface: "org.hb.FutoKeyboard1"
		signalsEnabled: true
		watchServiceStatus: true

		function keyboardModeChanged(orientation, mode) {
			keyboardLayout.applyKeyboardMode(String(orientation), Number(mode))
		}
	}

    // KeyboardBase centers a narrower safe keyboard surface in landscape on
    // devices with rounded/cut-out edges.  Some Loader paths expose the full
    // rotated screen as our parent width, so cap and center the layout here as
    // well; otherwise the right thumb cluster extends past the display.
    width: parent ? (portraitMode
                     ? parent.width
                     : Math.min(parent.width, geometry.keyboardWidthLandscape)) : 0
    x: parent ? Math.round((parent.width - width) / 2) : 0
    bottomPadding: portraitMode
                   ? Math.max(MInputMethodQuick.appOrientation === 180
                              ? Screen.topCutout.height : 0,
                              geometry.cornerPadding)
                   : 0

    Component.onCompleted: {
		migrateLegacyKeyboardModes()
        updateSizes()
		orientationRelayoutTimer.restart()
        suppressSystemLayoutPaging()
    }
    onWidthChanged: updateSizes()
    onPortraitModeChanged: {
        // The orientation-specific mode and keyboard geometry are separate
        // bindings. Run once immediately and once after Qt has propagated all
        // dependent changes so a rotated surface cannot retain the previous
        // orientation's one-handed or Thumb dimensions.
        updateSizes()
        orientationRelayoutTimer.restart()
    }
    onActiveKeyboardModeChanged: {
        updateSizes()
        orientationRelayoutTimer.restart()
    }

    Timer {
		id: orientationRelayoutTimer
		interval: 0
		repeat: false
		onTriggered: keyboardLayout.updateSizes()
	}

    Connections {
        target: keyboard
        onSplitEnabledChanged: keyboardLayout.updateSizes()
        // KeyboardBase.qml imperatively restores PagedView.interactive after
        // every released touch.  That breaks jolla-keyboard.qml's declarative
        // allowSwipeGesture binding, so reinforce the FUTO-only policy after
        // every such restoration and whenever the active layout changes.
        onInteractiveChanged: keyboardLayout.suppressSystemLayoutPaging()
        onLayoutChanged: keyboardLayout.suppressSystemLayoutPaging()
        onModeChanged: keyboardLayout.suppressSystemLayoutPaging()
    }

    Connections {
		target: modeSettings
        onKeyboardHeightScaleChanged: keyboardLayout.updateSizes()
		onPortraitKeyboardModeChanged: keyboardLayout.updateSizes()
		onLandscapeKeyboardModeChanged: keyboardLayout.updateSizes()
    }

    // Track the actual keyboard surface even while Maliit is starting, the
    // editor session is inactive, or the application is rotating. The parent
    // keyboard's portraitMode can briefly retain the old orientation during a
    // live rotation, whereas its width/height already describe the new input
    // surface. That stale value previously left landscape one-handed geometry
    // visible after returning to portrait.
    Binding on portraitMode {
        value: keyboard.width > 0 && keyboard.height > 0
               ? keyboard.width <= keyboard.height
               : keyboard.portraitMode
    }

    Loader {
        readonly property Item keyboardLayout: keyboardLayout

        active: useTopItem && (layoutIndex >= 0)
        sourceComponent: active && keyboardLayout.handler ? keyboardLayout.handler.topItem : null
        width: parent.width
        visible: active
        clip: keyboard.moving || keyboard.hasHorizontalPadding
        asynchronous: false
        opacity: (canvas.activeIndex === keyboardLayout.layoutIndex) ? 1.0 : 0.0

        Behavior on opacity { FadeAnimation {} }
    }

    // Observe KeyboardBase's existing touch area without taking ownership of
    // input.  This gives the trail real finger coordinates while the decoder
    // continues to use its compact layout-key path.
    Item {
        id: swipeTrail

        parent: keyboard
        anchors.fill: keyboard
        z: 2000
        property var touchSource: null
        property var trailPoints: []
        property var decoderPoints: []
        property bool trackingSwipe: false
        property real trailOpacity: 1.0
		property int normalMaximumTouchPoints: -1
		property int cursorSecondaryTouchCount
		property var pendingCanceledPointIds: []
        readonly property real maximumTailLength: Math.max(240,
                                                           Math.min(520,
                                                                    width * 0.48))
        visible: keyboard.layout === keyboardLayout
                 && trackingSwipe && trailPoints.length > 1
                 && trailOpacity > 0.01

        function findTouchArea(item) {
            if (!item)
                return null
            var name = String(item)
            if (name.indexOf("MultiPointTouchArea") >= 0
                    || (item.minimumTouchPoints !== undefined
                        && item.maximumTouchPoints !== undefined
                        && item.touchPoints !== undefined))
                return item
            var children = item.children
            if (!children || children.length === undefined)
                return null
            for (var i = 0; i < children.length; ++i) {
                var match = findTouchArea(children[i])
                if (match)
                    return match
            }
            return null
        }

        function discoverTouchArea() {
			if (!touchSource) {
                touchSource = findTouchArea(keyboard)
				if (touchSource && touchSource.maximumTouchPoints !== undefined)
					normalMaximumTouchPoints = Number(touchSource.maximumTouchPoints)
			}
			updateSwipeTouchPolicy()
        }

		function updateSwipeTouchPolicy() {
			if (!touchSource || touchSource.maximumTouchPoints === undefined
					|| normalMaximumTouchPoints < 0)
				return
			var swiping = keyboardLayout.handler
					&& keyboardLayout.handler.swipePath !== undefined
					&& keyboardLayout.handler.swipePath.length > 1
			// KeyboardBase already owns the first point.  Limiting that existing
			// touch area to one point makes later fingers inert without disrupting
			// the in-progress swipe path.
			touchSource.maximumTouchPoints = swiping ? 1 : normalMaximumTouchPoints
		}

		function cursorGestureActive() {
			return keyboardLayout.handler
					&& keyboardLayout.handler.spacebarGestureActive !== undefined
					&& keyboardLayout.handler.spacebarGestureActive
		}

		function beginCursorSecondaryTouch(points) {
			if (!cursorGestureActive())
				return false
			cursorSecondaryTouchCount += points ? points.length : 1
			if (keyboardLayout.handler.cursorMoveMode
					&& keyboardLayout.handler.beginCursorSelection)
				keyboardLayout.handler.beginCursorSelection()
			var ids = pendingCanceledPointIds.slice(0)
			for (var i = 0; points && i < points.length; ++i)
				ids.push(Number(points[i].pointId))
			pendingCanceledPointIds = ids
			cancelSecondaryTouchTimer.restart()
			return true
		}

		function endCursorSecondaryTouch(points) {
			if (cursorSecondaryTouchCount < 1)
				return false
			cursorSecondaryTouchCount = Math.max(0, cursorSecondaryTouchCount
			                                - (points ? points.length : 1))
			if (cursorSecondaryTouchCount === 0 && keyboardLayout.handler
					&& keyboardLayout.handler.endCursorSelection)
				keyboardLayout.handler.endCursorSelection()
			return true
		}

        function firstPoint(touchPoints) {
            if (!touchPoints || touchPoints.length < 1)
                return null
            return Qt.point(Number(touchPoints[0].x), Number(touchPoints[0].y))
        }

        function decoderSwipeActive() {
            return keyboardLayout.handler
                    && keyboardLayout.handler.swipePath !== undefined
                    && keyboardLayout.handler.swipePath.length > 1
        }

        function beginTouch(touchPoints) {
            var point = firstPoint(touchPoints)
            if (!point)
                return
            releaseFade.stop()
            trailOpacity = 1.0
            trackingSwipe = false
            trailPoints = [point]
            decoderPoints = [point]
        }

        function appendTouch(touchPoints) {
            var point = firstPoint(touchPoints)
            if (!point)
                return
            var decoder = decoderPoints.slice(0)
            if (decoder.length < 1) {
                decoder.push(point)
            } else {
                var decoderPrevious = decoder[decoder.length - 1]
                var decoderDeltaX = point.x - decoderPrevious.x
                var decoderDeltaY = point.y - decoderPrevious.y
                if (Math.sqrt(decoderDeltaX * decoderDeltaX
                              + decoderDeltaY * decoderDeltaY) >= 2)
                    decoder.push(point)
            }
            // Bound pathological event streams without losing either endpoint
            // or the overall curve. Normal gestures remain well below this.
            if (decoder.length > 192) {
                var thinned = [decoder[0]]
                for (var decoderIndex = 2;
                        decoderIndex < decoder.length - 1; decoderIndex += 2)
                    thinned.push(decoder[decoderIndex])
                thinned.push(decoder[decoder.length - 1])
                decoder = thinned
            }
            decoderPoints = decoder

            var points = trailPoints.slice(0)
            if (points.length < 1) {
                points.push(point)
            } else {
                var previous = points[points.length - 1]
                var deltaX = point.x - previous.x
                var deltaY = point.y - previous.y
                if (Math.sqrt(deltaX * deltaX + deltaY * deltaY) < 3)
                    return
                points.push(point)
            }

            while (points.length > 2) {
                var length = 0
                for (var i = 1; i < points.length; ++i) {
                    var x = points[i].x - points[i - 1].x
                    var y = points[i].y - points[i - 1].y
                    length += Math.sqrt(x * x + y * y)
                }
                if (length <= maximumTailLength && points.length <= 96)
                    break
                points.shift()
            }
            trailPoints = points
            if (decoderSwipeActive())
                trackingSwipe = true
        }

        function serializedDecoderPath(startKey, endKey) {
            if (!touchSource || decoderPoints.length < 2
                    || keyboardLayout.width <= 0 || keyboardLayout.height <= 0)
                return ""
            var result = []
            for (var i = 0; i < decoderPoints.length; ++i) {
                var point = decoderPoints[i]
                var mapped = touchSource.mapToItem(keyboardLayout,
                                                   point.x, point.y)
                var x = Math.max(0, Math.min(1,
                            Number(mapped.x) / keyboardLayout.width))
                var y = Math.max(0, Math.min(1,
                            Number(mapped.y) / keyboardLayout.height))
                var key = i === 0 ? startKey
                        : (i === decoderPoints.length - 1 ? endKey : 0)
                result.push(String(key) + ":" + x.toFixed(5)
                            + ":" + y.toFixed(5))
            }
            return result.join(";")
        }

        function finishTouch() {
            if (trackingSwipe && trailPoints.length > 1)
                releaseFade.restart()
            else
                clearTouch()
        }

        function clearTouch() {
            trackingSwipe = false
            trailPoints = []
            decoderPoints = []
            trailOpacity = 1.0
        }

        Component.onCompleted: discoverTouchArea()

        Timer {
            interval: 200
            repeat: true
            running: !swipeTrail.touchSource
            onTriggered: swipeTrail.discoverTouchArea()
        }

		Timer {
			id: cancelSecondaryTouchTimer
			interval: 0
			repeat: false
			onTriggered: {
				var ids = swipeTrail.pendingCanceledPointIds
				swipeTrail.pendingCanceledPointIds = []
				for (var i = 0; i < ids.length; ++i) {
					if (keyboard.cancelTouchPoint)
						keyboard.cancelTouchPoint(ids[i])
				}
			}
		}

        Connections {
            target: swipeTrail.touchSource
            ignoreUnknownSignals: true
			onPressed: {
				if (!swipeTrail.beginCursorSecondaryTouch(touchPoints))
					swipeTrail.beginTouch(touchPoints)
			}
			onUpdated: {
				if (swipeTrail.cursorSecondaryTouchCount < 1)
					swipeTrail.appendTouch(touchPoints)
			}
			onReleased: {
				if (!swipeTrail.endCursorSecondaryTouch(touchPoints)) {
					swipeTrail.appendTouch(touchPoints)
					swipeTrail.finishTouch()
				}
			}
			onCanceled: {
				if (!swipeTrail.endCursorSecondaryTouch(touchPoints))
					swipeTrail.clearTouch()
			}
        }

        Connections {
            target: keyboardLayout.handler
            ignoreUnknownSignals: true
			onSwipePathChanged: {
				swipeTrail.updateSwipeTouchPolicy()
                if (keyboardLayout.handler.swipePath.length > 1) {
                    swipeTrail.trackingSwipe = true
                    swipeTrail.trailOpacity = 1.0
                }
            }
			onCursorMoveModeChanged: {
				if (keyboardLayout.handler.cursorMoveMode
						&& swipeTrail.cursorSecondaryTouchCount > 0
						&& keyboardLayout.handler.beginCursorSelection)
					keyboardLayout.handler.beginCursorSelection()
			}
        }

        NumberAnimation {
            id: releaseFade
            target: swipeTrail
            property: "trailOpacity"
            from: 1.0
            to: 0.0
            duration: 220
            easing.type: Easing.OutQuad
            onStopped: {
                if (swipeTrail.trailOpacity < 0.01)
                    swipeTrail.clearTouch()
            }
        }

        Repeater {
            model: Math.max(0, swipeTrail.trailPoints.length - 1)

            Rectangle {
                property point startPoint: swipeTrail.trailPoints[index]
                property point endPoint: swipeTrail.trailPoints[index + 1]
                property real deltaX: endPoint.x - startPoint.x
                property real deltaY: endPoint.y - startPoint.y
                property real segmentLength: Math.sqrt(deltaX * deltaX
                                                       + deltaY * deltaY)
                property real age: (index + 1) / Math.max(1,
                                        swipeTrail.trailPoints.length - 1)

                x: startPoint.x
                y: startPoint.y - height / 2
                width: Math.max(1, segmentLength + 4)
                height: Math.max(Theme.paddingSmall, 8)
                radius: 0
                rotation: Math.atan2(deltaY, deltaX) * 180 / Math.PI
                transformOrigin: Item.Left
                color: Theme.highlightColor
                opacity: swipeTrail.trailOpacity
                         * Math.min(1.0, Math.max(0.06, age * 4.0))
            }
        }
    }

    function suppressSystemLayoutPaging() {
        if (keyboard.mode === "common"
                && keyboard.layout === keyboardLayout
                && keyboard.interactive) {
            keyboard.interactive = false
        }
    }

	function updateSizes() {
        if (width === 0)
            return

		var configuredScale = Number(modeSettings.keyboardHeightScale)
        var heightScale = isFinite(configuredScale)
				? Math.max(0.50, Math.min(1.30, configuredScale)) : 1.0
		// Read the selected mode directly for the current orientation instead of
		// depending on binding-notification order during a live rotation.
		var orientationMode = configuredKeyboardMode(portraitMode)
		var orientationThumbMode = orientationMode === 1
		var orientationOneHandedMode = orientationMode >= 2
		var orientationOneHandedSide = orientationMode === 3 ? 1 : 0
		var widthScale = orientationOneHandedMode
				? (portraitMode ? 0.82 : 0.36) : 1.0

        if (portraitMode) {
            keyHeight = Math.round(geometry.keyHeightPortrait * heightScale)
			punctuationKeyWidth = Math.round(geometry.punctuationKeyPortait * widthScale)
			shiftKeyWidth = Math.round(geometry.shiftKeyWidthPortrait * widthScale)
			functionKeyWidth = Math.round(geometry.functionKeyWidthPortrait * widthScale)
			shiftKeyWidthNarrow = Math.round(geometry.shiftKeyWidthPortraitNarrow
			                                 * widthScale)
			symbolKeyWidthNarrow = Math.round(geometry.symbolKeyWidthPortraitNarrow
			                                  * widthScale)
			avoidanceWidth = orientationThumbMode ? Math.round(width * 0.17) : 0
			splitActive = false
        } else {
            keyHeight = Math.round(geometry.keyHeightLandscape * heightScale)
			punctuationKeyWidth = Math.round(geometry.punctuationKeyLandscape * widthScale)
			functionKeyWidth = Math.round(geometry.functionKeyWidthLandscape * widthScale)

			var shouldSplit = orientationThumbMode && splitSupported
            if (shouldSplit) {
				avoidanceWidth = Math.round(width * 0.34)
                shiftKeyWidth = geometry.shiftKeyWidthLandscapeSplit
                shiftKeyWidthNarrow = geometry.shiftKeyWidthLandscapeSplit
                symbolKeyWidthNarrow = geometry.symbolKeyWidthLandscapeNarrowSplit
            } else {
                avoidanceWidth = 0
				shiftKeyWidth = Math.round(geometry.shiftKeyWidthLandscape * widthScale)
				shiftKeyWidthNarrow = Math.round(geometry.shiftKeyWidthLandscapeNarrow
				                                 * widthScale)
				symbolKeyWidthNarrow = Math.round(geometry.symbolKeyWidthLandscapeNarrow
				                                  * widthScale)
            }
            splitActive = shouldSplit
        }

        var i
        var child
		var contentWidth = orientationOneHandedMode
				? Math.round(width * (portraitMode ? 0.82 : 0.36)) : width
		var contentX = orientationOneHandedMode && orientationOneHandedSide === 1
				? width - contentWidth : 0
		var maxButton = contentWidth

        for (i = 0; i < children.length; ++i) {
            child = children[i]
			child.width = contentWidth
			child.x = contentX
            if (child.hasOwnProperty("followRowHeight") && child.followRowHeight)
                child.height = keyHeight

            if (child.maximumBasicButtonWidth !== undefined && !child.separateButtonSizes)
				maxButton = Math.min(child.maximumBasicButtonWidth(contentWidth), maxButton)
        }

        for (i = 0; i < children.length; ++i) {
            child = children[i]
            if (child.relayout !== undefined) {
                if (child.hasOwnProperty("separateButtonSizes") && child.separateButtonSizes)
					child.relayout(child.maximumBasicButtonWidth(contentWidth))
                else
                    child.relayout(maxButton)
            }
        }
    }
}
