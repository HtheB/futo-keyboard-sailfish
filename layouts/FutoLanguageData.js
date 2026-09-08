.pragma library
.import "FutoLanguageCatalogue.js" as Catalogue

// Keep the names already shown by released versions unchanged. Standard new
// locales are named by Qt in their own language; uncommon entries carry an
// explicit upstream name in the generated catalogue.
var establishedNames = {
    "AR": "العربية", "CS": "Čeština", "DA": "Dansk", "DE": "Deutsch",
    "EL": "Ελληνικά", "EN": "English (US)", "EN_GB": "English (UK)",
    "ES": "Español", "FA": "فارسی", "FI": "Suomi", "FR": "Français",
    "HR": "Hrvatski", "HU": "Magyar", "IT": "Italiano",
    "LT": "Lietuvių", "LV": "Latviešu", "NB": "Norsk bokmål",
    "NL": "Nederlands", "PL": "Polski", "PT_BR": "Português (Brasil)",
    "PT_PT": "Português (Portugal)", "RO": "Română", "RU": "Русский",
    "SL": "Slovenščina", "SR": "Српски (ћирилица)",
    "SR_LATN": "Srpski (latinica)", "SV": "Svenska", "TR": "Türkçe"
}

// Sailfish OS 5.x uses Qt 5.6, whose locale database predates many of the
// locale identifiers in FUTO's current layout catalogue.  Keep explicit
// end-user names here instead of allowing unsupported locales to appear as
// raw codes such as "tk" or "si_LK".
var additionalNames = {
    "AF": "Afrikaans", "AK": "Akan", "ALT": "алтай тил",
    "AZ_AZ": "Azərbaycan dili", "BA": "башҡорт теле",
    "BE_BY": "Беларуская", "BE_LATN": "Biełaruskaja (łacinka)",
    "BG": "Български", "BN_BD": "বাংলা (বাংলাদেশ)",
    "BN_IN": "বাংলা (ভারত)", "BOD": "བོད་སྐད་", "CA": "Català",
    "CE": "Нохчийн", "CKB": "کوردیی ناوەندی", "CV": "чӑваш чӗлхи",
    "CY": "Cymraeg", "DE_CH": "Deutsch (Schweiz)",
    "EN_IN": "English (India)", "EN_SHAW": "English (Shavian)",
    "EO": "Esperanto", "ES_419": "Español (Latinoamérica)",
    "ES_US": "Español (Estados Unidos)", "ET_EE": "Eesti",
    "EU_ES": "Euskara", "FR_CA": "Français (Canada)",
    "FR_CH": "Français (Suisse)", "GAG": "Gagauzça",
    "GL_ES": "Galego", "HA": "Hausa", "HI": "हिन्दी",
    "HY_AM": "Հայերեն", "IN": "Bahasa Indonesia", "IS": "Íslenska",
    "IT_CH": "Italiano (Svizzera)", "IZH": "ižoran keeli",
    "KA_GE": "ქართული", "KAA": "Qaraqalpaqsha", "KAB": "Taqbaylit",
    "KK": "Қазақ тілі", "KK_LATN": "Qazaq tili (latyn)",
    "KM_KH": "ខ្មែរ", "KN_IN": "ಕನ್ನಡ", "KRL": "karjalan kieli",
    "KU_LATN": "Kurdî", "KY": "Кыргызча", "LO_LA": "ລາວ",
    "MK": "Македонски", "ML_IN": "മലയാളം", "MN_MN": "Монгол",
    "MR_IN": "मराठी", "MS_MY": "Bahasa Melayu", "MT": "Malti",
    "MY": "မြန်မာ", "NE_NP": "नेपाली", "NEW_NP": "नेपाल भाषा",
    "NL_BE": "Nederlands (België)", "PA_IN": "ਪੰਜਾਬੀ",
    "SAH": "Саха тыла", "SE": "Davvisámegiella",
    "SI_LK": "සිංහල", "SK": "Slovenčina",
    "SMA": "Åarjelsaemien gïele", "SMJ": "Julevsámegiella",
    "SMN": "Anarâškielâ", "SQ": "Shqip", "SW": "Kiswahili",
    "TA_IN": "தமிழ் (இந்தியா)", "TA_LK": "தமிழ் (இலங்கை)",
    "TA_SG": "தமிழ் (சிங்கப்பூர்)", "TE_IN": "తెలుగు",
    "TG": "Тоҷикӣ", "TH": "ไทย", "TK": "Türkmençe",
    "TL": "Filipino", "TT": "Татарча", "TYV": "тыва дыл",
    "UG": "ئۇيغۇرچە", "UK": "Українська", "UR": "اردو",
    "UZ_UZ": "O‘zbekcha", "VOT": "vaďďa tšeeli",
    "ZGH_LATN": "Tamaziɣt (Latin)", "ZU": "isiZulu"
}

var languages = Catalogue.languages

function entry(code) {
    code = String(code).toUpperCase()
    for (var i = 0; i < languages.length; ++i) {
        if (languages[i].code === code)
            return languages[i]
    }
    return { code: code, officialCode: code.toLowerCase(), name: code,
             prediction: false, dictionaryPack: "", swipe: false }
}

function localeName(item) {
    if (establishedNames[item.code] !== undefined)
        return establishedNames[item.code]
    if (additionalNames[item.code] !== undefined)
        return additionalNames[item.code]
    if (item.name && item.name !== item.officialCode)
        return String(item.name)
    try {
        // Qt 5.6 uses underscore-separated locale names on Sailfish.
        var locale = Qt.locale(String(item.officialCode))
        var value = String(locale.nativeLanguageName || "")
        if (value !== "") {
            var country = String(locale.nativeCountryName || "")
            if (String(item.officialCode).indexOf("_") >= 0 && country !== "")
                value += " (" + country + ")"
            return value
        }
    } catch (error) {
    }
    return String(item.name || item.code)
}

function name(code) {
    return localeName(entry(code))
}

function predictionSupported(code) {
    return !!entry(code).prediction
}

function swipeSupported(code) {
    return !!entry(code).swipe
}

function dictionaryPack(code) {
    return String(entry(code).dictionaryPack || "")
}

function isLatinLead(value) {
    value = String(value || "")
    for (var i = 0; i < value.length; ++i) {
        var code = value.charCodeAt(i)
        if ((code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A)
                || (code >= 0x00C0 && code <= 0x024F))
            return true
        if (code > 0x024F)
            return false
    }
    return true
}

function displayLanguages() {
    var result = []
    for (var i = 0; i < languages.length; ++i) {
        var item = languages[i]
        result.push({ code: item.code, title: localeName(item),
                      prediction: !!item.prediction })
    }
    result.sort(function(first, second) {
        var firstLatin = isLatinLead(first.title)
        var secondLatin = isLatinLead(second.title)
        if (firstLatin !== secondLatin)
            return firstLatin ? -1 : 1
        return String(first.title).localeCompare(String(second.title))
    })
    return result
}
