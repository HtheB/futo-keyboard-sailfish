.pragma library
.import "FutoLanguageData.js" as Languages
.import "FutoGeneratedLayouts.js" as Generated

// Search-only names and aliases. Visible titles still come from the layout
// catalogue; native names and locale codes are added automatically below.
var englishNames = {
    AF: "Afrikaans", AK: "Akan", ALT: "Southern Altai", AR: "Arabic",
    AZ_AZ: "Azerbaijani Azerbaijan Azeri", BA: "Bashkir",
    BE_BY: "Belarusian Belarus", BE_LATN: "Belarusian Latin",
    BG: "Bulgarian", SJE: "Pite Sami", BN_BD: "Bangla Bengali Bangladesh",
    BN_IN: "Bangla Bengali India", BOD: "Tibetan", CA: "Catalan",
    CE: "Chechen", CKB: "Central Kurdish Sorani", CS: "Czech",
    CV: "Chuvash", CY: "Welsh", DA: "Danish", DE: "German",
    DE_CH: "German Switzerland Swiss", EL: "Greek",
    EN_GB: "English British United Kingdom UK", EN_IN: "English India",
    EN_SHAW: "English Shavian", EN: "English American United States US",
    EO: "Esperanto", ES: "Spanish", ES_419: "Spanish Latin America",
    ES_US: "Spanish United States", ET_EE: "Estonian Estonia",
    EU_ES: "Basque Spain", FA: "Persian Farsi", FI: "Finnish",
    FR: "French", FR_CA: "French Canada Canadian",
    FR_CH: "French Switzerland Swiss", GAG: "Gagauz", GL_ES: "Galician Spain",
    HA: "Hausa", HI: "Hindi", HI_LATN: "Hindi Latin Hinglish",
    HR: "Croatian", HU: "Hungarian", HY_AM: "Armenian Armenia",
    IN: "Indonesian Bahasa Indonesia", IPA: "International Phonetic Alphabet",
    IS: "Icelandic", IT: "Italian", IT_CH: "Italian Switzerland Swiss",
    IZH: "Ingrian Izhorian", JA: "Japanese", KA_GE: "Georgian Georgia",
    KAA: "Kara-Kalpak Karakalpak", KAB: "Kabyle", KK: "Kazakh",
    KK_LATN: "Kazakh Latin", KM_KH: "Khmer Cambodia", KN_IN: "Kannada India",
    KRL: "Karelian", KU_LATN: "Kurdish Latin Kurmanji", KY: "Kyrgyz",
    LO_LA: "Lao Laos", LT: "Lithuanian", LUD: "Ludic Veps",
    LV: "Latvian", MK: "Macedonian", ML_IN: "Malayalam India",
    MN_MN: "Mongolian Mongolia", MR_IN: "Marathi India", MS_MY: "Malay Malaysia",
    MT: "Maltese", MY: "Burmese Myanmar", NB: "Norwegian Bokmal",
    NE_NP: "Nepali Nepal", NEW_NP: "Newari Nepal Bhasa",
    NL: "Dutch", NL_BE: "Dutch Belgium Flemish", PA_IN: "Punjabi India",
    PL: "Polish", PT_BR: "Portuguese Brazil Brazilian",
    PT_PT: "Portuguese Portugal European", RO: "Romanian", RU: "Russian",
    SAH: "Yakut Sakha", SE: "Northern Sami", SI_LK: "Sinhala Sinhalese Sri Lanka",
    SK: "Slovak", SL: "Slovenian Slovene", SMA: "Southern Sami",
    SMJ: "Lule Sami", SMN: "Inari Sami", SJU: "Ume Sami", SQ: "Albanian",
    SR: "Serbian Cyrillic", SR_LATN: "Serbian Latin", SV: "Swedish",
    SW: "Swahili", TA_IN: "Tamil India", TA_LK: "Tamil Sri Lanka",
    TA_SG: "Tamil Singapore", TE_IN: "Telugu India", TG: "Tajik", TH: "Thai",
    TK: "Turkmen", TL: "Filipino Tagalog", TOK: "Toki Pona", TR: "Turkish",
    TT: "Tatar", TYV: "Tuvinian Tuvan", UG: "Uyghur Uighur", UK: "Ukrainian",
    UR: "Urdu", UZ_UZ: "Uzbek Uzbekistan", VEP: "Veps Vepsian", VOT: "Votic",
    ZGH_LATN: "Amazigh Tamazight Berber Latin", ZH: "Chinese Simplified Mandarin",
    ZH_HANT: "Chinese Traditional Mandarin", ZU: "Zulu", ABQ: "Abaza",
    ADY: "Adyghe", AGX: "Agul", KBD: "Kabardian", INH: "Ingush",
    DAR: "Dargwa Dargin", KPV: "Komi Zyrian", LBE: "Lak", LEZ: "Lezgian Lezghian",
    AV: "Avar Avaric", MHR: "Mari Meadow", MRJ: "Mari Western Hill", RUT: "Rutul",
    YRK: "Nenets", NIO: "Nganasan", ENF: "Forest Enets", ENH: "Tundra Enets",
    KOI: "Komi Permyak", TAB: "Tabasaran", UDM: "Udmurt", TKR_RU: "Tsakhur Russia",
    ZGH: "Amazigh Tamazight Berber Tifinagh"
}

