.pragma library

// Layout rows are adapted from the Apache-2.0 licensed
// futo-org/futo-keyboard-layouts project.  Keep these indices stable because
// users persist layout indices in their per-language assignments.
var layouts = [
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
        ["w", "x", "c", "v", "b", "n", ","]
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
    { name: "Nordic (Danish/Norwegian)", script: "latin", rows: [
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
        ["џ", "ђ", "ц", "в", "б", "н", "м", "ж"]
    ] },
    { name: "Persian", script: "persian", languages: ["FA"], rows: [
        ["ض", "ص", "ث", "ق", "ف", "غ", "ع", "ه", "خ", "ح", "ج"],
        ["ش", "س", "ی", "ب", "ل", "ا", "ت", "ن", "م", "ک", "گ"],
        ["ظ", "ط", "ژ", "ز", "ر", "ذ", "د", "پ", "و", "چ"]
    ] }
]

var count = layouts.length

// Compact names are used only in the narrow held-123 action strip.  The
// layout editor and Settings continue to show the full descriptive names.
var menuNames = [
    "QWERTY", "QWERTZ", "AZERTY", "TR-Q", "DE-QWERTZ", "ES-QWERTY",
    "SE/FI", "DA/NO", "RO-QWERTY", "COLEMAK", "COLEMAK-DH", "DVORAK",
    "WORKMAN", "ARABIC", "GREEK", "CYRILLIC", "TR-F", "SL-QWERTZ",
    "HR/SR-QW", "SR-CYRL", "PERSIAN"
]

// Match the first/best conventional layout offered for each language by the
// upstream FUTO layout catalogue, using the closest dedicated layout that this
// Sailfish port currently ships.  Keep these values as stable persisted layout
// indices.
var languageDefaults = {
    "AR": 13,
    "CS": 1,
    "DA": 7,
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
    "PT_BR": 5,
    "PT_PT": 5,
    "RO": 8,
    "RU": 15,
    "SL": 17,
    "SR": 19,
    "SR_LATN": 18,
    "SV": 6,
    "TR": 3
}

function clampedIndex(value) {
    var parsed = Number(value)
    if (!isFinite(parsed))
        return 0
    return Math.max(0, Math.min(count - 1, Math.round(parsed)))
}

function name(value) {
    return layouts[clampedIndex(value)].name
}

function menuName(value) {
    return menuNames[clampedIndex(value)]
}

function script(value) {
    return layouts[clampedIndex(value)].script
}

function languageScript(languageCode) {
    languageCode = String(languageCode).toUpperCase()
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
    for (var i = 0; i < layouts.length; ++i) {
        var allowedLanguages = layouts[i].languages
        if (layouts[i].script === wantedScript
                && (!allowedLanguages
                    || allowedLanguages.indexOf(languageCode) >= 0))
            result.push(i)
    }
    return result
}

function letter(value, row, column) {
    var rows = layouts[clampedIndex(value)].rows
    if (row < 0 || row >= rows.length || column < 0 || column >= rows[row].length)
        return ""
    return rows[row][column]
}

function shifted(letterValue, layoutValue) {
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
