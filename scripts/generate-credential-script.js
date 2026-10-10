#!/usr/bin/env node
"use strict";
const fs = require("fs");
const path = require("path");
const source = fs.readFileSync(path.join(__dirname, "../hardware/compose/browser-credential.js"), "utf8");
if (Buffer.byteLength(source) > 32768 || !process.argv[2]) {
    throw new Error("Invalid browser credential adapter input");
}
fs.writeFileSync(process.argv[2], "/* Generated from browser-credential.js. */\n"
    + "static const char futoBrowserCredentialScript[] = " + JSON.stringify(source) + ";\n");
