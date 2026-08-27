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

if (!Array.isArray(context.categories) || context.categories.length !== 13)
    throw new Error("Expected 13 extended-symbol categories");
if (context.categories[0].id !== "favorites"
        || context.categories[0].icon !== "☆"
        || context.categories[0].entries.length !== 0)
    throw new Error("Favorites must be the empty, runtime-populated first category");

const entries = context.categories.flatMap(category => category.entries);
if (entries.length !== 5807)
    throw new Error(`Expected 5807 generated symbols, got ${entries.length}`);
if (new Set(entries).size !== entries.length)
    throw new Error("Extended-symbol data contains duplicates");

const required = Array.from("←↑→↓↔↕↨∂∆∏∑∙√∞▀▄█▌▐░▒▓■□▪▫▬▲►▼◄◊○◌●◘◙◦☺☻ﷲﷴﷺﷻ﷽");
for (const symbol of required) {
    if (!entries.includes(symbol))
        throw new Error(`Missing required symbol U+${symbol.codePointAt(0).toString(16).toUpperCase()}`);
}

const numberEntries = context.categories.find(category =>
    category.id === "currency_numbers").entries;
const expectedNumberPrefix = Array.from(
    "$£€﷼₺¥¢⁰¹²³⁴⁵⁶⁷⁸⁹₀₁₂₃₄₅₆₇₈₉٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹");
if (numberEntries.slice(0, expectedNumberPrefix.length).join("")
        !== expectedNumberPrefix.join(""))
    throw new Error("Numeric category is missing its ordered digit families");

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

process.stdout.write(`Extended-symbol validation passed: ${entries.length} entries in ${context.categories.length} categories.\n`);