var englishDisplayNames = {
    ALT: "Altai", AR: "Arabic", BA: "Bashkir", BE_BY: "Belarusian",
    BG: "Bulgarian", BN_BD: "Bengali", BN_IN: "Bengali", BOD: "Tibetan",
    CKB: "Central Kurdish", CV: "Chuvash", EL: "Greek", FA: "Persian",
    HI: "Hindi", HY_AM: "Armenian", JA: "Japanese", KA_GE: "Georgian",
    KK: "Kazakh", KM_KH: "Khmer", KN_IN: "Kannada", KY: "Kyrgyz",
    LO_LA: "Lao", MK: "Macedonian", ML_IN: "Malayalam", MN_MN: "Mongolian",
    MR_IN: "Marathi", MY: "Burmese", NE_NP: "Nepali", NEW_NP: "Newari",
    PA_IN: "Punjabi", RU: "Russian", SAH: "Yakut", SI_LK: "Sinhala",
    SR: "Serbian", TA_IN: "Tamil", TA_LK: "Tamil", TA_SG: "Tamil",
    TE_IN: "Telugu", TG: "Tajik", TH: "Thai", TT: "Tatar", TYV: "Tuvan",
    UG: "Uyghur", UK: "Ukrainian", UR: "Urdu", ZH: "Chinese",
    ZH_HANT: "Chinese", KPV: "Komi", KOI: "Komi-Permyak", MHR: "Meadow Mari",
    MRJ: "Hill Mari", YRK: "Nenets", NIO: "Nganasan", ENF: "Forest Enets",
    ENH: "Tundra Enets", UDM: "Udmurt", ZGH: "Amazigh"
}

var variantNames = {
    "legacy-3": "Q", "legacy-4": "QWERTZ", "legacy-5": "QWERTY",
    "legacy-6": "Nordic", "legacy-7": "Nordic", "legacy-8": "QWERTY",
    "legacy-16": "F", "legacy-17": "QWERTZ", "legacy-18": "QWERTZ",
    "legacy-19": "Cyrillic", arabic: "AOSP", belarusian_latin: "Latin",
    bulgarian: "Phonetic", bulgarian_bds: "BDS", bengali_akkhor: "Akkhor",
    bengali_inscript: "InScript", spanish: "QWERTY", nordic: "Nordic",
    armenian_phonetic: "Phonetic", kazakh_cyrillic: "Cyrillic", kazakh_latin: "Latin",
    kannada_inscript: "InScript", lithuanian_qwerty: "QWERTY", myanmar_g: "G",
    nepali_romanized: "Romanized", newa_romanized: "Romanized", nordic__nb: "Nordic",
    slovenian_qwerty: "QWERTY", tamil_inscript: "InScript", uyghur_phonetic: "Phonetic",
    urdu_phonetic: "Phonetic", amazigh_basic: "Basic", zh_qwerty: "Pinyin (QWERTY)",
    japanese_qwerty: "Romaji (QWERTY)"
}

