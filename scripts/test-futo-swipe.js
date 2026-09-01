#!/usr/bin/env node

// Smoke-test the real FUTO Swipe worker with the default layout and a common
// word for every prediction language shipped by this Sailfish port.  The
// generated traces intentionally contain many intermediate points, matching
// the continuous touch path sent by FutoKeyboardLayout.qml.

"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");
const { spawn } = require("child_process");

const root = path.resolve(__dirname, "..");
const worker = process.env.FUTO_SWIPE_WORKER
    || path.join(root, "build", "host-swipe", "futo-keyboard-swipe");
const runner = (process.env.FUTO_SWIPE_RUNNER || "").trim()
    .split(/\s+/).filter(Boolean);
const encoder = process.env.FUTO_SWIPE_MODEL
    || path.join(root, "swipe", "models", "honorable_sturgeon", "model_fp32.pte");
const decoder = process.env.FUTO_SWIPE_DECODER
    || path.join(root, "swipe", "models", "magic_macaw", "model_fp32.pte");
const lmModel = process.env.FUTO_SWIPE_LM_MODEL
    || path.join(root, "swipe", "models", "hungry_jellyfish", "context_lm.pte");
const lmVocab = process.env.FUTO_SWIPE_LM_VOCAB
    || path.join(root, "swipe", "models", "hungry_jellyfish", "vocab.txt");

const allCases = [
    ["AR", "مرحبا"], ["CS", "ahoj"], ["DA", "hej"], ["DE", "danke"],
    ["EL", "γεια"], ["EN", "as"], ["EN", "I'm"], ["EN", "can't"],
    ["EN", "don't"], ["EN", "you're"],
    ["EN_GB", "thanks"], ["ES", "hola"],
    ["FA", "میکنم"], ["FI", "kiitos"], ["FR", "merci"], ["FR", "d'une"],
    ["HR", "hvala"], ["HU", "szia"], ["IT", "ciao"], ["IT", "l'anno"],
    ["LT", "labas"], ["LV", "sveiki"], ["NB", "hei"], ["NL", "hallo"],
    ["NL", "zo'n"], ["PL", "część"],
    ["PT_BR", "obrigado"], ["PT_PT", "obrigado"], ["RO", "salut"],
    ["RU", "привет"], ["SL", "hvala"], ["SR", "хвала"],
    ["SR_LATN", "hvala"], ["SV", "tack"], ["TR", "merhaba"],
    ["TR", "e-posta"]
];
const requestedLanguages = new Set((process.env.FUTO_SWIPE_TEST_LANGUAGES || "")
    .split(",").map(value => value.trim()).filter(Boolean));
const cases = requestedLanguages.size
    ? allCases.filter(([language]) => requestedLanguages.has(language))
    : allCases;
const mustRankFirst = new Set(["EN\tI'm", "EN\tcan't"]);

function loadLayouts() {
    let source = fs.readFileSync(path.join(root, "layouts", "FutoLetterLayouts.js"), "utf8");
    source = source.replace(/^\s*\.pragma\s+library\s*$/m, "");
    source += "\n;globalThis.__layouts = layouts; globalThis.__defaults = languageDefaults;";
    const context = {};
    vm.runInNewContext(source, context, { filename: "FutoLetterLayouts.js" });
    return { layouts: context.__layouts, defaults: context.__defaults };
}

function geometryFor(rows) {
    const keys = new Map();
    const geometry = [];
    rows.forEach((row, rowIndex) => {
        row.forEach((letter, column) => {
            let x;
            if (rowIndex === 0 || row.length >= 10) {
                x = (column + 0.5) / row.length;
            } else if (rowIndex === 1) {
                x = (column + 1.0) / (row.length + 1.0);
            } else {
                x = (column + 1.5) / (row.length + 3.0);
            }
            const y = (rowIndex + 0.5) / 3.0;
            const point = { letter: String(letter).toLowerCase(), x, y };
            if (!keys.has(point.letter))
                keys.set(point.letter, point);
            geometry.push(`${point.letter.codePointAt(0)}:${x.toFixed(5)}:${y.toFixed(5)}`);
        });
    });
    return { keys, serialized: geometry.join(";") };
}

function baseLetter(character) {
    const substitutions = {
        "ł": "l", "đ": "d", "ð": "d", "þ": "t", "ø": "o",
        "æ": "a", "œ": "o", "ß": "s", "ı": "i", "ё": "е"
    };
    const lower = String(character).toLowerCase();
    if (substitutions[lower])
        return substitutions[lower];
    return lower.normalize("NFD").replace(/\p{Mark}/gu, "");
}

