#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const root = path.resolve(__dirname, "..");
const source = fs.readFileSync(path.join(root, "layouts", "FutoSymbolData.js"), "utf8")
    .replace(/^\.pragma library\s*$/m, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context, { filename: "FutoSymbolData.js" });

const expectedCategoryIds = [
    "favorites", "arrows", "math", "numbers", "currency", "punctuation",
    "brackets_quotes", "boxes_blocks", "shapes", "technical", "braille",
    "letterlike", "styled_letters", "enclosed", "music", "games",
    "cultural", "marks_misc"
];
if (!Array.isArray(context.categories)
        || context.categories.map(category => category.id).join(",")
           !== expectedCategoryIds.join(","))
    throw new Error("Extended-symbol categories or their order are incorrect");
if (context.categories[0].id !== "favorites"
        || context.categories[0].icon !== "☆"
        || context.categories[0].entries.length !== 0)
    throw new Error("Favorites must be the empty, runtime-populated first category");

const entries = context.categories.flatMap(category => category.entries);
if (entries.length !== 5818)
    throw new Error(`Expected 5818 generated symbols, got ${entries.length}`);
if (new Set(entries).size !== entries.length)
    throw new Error("Extended-symbol data contains duplicates");

const required = Array.from("←↑→↓↔↕↨∂∆∏∑∙√∞▀▄█▌▐░▒▓■□▪▫▬▲►▼◄◊○◌●◘◙◦☺☻⃁﷼ﷲﷴﷺﷻ﷽");
for (const symbol of required) {
    if (!entries.includes(symbol))
        throw new Error(`Missing required symbol U+${symbol.codePointAt(0).toString(16).toUpperCase()}`);
}

const numberEntries = context.categories.find(category =>
    category.id === "numbers").entries;
const expectedNumberPrefix = Array.from(
    "⁰¹²³⁴⁵⁶⁷⁸⁹ⁿ₀₁₂₃₄₅₆₇₈₉٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹");
if (numberEntries.slice(0, expectedNumberPrefix.length).join("")
        !== expectedNumberPrefix.join(""))
    throw new Error("Numeric category is missing its ordered digit families");

const currencyEntries = context.categories.find(category =>
    category.id === "currency").entries;
if (currencyEntries.slice(0, 8).join("") !== "$£€₺⃁﷼¥¢")
    throw new Error("Currency category is missing its common-symbol prefix");
if (!entries.includes("ﷻ"))
    throw new Error("Jalla Jalaluhu must remain the actual U+FDFB character");

const symbolKeySource = fs.readFileSync(
    path.join(root, "layouts", "FutoExtendedSymbolKey.qml"), "utf8");
if (!/committedSymbolText:\s*symbolText/.test(symbolKeySource)
        || symbolKeySource.includes("جل جلاله"))
    throw new Error("Extended symbol keys must commit U+FDFB without text substitution");

const culturalEntries = context.categories.find(category =>
    category.id === "cultural").entries;
const expectedArabicPrefix = Array.from("﷽ﷲﷻﷴﷺﷹﷷﷸﷵﷶﷳﷰﷱ");
if (culturalEntries.slice(0, expectedArabicPrefix.length).join("")
        !== expectedArabicPrefix.join(""))
    throw new Error("Cultural category is missing its semantic Arabic ligature order");

// Emoji with artwork belong in the dedicated Unicode 17 emoji picker.
for (const duplicate of ["😀", "🚀", "🍺", "🐻", "🎉"]) {
    if (entries.includes(duplicate))
        throw new Error(`Emoji ${duplicate} is duplicated in the symbol picker`);
}

const semanticAssignments = new Map([
    ["Ⓐ", "enclosed"], ["ⓐ", "enclosed"],
    ["⌺", "technical"], ["⍉", "technical"], ["⍟", "technical"],
    ["♯", "music"], ["𝄸", "music"], ["♔", "games"],
    ["۞", "cultural"], ["﷽", "cultural"],
    ["⊕", "math"], ["⠿", "braille"], ["𝐀", "styled_letters"],
    ["►", "arrows"], ["▲", "shapes"], ["⎋", "technical"]
]);
for (const [symbol, expectedCategory] of semanticAssignments) {
    const actualCategory = context.categories.find(category =>
        category.entries.includes(symbol));
    if (!actualCategory || actualCategory.id !== expectedCategory)
        throw new Error(`${symbol} belongs in ${expectedCategory}, not ${actualCategory && actualCategory.id}`);
}

for (const regionalIndicator of ["🇦", "🇳", "🇿"]) {
    if (entries.includes(regionalIndicator))
        throw new Error("Standalone regional indicators belong in complete flag emoji");
}
if (entries.includes("⠀"))
    throw new Error("Blank Braille cell must not create an invisible key");

process.stdout.write(`Extended-symbol validation passed: ${entries.length} entries in ${context.categories.length} categories.\n`);
