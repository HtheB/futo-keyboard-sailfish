/*
 * Generate the complete image-backed Unicode Emoji 17 picker data.
 *
 * Inputs are pinned upstream checkouts.  Every user-facing fully-qualified
 * sequence gets an asset in all three selectable style directories.  If a
 * style intentionally aliases or omits a sequence, another pinned SVG is used
 * as a visibility fallback instead of leaving a blank key.
 */
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

function argumentsByName(argv) {
    const result = {};
    for (let i = 0; i < argv.length; i += 2) {
        if (!argv[i].startsWith("--") || i + 1 >= argv.length)
            throw new Error("Expected --name value arguments");
        result[argv[i].slice(2)] = path.resolve(argv[i + 1]);
    }
    return result;
}

function required(args, name) {
    if (!args[name])
        throw new Error("Missing --" + name);
    return args[name];
}

function normalizedCode(points) {
    return points
        .map((point) => typeof point === "number"
             ? point : Number.parseInt(String(point), 16))
        .filter((point) => point !== 0xfe0f)
        .map((point) => point.toString(16))
        .join("-");
}

function normalizedStem(stem, separator) {
    return normalizedCode(stem.split(separator).filter(Boolean));
}

function scanAssets(directory, extension, notoNames) {
    const result = Object.create(null);
    for (const name of fs.readdirSync(directory).sort()) {
        if (path.extname(name).toLowerCase() !== extension)
            continue;
        let stem = path.basename(name, extension);
        if (notoNames) {
            if (!stem.startsWith("emoji_u"))
                continue;
            stem = stem.slice("emoji_u".length);
        }
        const key = normalizedStem(stem, notoNames ? "_" : "-");
        if (key && !result[key])
            result[key] = path.join(directory, name);
    }
    return result;
}

