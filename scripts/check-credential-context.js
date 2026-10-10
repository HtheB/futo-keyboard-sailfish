#!/usr/bin/env node
"use strict";

const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");
const source = fs.readFileSync(path.join(__dirname, "../qml/FutoInputHandler.qml"), "utf8");
const manageSource = fs.readFileSync(path.join(__dirname, "../qml/FutoPasswordManagePage.qml"), "utf8");
const manageContext = {
    selectedTab: 0, searchQuery: "", secretMatchIds: {}, visibleEntries: [],
    allEntries: [
        { entryId: "z", entryLabel: "Zulu", entryOrigin: "https://z.test", entryUsername: "a", entryAppName: "" },
        { entryId: "b", entryLabel: "alpha", entryOrigin: "https://a.test", entryUsername: "z", entryAppName: "" },
        { entryId: "a", entryLabel: "Alpha", entryOrigin: "https://a.test", entryUsername: "a", entryAppName: "" },
        { entryId: "app-z", entryLabel: "A package", entryOrigin: "app://a", entryUsername: "", entryAppName: "Zulu app" },
        { entryId: "app-a", entryLabel: "Z package", entryOrigin: "app://z", entryUsername: "", entryAppName: "Alpha app" }
    ]
};
vm.createContext(manageContext);
vm.runInContext(manageSource.slice(manageSource.indexOf("function rebuildModels("),
    manageSource.indexOf("function searchEntries(")), manageContext);
manageContext.rebuildModels();
assert.deepStrictEqual(Array.from(manageContext.visibleEntries, e => e.entryId), ["a", "b", "z"]);
manageContext.selectedTab = 1;
manageContext.rebuildModels();
assert.deepStrictEqual(Array.from(manageContext.visibleEntries, e => e.entryId), ["app-a", "app-z"]);
manageContext.searchQuery = "app";
manageContext.rebuildModels();
assert.deepStrictEqual(Array.from(manageContext.visibleEntries, e => e.entryId), ["app-a", "app-z"]);
assert.strictEqual(manageContext.allEntries[0].entryId, "z"); // Sorting never changes stored data.
console.log("Managed website and app logins sort alphabetically by displayed name, including search results");
const companionRoot = path.join(__dirname, "../android-companion/app/src/main/java/org/htheb/futo/autofill");
const autofillService = fs.readFileSync(path.join(companionRoot, "FutoAutofillService.java"), "utf8");
const authenticationActivity = fs.readFileSync(path.join(companionRoot, "AuthenticationActivity.java"), "utf8");
assert(authenticationActivity.includes("onWindowFocusChanged(boolean focused)"));
assert(authenticationActivity.includes("hideSoftInputFromWindow(keyboardAnchor.getWindowToken(), 0)"));
assert(authenticationActivity.includes("!hasWindowFocus()"));
assert(authenticationActivity.includes('result.optBoolean("pending")'));
assert(authenticationActivity.includes("updateKeyboardVisibility(revision, visible)"));
assert(authenticationActivity.includes("revision <= keyboardRevision"));
assert(authenticationActivity.includes("!keyboardRequestedVisible"));
assert(autofillService.includes("if (worker.isShutdown()) return;"));
const loginForm = fs.readFileSync(path.join(companionRoot, "LoginForm.java"), "utf8");
const saveHandler = autofillService.slice(autofillService.indexOf("@Override public void onSaveRequest"),
    autofillService.indexOf("private void saveFailure"));
assert(saveHandler.includes('BridgeClient.call(this, "present"'));
assert(saveHandler.includes("callback.onSuccess();"));
assert(!saveHandler.includes("callback.onSuccess(PendingIntent"));
assert(saveHandler.includes("LoginForm.parseForSave(request.getFillContexts(), request.getClientState())"));
assert(autofillService.includes("response.setClientState(form.saveState())"));
const saveState = loginForm.slice(loginForm.indexOf("Bundle saveState()"), loginForm.indexOf("static LoginForm parseForSave"));
assert(!saveState.includes("getAutofillValue"));
assert(!saveState.includes("LoginForm.value"));
console.log("Android save retains field identities and does not depend on a closed login activity");
const nativeSave = fs.readFileSync(path.join(__dirname, "../qml/FutoAndroidCredentialPage.qml"), "utf8");
assert(!nativeSave.includes('qsTr("Save this login?")'));
assert(!nativeSave.includes('qsTr("Save login")'));
assert(nativeSave.includes('authentication.requestPermission(qsTr("Save this login in FUTO Keyboard"))'));
const nativeSaveContext = {
    vaultToken: "", requestId: "test-save", finished: false, completing: false, busy: true,
    message: "", qsTr: text => text
};
nativeSaveContext.page = nativeSaveContext;
vm.createContext(nativeSaveContext);
vm.runInContext(nativeSave.slice(nativeSave.indexOf("function vaultReady("),
    nativeSave.indexOf("function closePage(")), nativeSaveContext);
