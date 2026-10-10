#!/usr/bin/env node
"use strict";
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");
const source = fs.readFileSync(path.join(__dirname, "../hardware/compose/browser-credential.js"), "utf8");

function fixture(options = {}) {
    const events = [];
    class Input {
        constructor(type, name) {
            this.type = type;
            this.name = this.id = name;
            this.tagName = "INPUT";
            this.autocomplete = name === "username" ? "username" : "current-password";
            this.isConnected = true;
            this._value = "";
        }
        get value() { return this._value; }
        set value(value) { this._value = value; }
        getClientRects() { return this.hidden ? [] : [{}]; }
        dispatchEvent(event) {
            events.push([this.name, event.type]);
            if (this.onEvent) this.onEvent(event);
        }
        focus() { win.document.activeElement = this; }
        blur() { win.document.activeElement = win.document.body; }
    }
    const username = options.passwordOnly ? null : new Input("email", "username");
    const password = new Input("password", "password");
    const fields = username ? [username, password] : [password];
    const form = {
        querySelectorAll: () => fields,
        querySelector: () => password
    };
    for (const field of fields) field.form = form;
    const win = {
        location: { protocol: "https:", host: "example.test" },
        document: { body: {}, activeElement: username || password },
        HTMLInputElement: Input,
        Event: class Event { constructor(type) { this.type = type; } }
    };
    const context = vm.createContext({ window: win });
    for (const field of fields) field.ownerDocument = win.document;
    const adapter = vm.runInContext(source, context);
    // QtMozEmbed treats scripts as Function bodies, rather than eval strings.
    assert.strictEqual(JSON.parse(vm.runInContext("(function() { return (" + source
        + "\n)({operation:'context'}) })()", context)).available, true);
    return { win, username, password, fields, form, events,
        request: request => JSON.parse(adapter(request)) };
}

let f = fixture();
f.username.value = "old user";
f.password.value = "old secret";
let context = f.request({ operation: "context" });
assert.strictEqual(context.available, true);
assert.strictEqual(context.username, "old user");
assert(!JSON.stringify(context).includes("old secret"));
const fill = { operation: "fill", origin: context.origin, field: context.field,
    username: "new user", secret: "new secret" };
assert.strictEqual(f.request(fill).filled, true);
assert.strictEqual(f.username.value, "new user");
assert.strictEqual(f.password.value, "new secret");
assert.strictEqual(f.win.document.activeElement, f.password);
context = f.request({ operation: "context" });
assert.strictEqual(f.request({ ...fill, field: context.field }).filled, true);
assert.strictEqual(f.username.value, "new user");
assert.strictEqual(f.password.value, "new secret");
assert(!f.events.some(event => event[1] === "submit"));
assert.strictEqual(f.request({ ...fill, origin: "https://wrong.test", secret: "must not fill" }).available, false);
assert.strictEqual(f.request({ ...fill, field: "stale", secret: "must not fill" }).available, false);
assert.strictEqual(f.password.value, "new secret");
context = f.request({ operation: "context" });
assert.strictEqual(f.request({ operation: "restore", origin: context.origin, field: context.field }).restored, true);
f.password.blur();
assert.strictEqual(f.request({ operation: "restore", origin: context.origin, field: context.field }).restored, true);
assert.strictEqual(f.win.document.activeElement, f.password);

f = fixture({ passwordOnly: true });
context = f.request({ operation: "context" });
assert.strictEqual(f.request({ ...fill, field: context.field, username: "" }).filled, true);
assert.strictEqual(f.request({ ...fill, field: context.field, username: "saved username" }).filled, true);
assert.strictEqual(f.password.value, "new secret");
f.password.autocomplete = "new-password";
assert.strictEqual(f.request({ operation: "context" }).available, false);

f = fixture();
f.password.type = "text";
f.password.value = "revealed secret";
f.win.document.activeElement = f.password;
context = f.request({ operation: "context" });
assert.strictEqual(context.available, true);
assert.strictEqual(context.password, true);
assert.strictEqual(context.revealed, true);
assert.strictEqual(context.username, "");
assert(!JSON.stringify(context).includes("revealed secret"));
assert.strictEqual(f.request({ ...fill, field: context.field }).filled, true);
assert.strictEqual(f.username.value, "new user");
assert.strictEqual(f.password.value, "new secret");

f.password.autocomplete = "";
f.password.getAttribute = name => name === "autocomplete" ? "section-login current-password" : null;
context = f.request({ operation: "context" });
assert.strictEqual(context.available, true);
assert.strictEqual(context.password, true);
assert.strictEqual(context.username, "new user");

f = fixture();
f.username.autocomplete = "one-time-code";
f.username.name = "otp";
assert.strictEqual(f.request({ operation: "context" }).available, false);
f = fixture();
f.username.readOnly = true;
assert.strictEqual(f.request({ operation: "context" }).available, false);
f = fixture();
f.password.hidden = true;
assert.strictEqual(f.request({ operation: "context" }).available, false);

f = fixture();
context = f.request({ operation: "context" });
f.username.onEvent = () => { f.win.location.host = "changed.test"; };
assert.strictEqual(f.request({ ...fill, field: context.field }).available, false);
assert.strictEqual(f.password.value, "");
f = fixture();
context = f.request({ operation: "context" });
f.username.onEvent = () => { f.password.isConnected = false; };
assert.strictEqual(f.request({ ...fill, field: context.field }).available, false);
assert.strictEqual(f.password.value, "");

f = fixture();
f.win.document.activeElement = { tagName: "IFRAME", contentWindow: {
    location: { protocol: "https:", host: "foreign.test" }
} };
assert.strictEqual(f.request({ operation: "context" }).available, false);
console.log("Browser credentials: replacement, repeat fill, origin, field, navigation and password-only checks passed");
