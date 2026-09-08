#!/usr/bin/env node

"use strict";

// Exercises the decision which places a space after a punctuation mark, using
// the implementation as it stands in the input handler rather than a copy.

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const source = fs.readFileSync(
    path.resolve(__dirname, "..", "qml", "FutoInputHandler.qml"), "utf8");

const start = source.indexOf("    readonly property var punctuationAddressSchemes: [");
const end = source.indexOf("    function smartPunctuationField() {");
if (start < 0 || end < 0 || end < start)
    throw new Error("the punctuation spacing helpers were not found");

const extracted = source.substring(start, end)
    .replace("readonly property var punctuationAddressSchemes: [",
             "var punctuationAddressSchemes = [");

const context = {
    keyboardSettings: { spaceAfterPunctuationEnabled: true },
    preedit: "",
    before: "",
    plainField: true,
    contextBeforeCursor: function() { return context.before; },
    smartPunctuationField: function() { return context.plainField; }
};
vm.createContext(context);
vm.runInContext(extracted, context, { filename: "FutoInputHandler.qml" });

let failures = 0;

// "typed" is everything before the mark; "mark" is the key being pressed.
function check(description, typed, mark, expected, options) {
    options = options || {};
    // An Android editor already carries the preedit inside surroundingText;
    // a native one does not, so it is removed from the text before the cursor.
    context.preedit = options.preedit !== undefined ? options.preedit : "";
    context.before = options.androidEditor
            ? typed
            : typed.substring(0, typed.length - context.preedit.length);
    context.plainField = options.plainField !== false;
    context.keyboardSettings.spaceAfterPunctuationEnabled =
        options.enabled !== false;

    const actual = context.spaceAfterPunctuationAllowed(mark);
    const shown = JSON.stringify(typed + mark);
    if (actual !== expected) {
        failures++;
        console.log("FAIL  " + description + ": " + shown + " a space was "
                    + (actual ? "added" : "withheld") + ", wanted the opposite");
    } else {
        console.log("ok    " + description.padEnd(32) + shown.padEnd(24)
                    + (actual ? "space added" : "left alone"));
    }
}

// The reported problem: punctuation runs into the following word.
check("comma", "Hello", ",", true);
check("question mark", "doing", "?", true);
check("period", "Hi", ".", true);
check("colon after an ordinary word", "Note", ":", true);
check("semicolon", "one", ";", true);

// The colon which starts an address.
check("http", "http", ":", false);
check("https", "https", ":", false);
check("ftp", "ftp", ":", false);
check("ftps", "ftps", ":", false);
check("sftp", "sftp", ":", false);
check("mailto", "mailto", ":", false);
check("scheme is case insensitive", "HTTPS", ":", false);
check("scheme with a period after it", "http", ".", true);
check("scheme later in the line", "Open https", ":", false);

// The dot which starts a www address.
check("www", "www", ".", false);
check("www is case insensitive", "WWW", ".", false);
check("second dot of a www address", "www.example", ".", false);
check("www with a comma after it", "www", ",", true);
check("a word ending in www", "shwww", ".", true);

// Addresses which are already recognisable.
check("full address", "https://example", ".", false);
check("address later in the line", "Open https://example", ".", false);
check("email", "user@example", ".", false);
check("email later in the line", "Write to user@example", ".", false);
check("word after an address", "https://example.com now", ",", true);

// Native editors keep the preedit out of surroundingText, Android editors put
// it in. Both conventions must reach the same answer.
check("native editor, plain word", "Hello world", ",", true, { preedit: "world" });
check("android editor, plain word", "Hello world", ",", true,
      { preedit: "world", androidEditor: true });
check("native editor, scheme", "Open https", ":", false, { preedit: "https" });
check("android editor, scheme", "Open https", ":", false,
      { preedit: "https", androidEditor: true });

// Fields and the setting itself.
check("setting is off", "Hello", ",", false, { enabled: false });
check("address or password field", "Hello", ",", false, { plainField: false });

// Picking one of these from the suggestion strip must not put a space behind
// it, or the address can never be finished.
function checkOpener(word, expected) {
    const actual = context.wordOpensAddress(word);
    if (actual !== expected) {
        failures++;
        console.log("FAIL  suggestion " + JSON.stringify(word) + " was "
                    + (actual ? "treated as" : "not treated as")
                    + " the start of an address");
    } else {
        console.log("ok    " + ("suggestion strip").padEnd(32)
                    + JSON.stringify(word).padEnd(24)
                    + (actual ? "no space after it" : "space as usual"));
    }
}

checkOpener("www", true);
checkOpener("WWW", true);
checkOpener("http", true);
checkOpener("https", true);
checkOpener("ftp", true);
checkOpener("mailto", true);
checkOpener("hello", false);
checkOpener("wwww", false);
checkOpener("", false);

if (failures > 0) {
    console.log("");
    console.log(failures + " punctuation spacing checks failed");
    process.exit(1);
}
console.log("");
console.log("Punctuation spacing checks passed");
