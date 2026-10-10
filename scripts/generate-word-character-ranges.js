#!/usr/bin/env node
"use strict";
const fs = require("fs"), path = require("path");
const target = path.resolve(__dirname, "../qml/FutoInputHandler.qml");
let source = fs.readFileSync(target, "utf8");
function ranges(pattern) {
    const result = [];
    const escape = value => "\\u" + value.toString(16).padStart(4, "0");
    for (let code = 0; code <= 0xffff; code++) {
        if (!pattern.test(String.fromCharCode(code)))
            continue;
        const start = code;
        while (code < 0xffff && pattern.test(String.fromCharCode(code + 1))) code++;
        result.push(escape(start) + (code > start ? "-" + escape(code) : ""));
    }
    return result.join("");
}
for (const [name, pattern] of [["LETTER", /\p{Letter}/u], ["MARK", /\p{Mark}/u]]) {
    const expression = new RegExp("(// BEGIN GENERATED " + name + " RANGES\\n)[\\s\\S]*?(\\n[ \\t]*// END GENERATED " + name + " RANGES)");
    if (!expression.test(source)) throw new Error("Missing generated Unicode region: " + name);
    source = source.replace(expression, (_, begin, end) => begin + "\t\treturn /^[" + ranges(pattern) + "]$/.test(character)" + end);
}
if (process.argv.includes("--check")) {
    if (source !== fs.readFileSync(target, "utf8"))
        throw new Error("Unicode ranges are stale; run scripts/generate-word-character-ranges.js");
} else {
    fs.writeFileSync(target, source);
}
console.log("Unicode word-character ranges verified.");
