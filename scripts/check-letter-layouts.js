/* Validate stable layout indices, row data, and locale-specific casing. */
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const root = path.resolve(__dirname, "..");
const sourcePath = path.join(root, "layouts", "FutoLetterLayouts.js");
const source = fs.readFileSync(sourcePath, "utf8").replace(/^\.pragma library\r?\n/, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context, { filename: sourcePath });

function assert(condition, message) {
    if (!condition)
        throw new Error(message);
}

assert(context.count === 17, "Expected seventeen layouts");
for (let layout = 0; layout < context.count; ++layout) {
    assert(context.name(layout), "Layout " + layout + " has no name");
    for (let row = 0; row < 3; ++row)
        assert(context.letter(layout, row, 0), "Layout " + layout + " row " + row + " is empty");
}

assert(context.name(0) === "QWERTY", "Persisted QWERTY index changed");
assert(context.name(3) === "Turkish Q", "Persisted Turkish index changed");
assert(context.name(16) === "Turkish F", "Turkish F must remain appended at index 16");
assert(context.menuNames.length === context.count,
       "Every layout must have a compact held-123 menu name");
for (let layout = 0; layout < context.count; ++layout) {
    assert(context.menuName(layout), "Layout " + layout + " has no compact menu name");
    assert(context.menuName(layout).length <= 10,
           "Layout " + layout + " menu name is too wide: " + context.menuName(layout));
}
assert(context.menuName(6) === "SE/FI", "Nordic menu name must stay compact");
assert(context.menuName(15) === "CYRILLIC", "East Slavic menu name must stay compact");
assert(context.letter(11, 0, 0) === "'", "Dvorak punctuation mapping changed");
assert(context.shifted("i", 0) === "I", "QWERTY i must shift to I");
assert(context.shifted("i", 3) === "İ", "Turkish i must shift to İ");
assert(context.shifted("i", 16) === "İ", "Turkish F i must shift to İ");
assert(context.shifted("ı", 3) === "I", "Turkish ı must shift to I");
assert(context.shifted("m", 0) === "M", "Lowercase m must shift to M");
assert(context.compatibleIndices("EN").indexOf(16) >= 0,
       "Latin languages must support Turkish F");
assert(context.compatibleIndices("EN").indexOf(13) < 0,
       "Latin languages must not offer Arabic");
assert(context.compatibleIndices("AR").length === 1
       && context.compatibleIndices("AR")[0] === 13,
       "Arabic must only offer the Arabic layout");

const expectedDefaults = {
    AR: 13, CS: 1, DA: 7, DE: 4, EL: 14, EN: 0, EN_GB: 0, ES: 5,
    FI: 6, FR: 2, HR: 1, IT: 0, LT: 0, LV: 0, NB: 7, NL: 0,
    PL: 0, PT_BR: 5, PT_PT: 5, RO: 8, RU: 15, SL: 0, SV: 6, TR: 3
};
for (const [language, layout] of Object.entries(expectedDefaults)) {
    assert(context.defaultForLanguage(language) === layout,
           language + " default layout changed unexpectedly");
}
assert(context.legacyDefaultForLanguage("DE") === 0,
       "Legacy Latin default must remain QWERTY for migration");

process.stdout.write("Letter layout validation passed: " + context.count + " layouts.\n");