function displayName(item, layouts) {
    // Shape-based choices are not a language, even if several languages use
    // them. Preserve their familiar names and keep their language tags hidden.
    if (/^(QWERT[YZ]|AZERTY|Colemak|Dvorak|Workman|IPA)(\b|\s|\()/i.test(item.name))
        return item.name
    var groups = [], byLanguage = {}
    for (var i = 0; i < item.languages.length; ++i) {
        var language = Languages.entry(item.languages[i])
        var base = language.officialCode.split("_")[0]
        if (!byLanguage[base]) {
            byLanguage[base] = {language: language, count: 0}
            groups.push(byLanguage[base])
        }
        byLanguage[base].count++
    }
    // Broad shared families (such as North Caucasian) are layout names, not
    // one language. Do not mislabel them as whichever language was first.
    if (groups.length === 0 || groups.length > 2) return item.name
    var names = []
    for (var gi = 0; gi < groups.length; ++gi) {
        var entry = groups[gi].language
        var nativeName = Languages.localeName(entry)
        if (groups[gi].count > 1)
            nativeName = nativeName.replace(/\s*[\(（][^\)）]*[\)）]/g, "").trim()
        var english = englishDisplayNames[entry.code] || englishNames[entry.code]
        names.push(nativeName + (!Languages.isLatinLead(nativeName) ? " (" + english + ")" : ""))
    }
    var variant = variantNames[layouts.idForIndex(item.index)]
    return names.join(" / ") + (variant ? " - " + variant : "")
}

function normalize(value) {
    var text = String(value || "").toLowerCase()
    // Qt 5.6 does not provide String.normalize. Keep common Latin search
    // spellings usable there too (for example cestina, espanol and turkce).
    var accents = [/[àáâãäåāăą]/g, /[çćĉċč]/g, /[ďđð]/g,
        /[èéêëēĕėęě]/g, /[ĝğġģ]/g, /[ĥħ]/g, /[ìíîïĩīĭįı]/g,
        /[ĵ]/g, /[ķ]/g, /[ĺļľŀł]/g, /[ñńņňŋ]/g,
        /[òóôõöøōŏő]/g, /[ŕŗř]/g, /[śŝşšș]/g, /[ţťŧț]/g,
        /[ùúûüũūŭůűų]/g, /[ŵ]/g, /[ýÿŷ]/g, /[źżž]/g]
    var bases = "acdeghijklnorstuwyz"
    for (var i = 0; i < accents.length; ++i)
        text = text.replace(accents[i], bases.charAt(i))
    return text.replace(/[\u0300-\u036f]/g, "").replace(/[_\-\s]+/g, " ").trim()
}

function build(layouts) {
    var result = [], byIndex = {}
    for (var i = 0; i < layouts.builtinCount; ++i) {
        var hint = layouts.imeHint(i)
        if (hint && hint !== "qwerty") continue
        var item = {index: i, name: layouts.name(i), languages: [], search: [layouts.name(i),
            layouts.menuName(i), layouts.idForIndex(i), layouts.script(i)]}
        result.push(item)
        byIndex[i] = item
    }
    function add(index, terms, code) {
        if (!byIndex[index]) return
        byIndex[index].search.push(terms)
        if (byIndex[index].languages.indexOf(code) < 0) byIndex[index].languages.push(code)
    }
    for (var li = 0; li < Languages.languages.length; ++li) {
        var language = Languages.languages[li]
        var terms = [englishNames[language.code] || "", Languages.localeName(language),
            language.name, language.code, language.officialCode].join(" ")
        add(layouts.defaultForLanguage(language.code), terms, language.code)
        var options = Generated.languageLayoutOptions[language.code] || [language.layoutId]
        for (var oi = 0; oi < options.length; ++oi)
            add(layouts.indexForId(options[oi]), terms, language.code)
        // The established Turkish F is an alternative, not a default.
        if (language.code === "TR") add(layouts.indexForId("legacy-16"), terms, language.code)
    }
    for (var ri = 0; ri < result.length; ++ri) {
        result[ri].name = displayName(result[ri], layouts)
        result[ri].search = normalize(result[ri].search.join(" ") + " " + result[ri].name)
    }
    result.sort(function(first, second) {
        return Languages.compareDisplayNames(first.name, second.name) || first.index - second.index
    })
    return result
}

function filter(index, query) {
    var search = normalize(query), tokens = search ? search.split(" ") : [], result = []
    for (var i = 0; i < index.length; ++i) {
        var matches = true
        for (var t = 0; t < tokens.length; ++t)
            if (index[i].search.indexOf(tokens[t]) < 0) { matches = false; break }
        if (matches) result.push({index: index[i].index, name: index[i].name})
    }
    return result
}
