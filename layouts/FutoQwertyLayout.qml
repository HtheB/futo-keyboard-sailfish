/*
 * Based on Jolla's BSD-licensed keyboard layouts.
 * Modified for the independent FUTO Keyboard Sailfish integration.
 */
import QtQuick 2.0
import Nemo.Configuration 1.0
import com.jolla.keyboard 1.0
import com.meego.maliitquick 1.0
import ".."
import "FutoSymbolData.js" as SymbolData
import "FutoLetterLayouts.js" as LetterLayouts
import "FutoLanguageData.js" as LanguageData

FutoKeyboardLayout {
    id: root
    splitSupported: true
    // Keep Thumb mode split in landscape, but mount the normal horizontal
    // header when a tool page needs Quick Settings or category/search tabs.
    splitTopItemRequired: emojiMode || emojiSearchMode
                          || extendedSymbolMode || controlMode
	                      || credentialMode

    FontLoader {
        id: notoTifinaghFont
        source: "file:///usr/share/fonts/futo-keyboard-sailfish/NotoSansTifinagh-Regular.ttf"
    }
    FontLoader {
        id: notoSinhalaFont
        source: "file:///usr/share/fonts/futo-keyboard-sailfish/NotoSansSinhala-Light.ttf"
    }
    FontLoader {
        id: notoMyanmarFont
        source: "file:///usr/share/fonts/futo-keyboard-sailfish/NotoSansMyanmar-Light.ttf"
    }
    FontLoader {
        id: notoKhmerFont
        source: "file:///usr/share/fonts/futo-keyboard-sailfish/NotoSansKhmer-Light.ttf"
    }
    FontLoader {
        id: notoNaskhArabicFont
        source: "file:///usr/share/fonts/futo-keyboard-sailfish/NotoNaskhArabic-Regular.ttf"
    }
    FontLoader {
        id: androidRiyalFont
        source: "file:///usr/share/fonts/futo-keyboard-sailfish/FutoAndroidRiyal-Regular.ttf"
    }

    readonly property string specialArabicSymbolFontFamily:
            fontLoaderName(notoNaskhArabicFont, "Noto Naskh Arabic")
    readonly property string androidRiyalSymbolFontFamily:
            fontLoaderName(androidRiyalFont, "FUTO Android Riyal")

    ConfigurationGroup {
        id: layoutSettings
        path: "/sailfish/text_input/futo_keyboard"
        property bool numberRowEnabled: false
        property int layoutVariant: 0
        property string layoutAssignments: "{}"
        property int layoutAssignmentVersion: 0
        property string manualLayoutAssignments: "{}"
        property int layoutDefaultsVersion: 2
        property string enabledLanguages: "EN,NL,TR"
        property bool automaticLanguageDetection: true
		property bool mergeSameLayoutLanguages: true
        property string manualPredictionLanguage: ""
        property int symbolNumberLayout: 0
        property int emojiStyle: 3
        property int emojiSkinTone: 0
        property real emojiSizeScale: 1.0
        property string recentEmojis: "[]"
        property string extendedSymbolFavoritesJson: "[]"
        property bool incognitoMode: false
        property bool autoCapitalizationEnabled: true
        property bool clipboardHistoryEnabled: false
        property int clipboardRetentionSeconds: 3600
        property bool clipboardReturnAfterPaste: true
        // Hidden diagnostic switch.  It logs context flags and extension key
        // names only—never surrounding text, suggestions, or typed input.
        property bool debugInputContext: false
    }

    readonly property int layoutVariant: LetterLayouts.clampedIndex(
                                             layoutSettings.layoutVariant)
    readonly property int symbolNumberLayout: Math.max(0, Math.min(1,
                                                                  layoutSettings.symbolNumberLayout))
    readonly property int emojiStyle: Math.max(0, Math.min(3, layoutSettings.emojiStyle))
    readonly property int emojiSkinTone: Math.max(0, Math.min(5,
                                                              layoutSettings.emojiSkinTone))
    readonly property real emojiSizeScale: clampedEmojiSizeScale(
                                               layoutSettings.emojiSizeScale)
    readonly property bool numberRowEnabled: layoutSettings.numberRowEnabled
	readonly property int letterRowCount: LetterLayouts.rowCount(layoutVariant)
	readonly property bool effectiveNumberRowEnabled: numberRowEnabled
			|| LetterLayouts.numberRowRequired(layoutVariant)
	readonly property real numberRowHeightScale: 1.0
	readonly property real keyboardPanelHeight: (1 + letterRowCount
			+ (effectiveNumberRowEnabled
			? numberRowHeightScale : 0)) * keyHeight
    readonly property bool automaticPrivateInput: MInputMethodQuick.hiddenText
            || !MInputMethodQuick.predictionEnabled
            || !!MInputMethodQuick.extensions.privateMode
            || !!MInputMethodQuick.extensions.incognitoMode
            || !!MInputMethodQuick.extensions.sensitiveInput
    // FutoInputHandler owns the authoritative Incognito state.  It combines
    // the manual setting with private/password input and the optional Jolla
    // Privacy Switch trigger.  Keep this fallback for layout previews where
    // the FUTO handler is not present.
    readonly property bool effectiveIncognitoMode: keyboard.inputHandler
            && keyboard.inputHandler.incognitoMode !== undefined
            ? !!keyboard.inputHandler.incognitoMode
            : (layoutSettings.incognitoMode || automaticPrivateInput)
    readonly property int enabledLetterLayoutCount: configuredLayoutGroups().length
    readonly property int enabledLanguageCount: enabledPredictionLanguages().length
    readonly property bool languagesShareActiveLayout:
		layoutSettings.automaticLanguageDetection
		&& layoutSettings.mergeSameLayoutLanguages
    readonly property int languageSwitchCount: languagesShareActiveLayout
            ? enabledLetterLayoutCount : enabledLanguageCount
    readonly property string currentLetterLayoutName: letterLayoutName(layoutVariant)
    readonly property string currentLetterLayoutMenuName: LetterLayouts.menuName(layoutVariant)
    readonly property string currentLayoutLanguages: languagesShareActiveLayout
			? languageNamesForLayout(layoutVariant)
			: LanguageData.name(selectedPredictionLanguage(layoutVariant))
    readonly property string currentLayoutLanguageCodes: languagesShareActiveLayout
			? languagesForLayout(layoutVariant).join("+")
			: selectedPredictionLanguage(layoutVariant)
    readonly property bool usesArabicDigits: LetterLayouts.script(layoutVariant) === "arabic"
    readonly property bool usesPersianDigits: LetterLayouts.script(layoutVariant) === "persian"
    readonly property bool usesLocalizedDigits: usesArabicDigits || usesPersianDigits

    function fontLoaderName(loader, fallback) {
        return loader && String(loader.name || "") !== ""
                ? String(loader.name) : fallback
    }

    function keyFontFamilyForLayout(index) {
        var layoutScript = LetterLayouts.script(index)
        if (layoutScript === "tifinagh")
            return fontLoaderName(notoTifinaghFont, "Noto Sans Tifinagh")
        if (layoutScript === "sinhala")
            return fontLoaderName(notoSinhalaFont, "Noto Sans Sinhala")
        if (layoutScript === "myanmar")
            return fontLoaderName(notoMyanmarFont, "Noto Sans Myanmar")
        if (layoutScript === "khmer")
            return fontLoaderName(notoKhmerFont, "Noto Sans Khmer")
        if (LetterLayouts.name(index) === "AZERTY (Amazigh-Latin)")
            return "DejaVu Sans"
        return ""
    }
    readonly property string currentLayoutMenuLanguageLabel: {
        if (!languagesShareActiveLayout)
            return selectedPredictionLanguage(layoutVariant)
        var languages = languagesForLayout(layoutVariant)
        return languages.length > 2 ? qsTr("MULTI") : languages.join("+")
    }
    readonly property string activePredictionLanguages: predictionLanguagesForLayout(layoutVariant)
    readonly property bool numpadMode: symbolNumberLayout === 1
                                         && attributes.inSymView
                                         && !emojiMode
                                         && !extendedSymbolMode
                                         && !extraKeysMode
    property bool emojiMode: false
    property bool emojiSearchMode: false
    property string emojiSearchQuery: ""
    property var emojiSearchCodes: []
    property int emojiSearchRequestSerial: 0
    property int emojiPage: 1
    property bool extendedSymbolMode: false
    property bool extraKeysMode: false
    property int extendedSymbolPage: 0
    property var extendedSymbolFavorites: []
    property bool controlMode: false
    property bool layoutEditorMode: false
    property bool clipboardMode: false
	property bool credentialMode: false
    readonly property bool cursorMoveMode: keyboard.inputHandler
            && keyboard.inputHandler.cursorMoveMode !== undefined
            && keyboard.inputHandler.cursorMoveMode
    property bool recentEmojiViewActive: false
    property var recentEmojiViewEntries: []
    property bool suppressNextLayoutSwipeCancel: false
    property bool suppressNextLanguageSwipeCancel: false

    onEmojiModeChanged: {
        if (!emojiMode)
            endRecentEmojiView()
    }

    // Keep only the tiny category metadata in the always-loaded layout. The
    // full Emoji 17 database and grid live behind emojiPanelLoader.
    readonly property int emojiCategoryCount: 10
    readonly property var emojiCategoryNames: [
        "Smileys & Emotion", "People & Body", "Animals & Nature",
        "Food & Drink", "Travel & Places", "Activities", "Objects",
        "Symbols", "Flags"
    ]
    readonly property var emojiCategoryIconCodes: [
        "1f600", "1f44b", "1f43b", "1f354", "1f697", "26bd",
        "1f4a1", "2764", "1f3f3"
    ]
    readonly property int extendedSymbolCategoryCount: SymbolData.categories.length

    function extendedSymbolEntriesForPage() {
        var category = SymbolData.categories[Math.max(0, Math.min(
                SymbolData.categories.length - 1, extendedSymbolPage))]
        if (category.id === "favorites")
            return extendedSymbolFavorites
        return SymbolData.entriesForCategory(extendedSymbolPage)
    }

    function extendedSymbolCategoryIdForPage() {
        var category = SymbolData.categories[Math.max(0, Math.min(
                SymbolData.categories.length - 1, extendedSymbolPage))]
        return category ? String(category.id) : ""
    }

    function loadExtendedSymbolFavorites() {
        var parsed = []
        try {
            parsed = JSON.parse(String(layoutSettings.extendedSymbolFavoritesJson))
        } catch (error) {
            parsed = []
        }
        if (!Array.isArray(parsed))
            parsed = []

        var unique = []
        for (var i = 0; i < parsed.length; ++i) {
            var value = String(parsed[i])
            if (value !== "" && unique.indexOf(value) < 0)
                unique.push(value)
        }
        extendedSymbolFavorites = unique
    }

    function isExtendedSymbolFavorite(value) {
        return extendedSymbolFavorites.indexOf(String(value)) >= 0
    }

    function toggleExtendedSymbolFavorite(value) {
        value = String(value)
        if (value === "")
            return
        var updated = extendedSymbolFavorites.slice(0)
        var index = updated.indexOf(value)
        if (index >= 0)
            updated.splice(index, 1)
        else
            updated.unshift(value)
        extendedSymbolFavorites = updated
        layoutSettings.extendedSymbolFavoritesJson = JSON.stringify(updated)
    }

    function extendedSymbolTabIcon(pageIndex) {
        pageIndex = Math.max(0, Math.min(SymbolData.categories.length - 1,
                                         Number(pageIndex)))
        return SymbolData.categories[pageIndex].icon
    }

    function extendedSymbolTabName(pageIndex) {
        pageIndex = Math.max(0, Math.min(SymbolData.categories.length - 1,
                                         Number(pageIndex)))
        return SymbolData.categories[pageIndex].name
    }

    function clampedEmojiSizeScale(value) {
        var parsed = Number(value)
        if (!isFinite(parsed))
            parsed = 1.0
        return Math.max(0.65, Math.min(1.35, parsed))
    }

    function enabledPredictionLanguages() {
        var raw = String(layoutSettings.enabledLanguages).split(",")
        var result = []
        for (var i = 0; i < raw.length; ++i) {
            var code = raw[i].trim()
            if (code !== "" && result.indexOf(code) < 0)
                result.push(code)
        }
        return result.length > 0 ? result : ["EN"]
    }

    function layoutAssignments() {
        var result = {}
        try {
            result = JSON.parse(String(layoutSettings.layoutAssignments))
        } catch (error) {
            result = {}
        }
        return result && typeof result === "object" ? result : {}
    }

    function manualAssignmentFlags() {
        var result = {}
        try {
            result = JSON.parse(String(layoutSettings.manualLayoutAssignments))
        } catch (error) {
            result = {}
        }
        return result && typeof result === "object" ? result : {}
    }

    function layoutForLanguage(languageCode) {
        var assignments = layoutAssignments()
        var value = Number(assignments[String(languageCode)])
        return isFinite(value) ? LetterLayouts.clampedIndex(value)
                               : LetterLayouts.defaultForLanguage(languageCode)
    }

    function assignLayoutToLanguage(languageCode, layoutValue) {
        var compatible = LetterLayouts.compatibleIndices(languageCode)
        layoutValue = LetterLayouts.clampedIndex(layoutValue)
        if (compatible.indexOf(layoutValue) < 0)
            return false
        var assignments = layoutAssignments()
        var manualAssignments = manualAssignmentFlags()
        assignments[String(languageCode)] = layoutValue
        manualAssignments[String(languageCode)] = true
        layoutSettings.manualLayoutAssignments = JSON.stringify(manualAssignments)
        layoutSettings.layoutAssignments = JSON.stringify(assignments)
        layoutSettings.layoutAssignmentVersion = 1
        layoutSettings.layoutVariant = layoutValue
        synchronizeDetectedLanguage()
        return true
    }

    function ensureLayoutAssignments() {
        var assignments = layoutAssignments()
        var manualAssignments = manualAssignmentFlags()
        var languages = enabledPredictionLanguages()
        var legacyMigration = layoutSettings.layoutAssignmentVersion < 1
        var defaultsMigration = layoutSettings.layoutDefaultsVersion < 2
        var changed = legacyMigration
        var manualChanged = false

        if (defaultsMigration) {
            // The old defaults pointed Slovenian at generic QWERTY and
            // Croatian at generic QWERTZ.  Move only those generated values
            // to their exact national layouts; deliberate choices of any
            // other layout remain untouched.
            if (Number(assignments["SL"]) === 0) {
                assignments["SL"] = LetterLayouts.defaultForLanguage("SL")
                changed = true
            }
            if (Number(assignments["HR"]) === 1) {
                assignments["HR"] = LetterLayouts.defaultForLanguage("HR")
                changed = true
            }

            // Existing enabled assignments are user-visible choices and stay
            // untouched.  A disabled assignment that differs from the old
            // generated default is also almost certainly deliberate.
            for (var existingCode in assignments) {
                var existingValue = LetterLayouts.clampedIndex(
                            Number(assignments[existingCode]))
                if (languages.indexOf(existingCode) >= 0
                        || existingValue !== LetterLayouts.legacyDefaultForLanguage(
                                               existingCode)) {
                    if (!manualAssignments[existingCode]) {
                        manualAssignments[existingCode] = true
                        manualChanged = true
                    }
                }
            }
        }

        // Generated assignments for disabled languages should not shadow a
        // newly improved national default.  Explicit editor choices remain.
        for (var storedCode in assignments) {
            if (languages.indexOf(storedCode) < 0 && !manualAssignments[storedCode]) {
                delete assignments[storedCode]
                changed = true
            }
        }

        for (var i = 0; i < languages.length; ++i) {
            var code = languages[i]
            var value = Number(assignments[code])
            if (!isFinite(value)
                    || LetterLayouts.compatibleIndices(code).indexOf(
                        LetterLayouts.clampedIndex(value)) < 0) {
                assignments[code] = LetterLayouts.defaultForLanguage(code)
                changed = true
            }
        }
        if (manualChanged)
            layoutSettings.manualLayoutAssignments = JSON.stringify(manualAssignments)
        if (changed) {
            layoutSettings.layoutAssignments = JSON.stringify(assignments)
            layoutSettings.layoutAssignmentVersion = 1
        }
        if (defaultsMigration)
            layoutSettings.layoutDefaultsVersion = 2
        ensureActiveLetterLayout()
    }

    function configuredLayoutGroups() {
        var languages = enabledPredictionLanguages()
        var result = []
        for (var i = 0; i < languages.length; ++i) {
            var value = layoutForLanguage(languages[i])
            if (result.indexOf(value) < 0)
                result.push(value)
        }
        return result.length > 0 ? result : [0]
    }

    function languagesForLayout(layoutValue) {
        var languages = enabledPredictionLanguages()
        var result = []
        for (var i = 0; i < languages.length; ++i) {
            if (layoutForLanguage(languages[i]) === layoutValue)
                result.push(languages[i])
        }
        return result
    }

    function predictionLanguagesForLayout(layoutValue) {
        if (!languagesShareActiveLayout) {
            var selected = selectedPredictionLanguage(layoutValue)
            return selected !== "" && LanguageData.predictionSupported(selected)
                    ? selected : ""
        }
        var languages = languagesForLayout(layoutValue)
        var result = []
        for (var i = 0; i < languages.length; ++i) {
            if (LanguageData.predictionSupported(languages[i]))
                result.push(languages[i])
        }
        return result.join(",")
    }

    function selectedPredictionLanguage(layoutValue) {
        var languages = languagesForLayout(layoutValue)
        if (languages.length < 1)
            return ""
        var selected = String(layoutSettings.manualPredictionLanguage).trim()
        if (languages.indexOf(selected) >= 0)
            return selected
        if (handler && handler.detectedLanguage !== undefined) {
            var detected = String(handler.detectedLanguage)
            if (languages.indexOf(detected) >= 0)
                return detected
        }
        return languages[0]
    }

    function languageNamesForLayout(layoutValue) {
        var languages = languagesForLayout(layoutValue)
        var result = []
        for (var i = 0; i < languages.length; ++i)
            result.push(LanguageData.name(languages[i]))
        return result.join(" + ")
    }

    function compatibleLetterLayouts(languageCode) {
        return LetterLayouts.compatibleIndices(languageCode)
    }

    function languageName(languageCode) {
        return LanguageData.name(languageCode)
    }

    function letterForLayout(layoutValue, row, column) {
        return LetterLayouts.caption(layoutValue, row, column, false)
    }

    function rowLengthForLayout(layoutValue, row) {
        return LetterLayouts.rowLength(layoutValue, row)
    }

    function rowCountForLayout(layoutValue) {
        return LetterLayouts.rowCount(layoutValue)
    }

    function letterLayoutName(value) {
        return LetterLayouts.name(value)
    }

    function letterAt(row, column) {
        return LetterLayouts.caption(layoutVariant, row, column, false)
    }

    function shiftedLetterAt(row, column) {
        return LetterLayouts.caption(layoutVariant, row, column, true)
    }

    function letterAlternatives(base, shifted) {
        return LetterLayouts.alternatives(layoutVariant, base,
                                          currentLayoutLanguageCodes, shifted)
    }

    function letterRowLength(row) {
        return LetterLayouts.rowLength(layoutVariant, row)
    }

    function letterRowsUseIndependentSizing() {
        // KeyboardRow normally gives every letter row the smallest key width
        // required by any row. Arabic, Cyrillic, and the dense South Slavic
        // Latin layouts have eleven-letter rows plus a differently sized
        // Shift/Backspace row, so sharing that width compresses the letters
        // into a narrow centred block. Let them consume each row's width.
        return LetterLayouts.usesIndependentSizing(layoutVariant)
    }

    function digitForLayout(value) {
        var digit = String(value)
        if (!usesLocalizedDigits)
            return digit
        var index = Number(digit)
        return isFinite(index) && index >= 0 && index <= 9
                ? (usesPersianDigits ? "۰۱۲۳۴۵۶۷۸۹" : "٠١٢٣٤٥٦٧٨٩").charAt(index)
                : digit
    }

    function numberPageLabel() {
        return "123"
    }

    function letterPageLabel() {
        return usesArabicDigits ? "أبج" : (usesPersianDigits ? "ابپ" : "ABC")
    }

    function punctuationForLayout(value) {
        value = String(value)
        if (!usesLocalizedDigits)
            return value
        if (value === ",") return "،"
        if (value === "?") return "؟"
        if (value === ";") return "؛"
        if (value === "%") return "٪"
        return value
    }

    function secondarySymbolAt(row, column) {
        var result = LetterLayouts.secondarySymbolForLayout(layoutVariant,
                                                             row, column)
        if (result === "")
            return ""
        // The Arabic letter page offers Arabic-Indic digits from the held
        // letter shortcuts.  If a dedicated Arabic number row is visible,
        // those shortcuts become Western digits so both forms stay one hold
        // away.  The actual 123 page itself always uses Western digits.
        result = row === 0 && column < 10 && usesLocalizedDigits
                && !attributes.inSymView && !numberRowEnabled
                ? digitForLayout(result) : result
        return punctuationForLayout(result)
    }

    function secondSymbolAt(row, column) {
        var symbols = row === 0
                ? ["€", "£", "$", "¥", "₹", "%", "<", ">", "[", "]", "¢", "‰"]
                : row === 1
                  ? ["`", "^", "|", "_", "§", "{", "}", "¡", "¿", "~", "¡", "¿"]
                  : ["«", "»", "\"", "“", "”", "„", "~", "®", "§", "¶", "°", "·"]
        if (row === 0 && column >= 0 && column < 10 && usesLocalizedDigits)
            return digitForLayout(String((column + 1) % 10))
        return column >= 0 && column < symbols.length
                ? punctuationForLayout(symbols[column]) : ""
    }

    function applyConfiguredAutocaps() {
        if (keyboard.layout !== root)
            return
        if (!layoutSettings.autoCapitalizationEnabled) {
            if (keyboard.autocaps)
                keyboard.autocaps = false
        } else if (keyboard.applyAutocaps) {
            keyboard.applyAutocaps()
        }
    }

    function logInputContextMetadata(reason) {
        if (!layoutSettings.debugInputContext || !MInputMethodQuick.active)
            return
        var keys = []
        var extensions = MInputMethodQuick.extensions
        for (var key in extensions)
            keys.push(String(key))
        keys.sort()
        console.warn("FUTO_CONTEXT reason=" + reason
                     + " hidden=" + MInputMethodQuick.hiddenText
                     + " prediction=" + MInputMethodQuick.predictionEnabled
                     + " contentType=" + MInputMethodQuick.contentType
					 + " actionLabel=" + MInputMethodQuick.actionKeyOverride.label
					 + " actionIcon=" + MInputMethodQuick.actionKeyOverride.icon
					 + " actionEnabled=" + MInputMethodQuick.actionKeyOverride.enabled
                     + " extensionKeys=" + keys.join(","))
    }

    function ensureActiveLetterLayout() {
        var enabled = configuredLayoutGroups()
        if (enabled.indexOf(layoutVariant) < 0)
            layoutSettings.layoutVariant = enabled[0]
        synchronizeDetectedLanguage()
    }

    function synchronizeDetectedLanguage() {
        if (!handler || handler.detectedLanguage === undefined)
            return
        var languages = languagesForLayout(layoutVariant)
        if (languages.length < 1)
            return
        if (!languagesShareActiveLayout) {
            var selected = selectedPredictionLanguage(layoutVariant)
            if (selected === "")
                return
            if (String(layoutSettings.manualPredictionLanguage) !== selected)
                layoutSettings.manualPredictionLanguage = selected
            if (String(handler.detectedLanguage) !== selected)
                handler.detectedLanguage = selected
            return
        }
        if (languages.indexOf(String(handler.detectedLanguage)) < 0)
            handler.detectedLanguage = languages[0]
    }

    function cycleLetterLayout() {
        if (!languagesShareActiveLayout) {
            var languages = enabledPredictionLanguages()
            if (languages.length < 2)
                return
            var selected = selectedPredictionLanguage(layoutVariant)
            var currentLanguage = languages.indexOf(selected)
            var nextLanguage = languages[(currentLanguage + 1 + languages.length)
                                         % languages.length]
            var nextLayout = layoutForLanguage(nextLanguage)
            if (handler && handler.cancelSwipeSession)
                handler.cancelSwipeSession()
            if (layoutVariant !== nextLayout) {
                suppressNextLayoutSwipeCancel = true
                layoutSettings.layoutVariant = nextLayout
            }
            if (String(layoutSettings.manualPredictionLanguage) !== nextLanguage)
                suppressNextLanguageSwipeCancel = true
            layoutSettings.manualPredictionLanguage = nextLanguage
            synchronizeDetectedLanguage()
            controlTimeout.restart()
            return
        }
        var enabled = configuredLayoutGroups()
        if (enabled.length < 2) {
            return
        }
        var current = enabled.indexOf(layoutVariant)
        if (handler && handler.cancelSwipeSession)
            handler.cancelSwipeSession()
        suppressNextLayoutSwipeCancel = true
        layoutSettings.layoutVariant = enabled[(current + 1 + enabled.length) % enabled.length]
        synchronizeDetectedLanguage()
        controlTimeout.restart()
    }

    function emojiAssetPath(code) {
        if (emojiStyle === 3)
            return ""
        var directory = emojiStyle === 1 ? "openmoji" : emojiStyle === 2 ? "noto" : "twemoji"
		var home = String(StandardPaths.home)
		var root = (home.indexOf("file://") === 0 ? home : "file://" + home)
				+ "/.local/share/futo-keyboard-sailfish/content/emoji/"
		var revision = handler && handler.contentRevision !== undefined
				? handler.contentRevision : 0
		return root + directory + "/"
                + String(code).toLowerCase() + (emojiStyle === 2 ? ".png" : ".svg")
				+ "?r=" + revision
    }

    function emojiTabIconCode(pageIndex) {
        return pageIndex === 0 ? "1f550" : emojiCategoryIconCodes[pageIndex - 1]
    }

	function emojiTabAssetPath(pageIndex) {
		return "file:///usr/share/futo-keyboard-sailfish/emoji-tabs/"
				+ emojiTabIconCode(pageIndex) + ".png"
	}

    function emojiTabName(pageIndex) {
        return pageIndex === 0 ? qsTr("Recent") : emojiCategoryNames[pageIndex - 1]
    }

    function recentEmojiCodes() {
        var codes
        try {
            codes = JSON.parse(String(layoutSettings.recentEmojis))
        } catch (error) {
            codes = []
        }
        if (!codes || codes.length === undefined)
            codes = []
        return codes
    }

    function beginRecentEmojiView() {
        // Snapshot codes rather than the large EmojiData objects. Selecting an
        // emoji must not reorder the visible history until the view changes.
        recentEmojiViewEntries = recentEmojiCodes()
        recentEmojiViewActive = true
    }

    function endRecentEmojiView() {
        recentEmojiViewActive = false
        recentEmojiViewEntries = []
    }

    function emojiEntriesForPage() {
        var provider = emojiPanelLoader.item
        if (!provider)
            return []
        var recentCodes = recentEmojiViewActive ? recentEmojiViewEntries
                                                : recentEmojiCodes()
        return provider.entriesForPage(emojiPage, emojiSearchCodes, recentCodes)
    }

    function clearEmojiSearchResults() {
        emojiSearchRequestSerial++
        emojiSearchCodes = []
        if (emojiPanelLoader.item)
            emojiPanelLoader.item.searchRevision++
    }

    function requestEmojiSearchResults() {
        var query = String(emojiSearchQuery).trim()
        clearEmojiSearchResults()
        if (query === "" || !handler || !handler.searchEmoji)
            return
        var serial = emojiSearchRequestSerial
        var languages = enabledPredictionLanguages()
        handler.searchEmoji(query, languages.join(","), function(resultJson) {
            if (serial !== root.emojiSearchRequestSerial)
                return
            var result = []
            try {
                result = JSON.parse(String(resultJson))
            } catch (error) {
                result = []
            }
            root.emojiSearchCodes = result && result.length !== undefined
                    ? result : []
            if (emojiPanelLoader.item)
                emojiPanelLoader.item.searchRevision++
        }, function() {
            if (serial === root.emojiSearchRequestSerial) {
                root.emojiSearchCodes = []
                if (emojiPanelLoader.item)
                    emojiPanelLoader.item.searchRevision++
            }
        })
    }

    function recordEmoji(baseCode) {
        if (effectiveIncognitoMode)
            return
        var codes
        try {
            codes = JSON.parse(String(layoutSettings.recentEmojis))
        } catch (error) {
            codes = []
        }
        if (!codes || codes.length === undefined)
            codes = []
        var result = [String(baseCode)]
        for (var i = 0; i < codes.length && result.length < 60; ++i) {
            if (String(codes[i]) !== String(baseCode))
                result.push(String(codes[i]))
        }
        layoutSettings.recentEmojis = JSON.stringify(result)
    }

    function showEmojiPicker() {
        keyboard.inSymView = false
        keyboard.inSymView2 = false
        extendedSymbolMode = false
        extraKeysMode = false
        controlMode = false
        layoutEditorMode = false
        clipboardMode = false
		credentialMode = false
        emojiSearchMode = false
        emojiSearchQuery = ""
        clearEmojiSearchResults()
        emojiPage = recentEmojiCodes().length > 0 ? 0 : 1
        if (emojiPage === 0)
            beginRecentEmojiView()
        else
            endRecentEmojiView()
        emojiMode = true
        updateSizes()
    }

    function hideEmojiPicker() {
        emojiMode = false
        emojiSearchMode = false
        emojiSearchQuery = ""
        clearEmojiSearchResults()
        endRecentEmojiView()
        updateSizes()
    }

    function showExtendedSymbolPicker() {
        keyboard.inSymView = false
        keyboard.inSymView2 = false
        extraKeysMode = false
        emojiMode = false
        emojiSearchMode = false
        emojiSearchQuery = ""
        endRecentEmojiView()
        controlMode = false
        layoutEditorMode = false
        clipboardMode = false
		credentialMode = false
        extendedSymbolPage = 0
        extendedSymbolMode = true
        updateSizes()
    }

    function hideExtendedSymbolPicker() {
        extendedSymbolMode = false
        updateSizes()
    }

    function selectExtendedSymbolPage(pageIndex) {
        extendedSymbolPage = Math.max(0, Math.min(
                extendedSymbolCategoryCount - 1, Number(pageIndex)))
        extendedSymbolMode = true
        updateSizes()
    }

    function selectEmojiPage(pageIndex) {
        emojiSearchMode = false
        emojiSearchQuery = ""
        clearEmojiSearchResults()
        var nextPage = Math.max(0, Math.min(emojiCategoryCount - 1, pageIndex))
        if (nextPage !== emojiPage) {
            if (nextPage === 0)
                beginRecentEmojiView()
            else
                endRecentEmojiView()
        }
        emojiPage = nextPage
        emojiMode = true
        updateSizes()
    }

    function startEmojiSearch() {
        keyboard.inSymView = false
        keyboard.inSymView2 = false
        extraKeysMode = false
        controlMode = false
        extendedSymbolMode = false
        emojiMode = false
        endRecentEmojiView()
        emojiSearchMode = true
        updateSizes()
    }

    function finishEmojiSearch() {
        emojiSearchQuery = emojiSearchQuery.trim()
        emojiSearchMode = false
        emojiPage = emojiSearchQuery === "" ? 1 : -1
        endRecentEmojiView()
        emojiMode = true
        requestEmojiSearchResults()
        updateSizes()
    }

    function cancelEmojiSearch() {
        emojiSearchQuery = ""
        clearEmojiSearchResults()
        emojiSearchMode = false
        emojiPage = recentEmojiCodes().length > 0 ? 0 : 1
        if (emojiPage === 0)
            beginRecentEmojiView()
        else
            endRecentEmojiView()
        emojiMode = true
        updateSizes()
    }

    function handleEmojiSearchKey(key) {
        if (!emojiSearchMode)
            return false
        if (key.key === Qt.Key_Backspace) {
            emojiSearchQuery = emojiSearchQuery.slice(0, -1)
        } else if (key.key === Qt.Key_Return || key.key === Qt.Key_Enter) {
            finishEmojiSearch()
        } else if (key.key === Qt.Key_Space) {
            if (emojiSearchQuery !== "" && emojiSearchQuery.slice(-1) !== " ")
                emojiSearchQuery += " "
        } else if (key.text && key.text.length > 0) {
            // Preserve what the key actually produced.  Lowercasing here broke
            // Turkish I/İ/ı and could create an extra combining dot.
            emojiSearchQuery += String(key.text)
        }
        return true
    }

    function showControlStrip() {
        emojiMode = false
        emojiSearchMode = false
        extendedSymbolMode = false
        // Quick Settings is an overlay. Keep the Fn/desktop page underneath
        // when it was the active page, instead of exposing symbol page two.
        layoutEditorMode = false
        clipboardMode = false
		credentialMode = false
        controlMode = true
        controlTimeout.restart()
        updateSizes()
    }

    function hideControlStrip() {
        controlMode = false
        controlTimeout.stop()
        updateSizes()
    }

    function beginControlInteraction() {
        if (controlMode)
            controlTimeout.stop()
    }

    function endControlInteraction() {
        if (controlMode)
            controlTimeout.restart()
    }

    function showLayoutEditor() {
        keyboard.inSymView = false
        keyboard.inSymView2 = false
        extraKeysMode = false
        emojiMode = false
        emojiSearchMode = false
        extendedSymbolMode = false
        clipboardMode = false
		credentialMode = false
        controlMode = false
        layoutEditorMode = true
        controlTimeout.stop()
        updateSizes()
    }

    function hideLayoutEditor() {
        layoutEditorMode = false
        updateSizes()
    }

    function showClipboardHistory() {
        if (!layoutSettings.clipboardHistoryEnabled)
            return
        keyboard.inSymView = false
        keyboard.inSymView2 = false
        extraKeysMode = false
        emojiMode = false
        emojiSearchMode = false
        extendedSymbolMode = false
        layoutEditorMode = false
        controlMode = false
		credentialMode = false
        clipboardMode = true
        if (handler && handler.refreshClipboardHistory)
            handler.refreshClipboardHistory()
        controlTimeout.stop()
        updateSizes()
    }

    function hideClipboardHistory() {
        clipboardMode = false
        updateSizes()
    }

	function showSavedCredentialChooser() {
		keyboard.inSymView = false
		keyboard.inSymView2 = false
		extraKeysMode = false
		emojiMode = false
		emojiSearchMode = false
		extendedSymbolMode = false
		layoutEditorMode = false
		clipboardMode = false
		controlMode = false
		credentialMode = true
		controlTimeout.stop()
		updateSizes()
	}

	function hideSavedCredentialChooser() {
		credentialMode = false
		updateSizes()
	}

    function exitSymbolMode() {
        extendedSymbolMode = false
        extraKeysMode = false
        keyboard.inSymView = false
        keyboard.inSymView2 = false
    }

    function showSecondSymbolPage() {
        extendedSymbolMode = false
        extraKeysMode = false
        keyboard.inSymView = true
        keyboard.inSymView2 = true
    }

    function showFirstSymbolPage() {
        extendedSymbolMode = false
        extraKeysMode = false
        keyboard.inSymView = true
        keyboard.inSymView2 = false
    }

    function showDesktopKeysPage() {
        emojiMode = false
        emojiSearchMode = false
        emojiSearchQuery = ""
        extendedSymbolMode = false
        layoutEditorMode = false
        clipboardMode = false
		credentialMode = false
        controlMode = false
        keyboard.inSymView = true
        keyboard.inSymView2 = true
        extraKeysMode = true
        updateSizes()
    }

    Timer {
        id: controlTimeout
        interval: 7000
        onTriggered: root.hideControlStrip()
    }

    Timer {
        id: contextDebugTimer
        interval: 300
        onTriggered: root.logInputContextMetadata("focus")
    }

    Connections {
        target: MInputMethodQuick
        onActiveChanged: {
            if (MInputMethodQuick.active && layoutSettings.debugInputContext)
                contextDebugTimer.restart()
            if (!MInputMethodQuick.active) {
                // InputHandler.active does not reliably change when Maliit is
                // dismissed while its editor retains focus. Stop capture from
                // the authoritative keyboard visibility signal as well.
                if (keyboard.inputHandler && keyboard.inputHandler.cancelVoiceInput)
                    keyboard.inputHandler.cancelVoiceInput()
                root.emojiMode = false
                root.emojiSearchMode = false
                root.emojiSearchQuery = ""
                root.extendedSymbolMode = false
                root.extraKeysMode = false
                root.layoutEditorMode = false
                root.clipboardMode = false
				if (root.credentialMode && keyboard.inputHandler
						&& keyboard.inputHandler.cancelSavedCredentialChooser)
					keyboard.inputHandler.cancelSavedCredentialChooser()
				else
					root.credentialMode = false
                root.hideControlStrip()
            }
        }
        onFocusTargetChanged: {
            if (MInputMethodQuick.active && layoutSettings.debugInputContext)
                contextDebugTimer.restart()
        }
        onExtensionsChanged: {
            if (MInputMethodQuick.active && layoutSettings.debugInputContext)
                contextDebugTimer.restart()
        }
    }

    Connections {
        target: keyboard
        onInSymViewChanged: {
            if (keyboard.inSymView) {
                root.hideControlStrip()
                root.layoutEditorMode = false
                root.clipboardMode = false
				if (root.credentialMode && keyboard.inputHandler
						&& keyboard.inputHandler.cancelSavedCredentialChooser)
					keyboard.inputHandler.cancelSavedCredentialChooser()
				root.credentialMode = false
            }
            if (!keyboard.inSymView)
                root.extraKeysMode = false
            root.updateSizes()
        }
        onInSymView2Changed: root.updateSizes()
        onAutocapsChanged: {
            if (keyboard.layout === root
                    && !layoutSettings.autoCapitalizationEnabled && keyboard.autocaps)
                keyboard.autocaps = false
        }
        onLayoutChanged: root.applyConfiguredAutocaps()
    }

    Connections {
        target: layoutSettings
        onLayoutVariantChanged: {
            if (root.suppressNextLayoutSwipeCancel) {
                root.suppressNextLayoutSwipeCancel = false
            } else if (root.handler && root.handler.cancelSwipeSession) {
                root.handler.cancelSwipeSession()
            }
            root.updateSizes()
            root.synchronizeDetectedLanguage()
        }
        onEnabledLanguagesChanged: root.ensureLayoutAssignments()
        onLayoutAssignmentsChanged: root.ensureActiveLetterLayout()
        onAutomaticLanguageDetectionChanged: root.synchronizeDetectedLanguage()
        onManualPredictionLanguageChanged: {
            if (root.suppressNextLanguageSwipeCancel) {
                root.suppressNextLanguageSwipeCancel = false
            } else if (root.handler && root.handler.cancelSwipeSession) {
                root.handler.cancelSwipeSession()
            }
            root.synchronizeDetectedLanguage()
        }
        onNumberRowEnabledChanged: root.updateSizes()
        onSymbolNumberLayoutChanged: root.updateSizes()
        onAutoCapitalizationEnabledChanged: root.applyConfiguredAutocaps()
        onExtendedSymbolFavoritesJsonChanged: root.loadExtendedSymbolFavorites()
        onDebugInputContextChanged: {
            if (layoutSettings.debugInputContext && MInputMethodQuick.active)
                contextDebugTimer.restart()
        }
    }

    Component.onCompleted: {
        loadExtendedSymbolFavorites()
        ensureLayoutAssignments()
        synchronizeDetectedLanguage()
        applyConfiguredAutocaps()
    }

    FutoDesktopToolbar {
        targetLayout: root
    }

    KeyboardRow {
		id: numberRow
		followRowHeight: false
		height: root.keyHeight
        opacity: root.cursorMoveMode ? 0 : 1
        visible: !root.emojiMode && !root.extendedSymbolMode
                 && !root.extraKeysMode
                 && !root.layoutEditorMode && !root.clipboardMode
				 && !root.credentialMode
                 && !root.numpadMode && root.effectiveNumberRowEnabled
                 && LetterLayouts.numberRowLength(root.layoutVariant) === 0
        FutoCharacterKey { secondaryHintEligible: false; caption: root.digitForLayout("1"); captionShifted: caption; symView: "!"; symView2: "¹" }
        FutoCharacterKey { secondaryHintEligible: false; caption: root.digitForLayout("2"); captionShifted: caption; symView: "@"; symView2: "²" }
        FutoCharacterKey { secondaryHintEligible: false; caption: root.digitForLayout("3"); captionShifted: caption; symView: "#"; symView2: "³" }
        FutoCharacterKey { secondaryHintEligible: false; caption: root.digitForLayout("4"); captionShifted: caption; symView: "$"; symView2: "€" }
        FutoCharacterKey { secondaryHintEligible: false; caption: root.digitForLayout("5"); captionShifted: caption; symView: "%"; symView2: "‰" }
        FutoCharacterKey { secondaryHintEligible: false; caption: root.digitForLayout("6"); captionShifted: caption; symView: "^"; symView2: "¼" }
        FutoCharacterKey { secondaryHintEligible: false; caption: root.digitForLayout("7"); captionShifted: caption; symView: "&"; symView2: "½" }
        FutoCharacterKey { secondaryHintEligible: false; caption: root.digitForLayout("8"); captionShifted: caption; symView: "*"; symView2: "¾" }
        FutoCharacterKey { secondaryHintEligible: false; caption: root.digitForLayout("9"); captionShifted: caption; symView: "("; symView2: "[" }
        FutoCharacterKey { secondaryHintEligible: false; caption: root.digitForLayout("0"); captionShifted: caption; symView: ")"; symView2: "]" }
    }

    FutoGeneratedNumberRow {
        targetLayout: root
        layoutIndex: root.layoutVariant
        visible: !root.emojiMode && !root.extendedSymbolMode
                 && !root.extraKeysMode && !root.layoutEditorMode
                 && !root.clipboardMode && !root.credentialMode
                 && !root.numpadMode && root.effectiveNumberRowEnabled
                 && LetterLayouts.numberRowLength(root.layoutVariant) > 0
    }

    FutoLetterRow { targetLayout: root; layoutIndex: root.layoutVariant; rowIndex: 0 }
    FutoLetterRow { targetLayout: root; layoutIndex: root.layoutVariant; rowIndex: 1 }
    FutoLetterRow { targetLayout: root; layoutIndex: root.layoutVariant; rowIndex: 2 }
    FutoLetterRow { targetLayout: root; layoutIndex: root.layoutVariant; rowIndex: 3 }
    FutoLetterRow { targetLayout: root; layoutIndex: root.layoutVariant; rowIndex: 4 }

    FutoSpacebarRow {
        opacity: root.cursorMoveMode ? 0 : 1
        visible: !root.emojiMode && !root.extendedSymbolMode
                 && !root.extraKeysMode
                 && !root.layoutEditorMode && !root.clipboardMode
				 && !root.credentialMode
                 && !root.numpadMode
        targetLayout: root
        symbolNumberLayout: root.symbolNumberLayout
    }

    FutoNumpadLayout {
        visible: root.numpadMode && !root.extendedSymbolMode
                 && !root.extraKeysMode
                 && !root.layoutEditorMode && !root.clipboardMode
				 && !root.credentialMode
        targetLayout: root
        secondPage: attributes.inSymView2
    }

    Loader {
        id: emojiPanelLoader
        active: root.emojiMode || root.emojiSearchMode
        visible: root.emojiMode
        asynchronous: false
        source: "FutoEmojiPanel.qml"

        onLoaded: item.targetLayout = root
    }

    FutoExtendedSymbolGrid {
        visible: root.extendedSymbolMode
        targetLayout: root
    }

    FutoDesktopKeyGrid {
        visible: root.extraKeysMode
        targetLayout: root
    }

    FutoLayoutEditor {
        visible: root.layoutEditorMode
        targetLayout: root
		height: root.keyboardPanelHeight
    }

    FutoClipboardPanel {
        visible: root.clipboardMode
        targetLayout: root
        targetHandler: root.handler
		height: root.keyboardPanelHeight
    }

	FutoCredentialPanel {
		visible: root.credentialMode
		targetLayout: root
		targetHandler: root.handler
		height: root.keyboardPanelHeight
	}

    KeyboardRow {
        visible: root.emojiMode || root.extendedSymbolMode
        splitIndex: 3
        FutoEmojiBackKey { targetLayout: root }
        FutoSpacebarKey { languageLabel: "" }
        FutoSpacebarKey { active: splitActive; languageLabel: "" }
        FutoEnterKey { targetLayout: root }
        FutoBackspaceKey {}
    }
}
