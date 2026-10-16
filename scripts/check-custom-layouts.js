#!/usr/bin/env node
"use strict";
const assert = require("assert"), fs = require("fs"), path = require("path"), vm = require("vm");
const root = path.resolve(__dirname, "..");
const editorWindow = fs.readFileSync(path.join(root, "editor", "main.qml"), "utf8");
assert(/^    allowedOrientations: Orientation\.LandscapeMask\s*$/m.test(editorWindow), "Editor window must remain landscape");
assert(/^    _defaultPageOrientations: Orientation\.LandscapeMask\s*$/m.test(editorWindow), "Native file-picker subpages must inherit landscape");
const editorIcon = fs.readFileSync(path.join(root, "qml", "FutoLayoutEditorIcon.qml"), "utf8");
assert(editorIcon.includes('"image://theme/icon-m-keyboard"') && editorIcon.includes('"image://theme/icon-m-edit"'), "Layout editor icon must use both native theme icons");
assert(editorIcon.includes('root.width * 0.54'), "Layout editor must use the selected smaller-pencil design");
const menuItem = fs.readFileSync(path.join(root, "qml", "FutoSettingsMenuItem.qml"), "utf8");
assert(menuItem.includes('property Component iconComponent') && menuItem.includes('visible: !customIcon.item'), "Custom menu icons must retain the ordinary icon fallback");
const toolSource = fs.readFileSync(path.join(root, "editor", "FutoEditorTool.qml"), "utf8");
const nativeIconBody = toolSource.match(/readonly property string themeIconName: \{([\s\S]*?)\n    \}/);
assert(nativeIconBody, "Missing native editor icon mapping");
const nativeIcon = new Function("actionId", nativeIconBody[1]);
for (const action of ["key-add", "key-remove", "duplicate", "gap", "row-add", "row-remove", "up", "down", "page-add", "page-remove", "left", "right", "back", "clear", "width-increase", "width-decrease"])
    assert(/^icon-m-/.test(nativeIcon(action)), "Editor action must use a Sailfish theme icon: " + action);
function load(file, imports = {}) {
    const context = {...imports}; vm.createContext(context);
    vm.runInContext(fs.readFileSync(path.join(root, "layouts", file), "utf8").replace(/^\.(?:pragma|import).*$/gm, ""), context);
    return context;
}
const DeadKeys = load("FutoDeadKeyData.js");
const Custom = load("FutoCustomLayouts.js", {DeadKeys});
const Symbols=load("FutoSymbolData.js");
const CharacterContext={Symbols}; vm.createContext(CharacterContext);
vm.runInContext(fs.readFileSync(path.join(root,"editor","FutoEditorCharacters.js"),"utf8").replace(/^\.(?:pragma|import).*$/gm,""),CharacterContext);
assert(CharacterContext.characters(0).includes("ö") && CharacterContext.characters(0).includes("ë"));
assert(CharacterContext.characters(4).includes("\u0301"));
assert.equal(CharacterContext.display("\u0301"),"◌́");
for(let i=0;i<CharacterContext.categories.length;i++)
    for(const value of CharacterContext.characters(i)) assert(Custom.textValid(value,64,false),"Invalid picker character");
assert.equal(Custom.keyLabel(Custom.key("spacer")),"");
assert.equal(Custom.keyLabel(Custom.key("spacer","",1,"My label")),"My label");
for(const action of ["text","space","enter","backspace","spacer"]) {
    for(const style of ["auto","plain","button"]) {
        const key=Custom.key(action,"a"); key.style=style;
        for(const separated of [false,true])
            assert.equal(Custom.showsCard(key,separated),action!=="spacer" && style!=="plain" && (style==="button" || action==="space" || action==="text"&&separated));
    }
}
const Generated = load("FutoGeneratedLayouts.js"), Catalogue = load("FutoLanguageCatalogue.js");
const Layouts = load("FutoLetterLayouts.js", {Custom, Generated, Catalogue});
const id = "custom-" + "1".repeat(32), otherId = "custom-" + "2".repeat(32);
const layout = Custom.blank("My layout"); layout.id = id;
layout.pages[0].rows = [[Custom.key("text", "e", 1), Custom.key("text", "ö", 2)],
    [Custom.key("page", "", 1, "123", "numbers"), Custom.key("backspace"), Custom.key("backspace")]];
