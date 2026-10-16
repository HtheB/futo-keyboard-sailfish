/*
 * Based on Jolla's BSD-licensed keyboard layouts.
 * Modified for the independent FUTO Keyboard Sailfish integration.
 */
import QtQuick 2.0
import Sailfish.Silica 1.0 as Silica
import Nemo.Configuration 1.0
import Nemo.DBus 2.0
import com.jolla.keyboard 1.0
import com.meego.maliitquick 1.0
import ".."
import "FutoSymbolData.js" as SymbolData
import "FutoLetterLayouts.js" as LetterLayouts
import "FutoLanguageData.js" as LanguageData
import "FutoCustomLayouts.js" as CustomLayouts

FutoKeyboardLayout {
    id: root
    splitSupported: true
    // Keep Thumb mode split in landscape, but mount the normal horizontal
    // header when a tool page needs Quick Settings or category/search tabs.
    splitTopItemRequired: emojiMode || emojiSearchMode
                          || extendedSymbolMode || controlMode
	                      || compositionHint !== ""
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
        id: notoTibetanFont
        source: "file:///usr/share/fonts/futo-keyboard-sailfish/NotoSerifTibetan-Light.ttf"
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
        property real numberRowHeightScale: 1.0
        property int layoutVariant: 0
        property string layoutAssignments: "{}"
        property string layoutIds: "{}"
        property string customLayoutsJson: '{"version":1,"layouts":[]}'
        property int layoutAssignmentVersion: 0
        property string manualLayoutAssignments: "{}"
        property int layoutDefaultsVersion: 3
        property string enabledLanguages: "EN,NL,TR"
        property bool automaticLanguageDetection: true
		property bool mergeSameLayoutLanguages: true
        property string manualPredictionLanguage: ""
        property int symbolNumberLayout: 0
        // 0 nothing, 1 move the cursor, 2 switch language. Below zero means
        // the choice predates this setting and follows the old on/off switch.
        property int spacebarHoldAction: -1
        property bool spacebarCursorControlEnabled: true
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

    property int customLayoutRevision: 0
    property string loadedCustomLayoutsJson: ""
    readonly property int layoutVariant: { customLayoutRevision; return LetterLayouts.clampedIndex(layoutSettings.layoutVariant) }
    readonly property var customDocument: { customLayoutRevision; return customPreviewActive ? customPreviewCandidate.layout : LetterLayouts.customDocument(layoutVariant) }
    readonly property bool customLayoutActive: customDocument !== null
    property string customPageId: ""
    readonly property var customPage: customDocument ? customDocument.pages[CustomLayouts.pageIndex(customDocument, customPageId)] : null
    readonly property bool customPageIsText: !customPage || customPage.kind === "text"
    readonly property bool customInputRightToLeft: customLayoutActive
            && ["AR", "FA", "UR", "PS", "UG", "SD"].indexOf(selectedPredictionLanguage(layoutVariant)) >= 0
    readonly property bool customSurfaceVisible: customLayoutActive && !attributes.inSymView
            && !emojiMode && !extendedSymbolMode && !extraKeysMode && !layoutEditorMode
            && !clipboardMode && !credentialMode
    onCustomDocumentChanged: {
        if (!customDocument) customPageId = ""
        else if (!customPageId || customDocument.pages[CustomLayouts.pageIndex(customDocument, customPageId)].id !== customPageId)
            customPageId = customDocument.pages[0].id
        if (customDocument && keyboard.layout === root) {
            keyboard.inSymView = false
            keyboard.inSymView2 = false
        }
        if (handler && handler.clearCustomDeadKey) handler.clearCustomDeadKey()
        rowRelayoutTimer.restart()
    }
    function reloadCustomLayouts(raw) {
        raw = String(raw)
        if (raw === loadedCustomLayoutsJson) return
        var previousId = LetterLayouts.idForIndex(layoutSettings.layoutVariant)
        var previousLanguage = selectedPredictionLanguage(layoutVariant)
        if (!LetterLayouts.setCustomLayouts(raw)) return
        loadedCustomLayoutsJson = raw
        customLayoutRevision++
        var index = LetterLayouts.indexForId(previousId)
        if (index < 0 && previousLanguage !== "")
            index = LetterLayouts.defaultForLanguage(previousLanguage)
        if (index >= 0 && layoutSettings.layoutVariant !== index) layoutSettings.layoutVariant = index
        if (layoutSettings.customLayoutsJson !== String(raw)) layoutSettings.customLayoutsJson = String(raw)
        if (layoutConfigurationReady) ensureLayoutAssignments()
        rowRelayoutTimer.restart()
    }
    function activateCustomAction(item) {
        if (item.action === "page" && customDocument) {
            var document = customDocument
            var destination = document.pages[CustomLayouts.pageIndex(document, item.target)].id
            if (handler && handler.finishConversion)
                handler.finishConversion(function() { if (root.customDocument === document) root.applyCustomPage(destination) })
            else applyCustomPage(destination)
        } else if (item.action === "emoji") showEmojiPicker()
        else if (item.action === "symbols") showExtendedSymbolPicker()
        else if (item.action === "language") cycleLetterLayout()
        else if (item.action === "clipboard") showClipboardHistory()
        else if (item.action === "voice" && handler) { hideControlStrip(); handler.toggleVoiceInput() }
        else if (item.action !== "spacer" && handler) handler.activateDesktopKey(item.action)
    }
    function applyCustomPage(id) {
        if (!customDocument) return
        if (handler && handler.clearCustomDeadKey) handler.clearCustomDeadKey()
        if (handler && handler.cancelSwipeSession) handler.cancelSwipeSession()
        customPageId = customDocument.pages[CustomLayouts.pageIndex(customDocument, id)].id
    }
    function composeCustomDeadKey(dead, text) { return CustomLayouts.compose(dead, text) }
    // An unsaved test layout is a short, foreground-process-scoped lease. It
    // never enters the saved catalogue or changes the user's layout choice.
    ConfigurationGroup {
        id: customPreviewSettings
        path: "/sailfish/text_input/futo_keyboard/layoutEditorPreview"
        property string document: ""
        property double expires: 0
        onExpiresChanged: root.refreshCustomPreviewLease()
    }
    readonly property var customPreviewCandidate: parseCustomPreview(customPreviewSettings.document)
    onCustomPreviewCandidateChanged: { customPreviewFocusMatches = false; refreshCustomPreviewLease(); refreshCustomPreviewFocus() }
    property bool customPreviewLeaseValid: false
    property bool customPreviewFocusMatches: false
    property int customPreviewFocusSerial: 0
    readonly property bool customPreviewActive: customPreviewCandidate !== null
            && customPreviewLeaseValid && customPreviewFocusMatches && MInputMethodQuick.active
    function parseCustomPreview(raw) {
        if (!raw || raw.length > 262400) return null
        try {
            var value = JSON.parse(raw)
            if (!value || typeof value.owner !== "number" || value.owner < 2
                    || value.owner > 2147483647 || Math.floor(value.owner) !== value.owner
                    || !CustomLayouts.valid(value.layout, false)) return null
            return value
        } catch (error) { return null }
    }
    function refreshCustomPreviewLease() {
        var remaining = customPreviewSettings.expires - Date.now()
        var wasValid = customPreviewLeaseValid
        // Reject far-future/stale leases as well as malformed documents.
        customPreviewLeaseValid = customPreviewCandidate !== null && remaining > 0 && remaining <= 6500
        customPreviewExpiry.stop()
        if (customPreviewLeaseValid) {
            customPreviewExpiry.interval = Math.ceil(remaining) + 10
            customPreviewExpiry.start()
            if (!wasValid) refreshCustomPreviewFocus()
        } else { customPreviewFocusSerial++; customPreviewFocusMatches = false }
    }
    function refreshCustomPreviewFocus() {
        var serial = ++customPreviewFocusSerial
        customPreviewFocusMatches = false
        if (!customPreviewLeaseValid || !customPreviewCandidate || !MInputMethodQuick.active || keyboard.layout !== root) return
        var owner = customPreviewCandidate.owner
        customPreviewCompositor.typedCall("privateTopmostWindowProcessId", [], function(pid) {
            if (serial === root.customPreviewFocusSerial && root.customPreviewLeaseValid
                    && root.customPreviewCandidate && root.customPreviewCandidate.owner === owner
                    && MInputMethodQuick.active && keyboard.layout === root)
                root.customPreviewFocusMatches = Number(pid) === owner
        }, function() { if (serial === root.customPreviewFocusSerial) root.customPreviewFocusMatches = false })
    }
    Timer { id: customPreviewExpiry; onTriggered: root.refreshCustomPreviewLease() }
    DBusInterface {
        id: customPreviewCompositor
        bus: DBus.SessionBus; service: "org.nemomobile.lipstick"; path: "/"; iface: "org.nemomobile.compositor"
    }
    DBusInterface {
        id: customLayoutHelper
        bus: DBus.SessionBus; service: "org.hb.FutoKeyboard1"; path: "/org/hb/FutoKeyboard1"; iface: "org.hb.FutoKeyboard1"
        watchServiceStatus: true; signalsEnabled: true
        function customLayoutsChanged(raw) { root.reloadCustomLayouts(raw) }
        onStatusChanged: if (status === DBusInterface.Available)
            typedCall("ListCustomLayouts", [], function(raw) { root.reloadCustomLayouts(raw) }, function() {})
    }
    readonly property string compositionHint: customLayoutActive
            ? LetterLayouts.customCompositionHint(selectedPredictionLanguage(layoutVariant)) : LetterLayouts.imeHint(layoutVariant)
    readonly property string compositionLanguage: compositionHint !== ""
            ? selectedPredictionLanguage(layoutVariant) : ""
    readonly property string compositionLanguageLabel: compositionLanguage !== ""
            ? LanguageData.name(compositionLanguage) : ""
    property bool compositionLatinMode: false
    readonly property string compositionModeHint: compositionHint === "12key" && compositionLatinMode
            ? "12key-latin" : compositionHint
    property bool layoutConfigurationReady: false
    readonly property int renderedLayoutVariant: !customLayoutActive && (compositionLatinMode
            && compositionLanguage === "JA" && compositionHint !== "12key" || (compositionHint === "12key"
                && handler && !handler.conversionEnabled)) ? 0 : layoutVariant
    readonly property bool japaneseFlickLayout: !customLayoutActive && LetterLayouts.imeHint(renderedLayoutVariant) === "12key"
    readonly property real thumbLetterKeyWidth: {
        if (!thumbMode || japaneseFlickLayout) return 0
        var columns = 1
        for (var row = 0; row < LetterLayouts.rowCount(renderedLayoutVariant); ++row)
            columns = Math.max(columns, Math.ceil(
                                   LetterLayouts.rowLength(renderedLayoutVariant, row) / 2))
        return Math.max(1, (keyboardContentWidth - avoidanceWidth) / (2 * columns))
    }
    // ABC changes the rendered grid without changing the saved Japanese
    // layout. Wait for the new cell models/loaders before measuring the rows.
    onRenderedLayoutVariantChanged: rowRelayoutTimer.restart()
    onCompositionLanguageChanged: { compositionLatinMode = false; applyConfiguredAutocaps() }
    onCompositionHintChanged: { compositionLatinMode = false; applyConfiguredAutocaps() }
    readonly property int symbolNumberLayout: Math.max(0, Math.min(2,
                                                                  layoutSettings.symbolNumberLayout))
    readonly property int emojiStyle: Math.max(0, Math.min(3, layoutSettings.emojiStyle))
    readonly property int emojiSkinTone: Math.max(0, Math.min(5,
                                                              layoutSettings.emojiSkinTone))
    readonly property real emojiSizeScale: clampedEmojiSizeScale(
                                               layoutSettings.emojiSizeScale)
    readonly property bool numberRowEnabled: layoutSettings.numberRowEnabled
	readonly property int letterRowCount: japaneseFlickLayout ? 3
            : LetterLayouts.rowCount(renderedLayoutVariant)
	readonly property bool effectiveNumberRowEnabled: !customLayoutActive && LetterLayouts.numberRowAllowed(renderedLayoutVariant)
            && (numberRowEnabled || LetterLayouts.numberRowRequired(renderedLayoutVariant))
	readonly property real numberRowHeightScale: Math.max(0.5, Math.min(1.0,
			isFinite(Number(layoutSettings.numberRowHeightScale))
			? Number(layoutSettings.numberRowHeightScale) : 1.0))
	readonly property real keyboardPanelHeight: customLayoutActive
            ? Math.max(3, Math.min(5, customDocument.pages[0].rows.length)) * keyHeight
            : (1 + letterRowCount
			+ (effectiveNumberRowEnabled
			? numberRowHeightScale : 0)) * keyHeight
    readonly property bool automaticPrivateInput: MInputMethodQuick.hiddenText
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
    readonly property bool separateLayoutLanguages: !languagesShareActiveLayout || layoutHasConversionLanguages(layoutVariant)
    readonly property int languageSwitchCount: languageSwitchEntries().length
    readonly property string currentLetterLayoutName: letterLayoutName(
            layoutVariant, selectedPredictionLanguage(layoutVariant))
    readonly property string currentLetterLayoutMenuName: {
        customLayoutRevision
        return LetterLayouts.menuNameForLanguage(layoutVariant, selectedPredictionLanguage(layoutVariant))
    }
    readonly property string currentLayoutLanguages: !separateLayoutLanguages
			? languageNamesForLayout(layoutVariant)
			: LanguageData.name(selectedPredictionLanguage(layoutVariant))
    readonly property string currentLayoutLanguageCodes: !separateLayoutLanguages
			? languagesForLayout(layoutVariant).join("+")
			: selectedPredictionLanguage(layoutVariant)
    // Raised by the Space key while its language chooser is open, so the
    // chooser paints over the rows above it instead of behind them.
    property bool languagePopupActive: false
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
        if (layoutScript === "tibetan")
            return fontLoaderName(notoTibetanFont, "Noto Serif Tibetan Light")
        if (LetterLayouts.name(index) === "AZERTY (Amazigh-Latin)")
            return "DejaVu Sans"
        return ""
    }
    readonly property string currentLayoutMenuLanguageLabel: {
        if (separateLayoutLanguages)
            return selectedPredictionLanguage(layoutVariant)
        var languages = languagesForLayout(layoutVariant)
        return languages.length > 2 ? qsTr("MULTI") : languages.join("+")
    }
    readonly property string activePredictionLanguages: predictionLanguagesForLayout(layoutVariant)
    // Both arrangements are the numpad; they differ only in the side the
    // digits sit on, so only the page condition belongs to numpadMode.
    readonly property bool numpadMode: symbolNumberLayout >= 1
                                         && attributes.inSymView
                                         && !emojiMode
                                         && !extendedSymbolMode
                                         && !extraKeysMode
    readonly property bool numpadLeftAligned: symbolNumberLayout === 2
    // Every layout draws the across-the-top 123 page from this shared symbol
    // arrangement rather than reusing its letter rows, which may have a
    // different shape and cannot supply the required symbol keys.
    // Tapping {&= opens this second symbol page; holding it still opens the
    // categorised picker, which is a different view entirely.
    readonly property bool topRowSecondSymbolPage: symbolNumberLayout === 0
                                         && attributes.inSymView
                                         && attributes.inSymView2
                                         && !emojiMode
                                         && !extendedSymbolMode
                                         && !extraKeysMode
                                         && !layoutEditorMode
                                         && !clipboardMode
                                         && !credentialMode
    readonly property bool topRowSymbolPage: symbolNumberLayout === 0
                                         && attributes.inSymView
                                         && !attributes.inSymView2
                                         && !emojiMode
                                         && !extendedSymbolMode
                                         && !extraKeysMode
                                         && !layoutEditorMode
                                         && !clipboardMode
                                         && !credentialMode
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

    function layoutIdentities() {
        try {
            var identities = JSON.parse(String(layoutSettings.layoutIds))
            return identities && typeof identities === "object" ? identities : {}
        } catch (error) {
            return {}
        }
    }

    function layoutForLanguage(languageCode) {
        return LetterLayouts.assignedIndex(languageCode, layoutAssignments(),
                                          layoutIdentities())
    }

    function assignLayoutToLanguage(languageCode, layoutValue) {
        var compatible = LetterLayouts.compatibleIndices(languageCode)
        layoutValue = LetterLayouts.clampedIndex(layoutValue)
        if (compatible.indexOf(layoutValue) < 0)
            return false
        if (handler && handler.finishConversion)
            return handler.finishConversion(function() {
                root.applyLayoutAssignment(languageCode, layoutValue)
            })
        return applyLayoutAssignment(languageCode, layoutValue)
    }

    function applyLayoutAssignment(languageCode, layoutValue) {
        var assignments = layoutAssignments()
        var manualAssignments = manualAssignmentFlags()
        var identities = layoutIdentities()
        assignments[String(languageCode)] = layoutValue
        identities[String(languageCode)] = LetterLayouts.idForIndex(layoutValue)
        manualAssignments[String(languageCode)] = true
        layoutSettings.manualLayoutAssignments = JSON.stringify(manualAssignments)
        layoutSettings.layoutIds = JSON.stringify(identities)
        layoutSettings.layoutAssignments = JSON.stringify(assignments)
        layoutSettings.layoutAssignmentVersion = 2
        layoutSettings.layoutVariant = layoutValue
        if (!languagesShareActiveLayout || layoutHasConversionLanguages(layoutValue))
            layoutSettings.manualPredictionLanguage = String(languageCode)
        synchronizeDetectedLanguage()
        return true
    }

    function ensureLayoutAssignments() {
        var assignments = layoutAssignments()
        var identities = layoutIdentities()
        var manualAssignments = manualAssignmentFlags()
        var languages = enabledPredictionLanguages()
        var legacyMigration = layoutSettings.layoutAssignmentVersion < 1
        var defaultsMigration = layoutSettings.layoutDefaultsVersion < 2
        var nationalMigration = layoutSettings.layoutDefaultsVersion < 3
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

        if (nationalMigration) {
            // Danish sat on the Norwegian "ø æ" home row and both Portuguese
            // locales on the Spanish "ñ" one.  Nobody chose a neighbouring
            // country's keyboard on purpose, so these two old default values
            // move even where the earlier migration marked them as manual.
            if (Number(assignments["DA"]) === 7) {
                assignments["DA"] = LetterLayouts.defaultForLanguage("DA")
                changed = true
            }
            var portuguese = ["PT_BR", "PT_PT"]
            for (var portugueseIndex = 0; portugueseIndex < portuguese.length;
                    ++portugueseIndex) {
                var portugueseCode = portuguese[portugueseIndex]
                if (Number(assignments[portugueseCode]) === 5) {
                    assignments[portugueseCode]
                            = LetterLayouts.defaultForLanguage(portugueseCode)
                    changed = true
                }
            }
        }

        // Generated assignments for disabled languages should not shadow a
        // newly improved national default.  Explicit editor choices remain.
        for (var storedCode in assignments) {
            if (languages.indexOf(storedCode) < 0 && !manualAssignments[storedCode]) {
                delete assignments[storedCode]
                delete identities[storedCode]
                changed = true
            }
        }

        // Store identities for disabled manual choices too. Generated catalogue
        // additions must not change them when the language is enabled later.
        for (var identityCode in assignments) {
            var resolved = LetterLayouts.assignedIndex(identityCode, assignments, identities)
            if (assignments[identityCode] !== resolved) {
                assignments[identityCode] = resolved
                changed = true
            }
            identities[identityCode] = LetterLayouts.idForIndex(resolved)
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
            identities[code] = LetterLayouts.idForIndex(assignments[code])
        }
        if (manualChanged)
            layoutSettings.manualLayoutAssignments = JSON.stringify(manualAssignments)
        var encodedIds = JSON.stringify(identities)
        if (layoutSettings.layoutIds !== encodedIds)
            layoutSettings.layoutIds = encodedIds
        if (changed) {
            layoutSettings.layoutAssignments = JSON.stringify(assignments)
        }
        layoutSettings.layoutAssignmentVersion = 2
        if (defaultsMigration || nationalMigration)
            layoutSettings.layoutDefaultsVersion = 3
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
        if (!languagesShareActiveLayout || layoutHasConversionLanguages(layoutValue)) {
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

    function layoutHasConversionLanguages(layoutValue) {
        var languages = languagesForLayout(layoutValue)
        for (var i = 0; i < languages.length; i++)
            if (LetterLayouts.imeHint(layoutValue, languages[i]) !== "") return true
        return false
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
        customLayoutRevision
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

    function letterLayoutName(value, languageCode) {
        customLayoutRevision
        return LetterLayouts.nameForLanguage(value, languageCode)
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
        if (!layoutSettings.autoCapitalizationEnabled
                || (compositionHint !== "" && !compositionLatinMode)) {
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
        if (!layoutConfigurationReady) return
        var enabled = configuredLayoutGroups()
        if (enabled.indexOf(layoutVariant) < 0)
            layoutSettings.layoutVariant = enabled[0]
        synchronizeDetectedLanguage()
    }

    function synchronizeDetectedLanguage() {
        if (!layoutConfigurationReady) return
        if (!handler || handler.detectedLanguage === undefined)
            return
        var languages = languagesForLayout(layoutVariant)
        if (languages.length < 1)
            return
        if (!languagesShareActiveLayout || layoutHasConversionLanguages(layoutVariant)) {
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

    // Holding Space offers the same choices, in the same order, that tapping
    // the language button cycles through. One list serves both so the two can
    // never disagree about what comes next.
    function languageSwitchEntries() {
        var result = []
        var i
        if (!languagesShareActiveLayout) {
            var languages = enabledPredictionLanguages()
            for (i = 0; i < languages.length; ++i) {
                result.push({ "code": languages[i],
                              "name": LanguageData.name(languages[i]),
                              "layout": layoutForLanguage(languages[i]) })
            }
            return result
        }
        var groups = configuredLayoutGroups()
        for (i = 0; i < groups.length; ++i) {
            var codes = languagesForLayout(groups[i])
            if (layoutHasConversionLanguages(groups[i])) {
                for (var j = 0; j < codes.length; ++j)
                    result.push({ "code": codes[j], "name": LanguageData.name(codes[j]),
                                  "layout": groups[i] })
                continue
            }
            result.push({ "code": codes.length > 0 ? codes[0] : "",
                          "name": languageNamesForLayout(groups[i]),
                          "layout": groups[i] })
        }
        return result
    }

    function currentLanguageSwitchIndex() {
        var entries = languageSwitchEntries()
        var i
        if (separateLayoutLanguages) {
            var selected = selectedPredictionLanguage(layoutVariant)
            for (i = 0; i < entries.length; ++i) {
                if (entries[i].code === selected)
                    return i
            }
            return 0
        }
        for (i = 0; i < entries.length; ++i) {
            if (entries[i].layout === layoutVariant)
                return i
        }
        return 0
    }

    function applyLanguageSwitchIndex(index) {
        var entries = languageSwitchEntries()
        if (index < 0 || index >= entries.length)
            return
        var entry = entries[index]
        if (handler && handler.finishConversion) {
            handler.finishConversion(function() { root.applyLanguageSwitchEntry(entry) })
            return
        }
        applyLanguageSwitchEntry(entry)
    }

    function applyLanguageSwitchEntry(entry) {
        if (handler && handler.cancelSwipeSession)
            handler.cancelSwipeSession()
        if (layoutVariant !== entry.layout) {
            suppressNextLayoutSwipeCancel = true
            layoutSettings.layoutVariant = entry.layout
        }
        if ((!languagesShareActiveLayout || layoutHasConversionLanguages(entry.layout))
                && entry.code !== "") {
            if (String(layoutSettings.manualPredictionLanguage) !== entry.code)
                suppressNextLanguageSwipeCancel = true
            layoutSettings.manualPredictionLanguage = entry.code
        }
        synchronizeDetectedLanguage()
    }

    function cycleLetterLayout() {
        var entries = languageSwitchEntries()
        if (entries.length < 2) return
        applyLanguageSwitchIndex((currentLanguageSwitchIndex() + 1) % entries.length)
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
        id: rowRelayoutTimer
        interval: 0
        repeat: false
        onTriggered: root.updateSizes()
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
            root.refreshCustomPreviewFocus()
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
            root.refreshCustomPreviewFocus()
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
        onEnabledLanguagesChanged: if (root.layoutConfigurationReady) root.ensureLayoutAssignments()
        onLayoutAssignmentsChanged: root.ensureActiveLetterLayout()
        onLayoutIdsChanged: root.ensureActiveLetterLayout()
        onCustomLayoutsJsonChanged: root.reloadCustomLayouts(layoutSettings.customLayoutsJson)
        onAutomaticLanguageDetectionChanged: root.synchronizeDetectedLanguage()
        onMergeSameLayoutLanguagesChanged: root.synchronizeDetectedLanguage()
        onManualPredictionLanguageChanged: {
            if (root.handler && root.handler.clearCustomDeadKey) root.handler.clearCustomDeadKey()
            if (root.suppressNextLanguageSwipeCancel) {
                root.suppressNextLanguageSwipeCancel = false
            } else if (root.handler && root.handler.cancelSwipeSession) {
                root.handler.cancelSwipeSession()
            }
            root.synchronizeDetectedLanguage()
        }
        onNumberRowEnabledChanged: root.updateSizes()
        onNumberRowHeightScaleChanged: rowRelayoutTimer.restart()
        onSymbolNumberLayoutChanged: root.updateSizes()
        onAutoCapitalizationEnabledChanged: root.applyConfiguredAutocaps()
        onExtendedSymbolFavoritesJsonChanged: root.loadExtendedSymbolFavorites()
        onDebugInputContextChanged: {
            if (layoutSettings.debugInputContext && MInputMethodQuick.active)
                contextDebugTimer.restart()
        }
    }

    Component.onCompleted: {
        reloadCustomLayouts(layoutSettings.customLayoutsJson)
        loadExtendedSymbolFavorites()
        initialLayoutConfiguration.start()
    }

    Timer {
        id: initialLayoutConfiguration
        interval: 0
        onTriggered: {
            root.layoutConfigurationReady = true
            root.ensureLayoutAssignments()
            root.synchronizeDetectedLanguage()
            root.applyConfiguredAutocaps()
        }
    }

    // At start-up the layout exists before its input handler does, so the
    // call above finds nothing to correct and Space kept showing English on
    // a German keyboard until the first word was typed.
    onHandlerChanged: synchronizeDetectedLanguage()
    onCompositionLatinModeChanged: applyConfiguredAutocaps()

    FutoDesktopToolbar {
        targetLayout: root
    }

    KeyboardRow {
		id: numberRow
		followRowHeight: false
		property bool fitKeysToRowHeight: true
		height: Math.round(root.keyHeight * (root.effectiveNumberRowEnabled
			? root.numberRowHeightScale : 1.0))
        opacity: root.cursorMoveMode ? 0 : 1
        visible: !root.customLayoutActive && !root.emojiMode && !root.extendedSymbolMode
                 && !root.extraKeysMode
                 && !root.layoutEditorMode && !root.clipboardMode
				 && !root.credentialMode
                 && !root.numpadMode && !root.topRowSecondSymbolPage
                 && (root.topRowSymbolPage
                     || (root.effectiveNumberRowEnabled
                         && LetterLayouts.numberRowLength(root.layoutVariant) === 0))
        FutoCharacterKey { secondaryHintEligible: false; caption: root.digitForLayout("1"); captionShifted: caption; symView: "1"; symView2: "¹" }
        FutoCharacterKey { secondaryHintEligible: false; caption: root.digitForLayout("2"); captionShifted: caption; symView: "2"; symView2: "²" }
        FutoCharacterKey { secondaryHintEligible: false; caption: root.digitForLayout("3"); captionShifted: caption; symView: "3"; symView2: "³" }
        FutoCharacterKey { secondaryHintEligible: false; caption: root.digitForLayout("4"); captionShifted: caption; symView: "4"; symView2: "€" }
        FutoCharacterKey { secondaryHintEligible: false; caption: root.digitForLayout("5"); captionShifted: caption; symView: "5"; symView2: "‰" }
        FutoCharacterKey { secondaryHintEligible: false; caption: root.digitForLayout("6"); captionShifted: caption; symView: "6"; symView2: "¼" }
        FutoCharacterKey { secondaryHintEligible: false; caption: root.digitForLayout("7"); captionShifted: caption; symView: "7"; symView2: "½" }
        FutoCharacterKey { secondaryHintEligible: false; caption: root.digitForLayout("8"); captionShifted: caption; symView: "8"; symView2: "¾" }
        FutoCharacterKey { secondaryHintEligible: false; caption: root.digitForLayout("9"); captionShifted: caption; symView: "9"; symView2: "[" }
        FutoCharacterKey { secondaryHintEligible: false; caption: root.digitForLayout("0"); captionShifted: caption; symView: "0"; symView2: "]" }
    }

    FutoGeneratedNumberRow {
        targetLayout: root
        layoutIndex: root.layoutVariant
        visible: !root.customLayoutActive && !root.emojiMode && !root.extendedSymbolMode
                 && !root.extraKeysMode && !root.layoutEditorMode
                 && !root.clipboardMode && !root.credentialMode
                 && !attributes.inSymView && !root.numpadMode
                 && root.effectiveNumberRowEnabled
                 && LetterLayouts.numberRowLength(root.layoutVariant) > 0
    }

    FutoSymbolLayout {
        width: parent.width
        targetLayout: root
        visible: root.topRowSymbolPage
    }

    FutoLetterRow { targetLayout: root; layoutIndex: root.renderedLayoutVariant; rowIndex: 0 }
    FutoLetterRow { targetLayout: root; layoutIndex: root.renderedLayoutVariant; rowIndex: 1 }
    FutoLetterRow { targetLayout: root; layoutIndex: root.renderedLayoutVariant; rowIndex: 2 }
    FutoLetterRow { targetLayout: root; layoutIndex: root.renderedLayoutVariant; rowIndex: 3 }
    FutoLetterRow { targetLayout: root; layoutIndex: root.renderedLayoutVariant; rowIndex: 4 }

    FutoCustomLayoutPanel {
        targetLayout: root
        visible: root.customSurfaceVisible
        height: root.keyboardPanelHeight
        opacity: root.cursorMoveMode ? 0 : 1
    }

    FutoJapaneseFlickPanel {
        targetLayout: root
        visible: root.japaneseFlickLayout && !attributes.inSymView
                 && !root.emojiMode && !root.extendedSymbolMode
                 && !root.extraKeysMode && !root.layoutEditorMode
                 && !root.clipboardMode && !root.credentialMode
    }

    FutoSpacebarRow {
        opacity: root.cursorMoveMode ? 0 : 1
        visible: !root.customLayoutActive && !root.emojiMode && !root.extendedSymbolMode
                 && !root.extraKeysMode
                 && !root.layoutEditorMode && !root.clipboardMode
				 && !root.credentialMode
                 && !root.numpadMode && !root.topRowSecondSymbolPage
                 && !(root.japaneseFlickLayout && !attributes.inSymView)
        targetLayout: root
        symbolNumberLayout: root.symbolNumberLayout
    }

    FutoNumpadLayout {
        // Also serves the {&= page, which holds the same symbols; sharing one
        // component keeps the two from drifting apart.
        visible: (root.numpadMode || root.topRowSecondSymbolPage)
                 && !root.extraKeysMode
                 && !root.layoutEditorMode && !root.clipboardMode
				 && !root.credentialMode
        targetLayout: root
        leftAligned: root.numpadLeftAligned
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

    // Keep the overall input-method height unchanged while the selector uses
    // the otherwise empty prediction-strip area.  Growing this direct child
    // changes only its painted size after Maliit has measured the layout and
    // makes it overflow into the application above the keyboard.
    Item {
        id: layoutEditorContainer
        visible: root.layoutEditorMode
        height: root.keyboardPanelHeight
        z: 100

        readonly property real reclaimedTopHeight:
                root.useTopItem ? Silica.Theme.itemSizeSmall : 0

        FutoLayoutEditor {
            x: 0
            y: -layoutEditorContainer.reclaimedTopHeight
            width: layoutEditorContainer.width
            height: layoutEditorContainer.height
                    + layoutEditorContainer.reclaimedTopHeight
            targetLayout: root
        }
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
        id: pickerSpacebarRow
        visible: root.emojiMode || root.extendedSymbolMode
        // Match the ordinary bottom row: continuous in portrait, with one
        // expanding Space on each side of the landscape thumb-mode gap.
        property int avoidanceWidth: root.thumbLandscapeMode ? root.avoidanceWidth : 0
        splitIndex: 2
        FutoEmojiBackKey { targetLayout: root }
        FutoSpacebarKey { languageLabel: "" }
        FutoSpacebarKey {
            active: root.thumbLandscapeMode
            languageLabel: ""
            hintEligible: false
        }
        FutoEnterKey { targetLayout: root }
        FutoBackspaceKey {}
    }
}
