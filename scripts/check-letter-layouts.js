/* Validate stable layout indices, row data, and locale-specific casing. */
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const root = path.resolve(__dirname, "..");
const sourcePath = path.join(root, "layouts", "FutoLetterLayouts.js");
function dataVariable(file, name) {
    const source = fs.readFileSync(path.join(root, "layouts", file), "utf8")
        .replace(/^\.pragma library\s*/m, "");
    const dataContext = {};
    vm.createContext(dataContext);
    vm.runInContext(source, dataContext, { filename: file });
    return dataContext[name];
}
const source = fs.readFileSync(sourcePath, "utf8")
    .replace(/^\.pragma library\s*/m, "")
    .replace(/^\.import .*$/gm, "");
const context = {
    Generated: {
        layouts: dataVariable("FutoGeneratedLayouts.js", "layouts"),
        languageLayoutIds: dataVariable("FutoGeneratedLayouts.js", "languageLayoutIds"),
        languageAlternatives: dataVariable("FutoGeneratedLayouts.js", "languageAlternatives")
    },
    Catalogue: { languages: dataVariable("FutoLanguageCatalogue.js", "languages") }
};
vm.createContext(context);
vm.runInContext(source, context, { filename: sourcePath });

function assert(condition, message) {
    if (!condition)
        throw new Error(message);
}

assert(context.legacyLayoutCount === 21, "Expected twenty-one stable legacy layouts");
assert(context.count === 118, "Expected 21 stable plus 97 generated layouts");
const establishedLanguageCodes = new Set([
    "AR", "CS", "DA", "DE", "EL", "EN", "EN_GB", "ES", "FA", "FI", "FR",
    "HR", "HU", "IT", "LT", "LV", "NB", "NL", "PL", "PT_BR", "PT_PT",
    "RO", "RU", "SL", "SR", "SR_LATN", "SV", "TR"
]);
for (const language of context.Catalogue.languages) {
    if (!establishedLanguageCodes.has(language.code))
        assert(context.defaultForLanguage(language.code) >= context.legacyLayoutCount,
               language.code + " unexpectedly falls back to a legacy layout");
}
for (let layout = 0; layout < context.count; ++layout) {
    assert(context.name(layout), "Layout " + layout + " has no name");
    assert(context.rowCount(layout) >= 2 && context.rowCount(layout) <= 5,
           "Layout " + layout + " has an invalid row count");
    for (let row = 0; row < context.rowCount(layout); ++row)
        assert(context.rowLength(layout, row) > 0,
               "Layout " + layout + " row " + row + " is empty");
}

assert(context.name(0) === "QWERTY", "Persisted QWERTY index changed");
assert(context.name(3) === "Turkish Q", "Persisted Turkish index changed");
assert(context.name(16) === "Turkish F", "Turkish F must remain appended at index 16");
assert(context.name(17) === "Slovenian QWERTZ",
       "Slovenian QWERTZ must be appended at index 17");
assert(context.name(18) === "Croatian / Serbian Latin QWERTZ",
       "Croatian/Serbian Latin QWERTZ must be appended at index 18");
assert(context.name(19) === "Serbian Cyrillic",
       "Serbian Cyrillic must be appended at index 19");
assert(context.name(20) === "Persian",
       "Persian must be appended at index 20");
assert(context.menuNames.length === context.count,
       "Every layout must have a compact held-123 menu name");
for (let layout = 0; layout < context.count; ++layout) {
    assert(context.menuName(layout), "Layout " + layout + " has no compact menu name");
}
assert(context.menuName(6) === "SE/FI", "Nordic menu name must stay compact");
assert(context.menuName(7) === "NO",
       "Index 7 is the Norwegian arrangement, not a shared Danish one");
assert(context.name(7) === "Nordic (Norwegian)",
       "Index 7 must name itself as Norwegian");
assert(context.menuName(15) === "CYRILLIC", "East Slavic menu name must stay compact");
assert(context.letter(11, 0, 0) === "'", "Dvorak punctuation mapping changed");
assert(context.letter(17, 0, 5) === "z" && context.letter(17, 0, 10) === "š",
       "Slovenian top row must be QWERTZ with š at the right");
assert(context.letter(17, 1, 9) === "č" && context.letter(17, 1, 10) === "ž",
       "Slovenian middle row must end with č and ž");