let saveCalls = [], saveReply, saveFailure, closedSaves = 0, lockedSaves = 0;
nativeSaveContext.helper = { typedCall(method, args, success, failure) {
    saveCalls.push({ method, args });
    if (method === "CompleteAndroidAutofill") { saveReply = success; saveFailure = failure; }
} };
nativeSaveContext.lockVault = () => { lockedSaves++; };
nativeSaveContext.closePage = () => { closedSaves++; };
nativeSaveContext.vaultReady("");
assert.strictEqual(saveCalls.length, 0);
assert.strictEqual(nativeSaveContext.busy, false);
nativeSaveContext.vaultReady("authenticated-token");
assert.strictEqual(saveCalls.length, 1);
assert.strictEqual(saveCalls[0].method, "CompleteAndroidAutofill");
assert.strictEqual(saveCalls[0].args[0].value, "authenticated-token");
assert.strictEqual(saveCalls[0].args[3].value, true);
nativeSaveContext.complete("", true);
assert.strictEqual(saveCalls.length, 1); // No duplicate write during completion.
saveReply(true);
assert.strictEqual(nativeSaveContext.finished, true);
assert.strictEqual(closedSaves, 1);
assert.strictEqual(lockedSaves, 1);
nativeSaveContext.vaultReady("late-token");
assert.strictEqual(saveCalls[1].method, "LockVault");
assert.strictEqual(saveCalls[1].args[0].value, "late-token");
nativeSaveContext.finished = false;
nativeSaveContext.vaultReady("retry-token");
saveFailure();
assert.strictEqual(nativeSaveContext.finished, false);
assert.strictEqual(nativeSaveContext.completing, false);
assert.strictEqual(nativeSaveContext.busy, false);
assert(nativeSaveContext.message.includes("Could not finish"));
nativeSaveContext.complete("", false);
assert.strictEqual(saveCalls[saveCalls.length - 1].args[3].value, false);
nativeSaveContext.vaultReady("canceled-token");
assert.strictEqual(saveCalls[saveCalls.length - 1].method, "LockVault");
saveReply(false);
assert.strictEqual(closedSaves, 2);
console.log("Android Save consent writes once after authentication, without a second confirmation");
const bridge = fs.readFileSync(path.join(__dirname, "../helper/cmd/futo-keyboard-helper/android_autofill.go"), "utf8");
const present = bridge.slice(bridge.indexOf('case "/v1/present":'), bridge.indexOf('case "/v1/result":'));
assert(present.includes("go b.saveInBackground"));
assert(!present.includes("showPage"));
assert(!present.includes("bus.Emit"));
const deviceAuth = fs.readFileSync(path.join(__dirname, "../vault/futo-keyboard-device-auth.cpp"), "utf8");
assert(deviceAuth.includes("Authenticator.SecurityCode | Authenticator.Fingerprint"));
assert(deviceAuth.includes("clearenv()"));
assert(deviceAuth.includes("setImportPathList"));
assert(deviceAuth.includes("packagedInfo.st_ino"));
assert(deviceAuth.includes("SystemDialog {"));
assert(deviceAuth.includes("DeviceLockInput {"));
assert(deviceAuth.includes("PatternLockInput {"));
assert(deviceAuth.includes("granted && inputConfirmed"));
assert(deviceAuth.includes('&& request->property("inputConfirmed").toBool()'));
assert(deviceAuth.includes("authentication.authenticatingProcess !== authenticationPid"));
assert(deviceAuth.includes("registered: request.started && !request.finishing"));
assert(deviceAuth.includes("QML_DISABLE_DISK_CACHE"));
assert(!deviceAuth.includes("ApplicationWindow"));
assert(deviceAuth.includes('QByteArray(argv[1]) == "--use-login"'));
assert(deviceAuth.includes('QStringLiteral("Use a saved FUTO login")'));
assert(deviceAuth.includes("authenticator.requestPermission(authenticationMessage"));
assert(deviceAuth.includes("unlockInput.usePattern || unlockInput._showKeypad"));
assert(deviceAuth.includes("Qt.inputMethod.hide()"));
const vaultUnlock = fs.readFileSync(path.join(__dirname, "../helper/cmd/futo-keyboard-helper/vault_unlock.go"), "utf8");
assert(vaultUnlock.includes('exec.CommandContext(ctx, deviceAuthenticationPath, "--use-login")'));
const helperSource = fs.readFileSync(path.join(__dirname, "../helper/cmd/futo-keyboard-helper/main.go"), "utf8");
const vaultAuthentication = helperSource.slice(helperSource.indexOf("func (service *service) authenticateVaultPIDForActionContext"),
    helperSource.indexOf("func (service *service) expireVaultSessionsLocked"));
