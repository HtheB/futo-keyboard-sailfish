#!/usr/bin/env node
"use strict";
const fs = require("fs"), path = require("path"), vm = require("vm"), assert = require("assert");
const source = fs.readFileSync(path.resolve(__dirname, "../qml/FutoInputHandler.qml"), "utf8");
const start = source.indexOf("    function isLetterCharacter("), end = source.indexOf("    function insertWordCharacter(", start);
for (const [name, next] of [["swipeKeyAllowed", "swipePointForKey"], ["collectSwipeGeometry", "swipeGeometry"]]) {
    const block = source.slice(source.indexOf("function " + name + "("), source.indexOf("function " + next + "("));
    assert(block.includes("isCombiningCharacter(caption)"), name + " excludes combining-mark keys");
}
for (const KeyboardSupport of [{}, {isLetter: text => /^\p{Letter}$/u.test(text)}]) {
    const context = {KeyboardSupport};
    vm.runInNewContext(source.slice(start, end), context);
    for (let code = 0; code < 0x10000; code++) {
        const character = String.fromCharCode(code);
        assert.strictEqual(context.isLetterCharacter(character), /^\p{Letter}$/u.test(character), "letter U+" + code.toString(16));
        const word = /^[\p{Letter}\p{Mark}]$/u.test(character) || "'-’\u200c".includes(character);
        assert.strictEqual(context.isInputCharacter(character), word, "word character U+" + code.toString(16));
    }
    for (const word of ["að", "বাংলা", "हिन्दी", "ภาษา", "ខ្មែរ", "ආයුබෝවන්", "مرحبا", "می‌کنم"])
        assert(context.isInputCharacter(word), "word rejected: " + word);
    for (const text of ["", "hello world", "1", "!", ",", "؟"])
        assert(!context.isInputCharacter(text), "non-word text accepted: " + text);
}
console.log("All BMP letters/marks and multilingual word queries work on old and new Sailfish APIs.");