assert(context.letter(18, 0, 10) === "š"
       && context.letter(18, 1, 9) === "č"
       && context.letter(18, 1, 10) === "ć"
       && context.letter(18, 2, 7) === "đ"
       && context.letter(18, 2, 8) === "ž",
       "Croatian/Serbian Latin national letters are incorrect");
assert(context.letter(19, 0, 0) === "љ"
       && context.letter(19, 0, 5) === "з"
       && context.letter(19, 1, 10) === "ћ"
       && context.letter(19, 2, 0) === "ѕ"
       && context.letter(19, 2, 1) === "џ"
       && context.letter(19, 2, 7) === "ђ"
       && context.letter(19, 2, 8) === "ж",
       "Serbian Cyrillic letters are incorrect");
assert(context.shifted("i", 0) === "I", "QWERTY i must shift to I");
assert(context.shifted("i", 3) === "İ", "Turkish i must shift to İ");
assert(context.shifted("i", 16) === "İ", "Turkish F i must shift to İ");
assert(context.shifted("ı", 3) === "I", "Turkish ı must shift to I");
assert(context.shifted("m", 0) === "M", "Lowercase m must shift to M");
assert(context.compatibleIndices("EN").indexOf(16) >= 0,
       "Latin languages must support Turkish F");
assert(context.compatibleIndices("EN").indexOf(13) < 0,
       "Latin languages must not offer Arabic");
assert(context.compatibleIndices("AR").includes(13),
       "Arabic must retain its stable Arabic layout");
assert(context.compatibleIndices("RU").includes(15),
       "Russian must retain its stable East Slavic layout");
assert(context.compatibleIndices("SR").includes(19),
       "Serbian must retain its stable Cyrillic layout");
assert(context.compatibleIndices("FA").includes(20),
       "Persian must retain its stable Persian layout");
assert(context.letter(20, 0, 0) === "ض"
       && context.letter(20, 1, 2) === "ی"
       && context.letter(20, 1, 9) === "ک"
       && context.letter(20, 1, 10) === "گ"
       && context.letter(20, 2, 2) === "ژ"
       && context.letter(20, 2, 7) === "پ"
       && context.letter(20, 2, 9) === "چ",
       "Persian national letters are incorrect");

const expectedDefaults = {
    AR: 13, CS: 1, DE: 4, EL: 14, EN: 0, EN_GB: 0, ES: 5, FA: 20,
    FI: 6, FR: 2, HR: 18, IT: 0, LT: 0, LV: 0, NB: 7, NL: 0,
    PL: 0, RO: 8, RU: 15, SL: 17,
    SR: 19, SR_LATN: 18, SV: 6, TR: 3
};
for (const [language, layout] of Object.entries(expectedDefaults)) {
    assert(context.defaultForLanguage(language) === layout,
           language + " default layout changed unexpectedly");
}
// Danish, Norwegian and Portuguese each need their own home row rather than
// the neighbouring country's.
const nationalHomeRows = {
    DA: ["æ", "ø"],
    NB: ["ø", "æ"],
    PT_PT: ["ç"],
    PT_BR: ["ç"],
    ES: ["ñ"]
};
for (const [language, tail] of Object.entries(nationalHomeRows)) {
    const layout = context.defaultForLanguage(language);
    const length = context.rowLength(layout, 1);
    const actual = [];
    for (let i = length - tail.length; i < length; ++i)
        actual.push(context.letter(layout, 1, i));
    assert(actual.join("") === tail.join(""),
           language + " home row ends with " + actual.join("")
           + " instead of " + tail.join(""));
}
assert(context.defaultForLanguage("DA") !== context.defaultForLanguage("NB"),
       "Danish and Norwegian must not share one layout");
assert(context.defaultForLanguage("PT_PT") !== context.defaultForLanguage("ES"),
       "Portuguese must not share the Spanish layout");

assert(context.legacyDefaultForLanguage("DE") === 0,
       "Legacy Latin default must remain QWERTY for migration");

for (const language of context.Catalogue.languages) {
    const layout = context.defaultForLanguage(language.code);
    assert(layout >= 0 && layout < context.count,
           language.code + " has no valid default layout");
    assert(context.compatibleIndices(language.code).includes(layout),
           language.code + " default is not compatible");
}
assert(!context.Catalogue.languages.some(item => item.code === "IW"),
       "Hebrew must stay excluded");

process.stdout.write("Letter layout validation passed: " + context.count + " layouts.\n");
