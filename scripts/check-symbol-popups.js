#!/usr/bin/env node

"use strict";

// Checks the long-press popups of the symbol keys against the arrangement the
// keyboard is specified to use, reading the implementation itself rather than
// a copy of it. Each entry is [key, highlighted, popup in display order].

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const source = fs.readFileSync(
    path.resolve(__dirname, "..", "layouts", "FutoCharacterKey.qml"), "utf8");

function extract(name, endMarker) {
    const start = source.indexOf("    function " + name + "(base) {");
    const end = source.indexOf(endMarker);
    if (start < 0 || end < 0 || end < start)
        throw new Error("could not find " + name + " in FutoCharacterKey.qml");
    return source.substring(start, end).replace("    function ", "function ");
}

const context = { keyboard: { layout: {} } };
vm.createContext(context);
vm.runInContext(extract("symbolPopupChoices", "    function symbolPopupDefault"),
                context, { filename: "FutoCharacterKey.qml" });
vm.runInContext(extract("symbolPopupDefault", "    function popupChoices"),
                context, { filename: "FutoCharacterKey.qml" });

const expected = [
    ["1", "¹", "¹⅛¼⅓½"],
    ["2", "²", "⅔²"],
    ["3", "³", "¾³⅜"],
    ["4", "⁴", "⁴"],
    ["5", "ⁿ", "⅝ⁿ"],
    ["7", "⅞", "⅞"],
    ["€", "$", "£¥$⃁₺¢"],
    ["-", "—", "¯—–"],
    ["(", "<", "{<["],
    [")", ">", "}>]"],
    ["=", "≠", "≈≠"],
    ["%", "‰", "‰"],
    ["\"", "“", "„“«»”"],
    ["*", "×", "×"],
    ["'", "`", "ʼ‹‡`†›"],
    [":", ";", ";"],
    ["/", "\\", "÷\\"],
    ["!", "¡", "¡"],
    ["?", "¿", "¿"],
    ["+", "±", "±"],
    [".", "…", "•…"]
];

let failures = 0;

for (const [key, highlighted, popup] of expected) {
    const actualPopup = context.symbolPopupChoices(key);
    const actualHighlight = context.symbolPopupDefault(key);
    const problems = [];
    if (actualPopup !== popup)
        problems.push("popup " + JSON.stringify(actualPopup)
                      + " wanted " + JSON.stringify(popup));
    if (actualHighlight !== highlighted)
        problems.push("highlight " + JSON.stringify(actualHighlight)
                      + " wanted " + JSON.stringify(highlighted));
    // The highlighted entry has to be one the popup actually offers, or the
    // key would commit a character the row never shows.
    if (actualPopup.indexOf(actualHighlight) < 0)
        problems.push("highlighted " + JSON.stringify(actualHighlight)
                      + " is absent from the popup");
    if (problems.length > 0) {
        failures++;
        console.log("FAIL  " + JSON.stringify(key) + "  " + problems.join("; "));
    } else {
        console.log("ok    " + JSON.stringify(key).padEnd(6)
                    + "highlights " + JSON.stringify(highlighted).padEnd(5)
                    + " in " + JSON.stringify(popup));
    }
}

// Keys deliberately left alone keep having nothing to offer.
for (const key of ["6", "8", "9", "0", "@", "#", "&", "_"]) {
    if (context.symbolPopupChoices(key) !== "") {
        failures++;
        console.log("FAIL  " + JSON.stringify(key) + " gained a popup it should not have");
    }
}

if (failures > 0) {
    console.log("");
    console.log(failures + " symbol popup checks failed");
    process.exit(1);
}
console.log("");
console.log("Symbol popup checks passed");
