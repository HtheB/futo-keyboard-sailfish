.pragma library
.import "FutoGeneratedLayouts.js" as Generated
.import "FutoLanguageCatalogue.js" as Catalogue

// Layout rows and language-specific long-press choices are adapted from the
// pinned Apache-2.0 futo-org/futo-keyboard-layouts catalogue and the locale
// data shipped by the pinned FUTO Android Keyboard revision. QWERTY keeps this
// port's established SwiftKey-like arrangement. Keep these indices stable
// because users persist layout indices in their per-language assignments.
var legacyLayouts = [
    { name: "QWERTY", script: "latin", rows: [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"]
    ] },
    { name: "QWERTZ", script: "latin", rows: [
        ["q", "w", "e", "r", "t", "z", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["y", "x", "c", "v", "b", "n", "m"]
    ] },
    { name: "AZERTY", script: "latin", rows: [
        ["a", "z", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["q", "s", "d", "f", "g", "h", "j", "k", "l", "m"],
        ["w", "x", "c", "v", "b", "n", "'"]
    ] },
    { name: "Turkish Q", script: "latin", rows: [
        ["q", "w", "e", "r", "t", "y", "u", "ı", "o", "p", "ğ", "ü"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ş", "i"],
        ["z", "x", "c", "v", "b", "n", "m", "ö", "ç"]
    ] },
    { name: "German QWERTZ", script: "latin", rows: [
        ["q", "w", "e", "r", "t", "z", "u", "i", "o", "p", "ü"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ö", "ä"],
        ["y", "x", "c", "v", "b", "n", "m"]
    ] },
    { name: "Spanish QWERTY", script: "latin", rows: [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ñ"],
        ["z", "x", "c", "v", "b", "n", "m"]
    ] },
    { name: "Nordic (Swedish/Finnish)", script: "latin", rows: [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "å"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ö", "ä"],
        ["z", "x", "c", "v", "b", "n", "m"]
    ] },
    // Danish and Norwegian are not the same arrangement: Danish ends the home
    // row with "æ ø" and Norwegian with "ø æ".  This entry is the Norwegian
    // one; Danish uses the upstream "nordic" layout below.
    { name: "Nordic (Norwegian)", script: "latin", rows: [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "å"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ø", "æ"],
        ["z", "x", "c", "v", "b", "n", "m"]
    ] },
    { name: "Romanian QWERTY", script: "latin", rows: [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "ă"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ș", "ț"],
        ["z", "x", "c", "v", "b", "n", "m", "î", "â"]
    ] },
    { name: "Colemak", script: "latin", rows: [
        ["q", "w", "f", "p", "g", "j", "l", "u", "y", ";"],
        ["a", "r", "s", "t", "d", "h", "n", "e", "i", "o"],
        ["z", "x", "c", "v", "b", "k", "m"]
    ] },
    { name: "Colemak DH", script: "latin", rows: [
        ["q", "w", "f", "p", "b", "j", "l", "u", "y", ";"],
        ["a", "r", "s", "t", "g", "m", "n", "e", "i", "o"],
        ["z", "x", "c", "d", "v", "k", "h"]
    ] },
    { name: "Dvorak", script: "latin", rows: [
        ["'", ",", ".", "p", "y", "f", "g", "c", "r", "l"],
        ["a", "o", "e", "u", "i", "d", "h", "t", "n", "s"],
        [";", "q", "j", "k", "x", "b", "m", "w", "v", "z"]
    ] },
    { name: "Workman", script: "latin", rows: [
        ["q", "d", "r", "w", "b", "j", "f", "u", "p", ";"],
        ["a", "s", "h", "t", "g", "y", "n", "e", "o", "i"],
        ["z", "x", "m", "c", "v", "k", "l"]
    ] },
    { name: "Arabic", script: "arabic", rows: [
        ["ض", "ص", "ث", "ق", "ف", "غ", "ع", "ه", "خ", "ح", "ج"],
        ["ش", "س", "ي", "ب", "ل", "ا", "ت", "ن", "م", "ك", "ط"],
        ["ذ", "ء", "ؤ", "ر", "ى", "ة", "و", "ز", "ظ", "د"]
    ] },
    { name: "Greek", script: "greek", rows: [
        [";", "ς", "ε", "ρ", "τ", "υ", "θ", "ι", "ο", "π"],
        ["α", "σ", "δ", "φ", "γ", "η", "ξ", "κ", "λ"],
        ["ζ", "χ", "ψ", "ω", "β", "ν", "μ"]
    ] },
    { name: "East Slavic", script: "cyrillic", languages: ["RU"], rows: [
        ["й", "ц", "у", "к", "е", "н", "г", "ш", "щ", "з", "х"],
        ["ф", "ы", "в", "а", "п", "р", "о", "л", "д", "ж", "э"],
        ["я", "ч", "с", "м", "и", "т", "ь", "б", "ю"]
    ] },
    { name: "Turkish F", script: "latin", rows: [
        ["f", "g", "ğ", "ı", "o", "d", "r", "n", "h", "p", "q", "w"],
        ["u", "i", "e", "a", "ü", "t", "k", "m", "l", "y", "ş", "x"],
        ["j", "ö", "v", "c", "ç", "z", "s", "b", ".", ","]
    ] },
    { name: "Slovenian QWERTZ", script: "latin", rows: [
        ["q", "w", "e", "r", "t", "z", "u", "i", "o", "p", "š"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", "č", "ž"],
        ["y", "x", "c", "v", "b", "n", "m"]
    ] },
    { name: "Croatian / Serbian Latin QWERTZ", script: "latin", rows: [
        ["q", "w", "e", "r", "t", "z", "u", "i", "o", "p", "š"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", "č", "ć"],
        ["y", "x", "c", "v", "b", "n", "m", "đ", "ž"]
    ] },
    { name: "Serbian Cyrillic", script: "cyrillic", languages: ["SR"], rows: [
        ["љ", "њ", "е", "р", "т", "з", "у", "и", "о", "п", "ш"],
        ["а", "с", "д", "ф", "г", "х", "ј", "к", "л", "ч", "ћ"],
        ["ѕ", "џ", "ц", "в", "б", "н", "м", "ђ", "ж"]
    ] },
    { name: "Persian", script: "persian", languages: ["FA"], rows: [
        ["ض", "ص", "ث", "ق", "ف", "غ", "ع", "ه", "خ", "ح", "ج"],
        ["ش", "س", "ی", "ب", "ل", "ا", "ت", "ن", "م", "ک", "گ"],
        ["ظ", "ط", "ژ", "ز", "ر", "ذ", "د", "پ", "و", "چ"]
    ] }
]

// Explicit single-character more-keys from the corresponding upstream FUTO
// layout YAML. FUTO entries whose visible label maps to a multi-codepoint
// output use the closest single-codepoint Unicode form supported by Sailfish's
// character popper.
var letterAlternatives = {
    13: {
        "ق": "ڨ", "ف": "ڤڢڥ", "ه": "ﻫ", "ج": "چ",
        "ش": "ڜ", "ي": "ئى", "ب": "پ", "ل": "ﻻﻷﻹﻵ",
        "ا": "آءأإٱ", "ك": "گک", "ى": "ئ", "ز": "ژ"
    },
    14: {
        ";": "%:·",
        "ε": "έὲἐἑἔἕἒἓ",
        "ρ": "ῥ",
        "υ": "ύϋΰὺῦὐὑὔὕὒὓὖὗῢῧ",
        "ι": "ίϊΐὶῖἰἱἴἵἲἳἶἷῒῗ",
        "ο": "όὸὀὁὄὅὂὃ",
        "α": "άὰᾶἀἁἄἅἂἃἆἇᾳᾴᾲᾷᾀᾁᾄᾅᾂᾃᾆᾇ",
        "η": "ήὴῆἠἡἤἥἢἣἦἧῃῄῂῇᾐᾑᾔᾕᾒᾓᾖᾗ",
        "ω": "ώὼῶὠὡὤὥὢὣὦὧῳῴῲῷᾠᾡᾤᾥᾢᾣᾦᾧ"
    },
    15: {
        "е": "ё", "ь": "ъ"
    },
    17: {
        "d": "đ"
    },
    19: {
        "е": "ѐ", "и": "ѝ"
    },
    20: {
        "ه": "ﻫۀة", "ی": "ئيى", "ا": "ٱءآأإ", "ت": "ة",
        "ک": "ك", "و": "ؤ"
    }
}

// Locale more-keys from FUTO Android Keyboard. When several languages share
// one physical layout, their alternatives are merged in the same order as the
// active languages, so a single QWERTY remains genuinely multilingual.
var languageAlternatives = {
    "CS": { "a": "á", "c": "č", "d": "ď", "e": "éě", "i": "í", "n": "ň", "o": "ó", "r": "ř", "s": "š", "t": "ť", "u": "úů", "y": "ý", "z": "ž" },
    "DA": { "a": "åæ", "o": "ø" },
    "DE": { "a": "ä", "o": "ö", "s": "ß", "u": "ü" },
    "ES": { "a": "á", "e": "é", "i": "í", "n": "ñ", "o": "ó", "u": "úü" },
    "FI": { "a": "äå", "o": "ö", "s": "š", "z": "ž" },
    "FR": { "a": "àâæ", "c": "ç", "e": "éèêë", "i": "îï", "o": "ôœ", "u": "ùûü", "y": "ÿ" },
    "HR": { "c": "čć", "d": "đ", "s": "š", "z": "ž" },
    "HU": { "a": "á", "e": "é", "i": "í", "o": "óöő", "u": "úüű" },
    "IT": { "a": "à", "e": "èé", "i": "ì", "o": "ò", "u": "ù" },
    "LT": { "a": "ą", "c": "č", "e": "ėę", "i": "į", "s": "š", "u": "ūų", "z": "ž" },
    "LV": { "a": "ā", "c": "č", "e": "ē", "g": "ģ", "i": "ī", "k": "ķ", "l": "ļ", "n": "ņ", "s": "š", "u": "ū", "z": "ž" },
    "NB": { "a": "åæäàáâãā", "e": "éèêëęėē", "o": "øöôòóõœō", "u": "üûùúū" },
    "NL": { "a": "áäâà", "e": "éëêè", "i": "íïìîįīĳ", "o": "óö", "u": "úü" },
    "PL": { "a": "ą", "c": "ć", "e": "ę", "l": "ł", "n": "ń", "o": "ó", "s": "ś", "z": "żź" },
    "PT_BR": { "a": "áãàâ", "c": "ç", "e": "éê", "i": "í", "o": "óõô", "u": "úü" },
    "PT_PT": { "a": "áãàâ", "c": "ç", "e": "éê", "i": "í", "o": "óõô", "u": "úü" },
    "RO": { "a": "ăâ", "i": "î", "s": "ș", "t": "ț" },
    "SL": { "c": "č", "s": "š", "z": "ž" },
    "SR_LATN": { "c": "čć", "d": "đ", "e": "è", "i": "ì", "s": "š", "z": "ž" },
    "SV": { "a": "äå", "e": "é", "o": "ö" },
    "TR": { "c": "ç", "g": "ğ", "i": "ı", "o": "ö", "s": "ş", "u": "ü" }
}

// Greek contains a few explicit shifted lists which cannot be derived by
// uppercasing the normal list without changing their polytonic forms.
var shiftedLetterAlternatives = {
    14: {
        ";": "%;·",
        "α": "ΆᾺἈἉἌἍἊἋἎἏ",
        "η": "ΉῊἨἩἬἭἪἫἮἯ",
        "ω": "ΏῺὨὩὬὭὪὫὮὯ"
    }
}

// Visible letter-page hints follow the SwiftKey arrangement used as the
// reference for this port. The trailing cells cover wider language layouts.
// Every position is unique so layouts such as Russian never show the same
// shortcut twice.
var secondarySymbols = [
    ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "[", "]"],
    ["@", "#", "&", "*", "-", "+", "=", "(", ")", "{", "}", "?"],
    ["_", "€", "\"", "'", ":", ";", "/", "\\", "|", "<", ">", "~"]
]

// QWERTY carries one fixed set of alternates per key rather than a collection
// merged from whichever languages are enabled, and the secondary symbol the key
// prints sits at a set place inside that set, which is where it is highlighted.
var qwertyAlternateSets = {
    "q": "1", "w": "2", "e": "èê3ěęėëé", "r": "ř4", "t": "þț5ť",
    "y": "ý6", "u": "ùûů7űüú", "i": "ìîı8ïí", "o": "òôõöøō9ó", "p": "0",
    "a": "@ąăåäãâáà", "s": "ß#șšşś", "d": "ð&ď", "f": "*", "g": "ğ-",
    "h": "+", "j": "=", "k": "(", "l": "ĺľł)",
    "z": "ź_žż", "x": "$¢€\u20C1₺¥£", "c": "çč\"ć",
    "v": "'", "b": ":", "n": "ñň;ń", "m": "\\/%"
}

// With the number row on screen the digits are already reachable, so the top
// letter row carries these instead, on the key and inside the popup alike.
// Each entry is [the digit it replaces, the symbol replacing it].
var qwertyNumberRowSwap = {
    "q": ["1", "%"], "w": ["2", "^"], "e": ["3", "~"], "r": ["4", "|"],
    "t": ["5", "["], "y": ["6", "]"], "u": ["7", "<"], "i": ["8", ">"],
    "o": ["9", "{"], "p": ["0", "}"]
}

function qwertySwapFor(letterValue) {
    return qwertyNumberRowSwap[String(letterValue).toLowerCase()]
}

// "ß" uppercases to two characters; the popup gives one cell per entry, so a
// letter without a single-character capital stays as it is.
function shiftedAlternateSet(value) {
    var result = ""
    for (var i = 0; i < value.length; ++i) {
        var character = value.charAt(i)
        var upper = character.toUpperCase()
        result += upper.length === 1 ? upper : character
    }
    return result
}

function qwertyAlternateSet(letterValue, numberRowVisible, shiftedValue) {
    var set = qwertyAlternateSets[String(letterValue).toLowerCase()]
    if (set === undefined)
        return ""
    var swap = numberRowVisible ? qwertySwapFor(letterValue) : undefined
    if (swap !== undefined)
        set = set.replace(swap[0], swap[1])
    return shiftedValue ? shiftedAlternateSet(set) : set
}

var legacyLayoutCount = legacyLayouts.length
var layouts = legacyLayouts.concat(Generated.layouts)
var count = layouts.length

// Compact names are used only in the narrow held-123 action strip.  The
// layout editor and Settings continue to show the full descriptive names.
var menuNames = [
    "QWERTY", "QWERTZ", "AZERTY", "TR-Q", "DE-QWERTZ", "ES-QWERTY",
    "SE/FI", "NO", "RO-QWERTY", "COLEMAK", "COLEMAK-DH", "DVORAK",
    "WORKMAN", "ARABIC", "GREEK", "CYRILLIC", "TR-F", "SL-QWERTZ",
    "HR/SR-QW", "SR-CYRL", "PERSIAN"
]

// Upstream titles its layouts by shape, which reads oddly once one of them is
// a country's own default.  These few are the ones this port hands to a
// language directly, so name them the way the person picking them thinks of
// them.  Every other generated layout keeps its upstream title.
var generatedDisplayNames = {
    "nordic": "Nordic (Danish)",
    "nordic__nb": "Nordic (Norwegian)",
    "spanish": "Portuguese QWERTY"
}

var generatedMenuNames = {
    "nordic": "DA",
    "nordic__nb": "NO",
    "spanish": "PT-QWERTY"
}

for (var generatedMenuIndex = 0;
        generatedMenuIndex < Generated.layouts.length; ++generatedMenuIndex) {
    var generatedMenuLayout = Generated.layouts[generatedMenuIndex]
    menuNames.push(generatedMenuNames[generatedMenuLayout.id]
                   || String(generatedMenuLayout.name).toUpperCase())
}

var generatedIndexById = {}
for (var generatedLayoutIndex = 0;
        generatedLayoutIndex < Generated.layouts.length; ++generatedLayoutIndex) {
    generatedIndexById[Generated.layouts[generatedLayoutIndex].id]
            = legacyLayoutCount + generatedLayoutIndex
}

// Match the first/best conventional layout offered for each language by the
// upstream FUTO layout catalogue, using the closest dedicated layout that this
// Sailfish port currently ships.  Keep these values as stable persisted layout
// indices.
var languageDefaults = {
    "AR": 13,
    "CS": 1,
    // "DA" is deliberately absent: Danish takes the upstream "nordic" layout
    // from the loop below, which ends the home row "æ ø" as a Danish keyboard
    // does.  Index 7 is the Norwegian "ø æ" order and stays with Norwegian.
    "DE": 4,
    "EL": 14,
    "EN": 0,
    "EN_GB": 0,
    "ES": 5,
    "FA": 20,
    "FI": 6,
    "FR": 2,
    "HR": 18,
    "HU": 1,
    "IT": 0,
    "LT": 0,
    "LV": 0,
    "NB": 7,
    "NL": 0,
    "PL": 0,
    // Both Portuguese entries are likewise absent: index 5 is Spanish, whose
    // extra home-row key is "ñ".  Upstream gives Portuguese the same shape
    // with "ç", which is the key a Portuguese keyboard actually carries.
    "RO": 8,
    "RU": 15,
    "SL": 17,
    "SR": 19,
    "SR_LATN": 18,
    "SV": 6,
    "TR": 3
}

// Keep the first 21 persisted choices stable for existing users. Languages
// newly exposed by the complete FUTO catalogue start on their canonical
// upstream layout; the established languages above retain this port's current
// defaults and can select the FUTO variant in the visual editor.
for (var catalogueIndex = 0; catalogueIndex < Catalogue.languages.length;
        ++catalogueIndex) {
    var catalogueLanguage = Catalogue.languages[catalogueIndex]
    if (languageDefaults[catalogueLanguage.code] === undefined
            && generatedIndexById[catalogueLanguage.layoutId] !== undefined) {
        languageDefaults[catalogueLanguage.code]
                = generatedIndexById[catalogueLanguage.layoutId]
    }
}

function clampedIndex(value) {
    var parsed = Number(value)
    if (!isFinite(parsed))
        return 0
    return Math.max(0, Math.min(count - 1, Math.round(parsed)))
}

function name(value) {
    var layout = layouts[clampedIndex(value)]
    return generatedDisplayNames[layout.id] || layout.name
}

function menuName(value) {
    return menuNames[clampedIndex(value)]
}

function script(value) {
    return layouts[clampedIndex(value)].script
}

function catalogueEntry(languageCode) {
    languageCode = String(languageCode).toUpperCase()
    for (var i = 0; i < Catalogue.languages.length; ++i) {
        if (Catalogue.languages[i].code === languageCode)
            return Catalogue.languages[i]
    }
    return null
}

function languageScript(languageCode) {
    languageCode = String(languageCode).toUpperCase()
    var generatedEntry = catalogueEntry(languageCode)
    if (generatedEntry)
        return generatedEntry.script
    if (languageCode === "AR")
        return "arabic"
    if (languageCode === "EL")
        return "greek"
    if (languageCode === "FA")
        return "persian"
    if (languageCode === "RU" || languageCode === "SR")
        return "cyrillic"
    return "latin"
}

function defaultForLanguage(languageCode) {
    languageCode = String(languageCode).toUpperCase()
    if (languageDefaults[languageCode] !== undefined)
        return languageDefaults[languageCode]
    var generatedEntry = catalogueEntry(languageCode)
    if (generatedEntry && generatedIndexById[generatedEntry.layoutId] !== undefined)
        return generatedIndexById[generatedEntry.layoutId]
    return 0
}

// Before national defaults were introduced, every Latin language inherited
// QWERTY while the three non-Latin scripts had fixed layouts.  This lets the
// one-time migration distinguish generated legacy assignments from most
// deliberate layout choices.
function legacyDefaultForLanguage(languageCode) {
    var languageScriptValue = languageScript(languageCode)
    if (languageScriptValue === "arabic")
        return 13
    if (languageScriptValue === "greek")
        return 14
    if (languageScriptValue === "persian")
        return 20
    if (languageScriptValue === "cyrillic")
        return 15
    return 0
}

function compatibleIndices(languageCode) {
    languageCode = String(languageCode).toUpperCase()
    var wantedScript = languageScript(languageCode)
    var result = []
    if (wantedScript === "latin") {
        // As agreed for the visual layout editor, direct Latin layouts are
        // interchangeable (for example English can use Turkish F).
        for (var i = 0; i < layouts.length; ++i) {
            if (layouts[i].script === "latin")
                result.push(i)
        }
        return result
    }

    // Do not fall back from one non-Latin script layout to another. Offer the
    // exact upstream layout, plus the stable legacy layout where this port had
    // already exposed that same language before the complete catalogue.
    var legacy = languageDefaults[languageCode]
    if (legacy !== undefined && legacy < legacyLayoutCount)
        result.push(legacy)
    var entry = catalogueEntry(languageCode)
    if (entry && generatedIndexById[entry.layoutId] !== undefined
            && result.indexOf(generatedIndexById[entry.layoutId]) < 0)
        result.push(generatedIndexById[entry.layoutId])
    return result
}

function rawKey(value, row, column) {
    var rows = layouts[clampedIndex(value)].rows
    if (row < 0 || row >= rows.length || column < 0 || column >= rows[row].length)
        return null
    var source = rows[row][column]
    if (typeof source === "string")
        return { kind: "character", caption: source, output: source, more: [] }
    return source
}

function letter(value, row, column) {
    var item = rawKey(value, row, column)
    return item && item.kind === "character" ? String(item.caption || "") : ""
}

function rowCount(value) {
    return layouts[clampedIndex(value)].rows.length
}

function rowLength(value, row) {
    var layoutIndex = clampedIndex(value)
    var rows = layouts[layoutIndex].rows
    if (row < 0 || row >= rows.length)
        return 0
    return layoutIndex < legacyLayoutCount && row === rows.length - 1
            ? rows[row].length + 2 : rows[row].length
}

function key(value, row, column) {
    var layoutIndex = clampedIndex(value)
    var rows = layouts[layoutIndex].rows
    if (layoutIndex < legacyLayoutCount && row === rows.length - 1) {
        if (column === 0)
            return { kind: "shift" }
        if (column === rows[row].length + 1)
            return { kind: "delete" }
        column--
    }
    var item = rawKey(layoutIndex, row, column)
    return item || { kind: "gap" }
}

function keyKind(value, row, column) {
    return String(key(value, row, column).kind || "gap")
}

function caption(value, row, column, shiftedValue) {
    var item = key(value, row, column)
    if (item.kind !== "character")
        return ""
    if (shiftedValue && item.shiftedCaption !== undefined)
        return String(item.shiftedCaption)
    if (shiftedValue && layouts[clampedIndex(value)].shiftable !== false)
        return shifted(String(item.caption || ""), value)
    return String(item.caption || "")
}

function output(value, row, column, shiftedValue) {
    var item = key(value, row, column)
    if (item.kind !== "character")
        return ""
    if (shiftedValue && item.shiftedOutput !== undefined)
        return String(item.shiftedOutput)
    if (shiftedValue && layouts[clampedIndex(value)].shiftable !== false)
        return shifted(String(item.output || item.caption || ""), value)
    return String(item.output || item.caption || "")
}

function numberRow(value) {
    return layouts[clampedIndex(value)].numberRow || []
}

function numberRowLength(value) {
    return numberRow(value).length
}

function numberKey(value, column) {
    var row = numberRow(value)
    return column >= 0 && column < row.length ? row[column] : { kind: "gap" }
}

function numberRowRequired(value) {
    var mode = String(layouts[clampedIndex(value)].numberRowMode || "Default")
    return numberRow(value).length > 0 && mode === "AlwaysEnabled"
}

function usesIndependentSizing(value) {
    var layoutIndex = clampedIndex(value)
    if (layoutIndex < legacyLayoutCount) {
        var activeScript = layouts[layoutIndex].script
        return activeScript === "arabic" || activeScript === "persian"
                || activeScript === "cyrillic"
                || layoutIndex === 17 || layoutIndex === 18
    }
    return !!layouts[layoutIndex].independentSizing
}

function secondarySymbol(row, column) {
    if (row < 0 || row >= secondarySymbols.length
            || column < 0 || column >= secondarySymbols[row].length)
        return ""
    return secondarySymbols[row][column]
}

function shifted(letterValue, layoutValue) {
    if (clampedIndex(layoutValue) === 14 && letterValue === "ς")
        return "ς"
    if (letterValue === "ı")
        return "I"
    if (letterValue === "i" && (clampedIndex(layoutValue) === 3
                                || clampedIndex(layoutValue) === 16))
        return "İ"
    if (letterValue === ";")
        return ":"
    if (letterValue === "'")
        return "\""
    if (letterValue === ",")
        return "<"
    if (letterValue === ".")
        return ">"
    return String(letterValue).toUpperCase()
}

function appendUniqueCharacters(result, value, excluded) {
    value = String(value || "")
    for (var i = 0; i < value.length; ++i) {
        var character = value.charAt(i)
        if (character !== "%" && character !== " "
                && excluded.indexOf(character) < 0
                && result.indexOf(character) < 0)
            result += character
    }
    return result
}

function alternatives(layoutValue, letterValue, languageCodes, shiftedValue) {
    var layoutIndex = clampedIndex(layoutValue)
    var base = String(letterValue || "")
    if (base === "")
        return ""

    var excluded = shiftedValue ? shifted(base, layoutIndex) : base
    var result = ""
    var layoutValues = letterAlternatives[layoutIndex]
    var explicitShiftedValues = shiftedLetterAlternatives[layoutIndex]
    var layoutResult = layoutValues && layoutValues[base] !== undefined
            ? String(layoutValues[base]) : ""
    if (shiftedValue) {
        if (explicitShiftedValues && explicitShiftedValues[base] !== undefined)
            layoutResult = String(explicitShiftedValues[base])
        else
            layoutResult = layoutResult.toUpperCase()
    }
    result = appendUniqueCharacters(result, layoutResult, excluded)

    var languages = String(languageCodes || "").toUpperCase().split("+")
    for (var i = 0; i < languages.length; ++i) {
        var values = languageAlternatives[languages[i]]
        if (!values || values[base] === undefined)
            continue
        var languageResult = String(values[base])
        if (shiftedValue)
            languageResult = languageResult.toUpperCase()
        result = appendUniqueCharacters(result, languageResult, excluded)
    }
    return result
}

function appendChoice(result, choice, excludedOutput) {
    if (!choice || choice.kind !== undefined && choice.kind !== "character")
        return
    var captionValue = String(choice.caption !== undefined
                              ? choice.caption : choice.output || "")
    var outputValue = String(choice.output !== undefined
                             ? choice.output : captionValue)
    if (outputValue === "" || outputValue === excludedOutput)
        return
    for (var i = 0; i < result.length; ++i) {
        if (result[i].output === outputValue)
            return
    }
    result.push({ caption: captionValue, output: outputValue })
}

function upperChoice(choice, languageCode) {
    var code = String(languageCode || "").toUpperCase()
    var captionValue = String(choice.caption !== undefined
                              ? choice.caption : choice.output || "")
    var outputValue = String(choice.output !== undefined
                             ? choice.output : captionValue)
    if (code === "TR" || code.indexOf("AZ") === 0) {
        captionValue = captionValue.replace(/i/g, "İ").replace(/ı/g, "I")
        outputValue = outputValue.replace(/i/g, "İ").replace(/ı/g, "I")
    }
    return { caption: captionValue.toUpperCase(), output: outputValue.toUpperCase() }
}

function stringChoices(value) {
    var result = []
    value = String(value || "")
    for (var i = 0; i < value.length; ++i)
        appendChoice(result, { caption: value.charAt(i), output: value.charAt(i) }, "")
    return result
}

function alternativeChoices(layoutValue, row, column, languageCodes, shiftedValue,
                            numberRowVisible) {
    var layoutIndex = clampedIndex(layoutValue)
    var item = key(layoutIndex, row, column)
    if (item.kind !== "character")
        return []

    if (layoutIndex === 0) {
        var fixed = qwertyAlternateSet(item.caption, numberRowVisible, shiftedValue)
        if (fixed !== "")
            return stringChoices(fixed)
    }

    // The stable pre-catalogue layouts keep their established broad accent
    // collection. Generated layouts use FUTO's exact structured choices,
    // including distinct labels/outputs and multi-codepoint results.
    if (layoutIndex < legacyLayoutCount) {
        return stringChoices(alternatives(layoutIndex, item.caption,
                                          languageCodes, shiftedValue))
    }

    var result = []
    var excluded = output(layoutIndex, row, column, shiftedValue)
    var direct = shiftedValue && item.shiftedMore !== undefined
            ? item.shiftedMore : (item.more || [])
    for (var directIndex = 0; directIndex < direct.length; ++directIndex)
        appendChoice(result, direct[directIndex], excluded)

    var languages = String(languageCodes || "").toUpperCase().split("+")
    var base = String(item.caption || "")
    for (var languageIndex = 0; languageIndex < languages.length; ++languageIndex) {
        var languageCode = languages[languageIndex]
        var languageMap = Generated.languageAlternatives[languageCode]
        var choices = languageMap && languageMap[base] ? languageMap[base] : []
        for (var choiceIndex = 0; choiceIndex < choices.length; ++choiceIndex) {
            appendChoice(result, shiftedValue
                         ? upperChoice(choices[choiceIndex], languageCode)
                         : choices[choiceIndex], excluded)
        }
    }
    return result
}

function hasExactAlternatives(layoutValue) {
    return clampedIndex(layoutValue) >= legacyLayoutCount
}

// A row can open with a shift key and close with a backspace, while the hint
// table is laid out by letter position. Counting the letters keeps the bottom
// row from taking every hint from its neighbour.
function letterIndexAt(layoutIndex, row, column) {
    var index = 0
    for (var i = 0; i < column; ++i) {
        if (key(layoutIndex, row, i).kind === "character")
            index++
    }
    return index
}

function secondarySymbolForLayout(layoutValue, row, column, numberRowVisible) {
    var layoutIndex = clampedIndex(layoutValue)
    if (layoutIndex >= legacyLayoutCount)
        return ""
    if (layoutIndex === 0 && numberRowVisible) {
        var swap = qwertySwapFor(caption(layoutIndex, row, column, false))
        if (swap !== undefined)
            return swap[1]
    }
    return secondarySymbol(row, letterIndexAt(layoutIndex, row, column))
}