layout.pages.push(Custom.newPage("numbers", "123", "symbols"));
assert(Custom.valid(layout, true));
assert(Layouts.setCustomLayouts(JSON.stringify({version: 1, layouts: [layout]})));
assert.equal(Layouts.idForIndex(Layouts.builtinCount), id);
assert.equal(Layouts.name(Layouts.builtinCount), "My layout (Custom)");
assert.equal(Layouts.idForIndex(0), "legacy-0");
for (const entry of Catalogue.languages) {
    const code = entry.code;
    const offered = Layouts.compatibleIndices(code).some(i => Layouts.idForIndex(i) === id);
    assert.equal(offered, true, "Custom layout visibility: " + code);
    assert.equal(Layouts.imeHint(Layouts.builtinCount, code), ["JA", "ZH", "ZH_HANT"].includes(code) ? "qwerty" : "",
        "Custom conversion follows the selected language: " + code);
}
const second=Custom.clone(layout); second.id=otherId;
assert(Layouts.setCustomLayouts(JSON.stringify({version:1,layouts:[second,layout]})));
assert.equal(Layouts.indexForId(id), Layouts.builtinCount+1);
assert(Layouts.setCustomLayouts(JSON.stringify({version:1,layouts:[layout]})));
assert.equal(Layouts.indexForId(id), Layouts.builtinCount);
assert.equal(Layouts.indexForId(otherId), -1);
const originalCollection = JSON.stringify({version: 1, layouts: [layout, second]});
const remainingCollection = JSON.stringify({version: 1, layouts: [second]});
for (const entry of Catalogue.languages) {
    assert(Layouts.setCustomLayouts(originalCollection));
    const assignments = {[entry.code]: Layouts.indexForId(id)};
    const identities = {[entry.code]: id};
    assert(Layouts.setCustomLayouts(remainingCollection));
    assert.equal(Layouts.assignedIndex(entry.code, assignments, identities),
        Layouts.defaultForLanguage(entry.code), "Deleted layout must restore the language default: " + entry.code);
    assert.equal(Layouts.assignedIndex(entry.code, {[entry.code]: Layouts.builtinCount + 1}, {[entry.code]: otherId}),
        Layouts.builtinCount, "Surviving custom layout must keep its identity: " + entry.code);
}

