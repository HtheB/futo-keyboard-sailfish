const fs = require("fs");
const vm = require("vm");
const path = require("path");
const assert = require("assert");
const flick = {};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, "../layouts/FutoFlickGesture.js"), "utf8")
    .replace(/^\.pragma library\s*/m, ""), flick);
const choices = {primary: {}, left: {}, up: {}, right: {}, down: {}};
for (const [x, y, expected] of [[0, 0, "primary"], [19, 19, "primary"],
    [-25, 0, "left"], [0, -25, "up"], [25, 0, "right"], [0, 25, "down"],
    [-55, 20, "left"], [12, -70, "up"]]) {
    assert.strictEqual(flick.direction(x, y, 20, choices), expected);
}
assert.strictEqual(flick.direction(100, 0, 20, {primary: {}}), "primary");
assert.strictEqual(flick.displayedCaption({caption: "こ"}), "こ");
assert.strictEqual(flick.displayedCaption(null), "");
assert.strictEqual(flick.isKanaModifier({caption: "!icon/japanese_key"}), true);
assert.strictEqual(flick.isKanaModifier({caption: "あ"}), false);
assert.strictEqual(flick.isKanaModifier(null), false);
assert.strictEqual(flick.isKanaPunctuation({caption: "、", output: "#"}), true);
assert.strictEqual(flick.isKanaPunctuation({caption: "、", output: "、"}), false);
assert.strictEqual(flick.isKanaPunctuation({caption: "。", output: ","}), false);
assert.strictEqual(flick.isKanaPunctuation(null), false);
const layout = fs.readFileSync(path.join(__dirname, "../layouts/FutoQwertyLayout.qml"), "utf8");
assert(/onRenderedLayoutVariantChanged:\s*rowRelayoutTimer\.restart\(\)/.test(layout),
    "ABC must relayout the rendered rows, not only change their labels");
const panel = fs.readFileSync(path.join(__dirname, "../layouts/FutoJapaneseFlickPanel.qml"), "utf8");
assert.strictEqual((panel.match(/FutoKanaModifierLabel\s*\{/g) || []).length, 2,
    "the modifier key and popup must share the compact stacked mark");
assert.strictEqual((panel.match(/FutoKanaPunctuationLabel\s*\{/g) || []).length, 1,
    "only the key combines punctuation; popup choices retain their individual labels");
const modifier = fs.readFileSync(path.join(__dirname, "../layouts/FutoKanaModifierLabel.qml"), "utf8");
const punctuation = fs.readFileSync(path.join(__dirname, "../layouts/FutoKanaPunctuationLabel.qml"), "utf8");
for (const [name, source] of [["modifier", modifier], ["punctuation", punctuation]]) {
    assert(/Icon\s*\{/.test(source) && /anchors\.centerIn:\s*parent/.test(source)
        && !/Label\s*\{/.test(source),
        "the " + name + " mark must use one centred icon, without font-bearing offsets");
    assert(source.includes("icon-m-kana-" + name + ".svg"));
    assert(fs.existsSync(path.join(__dirname, "../assets/icons/icon-m-kana-" + name + ".svg")));
}
assert((panel.match(/fontSizeMode:\s*Text\.Fit/g) || []).length >= 2,
    "kana labels must fit their key and popup bounds");
assert(panel.includes('holdActionOverride: cell.actionName === "emoji" ? 2 : 1'),
    "kana flick must put language hold on Emoji and cursor hold on all of Space");
assert(panel.includes('alternateTapEnabled: cell.actionName === "emoji"')
    && panel.includes('onAlternateTapped: panel.action("emoji")'),
    "a short Emoji tap must open the picker, not insert a space");
assert(panel.includes("width: Math.min(parent.width * 0.46, Theme.iconSizeMedium)"),
    "the kana Space mark should be wide and scale with its key");
assert(panel.includes("anchors.verticalCenterOffset: parent.height * 0.20"),
    "the kana Space mark should sit in the lower third of the key");
const pickerRow = layout.slice(layout.indexOf("id: pickerSpacebarRow"));
assert(pickerRow.includes("property int avoidanceWidth: root.thumbLandscapeMode ? root.avoidanceWidth : 0")
    && pickerRow.includes("splitIndex: 2")
    && pickerRow.includes("active: root.thumbLandscapeMode"),
    "picker Space must fill portrait's bottom row, and occupy both landscape thumb halves");
const space = fs.readFileSync(path.join(__dirname, "../layouts/FutoSpacebarKey.qml"), "utf8");
assert(space.includes("ownerLayout.languageSwitchEntries().length > 1"),
    "language hold and its hint must only be offered for multiple choices");
assert(space.includes("property int holdActionOverride: -1")
    && space.includes("property bool alternateTapEnabled: false"),
    "ordinary space keys must keep their configured actions and normal tap");
assert(space.includes("enabled: spaceKey.alternateTapEnabled || spaceKey.cursorControlOffered"),
    "Emoji taps must still open the picker when only one language is active");
assert(space.includes("endSpacebarGesture(spaceKey.alternateTapEnabled)"),
    "an Emoji tap must swallow the underlying Space key's release tail");
const key = fs.readFileSync(path.join(__dirname, "../layouts/FutoLayoutKey.qml"), "utf8");
assert(key.includes("implicitSeparator: cell.implicitSeparator"),
    "row-edge separator suppression must reach the visible character key");
assert(key.includes("targetLayout.thumbLetterKeyWidth"),
    "thumb Shift and Backspace must not squeeze the bottom letter row");
const letterRow = fs.readFileSync(path.join(__dirname, "../layouts/FutoLetterRow.qml"), "utf8");
assert(letterRow.includes("return targetLayout.thumbLetterKeyWidth"),
    "all thumb letter rows must use the same key width");
const widthBody = layout.match(/readonly property real thumbLetterKeyWidth:\s*\{([\s\S]*?)\n    \}/)[1];
function thumbWidth(lengths, thumbMode = true) {
    return vm.runInNewContext("(function() {" + widthBody + "})()", {
        thumbMode, japaneseFlickLayout: false, renderedLayoutVariant: 0,
        keyboardContentWidth: 1080, avoidanceWidth: 184,
        LetterLayouts: {rowCount: () => lengths.length, rowLength: (_, row) => lengths[row]}
    });
}
assert.strictEqual(thumbWidth([10, 9, 9]), 89.6); // QWERTY: Shift/Backspace are one unit too.
assert.strictEqual(thumbWidth([10, 9, 9], false), 0); // Full/one-hand sizing remains unchanged.
assert.strictEqual(thumbWidth([11, 11, 10]), 896 / 12); // Denser scripts also fit both halves.
assert(panel.includes("color: keyboard.popperBackgroundColor")
    && panel.includes("color: panel.palette.highlightBackgroundColor")
    && !panel.includes("? Theme.highlightBackgroundColor"),
    "kana key highlights and popups must use the ordinary keyboard palette");
process.stdout.write("Kana flick gesture tests passed.\n");
