#!/usr/bin/env node
"use strict";

const assert = require("assert");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");
const root = path.resolve(__dirname, "..");
const engine = process.env.FUTO_TEST_DICTIONARY_ENGINE ||
    path.join(root, "build", "futo-dictionary-compiler");
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "futo-spelling-"));

function request(dictionary, commands) {
    const result = spawnSync(engine, ["--dictionary", "IT=" + dictionary], {
        input: commands.join("\n") + "\n", encoding: "utf8"
    });
    assert.strictEqual(result.status, 0, result.stderr);
    return result.stdout.trim().split("\n").map(line => {
        assert(line.startsWith("OK\t"), line);
        return JSON.parse(line.slice(3));
    });
}

try {
    // Every pair is deliberately given a more frequent unaccented spelling:
    // typing the accent must still preserve it, independent of frequency.
    const pairs = [
        ["e", "è"], ["ou", "où"], ["si", "sí"], ["tu", "tú"],
        ["schon", "schön"], ["wurde", "würde"], ["avo", "avó"],
        ["een", "één"], ["все", "всё"], ["αλλα", "αλλά"],
        ["rad", "rád"], ["mas", "más"], ["car", "čar"],
        ["sok", "sók"], ["far", "får"]
    ];
    // These are algorithm checks, not dictionary frequency or grammar claims.
    const absent = ["ecole", "cafe", "fur", "prilis"];
    const restored = ["école", "café", "für", "příliš"];
    const words = new Map();
    for (const [plain, accented] of pairs) {
        words.set(plain, 240);
        words.set(accented, 180);
    }
    words.set("avô", 240);
    for (const word of restored) words.set(word, 250);
    const source = path.join(temporary, "spelling.combined");
    const compiled = path.join(temporary, "spelling.fksidx");
    fs.writeFileSync(source, Array.from(words, ([word, frequency]) =>
        " word=" + word + ",f=" + frequency + ",flags=\n").join(""));
    const compile = spawnSync(engine, ["--compile", source, compiled], { encoding: "utf8" });
    assert.strictEqual(compile.status, 0, compile.stderr);

    for (const dictionary of [source, compiled]) {
        for (const [plain, accented] of pairs) {
            const [base, explicit, correction] = request(dictionary, [
                "ANALYZE\tIT\t4\t" + plain,
                "ANALYZE\tIT\t4\t" + accented,
                "CORRECT\tIT\t" + plain
            ]);
            assert(base.known && explicit.known, plain + " / " + accented);
            assert(base.suggestions.some(item => item.word === accented && item.spellingMatch),
                accented + " must be offered without an accent in the query");
            assert.strictEqual(explicit.suggestions[0].word, accented,
                "explicit accents must outrank unaccented homographs");
            assert.strictEqual(correction, "", "do not auto-replace a valid unaccented word");
        }
        for (let i = 0; i < absent.length; ++i) {
            const [analysis, correction] = request(dictionary, [
                "ANALYZE\tIT\t4\t" + absent[i], "CORRECT\tIT\t" + absent[i]
            ]);
            assert.strictEqual(analysis.known, false, absent[i] + " must not be falsely known");
            assert.strictEqual(analysis.suggestions[0].word, restored[i]);
            assert.strictEqual(correction, restored[i], "restore a missing accent on an unknown word");
            assert.deepStrictEqual(analysis.phrases, [], "do not split an accent-only spelling");
        }
        const [first, second] = request(dictionary, [
            "ANALYZE\tIT\t4\tavó", "ANALYZE\tIT\t4\tÉcole"
        ]);
        assert.strictEqual(first.suggestions[0].word, "avó");
        assert.strictEqual(second.suggestions[0].word, "École");
    }
    console.log("Accent-aware suggestions and corrections passed for plain and compiled dictionaries");

    if (process.env.FUTO_TEST_ALL_DICTIONARIES === "1") {
        const manifest = JSON.parse(fs.readFileSync(path.join(root, "content", "manifest.json")));
        const files = new Set(manifest.items.filter(item => item.kind === "dictionary")
            .flatMap(item => item.paths).filter(file => file.endsWith(".fksidx")));
        const directory = process.env.FUTO_TEST_DICTIONARY_DIR || path.join(root, "build", "dictionaries");
        let checked = 0;
        for (const relative of files) {
            const dictionary = path.join(directory, path.basename(relative));
            const data = fs.readFileSync(dictionary);
            assert.strictEqual(data.subarray(0, 8).toString("binary"), "FKSIDX1\0");
            const count = data.readUInt32LE(8);
            let offset = 12;
            const accented = [], ordinary = [];
            for (let i = 0; i < count && accented.length < 3; ++i) {
                const bytes = data.readUInt16LE(offset), length = data[offset + 2];
                const start = offset + 8;
                const word = data.subarray(start, start + bytes).toString("utf8");
                offset = start + bytes + length * 4;
                if (word !== word.toLowerCase() || !/^\p{L}+$/u.test(word)) continue;
                const normalized = String.fromCodePoint(...Array.from({length},
                    (_, j) => data.readUInt32LE(start + bytes + j * 4)));
                if (word !== normalized) {
                    accented.push(word);
                } else if (ordinary.length === 0) {
                    ordinary.push(word);
                }
            }
            const words = accented.length ? accented : ordinary;
            assert(words.length > 0, "no usable entries in " + relative);
            const analyses = request(dictionary, words.map(word => "ANALYZE\tIT\t4\t" + word));
            analyses.forEach((analysis, i) => {
                assert(analysis.known, relative + ": exact word became unknown: " + words[i]);
                assert.strictEqual(analysis.suggestions[0].word.toLowerCase(), words[i],
                    relative + ": explicit spelling lost priority");
            });
            ++checked;
            console.log(path.basename(relative) + ": " + words.join(", "));
        }
        assert(checked >= 50, "not enough downloadable dictionary files were checked");
        console.log("PASS: explicit spelling preserved in " + checked + " downloadable dictionaries");
    }
} finally {
    fs.rmSync(temporary, { recursive: true, force: true });
}
