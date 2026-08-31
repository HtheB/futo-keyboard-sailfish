/* Image-backed Emoji 17 key with data-driven skin-tone variants. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import ".."

CharacterKey {
    id: emojiKey

    property string emojiText
    property string assetCode
    property var variants: []
    property int emojiStyle
    property int skinTone
    property string commitOverride: ""
    property bool held
    property bool moved
    property real pressX
    property real pressY
    readonly property bool toneCapable: variants && variants.length > 0
    readonly property int variantCount: 1 + (variants ? variants.length : 0)
    readonly property string styleDirectory: emojiStyle === 1 ? "openmoji"
                                             : emojiStyle === 2 ? "noto"
                                             : emojiStyle === 0 ? "twemoji" : ""
    readonly property var effectiveVariant: defaultVariant()
    readonly property int contentRevision: keyboard && keyboard.inputHandler
            && keyboard.inputHandler.contentRevision !== undefined
            ? keyboard.inputHandler.contentRevision : 0

    signal toneRequested()
    signal emojiCommitted(string baseCode)

    function baseVariant() {
        return { "t": emojiText, "c": assetCode, "s": 0 }
    }

    function variantAt(index) {
        if (index <= 0 || !variants || index > variants.length)
            return baseVariant()
        return variants[index - 1]
    }

    function defaultVariant() {
        var requestedTone = Math.max(0, Math.min(5, Math.round(Number(skinTone))))
        if (requestedTone > 0 && variants) {
            for (var i = 0; i < variants.length; ++i) {
                if (Number(variants[i].s) === requestedTone)
                    return variants[i]
            }
        }
        return baseVariant()
    }

    function assetPath(code, bundled) {
        if (emojiStyle === 3)
            return ""
        var home = String(StandardPaths.home)
        var userRoot = (home.indexOf("file://") === 0 ? home : "file://" + home)
                + "/.local/share/futo-keyboard-sailfish/content/emoji/"
        var root = bundled ? "file:///usr/share/futo-keyboard-sailfish/emoji/" : userRoot
        return root + styleDirectory + "/" + String(code).toLowerCase()
                + (emojiStyle === 2 ? ".png" : ".svg")
                + "?r=" + contentRevision
    }

    function triggerVariant(index) {
        if (!keyboard.inputHandler)
            return
        var selected = variantAt(index)
        commitOverride = selected.t
        keyboard.inputHandler._handleKeyPress(emojiKey)
        keyboard.inputHandler._handleKeyClick(emojiKey)
        keyboard.inputHandler._handleKeyRelease()
        emojiKey.clicked()
        commitOverride = ""
        emojiCommitted(assetCode)
    }

    function triggerDefault() {
        if (!keyboard.inputHandler)
            return
        var selected = effectiveVariant
        commitOverride = selected.t
        keyboard.inputHandler._handleKeyPress(emojiKey)
        keyboard.inputHandler._handleKeyClick(emojiKey)
        keyboard.inputHandler._handleKeyRelease()
        emojiKey.clicked()
        commitOverride = ""
        emojiCommitted(assetCode)
    }

    caption: ""
    keyText: ""
    text: commitOverride !== "" ? commitOverride
                                 : (effectiveVariant ? effectiveVariant.t : emojiText)
    showPopper: false

    ConfigurationGroup {
        id: visualSettings
        path: "/sailfish/text_input/futo_keyboard"
        property bool separatedKeysEnabled: true
        property real keyGapScale: 1.0
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: Math.max(1, Theme.paddingSmall / 3
                                  * Math.max(0.5, Math.min(2.0,
                                                         visualSettings.keyGapScale)))
        radius: Theme.paddingSmall
        z: -2
        color: Theme.rgba(parent.palette.primaryColor, parent.pressed ? 0.24 : 0.12)
        border.width: 1
        border.color: Theme.rgba(parent.palette.primaryColor, 0.12)
        visible: visualSettings.separatedKeysEnabled
    }

    Image {
        id: emojiImage
        property bool bundledFallback: false
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.72
        height: width
		sourceSize.width: Math.max(1, Math.ceil(width))
		sourceSize.height: Math.max(1, Math.ceil(height))
        fillMode: Image.PreserveAspectFit
        smooth: true
		// The grid is row-virtualized, so only the visible cells exist. Loading
		// these small local assets synchronously avoids Qt 5.6's slow serial
		// asynchronous SVG queue when changing categories.
		asynchronous: false
		// Do not retain every decoded emoji visited while scrolling. The grid is
		// virtualized and local assets are cheap to reload when they return.
		cache: false
        source: !emojiKey.effectiveVariant ? ""
                : emojiKey.assetPath(emojiKey.effectiveVariant.c, bundledFallback)
        onStatusChanged: {
            if (status === Image.Error && !bundledFallback)
                bundledFallback = true
        }
    }

    Label {
        anchors.centerIn: parent
        width: parent.width * 0.8
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: Math.min(parent.width, parent.height) * 0.52
        color: Theme.primaryColor
        text: emojiKey.effectiveVariant ? emojiKey.effectiveVariant.t : emojiKey.emojiText
        visible: emojiImage.status === Image.Error || emojiImage.source === ""
    }

    onContentRevisionChanged: emojiImage.bundledFallback = false
    onStyleDirectoryChanged: emojiImage.bundledFallback = false
    onEffectiveVariantChanged: emojiImage.bundledFallback = false

    Canvas {
        id: toneIndicator
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Math.max(2, Theme.paddingSmall / 3)
        anchors.bottomMargin: Math.max(2, Theme.paddingSmall / 3)
        width: Math.max(8, Math.min(parent.width, parent.height) * 0.16)
        height: width
        z: 4
        visible: emojiKey.toneCapable
        property color indicatorColor: Theme.highlightColor

        onIndicatorColorChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            var context = getContext("2d")
            context.clearRect(0, 0, width, height)
            context.fillStyle = indicatorColor
            context.beginPath()
            context.moveTo(width, 0)
            context.lineTo(width, height)
            context.lineTo(0, height)
            context.closePath()
            context.fill()
        }
    }

    Timer {
        id: toneTimer
        interval: 500
        onTriggered: {
            if (emojiKey.toneCapable && !emojiKey.moved) {
                emojiKey.held = true
                emojiKey.toneRequested()
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        preventStealing: false

        onPressed: {
            if (keyboard.inputHandler && keyboard.inputHandler.playManualKeyFeedback)
                keyboard.inputHandler.playManualKeyFeedback(emojiKey, "option")
            emojiKey.held = false
            emojiKey.moved = false
            emojiKey.pressX = mouse.x
            emojiKey.pressY = mouse.y
            emojiKey.pressed = true
            if (emojiKey.toneCapable)
                toneTimer.restart()
        }
        onPositionChanged: {
            var dx = mouse.x - emojiKey.pressX
            var dy = mouse.y - emojiKey.pressY
            if (dx * dx + dy * dy > Theme.startDragDistance * Theme.startDragDistance) {
                emojiKey.moved = true
                toneTimer.stop()
            }
        }
        onReleased: {
            toneTimer.stop()
            emojiKey.pressed = false
            if (!emojiKey.held && !emojiKey.moved)
                emojiKey.triggerDefault()
        }
        onCanceled: {
            toneTimer.stop()
            emojiKey.pressed = false
            emojiKey.moved = true
        }
    }
}
