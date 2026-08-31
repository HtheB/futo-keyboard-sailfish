/* Independent Sailfish integration for FUTO Keyboard; not an official FUTO product. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import ".."

CharacterKey {
    id: futoKey
    property string letterAccents: defaultAccents(caption, false)
    property string letterAccentsShifted: defaultAccents(caption, true)
    property string secondarySymbol: symView
    property bool secondaryHintEligible: true
    property bool popupArmed: false
    property string popupHighlightedText: ""
    property var managedPopperTimer: null
    property bool popupAlways: symbolPopupChoices(baseKeyText()) !== ""
	readonly property bool gesturePreviewSuppressed: keyboard.inputHandler
			&& ((keyboard.inputHandler.spacebarGestureActive !== undefined
			     && keyboard.inputHandler.spacebarGestureActive)
			    || (keyboard.inputHandler.swipePath !== undefined
			        && keyboard.inputHandler.swipePath.length > 1))
    // FutoInputHandler uses this marker to collect only the visible letter
    // keys when building a layout-specific swipe trajectory.
    property bool swipeTypingKey: true

    function accentChoices(base, secondary) {
        if (popupArmed)
            return ""
        if (!visualSettings.secondarySymbolsEnabled || secondary === ""
                || base.indexOf(secondary) >= 0)
            return base
        // Put the secondary character in the cell that Popper.qml would
        // otherwise reserve for a duplicate copy of the base letter.
        var insertionIndex = Math.floor((base.length + 1) / 2)
        return base.slice(0, insertionIndex) + secondary
               + base.slice(insertionIndex)
    }

    function baseKeyText() {
        return attributes.inSymView && symView.length > 0
               ? (attributes.inSymView2 ? symView2 : symView)
               : (attributes.isShifted ? captionShifted : caption)
    }

    function symbolPopupChoices(base) {
        var arabicAlternatives = keyboard && keyboard.layout
                && keyboard.layout.usesArabicDigits !== undefined
                && keyboard.layout.usesArabicDigits
        switch (base) {
        case "$": return "£€\uFDFC₺¥¢"
        case "€": return "£$\uFDFC₺¥¢"
        case "0": return arabicAlternatives ? "٠" : ""
        case "1": return arabicAlternatives ? "١½¼¹⅛⅓" : "½¼¹⅛⅓"
        case "2": return arabicAlternatives ? "٢⅔²" : "⅔²"
        case "3": return arabicAlternatives ? "٣¾³⅜" : "¾³⅜"
        case "4": return arabicAlternatives ? "٤⁴" : "⁴"
        case "5": return arabicAlternatives ? "٥⅝ⁿ" : "⅝ⁿ"
        case "6": return arabicAlternatives ? "٦" : ""
        case "7": return arabicAlternatives ? "٧" : ""
        case "8": return arabicAlternatives ? "٨" : ""
        case "9": return arabicAlternatives ? "٩" : ""
        case "٠": return "0"
        case "١": return "1½¼¹⅛⅓"
        case "٢": return "2⅔²"
        case "٣": return "3¾³⅜"
        case "٤": return "4⁴"
        case "٥": return "5⅝ⁿ"
        case "٦": return "6"
        case "٧": return "7"
        case "٨": return "8"
        case "٩": return "9"
        case ".": return "…•"
        case "*": return "×"
        case "\"": return "„“«»”"
        case "'": return "ʼ`‡†‹›"
        case "(": return "{<["
        case ")": return "}>]"
        case "=": return "≈≠"
        case "+": return "±"
        case "-": return "¯—–"
        case "%": return "‰"
        case "/": return "÷\\"
        default: return ""
        }
    }

    function symbolPopupDefault(base) {
        var arabicAlternatives = keyboard && keyboard.layout
                && keyboard.layout.usesArabicDigits !== undefined
                && keyboard.layout.usesArabicDigits
        switch (base) {
        case "$": return "€"
        case "€": return "$"
        case "0": return arabicAlternatives ? "٠" : ""
        case "1": return arabicAlternatives ? "١" : "¹"
        case "2": return arabicAlternatives ? "٢" : "²"
        case "3": return arabicAlternatives ? "٣" : "³"
        case "4": return arabicAlternatives ? "٤" : ""
        case "5": return arabicAlternatives ? "٥" : ""
        case "6": return arabicAlternatives ? "٦" : ""
        case "7": return arabicAlternatives ? "٧" : ""
        case "8": return arabicAlternatives ? "٨" : ""
        case "9": return arabicAlternatives ? "٩" : ""
        case "٠": return "0"
        case "١": return "1"
        case "٢": return "2"
        case "٣": return "3"
        case "٤": return "4"
        case "٥": return "5"
        case "٦": return "6"
        case "٧": return "7"
        case "٨": return "8"
        case "٩": return "9"
        case ".": return "…"
        case "\"": return "“"
        case "(": return "<"
        case ")": return ">"
        case "=": return "≠"
        case "-": return "—"
        case "/": return "\\"
        default: return ""
        }
    }

    function popupChoices() {
        if (popupArmed)
            return ""
        var symbolChoices = symbolPopupChoices(baseKeyText())
        if (symbolChoices !== "")
            return symbolChoices
        return accentChoices(attributes.isShifted
                             ? letterAccentsShifted : letterAccents,
                             secondarySymbol)
    }

    function findPopper(item) {
        if (!item)
            return null
        if (item.target !== undefined && item.expanded !== undefined
                && typeof item.setup === "function"
                && typeof item.setActiveCell === "function")
            return item
        var children = item.children
        if (!children || children.length === undefined)
            return null
        for (var i = 0; i < children.length; ++i) {
            var match = findPopper(children[i])
            if (match)
                return match
        }
        return null
    }

    function findPopperTimer(popper) {
        if (!popper || !popper.data || popper.data.length === undefined)
            return null
        for (var i = 0; i < popper.data.length; ++i) {
            var object = popper.data[i]
            if (object && object.interval !== undefined
                    && object.repeat !== undefined
                    && typeof object.restart === "function")
                return object
        }
        return null
    }

    function applyPopupGlyphFonts(item) {
        if (!item)
            return
        // U+FDFC is present in Amiri on Sailfish OS, but not in Sail Sans.
        // Relying on implicit fallback produces a malformed/tiny Rial ligature
        // inside the narrow popup cell, especially with synthetic bold.
        if (item.text !== undefined && String(item.text) === "\uFDFC"
                && item.font !== undefined) {
            item.font.family = "Amiri"
            item.font.bold = false
        }
        var children = item.children
        if (!children || children.length === undefined)
            return
        for (var i = 0; i < children.length; ++i)
            applyPopupGlyphFonts(children[i])
    }

    function hasPopupChoices() {
        return symbolPopupChoices(baseKeyText()) !== ""
                || ((!attributes.inSymView)
                    && ((visualSettings.secondarySymbolsEnabled
                         && secondarySymbol !== "")
                        || letterAccents !== "" || letterAccentsShifted !== ""))
    }

    function armSecondaryPopup() {
        if (!hasPopupChoices())
            return

        // Popper.qml normally inserts the base letter as the highlighted cell
        // and hard-codes a 500 ms timer.  Rebuild it first with an empty accent
        // list, then populate it at the configured deadline with the secondary
        // symbol as the centre cell.  This preserves all accent choices while
        // making the visible key hint the long-press default.
        popupArmed = true
        popupHighlightedText = ""
        managedPopperTimer = null
        popupDelayTimer.interval = Math.max(200,
                                            visualSettings.secondaryKeyHoldMs)
        popupDelayTimer.restart()

        var popper = findPopper(keyboard)
        var systemTimer = findPopperTimer(popper)
        if (systemTimer) {
            systemTimer.interval = popupDelayTimer.interval
            managedPopperTimer = systemTimer
        }
        keyboard.updatePopper()
    }

    function prepareSecondaryPopup() {
		// A long-press timer may have been armed on the first letter before the
		// gesture travelled far enough to become swipe typing.  Never let that
		// stale timer open an accent/secondary-key popup during the swipe.
		if (!pressed || gesturePreviewSuppressed)
            return

        var symbolBase = baseKeyText()
        var symbolChoices = symbolPopupChoices(symbolBase)
        var symbolDefault = symbolPopupDefault(symbolBase)
        popupHighlightedText = symbolChoices !== ""
                               ? symbolDefault
                               : ((!attributes.inSymView
                                   && visualSettings.secondarySymbolsEnabled)
                                  ? secondarySymbol : "")
        popupArmed = false

        var popper = findPopper(keyboard)
        if (!popper)
            return
        if (managedPopperTimer)
            managedPopperTimer.stop()
        popper.hasAccents = true
        popper.setup()
        applyPopupGlyphFonts(popper)
        keyboard.inputHandler._handleKeyRelease()
        popper.expanded = true
        keyboard.cancelGesture()
    }

    function cancelSecondaryPopup() {
        popupDelayTimer.stop()
        if (managedPopperTimer)
            managedPopperTimer.stop()
        popupArmed = false
        popupHighlightedText = ""
        managedPopperTimer = null
    }

    function defaultAccents(base, shifted) {
        // Keep the pop-up compact and derive it from the key that is actually
        // shown.  The 0.4 layout attached the A alternatives to Q in QWERTY,
        // which made several pop-ups both incorrect and unnecessarily wide.
        if (base === undefined || base.length !== 1)
            return ""
        switch (base) {
        case "a": return shifted ? "ÄÁÀÂÃÅÆĄ" : "äáàâãåæą"
        case "c": return shifted ? "ÇČĆ" : "çčć"
        case "d": return shifted ? "ĎĐÐ" : "ďđð"
        case "e": return shifted ? "ÉÈÊËĚĒĘ" : "éèêëěēę"
        case "g": return shifted ? "ĞĢ" : "ğģ"
        case "i": return shifted ? "İÎÏÌÍĪĮ" : "ıîïìíīį"
        case "k": return shifted ? "Ķ" : "ķ"
        case "l": return shifted ? "ŁĻ" : "łļ"
        case "n": return shifted ? "ÑŇŃŅ" : "ñňńņ"
        case "o": return shifted ? "ÖÓÒÔÕŐØŒ" : "öóòôõőøœ"
        case "s": return shifted ? "ŞŠŚȘẞ" : "şšśșß"
        case "t": return shifted ? "ŤȚŢÞ" : "ťțţþ"
        case "u": return shifted ? "ÜÚÙÛŰŮŪŲ" : "üúùûűůūų"
        case "y": return shifted ? "ÝŸ" : "ýÿ"
        case "z": return shifted ? "ŽŹŻ" : "žźż"
        default: return ""
        }
    }

    // Once a gesture is known to be swipe typing, do not expose alternatives
    // to the platform Popper at all.  Popper caches hasAccents when its target
    // changes, so FutoInputHandler also detaches that target at swipe start.
    accents: gesturePreviewSuppressed ? "" : popupChoices()
    accentsShifted: gesturePreviewSuppressed ? "" : popupChoices()
    keyText: popupHighlightedText !== "" ? popupHighlightedText : baseKeyText()
    pixelSize: Math.round(Theme.fontSizeLarge
                          * Math.max(0.8, Math.min(1.3, visualSettings.keyFontScale)))
    fontSizeMode: Text.Fit
    showPopper: visualSettings.keyPreviewEnabled
				&& !gesturePreviewSuppressed
                && !(visualSettings.hideKeyPreviewsInIncognito
                     && keyboard.layout
                     && keyboard.layout.effectiveIncognitoMode !== undefined
                     && keyboard.layout.effectiveIncognitoMode)

    ConfigurationGroup {
        id: visualSettings
        path: "/sailfish/text_input/futo_keyboard"
        property bool separatedKeysEnabled: true
        property real keyGapScale: 1.0
        property real keyFontScale: 1.0
        property bool keyPreviewEnabled: true
        property bool hideKeyPreviewsInIncognito: false
        property bool secondarySymbolsEnabled: true
        property int secondaryKeyHoldMs: 500
    }

    Timer {
        id: popupDelayTimer
        interval: 500
        repeat: false
        onTriggered: futoKey.prepareSecondaryPopup()
    }

    onPressedChanged: {
		if (pressed && !gesturePreviewSuppressed)
            armSecondaryPopup()
        else
            cancelSecondaryPopup()
    }

	onGesturePreviewSuppressedChanged: {
		if (gesturePreviewSuppressed)
			cancelSecondaryPopup()
	}

    Rectangle {
        anchors.fill: parent
		anchors.topMargin: Math.max(1, Theme.paddingSmall / 3
		                            * Math.max(0.5, Math.min(2.0,
		                                                   visualSettings.keyGapScale)))
		anchors.bottomMargin: anchors.topMargin
		// KeyboardRow stores the centring space of short rows in the first and
		// last key's padding.  Exclude that padding from the separated-key card,
		// otherwise QWERTY's A and L appear wider than every other letter.
		anchors.leftMargin: anchors.topMargin + futoKey.leftPadding
		anchors.rightMargin: anchors.topMargin + futoKey.rightPadding
        radius: Theme.paddingSmall
        z: -2
        color: Theme.rgba(parent.palette.primaryColor,
				          parent.pressed && !parent.gesturePreviewSuppressed
				          ? 0.24 : 0.12)
        border.width: 1
        border.color: Theme.rgba(parent.palette.primaryColor, 0.12)
        visible: visualSettings.separatedKeysEnabled
    }

    Label {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Math.max(1, Theme.paddingSmall / 4)
		anchors.rightMargin: Theme.paddingMedium + parent.rightPadding
        color: parent.palette.primaryColor
        font.pixelSize: Math.max(Theme.fontSizeTiny,
                                 Math.round(parent.pixelSize * 0.43))
        text: parent.secondarySymbol
        visible: visualSettings.secondarySymbolsEnabled
                 && parent.secondaryHintEligible
                 && !attributes.inSymView
                 && parent.secondarySymbol !== ""
        opacity: 0.72
    }
}