assert(vaultAuthentication.includes("vaultDeviceAuthenticationCommand"));
assert(!vaultAuthentication.includes("pkcheck"));
assert(autofillService.includes("watchSaveResult(getApplicationContext(), requestId)"));
console.log("Android saving uses the system unlock view without opening Settings or another activity");
const overlayFunctions = [...deviceAuth.matchAll(/function (finish|tryFinish|begin|cancel)\([^)]*\) \{[\s\S]*?\n    \}/g)]
    .map((match) => match[0]).join("\n");
assert.strictEqual((overlayFunctions.match(/function /g) || []).length, 4);
let overlayCloses = 0, overlayQuits = 0, overlayStarts = 0, overlayCancels = 0;
const overlayContext = {
    started: false, finishing: false, granted: false, inputConfirmed: false,
    close() { overlayCloses++; },
    Qt: { quit() { overlayQuits++; } },
    Authenticator: { SecurityCode: 1, Fingerprint: 2 },
    authenticator: { availableMethods: 3, cancel() { overlayCancels++; } },
    dispatch: { start() { overlayStarts++; }, stop() {} }
};
vm.createContext(overlayContext);
vm.runInContext(overlayFunctions, overlayContext);
overlayContext.begin();
overlayContext.begin();
assert.strictEqual(overlayStarts, 1);
overlayContext.granted = true;
overlayContext.tryFinish();
assert.strictEqual(overlayQuits, 0); // The input has not confirmed yet.
overlayContext.inputConfirmed = true;
overlayContext.tryFinish();
overlayContext.tryFinish();
assert.strictEqual(overlayCloses, 1);
assert.strictEqual(overlayQuits, 1);
overlayContext.finishing = false;
overlayContext.inputConfirmed = false;
overlayContext.cancel();
assert.strictEqual(overlayContext.granted, false);
assert.strictEqual(overlayCancels, 1);
assert.strictEqual(overlayCloses, 2);
assert.strictEqual(overlayQuits, 2);
overlayContext.started = false;
overlayContext.authenticator.availableMethods = 0;
overlayContext.begin();
assert.strictEqual(overlayStarts, 1);
console.log("Unlock overlay waits for both authentication signals and cancels without granting access");
const appSupportPage = fs.readFileSync(path.join(__dirname, "../qml/FutoAndroidAutofillPage.qml"), "utf8");
const privacyPage = fs.readFileSync(path.join(__dirname, "../qml/FutoPrivacyPage.qml"), "utf8");
const configureActivity = fs.readFileSync(path.join(companionRoot, "ConfigureActivity.java"), "utf8");
assert(privacyPage.includes('qsTr("Android™ AppSupport")'));
assert(privacyPage.includes('"image://theme/icon-m-android"'));
const setupToastSource = fs.readFileSync(path.join(__dirname, "../vault/futo-keyboard-setup-toast.cpp"), "utf8");
assert(appSupportPage.includes('helper.typedCall("ShowAndroidAutofillSetupToast", [])'));
assert(setupToastSource.includes("QTimer::singleShot(15000"));
assert(setupToastSource.includes("Select FUTO Autofill in Android's autofill settings."));
assert(setupToastSource.includes("Qt::WindowDoesNotAcceptFocus | Qt::WindowTransparentForInput"));
assert(setupToastSource.includes('QStringLiteral("CATEGORY"), QStringLiteral("overlay")'));
assert(setupToastSource.includes("view.setMask(QRegion(-1, -1, 1, 1))"));
assert(!appSupportPage.includes('page.message = qsTr("Select FUTO'));
assert(!appSupportPage.includes('qsTr("Android autofill is disabled")'));
assert(configureActivity.includes('!ACTION_ENABLE.equals(getIntent().getAction())'));
assert(appSupportPage.includes('setupOnly === true ? "org.htheb.futo.autofill.ENABLE"'));
assert(!appSupportPage.includes('"setup_only"'));
assert(!appSupportPage.includes("Notification {"));
const companionManifest = fs.readFileSync(path.join(__dirname, "../android-companion/app/src/main/AndroidManifest.xml"), "utf8");
assert.strictEqual((companionManifest.match(/android:icon="@drawable\/futo_keyboard_icon"/g) || []).length, 2);
assert(fs.readFileSync(path.join(__dirname, "../assets/icons/futo-keyboard-sailfish.png"))
    .equals(fs.readFileSync(path.join(__dirname, "../android-companion/app/src/main/res/drawable-nodpi/futo_keyboard_tile.png"))));