const keyboardSource = fs.readFileSync(path.join(root, "layouts", "FutoQwertyLayout.qml"), "utf8");
function keyboardFunction(name) {
    const start = keyboardSource.indexOf("    function " + name + "(");
    assert(start >= 0, "Missing keyboard function: " + name);
    for (let end = keyboardSource.indexOf("}", start); end >= 0; end = keyboardSource.indexOf("}", end + 1)) {
        const block = keyboardSource.slice(start, end + 1);
        try { new vm.Script(block); return block; } catch (error) {
            if (!(error instanceof SyntaxError)) throw error;
        }
    }
    throw new Error("Missing keyboard function end: " + name);
}
for (const active of [id, otherId]) {
    assert(Layouts.setCustomLayouts(originalCollection));
    const settings = {
        enabledLanguages: "EN,AR,NL", manualPredictionLanguage: active === id ? "AR" : "NL",
        layoutVariant: Layouts.indexForId(active), customLayoutsJson: originalCollection,
        layoutAssignments: JSON.stringify({EN: 0, AR: Layouts.indexForId(id), NL: Layouts.indexForId(otherId), TR: Layouts.indexForId(id)}),
        layoutIds: JSON.stringify({EN: "legacy-0", AR: id, NL: otherId, TR: id}),
        manualLayoutAssignments: JSON.stringify({EN: true, AR: true, NL: true, TR: true}),
        layoutAssignmentVersion: 2, layoutDefaultsVersion: 3
    };
    const context = {
        LetterLayouts: Layouts, layoutSettings: settings, handler: {detectedLanguage: settings.manualPredictionLanguage},
        layoutConfigurationReady: true, customLayoutRevision: 0, loadedCustomLayoutsJson: originalCollection,
        rowRelayoutTimer: {restart() {}}, languagesShareActiveLayout: false, compositionHint: ""
    };
    Object.defineProperty(context, "layoutVariant", {get() { return Layouts.clampedIndex(settings.layoutVariant); }});
    context.root = context;
    vm.createContext(context);
    for (const name of ["reloadCustomLayouts", "layoutAssignments", "layoutIdentities", "manualAssignmentFlags",
        "layoutForLanguage", "enabledPredictionLanguages", "languagesForLayout", "selectedPredictionLanguage", "layoutHasConversionLanguages",
        "configuredLayoutGroups", "ensureLayoutAssignments", "ensureActiveLetterLayout", "synchronizeDetectedLanguage"])
        vm.runInContext(keyboardFunction(name), context);
    context.reloadCustomLayouts(remainingCollection);
    const assignments = JSON.parse(settings.layoutAssignments), identities = JSON.parse(settings.layoutIds);
    assert.equal(assignments.AR, Layouts.defaultForLanguage("AR"));
    assert.equal(identities.AR, Layouts.idForIndex(Layouts.defaultForLanguage("AR")));
    assert.equal(assignments.TR, Layouts.defaultForLanguage("TR"), "Disabled languages must be repaired too");
    assert.equal(assignments.EN, 0, "Other built-in choices stay unchanged");
    assert.equal(identities.NL, otherId, "Other custom choices stay unchanged");
    assert.equal(assignments.NL, Layouts.indexForId(otherId), "Surviving numeric indices are updated");
    assert.equal(settings.layoutVariant, active === id ? Layouts.defaultForLanguage("AR") : Layouts.indexForId(otherId),
        "The active keyboard must follow its selected language, not the first enabled language");
    assert.equal(settings.manualPredictionLanguage, active === id ? "AR" : "NL");
    assert.equal(settings.enabledLanguages, "EN,AR,NL", "Language and dictionary selections stay unchanged");
    context.reloadCustomLayouts(JSON.stringify({version: 1, layouts: [second, layout]}));
    assert.equal(JSON.parse(settings.layoutIds).AR, identities.AR, "Reimporting a layout must not revive a deleted assignment");
}
for (const merge of [false, true]) {
    assert(Layouts.setCustomLayouts(originalCollection));
    const codes = ["EN", "NL", "JA", "ZH", "ZH_HANT"], index = Layouts.indexForId(id);
    const settings = {enabledLanguages: codes.join(","), manualPredictionLanguage: "EN", layoutVariant: index,
        layoutAssignments: JSON.stringify(Object.fromEntries(codes.map(code => [code, index]))),
        layoutIds: JSON.stringify(Object.fromEntries(codes.map(code => [code, id]))), manualLayoutAssignments: "{}"};
    const context = {LetterLayouts: Layouts, layoutSettings: settings, languagesShareActiveLayout: merge,
        LanguageData: {name: code => code, predictionSupported: code => !["JA", "ZH", "ZH_HANT"].includes(code)},
        handler: {detectedLanguage: "EN", cancelSwipeSession() {}}, layoutConfigurationReady: true};
    context.root = context;
    Object.defineProperty(context, "layoutVariant", {get: () => settings.layoutVariant});
    Object.defineProperty(context, "separateLayoutLanguages", {get: () => !merge || context.layoutHasConversionLanguages(settings.layoutVariant)});
    vm.createContext(context);
    for (const name of ["layoutAssignments", "layoutIdentities", "manualAssignmentFlags", "layoutForLanguage",
        "enabledPredictionLanguages", "languagesForLayout", "selectedPredictionLanguage", "layoutHasConversionLanguages",
        "configuredLayoutGroups", "languageNamesForLayout", "predictionLanguagesForLayout", "languageSwitchEntries",
        "currentLanguageSwitchIndex", "applyLanguageSwitchEntry", "synchronizeDetectedLanguage", "applyLayoutAssignment"])
        vm.runInContext(keyboardFunction(name), context);
    const entries = context.languageSwitchEntries();
    assert.equal(entries.map(entry => entry.code).join(), codes.join(), "Conversion languages remain individually selectable, merge=" + merge);
    for (let i = 0; i < entries.length; i++) {
        context.applyLanguageSwitchEntry(entries[i]);
        assert.equal(context.selectedPredictionLanguage(index), codes[i]);
        assert.equal(context.handler.detectedLanguage, codes[i]);
        assert.equal(context.currentLanguageSwitchIndex(), i);
        assert.equal(context.predictionLanguagesForLayout(index), i < 2 ? codes[i] : "", "Ordinary dictionaries must not replace conversion candidates");
    }
    context.applyLayoutAssignment("JA", index);
    assert.equal(context.selectedPredictionLanguage(index), "JA", "Assigning a shared layout selects the requested conversion language");
    settings.enabledLanguages = "EN,NL";
    settings.manualPredictionLanguage = "NL";
    context.handler.detectedLanguage = "NL";
    assert.equal(context.layoutHasConversionLanguages(index), false);
    assert.equal(context.languageSwitchEntries().length, merge ? 1 : 2, "Ordinary language merging stays available");
    assert.equal(context.predictionLanguagesForLayout(index), merge ? "EN,NL" : "NL");
}
{
    const callbacks = [], document = Custom.fromBuiltin(0, Layouts);
    let cleared = 0, cancelled = 0;
    const context = {CustomLayouts: Custom, customDocument: document, customPageId: "letters",
        handler: {finishConversion: callback => callbacks.push(callback), clearCustomDeadKey: () => cleared++, cancelSwipeSession: () => cancelled++}};
    context.root = context; vm.createContext(context);
    for (const name of ["activateCustomAction", "applyCustomPage"])
        vm.runInContext(keyboardFunction(name), context);
    context.activateCustomAction({action: "page", target: "numbers"});
    assert.equal(context.customPageId, "letters", "A custom page switch waits for unfinished conversion to commit");
    callbacks.shift()();
    assert.equal(context.customPageId, "numbers");
    assert.equal(cleared, 1); assert.equal(cancelled, 1);
    context.activateCustomAction({action: "page", target: "symbols"});
    context.customDocument = Custom.clone(document);
    callbacks.shift()();
    assert.equal(context.customPageId, "numbers", "An old conversion callback cannot change a replacement layout");
}
assert(Layouts.setCustomLayouts(JSON.stringify({version: 1, layouts: [layout]})));
for (const [dead,base,result] of [["`","e","è"],["'","e","é"],["¨","u","ü"],["'","Ε","Έ"],["\u0308","Е","Ё"],["'"," ","'"],["'","'","'"],["^","x","^x"]])
    assert.equal(Custom.compose(dead,base),result,dead+base);