function traceFor(word, keys) {
    const gestureCharacters = Array.from(word).filter(character =>
        !["'", "’", "‘", "ʼ", "`", "´", "-"].includes(character));
    const centers = gestureCharacters.map(character => {
        const lower = character.toLowerCase();
        return keys.get(lower) || keys.get(baseLetter(lower));
    });
    if (centers.some(point => !point))
        throw new Error(`word cannot be drawn on layout: ${word}`);

    const points = [];
    let elapsed = 0;
    const append = (x, y) => {
        points.push({ x, y, t: elapsed });
        elapsed += 12;
    };
    append(centers[0].x, centers[0].y);
    for (let index = 1; index < centers.length; ++index) {
        const from = centers[index - 1];
        const to = centers[index];
        for (let step = 1; step <= 8; ++step) {
            const amount = step / 8.0;
            append(from.x + (to.x - from.x) * amount,
                   from.y + (to.y - from.y) * amount);
        }
    }
    const first = centers[0].letter.codePointAt(0);
    const last = centers[centers.length - 1].letter.codePointAt(0);
    return points.map((point, index) => {
        const code = index === 0 ? first : (index === points.length - 1 ? last : 0);
        return `${code}:${point.x.toFixed(5)}:${point.y.toFixed(5)}:${point.t}`;
    }).join(";");
}

async function main() {
    if (!fs.existsSync(worker))
        throw new Error(`FUTO Swipe worker is missing: ${worker}`);
    if (!fs.existsSync(encoder))
        throw new Error(`FUTO Swipe model is missing: ${encoder}`);

    const { layouts, defaults } = loadLayouts();
    const argumentsList = ["--encoder", encoder];
    if (fs.existsSync(decoder))
        argumentsList.push("--decoder", decoder);
    if (fs.existsSync(lmModel) && fs.existsSync(lmVocab))
        argumentsList.push("--lm-model", lmModel, "--lm-vocab", lmVocab);
    for (const [language] of cases) {
        const filename = language === "EN" ? "en_US"
            : (language === "EN_GB" ? "en_GB"
               : (language === "SR_LATN" ? "sr_Latn" : language.toLowerCase()));
        const dictionary = path.join(root, "build", "dictionaries", `${filename}.fksidx`);
        if (!fs.existsSync(dictionary))
            throw new Error(`compiled dictionary is missing: ${dictionary}`);
        argumentsList.push("--dictionary", `${language}=${dictionary}`);
    }

    const executable = runner.length ? runner[0] : worker;
    const processArguments = runner.length
        ? runner.slice(1).concat([worker], argumentsList)
        : argumentsList;
    const child = spawn(executable, processArguments,
        { stdio: ["pipe", "pipe", "inherit"] });
    child.stdout.setEncoding("utf8");
    let buffered = "";
    const pending = [];
    child.stdout.on("data", chunk => {
        buffered += chunk;
        while (buffered.includes("\n")) {
            const newline = buffered.indexOf("\n");
            const line = buffered.slice(0, newline).replace(/\r$/, "");
            buffered = buffered.slice(newline + 1);
            const next = pending.shift();
            if (next)
                next.resolve(line);
        }
    });
    child.on("error", error => {
        while (pending.length)
            pending.shift().reject(error);
    });
    child.on("exit", (code, signal) => {
        if ((code || signal) && pending.length) {
            const detail = signal ? `signal ${signal}` : `status ${code}`;
            const error = new Error(`FUTO Swipe worker exited with ${detail}`);
            while (pending.length)
                pending.shift().reject(error);
        }
    });

    const request = line => new Promise((resolve, reject) => {
        pending.push({ resolve, reject });
        child.stdin.write(line + "\n");
    });

    let failures = 0;
    for (const [language, expected] of cases) {
        const layout = layouts[defaults[language]];
        const geometry = geometryFor(layout.rows);
        const response = await request(["SWIPE3", language, "20", "0", "1", "",
            traceFor(expected, geometry.keys), geometry.serialized].join("\t"));
        if (!response.startsWith("OK\t")) {
            console.error(`${language}: ${response}`);
            failures++;
            continue;
        }
        const suggestions = JSON.parse(response.slice(3)).map(item => item.word);
        const rank = suggestions.indexOf(expected);
        console.log(`${language.padEnd(7)} ${expected.padEnd(10)} rank=${rank < 0 ? "-" : rank + 1}`
                    + `  ${suggestions.slice(0, 5).join(", ")}`);
        if (suggestions.length === 0 || rank < 0
                || (mustRankFirst.has(`${language}\t${expected}`) && rank !== 0))
            failures++;
    }
    child.stdin.end();
    if (failures)
        throw new Error(`${failures} FUTO Swipe language smoke test(s) failed`);
}

main().catch(error => {
    console.error(error.message || error);
    process.exitCode = 1;
});
