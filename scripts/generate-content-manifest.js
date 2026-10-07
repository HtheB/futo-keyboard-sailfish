#!/usr/bin/env node
"use strict";

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const projectRoot = path.resolve(__dirname, "..");
const outputDirectory = path.resolve(process.argv[2] || path.join(projectRoot, "build/content-packs"));
const manifestPath = path.resolve(process.argv[3] || path.join(projectRoot, "content/manifest.json"));
const packVersion = "0.4.0-1";
// Packs whose content changed after the release their base URL points at.
// Only these carry a new version and filename; every other archive already
// published stays exactly where it is and is never re-downloaded.
const packVersionOverrides = {
    "dictionary-ro": "0.4.2-1"
};

function versionFor(id) {
    return packVersionOverrides[id] || packVersion;
}
const defaultBaseUrl = "https://github.com/HtheB/futo-keyboard-sailfish/releases/download/v0.4.0/";

const languages = [
    ["EN", "English (US)", "en_US.fksidx", "en-us"],
    ["EN_GB", "English (UK)", "en_GB.fksidx", "en-gb"],
    ["NL", "Nederlands", "nl.fksidx", "nl"],
    ["TR", "Türkçe", "tr.fksidx", "tr"],
    ["DE", "Deutsch", "de.fksidx", "de"],
    ["FR", "Français", "fr.fksidx", "fr"],
    ["ES", "Español", "es.fksidx", "es"],
    ["IT", "Italiano", "it.fksidx", "it"],
    ["PT_BR", "Português (Brasil)", "pt_BR.fksidx", "pt-br"],
    ["PT_PT", "Português (Portugal)", "pt_PT.fksidx", "pt-pt"],
    ["SV", "Svenska", "sv.fksidx", "sv"],
    ["NB", "Norsk bokmål", "nb.fksidx", "nb"],
    ["DA", "Dansk", "da.fksidx", "da"],
    ["FI", "Suomi", "fi.fksidx", "fi"],
    ["PL", "Polski", "pl.fksidx", "pl"],
    ["CS", "Čeština", "cs.fksidx", "cs"],
    ["RO", "Română", "ro.fksidx", "ro"],
    ["SL", "Slovenščina", "sl.fksidx", "sl"],
    ["HR", "Hrvatski", "hr.fksidx", "hr"],
    ["HU", "Magyar", "hu.fksidx", "hu"],
    ["LV", "Latviešu", "lv.fksidx", "lv"],
    ["LT", "Lietuvių", "lt.fksidx", "lt"],
    ["EL", "Ελληνικά", "el.fksidx", "el"],
    ["RU", "Русский", "ru.fksidx", "ru"],
    ["SR", "Српски (ћирилица)", "sr.fksidx", "sr"],
    ["SR_LATN", "Srpski (latinica)", "sr_Latn.fksidx", "sr-latn"],
    ["AR", "العربية", "ar.fksidx", "ar"],
    ["FA", "فارسی", "fa.fksidx", "fa"]
];

function recursiveSize(filename) {
    const info = fs.statSync(filename);
    if (info.isFile()) return info.size;
    return fs.readdirSync(filename).reduce((sum, entry) =>
        sum + recursiveSize(path.join(filename, entry)), 0);
}

function archiveInfo(filename) {
    const fullPath = path.join(outputDirectory, filename);
    const data = fs.readFileSync(fullPath);
    return {
        sha256: crypto.createHash("sha256").update(data).digest("hex"),
        downloadBytes: data.length
    };
}

function item(id, kind, name, archive, installedSource, installedPath, extra) {
    return Object.assign({
        id,
        kind,
        name,
        version: versionFor(id),
        archive,
        ...archiveInfo(archive),
        installedBytes: recursiveSize(installedSource),
        paths: [installedPath]
    }, extra || {});
}

function directFileItem(id, kind, name, filename, installedPath, sha256, bytes, version,
                        url, fallbackUrl) {
    return {
        id,
        kind,
        name,
        version: version || `upstream-${sha256.slice(0, 8)}`,
        archive: filename,
        url: url || `${defaultBaseUrl}${filename}`,
        fallbackUrl: fallbackUrl || `https://keyboard.futo.org/${filename}`,
        rawFile: true,
        sha256,
        downloadBytes: bytes,
        installedBytes: bytes,
        paths: [installedPath]
    };
}

