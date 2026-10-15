#!/usr/bin/env node
"use strict";
const assert = require("assert"), fs = require("fs"), vm = require("vm"), path = require("path");
const context = {};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, "../qml/FutoCompositionSession.js"), "utf8")
    .replace(/^\.pragma library\s*/m, ""), context);
function setup() {
    const calls = [], updates = [], failures = [];
    const session = new context.Session((method, args, success, failure) =>
        calls.push({method, args: Array.from(args, arg => arg.value), success, failure}),
        (state, request) => updates.push({state, request}), () => failures.push(true));
    function reply(call, token = "session-a", revision = 0, candidates = []) {
        call.success(JSON.stringify({session: token, revision, consumed: true,
            commit: "", preedit: "reading", cursor: 0, candidates, hasMore: false}));
    }
    return {session, calls, updates, failures, reply};
}
{
    const t = setup();
    t.session.begin("JA", "qwerty");
    assert.deepStrictEqual(t.calls[0].args, ["JA", "qwerty", true]);
    t.session.enqueue("text", "n"); t.session.enqueue("text", "i");
    assert.strictEqual(t.calls.length, 1, "input must wait for startup");
    t.reply(t.calls[0]);
    assert.deepStrictEqual(t.calls[1].args, ["session-a", 0, "text", "n"]);
    assert.strictEqual(t.calls.length, 2);
    t.reply(t.calls[1], "session-a", 1, [{id: -17, text: "日本"}]);
    assert.deepStrictEqual(t.calls[2].args, ["session-a", 1, "text", "i"]);
    assert.strictEqual(t.session.select(-17, 1), false, "do not select while input is pending");
    t.reply(t.calls[2], "session-a", 2, [{id: -17, text: "日本"}]);
    assert.strictEqual(t.session.select(-17, 1), false, "stale revision");
    assert.strictEqual(t.session.select(0, 2), false, "unknown candidate ID");
    assert.strictEqual(t.session.select(-17, 2), true);
    assert.deepStrictEqual(t.calls[3].args, ["session-a", 2, "select", "-17"]);
    t.session.invalidate(); t.reply(t.calls[3], "session-a", 3);
    assert.strictEqual(t.updates.length, 3, "stale selection must not enter the next field");
    assert.strictEqual(t.session.token, "");
}
{
    const t = setup(); t.session.begin("ZH", "qwerty");
    t.reply(t.calls[0], "session-a", 0, [{id: 0, text: "你好"}]);
    assert.strictEqual(t.session.select(0, 0), true);
    assert.strictEqual(t.calls[1].args[3], "0", "candidate zero is an actual ID");
}
{
    const t = setup();
    t.session.begin("ZH", "qwerty");
    t.session.enqueue("text", "n");
    const old = t.calls[0];
    t.session.invalidate();
    t.session.begin("ZH_HANT", "stroke");
    t.reply(old, "old-token");
    assert.strictEqual(t.updates.length, 0, "ignore old editor startup");
    assert.deepStrictEqual(t.calls[2].args, ["old-token"]);
    assert.strictEqual(t.calls[2].method, "EndComposition");
    t.reply(t.calls[1], "new-token");
    assert.strictEqual(t.session.token, "new-token");
    assert.strictEqual(t.session.queue.length, 0, "old keys must not follow new focus");
    old.failure();
    assert.strictEqual(t.failures.length, 0, "old failure must not stop the new editor");
}
{
    const t = setup();
    t.session.begin("JA", "qwerty");
    t.calls[0].success("not JSON");
    assert.strictEqual(t.failures.length, 1);
    assert.strictEqual(t.session.token, "");
    assert.strictEqual(t.session.enqueue("text", "discarded"), false);
}
{
    const t = setup();
    t.session.begin("JA", "qwerty"); t.reply(t.calls[0]);
    let switched = false;
    t.session.enqueue("commit", "", () => { switched = true; });
    assert.strictEqual(switched, false, "finish conversion before changing input mode");
    t.reply(t.calls[1], "session-a", 1);
    assert.strictEqual(switched, true);
}
function qmlFunction(file, name) {
    const source = fs.readFileSync(path.join(__dirname, "..", file), "utf8");
    const start = source.indexOf("function " + name + "(");
    assert(start >= 0, "missing production function " + name);
    for (let end = source.indexOf("}", start); end >= 0; end = source.indexOf("}", end + 1)) {
        const block = source.slice(start, end + 1);
        try { new vm.Script(block); return block; } catch (error) {
            if (!(error instanceof SyntaxError)) throw error;
        }
    }
    throw new Error("missing function end " + name);
}
{
    const calls = [];
    const c = {conversion: {language: "JA"}, Qt: {Key_Space: 32}, Maliit: {KeyClick: 0},
        MInputMethodQuick: {sendCommit(value) { calls.push(["commit", value]); }, sendPreedit() {},
            sendKey(key, modifiers, text) { calls.push(["key", key, text]); }}};
    vm.createContext(c);
    vm.runInContext(qmlFunction("qml/FutoInputHandler.qml", "applyConversionResult"), c);
    c.applyConversionResult({preedit: "", commit: "", consumed: false}, {operation: "key", value: "32"});
    assert.deepStrictEqual(calls, [["key", 32, " "]], "half-width Space reaches the editor exactly once");
    calls.length = 0;
    c.applyConversionResult({preedit: "", commit: "　", consumed: true}, {operation: "key", value: "32"});
    assert.deepStrictEqual(calls, [["commit", "　"]], "full-width Space does not also insert a narrow Space");
}
{
    const c = {enabled: true, session: null, toggleTimer: {stop() {}}};
    vm.createContext(c);
    vm.runInContext(qmlFunction("qml/FutoCompositionController.qml", "finish"), c);
    let completed = 0;
    assert.strictEqual(c.finish(() => { completed++; }), true);
    assert.strictEqual(completed, 1, "switching an empty editor must not start an engine");
    let pending;
    c.session = {language: "JA", token: "session-a", starting: false,
        enqueue(operation, value, after) {
            assert.strictEqual(operation, "commit");
            assert.strictEqual(value, "");
            pending = after; return true;
        }};
    c.finish(() => { completed++; });
    assert.strictEqual(completed, 1, "finish the current conversion before switching");
    pending(); assert.strictEqual(completed, 2);
    c.enabled = false;
    c.finish(() => { completed++; });
    assert.strictEqual(completed, 3, "ordinary language switches must remain synchronous");
}
{
    const source = fs.readFileSync(path.join(__dirname, "../qml/FutoInputHandler.qml"), "utf8");
    const gestureShield = source.slice(source.indexOf("// When there is nothing to scroll or tap,"),
        source.indexOf("preventStealing: true", source.indexOf("// When there is nothing to scroll or tap,")));
    assert(gestureShield.includes("&& !topStrip.conversionVisible"),
        "the empty-strip touch shield must not intercept conversion candidates");
    assert(qmlFunction("qml/FutoInputHandler.qml", "reset").includes("conversion.clear()"),
        "external editor resets must discard the native conversion session");
}
process.stdout.write("Conversion session validation passed: request order, focus isolation, opaque IDs and mode changes.\n");