assert(fs.readFileSync(path.join(__dirname, "../packaging/rpm/futo-keyboard-sailfish.spec"), "utf8")
    .includes("Icon:           %{name}.xpm"));
assert(autofillService.includes('Settings.Secure.getUriFor("autofill_service")'));
const appSupportContext = { busy: false, checking: false, refreshSerial: 0, stateReady: false, configuring: false, installed: false,
    enabled: false, active: false, packageName: "org.htheb.futo.autofill", qsTr: text => text, JSON };
appSupportContext.page = appSupportContext;
vm.createContext(appSupportContext);
vm.runInContext(appSupportPage.slice(appSupportPage.indexOf("function refresh("),
    appSupportPage.indexOf("function installCompanion(")), appSupportContext);
let appSupportState, disabledBridges = 0;
appSupportContext.appSupport = { typedCall(method, args, done) { done([{}]); } };
appSupportContext.helper = { typedCall(method, args, done) {
    assert.strictEqual(method, "GetAndroidAutofillState"); done(JSON.stringify(appSupportState));
} };
appSupportContext.setEnabled = enabled => { assert.strictEqual(enabled, false); disabledBridges++; };
appSupportState = { enabled: true, active: false };
appSupportContext.refresh();
assert.strictEqual(appSupportContext.enabled, false);
assert.strictEqual(disabledBridges, 1);
appSupportContext.configuring = true;
appSupportContext.refresh();
assert.strictEqual(appSupportContext.enabled, false);
assert.strictEqual(disabledBridges, 1); // Do not cancel an unfinished Android picker.
appSupportContext.configuring = false;
appSupportState = { enabled: true, active: true };
appSupportContext.refresh();
assert.strictEqual(appSupportContext.enabled, true);
appSupportState = { enabled: false, active: true };
appSupportContext.refresh();
assert.strictEqual(appSupportContext.enabled, false);
assert.strictEqual(appSupportContext.stateReady, true);
console.log("AppSupport switch follows confirmed Android selection; setup uses transient fifteen-second feedback");
const spinnerStart = appSupportPage.indexOf("BusyIndicator {");
const spinnerEnd = appSupportPage.indexOf("\n            Label {", spinnerStart);
assert(spinnerStart > appSupportPage.indexOf('qsTr("Open Android autofill settings")'));
const spinnerRunning = appSupportPage.slice(spinnerStart, spinnerEnd).match(/running:\s*([^\r\n]+)/)[1];
const initialLoading = appSupportPage.match(/readonly property bool initialLoading:\s*([^\r\n]+)/)[1];
const switchStart = appSupportPage.indexOf("TextSwitch {");
const switchEnd = appSupportPage.indexOf("\n            Button {", switchStart);
const switchEnabled = appSupportPage.slice(switchStart, switchEnd).match(/enabled:\s*([^\r\n]+)/)[1];
let refreshReply, statusChecks = 0;
appSupportContext.appSupport = { typedCall(method, args, done) { statusChecks++; refreshReply = done; } };
appSupportContext.refresh();
assert.strictEqual(appSupportContext.checking, true);
appSupportContext.initialLoading = vm.runInContext(initialLoading, appSupportContext);
assert.strictEqual(vm.runInContext(spinnerRunning, appSupportContext), false);
assert.strictEqual(vm.runInContext(switchEnabled, appSupportContext), true);
appSupportContext.refresh();
assert.strictEqual(statusChecks, 1); // Do not overlap a background refresh.
refreshReply([{}]);
assert.strictEqual(appSupportContext.checking, false);
appSupportContext.refresh();
appSupportContext.invalidateRefresh();
appSupportContext.enabled = true;
refreshReply([]);
assert.strictEqual(appSupportContext.enabled, true);
assert.strictEqual(appSupportContext.installed, true);
assert.strictEqual(appSupportContext.checking, false);
// A late helper reply must also leave a newer user action untouched.
let stateReply;
appSupportContext.appSupport = { typedCall(method, args, done) { done([{}]); } };
appSupportContext.helper = { typedCall(method, args, done) { stateReply = done; } };
appSupportContext.refresh();
appSupportContext.invalidateRefresh();
stateReply(JSON.stringify({ enabled: false, active: false }));
assert.strictEqual(appSupportContext.enabled, true);
assert.strictEqual(appSupportContext.checking, false);
appSupportContext.stateReady = false;
appSupportContext.initialLoading = vm.runInContext(initialLoading, appSupportContext);
assert.strictEqual(vm.runInContext(spinnerRunning, appSupportContext), true);
appSupportContext.stateReady = true;
appSupportContext.initialLoading = vm.runInContext(initialLoading, appSupportContext);
appSupportContext.busy = true;
assert.strictEqual(vm.runInContext(spinnerRunning, appSupportContext), true);
assert.strictEqual(vm.runInContext(switchEnabled, appSupportContext), false);
console.log("Background AppSupport checks do not move or dim controls, and stale replies cannot override actions");
// Enabling an already selected provider stays on the native page. Only a
// missing selection launches the Android setup action.
for (const selected of [true, false]) {
    const enableContext = { busy: false, enabled: false, active: false, configuring: false,
        qsTr: text => text, JSON, invalidated: 0, setupCalls: [] };
    enableContext.page = enableContext;
    enableContext.invalidateRefresh = () => enableContext.invalidated++;
    enableContext.configureCompanion = setupOnly => enableContext.setupCalls.push(setupOnly);
    enableContext.helper = { typedCall(method, args, done) {
        if (method === "SetAndroidAutofillEnabled") {
            assert.strictEqual(args[0].value, true);
            done(true);
        } else {
            assert.strictEqual(method, "GetAndroidAutofillState");
            done(JSON.stringify({enabled: true, active: selected}));
        }
    }};
    vm.createContext(enableContext);
    vm.runInContext(appSupportPage.slice(appSupportPage.indexOf("function setEnabled("),
        appSupportPage.indexOf("function configureCompanion(")), enableContext);
    enableContext.setEnabled(true);
    assert.strictEqual(enableContext.busy, false);
    assert.strictEqual(enableContext.enabled, selected);
    assert.strictEqual(enableContext.active, selected);
    assert.deepStrictEqual(enableContext.setupCalls, selected ? [] : [true]);
}
console.log("Re-enabling a selected Android provider skips setup, while an unselected provider opens it");
function functionsBetween(first, next) {
    const start = source.indexOf("function " + first + "(");
    const end = source.indexOf("function " + next + "(", start);
    assert(start >= 0 && end > start);
    return source.slice(start, end);
}
const context = {
    MInputMethodQuick: { extensions: {} },
    Qt: { ImhHiddenText: 1, ImhSensitiveData: 2 }
};
vm.createContext(context);
vm.runInContext(functionsBetween("numericInputMetadata", "requestCredentialMatch"), context);
vm.runInContext(functionsBetween("credentialOriginKey", "credentialDebug"), context);
for (const value of [false, "false", 0, "0", "off", "no", "", null, undefined]) {
    context.MInputMethodQuick.extensions = { passwordField: value, usernameField: value };
    assert.strictEqual(context.passwordMetadataAvailable(), false);
    assert.strictEqual(context.usernameMetadataAvailable(), false);
}
for (const value of [true, "true", 1]) {
    context.MInputMethodQuick.extensions = { passwordField: value };
    assert.strictEqual(context.passwordMetadataAvailable(), true);
}
for (const value of [0x81, "0xe1", "145"]) {
    context.MInputMethodQuick.extensions = { androidInputType: value };
    assert.strictEqual(context.passwordMetadataAvailable(), true);
}
context.MInputMethodQuick.extensions = { autofillHint: "current-password" };
assert.strictEqual(context.passwordMetadataAvailable(), true);
context.MInputMethodQuick.extensions = { autofillHint: "one-time-code" };
assert.strictEqual(context.passwordMetadataAvailable(), false);
context.MInputMethodQuick.extensions = { autofillHint: "username" };
assert.strictEqual(context.usernameMetadataAvailable(), true);
assert.strictEqual(context.credentialOriginKey("https://Example.test/path"), "example.test");
assert.strictEqual(context.credentialOriginKey("http://example.test/"), "example.test");
assert.notStrictEqual(context.credentialOriginKey("app://example.test"),
                      context.credentialOriginKey("https://example.test"));
