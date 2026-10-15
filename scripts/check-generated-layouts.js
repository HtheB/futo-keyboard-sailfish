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
assert(generated.layouts.length === 102, "expected 102 distinct resolved FUTO layouts");
assert(catalogue.languages.length === 143, "expected 143 eligible FUTO languages");
assert(catalogue.languages.filter(item => item.prediction).length === 73,
       "prediction catalogue must contain exactly 73 dictionary-backed locales");
assert(catalogue.languages.every(item => item.swipe === item.prediction),
       "swipe must only be offered where a prediction dictionary exists");
const excluded = ["IW", "KO", "VI", "GA", "HAW",
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
assert(Array.from(generated.languageLayoutOptions.BG).join(",")
       === "bulgarian,bulgarian_bds",
       "Bulgarian must offer both its phonetic and official BDS layouts");
const bulgarianBds = generated.layouts.find(item => item.id === "bulgarian_bds");
assert(bulgarianBds.rows.map(row => row.filter(key => key.kind === "character")
       .map(key => key.caption).join("")).join("/")
       === "уеишщксдзцб/ьяаожгтнвмч/юйъэфхпрл",
       "the official Bulgarian BDS key order changed");
assert(generated.layouts.find(item => item.id === "qwerty").name === "QWERTY",
       "the generated FUTO QWERTY label changed");

const newlyBacked = {
    AZ_AZ: "az", ET_EE: "et", IS: "is", KM_KH: "km", MK: "mk",
    NE_NP: "ne", TH: "th", TL: "tl", ZGH: "zgh"
};
for (const code of Object.keys(newlyBacked)) {
    const language = catalogue.languages.find(item => item.code === code);
    assert(language && language.dictionaryPack === newlyBacked[code]
           && language.prediction && language.swipe,
           code + " does not expose its verified dictionary pack");
}

for (const code of ["JA", "ZH", "ZH_HANT"]) {
    const language = catalogue.languages.find(item => item.code === code);
    assert(language && language.compositionPack && !language.prediction && !language.swipe,
           code + " must use its conversion engine, not a direct dictionary or swipe");
    assert(generated.layouts.find(item => item.id === language.layoutId).imeHint === "qwerty",
           code + " does not use the canonical QWERTY conversion layout");
}
const stroke = generated.layouts.find(item => item.id === "zh_stroke");
assert(stroke.rows.flat().filter(key => key.kind === "character").map(key => key.output).join("")
       === "hspnz?!", "Chinese stroke keys lost their RIME key codes");
assert(stroke.rows.flat().filter(key => key.kind === "spacer").length === 4,
       "stroke placeholders must not turn into extra space keys");
const letters = { Generated: generated, Catalogue: catalogue };
vm.runInNewContext(fs.readFileSync(path.join(root, "layouts/FutoLetterLayouts.js"), "utf8")
    .replace(/^\.pragma library\s*/m, "").replace(/^\.import .*$/gm, ""), letters);
const strokeIndex = letters.layouts.findIndex(item => item.id === "zh_stroke");
const pinyinIndex = letters.layouts.findIndex(item => item.id === "zh_qwerty");
assert(letters.secondarySymbolForLayout(strokeIndex, 0, 0, false) === ""
       && letters.secondarySymbolForLayout(strokeIndex, 1, 0, false) === "",
       "Chinese stroke keys must not gain invented Latin shortcuts");
assert(letters.secondarySymbolForLayout(pinyinIndex, 1, 0, false) === "？",
       "Pinyin punctuation hints must use FUTO's explicit alternatives");
assert(letters.secondarySymbolForLayout(pinyinIndex, 0, 0, true) === "~",
       "a visible number row must not duplicate the digit in the Pinyin hint");
const flick = generated.layouts.find(item => item.id === "flick");
assert(flick.imeHint === "12key" && flick.numberRowMode === "AlwaysDisabled"
       && flick.rows.length === 4 && flick.rows.every(row => row.length === 5),
       "Japanese flick must retain all four canonical rows without a number row");
assert(flick.rows[0][2].choices.down.caption === "こ"
       && flick.rows[0][2].choices.down.output === "|",
       "the literal pipe Mozc flick code was incorrectly split");
assert(flick.rows[3][1].choices.left.output === "["
       && flick.rows[3][1].choices.right.output === "]",
       "kana voiced/semi-voiced flick codes changed");
assert(Array.from(generated.languageLayoutOptions.JA).join(",") === "japanese_qwerty,flick",
       "Japanese must offer both romaji and kana flick");
const flickIndex = letters.layouts.findIndex(item => item.id === "flick");
assert(!letters.numberRowAllowed(flickIndex) && letters.flickRows(flickIndex).length === 4,
       "flick must not grow an extra fifth number row");
assert(letters.letter(flickIndex, 0, 1) === "あ",
       "the kana layout preview must show kana rather than blank keys or engine codes");
assert(Array.from(generated.languageLayoutOptions.ZH).join(",") === "zh_qwerty,zh_stroke"
       && Array.from(generated.languageLayoutOptions.ZH_HANT).join(",") === "zh_qwerty,zh_stroke",
       "both Chinese scripts must offer their non-QWERTY stroke layout");
process.stdout.write("Generated layout validation passed: 143 languages, 102 layouts.\n");
