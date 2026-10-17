#!/usr/bin/env node
"use strict";
const assert = require("assert"), fs = require("fs"), path = require("path"), vm = require("vm");
const root = path.resolve(__dirname, "..");
const Haptics = {};
vm.runInNewContext(fs.readFileSync(path.join(root, "qml/FutoHapticFeedback.js"), "utf8")
    .replace(/^\.pragma.*$/gm, ""), Haptics);
for (const [mode, duration] of [[0, 0], [1, 30], [2, 0], [3, 65]]) {
    assert.equal(Haptics.mode(mode), mode);
    assert.equal(Haptics.pulseDuration(mode), duration);
    assert.equal(Haptics.platformEffect(mode, 2, 65535), mode === 2 ? 2 : 65535);
    assert.equal(Haptics.allowed(mode, 1), mode !== 0);
    assert.equal(Haptics.allowed(mode, 0), false);
}
for (const invalid of [-1, 4, 100, NaN, Infinity, undefined, "invalid", 1.5]) {
    assert.equal(Haptics.mode(invalid), 2, "Malformed preferences must retain normal feedback");
    assert.equal(Haptics.platformEffect(invalid, 2, 65535), 2);
}
const handler = fs.readFileSync(path.join(root, "qml/FutoInputHandler.qml"), "utf8");
const settings = fs.readFileSync(path.join(root, "qml/FutoFeedbackPage.qml"), "utf8");
for (const source of [handler, settings]) {
    assert(source.includes('import "FutoHapticFeedback.js" as Haptics'));
    assert(source.includes("property int keyVibrationMode: 2"));
    assert(!/touchscreenVibrationLevel\s*=(?!=)/.test(source), "FUTO must not change phone-wide vibration settings");
}
assert(settings.includes('label: qsTr("Vibration feedback")'));
for (const [mode, label] of ["Off", "Light", "Normal", "Strong"].entries())
    assert(settings.includes('MenuItem { text: qsTr("' + label + '"); onClicked: page.setVibrationMode(' + mode + ') }'),
        "Selecting the same level must also replay its preview");
assert(settings.includes("vibrationPreview.play()") && settings.includes("Haptics.allowed("));
assert(settings.includes("onKeyVibrationModeChanged:"), "The selector must reflect external preference updates");
assert(handler.includes("platformHapticsState, active,") && handler.includes("Component.onDestruction: Haptics.updatePlatformEffect("),
    "Platform effects must be saved and explicitly restored on deactivation/destruction");