assert.notStrictEqual(context.credentialOriginKey("https://example.test:443"),
                      context.credentialOriginKey("https://example.test:8443"));
console.log("Credential field metadata and exact-origin checks passed");

vm.runInContext(functionsBetween("normalizedApplicationId", "browserApplicationId"), context);
vm.runInContext(functionsBetween("credentialOriginDisplayName", "resolveBrowserCredentialOrigin"), context);
context.applicationDisplayNames = { "org.example.login": "Example app" };
assert.strictEqual(context.credentialOriginDisplayName("app://org.example.login"), "Example app");

vm.runInContext(functionsBetween("credentialAutofillContextCurrent", "beginCredentialAutofill"), context);
context.futoHandler = context;
context.credentialDebug = () => {};
context.credentialAutofillSerial = 1;
context.credentialAutofillStage = 2;
context.credentialAutofillOrigin = "https://right.test";
context.activeAndroidComponent = "";
context.activePolicyApplicationId = "sailfish-browser";
let cancellations = 0;
let fills = 0;
context.cancelCredentialAutofill = () => cancellations++;
context.resolveApplicationCredentialOrigin = callback => callback("https://wrong.test");
context.credentialAutofillContextCurrent(() => fills++);
assert.strictEqual(fills, 0);
assert.strictEqual(cancellations, 1);
context.resolveApplicationCredentialOrigin = callback => callback("https://right.test/path");
context.credentialAutofillContextCurrent(() => fills++);
assert.strictEqual(fills, 1);
let pending;
context.resolveApplicationCredentialOrigin = callback => { pending = callback; };
context.credentialAutofillContextCurrent(() => fills++);
context.credentialAutofillSerial++;
pending("https://right.test");
assert.strictEqual(fills, 1);
context.credentialAutofillOrigin = "";
context.credentialAutofillApplication = "org.example.login";
context.activeAndroidComponent = "org.example.other";
context.resolveApplicationCredentialOrigin = callback => callback("");
context.credentialAutofillContextCurrent(() => fills++);
assert.strictEqual(fills, 1);
assert.strictEqual(cancellations, 2);
console.log("Autofill rejects changed origins, applications and stale transactions");