const items = [];
for (const style of ["twemoji", "openmoji", "noto"]) {
    const display = style === "twemoji" ? "Twemoji"
        : style === "openmoji" ? "OpenMoji" : "Noto Color Emoji";
    items.push(item(
        `emoji-${style}`,
        "emoji",
        display,
        `futo-content-emoji-${style}-${packVersion}.tar.gz`,
        path.join(projectRoot, "emoji", style),
        `emoji/${style}`,
        { style }
    ));
}

items.push(directFileItem(
    "voice-multilingual-39",
    "voice",
    "Multilingual - Default, fastest",
    "voice-input-multilingual-39.bin",
    "voice/tiny_acft_q8_0.bin",
    "07aa4d514144deacf5ffec5cacb36c93dee272fda9e64ac33a801f8cd5cbd953",
    43537450,
    packVersion
));

items.push(directFileItem(
    "voice-english-39",
    "voice",
    "English - Fastest",
    "voice-input-english-39.bin",
    "voice/english-39.bin",
    "4b5480aa1b14a7efc5b578ef176510970a898049671c3cd237285b3e3f6bfbfc",
    43550795
));
items.push(directFileItem(
    "voice-english-74",
    "voice",
    "English - Slower, more accurate",
    "voice-input-english-74.bin",
    "voice/english-74.bin",
    "e9b4b7b81b8a28769e8aa9962aa39bb9f21b622cf6a63982e93f065ed5caf1c8",
    81781811
));
items.push(directFileItem(
    "voice-english-244",
    "voice",
    "English - Slowest, most accurate",
    "voice-input-english-244.bin",
    "voice/english-244.bin",
    "58fbe949992dafed917590d58bc12ca577b08b9957f0b3e0d7ee71b64bed3aa8",
    264477561
));
items.push(directFileItem(
    "voice-multilingual-74",
    "voice",
    "Multilingual - Slower, more accurate",
    "voice-input-multilingual-74.bin",
    "voice/multilingual-74.bin",
    "e44f352c9aa2c3609dece20c733c4ad4a75c28cd9ab07d005383df55fa96efc4",
    81768602
));
items.push(directFileItem(
    "voice-multilingual-244",
    "voice",
    "Multilingual - Slowest, most accurate",
    "voice-input-multilingual-244.bin",
    "voice/multilingual-244.bin",
    "15ef255465a6dc582ecf1ec651a4618c7ee2c18c05570bbe46493d248d465ac4",
    264464624
));

items.push(directFileItem(
    "prediction-english-futo",
    "prediction",
    "English - Context-aware",
    "futo-content-prediction-english-0.7.0-1.gguf",
    "prediction/ml4_q6_k.gguf",
    "6545c1c9ef2d76e9bfb87ad4fcf2061889513af84fcf30d907412be7fcdedb7b",
    30662880,
    "upstream-d87d9dbd",
    "https://github.com/HtheB/futo-keyboard-sailfish/releases/download/v0.7.0/futo-content-prediction-english-0.7.0-1.gguf",
    "https://gitlab.futo.org/keyboard/keyboard-large-resources/-/raw/d87d9dbdf3966bbe18413be375dab2f6c7bbdfdd/raw/ml4_q6_k.gguf"
));

items.push(item(
    "swipe-universal",
    "swipe",
    "FUTO Swipe",
    `futo-content-swipe-universal-${packVersion}.tar.gz`,
    path.join(projectRoot, "swipe/models"),
    "swipe/models"
));

for (const [code, name, filename, slug] of languages) {
    items.push(item(
        `dictionary-${slug}`,
        "dictionary",
        name,
        `futo-content-dictionary-${slug}-${versionFor(`dictionary-${slug}`)}.tar.gz`,
        path.join(projectRoot, "build/dictionaries", filename),
        `dictionaries/${filename}`,
        { languageCode: code }
    ));
}

const manifest = {
    formatVersion: 1,
    contentVersion: packVersion,
    baseUrl: process.env.FUTO_CONTENT_BASE_URL || defaultBaseUrl,
    items
};

fs.mkdirSync(path.dirname(manifestPath), { recursive: true });
fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n");
console.log(`Wrote ${items.length} content entries to ${manifestPath}`);
