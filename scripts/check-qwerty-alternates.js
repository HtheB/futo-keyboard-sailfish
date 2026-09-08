#!/usr/bin/env node

"use strict";

// Holds the QWERTY letter keys to the arrangement they are specified to have:
// the symbol printed on the key, the alternates offered on a long press, and
// what both become once the number row puts the digits on screen already.

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const root = path.resolve(__dirname, "..");
const source = fs.readFileSync(path.join(root, "layouts", "FutoLetterLayouts.js"), "utf8")
    .replace(/^\.pragma library\s*/m, "")
    .replace(/^\.import .*$/gm, "");

const context = {
    Generated: { layouts: [], languageLayoutIds: {}, languageAlternatives: {} },
    Catalogue: { languages: [] }
};
vm.createContext(context);
vm.runInContext(source, context, { filename: "FutoLetterLayouts.js" });

const QWERTY = 0;

// letter: [printed symbol, alternates] with the number row hidden.
const expected = {
    q: ["1", "1"],
    w: ["2", "2"],
    e: ["3", "èê3ěęėëé"],
    r: ["4", "ř4"],
    t: ["5", "þț5ť"],
    y: ["6", "ý6"],
    u: ["7", "ùûů7űüú"],
    i: ["8", "ìîı8ïí"],
    o: ["9", "òôõöøō9ó"],
    p: ["0", "0"],
    a: ["@", "@ąăåäãâáà"],
    s: ["#", "ß#șšşś"],
    d: ["&", "ð&ď"],
    f: ["*", "*"],
    g: ["-", "ğ-"],
    h: ["+", "+"],
    j: ["=", "="],
    k: ["(", "("],
    l: [")", "ĺľł)"],
    z: ["_", "ź_žż"],
    x: ["€", "$¢€⃁₺¥£"],
    c: ["\"", "çč\"ć"],
    v: ["'", "'"],
    b: [":", ":"],
    n: [";", "ñň;ń"],
    m: ["/", String.fromCharCode(92) + "/%"]
};

// What the top row prints instead once the digits are on screen.
const numberRowSymbols = {
    q: "%", w: "^", e: "~", r: "|", t: "[",
    y: "]", u: "<", i: ">", o: "{", p: "}"
};

let failures = 0;

function report(letter, description, actual, wanted) {
    if (actual === wanted) {
        console.log("ok    " + (letter + " " + description).padEnd(34)
                    + JSON.stringify(actual));
        return;
    }
    failures++;
    console.log("FAIL  " + letter + " " + description + ": "
                + JSON.stringify(actual) + ", wanted " + JSON.stringify(wanted));
}

function choicesToString(choices) {
    return choices.map(choice => choice.output).join("");
}

// Walk the real rows so the printed symbol is read the way a key reads it.
for (let row = 0; row < context.rowCount(QWERTY); ++row) {
    for (let column = 0; column < context.rowLength(QWERTY, row); ++column) {
        const item = context.key(QWERTY, row, column);
        if (item.kind !== "character")
            continue;
        const letter = String(item.caption);
        const wanted = expected[letter];
        if (wanted === undefined)
            continue;

        report(letter, "prints",
               context.secondarySymbolForLayout(QWERTY, row, column, false),
               wanted[0]);
        report(letter, "offers",
               choicesToString(context.alternativeChoices(QWERTY, row, column, "", false, false)),
               wanted[1]);

        const swapped = numberRowSymbols[letter];
        if (swapped === undefined)
            continue;
        report(letter, "prints with numbers",
               context.secondarySymbolForLayout(QWERTY, row, column, true),
               swapped);
        report(letter, "offers with numbers",
               choicesToString(context.alternativeChoices(QWERTY, row, column, "", false, true)),
               wanted[1].replace(wanted[0], swapped));
    }
}

// Invariants which matter more than any single row.
for (const letter of Object.keys(expected)) {
    const [symbol, alternates] = expected[letter];
    if (alternates.indexOf(symbol) < 0) {
        failures++;
        console.log("FAIL  " + letter + ": the printed symbol is not among its alternates");
    }
    const shifted = context.qwertyAlternateSet(letter, false, true);
    if (shifted.length !== alternates.length) {
        failures++;
        console.log("FAIL  " + letter + ": shifting changed the number of alternates, "
                    + JSON.stringify(shifted));
    }
}

if (failures > 0) {
    console.log("");
    console.log(failures + " QWERTY alternate checks failed");
    process.exit(1);
}
console.log("");
console.log("QWERTY alternate checks passed");