const ownershipStart = source.indexOf("readonly property bool androidCompanionOwnsCredentials:");
const ownershipEnd = source.indexOf("readonly property bool credentialFieldCandidate:", ownershipStart);
assert(ownershipStart >= 0 && ownershipEnd > ownershipStart);
const ownership = source.slice(ownershipStart, ownershipEnd).split(":").slice(1).join(":").trim();
context.keyboardSettings = { androidAutofillEnabled: true, androidAutofillActive: true };
context.credentialPlatformKnown = false;
context.credentialPlatformAndroid = false;
assert.strictEqual(vm.runInContext(ownership, context), true);
context.credentialPlatformKnown = true;
assert.strictEqual(vm.runInContext(ownership, context), false);
context.credentialPlatformAndroid = true;
assert.strictEqual(vm.runInContext(ownership, context), true);
context.keyboardSettings.androidAutofillEnabled = false;
assert.strictEqual(vm.runInContext(ownership, context), false);

const resumeStart = source.indexOf("function resumePasswordVault(");
const resumeEnd = source.indexOf("\n\tTimer {", resumeStart);
assert(resumeStart >= 0 && resumeEnd > resumeStart);
vm.runInContext(source.slice(resumeStart, resumeEnd), context);
context.passwordVaultSelectionSerial = 7;
context.androidAutofillRequestId = "";
context.passwordVaultNativeContext = { available: true, processId: 42,
    origin: "https://example.test", field: "username" };
context.passwordVaultToken = "test token";
context.editorSessionActive = false;
context.passwordVaultResumeAttempts = 0;
let loaded = 0;
let retries = 0;
context.loadPasswordCredentials = () => loaded++;
context.passwordVaultResumeTimer = { restart: () => retries++ };
context.helper = { typedCall: (method, args, done) => {
    assert.strictEqual(method, "RestoreNativeCredentialField");
    done(true);
} };
context.resumePasswordVault(7);
assert.strictEqual(loaded, 0);
assert.strictEqual(context.passwordVaultNativeContext.restored, true);
context.resumePasswordVault(7);
assert.strictEqual(loaded, 0);
context.editorSessionActive = true;
context.resumePasswordVault(7);
assert.strictEqual(loaded, 1);
assert.strictEqual(retries, 2);
context.passwordVaultSelectionSerial++;
context.resumePasswordVault(7);
assert.strictEqual(loaded, 1);
console.log("Platform changes and native authorization wait for an active editor");

