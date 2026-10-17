#!/usr/bin/env node
"use strict";

// Run the production key/commit and asynchronous-reply handlers against an
// editor whose document and published Maliit state can update independently.
const assert = require("assert"), fs = require("fs"), path = require("path"), vm = require("vm");
const source = fs.readFileSync(path.resolve(__dirname, "../qml/FutoInputHandler.qml"), "utf8");
const Haptics = {};
vm.runInNewContext(fs.readFileSync(path.resolve(__dirname, "../qml/FutoHapticFeedback.js"), "utf8")
    .replace(/^\.pragma.*$/gm, ""), Haptics);
const noop = () => {};
function extract(name, signal = false) {
    const pattern = new RegExp("^([ \\t]*)" + (signal ? name + ": \\{" : "function " + name + "\\("), "m");
    const match = pattern.exec(source);
    assert(match, "Missing handler: " + name);
    for (let end = source.indexOf("}", match.index); end >= 0; end = source.indexOf("}", end + 1)) {
        let block = source.slice(match.index, end + 1);
        if (signal) block = block.replace(name + ": {", "function " + name + "() {");
        try { new vm.Script(block); return block; } catch (error) {
            if (!(error instanceof SyntaxError)) throw error;
        }
    }
    throw new Error("Missing handler end: " + name);
}
function setup(initial = "", position = initial.length, options = {}) {
    const requests = [], commits = [], keys = [], rows = [];
    let text = initial, cursor = position, selection = null;
    const timer = () => ({running: false, stop() { this.running = false; }, restart() { this.running = true; }, start() { this.running = true; }});
    const context = {
        active: true, activeEditor: true, passwordField: false, urlField: false, immediateCommitField: false,
        Haptics, customButtonVibration: {play: noop}, silencePressEffect: noop,
        preedit: "", preeditAlreadyCommitted: false, committedPreeditStart: -1, committedPreeditConfirmedCursor: -1,
        committedPreeditSending: false, editorContextSerial: 0, predictionEditorSerial: -1, inputActionSerial: 0,
        predictionActionSerial: -1,
        pendingSuggestionTap: null,
        pendingEditorStates: [], lastObservedEditorState: null, lastObservedSelection: false, lastObservedTextValid: false,
        requestSerial: 0, urlRequestSerial: 0, correctionQuery: "", correctionCandidate: "", nextWordMode: false,
        predictionRequestInFlight: false, pendingPredictionRequest: null,
        nextContextOverride: "", editingWord: "", editingWordStart: -1, editingWordLength: 0,
        urlSuggestionResultsActive: false, urlSuggestionFallbackActive: false, editorTypedBuffer: "",
        committedSpaceArmed: false, committedSpaceExpectedCursor: -1, candidateSpaceIndex: -1,
        undoCorrectionAvailable: false, undoOriginalWord: "", undoReplacementWord: "", undoCommittedSuffix: "",
        undoRestoredSuffix: "", undoCursorPosition: -1, activePredictionsAvailable: true,
        customPendingDeadKey: "", customPopupSource: null, customPopupDispatch: {customPopupAction: true}, activeDesktopModifiers: 0, spacebarGestureActive: false, swipeAutoSpacePending: false, swipeReplacementActive: false,
        swipePendingForcedInput: false, swipeLeadingSpaceForGesture: false, swipeOutstanding: 0, swipeRequestQueue: [],
        swipeBatchActionSerial: -1, swipeExpectedEditorState: null, swipeExpectedTextValid: false,
        swipeAwaitingEditor: false, swipeEditorWaitStarted: 0, swipeSessionSerial: 0, swipePath: [],
        detectedLanguage: "EN", privacySwitchActive: false, credentialAutofillStage: 0,
        credentialFieldCandidate: false, credentialUsernameField: false, credentialSavingPrivateBlocked: true,
        voiceRecording: false, passwordVaultBusy: false, incognitoMode: false,
        showUrlSuggestions: false, showApplicationSuggestions: false,
        keyboardSettings: {predictionEnabled: true, autoCorrectionEnabled: false, punctuationCorrectionEnabled: false,
            doubleSpacePeriodEnabled: false, smartPunctuationEnabled: false, spaceAfterPunctuationEnabled: false,
            swipeTypingEnabled: false, forcedAppSupportKeyEvents: false, undoCorrectionEnabled: false,
            autoSpaceAfterSuggestion: true, suggestionCount: 12, showTypedWord: true, correctionLevel: 0,
            nextWordPredictionEnabled: true, contextPredictionEnabled: true, automaticLanguageDetection: false,
            passwordSavingEnabled: false, autoCapitalizationEnabled: false, urlHistoryEnabled: false, keyVibrationMode: 2},
        Qt: {Key_Space: 32, Key_Backspace: 8, Key_Return: 13, Key_Enter: 14,
            Key_Escape: 27, Key_Left: 37, Key_Right: 39},
        ShiftState: {LockedShift: 3, LatchedShift: 2, NoShift: 0, AutoShift: 1},
        KeyType: {ShiftKey: 1, SymbolKey: 2, CharacterKey: 3, PopupKey: 4}, Maliit: {KeyClick: 0},
        keyboard: {shiftState: 0, autocaps: false, layout: {}, expandedPaste: false},
        predictionTimer: timer(), nextPredictionTimer: timer(), suggestionTapTimer: timer(), editorContextTimer: timer(),
        urlSuggestionTimer: timer(), swipeReleaseTimer: timer(), swipeEditorReadyTimer: timer(),
        committedPreeditReconcileTimer: timer(), passwordFocusProtectionTimer: timer(),
        Clipboard: {text: "pasted"},
        predictionModel: {get count() { return rows.length; }, get: i => rows[i], clear: () => rows.splice(0), append: row => rows.push(row)},
        suggestionsUpdated: noop, syncEditorTypedBuffer: noop, playAutomaticKeySound: noop, playOptionFeedback: noop,
        typingContinued: noop, captureEditorKey: noop, captureCredentialKey: noop, restorePressEffect: noop,
        handleArmedDesktopModifierKey: () => false, finishSwipeGesture: () => false,
        conversionEnabled: false, customPageAllowsSuggestions: true, conversion: {clear: noop}, handleConversionKey: () => false,
        refreshApplicationSuggestions: noop, credentialDebug: noop, credentialDebugContext: noop,
        refreshCredentialPlatform: noop, refreshAndroidKeyboardAutofill: noop, rememberCredentialContext: noop,
        refreshCredentialMatch: noop, endForcedAppSupportSession: noop,
        refreshWordSuggestionPreference: noop, learn: noop, learnSwipeCorrection: noop, learnWithPrevious: noop,
        enabledLanguages: () => "EN", learnCurrentUrl: noop, cancelVoiceInput: noop,
        helper: {typedCall(method, args, success, failure) { requests.push({method, args, success, failure}); return true; }},
        MInputMethodQuick: {surroundingText: initial, cursorPosition: position, surroundingTextValid: true,
            hasSelection: false, hiddenText: false, anchorPosition: position,
            actionKeyOverride: {label: "", icon: "", enabled: true}}
    };
    context.futoHandler = context;
    Object.defineProperty(context, "activeSuggestionQuery", {get: () => context.preedit || context.editingWord});
    vm.createContext(context);
    const names = ["clearCommittedSpace", "armCommittedSpace", "committedSpaceIsCurrent", "spaceImmediatelyBeforeCursor",
        "clearEditingWord", "clearCommittedPreedit", "committedPreeditMatchesEditor", "reconcileCommittedPreedit",
        "editorStateSnapshot", "sameEditorState", "acknowledgedEditorState", "editorStateForWrite", "recordEditorMutation",
        "sendEditorCommit", "sendEditorBackspace", "observeEditorContext", "editingWordMatchesEditor",
        "appendCommittedWordCharacter", "wordRangeAtCursor",
        "resetSuggestionDisplay", "requestSuggestionsSoon", "clearUndoCorrection", "undoLastCorrection",
        "wordStartBeforeReplacement", "lastWord", "contextBeforeCursor", "handleKeyClick", "insertWordCharacter", "commit",
        "clearCustomDeadKey", "typeCustomText", "handleCustomLayoutKey", "resolveCustomPopupKey",
        "isLetterCharacter", "isCombiningCharacter", "isInputCharacter", "smartPunctuationField",
        "spaceAfterPunctuationAllowed", "clearSwipeReplacementState", "resetSwipePath", "cancelSwipeSession",
        "discardPendingSwipeWord", "swipeSeparatorPrecedesKey", "insertPendingSwipeSeparator",
        "scheduleNextWords", "displayableSuggestion", "nonEmptySuggestions", "allowedWordSuggestion", "wordSuggestions",
        "replacePredictionSuggestions", "visiblePrimaryCorrection", "correctedWordForCommit", "requestSuggestions",
        "dispatchPredictionRequest", "finishPredictionRequest", "requestNextWords", "applyPrediction", "deletePreviousWord", "deletePreviousWords", "rawEditorText", "refreshEditingWord",
        "cancelPendingSuggestionTap", "deferSuggestionTap", "retryPendingSuggestionTap",
        "acceptSelectionCaseSuggestion",
        "swipeEditorUnchanged", "dispatchNextSwipe", "acceptPendingSwipeForNextGesture", "wordOpensAddress"];
    for (const name of names) vm.runInContext(extract(name), context);
    for (const name of ["onCursorPositionChanged", "onEditorStateUpdate", "onFocusTargetChanged", "onPaste", "onSelect"])
        vm.runInContext(extract(name, true), context);
    context.KeyboardSupport = {};
    context.punctuationAddressSchemes = ["http", "https", "mailto"];
    context.punctuationInsideAddress = () => false;
    context.swipeKeyAllowed = () => true;
    context.serializeSwipePath = () => "trace";
    context.swipeGeometry = () => "geometry";
    context.keyboard.layout.swipeGeometry = () => "geometry";
    const finishSwipe = vm.runInContext("(" + extract("finishSwipeGesture") + ")", context);
    function publish() {
        const editor = context.MInputMethodQuick;
        const cursorChanged = editor.cursorPosition !== cursor;
        editor.surroundingText = text; editor.cursorPosition = cursor;
        editor.anchorPosition = selection ? selection.start : cursor;
        editor.hasSelection = !!selection;
        if (cursorChanged) context.onCursorPositionChanged();
        context.onEditorStateUpdate();
    }
    context.MInputMethodQuick.sendCommit = (value, offset = 0, length = 0) => {
        commits.push({value, offset, length, cursor});
        const start = selection && offset === 0 && length === 0 ? selection.start : Math.max(0, cursor + offset);
        const count = selection && offset === 0 && length === 0 ? selection.end - selection.start : length;
        text = text.slice(0, start) + value + text.slice(start + count);
        cursor = start + value.length; selection = null;
        if (!options.delayed) publish();
    };
    context.MInputMethodQuick.sendKey = (key) => {
        keys.push(key);
        if (key === 8) {
            const start = selection ? selection.start : Math.max(0, cursor - 1);
            const end = selection ? selection.end : cursor;
            text = text.slice(0, start) + text.slice(end); cursor = start; selection = null;
            if (!options.delayed) publish();
        }
    };
    function type(value) {
        for (const character of value) {
            context.pressedKey = {key: character === " " ? 32 : character.charCodeAt(0), text: character, keyType: 0};
            context.handleKeyClick();
        }
    }
    return {context, commits, keys, requests, rows, type, publish,
        get text() { return text; }, get cursor() { return cursor; },
        swipe() {
            context.keyboardSettings.swipeTypingEnabled = true;
            context.acceptPendingSwipeForNextGesture();
            context.swipePath = [{x: 0, y: 0}, {x: 100, y: 0}]; context.swipeGestureActive = true;
            context.swipeDistance = 1000; context.swipeStartX = 0; context.swipeStartY = 0;
            context.pressedKey = {key: 101, text: "e", keyType: 0};
            return finishSwipe();
        },
        move(position) { cursor = position; publish(); },
        clear() { text = ""; cursor = 0; publish(); },
        select(start, end) { selection = {start, end}; cursor = end; publish(); },
        focus(value) { text = value; cursor = value.length; publish(); context.onFocusTargetChanged(); },
        backspace() {
            context.pressedKey = {key: 8, text: "", keyType: 0};
            if (!context.handleKeyClick()) context.MInputMethodQuick.sendKey(8);
        }
    };
}
function check(name, body) { body(); console.log("ok    " + name); }
check("ordinary key sound starts on press and is not repeated on release", () => {
    const t = setup(), c = t.context, sounds = [];
    c.KeyType.CharacterKey = 3; c.KeyType.PopupKey = 4;
    c.keyboardSettings.swipeVibrationEnabled = true;
    c.swipeCrossesSpacebar = () => false;
    c.captureSwipeKey = noop;
    c.playKeySound = sound => sounds.push(sound);
    vm.runInContext(extract("playAutomaticKeySound"), c);
    vm.runInContext(extract("handleKeyPress"), c);
    c.pressedKey = {key: 97, text: "a", keyType: c.KeyType.CharacterKey};
    c.handleKeyPress(); assert.deepStrictEqual(sounds, ["letter"]);
    c.handleKeyClick(); assert.deepStrictEqual(sounds, ["letter"]);
    c.swipePath = [{x: 1, y: 1}]; c.handleKeyPress();
    assert.deepStrictEqual(sounds, ["letter"], "crossing keys during a swipe must stay quiet");
    c.swipePath = []; c.pressedKey.manualFeedbackOnPress = true; c.handleKeyPress();
    assert.deepStrictEqual(sounds, ["letter"], "custom keys already play their own press sound");
});
check("timed haptics play once per swipe unless per-letter vibration is selected", () => {
    const t = setup(), c = t.context;
    let pulses = 0;
    c.customButtonVibration.play = () => ++pulses;
    c.swipeCrossesSpacebar = () => false; c.captureSwipeKey = noop;
    vm.runInContext(extract("handleKeyPress"), c);
    c.pressedKey = {key: 97, text: "a", keyType: c.KeyType.CharacterKey};
    c.keyboardSettings.keyVibrationMode = 1;
    c.handleKeyPress(); assert.strictEqual(pulses, 1);
    c.swipePath = [{x: 1, y: 1}]; c.handleKeyPress(); assert.strictEqual(pulses, 1);
    c.keyboardSettings.swipeVibrationEnabled = true; c.handleKeyPress(); assert.strictEqual(pulses, 2);
    c.pressedKey.manualFeedbackOnPress = true; c.handleKeyPress(); assert.strictEqual(pulses, 2);
    c.pressedKey.manualFeedbackOnPress = false; c.spacebarGestureActive = true;
    c.handleKeyPress(); assert.strictEqual(pulses, 2);
    c.spacebarGestureActive = false; c.swipePath = [];
    c.keyboardSettings.keyVibrationMode = 3; c.handleKeyPress(); assert.strictEqual(pulses, 3);
    c.keyboardSettings.keyVibrationMode = 0; c.handleKeyPress(); assert.strictEqual(pulses, 3);
    c.keyboardSettings.keyVibrationMode = 2; c.handleKeyPress(); assert.strictEqual(pulses, 3);
});
check("fast typed keys retain one haptic request per press", () => {
    const t = setup(), c = t.context;
    let pulses = 0;
    c.keyboardSettings.keyVibrationMode = 1;
    c.customButtonVibration.play = () => ++pulses;
    c.swipeCrossesSpacebar = () => false;
    c.captureSwipeKey = () => c.swipePath.push({x: 1, y: 1});
    vm.runInContext(extract("handleKeyPress") + extract("handleKeyRelease"), c);
    for (let i = 0; i < 200; ++i) {
        c.pressedKey = {key: 97, text: "a", keyType: c.KeyType.CharacterKey};
        c.handleKeyPress(); c.handleKeyClick(); c.handleKeyRelease();
    }
    assert.strictEqual(pulses, 200); assert.strictEqual(t.text, "a".repeat(200));
});
for (const perLetter of [false, true]) check("rapid swipe haptics follow the per-letter setting: " + perLetter, () => {
    const t = setup(), c = t.context;
    let pulses = 0;
    c.keyboardSettings.keyVibrationMode = 1;
    c.keyboardSettings.swipeVibrationEnabled = perLetter;
    c.customButtonVibration.play = () => ++pulses;
    c.swipeCrossesSpacebar = () => false;
    c.captureSwipeKey = () => c.swipePath.push({x: 1, y: 1});
    vm.runInContext(extract("handleKeyPress"), c);
    c.pressedKey = {key: 97, text: "a", keyType: c.KeyType.CharacterKey};
    for (let i = 0; i < 200; ++i) c.handleKeyPress();
    assert.strictEqual(pulses, perLetter ? 200 : 1);
});
check("suggestions only: ordinary Space never replaces typed words", () => {
    const t = setup(); t.type("hello world "); assert.strictEqual(t.text, "hello world ");
    assert(t.commits.every(c => c.length === 0 && c.offset === 0));
});
check("cursor move while typing cannot carry the old word into an edit", () => {
    const t = setup(); t.type("one two"); t.move(3); t.type("X "); assert.strictEqual(t.text, "oneX  two");
});
check("cleared message cannot reappear in the next message", () => {
    const t = setup(); t.type("old"); t.clear(); t.type("new "); assert.strictEqual(t.text, "new ");
});
check("a matching word at a different position does not own the query", () => {
    const t = setup(); t.type("same same"); t.move(4); assert.strictEqual(t.context.preedit, "");
    t.type(" "); assert.strictEqual(t.text, "same  same");
});
check("focus change clears all committed prediction ownership", () => {
    const t = setup(); t.type("old"); t.focus(""); t.type("new "); assert.strictEqual(t.text, "new ");
});
check("selection replacement and deleting selected text are safe", () => {
    const t = setup(); t.type("first last"); t.select(0, 5); t.type("new "); assert.strictEqual(t.text, "new  last");
    t.select(0, 3); t.context.deletePreviousWord(); assert.strictEqual(t.text, "  last");
});
check("typing within an existing word predicts the whole edited word", () => {
    const t = setup("hell world", 4); t.type("o"); t.context.refreshEditingWord();
    assert.strictEqual(t.text, "hello world"); assert.strictEqual(t.context.editingWord, "hello");
});
check("paste after a cursor move never reintroduces the cached word", () => {
    const t = setup(); t.type("one two"); t.move(0); t.context.onPaste(); assert.strictEqual(t.text, "pastedone two");
});
check("Space and punctuation respect independently disabled correction", () => {
    const t = setup(); t.type("teh"); t.context.correctionQuery = "teh"; t.context.correctionCandidate = "the";
    t.context.replacePredictionSuggestions(["teh", "the"], "the"); t.type("."); assert.strictEqual(t.text, "teh.");
});
check("enabled Space correction and first-Backspace undo remain functional", () => {
    const t = setup(); t.context.keyboardSettings.autoCorrectionEnabled = true;
    t.context.keyboardSettings.undoCorrectionEnabled = true; t.type("teh");
    t.context.correctionQuery = "teh"; t.context.correctionCandidate = "the";
    t.context.replacePredictionSuggestions(["teh", "the"], "the"); t.type(" "); assert.strictEqual(t.text, "the ");
    t.backspace(); assert.strictEqual(t.text, "teh "); t.backspace(); assert.strictEqual(t.text, "teh");
});
check("explicit suggestion replaces the verified current word", () => {
    const t = setup(); t.type("hel"); t.context.replacePredictionSuggestions(["hello"]);
    t.context.applyPrediction("hello"); assert.strictEqual(t.text, "hello ");
});
check("actual suggestion-tap handler accepts the current row", () => {
    const t = setup(); t.type("hel"); t.context.replacePredictionSuggestions(["hello"]);
    t.context.text = "hello"; t.context.onSelect(); assert.strictEqual(t.text, "hello ");
});
for (const [partial, completion] of [["hel", "hello"], ["teh", "the"], ["при", "привет"], ["عر", "عربي"]]) {
    check("partial completion survives a late owned acknowledgement: " + partial, () => {
        const t = setup("", 0, {delayed: true}); t.type(partial);
        t.context.replacePredictionSuggestions([completion]); t.publish();
        t.context.text = completion; t.context.onSelect();
        assert.strictEqual(t.text, completion + " ");
    });
    check("partial completion waits for its own text publication: " + partial, () => {
        const t = setup("", 0, {delayed: true}); t.type(partial);
        t.context.replacePredictionSuggestions([completion]);
        t.context.text = completion; t.context.onSelect();
        assert(t.context.pendingSuggestionTap); assert.strictEqual(t.text, partial);
        t.publish(); t.context.retryPendingSuggestionTap();
        assert.strictEqual(t.text, completion + " ");
        t.context.retryPendingSuggestionTap(); assert.strictEqual(t.text, completion + " ");
        assert.strictEqual(t.context.pendingSuggestionTap, null);
    });
}
check("intermediate acknowledgements keep a tapped partial completion owned", () => {
    const t = setup("", 0, {delayed: true}); t.type("hel");
    t.context.replacePredictionSuggestions(["hello"]);
    t.context.text = "hello"; t.context.onSelect();
    t.context.MInputMethodQuick.surroundingText = "h";
    t.context.MInputMethodQuick.cursorPosition = 1;
    t.context.onCursorPositionChanged(); t.context.onEditorStateUpdate();
    t.context.retryPendingSuggestionTap(); assert.strictEqual(t.text, "hel");
    t.publish(); t.context.retryPendingSuggestionTap(); assert.strictEqual(t.text, "hello ");
});
check("repeated taps while awaiting an acknowledgement insert only the last choice", () => {
    const t = setup("", 0, {delayed: true}); t.type("hel");
    t.context.replacePredictionSuggestions(["hello", "help"]);
    t.context.text = "hello"; t.context.onSelect();
    t.context.text = "help"; t.context.onSelect();
    t.publish(); t.context.retryPendingSuggestionTap();
    assert.strictEqual(t.text, "help "); assert.strictEqual(t.context.pendingSuggestionTap, null);
});
for (const [name, change] of [
    ["cursor movement", t => t.move(0)], ["focus change", t => t.focus("other field")],
    ["selection", t => t.select(0, 2)], ["new typing", t => t.type("x")],
    ["cleared message", t => t.clear()]
]) check("pending completion cannot survive " + name, () => {
    const t = setup("", 0, {delayed: true}); t.type("hel");
    t.context.replacePredictionSuggestions(["hello"]);
    t.context.text = "hello"; t.context.onSelect(); assert(t.context.pendingSuggestionTap);
    change(t); const expected = t.text; t.publish(); t.context.retryPendingSuggestionTap();
    // Clearing an editor whose last published state was already empty is
    // indistinguishable from an outstanding acknowledgement. It must expire
    // without writing, rather than guessing that the original word survived.
    if (name === "cleared message" && t.context.pendingSuggestionTap) {
        t.context.pendingSuggestionTap.started = Date.now() - 600;
        t.context.retryPendingSuggestionTap();
    }
    assert.strictEqual(t.text, expected); assert.strictEqual(t.context.pendingSuggestionTap, null);
});
check("a timed-out completion does not write unverified text", () => {
    const t = setup("", 0, {delayed: true}); t.type("hel");
    t.context.replacePredictionSuggestions(["hello"]);
    t.context.text = "hello"; t.context.onSelect();
    t.context.pendingSuggestionTap.started = Date.now() - 600;
    t.context.retryPendingSuggestionTap(); assert.strictEqual(t.text, "hel");
    assert.strictEqual(t.context.pendingSuggestionTap, null);
});
check("old suggestion cannot replace text after a cursor move", () => {
    const t = setup(); t.type("one two"); t.context.replacePredictionSuggestions(["too"]); t.move(3);
    t.context.applyPrediction("too"); assert.strictEqual(t.text, "one two");
});
check("late analysis for the same word at another position is ignored", () => {
    const t = setup("same same", 9); t.context.refreshEditingWord(); t.context.requestSuggestions();
    const request = t.requests.find(r => r.method === "AnalyzeContext"); assert(request);
    t.move(4); request.success(JSON.stringify({suggestions: ["wrong"], correction: "wrong"})); assert.strictEqual(t.rows.length, 0);
});
check("next-word results cannot overwrite suggestions in a new edit", () => {
    const t = setup("one "); t.context.requestNextWords(); const request = t.requests.find(r => r.method === "NextWords");
    t.type("x"); request.success(JSON.stringify(["wrong"])); assert.strictEqual(t.rows.length, 0);
});
check("delayed Android publication preserves fast multiword typing", () => {
    const t = setup("", 0, {delayed: true}); t.type("one two three");
    assert.strictEqual(t.context.preedit, "three"); assert.strictEqual(t.context.committedPreeditStart, 8);
    t.publish(); assert(t.context.committedPreeditMatchesEditor()); t.type(" ");
    assert.strictEqual(t.text, "one two three "); assert(t.commits.every(c => c.length === 0));
});
check("unchanged editor updates do not starve asynchronous suggestions", () => {
    const t = setup(); t.type("hel"); t.context.requestSuggestions();
    const request = t.requests.find(r => r.method === "AnalyzeContext");
    t.publish(); t.publish(); request.success(JSON.stringify({suggestions: ["hello"]}));
    assert(t.rows.some(row => row.text === "hello"));
});
check("slow prediction requests keep only the latest typed prefix", () => {
    const t = setup(), c = t.context;
    t.type("h"); c.requestSuggestions();
    const first = t.requests[0];
    for (const letter of "elloabcdefghijklmnopqrstuvxyz") {
        t.type(letter); c.requestSuggestions();
    }
    assert.equal(t.requests.length, 1, "Do not queue every keystroke in the helper");
    const latest = c.preedit;
    assert.equal(c.pendingPredictionRequest.args[1].value, latest);
    first.success(JSON.stringify({suggestions: ["stale"]}));
    assert.equal(t.requests.length, 2, "Dispatch just one retained request after completion");
    first.success(JSON.stringify({suggestions: ["duplicate"]}));
    assert.equal(c.predictionRequestInFlight, true, "An obsolete duplicate reply cannot release the newer request");
    assert.equal(t.requests[1].args[1].value, latest);
    assert.equal(t.rows.length, 0, "The superseded result must not be displayed");
    t.requests[1].success(JSON.stringify({suggestions: [latest + "x"]}));
    assert(t.rows.some(row => row.text === latest + "x"));
    assert.equal(c.predictionRequestInFlight, false); assert.equal(c.pendingPredictionRequest, null);
});
check("next-word and typed-word predictions share one bounded request lane", () => {
    const t = setup("one "), c = t.context;
    c.requestNextWords(); const first = t.requests[0];
    t.type("hel"); c.requestSuggestions();
    t.type("lo"); c.requestSuggestions();
    assert.equal(t.requests.length, 1);
    first.success(JSON.stringify(["stale"]));
    assert.equal(t.requests.length, 2); assert.equal(t.requests[1].method, "AnalyzeContext");
    assert.equal(t.requests[1].args[1].value, "hello");
    t.requests[1].failure("test error"); assert.equal(c.predictionRequestInFlight, false);
    t.type("x"); c.requestSuggestions(); assert.equal(t.requests.length, 3);
});
for (const [name, change] of [
    ["focus", t => t.focus("other")], ["cursor", t => t.move(0)],
    ["clear", t => t.clear()], ["selection", t => t.select(0, 2)],
    ["hidden keyboard", t => t.context.active = false],
    ["password field", t => t.context.passwordField = true]
]) check("retained predictions are dropped after " + name, () => {
    const t = setup(), c = t.context;
    t.type("h"); c.requestSuggestions(); const first = t.requests[0];
    t.type("el"); c.requestSuggestions(); assert(c.pendingPredictionRequest);
    change(t); first.success(JSON.stringify({suggestions: ["stale"]}));
    assert.equal(t.requests.length, 1); assert.equal(c.pendingPredictionRequest, null);
    assert.equal(c.predictionRequestInFlight, false); assert.equal(t.rows.length, 0);
});
check("a dispatch failure releases the prediction lane", () => {
    const t = setup(), c = t.context;
    t.type("hel"); c.helper.typedCall = () => false;
    c.requestSuggestions(); assert.equal(c.predictionRequestInFlight, false);
    c.helper.typedCall = (method, args, success, failure) => {
        t.requests.push({method, args, success, failure}); return true;
    };
    c.requestSuggestions(); assert.equal(t.requests.length, 1);
    t.requests[0].success(JSON.stringify({suggestions: ["hello"]}));
    assert(t.rows.some(row => row.text === "hello"));
    c.helper.typedCall = () => { throw new Error("service unavailable"); };
    c.requestSuggestions(); assert.equal(c.predictionRequestInFlight, false);
});
check("delayed backspaces keep ownership of the surviving word", () => {
    const t = setup("", 0, {delayed: true}); t.type("hello"); t.backspace(); t.backspace(); t.publish();
    assert.strictEqual(t.text, "hel"); assert.strictEqual(t.context.preedit, "hel");
    assert(t.context.committedPreeditMatchesEditor());
});
check("word deletion uses the pending word, not an old published cursor", () => {
    const t = setup("older ", 6, {delayed: true}); t.type("longerword"); t.context.deletePreviousWord();
    assert.strictEqual(t.text, "older "); t.publish(); t.type("new "); assert.strictEqual(t.text, "older new ");
});
for (const delayed of [false, true]) check("progressive word deletion uses successive editor states (delayed=" + delayed + ")", () => {
    const t = setup("one two three four five", 23, {delayed});
    t.context.deletePreviousWords(1); assert.strictEqual(t.text, "one two three four ");
    t.context.deletePreviousWords(2); assert.strictEqual(t.text, "one two ");
    t.context.deletePreviousWords(1); assert.strictEqual(t.text, "one ");
    t.publish(); t.type("new"); assert.strictEqual(t.text, "one new");
});
check("multiword deletion includes the immediately committed current word", () => {
    const t = setup("one two ", 8, {delayed: true}); t.type("three");
    t.context.deletePreviousWords(2); assert.strictEqual(t.text, "one ");
});
check("case suggestion replaces only the selection, without appending a space", () => {
    const t = setup("before hello world after"); t.select(7, 18);
    t.context.selectionCaseSuggestion = "Hello World";
    t.context.keyboard.shiftState = t.context.ShiftState.LatchedShift;
    t.context.acceptSelectionCaseSuggestion(); assert.strictEqual(t.text, "before Hello World after");
    assert.strictEqual(t.context.keyboard.shiftState, t.context.ShiftState.NoShift);
});
check("caps lock is preserved after accepting a selected-text case suggestion", () => {
    const t = setup("hello"); t.select(0, 5); t.context.selectionCaseSuggestion = "HELLO";
    t.context.keyboard.shiftState = t.context.ShiftState.LockedShift;
    t.context.acceptSelectionCaseSuggestion(); assert.strictEqual(t.text, "HELLO");
    assert.strictEqual(t.context.keyboard.shiftState, t.context.ShiftState.LockedShift);
});
check("acknowledgement ledger stays bounded and never stores passwords", () => {
    const t = setup("", 0, {delayed: true}); t.type("very ".repeat(100));
    assert(t.context.pendingEditorStates.length <= 16);
    assert(t.context.pendingEditorStates.every(s => s.before.length <= 128 && s.after.length <= 128));
    t.context.passwordField = true; t.type("secret"); assert.strictEqual(t.context.pendingEditorStates.length, 0);
    t.publish(); assert.strictEqual(t.context.lastObservedEditorState, null);
});
check("queued swipes decode and insert in gesture order", () => {
    const t = setup(); assert(t.swipe()); assert(t.swipe());
    const first = t.requests.find(r => r.method === "SwipeSuggestions"); assert(first);
    assert.strictEqual(t.requests.filter(r => r.method === "SwipeSuggestions").length, 1);
    first.success(JSON.stringify({suggestions: ["one"]}));
    const second = t.requests.filter(r => r.method === "SwipeSuggestions")[1]; assert(second);
    assert.strictEqual(second.args[3].value, "one");
    second.success(JSON.stringify({suggestions: ["two"]})); assert.strictEqual(t.text, "one two");
});
check("a subsequent swipe works after accepting the previous word", () => {
    const t = setup(); t.swipe(); t.requests[0].success(JSON.stringify({suggestions: ["one"]}));
    t.swipe(); const second = t.requests.filter(r => r.method === "SwipeSuggestions")[1]; assert(second);
    second.success(JSON.stringify({suggestions: ["two"]})); assert.strictEqual(t.text, "one two");
});
check("delayed swipe publication waits for the preceding committed word", () => {
    const t = setup("", 0, {delayed: true}); t.swipe(); t.swipe();
    t.requests[0].success(JSON.stringify({suggestions: ["one"]}));
    assert.strictEqual(t.requests.filter(r => r.method === "SwipeSuggestions").length, 1);
    t.publish(); t.context.dispatchNextSwipe();
    const second = t.requests.filter(r => r.method === "SwipeSuggestions")[1]; assert(second);
    second.success(JSON.stringify({suggestions: ["two"]})); assert.strictEqual(t.text, "one two");
});
check("a third gesture cannot consume a separator owned by a pending swipe", () => {
    const t = setup(); t.swipe(); t.swipe();
    t.requests[0].success(JSON.stringify({suggestions: ["one"]})); t.swipe();
    t.requests[1].success(JSON.stringify({suggestions: ["two"]}));
    t.requests[2].success(JSON.stringify({suggestions: ["three"]}));
    assert.strictEqual(t.text, "one two three");
});
check("swiping after fast typed text waits for that text's acknowledgement", () => {
    const t = setup("", 0, {delayed: true}); t.type("one"); t.swipe();
    assert.strictEqual(t.requests.filter(r => r.method === "SwipeSuggestions").length, 0);
    t.publish(); t.context.dispatchNextSwipe();
    const request = t.requests.find(r => r.method === "SwipeSuggestions"); assert(request);
    assert.strictEqual(request.args[3].value, "one ");
    request.success(JSON.stringify({suggestions: ["two"]})); assert.strictEqual(t.text, "one two");
});
check("stale visible row cannot insert after an unpublished edit", () => {
    const t = setup("hel", 3, {delayed: true}); t.context.refreshEditingWord();
    t.context.replacePredictionSuggestions(["hello"]); t.type("p"); t.context.applyPrediction("hello");
    assert.strictEqual(t.text, "help");
});
check("one-shot Shift captures a key before consuming its live Shift state", () => {
    const t = setup(); t.context.keyboard.shiftState = t.context.ShiftState.LatchedShift;
    t.context.pressedKey = {key: 65, keyType: 0, get text() { return t.context.keyboard.shiftState === 0 ? "a" : "A"; }};
    t.context.handleKeyClick(); assert.strictEqual(t.text, "A"); assert.strictEqual(t.context.keyboard.shiftState, 0);
});
for (const [name, action] of [
    ["typing", t => t.type("x")], ["cursor move", t => t.move(0)],
    ["clear", t => t.clear()], ["focus change", t => t.focus("")],
    ["paste", t => t.context.onPaste()], ["backspace", t => t.backspace()]
]) check("late swipe cannot insert after " + name, () => {
    const t = setup("old "); t.swipe(); const request = t.requests[0]; assert(request);
    action(t); const expected = t.text; request.success(JSON.stringify({suggestions: ["wrong"]}));
    assert.strictEqual(t.text, expected);
});
check("cancelled swipe reply cannot complete a newer swipe", () => {
    const t = setup(); t.swipe(); const old = t.requests[0]; t.context.cancelSwipeSession(); t.swipe();
    old.success(JSON.stringify({suggestions: ["wrong"]})); assert.strictEqual(t.context.swipeOutstanding, 1);
    t.requests[1].success(JSON.stringify({suggestions: ["right"]})); assert.strictEqual(t.text, "right");
});
for (const word of ["íslenska", "русский", "العربية", "فارسی", "Ελληνικά", "görüş"])
    check("committed query stays anchored for " + word, () => {
        const t = setup(); t.type(word); assert(t.context.committedPreeditMatchesEditor());
        t.type(" "); assert.strictEqual(t.text, word + " ");
    });