const target = {effect: 77}, state = {applied: false, original: 0};
Haptics.updatePlatformEffect(target, state, false, true, false, 2, 65535);
assert.equal(target.effect, 77);
for (const selected of [3, 2, 4]) {
    Haptics.updatePlatformEffect(target, state, true, true, false, selected, 65535);
    assert.equal(target.effect, selected); assert.equal(state.original, 77);
    Haptics.updatePlatformEffect(target, state, true, true, true, selected, 65535);
    assert.equal(target.effect, 65535);
}
Haptics.updatePlatformEffect(target, state, true, false, false, 4, 65535);
assert.equal(target.effect, 65535);
Haptics.updatePlatformEffect(target, state, false, false, false, 4, 65535);
assert.equal(target.effect, 77); assert.equal(state.applied, false);
target.effect = 88;
Haptics.updatePlatformEffect(target, state, false, true, false, 2, 65535);
assert.equal(target.effect, 88, "Inactive FUTO must not overwrite another keyboard's effect");
assert(handler.includes("onPressEffectSilencedChanged: synchronizePlatformHaptics()") && handler.includes("pressEffectSilenced = false"));
assert(handler.includes("if (!keyboardSettings.swipeVibrationEnabled)"));
const pulse = fs.readFileSync(path.join(root, "qml/FutoKeyHaptics.qml"), "utf8");
assert(pulse.includes('import Nemo.Ngf 1.0') && pulse.includes('value: "on=" + Haptics.pulseDuration(feedback.mode) + ",pause=160"'));
assert(pulse.includes('NgfProperty { name: "haptic.effect"; value: "short" }'));
assert(!pulse.includes('NgfProperty { name: "haptic.duration"'), "The QML NGF API cannot encode the unsigned duration expected by native backends");
assert(pulse.includes("onTriggered: controlledPulse.stop()"), "Short pulses must explicitly stop minimum-duration native motors");
assert(pulse.includes("normalPulse.play()"), "Normal must retain device-tuned Sailfish feedback");
assert(pulse.includes("onEnabledChanged: if (!enabled) stop()") && pulse.includes("onModeChanged: stop()"));
function extractPulse(name, signal = false) {
    const match = new RegExp(signal ? name + ": \\{" : "function " + name + "\\(").exec(pulse);
    assert(match);
    for (let end = pulse.indexOf("}", match.index); end >= 0; end = pulse.indexOf("}", end + 1)) {
        let block = pulse.slice(match.index, end + 1);
        if (signal) block = block.replace(name + ": {", "function " + name + "() {");
        try { new vm.Script(block); return block; } catch (error) { if (!(error instanceof SyntaxError)) throw error; }
    }
    throw Error("Missing pulse handler: " + name);
}
function pulseFixture(autoAck = false) {
    const calls = [];
    let now = 1000;
    const c = {mode: 1, enabled: true, pulsePending: false, repeatRequested: false, lastRequestAt: 0, Haptics,
        Date: {now: () => now},
        NonGraphicalFeedback: {Stopped: 0, Failed: 1, Playing: 2},
        pulseStop: {running: false, restart() { this.running = true; this.deadline = now + Haptics.pulseDuration(c.mode); calls.push("timer-start"); }, stop() { this.running = false; }, fire() { this.running = false; c.controlledPulse.stop(); }},
        repeatDelay: {running: false, restart() { this.running = true; this.deadline = now + 8; }, stop() { this.running = false; }, fire() { this.running = false; c.playQueuedRepeat(); }},
        normalPulse: {play() { calls.push("normal"); }},
        controlledPulse: {status: 0, play() { calls.push("start"); if (autoAck) { this.status = 2; c.onStatusChanged(); } }, stop() { calls.push("stop"); this.status = 0; c.onStatusChanged(); }}};
    c.feedback = c;
    Object.defineProperty(c, "status", {get: () => c.controlledPulse.status});
    vm.createContext(c);
    vm.runInContext(extractPulse("play") + extractPulse("stop") + extractPulse("playQueuedRepeat") + extractPulse("onStatusChanged", true), c);
    return {c, calls, setNow(value) { now = value; }, advance(delta) {
        const target = now + delta;
        for (;;) {
            const due = [c.pulseStop, c.repeatDelay].filter(t => t.running && t.deadline <= target).sort((a, b) => a.deadline - b.deadline)[0];
            if (!due) break;
            now = due.deadline; due.fire();
        }
        now = target;
    }, acknowledge(status = 2) { c.controlledPulse.status = status; c.onStatusChanged(); }};
}
{
    const {c, calls, acknowledge} = pulseFixture();
    c.play();
    for (let i = 0; i < 20; ++i) c.play();
    assert.deepStrictEqual(calls, ["start"], "Fast keys must not cancel and recreate a still-queued pulse");
    assert.equal(c.pulseStop.running, false, "The pulse duration must not elapse before playback is acknowledged");
    acknowledge(); assert(c.pulseStop.running);
    const deadline = c.pulseStop.deadline;
    for (let i = 0; i < 20; ++i) c.play();
    acknowledge();
    assert.equal(c.pulseStop.deadline, deadline, "Overlapping keys and duplicate acknowledgements must never extend a pulse");
    assert.equal(calls.filter(s => s === "timer-start").length, 1);
    assert(c.repeatRequested);
    c.stop(); assert(!c.pulsePending && !c.pulseStop.running);
    c.play(); assert.equal(calls.filter(s => s === "start").length, 2);
    acknowledge(1); assert(!c.pulsePending && !c.pulseStop.running);
    c.play(); c.enabled = false; c.stop(); acknowledge();
    assert(!c.pulsePending && !c.pulseStop.running, "A cancelled late acknowledgement cannot start another pulse timer");
}
for (const mode of [1, 3]) {
    const {c, calls, advance} = pulseFixture(true);
    c.mode = mode; c.play();
    const end = c.pulseStop.deadline;
    for (let i = 0; i < 4; ++i) { advance(5); c.play(); }
    assert.equal(c.pulseStop.deadline, end, "Fast input must preserve the selected fixed pulse duration");
    advance(Haptics.pulseDuration(mode) - 20);
    assert(!c.pulsePending && c.repeatDelay.running, "Every repeated pulse needs a real off gap");
    assert.equal(calls.filter(s => s === "start").length, 1);
    advance(8); assert(c.pulsePending);
    assert.equal(calls.filter(s => s === "start").length, 2, "Keep one recent overlapping press, not an unbounded queue");
    advance(300); assert(!c.pulsePending && !c.repeatDelay.running);
}
{
    const {c, calls, advance, setNow} = pulseFixture(true);
    c.play(); c.play(); advance(30);
    setNow(1300); c.repeatDelay.fire();
    assert.equal(calls.filter(s => s === "start").length, 1, "A stale queued repeat cannot buzz after typing has stopped");
    c.play(); c.play(); c.enabled = false; c.stop(); advance(300);
    assert(!c.pulsePending && !c.repeatRequested && !c.repeatDelay.running);
}
{
    const {c, calls} = pulseFixture();
    c.mode = 2; c.play(); assert(calls.includes("normal"));
    c.mode = 0; c.play(); assert.equal(calls.filter(s => s === "start").length, 0);
}
assert(handler.includes("pressedKey.manualFeedbackOnPress !== true") && handler.includes("swipePath.length === 0 || keyboardSettings.swipeVibrationEnabled"),
    "Timed keyboard pulses must not duplicate manual keys or every letter crossed by a swipe");
assert(handler.includes("enabled: futoHandler.active && Haptics.allowed(mode, systemFeedback.touchscreenVibrationLevel)"));
const makefile = fs.readFileSync(path.join(root, "packaging/Makefile"), "utf8");
const spec = fs.readFileSync(path.join(root, "packaging/rpm/futo-keyboard-sailfish.spec"), "utf8");
assert(makefile.includes("qml/FutoHapticFeedback.js") && makefile.includes("\tFutoHapticFeedback.js"));
assert(makefile.includes("qml/FutoKeyHaptics.qml") && makefile.includes("\tFutoKeyHaptics.qml"));
for (const prefix of ["com/jolla/", "com/jolla/handlers/"]) {
    assert(spec.includes(prefix + "FutoHapticFeedback.js"));
    assert(spec.includes(prefix + "FutoKeyHaptics.qml"));
}
console.log("Haptic feedback passed: levels, delayed acknowledgements, fast repeats, cancellation, system mute and packaging");