{
    const t = setup();
    t.session.begin("ZH", "qwerty", false, {pinyinScheme: "FlyPY"});
    assert.strictEqual(t.calls[0].method, "StartCompositionWithOptions");
    assert.deepStrictEqual(t.calls[0].args, ["ZH", "qwerty", false, '{"pinyinScheme":"FlyPY"}']);
    t.reply(t.calls[0]);
    t.session.begin("ZH", "qwerty", true, {pinyinScheme: "Natural"});
    assert.strictEqual(t.calls[1].method, "EndComposition");
    assert.strictEqual(t.calls[2].args[2], true);
}
{
    const t = setup();
    t.session.begin("JA", "12key", false, {flickOnly: false}); t.reply(t.calls[0]);
    t.session.begin("JA", "12key", true, {flickOnly: false});
    assert.strictEqual(t.calls[1].method, "EndComposition", "entering Incognito must discard learning even with the same options");
    assert.strictEqual(t.calls[2].args[2], true);
}

{
    const t = setup();
    t.session.begin("JA", "qwerty");
    t.reply(t.calls[0]);
    t.session.enqueue("text", "n");
    const oldReply = t.calls[1];
    t.session.begin("JA", "12key");
    assert.strictEqual(t.calls[2].method, "EndComposition");
    assert.deepStrictEqual(t.calls[3].args, ["JA", "12key", true]);
    const count = t.updates.length;
    t.reply(oldReply);
    assert.strictEqual(t.updates.length, count, "old romaji must not enter the new kana-flick editor");
}
