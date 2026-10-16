#!/usr/bin/env node
"use strict";
const assert = require("assert"), fs = require("fs"), path = require("path"), vm = require("vm");
const root = path.resolve(__dirname, "..");
const source = fs.readFileSync(path.join(root, "layouts/FutoQwertyLayout.qml"), "utf8");
function qmlFunction(name) {
    const start = source.indexOf("function " + name + "(");
    const next = /\n[ \t]*function \w+\(/g;
    next.lastIndex = start + 1;
    const end = next.exec(source);
    assert(start >= 0 && end, "missing function " + name);
    return source.slice(start, end.index);
}
const context = {
    layoutSettings: {manualPredictionLanguage: "IS", automaticLanguageDetection: true, mergeSameLayoutLanguages: false},
    handler: {detectedLanguage: "EN"}, layoutVariant: 0,
    compositionHint: "", layoutConfigurationReady: true,
    languagesForLayout: () => ["EN", "IS"],
    LetterLayouts: {imeHint: (_layout, code) => ["JA", "ZH", "ZH_HANT"].includes(code) ? "qwerty" : ""},
    LanguageData: {predictionSupported: () => true}
};
context.root = context;
Object.defineProperty(context, "languagesShareActiveLayout", {get: () =>
    context.layoutSettings.automaticLanguageDetection && context.layoutSettings.mergeSameLayoutLanguages});
vm.createContext(context);
for (const name of ["layoutHasConversionLanguages", "predictionLanguagesForLayout", "selectedPredictionLanguage", "synchronizeDetectedLanguage"])
    vm.runInContext(qmlFunction(name), context);
for (const automatic of [false, true]) {
    context.layoutSettings.automaticLanguageDetection = automatic;
    for (const selected of ["EN", "IS"]) {
        context.layoutSettings.manualPredictionLanguage = selected;
        context.layoutSettings.mergeSameLayoutLanguages = false;
        assert.strictEqual(context.predictionLanguagesForLayout(0), selected);
        context.synchronizeDetectedLanguage();
        assert.strictEqual(context.handler.detectedLanguage, selected);
    }
}
context.layoutSettings.automaticLanguageDetection = true;
context.layoutSettings.mergeSameLayoutLanguages = true;
assert.strictEqual(context.predictionLanguagesForLayout(0), "EN,IS");
context.layoutSettings.mergeSameLayoutLanguages = false;
assert.strictEqual(context.predictionLanguagesForLayout(0), "IS");
// Pinyin variants share physical keys, not an interchangeable conversion state.
context.languagesForLayout = () => ["ZH", "ZH_HANT"];
context.compositionHint = "qwerty";
context.layoutSettings.mergeSameLayoutLanguages = true;
context.layoutSettings.manualPredictionLanguage = "ZH_HANT";
context.handler.detectedLanguage = "ZH";
context.synchronizeDetectedLanguage();
assert.strictEqual(context.handler.detectedLanguage, "ZH_HANT");
assert.strictEqual(context.layoutSettings.manualPredictionLanguage, "ZH_HANT");
// Defaults arriving before ConfigurationGroup finishes loading cannot overwrite
// the user's persisted selection during keyboard startup.
context.layoutConfigurationReady = false;
context.handler.detectedLanguage = "EN";
context.synchronizeDetectedLanguage();
assert.strictEqual(context.handler.detectedLanguage, "EN");
assert.strictEqual(context.layoutSettings.manualPredictionLanguage, "ZH_HANT");
assert(source.includes("onMergeSameLayoutLanguagesChanged: root.synchronizeDetectedLanguage()"));
const handler = fs.readFileSync(path.join(root, "qml/FutoInputHandler.qml"), "utf8");
assert(/onActivePredictionLanguagesChanged:\s*\{\s*futoHandler.requestSerial\+\+/.test(handler));
console.log("Language isolation: separate/combined selection, stale detection and live refresh passed");
