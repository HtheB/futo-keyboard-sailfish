#!/usr/bin/env node
"use strict";

const fs = require("fs");
const zlib = require("zlib");

if (process.argv.length !== 4) {
    console.error("usage: generate-serbian-latin-dictionary.js INPUT.gz OUTPUT");
    process.exit(2);
}

const input = zlib.gunzipSync(fs.readFileSync(process.argv[2])).toString("utf8");
if (!input.startsWith("dictionary=main:sr,locale=sr,"))
    throw new Error("input is not the pinned Serbian dictionary");

const replacements = {
    "А": "A", "а": "a", "Б": "B", "б": "b", "В": "V", "в": "v",
    "Г": "G", "г": "g", "Д": "D", "д": "d", "Ђ": "Đ", "ђ": "đ",
    "Е": "E", "е": "e", "Ж": "Ž", "ж": "ž", "З": "Z", "з": "z",
    "И": "I", "и": "i", "Ј": "J", "ј": "j", "К": "K", "к": "k",
    "Л": "L", "л": "l", "Љ": "Lj", "љ": "lj", "М": "M", "м": "m",
    "Н": "N", "н": "n", "Њ": "Nj", "њ": "nj", "О": "O", "о": "o",
    "П": "P", "п": "p", "Р": "R", "р": "r", "С": "S", "с": "s",
    "Т": "T", "т": "t", "Ћ": "Ć", "ћ": "ć", "У": "U", "у": "u",
    "Ф": "F", "ф": "f", "Х": "H", "х": "h", "Ц": "C", "ц": "c",
    "Ч": "Č", "ч": "č", "Џ": "Dž", "џ": "dž", "Ш": "Š", "ш": "š"
};

let output = input.replace(/[А-Ша-шЂ-Џђ-џ]/g, character =>
    replacements[character] === undefined ? character : replacements[character]);
output = output.replace(/^dictionary=main:sr,locale=sr,/, 
                        "dictionary=main:sr_Latn,locale=sr_Latn,");

fs.writeFileSync(process.argv[3], output, "utf8");