for (const gap of [0,160]) {
    const boxes=Custom.geometry(layout.pages[0].rows,800,300,gap);
    for (let row=0;row<2;row++) {
        const cells=boxes.filter(b=>b.row===row);
        assert(Math.abs(cells.reduce((sum,b)=>sum+b.width,0)-(800-gap))<0.001);
        for (let i=0;i<cells.length;i++) {
            assert(cells[i].x>=0 && cells[i].x+cells[i].width<=800.001);
            if (i) assert(cells[i].x>=cells[i-1].x+cells[i-1].width-0.001);
            if(gap) assert(cells[i].x+cells[i].width<=320.001 || cells[i].x>=480);
        }
    }
}
const moved=Custom.clone(layout);
assert(Custom.move(moved,0,0,0,1,1));
assert.equal(moved.pages[0].rows[1][1].output,"e");
assert.equal(Custom.move(moved,0,0,0,1,0),null);
const invalids=[l=>l.pages[0].rows[0][0].action="exec",l=>l.pages[0].rows[0][0].width=0,
    l=>l.pages[0].rows[0][0].output="\u0000",l=>l.pages[0].rows[0][0].output="\ud800",
    l=>l.pages[0].rows[0][0].shifted="\u0000",l=>l.pages[0].rows[0][0].defaultMore=1,
    l=>l.pages[0].rows[0][0].defaultMore=0.5,l=>l.pages[0].rows[0][0].dead=true && (l.pages[0].rows[0][0].output="ab"),
    l=>l.pages[0].rows[1][0].target="missing",l=>l.pages[0].rows[0][0].style="script"];