vm.runInContext(functionsBetween("resolveBrowserCredentialOrigin", "resolveAndroidCredentialOrigin"), context);
context.normalizedApplicationId = value => value;
context.sailfishBrowserApplicationId = () => true;
context.nativeBrowserCredentialContextSerial = 0;
context.passwordFocusProtected = false;
let editorReply;
context.helper = { typedCall: (method, args, done) => { editorReply = done; } };
let resolvedOrigin;
context.resolveBrowserCredentialOrigin("sailfish-browser", false, value => { resolvedOrigin = value; });
context.nativeBrowserCredentialContextSerial++;
editorReply(JSON.stringify({ available: true, password: true, revealed: true, origin: "https://stale.test" }));
assert.strictEqual(resolvedOrigin, "");
assert.strictEqual(context.passwordFocusProtected, false);
context.resolveBrowserCredentialOrigin("sailfish-browser", false, value => { resolvedOrigin = value; });
editorReply(JSON.stringify({ available: true, password: true, revealed: true, origin: "https://current.test" }));
assert.strictEqual(resolvedOrigin, "https://current.test");
assert.strictEqual(context.nativeBrowserCredentialContext.revealed, true);
console.log("Revealed password roles stay private and stale editor replies are ignored");

vm.runInContext(functionsBetween("completePasswordVaultAuthorization", "openPasswordVault"), context);
context.passwordVaultAuthRequestId = "request-current";
context.passwordVaultAuthSerial = context.passwordVaultSelectionSerial;
context.androidAutofillRequestId = "";
let returnedTokens = 0;
context.helper = { typedCall: (method, args) => {
    assert.strictEqual(method, "LockVault");
    returnedTokens++;
} };
context.completePasswordVaultAuthorization("request-old", "unused-token");
assert.strictEqual(returnedTokens, 1);
assert.strictEqual(context.passwordVaultAuthRequestId, "request-current");
context.completePasswordVaultAuthorization("request-current", "current-token");
assert.strictEqual(context.passwordVaultToken, "current-token");
assert.strictEqual(context.passwordVaultAuthRequestId, "");
assert.strictEqual(context.passwordVaultResumeSerial, context.passwordVaultSelectionSerial);
console.log("Delayed authorization is caller-bound and stale tokens are locked");

vm.runInContext(functionsBetween("openPasswordVault", "selectSavedCredential"), context);
context.passwordVaultBusy = false;
context.passwordVaultToken = "previous-token";
context.passwordField = false;
context.unscopedCredentialField = false;
context.androidAutofillRequestId = "";
context.nativeBrowserCredentialContext = { available: false };
context.lastCredentialOrigin = "https://example.test";
context.resetSuggestionDisplay = () => {};
context.qsTr = text => text;
context.futoHandler = context;
let freshUnlocks = 0, retiredTokens = 0;
context.helper = { typedCall(method, args, done) {
    if (method === "VaultStatus") done("unlocked");
    else if (method === "LockVault") retiredTokens++;
    else if (method === "BeginVaultUnlock") { freshUnlocks++; done(true); }
    else assert.fail("unexpected vault operation " + method);
} };
context.openPasswordVault();
assert.strictEqual(retiredTokens, 1);
assert.strictEqual(context.passwordVaultToken, "");
assert.strictEqual(freshUnlocks, 1);
assert.strictEqual(context.passwordVaultBusy, true);
console.log("A new saved-login use always authenticates, even if the vault is already unlocked");

context.credentialDebug = () => {};
vm.runInContext(functionsBetween("noteCredentialFilled", "resetPasswordVault"), context);
const filledStart = source.indexOf("readonly property bool credentialFilledForCurrentOrigin:");
const filledEnd = source.indexOf("\n\tproperty ", filledStart);
assert(filledStart >= 0 && filledEnd > filledStart);
const filledExpression = source.slice(filledStart, filledEnd).split(":").slice(1).join(":").trim();
context.lastCredentialOrigin = "https://example.test";
context.noteCredentialFilled("https://example.test");
assert.strictEqual(vm.runInContext(filledExpression, context), true);
// Late focus metadata must not show the same offer again after filling.
context.credentialOfferDismissedForFocus = false;
assert.strictEqual(vm.runInContext(filledExpression, context), true);
context.lastCredentialOrigin = "https://other.test";
assert.strictEqual(vm.runInContext(filledExpression, context), false);
context.credentialFilledOrigin = "";
assert.strictEqual(vm.runInContext(filledExpression, context), false);
console.log("Completed autofill suppresses repeated offers only for the current login session");

