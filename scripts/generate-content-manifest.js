#!/usr/bin/env node
"use strict";

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const projectRoot = path.resolve(__dirname, "..");
const outputDirectory = path.resolve(process.argv[2] || path.join(projectRoot, "build/content-packs"));
const manifestPath = path.resolve(process.argv[3] || path.join(projectRoot, "content/manifest.json"));
const packVersion = "0.1.0-1";
const defaultBaseUrl = "https://github.com/HtheB/futo-keyboard-sailfish/releases/download/v0.1.0/";

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
    ["LV", "Latviešu", "lv.fksidx", "lv"],
    ["LT", "Lietuvių", "lt.fksidx", "lt"]
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
        version: packVersion,
        archive,
        ...archiveInfo(archive),
        installedBytes: recursiveSize(installedSource),
        paths: [installedPath]
    }, extra || {});
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

items.push(item(
    "voice-multilingual-39",
    "voice",
    "FUTO Multilingual-39",
    `futo-content-voice-multilingual-39-${packVersion}.tar.gz`,
    path.join(projectRoot, "voice/models/tiny_acft_q8_0.bin"),
    "voice/tiny_acft_q8_0.bin"
));

for (const [code, name, filename, slug] of languages) {
    items.push(item(
        `dictionary-${slug}`,
        "dictionary",
        name,
        `futo-content-dictionary-${slug}-${packVersion}.tar.gz`,
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
