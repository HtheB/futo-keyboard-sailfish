.pragma library

// Keep this list alphabetized by the user-facing name.  The three
// script-specific entries currently provide direct typing only; all other
// entries also have packaged prediction dictionaries.
var languages = [
    { code: "AR", name: "العربية", prediction: false },
    { code: "CS", name: "Čeština", prediction: true },
    { code: "DA", name: "Dansk", prediction: true },
    { code: "DE", name: "Deutsch", prediction: true },
    { code: "EN_GB", name: "English (UK)", prediction: true },
    { code: "EN", name: "English (US)", prediction: true },
    { code: "ES", name: "Español", prediction: true },
    { code: "FR", name: "Français", prediction: true },
    { code: "EL", name: "Ελληνικά", prediction: false },
    { code: "HR", name: "Hrvatski", prediction: true },
    { code: "IT", name: "Italiano", prediction: true },
    { code: "LV", name: "Latviešu", prediction: true },
    { code: "LT", name: "Lietuvių", prediction: true },
    { code: "NL", name: "Nederlands", prediction: true },
    { code: "NB", name: "Norsk bokmål", prediction: true },
    { code: "PL", name: "Polski", prediction: true },
    { code: "PT_BR", name: "Português (Brasil)", prediction: true },
    { code: "PT_PT", name: "Português (Portugal)", prediction: true },
    { code: "RO", name: "Română", prediction: true },
    { code: "RU", name: "Русский", prediction: false },
    { code: "SL", name: "Slovenščina", prediction: true },
    { code: "FI", name: "Suomi", prediction: true },
    { code: "SV", name: "Svenska", prediction: true },
    { code: "TR", name: "Türkçe", prediction: true }
]

function entry(code) {
    code = String(code).toUpperCase()
    for (var i = 0; i < languages.length; ++i) {
        if (languages[i].code === code)
            return languages[i]
    }
    return { code: code, name: code, prediction: false }
}

function name(code) {
    return entry(code).name
}

function predictionSupported(code) {
    return !!entry(code).prediction
}