for(const invalidate of invalids) {const item=Custom.clone(layout);invalidate(item);assert(!Custom.valid(item,true));}
let templates=0;
for(let i=0;i<Layouts.builtinCount;i++) {
    const template=Custom.fromBuiltin(i,Layouts);
    if(Layouts.imeHint(i) && Layouts.imeHint(i)!=="qwerty") {assert.equal(template,null);continue;}
    assert(Custom.valid(template,false),"Invalid template: "+Layouts.name(i));
    assert(template.pages[0].rows.some(row=>row.some(k=>k.action==="backspace")),"Missing Backspace: "+Layouts.name(i));
    templates++;
}
function qmlFunction(source, name) {
    const start = source.indexOf("    function " + name + "(");
    assert(start >= 0, "Missing editor function: " + name);
    for (let end = source.indexOf("}", start); end >= 0; end = source.indexOf("}", end + 1)) {
        const block = source.slice(start, end + 1);
        try { new vm.Script(block); return block; } catch (error) {
            if (!(error instanceof SyntaxError)) throw error;
        }
    }
    throw new Error("Unterminated editor function: " + name);
}
const pageEditorSource = fs.readFileSync(path.join(root, "editor", "FutoEditorPage.qml"), "utf8");
function pageEditor() {
    const context = {Custom, document: Custom.blank(), pageIndex: 0, selectedRow: 0, selectedColumn: 0,
        revision: 0, dirty: false, message: "", undoStack: [], redoStack: [], pagePickerOpen: true,
        pagePicker: {cancelInteractions() {}}, properties: {contentY: 80}, forceActiveFocus() {}, qsTr: text => text,
        Date: {now: () => 123456}};
    context.document.pages.push(Custom.newPage("numbers", "123", "symbols"), Custom.newPage("functions", "Fn", "function"));
    context.document.pages[0].rows[0].push(Custom.key("page", "", 1, "123", "numbers"));
    Object.defineProperty(context, "pageData", {get() { return context.document.pages[context.pageIndex]; }});
    vm.createContext(context);
    for (const name of ["remember", "changed", "indexForPage", "select", "addPage", "deletePage", "movePage", "undo", "choosePage"])
        vm.runInContext(qmlFunction(pageEditorSource, name), context);
    return context;
}
{
    const editor = pageEditor();
    editor.pageIndex = 1; editor.selectedColumn = 1;
    editor.movePage("letters", 2);
    assert.equal(editor.pageData.id, "numbers", "Reordering preserves the selected page by ID");
    assert.equal(editor.selectedColumn, 1, "Reordering preserves key selection");
    assert.equal(editor.undoStack.length, 1, "Each drag is one undo step");
    assert.equal(editor.document.pages.map(page => page.id).join(), "numbers,functions,letters");
    editor.undo(false);
    assert.equal(editor.pageData.id, "numbers");
    assert.equal(editor.document.pages[0].id, "letters");
    editor.undo(true);
    assert.equal(editor.document.pages[2].id, "letters");
    const before = JSON.stringify(editor.document), count = editor.undoStack.length;
    editor.movePage("absent", 0); editor.movePage("letters", 2); editor.movePage("letters", -1); editor.movePage("letters", 3);
    assert.equal(JSON.stringify(editor.document), before); assert.equal(editor.undoStack.length, count);
    editor.choosePage("functions");
    assert.equal(editor.pageData.id, "functions"); assert.equal(editor.pagePickerOpen, false);
    assert.equal(editor.properties.contentY, 0); assert.equal(editor.undoStack.length, count);
}
for (const selected of ["letters", "numbers", "functions"]) {
    for (const removed of ["letters", "numbers", "functions"]) {
        const editor = pageEditor(); editor.pageIndex = editor.indexForPage(selected);
        editor.deletePage(removed);
        assert.equal(editor.document.pages.length, 2);
        assert(Custom.valid(editor.document, false), "Deletion repairs page-switch destinations");
        if (selected !== removed) assert.equal(editor.pageData.id, selected);
        else assert.equal(editor.pageData.id, removed === "numbers" ? "functions" : "numbers");
        editor.undo(false);
        assert.equal(editor.document.pages.length, 3);
        assert.equal(editor.document.pages[0].rows[0][1].target, "numbers", "Undo restores original destinations");
    }
}
{
    const editor = pageEditor(); editor.deletePage("functions"); editor.deletePage("numbers");
    const count = editor.undoStack.length;
    editor.deletePage("letters"); editor.deletePage("absent");
    assert.equal(editor.document.pages.length, 1); assert.equal(editor.undoStack.length, count);
    while (editor.document.pages.length < 16) editor.addPage();
    assert.equal(new Set(editor.document.pages.map(page => page.id)).size, 16, "Rapid adds have unique IDs");
    assert(Custom.valid(editor.document, false));
    editor.addPage(); assert.equal(editor.document.pages.length, 16);
    editor.undo(false); assert.equal(editor.document.pages.length, 15);
    assert(editor.pageIndex < 15, "Undo of an added page keeps selection in range");
}
const pickerSource = fs.readFileSync(path.join(root, "editor", "FutoEditorPagePicker.qml"), "utf8");
{
    const callbacks = [], deleted = [];
    let cancels = 0;
    const context = {active: true, pages: [{id: "a"}, {id: "b"}], dragging: false, settling: false,
        pendingDeleteId: "", pendingRemorse: null, deleteRequestSerial: 0, qsTr: text => text,
        deleteRequested(id) { deleted.push(id); },
        Remorse: {itemAction(row, text, callback) { callbacks.push(callback); return {cancel() { cancels++; }}; }}};
    context.picker = context; vm.createContext(context);
    for (const name of ["cancelDeletion", "requestDeletion"]) vm.runInContext(qmlFunction(pickerSource, name), context);
    context.requestDeletion("a", {}); assert.equal(context.pendingDeleteId, "a");
    context.cancelDeletion(); callbacks[0](); assert.equal(deleted.length, 0);
    context.requestDeletion("a", {}); callbacks[0]();
    assert.equal(deleted.length, 0, "An older canceled callback cannot delete a newly requested page with the same ID");
    callbacks[1](); assert.equal(deleted.join(), "a");
    assert.equal(context.pendingDeleteId, ""); assert.equal(context.pendingRemorse, null);
    assert.equal(cancels, 1);
    context.active = false; context.requestDeletion("b", {}); assert.equal(callbacks.length, 2);
    context.active = true; context.pages = [{id: "b"}]; context.requestDeletion("b", {}); assert.equal(callbacks.length, 2);
}
{
    const rows = [{pageId: "a", pageName: "ABC"}, {pageId: "b", pageName: "123"}, {pageId: "c", pageName: "Fn"}];
    const original = rows.slice();
    const context = {pages: [{id: "c", name: "Function keys"}, {id: "a", name: "Letters"}, {id: "d", name: "New"}],
        dragging: false, cancelDeletion() {}, pageModel: {get count() { return rows.length; }, get: i => rows[i],
            insert(i, row) { rows.splice(i, 0, row); }, move(i, target) { rows.splice(target, 0, rows.splice(i, 1)[0]); },
            setProperty(i, key, value) { rows[i][key] = value; }, remove(i, count) { rows.splice(i, count); }}};
    vm.createContext(context); vm.runInContext(qmlFunction(pickerSource, "synchronize"), context);
    context.synchronize();
    assert.equal(rows.map(row => row.pageId).join(), "c,a,d");
    assert.strictEqual(rows[0], original[2]); assert.strictEqual(rows[1], original[0], "Updates retain delegates instead of clearing the list");
    assert.equal(rows[0].pageName, "Function keys");
}
for (const origin of [-120, 0, 120]) {
    const moves = [];
    const context = {dragging: true, pointerY: 100, grabY: 50, rowHeight: 100, draggedIndex: 0, floatingRow: {},
        pageList: {contentY: origin, originY: origin, mapToItem() { return {y: 50}; }},
        pageModel: {count: 4, move(from, to) { moves.push([from, to]); }}};
    context.picker = context; vm.createContext(context); vm.runInContext(qmlFunction(pickerSource, "updateDrag"), context);
    context.updateDrag(225); assert.equal(context.draggedIndex, 1);
    context.updateDrag(100); assert.equal(context.draggedIndex, 0);
    assert.equal(context.floatingRow.y, 50, "Dragged row follows the exact pointer offset");
    assert.equal(moves.length, 2);
}
console.log(`Custom layouts passed: ${templates} templates, global choices, stable IDs, bounded geometry, page targets, page management and Unicode dead keys.`);
