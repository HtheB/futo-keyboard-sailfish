/* Validate the generated Emoji 17 data and every packaged style asset. */
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const root = path.resolve(__dirname, "..");
const sourcePath = path.join(root, "layouts", "FutoEmojiData.js");
const manifest = JSON.parse(fs.readFileSync(path.join(root, "emoji", "manifest.json"), "utf8"));
const source = fs.readFileSync(sourcePath, "utf8").replace(/^\.pragma library\r?\n/, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context, { filename: sourcePath });

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
    assert(entry.t && entry.c && entry.n, "Emoji entry is missing text, code, or search data");
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
for (const query of ["happy", "dog", "pizza", "train", "football", "light bulb", "heart", "flag netherlands"])
    assert(context.search(query, ["EN"]).length > 0, "Search returned no matches for: " + query);

const englishBeer = context.search("beer", ["EN"]).map((entry) => entry.c);
const dutchBeer = context.search("beer", ["NL"]).map((entry) => entry.c);
const bilingualBeer = context.search("beer", ["EN", "NL"]).map((entry) => entry.c);
assert(englishBeer.includes("1f37a"), "English beer search did not find the beer mug");
assert(!englishBeer.includes("1f43b"), "English beer search incorrectly found the bear");
assert(dutchBeer.includes("1f43b"), "Dutch beer search did not find the bear");
assert(!dutchBeer.includes("1f37a"), "Dutch beer search incorrectly found the beer mug");
assert(bilingualBeer.includes("1f37a") && bilingualBeer.includes("1f43b"),
       "English + Dutch beer search must find both beer and bear");

const turkishBear = context.search("ayı", ["TR"]).map((entry) => entry.c);
const turkishUpperBear = context.search("AYI", ["TR"]).map((entry) => entry.c);
assert(turkishBear.includes("1f43b"), "Turkish ayı search did not find the bear");
assert(turkishUpperBear.includes("1f43b"),
       "Turkish locale-aware I/ı folding did not find the bear");
assert(context.standardFold("İ") === "i", "Standard İ folding retained a combining dot");
assert(context.turkishFold("Iİıi") === "ıiıi", "Turkish I/İ/ı/i folding is incorrect");

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