for (const delayed of [false, true]) check("mixed editing sequences never alter unaccepted words (delayed=" + delayed + ")", () => {
    const t = setup("", 0, {delayed}); let seed = 271828;
    const random = n => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed % n; };
    for (let i = 0; i < 600; ++i) {
        const action = random(12), before = t.text, cursor = t.cursor;
        if (action < 7) {
            const value = ["a", "b", " ", ".", "e", "'", "Ж"][action];
            t.type(value); assert.strictEqual(t.text, before.slice(0, cursor) + value + before.slice(cursor), "type " + i);
        } else if (action === 7) {
            t.backspace(); assert.strictEqual(t.text, before.slice(0, Math.max(0, cursor - 1)) + before.slice(cursor), "backspace " + i);
        } else if (action === 8) {
            t.move(random(t.text.length + 1)); assert.strictEqual(t.text, before, "move " + i);
        } else if (action === 9) {
            t.publish(); assert.strictEqual(t.text, before, "publish " + i);
        } else if (action === 10) {
            t.clear(); assert.strictEqual(t.text, "", "clear " + i);
        } else {
            t.context.requestSuggestions();
            const request = t.requests[t.requests.length - 1];
            if (request && request.method === "AnalyzeContext")
                request.success(JSON.stringify({suggestions: ["wrong"], correction: "wrong"}));
            assert.strictEqual(t.text, before, "suggestion reply " + i);
        }
    }
});
check("custom dead keys compose without exposing the pending accent to the editor", () => {
    const t=setup();
    t.context.keyboard.layout.composeCustomDeadKey=(dead,text)=>dead==="`"&&text==="e"?"è":text===" "||text===dead?dead:dead+text;
    function dead(value) {t.context.pressedKey={key:0,text:value,keyType:0,customAction:"text",customDeadKey:true}; t.context.handleKeyClick();}
    dead("`"); assert.equal(t.text,""); assert.equal(t.context.customPendingDeadKey,"`");
    t.type("e"); assert.equal(t.text,"è"); assert.equal(t.context.customPendingDeadKey,"");
    t.type(" "); dead("`"); t.type(" "); assert.equal(t.text,"è `");
    dead("`"); t.backspace(); assert.equal(t.text,"è `"); assert.equal(t.context.customPendingDeadKey,"");
    dead("`"); dead("`"); assert.equal(t.text,"è ``");
    dead("`"); t.focus(""); assert.equal(t.context.customPendingDeadKey,"");
});
check("custom action and protected Quick Settings releases never type their labels", () => {
    const t=setup(); let action="";
    t.context.keyboard.layout.activateCustomAction=item=>action=item.action;
    t.context.pressedKey={key:0,text:"",keyType:0,customAction:"page",customDefinition:{action:"page",target:"numbers"}};
    assert.equal(t.context.handleKeyClick(),true);assert.equal(action,"page");assert.equal(t.text,"");
    t.context.pressedKey={key:32,text:" ",keyType:0,reservedQuickSettings:true,heldForSettings:true};
    assert.equal(t.context.handleKeyClick(),true);assert.equal(t.text,"");
});
for (const language of ["JA", "ZH", "ZH_HANT"]) check("custom keys use the active conversion engine for " + language, () => {
    const t = setup(), submitted = [], actions = [];
    const c = t.context;
    c.conversionEnabled = true;
    c.conversion = {language, submit: (operation, value) => submitted.push([operation, value]), kanaKeyEntered: noop};
    c.handleConversionKey = vm.runInContext("(" + extract("handleConversionKey") + ")", c);
    c.keyboard.layout.activateCustomAction = item => actions.push(item.action);
    c.desktopKeyCode = action => ({esc: 27, left: 37, right: 39})[action];
    t.type(language === "JA" ? "nihon" : "nihao");
    assert.equal(t.text, "", "Phonetic keys must not bypass conversion");
    assert.equal(submitted.map(item => item[1]).join(""), language === "JA" ? "nihon" : "nihao");
    for (const action of ["left", "right", "esc"]) {
        c.pressedKey = {key: 0, text: "", keyType: 0, customAction: action, customDefinition: {action}};
        c.handleKeyClick();
    }
    assert.deepEqual(submitted.slice(-3).map(item => item[1]), ["65361", "65363", "65307"]);
    assert.equal(actions.length, 0, "Navigation belongs to the unfinished conversion");
    c.keyboard.layout.composeCustomDeadKey = () => "è";
    c.pressedKey = {key: 0, text: "`", keyType: 0, customAction: "text", customDeadKey: true};
    c.handleKeyClick(); t.type("e");
    assert.deepEqual(submitted[submitted.length - 1], ["text", "è"]);
    c.customPageAllowsSuggestions = false;
    const before = submitted.length;
    t.type("123");
    assert.equal(t.text, "123", "A custom symbol page types its literal keys");
    assert.equal(submitted.length, before, "Symbol pages must not feed Pinyin/Romaji");
});
check("mixed custom popup choices dispatch actions and preserve literal macros", () => {
    const t = setup(), c = t.context, actions = [];
    c.keyboard.layout.activateCustomAction = choice => actions.push(choice.action);
    c.keyboard.cycleShift = () => c.keyboard.shiftState++;
    function choose(choice) {
        c.customPopupSource = {choiceForPopupOutput: token => token === "\uF8FFfuto:0" ? choice : null};
        c.pressedKey = {key: 0, text: "\uF8FFfuto:0", keyType: c.KeyType.PopupKey};
        c.handleKeyClick();
    }
    choose("www."); choose({text: "https://example.test/" + "path/".repeat(100), label: "Website"});
    assert.equal(t.text, "www.https://example.test/" + "path/".repeat(100));
    choose({action: "page", target: "numbers"}); assert.deepEqual(actions, ["page"]);
    choose({action: "shift"}); assert.equal(c.keyboard.shiftState, 1);
    assert.equal(c.customPopupSource, null);
    const before = t.text;
    c.pressedKey = {key: 0, text: "\uF8FFfuto:0", keyType: c.KeyType.PopupKey}; c.handleKeyClick();
    assert.equal(t.text, before, "A canceled/stale popup cannot leak an internal token into text");
    c.customPopupSource = {}; c.clearCustomDeadKey(); assert.equal(c.customPopupSource, null);
});
check("editing actions dispatch standard shortcuts, current clipboard and dismissal", () => {
    const t = setup(), c = t.context, events = [];
    c.Qt.ControlModifier = 0x04000000;
    c.prepareDesktopKeyDispatch = () => events.push("prepare");
    c.paste = text => events.push(["paste", text]); c.Clipboard.hasText = true;
    c.MInputMethodQuick.sendKey = (key, modifiers) => events.push([key, modifiers]);
    c.MInputMethodQuick.userHide = () => events.push("hide");
    vm.runInContext(extract("activateEditingAction"), c);
    for (const action of ["copy", "cut", "selectall"]) c.activateEditingAction(action);
    assert.deepEqual(events.filter(Array.isArray), [[67, c.Qt.ControlModifier], [88, c.Qt.ControlModifier], [65, c.Qt.ControlModifier]]);
    c.activateEditingAction("paste"); assert.deepEqual(events[events.length - 1], ["paste", "pasted"]);
    c.pressedKey = {key: 0, text: "", customAction: "hide", keyType: c.KeyType.CharacterKey}; c.handleKeyClick();
    assert.equal(events[events.length - 1], "hide");
});
console.log("Editor-state and suggestion ownership checks passed.");
