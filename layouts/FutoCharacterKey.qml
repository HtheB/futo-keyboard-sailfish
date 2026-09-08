/* Independent Sailfish integration for FUTO Keyboard; not an official FUTO product. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import ".."

CharacterKey {
    id: futoKey
    property string letterAccents: defaultAccents(caption, false)
    property string letterAccentsShifted: defaultAccents(caption, true)
    property string keyOutput: caption
    property string keyOutputShifted: captionShifted
    property var letterAlternativeChoices: []
    property var letterAlternativeChoicesShifted: []
    property bool exactAlternativeMode: false
    property string preferredFontFamily: ""
    property string specialArabicFontFamily: "Noto Naskh Arabic"
    property string androidRiyalFontFamily: "FUTO Android Riyal"
    property string secondarySymbol: symView
    property bool secondaryHintEligible: true
    property bool popupArmed: false
    property string popupHighlightedText: ""
    property string popupHighlightedOutput: ""
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

    function baseKeyOutput() {
        return attributes.inSymView && symView.length > 0
               ? (attributes.inSymView2 ? symView2 : symView)
               : (attributes.isShifted ? keyOutputShifted : keyOutput)
    }

    function activeStructuredChoices() {
        if (!exactAlternativeMode || attributes.inSymView)
            return []
        var source = attributes.isShifted
                ? letterAlternativeChoicesShifted : letterAlternativeChoices
        return source && source.length !== undefined ? source : []
    }

    function placeholderAccents(count) {
        var result = ""
        for (var i = 0; i < count; ++i)
            result += String.fromCharCode(0xE100 + (i % 0x180))
        return result
    }

    function symbolPopupChoices(base) {
        var arabicAlternatives = keyboard && keyboard.layout
                && keyboard.layout.usesArabicDigits !== undefined
                && keyboard.layout.usesArabicDigits
        var persianAlternatives = keyboard && keyboard.layout
                && keyboard.layout.usesPersianDigits !== undefined
                && keyboard.layout.usesPersianDigits
        var localizedAlternatives = arabicAlternatives || persianAlternatives
        var localizedDigits = persianAlternatives ? "۰۱۲۳۴۵۶۷۸۹" : "٠١٢٣٤٥٦٧٨٩"
        switch (base) {
        case "$": return "£€₺\u20C1¥¢"
        case "€": return "£$₺\u20C1¥¢"
        case "0": return localizedAlternatives ? localizedDigits.charAt(0) : ""
        case "1": return (localizedAlternatives ? localizedDigits.charAt(1) : "") + "½¼¹⅛⅓"
        case "2": return (localizedAlternatives ? localizedDigits.charAt(2) : "") + "⅔²"
        case "3": return (localizedAlternatives ? localizedDigits.charAt(3) : "") + "¾³⅜"
        case "4": return (localizedAlternatives ? localizedDigits.charAt(4) : "") + "⁴"
        case "5": return (localizedAlternatives ? localizedDigits.charAt(5) : "") + "⅝ⁿ"
        case "6": return localizedAlternatives ? localizedDigits.charAt(6) : ""
        case "7": return localizedAlternatives ? localizedDigits.charAt(7) : ""
        case "8": return localizedAlternatives ? localizedDigits.charAt(8) : ""
        case "9": return localizedAlternatives ? localizedDigits.charAt(9) : ""
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
        case "۰": return "0"
        case "۱": return "1½¼¹⅛⅓"
        case "۲": return "2⅔²"
        case "۳": return "3¾³⅜"
        case "۴": return "4⁴"
        case "۵": return "5⅝ⁿ"
        case "۶": return "6"
        case "۷": return "7"
        case "۸": return "8"
        case "۹": return "9"
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
        var persianAlternatives = keyboard && keyboard.layout
                && keyboard.layout.usesPersianDigits !== undefined
                && keyboard.layout.usesPersianDigits
        var localizedAlternatives = arabicAlternatives || persianAlternatives
        var localizedDigits = persianAlternatives ? "۰۱۲۳۴۵۶۷۸۹" : "٠١٢٣٤٥٦٧٨٩"
        switch (base) {
        case "$": return "€"
        case "€": return "$"
        case "0": return localizedAlternatives ? localizedDigits.charAt(0) : ""
        case "1": return localizedAlternatives ? localizedDigits.charAt(1) : "¹"
        case "2": return localizedAlternatives ? localizedDigits.charAt(2) : "²"
        case "3": return localizedAlternatives ? localizedDigits.charAt(3) : "³"
        case "4": return localizedAlternatives ? localizedDigits.charAt(4) : ""
        case "5": return localizedAlternatives ? localizedDigits.charAt(5) : ""
        case "6": return localizedAlternatives ? localizedDigits.charAt(6) : ""
        case "7": return localizedAlternatives ? localizedDigits.charAt(7) : ""
        case "8": return localizedAlternatives ? localizedDigits.charAt(8) : ""
        case "9": return localizedAlternatives ? localizedDigits.charAt(9) : ""
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
        case "۰": return "0"
        case "۱": return "1"
        case "۲": return "2"
        case "۳": return "3"
        case "۴": return "4"
        case "۵": return "5"
        case "۶": return "6"
        case "۷": return "7"
        case "۸": return "8"
        case "۹": return "9"
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
        var structured = activeStructuredChoices()
        if (structured.length > 0)
            return placeholderAccents(structured.length)
        if (exactAlternativeMode && !attributes.inSymView)
            return ""
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

    function findPopperModel(item) {
        if (!item)
            return null
        if (item.count !== undefined && typeof item.clear === "function"
                && typeof item.append === "function"
                && typeof item.get === "function")
            return item
        var values = item.data
        if (!values || values.length === undefined)
            return null
        for (var i = 0; i < values.length; ++i) {
            var match = findPopperModel(values[i])
            if (match)
                return match
        }
        return null
    }

    function replacePopperChoices(popper) {
        var choices = activeStructuredChoices()
        if (!popper || choices.length < 1)
            return
        var model = findPopperModel(popper)
        if (!model)
            return
        var activeCell = Number(popper.activeCell)
        if (!isFinite(activeCell) || activeCell < 0)
            activeCell = Math.floor((choices.length + 1) / 2)
        activeCell = Math.min(choices.length, Math.round(activeCell))
        var rows = []
        var sourceIndex = 0
        for (var cell = 0; cell < choices.length + 1; ++cell) {
            if (cell === activeCell) {
                rows.push({ labelText: baseKeyText(), inputText: baseKeyOutput() })
            } else {
                var choice = choices[sourceIndex++] || {}
                rows.push({
                    labelText: String(choice.caption !== undefined
                                      ? choice.caption : choice.output || ""),
                    inputText: String(choice.output !== undefined
                                      ? choice.output : choice.caption || "")
                })
            }
        }
        model.clear()
        for (var row = 0; row < rows.length; ++row)
            model.append(rows[row])
    }

    function applyPopupGlyphFonts(item) {
        if (!item)
            return
        // These three symbols are absent or malformed in Sailfish's native
        // fonts. Keep their fallback exact so ordinary Arabic and Latin text
        // continues to use the system typeface.
        if (item.text !== undefined
                && usesAndroidRiyalFont(String(item.text))
                && item.font !== undefined) {
            item.font.family = androidRiyalFontFamily
            item.font.bold = false
            item.font.weight = Font.Normal
        } else if (item.text !== undefined
                && usesSpecialArabicFont(String(item.text))
                && item.font !== undefined) {
            item.font.family = specialArabicFontFamily
            item.font.bold = false
            item.font.weight = Font.Normal
        } else if (item.text !== undefined && item.font !== undefined
                   && preferredFontFamily !== "") {
            var popupUsesBundledFont = shouldUsePreferredFont(String(item.text))
            item.font.family = popupUsesBundledFont
                    ? preferredFontFamily : Theme.fontFamily
            item.font.bold = false
            item.font.weight = popupUsesBundledFont ? Font.Light : Font.Normal
        }
        var children = item.children
        if (!children || children.length === undefined)
            return
        for (var i = 0; i < children.length; ++i)
            applyPopupGlyphFonts(children[i])
    }

    function isBundledScriptCodepoint(codepoint) {
        // Extended Latin is needed by the Amazigh-Latin layout. Restrict the
        // generic Noto Sans face to those missing glyphs so ordinary Latin
        // keys keep Sailfish's native Sail Sans appearance.
        return (codepoint >= 0x0250 && codepoint <= 0x02AF)
                || (codepoint >= 0x1E00 && codepoint <= 0x1EFF)
                || (codepoint >= 0x2D30 && codepoint <= 0x2D7F)
                || (codepoint >= 0x0D80 && codepoint <= 0x0DFF)
                || (codepoint >= 0x1000 && codepoint <= 0x109F)
                || (codepoint >= 0xA9E0 && codepoint <= 0xA9FF)
                || (codepoint >= 0xAA60 && codepoint <= 0xAA7F)
                || (codepoint >= 0x1780 && codepoint <= 0x17FF)
                || (codepoint >= 0x19E0 && codepoint <= 0x19FF)
    }

    function shouldUsePreferredFont(value) {
        if (preferredFontFamily === "")
            return false
        value = String(value || "")
        for (var i = 0; i < value.length; ++i) {
            var codepoint = value.charCodeAt(i)
            if (isBundledScriptCodepoint(codepoint))
                return true
        }
        return false
    }

    function usesSpecialArabicFont(value) {
        value = String(value || "")
        for (var i = 0; i < value.length; ++i) {
            var codepoint = value.charCodeAt(i)
            if (codepoint === 0x20C1 || codepoint === 0xFDFB)
                return true
        }
        return false
    }

    function usesAndroidRiyalFont(value) {
        value = String(value || "")
        for (var i = 0; i < value.length; ++i) {
            if (value.charCodeAt(i) === 0xFDFC)
                return true
        }
        return false
    }

    function applyKeyGlyphFont(item) {
        if (!item)
            return
        if (item !== futoKey && item.text !== undefined
                && item.font !== undefined
                && String(item.text) === String(futoKey.keyText)) {
            var value = String(item.text)
            var usesAndroidFont = usesAndroidRiyalFont(value)
            var usesSpecialFont = usesSpecialArabicFont(value)
            var usesBundledFont = shouldUsePreferredFont(value)
            if (usesAndroidFont)
                item.font.family = androidRiyalFontFamily
            else if (usesSpecialFont)
                item.font.family = specialArabicFontFamily
            else
                item.font.family = usesBundledFont
                        ? preferredFontFamily : Theme.fontFamily
            item.font.bold = false
            item.font.weight = usesBundledFont && !usesSpecialFont
                    && !usesAndroidFont
                    ? Font.Light : Font.Normal
        }
        var children = item.children
        if (!children || children.length === undefined)
            return
        for (var i = 0; i < children.length; ++i)
            applyKeyGlyphFont(children[i])
    }

    function hasPopupChoices() {
        return symbolPopupChoices(baseKeyText()) !== ""
                || ((!attributes.inSymView)
                    && ((visualSettings.secondarySymbolsEnabled
                         && secondarySymbol !== "")
                        || activeStructuredChoices().length > 0
                        || (!exactAlternativeMode
                            && (letterAccents !== ""
                                || letterAccentsShifted !== ""))))
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
        popupHighlightedOutput = ""
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
        popupHighlightedOutput = popupHighlightedText
        popupArmed = false

        var popper = findPopper(keyboard)
        if (!popper)
            return
        if (managedPopperTimer)
            managedPopperTimer.stop()
        popper.hasAccents = true
        popper.setup()
        replacePopperChoices(popper)
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
        popupHighlightedOutput = ""
        managedPopperTimer = null
    }

    function fallbackAccents(base, shifted) {
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

    function mergeAccentCharacters(first, second) {
        var result = ""
        var combined = String(first || "") + String(second || "")
        for (var i = 0; i < combined.length; ++i) {
            var character = combined.charAt(i)
            if (result.indexOf(character) < 0)
                result += character
        }
        return result
    }

    function defaultAccents(base, shifted) {
        // Keep the pop-up derived from the key that is actually shown. FUTO's
        // locale choices come first; the established broad Latin choices stay
        // available afterwards for this port's multilingual QWERTY layout.
        if (base === undefined || base.length !== 1)
            return ""
        var officialAlternatives = ""
        if (keyboard && keyboard.layout
                && keyboard.layout.letterAlternatives !== undefined) {
            officialAlternatives = String(
                    keyboard.layout.letterAlternatives(base, shifted) || "")
        }
        return mergeAccentCharacters(officialAlternatives,
                                     fallbackAccents(base, shifted))
    }

    // Once a gesture is known to be swipe typing, do not expose alternatives
    // to the platform Popper at all.  Popper caches hasAccents when its target
    // changes, so FutoInputHandler also detaches that target at swipe start.
    accents: gesturePreviewSuppressed ? "" : popupChoices()
    accentsShifted: gesturePreviewSuppressed ? "" : popupChoices()
    keyText: popupHighlightedText !== "" ? popupHighlightedText : baseKeyText()
    text: popupHighlightedOutput !== "" ? popupHighlightedOutput : baseKeyOutput()
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

    Timer {
        id: glyphFontRefresh
        interval: 0
        repeat: false
        onTriggered: futoKey.applyKeyGlyphFont(futoKey)
    }

    Component.onCompleted: glyphFontRefresh.restart()
    onPreferredFontFamilyChanged: glyphFontRefresh.restart()
    onSpecialArabicFontFamilyChanged: glyphFontRefresh.restart()
    onAndroidRiyalFontFamilyChanged: glyphFontRefresh.restart()
    onKeyTextChanged: glyphFontRefresh.restart()

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