vm.runInContext(functionsBetween("selectSavedCredential", "fillPassword"), context);
context.passwordVaultBusy = false;
context.passwordVaultToken = "test-token";
context.passwordVaultRequestedFromPassword = false;
context.passwordVaultRequestedOrigin = "https://example.test";
context.passwordVaultNativeContext = {
    available: true, processId: 42, origin: "https://example.test", field: "field-1"
};
context.androidAutofillRequestId = "";
let nativeFillCompleted;
context.helper = { typedCall: (method, args, completed) => {
    assert.strictEqual(method, "AutofillNativeCredential");
    nativeFillCompleted = completed;
} };
let closedChoosers = 0;
let hiddenChoosers = 0;
context.keyboard = { layout: { hideSavedCredentialChooser() { hiddenChoosers++; } } };
context.resetPasswordVault = () => { closedChoosers++; };
context.selectSavedCredential("test-entry", "test-user");
assert.strictEqual(hiddenChoosers, 1);
assert.strictEqual(context.passwordVaultPanelOpen, false);
context.passwordVaultNativeContext = {};
nativeFillCompleted(true);
assert.strictEqual(context.credentialFilledOrigin, "https://example.test");
assert.strictEqual(closedChoosers, 1);
assert.strictEqual(context.credentialCaptureSuppressed, false);
console.log("Native browser completion retains the selected origin and closes the chooser");

context.credentialLookupPrivateBlocked = true;
context.keyboardSettings.incognitoMode = false;
context.keyboardSettings.incognitoOnPrivacySwitch = false;
context.privacySwitchActive = false;
context.passwordVaultNativeFillPending = false;
assert.strictEqual(context.credentialLookupPrivacyCancelsFill(), true);
context.passwordVaultNativeFillPending = true;
assert.strictEqual(context.credentialLookupPrivacyCancelsFill(), false);
context.keyboardSettings.incognitoMode = true;
assert.strictEqual(context.credentialLookupPrivacyCancelsFill(), true);
context.keyboardSettings.incognitoMode = false;
context.keyboardSettings.incognitoOnPrivacySwitch = true;
context.privacySwitchActive = true;
assert.strictEqual(context.credentialLookupPrivacyCancelsFill(), true);
console.log("Native fill tolerates transitional field flags but respects explicit privacy controls");

vm.runInContext(functionsBetween("replaceCredentialEditorText", "retryCredentialSelection"), context);
const retryStart = source.indexOf("function retryCredentialSelection(");
const retryEnd = source.indexOf("\n\tTimer {", retryStart);
vm.runInContext(source.slice(retryStart, retryEnd), context);
context.credentialAutofillSerial = 20;
context.passwordField = true;
context.urlField = false;
context.credentialSelectionTimer = { restart() {} };
context.credentialAutofillContextCurrent = completed => completed();
context.credentialDebug = () => {};
let nativeCommits = [];
context.MInputMethodQuick.sendCommit = (...args) => nativeCommits.push(args);
context.MInputMethodQuick.surroundingTextValid = false;
let replacementFinished = 0;
const rejectedBefore = cancellations;
context.replaceCredentialEditorText("dummy-secret", true, () => replacementFinished++);
context.credentialSelectionTimer.completed();
assert.strictEqual(cancellations, rejectedBefore);
assert.strictEqual(nativeCommits.length, 0);
context.MInputMethodQuick.surroundingTextValid = true;
context.MInputMethodQuick.surroundingText = "";
context.MInputMethodQuick.cursorPosition = 0;
context.credentialSelectionTimer.completed();
assert.deepStrictEqual(nativeCommits, [["dummy-secret", -0, 0]]);
assert.strictEqual(replacementFinished, 1);
context.MInputMethodQuick.surroundingTextValid = false;
context.replaceCredentialEditorText("dummy-secret", true, () => replacementFinished++);
for (let attempt = 0; attempt < 7; attempt++) context.credentialSelectionTimer.completed();
assert.strictEqual(cancellations, rejectedBefore + 1);
assert.strictEqual(nativeCommits.length, 1);
assert.strictEqual(replacementFinished, 1);
console.log("Native autofill waits for valid editor metadata and fails closed after bounded retries");
