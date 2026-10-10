#!/usr/bin/env node
"use strict";

const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");
const root = path.resolve(__dirname, "..");
const source = fs.readFileSync(path.join(root, "qml/FutoInputHandler.qml"), "utf8");

function qmlFunction(name) {
    const start = source.indexOf("function " + name + "(");
    assert(start >= 0, "Missing function " + name);
    const next = /\n[ \t]*function \w+\(/g;
    next.lastIndex = start + 1;
    const end = next.exec(source);
    assert(end, "Missing end of function " + name);
    return source.slice(start, end.index);
}

let rows = [], updates = 0, refreshes = 0;
const context = {
    keyboardSettings: { allowSuggestionsWithSpaces: true, suggestionCount: 3, showTypedWord: true },
    activeSuggestionQuery: "ihave", correctionCandidate: "I have", correctionQuery: "ihave",
    requestSerial: 2, urlSuggestionResultsActive: false,
    predictionModel: {
        get count() { return rows.length; },
        get: index => rows[index],
        clear: () => { rows = []; },
        append: item => rows.push(item)
    },
    suggestionsUpdated: () => updates++,
    requestSuggestionsSoon: () => refreshes++
};
context.futoHandler = context;
vm.createContext(context);
for (const name of ["displayableSuggestion", "nonEmptySuggestions", "allowedWordSuggestion",
    "wordSuggestions", "refreshWordSuggestionPreference", "replacePredictionSuggestions",
    "visiblePrimaryCorrection", "correctedWordForCommit"]) {
    vm.runInContext(qmlFunction(name), context);
}

const candidates = ["I have", "can't", "со мной", "سلام دنیا", "a\u00a0lot", "two\twords",
    "two\nwords", "l’école", "فارسی\u200cنویسی", "hello"];
assert.deepStrictEqual(Array.from(context.wordSuggestions(candidates)), candidates);
assert.deepStrictEqual(Array.from(context.wordSuggestions([null, "", "  ", undefined, "word"])), ["word"]);
context.replacePredictionSuggestions(["ihave", "have"], "I have");
assert.deepStrictEqual(rows.map(item => item.text), ["ihave", "I have", "have"]);
assert.strictEqual(context.correctedWordForCommit("ihave"), "I have");

// Toggling the preference immediately removes existing phrases and invalidates replies.
context.keyboardSettings.allowSuggestionsWithSpaces = false;
context.refreshWordSuggestionPreference();
assert.deepStrictEqual(rows.map(item => item.text), ["ihave", "have"]);
assert.strictEqual(context.requestSerial, 3);
assert.strictEqual(updates, 1);
assert.strictEqual(refreshes, 1);
assert.strictEqual(context.correctedWordForCommit("ihave"), "ihave");
assert.deepStrictEqual(Array.from(context.wordSuggestions(candidates)),
    ["can't", "l’école", "فارسی\u200cنویسی", "hello"]);
// Application autofill and URL handling retain their independent list sanitization.
assert.deepStrictEqual(Array.from(context.nonEmptySuggestions(["Jane Doe", "example.test"])),
    ["Jane Doe", "example.test"]);

// Filtering happens before the visible limit, and a rejected primary is not reinserted.
const input = ["two words", "one", "three words", "two", "three", "four"];
assert.strictEqual(context.replacePredictionSuggestions(input, "new phrase"), 3);
assert.deepStrictEqual(rows.map(item => item.text), ["one", "two", "three"]);
assert(rows.every(item => item.primary === false));
assert.strictEqual(input.length, 6);
context.activeSuggestionQuery = "teh";
context.correctionQuery = "teh";
context.correctionCandidate = "the";
context.replacePredictionSuggestions(["teh", "ten"], "the");
assert.strictEqual(context.correctedWordForCommit("teh"), "the");

// A settings change must not replace a row of URL suggestions.
context.urlSuggestionResultsActive = true;
rows = [{ text: "example.test", source: "https://example.test", primary: false }];
context.refreshWordSuggestionPreference();
assert.deepStrictEqual(rows.map(item => item.text), ["example.test"]);
context.keyboardSettings.allowSuggestionsWithSpaces = true;
assert.deepStrictEqual(Array.from(context.wordSuggestions(candidates)), candidates);

// All prediction producers use the same filter, including the swipe commit candidate.
assert(qmlFunction("requestNextWords").includes("replacePredictionSuggestions(words)"));
assert(qmlFunction("requestSuggestions").includes("allowedWordSuggestion(result.correction)"));
const swipe = qmlFunction("finishSwipeGesture");
assert(swipe.includes("futoHandler.wordSuggestions(result.suggestions || [])"));
assert(swipe.indexOf("futoHandler.wordSuggestions(") < swipe.indexOf("var word = suggestions[0]"));
assert(source.includes("onAllowSuggestionsWithSpacesChanged: futoHandler.refreshWordSuggestionPreference()"));
for (const file of ["FutoInputHandler.qml", "FutoTypingPage.qml", "FutoSettingsPage.qml"]) {
    assert(fs.readFileSync(path.join(root, "qml", file), "utf8")
        .includes("property bool allowSuggestionsWithSpaces: true"));
}
assert(fs.readFileSync(path.join(root, "qml/FutoSettingsPage.qml"), "utf8")
    .includes("settings.allowSuggestionsWithSpaces = true"));
console.log("Space-containing suggestions: defaults, multilingual filtering, correction, swipe, live refresh and reset passed");
