#!/usr/bin/env node
"use strict";

const assert = require("assert"), fs = require("fs"), path = require("path"), vm = require("vm");
const source = fs.readFileSync(path.resolve(__dirname, "../qml/FutoInputHandler.qml"), "utf8");
function binding(name) {
    const match = new RegExp("readonly property bool " + name + ":([\\s\\S]*?)(?=\\n\\s*(?:readonly property |on\\w+:|height:))").exec(source);
    assert(match, "Missing production binding: " + name);
    return "(" + match[1].trim() + "\n)";
}
const context = {
    Clipboard: {hasText: true},
    futoHandler: {conversionEnabled: false, passwordField: false,
        conversionCandidatesExpanded: false,
        ordinaryPredictionStripEnabled: true, urlHistoryStripEnabled: false,
        showUrlSuggestions: false, showApplicationSuggestions: false,
        activePredictionsAvailable: true, predictionSuggestionsAvailable: false},
    keyboardSettings: {predictionEnabled: true, clipboardHistoryEnabled: false},
    keyboardLayout: {credentialMode: false},
    conversion: {preedit: ""},
    predictionModel: {count: 0}, applicationSuggestionModel: {count: 0},
    layoutEditorVisible: false, selectionCaseVisible: false,
    cursorStatusVisible: false, modifierStatusVisible: false,
    emojiTabsVisible: false, emojiSearchVisible: false, symbolTabsVisible: false,
    controlsVisible: false, voiceStatusVisible: false, passwordVaultVisible: false
};
vm.createContext(context);
function available() {
    context.predictionContentAvailable = vm.runInContext(binding("predictionContentAvailable"), context);
    return vm.runInContext(binding("clipboardOnlyPasteVisible"), context);
}
assert.strictEqual(available(), true, "Paste must appear in an empty focused field before the first keypress");
context.futoHandler.predictionSuggestionsAvailable = true;
assert.strictEqual(available(), true, "Paste must remain fixed when initial suggestions populate the list");
context.passwordVaultVisible = true;
assert.strictEqual(available(), true, "A saved-login prompt hides the prediction header but must keep Paste available");
context.passwordVaultVisible = false;
context.futoHandler.predictionSuggestionsAvailable = false;
assert.strictEqual(available(), true, "Changing focus back to an empty field must immediately restore Paste");
context.futoHandler.ordinaryPredictionStripEnabled = false;
context.keyboardSettings.predictionEnabled = false;
assert.strictEqual(available(), true, "Disabling suggestions must not disable the live clipboard");
context.futoHandler.showUrlSuggestions = true;
context.futoHandler.urlHistoryStripEnabled = true;
assert.strictEqual(available(), true, "An empty URL list must still show Paste");
context.predictionModel.count = 1;
assert.strictEqual(available(), true, "Paste must remain fixed beside populated URL suggestions");
context.predictionModel.count = 0;
context.futoHandler.showUrlSuggestions = false;
context.futoHandler.showApplicationSuggestions = true;
context.applicationSuggestionModel.count = 2;
assert.strictEqual(available(), true, "Application autofill suggestions have no prediction Paste header");
context.futoHandler.showApplicationSuggestions = false;
context.futoHandler.conversionEnabled = true;
assert.strictEqual(available(), true, "Chinese and Japanese must allow Paste before composition begins");
context.conversion.preedit = "ni";
assert.strictEqual(available(), false, "Active conversion must not be obscured by the empty-field Paste action");
context.conversion.preedit = "";
context.futoHandler.conversionCandidatesExpanded = true;
assert.strictEqual(available(), false, "An expanded candidate grid must retain its own full width");
context.futoHandler.conversionCandidatesExpanded = false;
context.futoHandler.conversionEnabled = false;
context.keyboardSettings.clipboardHistoryEnabled = true;
assert.strictEqual(available(), true, "Live Paste must not depend on clipboard history");
context.Clipboard.hasText = false;
assert.strictEqual(available(), false, "Clearing the live clipboard must hide Paste immediately");
context.Clipboard.hasText = true;
for (const name of ["cursorStatusVisible", "modifierStatusVisible", "emojiTabsVisible", "emojiSearchVisible",
    "symbolTabsVisible", "controlsVisible", "voiceStatusVisible", "selectionCaseVisible"]) {
    context[name] = true;
    assert.strictEqual(available(), false, "Paste must not overlap " + name);
    context[name] = false;
}
context.futoHandler.passwordField = true;
assert.strictEqual(available(), false, "Password fields use the separate password Paste action");
assert.strictEqual(vm.runInContext(binding("passwordClipboardPasteVisible"), context), true);
assert(source.includes("anchors.leftMargin: passwordClipboardPasteButton.width"), "Standalone Paste must have reserved space");
assert(source.includes("showClipboardPaste: false"), "The shared strip must disable the scrolling Paste header");
const horizontal = fs.readFileSync(path.resolve(__dirname, "../qml/FutoHorizontalPredictionListView.qml"), "utf8");
assert(horizontal.includes("visible: view.showClipboardPaste && Clipboard.hasText"), "Scrolling Paste must be explicitly suppressible");
console.log("Live clipboard Paste appears before typing, follows focus/list changes, and respects alternate strip views");
