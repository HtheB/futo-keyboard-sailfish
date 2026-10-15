#!/usr/bin/env node
"use strict";
const assert = require("assert"), fs = require("fs"), path = require("path"), vm = require("vm");
const prompt = fs.readFileSync(path.join(__dirname, "../qml/FutoSavedLoginPrompt.qml"), "utf8");
const gesture = {};
vm.runInNewContext(prompt.slice(prompt.indexOf("function isHorizontalSwipe("),
    prompt.indexOf("function resetGesture(")), gesture);
assert.strictEqual(gesture.isHorizontalSwipe(30, 5, 20), true);
assert.strictEqual(gesture.isHorizontalSwipe(-30, 5, 20), true);
assert.strictEqual(gesture.isHorizontalSwipe(10, 0, 20), false);
assert.strictEqual(gesture.isHorizontalSwipe(30, 50, 20), false);
for (const sign of [-1, 1]) {
    assert.strictEqual(gesture.dismissalReached(sign * 219, 1000, 20), false);
    assert.strictEqual(gesture.dismissalReached(sign * 220, 1000, 20), true);
    assert.strictEqual(gesture.dismissalReached(sign * 39, 120, 20), false);
    assert.strictEqual(gesture.dismissalReached(sign * 40, 120, 20), true);
}
assert(prompt.includes('property: "swipeOffset"') && prompt.includes("Easing.OutCubic"));
assert(prompt.includes("prompt.pressedContextKey === prompt.contextKey"));
assert(prompt.includes("onContextKeyChanged: resetGesture()"));
assert(prompt.includes("onCanceled: prompt.resetGesture()"));
assert(prompt.includes("? (prompt.swipeOffset < 0 ? -prompt.width : prompt.width) : 0"));
const handler = fs.readFileSync(path.join(__dirname, "../qml/FutoInputHandler.qml"), "utf8");
const dismiss = handler.slice(handler.indexOf("function dismissSavedLoginOffer("),
    handler.indexOf("function refreshAndroidKeyboardAutofill("));
const state = {passwordVaultBusy: false, passwordVaultPanelOpen: false,
    credentialAutofillStage: 0, credentialOfferDismissedForFocus: false,
    passwordVaultToken: "unchanged", accountCount: 3};
vm.runInNewContext(dismiss, state);
state.dismissSavedLoginOffer();
assert.strictEqual(state.credentialOfferDismissedForFocus, true);
assert.strictEqual(state.passwordVaultToken, "unchanged");
assert.strictEqual(state.accountCount, 3);
for (const key of ["passwordVaultBusy", "passwordVaultPanelOpen", "credentialAutofillStage"]) {
    state.credentialOfferDismissedForFocus = false;
    state[key] = key === "credentialAutofillStage" ? 1 : true;
    state.dismissSavedLoginOffer();
    assert.strictEqual(state.credentialOfferDismissedForFocus, false);
    state[key] = key === "credentialAutofillStage" ? 0 : false;
}
assert(!dismiss.includes("typedCall") && !dismiss.includes("openPasswordVault"));
assert(handler.includes("onDismissRequested: futoHandler.dismissSavedLoginOffer()"));
console.log("Saved-login swipe dismissal works in both directions, without changing vault data or ongoing autofill.");
