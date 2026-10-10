#!/usr/bin/env node
"use strict";
const assert = require("assert");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const vm = require("vm");
const root = path.resolve(__dirname, "..");
const pins = require("../content/published-packs.json");
const manifest = require("../content/manifest.json");
const pin = pins["swipe-universal"];
function check(item) {
    for (const key of ["version", "archive", "sha256", "downloadBytes", "installedBytes"])
        assert.strictEqual(item[key], pin[key], `published swipe ${key} changed`);
    assert.strictEqual(item.url || manifest.baseUrl + item.archive, pin.url);
}
check(manifest.items.find(item => item.id === "swipe-universal"));

// Deliberately make every local archive and installed tree different. The
// generator must preserve the published contract rather than hash the rebuild.
let generated;
const fakeFs = {
    statSync: () => ({ isFile: () => true, size: 123 }),
    readFileSync: () => Buffer.from("rebuilt archive differs"),
    mkdirSync: () => {},
    writeFileSync: (_, data) => { generated = JSON.parse(data); }
};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, "generate-content-manifest.js"), "utf8"), {
    __dirname,
    process: { argv: ["node", "generator"], env: {} },
    console: { log: () => {} },
    require: name => name === "fs" ? fakeFs : name === "crypto" ? crypto
        : name === "path" ? path : name === "../content/published-packs.json" ? pins
        : (() => { throw new Error(`unexpected dependency ${name}`); })()
});
check(generated.items.find(item => item.id === "swipe-universal"));
assert.notStrictEqual(generated.items[0].sha256, pin.sha256);
console.log("Published content metadata stays pinned across rebuilds.");
