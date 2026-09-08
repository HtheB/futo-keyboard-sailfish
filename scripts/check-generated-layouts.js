#!/usr/bin/env node

"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");
const root = path.resolve(__dirname, "..");

function load(file) {
    const context = {};
    vm.runInNewContext(fs.readFileSync(path.join(root, "layouts", file), "utf8")
        .replace(/^\.pragma library\s*/m, ""), context, { filename: file });
    return context;
}

function assert(condition, message) {
    if (!condition)
        throw new Error(message);
}

const generated = load("FutoGeneratedLayouts.js");
const catalogue = load("FutoLanguageCatalogue.js");

function loadLanguageData() {
    const context = {
        Catalogue: { languages: catalogue.languages },
        Qt: { locale: function() { return {}; } }
    };
    const source = fs.readFileSync(path.join(root, "layouts", "FutoLanguageData.js"), "utf8")
        .replace(/^\.pragma library\s*/m, "")
        .replace(/^\.import .*$/gm, "");
    vm.runInNewContext(source, context, { filename: "FutoLanguageData.js" });
    return context;
}

const languageData = loadLanguageData();
assert(generated.upstreamRevision === "fb4dad270790d980c32417b60359104bd0c32c1c",
       "generated layouts do not use the pinned FUTO revision");
assert(generated.layouts.length === 97, "expected 97 distinct resolved FUTO layouts");
assert(catalogue.languages.length === 140, "expected 140 eligible FUTO languages");
assert(catalogue.languages.filter(item => item.prediction).length === 36,
       "prediction catalogue must contain exactly 36 dictionary-backed locales");
assert(catalogue.languages.every(item => item.swipe === item.prediction),
       "swipe must only be offered where a prediction dictionary exists");
const excluded = ["IW", "ZH", "ZH_HANT", "JA", "KO", "VI", "GA", "HAW",
                  "LKT", "KS_LATN", "DZ", "LBJ", "SIP", "XSR", "ZZ"];
assert(!catalogue.languages.some(item => excluded.includes(item.code)),
       "excluded IME/composition languages leaked into the catalogue");
for (const language of catalogue.languages) {
    const title = languageData.localeName(language);
    assert(title && title !== language.code && title !== language.officialCode,
           language.code + " is displayed as a raw locale code");
}

for (const language of catalogue.languages) {
    const layout = generated.layouts.find(item => item.id === language.layoutId);
    assert(layout, language.code + " refers to a missing layout");
    assert(layout.rows.length >= 2 && layout.rows.length <= 5,
           language.code + " has an invalid row count");
    assert(layout.rows.every(row => row.length > 0 && row.length <= 12),
           language.code + " has invalid row geometry");
}

const arabic = generated.layouts.find(item => item.id === generated.languageLayoutIds.AR);
const lam = arabic.rows.flat().find(key => key.caption === "ل");
assert(lam.more.some(key => key.caption === "ﻻ" && key.output === "لا"),
       "Arabic label/output ligature mapping was not preserved");
const hungarian = generated.layouts.find(item => item.id === generated.languageLayoutIds.HU);
assert(hungarian.rows.length === 4 && hungarian.rows[0].map(key => key.caption).join("")
       === "áéíóöőúüű-", "Hungarian FUTO layout is not exact");
const shavian = generated.layouts.find(item => item.id === generated.languageLayoutIds.EN_SHAW);
assert(shavian.rows.length === 5, "Shavian's five-row layout was flattened");
const punjabi = generated.layouts.find(item => item.id === generated.languageLayoutIds.PA_IN);
assert(punjabi.numberRow.length === 10,
       "Gurmukhi's explicit FUTO number row is missing");
assert(generated.layouts.find(item => item.id === "qwerty").name === "QWERTY",
       "the generated FUTO QWERTY label changed");

process.stdout.write("Generated layout validation passed: 140 languages, 97 layouts.\n");
