/* Validate the generated Emoji 17 data and every packaged style asset. */
const fs = require("fs");
const path = require("path");
const vm = require("vm");
const zlib = require("zlib");

const root = path.resolve(__dirname, "..");
const sourcePath = path.join(root, "layouts", "FutoEmojiData.js");
const searchSourcePath = path.join(root, "layouts", "FutoEmojiSearchData.json.gz");
const manifest = JSON.parse(fs.readFileSync(path.join(root, "emoji", "manifest.json"), "utf8"));
const source = fs.readFileSync(sourcePath, "utf8").replace(/^\.pragma library\r?\n/, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context, { filename: sourcePath });
const searchEntries = JSON.parse(zlib.gunzipSync(fs.readFileSync(searchSourcePath)));

function standardFold(value) {
    return String(value).toLowerCase().replace(/\u0307/g, "");
}

function turkishFold(value) {
    return String(value).replace(/I/g, "ı").replace(/İ/g, "i")
        .toLowerCase().replace(/\u0307/g, "");
}

function search(query, languages) {
    const rawQuery = String(query).trim();
    const selected = languages && languages.length ? languages : ["EN"];
    return searchEntries.filter((entry) => selected.some((language) => {
        const fold = language === "TR" ? turkishFold : standardFold;
        let searchable = "";
        if (language === "EN" || language === "EN_GB")
            searchable += " " + entry.n;
        if (entry.l && entry.l[language])
            searchable += " " + entry.l[language];
        return fold(rawQuery).split(/\s+/).every((word) => fold(searchable).includes(word));
    })).map((entry) => entry.c);
}

function assert(condition, message) {
    if (!condition)
        throw new Error(message);
}

assert(context.categories.length === 9, "Expected nine emoji categories");
const entries = context.categories.reduce((all, category) => all.concat(category), []);
assert(entries.length === manifest.baseGridEntries, "Base-grid count differs from manifest");

const codes = new Set();
let variantCount = 0;
for (const entry of entries) {
    assert(entry.t && entry.c, "Emoji entry is missing text or code");
    assert(!codes.has(entry.c), "Duplicate base code: " + entry.c);
    codes.add(entry.c);
    for (const variant of entry.v || []) {
        assert(variant.t && variant.c, "Tone variant is missing text or code");
        assert(!codes.has(variant.c), "Duplicate variant code: " + variant.c);
        codes.add(variant.c);
        variantCount++;
    }
}

assert(variantCount === manifest.skinToneVariants, "Tone-variant count differs from manifest");
assert(codes.size === manifest.userFacingSequences, "Not every Emoji 17 sequence is reachable");
assert(searchEntries.length === entries.length,
       "Search index count differs from the visual catalogue");
for (const query of ["happy", "dog", "pizza", "train", "football", "light bulb", "heart", "flag netherlands"])
    assert(search(query, ["EN"]).length > 0,
           "Search returned no matches for: " + query);

const englishBeer = search("beer", ["EN"]);
const dutchBeer = search("beer", ["NL"]);
const bilingualBeer = search("beer", ["EN", "NL"]);
assert(englishBeer.includes("1f37a"), "English beer search did not find the beer mug");
assert(!englishBeer.includes("1f43b"), "English beer search incorrectly found the bear");
assert(dutchBeer.includes("1f43b"), "Dutch beer search did not find the bear");
assert(!dutchBeer.includes("1f37a"), "Dutch beer search incorrectly found the beer mug");
assert(bilingualBeer.includes("1f37a") && bilingualBeer.includes("1f43b"),
       "English + Dutch beer search must find both beer and bear");

const turkishBear = search("ayı", ["TR"]);
const turkishUpperBear = search("AYI", ["TR"]);
assert(turkishBear.includes("1f43b"), "Turkish ayı search did not find the bear");
assert(turkishUpperBear.includes("1f43b"),
       "Turkish locale-aware I/ı folding did not find the bear");
assert(standardFold("İ") === "i",
       "Standard İ folding retained a combining dot");
assert(turkishFold("Iİıi") === "ıiıi",
       "Turkish I/İ/ı/i folding is incorrect");

for (const style of ["twemoji", "openmoji", "noto"]) {
    const extension = style === "noto" ? ".png" : ".svg";
    const directory = path.join(root, "emoji", style);
    const files = fs.readdirSync(directory).filter((name) => path.extname(name) === extension);
    assert(files.length === manifest.assetFilesPerStyle,
           style + " contains " + files.length + " assets");
    for (const code of codes) {
        const file = path.join(directory, code + extension);
        assert(fs.existsSync(file) && fs.statSync(file).size > 0,
               "Missing or empty " + style + " asset: " + code);
    }
}

process.stdout.write("Emoji 17 validation passed: " + entries.length + " base entries + "
                    + variantCount + " tone variants = " + codes.size + " sequences.\n");
