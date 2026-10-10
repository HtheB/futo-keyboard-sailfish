#!/usr/bin/env node
"use strict";
const assert = require("assert"), fs = require("fs"), path = require("path"), vm = require("vm");
const root = path.resolve(__dirname, "..");
function load(file, globals = {}) {
    vm.runInNewContext(fs.readFileSync(path.join(root, "layouts", file), "utf8")
        .replace(/^\.pragma .*$/gm, "").replace(/^\.import .*$/gm, ""), globals);
    return globals;
}
const Generated = load("FutoGeneratedLayouts.js"), Catalogue = load("FutoLanguageCatalogue.js");
const layouts = load("FutoLetterLayouts.js", {Generated, Catalogue});
const published = require("../content/layout-order.json");
assert.deepStrictEqual(Array.from(Generated.layouts.slice(0, published.generatedIds.length), item => item.id), published.generatedIds);
assert.deepStrictEqual(JSON.parse(JSON.stringify(layouts.pre071Defaults)), published.pre071Defaults);
for (let index = 0; index < layouts.count; index++)
    assert.strictEqual(layouts.indexForId(layouts.idForIndex(index)), index);
const qml = fs.readFileSync(path.join(root, "layouts/FutoQwertyLayout.qml"), "utf8");
const start = qml.indexOf("function ensureLayoutAssignments(");
const end = qml.indexOf("function configuredLayoutGroups(", start);
function migrate(codes, assignments, identities = {}, manual = {}) {
    const settings = {layoutAssignments: JSON.stringify(assignments), layoutIds: JSON.stringify(identities),
        manualLayoutAssignments: JSON.stringify(manual), layoutAssignmentVersion: 1, layoutDefaultsVersion: 3};
    const context = {layoutSettings: settings, LetterLayouts: layouts,
        enabledPredictionLanguages: () => codes, layoutAssignments: () => JSON.parse(settings.layoutAssignments),
        layoutIdentities: () => JSON.parse(settings.layoutIds),
        manualAssignmentFlags: () => JSON.parse(settings.manualLayoutAssignments), ensureActiveLetterLayout: () => {}};
    vm.runInNewContext(qml.slice(start, end), context);
    context.ensureLayoutAssignments();
    const once = JSON.stringify(settings);
    context.ensureLayoutAssignments();
    assert.strictEqual(JSON.stringify(settings), once, "migration must be idempotent");
    assert.strictEqual(settings.layoutAssignmentVersion, 2);
    return {assignments: JSON.parse(settings.layoutAssignments), identities: JSON.parse(settings.layoutIds)};
}
for (const code of Object.keys(published.pre071Defaults)) {
    for (const manual of [{}, {[code]: true}]) {
        const result = migrate([code], {[code]: published.pre071Defaults[code]}, {}, manual);
        assert.strictEqual(result.assignments[code], layouts.defaultForLanguage(code), code + " old default was not repaired");
        assert.strictEqual(result.identities[code], layouts.idForIndex(layouts.defaultForLanguage(code)));
    }
}
for (const language of Catalogue.languages) {
    const index = layouts.defaultForLanguage(language.code);
    assert.strictEqual(migrate([language.code], {[language.code]: index}).assignments[language.code], index,
        language.code + " current default changed");
    assert.strictEqual(migrate([language.code], {}).assignments[language.code], index);
}
assert.strictEqual(migrate(["DA"], {DA: 9}, {}, {DA: true}).assignments.DA, 9);
// An explicit ID disambiguates a deliberate Welsh choice from old Danish index 39.
assert.strictEqual(migrate(["DA"], {DA: 39}, {DA: "welsh_qwerty"}, {DA: true}).assignments.DA, 39);
assert.strictEqual(migrate(["EN"], {EN: 0, DA: 9}, {}, {DA: true}).identities.DA, "legacy-9");
assert.strictEqual(migrate(["DA"], {DA: 0}, {DA: "nordic"}).assignments.DA, layouts.defaultForLanguage("DA"));
console.log("Layout upgrade, stable identity and all language-default tests passed.");