function parseEmojiTest(source) {
    const items = [];
    let group = "";
    let subgroup = "";
    for (const rawLine of source.split(/\r?\n/)) {
        let match = rawLine.match(/^# group: (.+)$/);
        if (match) {
            group = match[1];
            continue;
        }
        match = rawLine.match(/^# subgroup: (.+)$/);
        if (match) {
            subgroup = match[1];
            continue;
        }
        match = rawLine.match(/^([0-9A-F ]+)\s*;\s*fully-qualified\s*#\s*\S+\s+E[0-9.]+\s+(.+)$/u);
        if (!match)
            continue;
        const points = match[1].trim().split(/\s+/).map((value) => Number.parseInt(value, 16));
        items.push({
            points,
            text: String.fromCodePoint(...points),
            code: normalizedCode(points),
            group,
            subgroup,
            name: match[2].trim()
        });
    }
    return items;
}

function readOpenMojiSearchData(file) {
    const wordsByCode = Object.create(null);
    const toneBaseByCode = Object.create(null);
    const data = JSON.parse(fs.readFileSync(file, "utf8"));
    for (const item of data) {
        if (!item.hexcode)
            continue;
        const key = normalizedStem(String(item.hexcode), "-");
        const words = [item.annotation, item.tags, item.openmoji_tags, item.subgroups]
            .filter(Boolean).join(" ").toLowerCase();
        if (!wordsByCode[key] || words.length > wordsByCode[key].length)
            wordsByCode[key] = words;
        if (item.skintone_base_hexcode)
            toneBaseByCode[key] = normalizedStem(String(item.skintone_base_hexcode), "-");
    }
    return { wordsByCode, toneBaseByCode };
}

const cldrLocales = {
    EN: ["en"],
    EN_GB: ["en", "en-GB"],
    NL: ["nl"],
    TR: ["tr"],
    DE: ["de"],
    FR: ["fr"],
    ES: ["es"],
    IT: ["it"],
    PT_BR: ["pt"],
    PT_PT: ["pt", "pt-PT"],
    SV: ["sv"],
    NB: ["no"],
    DA: ["da"],
    FI: ["fi"],
    PL: ["pl"],
    CS: ["cs"],
    RO: ["ro"],
    SL: ["sl"],
    HR: ["hr"],
    LV: ["lv"],
    LT: ["lt"]
};

function normalizedEmojiText(text) {
    return normalizedCode(Array.from(String(text), (character) => character.codePointAt(0)));
}

function mergeCldrFile(target, file, rootKey) {
    if (!fs.existsSync(file))
        return;
    const document = JSON.parse(fs.readFileSync(file, "utf8"));
    const annotations = document[rootKey] && document[rootKey].annotations;
    if (!annotations)
        throw new Error("Invalid CLDR annotations file: " + file);
    for (const emoji of Object.keys(annotations)) {
        const value = annotations[emoji];
        const words = [];
        for (const field of [value.default, value.tts]) {
            if (Array.isArray(field))
                words.push(...field);
        }
        const normalizedWords = words.join(" ").toLocaleLowerCase()
                .replace(/\s+/g, " ").trim();
        const code = normalizedEmojiText(emoji);
        if (code && normalizedWords)
            target[code] = ((target[code] || "") + " " + normalizedWords)
                    .replace(/\s+/g, " ").trim();
    }
}

function readCldrSearchData(annotationsRoot, derivedRoot) {
    const result = Object.create(null);
    for (const languageCode of Object.keys(cldrLocales)) {
        const wordsByCode = Object.create(null);
        for (const locale of cldrLocales[languageCode]) {
            mergeCldrFile(wordsByCode,
                          path.join(annotationsRoot, locale, "annotations.json"),
                          "annotations");
            mergeCldrFile(wordsByCode,
                          path.join(derivedRoot, locale, "annotations.json"),
                          "annotationsDerived");
        }
        result[languageCode] = wordsByCode;
    }
    return result;
}

function toneNumber(points) {
    const tones = points.filter((point) => point >= 0x1f3fb && point <= 0x1f3ff);
    if (tones.length === 0)
        return 0;
    const first = tones[0];
    for (let i = 1; i < tones.length; ++i) {
        if (tones[i] !== first)
            return 0;
    }
    return first - 0x1f3fa;
}

function withoutTones(points) {
    return points.filter((point) => point < 0x1f3fb || point > 0x1f3ff);
}

function jsonForQml(value) {
    return JSON.stringify(value).replace(/\u2028/g, "\\u2028").replace(/\u2029/g, "\\u2029");
}

async function main() {
    const args = argumentsByName(process.argv.slice(2));
    const projectRoot = path.resolve(__dirname, "..");
    const emojiTestPath = required(args, "emoji-test");
    const twemojiDirectory = required(args, "twemoji");
    const openMojiDirectory = required(args, "openmoji");
    const openMojiDataPath = required(args, "openmoji-data");
    const notoDirectory = required(args, "noto");
    const cldrAnnotationsRoot = required(args, "cldr-annotations");
    const cldrDerivedRoot = required(args, "cldr-derived");

    const emojiTest = fs.readFileSync(emojiTestPath, "utf8");
    const emojiTestHash = crypto.createHash("sha256").update(emojiTest).digest("hex");
    const allItems = parseEmojiTest(emojiTest);
    if (allItems.length !== 3944)
        throw new Error("Expected 3944 fully-qualified Emoji 17 entries, got " + allItems.length);

    const userItems = allItems.filter((item) => item.group !== "Component");
    const openMojiData = readOpenMojiSearchData(openMojiDataPath);
    const cldrSearchData = readCldrSearchData(cldrAnnotationsRoot, cldrDerivedRoot);
    const groups = [
        "Smileys & Emotion", "People & Body", "Animals & Nature",
        "Food & Drink", "Travel & Places", "Activities", "Objects",
        "Symbols", "Flags"
    ];
    const categories = groups.map(() => []);
    const baseByCode = Object.create(null);

    for (const item of userItems) {
        const hasTone = item.points.some((point) => point >= 0x1f3fb && point <= 0x1f3ff);
        if (hasTone)
            continue;
        const groupIndex = groups.indexOf(item.group);
        if (groupIndex < 0)
            throw new Error("Unexpected Emoji 17 group: " + item.group);
        const search = [item.name, item.subgroup, openMojiData.wordsByCode[item.code] || ""]
            .join(" ").toLowerCase().replace(/\s+/g, " ").trim();
        const localized = {};
        for (const languageCode of Object.keys(cldrSearchData)) {
            const localizedWords = cldrSearchData[languageCode][item.code];
            if (localizedWords)
                localized[languageCode] = localizedWords;
        }
        const entry = { t: item.text, c: item.code, n: search, l: localized, v: [] };
        categories[groupIndex].push(entry);
        baseByCode[item.code] = entry;
    }

    let attachedVariants = 0;
    for (const item of userItems) {
        if (!item.points.some((point) => point >= 0x1f3fb && point <= 0x1f3ff))
            continue;
        const baseCode = openMojiData.toneBaseByCode[item.code]
                || normalizedCode(withoutTones(item.points));
        const base = baseByCode[baseCode];
        if (!base)
            throw new Error("No base emoji for toned sequence " + item.code + " (base " + baseCode + ")");
        base.v.push({ t: item.text, c: item.code, s: toneNumber(item.points) });
        attachedVariants++;
    }

    const baseCount = categories.reduce((sum, category) => sum + category.length, 0);
    if (baseCount !== 1914)
        throw new Error("Expected 1914 base Emoji 17 entries, got " + baseCount);
    if (baseCount + attachedVariants !== userItems.length)
        throw new Error("Not every user-facing Emoji 17 sequence is reachable");

    const twemoji = scanAssets(twemojiDirectory, ".svg", false);
    const openmoji = scanAssets(openMojiDirectory, ".svg", false);
    const noto = scanAssets(notoDirectory, ".png", true);
    const stage = path.join(projectRoot, "build", "emoji-17-stage");
    fs.rmSync(stage, { recursive: true, force: true });
    for (const style of ["twemoji", "openmoji", "noto"])
        fs.mkdirSync(path.join(stage, style), { recursive: true });

    let sharp = null;
    const fallbacks = { twemoji: 0, openmoji: 0, noto: 0 };
    const uniqueItems = Object.create(null);
    for (const item of userItems)
        uniqueItems[item.code] = item;

    for (const code of Object.keys(uniqueItems).sort()) {
        const twemojiSource = twemoji[code] || openmoji[code];
        if (!twemojiSource)
            throw new Error("No SVG artwork for Emoji 17 sequence " + code);
        if (!twemoji[code])
            fallbacks.twemoji++;
        fs.copyFileSync(twemojiSource, path.join(stage, "twemoji", code + ".svg"));

        const openMojiSource = openmoji[code] || twemoji[code];
        if (!openMojiSource)
            throw new Error("No OpenMoji/Twemoji artwork for " + code);
        if (!openmoji[code])
            fallbacks.openmoji++;
        fs.copyFileSync(openMojiSource, path.join(stage, "openmoji", code + ".svg"));

        const notoTarget = path.join(stage, "noto", code + ".png");
        if (noto[code]) {
            fs.copyFileSync(noto[code], notoTarget);
        } else {
            if (!sharp)
                sharp = require("sharp");
            fallbacks.noto++;
            await sharp(twemojiSource, { density: 160 })
                .resize(96, 96, { fit: "contain" }).png().toFile(notoTarget);
        }
    }

    for (const style of ["twemoji", "openmoji", "noto"]) {
        const files = fs.readdirSync(path.join(stage, style));
        if (files.length !== userItems.length)
            throw new Error(style + " staged " + files.length + " assets; expected " + userItems.length);
    }

    const dataSource = [
        ".pragma library",
        "// Generated from Unicode Emoji 17.0; do not edit by hand.",
        "var categoryNames = " + jsonForQml(groups) + ";",
        "var categoryIconCodes = " + jsonForQml([
            "1f600", "1f44b", "1f43b", "1f354", "1f697",
            "26bd", "1f4a1", "2764", "1f3f3"
        ]) + ";",
        "var categories = " + jsonForQml(categories) + ";",
        "var byCode = {};",
        "var allEntries = [];",
        "for (var categoryIndex = 0; categoryIndex < categories.length; ++categoryIndex) {",
        "    for (var itemIndex = 0; itemIndex < categories[categoryIndex].length; ++itemIndex) {",
        "        var entry = categories[categoryIndex][itemIndex];",
        "        byCode[entry.c] = entry;",
        "        allEntries.push(entry);",
        "    }",
        "}",
        "function entryForCode(code) { return byCode[String(code)] || null; }",
        "function standardFold(value) {",
        "    return String(value).toLowerCase().replace(/\\u0307/g, \"\");",
        "}",
        "function turkishFold(value) {",
        "    return String(value).replace(/I/g, \"ı\").replace(/İ/g, \"i\")",
        "            .toLowerCase().replace(/\\u0307/g, \"\");",
        "}",
        "function foldForLanguage(value, language) {",
        "    return String(language) === \"TR\" ? turkishFold(value) : standardFold(value);",
        "}",
        "function search(query, languages) {",
        "    var rawQuery = String(query).trim();",
        "    if (rawQuery === \"\") return allEntries;",
        "    var selected = languages && languages.length ? languages : [\"EN\"];",
        "    var matches = [];",
        "    for (var i = 0; i < allEntries.length; ++i) {",
        "        var matched = false;",
        "        for (var languageIndex = 0; languageIndex < selected.length; ++languageIndex) {",
        "            var language = String(selected[languageIndex]);",
        "            var searchable = \"\";",
        "            if (language === \"EN\" || language === \"EN_GB\")",
        "                searchable += \" \" + allEntries[i].n;",
        "            if (allEntries[i].l && allEntries[i].l[language])",
        "                searchable += \" \" + allEntries[i].l[language];",
        "            searchable = foldForLanguage(searchable, language);",
        "            var words = foldForLanguage(rawQuery, language).split(/\\s+/);",
        "            var languageMatched = true;",
        "            for (var j = 0; j < words.length; ++j) {",
        "                if (searchable.indexOf(words[j]) < 0) { languageMatched = false; break; }",
        "            }",
        "            if (languageMatched) { matched = true; break; }",
        "        }",
        "        if (matched) matches.push(allEntries[i]);",
        "    }",
        "    return matches;",
        "}",
        ""
    ].join("\n");
    const dataStage = path.join(stage, "FutoEmojiData.js");
    fs.writeFileSync(dataStage, dataSource, "utf8");

    const manifest = {
        unicodeVersion: "17.0",
        emojiTestSha256: emojiTestHash,
        fullyQualifiedSequences: allItems.length,
        userFacingSequences: userItems.length,
        baseGridEntries: baseCount,
        skinToneVariants: attachedVariants,
        categoryCounts: Object.fromEntries(groups.map((name, index) => [name, categories[index].length])),
        assetFilesPerStyle: userItems.length,
        fallbackArtwork: fallbacks,
        sources: {
            twemoji: "v17.0.3 b6b55fef1e8636b540a6d016a4729ca8cdf2e60b",
            openmoji: "17.0.0 f9fc506a3f913be9897ab0181d611d4c910a4104",
            noto: "v2.051 8998f5dd683424a73e2314a8c1f1e359c19e8742"
            ,cldr: "48.2.0 bb334e8d6250c9363e957e131bf7e6d08ec72f91"
        }
    };
    fs.writeFileSync(path.join(stage, "manifest.json"), JSON.stringify(manifest, null, 2) + "\n");

    const emojiRoot = path.join(projectRoot, "emoji");
    for (const style of ["twemoji", "openmoji", "noto"]) {
        const target = path.join(emojiRoot, style);
        fs.rmSync(target, { recursive: true, force: true });
        fs.renameSync(path.join(stage, style), target);
    }
    fs.copyFileSync(dataStage, path.join(projectRoot, "layouts", "FutoEmojiData.js"));
    fs.copyFileSync(path.join(stage, "manifest.json"), path.join(emojiRoot, "manifest.json"));
    fs.rmSync(stage, { recursive: true, force: true });

    process.stdout.write(JSON.stringify(manifest, null, 2) + "\n");
}

main().catch((error) => {
    process.stderr.write(String(error.stack || error) + "\n");
    process.exit(1);
});
