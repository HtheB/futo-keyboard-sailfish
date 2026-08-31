/*
 * FUTO Keyboard for Sailfish OS
 * Independent Sailfish integration; not an official FUTO product.
 */

import QtQuick 2.0
import com.meego.maliitquick 1.0
import Sailfish.Silica 1.0
import Sailfish.Silica.private 1.0 as SilicaPrivate
import com.jolla.keyboard 1.0
import Nemo.DBus 2.0
import Nemo.Configuration 1.0
import QtFeedback 5.0
import org.nemomobile.systemsettings 1.0

InputHandler {
    id: futoHandler

    property int candidateSpaceIndex: -1
    property bool committedSpaceArmed: false
    property bool committedSpaceAllowsPeriod: false
    property double committedSpaceTimestamp: 0
    property int committedSpaceExpectedCursor: -1
    property string preedit: ""
    property int requestSerial: 0
    property int urlRequestSerial: 0
    property bool trackSurroundings: false
    property string correctionQuery: ""
    property string correctionCandidate: ""
    property bool undoCorrectionAvailable: false
    property string undoOriginalWord: ""
    property string undoReplacementWord: ""
    property int undoCursorPosition: -1
    property bool privacySwitchActive: false
    property bool hardwareKeyboardAvailable: false
    property string detectedLanguage: "EN"
    property bool nextWordMode: false
    property string nextContextOverride: ""
    property string editingWord: ""
    property int editingWordStart: -1
    property int editingWordLength: 0
    property var learnedUrlSuggestions: []
    property bool urlSuggestionResultsActive: false
    property bool urlSuggestionFallbackActive: false
    property string urlAcceptedThisFocus: ""
    property string editorTypedBuffer: ""
	property var swipePath: []
	property string swipeLastKey: ""
	property int swipeSessionSerial: 0
	property int swipeOutstanding: 0
	property bool swipeReplacementActive: false
	property string swipePreviousWord: ""
	// A Space-bar drag owns the complete touch sequence.  Without this guard,
	// KeyboardBase starts feeding letter keys into swipe typing as soon as the
	// finger leaves Space, which steals cursor-control gestures.
	property bool spacebarGestureActive: false
	property bool cursorMoveMode: false
	property bool cursorSelectionMode: false
	// Desktop modifiers use a sticky-key model. A single tap latches the
	// modifier for exactly one real key event; a quick second tap locks it until
	// explicitly tapped again.
	property int desktopLatchedModifiers: 0
	property int desktopLockedModifiers: 0
	property string desktopLastModifierId: ""
	property double desktopLastModifierTapMs: 0
	readonly property int activeDesktopModifiers:
	        desktopLatchedModifiers | desktopLockedModifiers
	readonly property string desktopModifierStatusText:
	        desktopModifierSummary()
	property int pendingCursorHorizontalSteps: 0
	property int pendingCursorVerticalSteps: 0
	property bool voiceRecording: false
	property bool voiceBusy: false
	property string voiceMessage: ""
	property string voicePartial: ""
	property bool voicePollBusy: false
	property bool voiceStopPending: false
	property bool voiceLiveFailed: false
	property bool voicePushToTalk: false
	property int voiceSessionSerial: 0
	property bool passwordVaultPanelOpen: false
	property bool passwordVaultBusy: false
	property string passwordVaultMessage: ""
	property string passwordVaultToken: ""
	property bool passwordVaultRequestedFromPassword: false
	property string passwordVaultRequestedOrigin: ""
	property int passwordVaultSelectionSerial: 0
	property string credentialAutofillUsername: ""
	property string credentialAutofillPassword: ""
	// 0 = inactive, 1 = waiting for the username editor, 2 = waiting for
	// the password editor. Password data exists here only for the short-lived
	// autofill transaction and is cleared on success, cancellation, timeout,
	// keyboard dismissal, or Incognito mode.
	property int credentialAutofillStage: 0
	property int credentialAutofillStepAttempts: 0
	property int credentialAutofillFocusAttempts: 0
	property bool credentialOfferDismissedForFocus: false
	property string activeAndroidComponent: ""
	property string activePolicyApplicationId: ""
	property string activeApplicationDisplayName: ""
	property string activeApplicationDisplayPackage: ""
	property var applicationDisplayNames: ({})
	property int activeApplicationDisplaySerial: 0
	property bool androidSurfaceAwaitingIdentity: false
	readonly property int credentialOriginFallbackSeconds: 6 * 60 * 60
    property string credentialCapturePassword: ""
    property string credentialCaptureUsername: ""
    property string credentialCaptureOrigin: ""
    property string credentialPendingPassword: ""
    property string credentialPendingUsername: ""
    property string credentialPendingOrigin: ""
    property string lastCredentialUsername: ""
    property string lastCredentialOrigin: ""
    property bool credentialSaveInProgress: false
    property bool credentialCaptureSuppressed: false
	property bool credentialMatchAvailable: false
	property int credentialMatchSerial: 0
	property int contentRevision: 0
    readonly property string activeSuggestionQuery: preedit !== "" ? preedit : editingWord
    readonly property bool inputSessionActive: active || MInputMethodQuick.active
    readonly property bool editorSessionActive: inputSessionActive
            || !!MInputMethodQuick.extensions.focusState
    readonly property bool automaticIncognitoMode: MInputMethodQuick.hiddenText
            || (!MInputMethodQuick.predictionEnabled && !urlField)
            || !!MInputMethodQuick.extensions.privateMode
            || !!MInputMethodQuick.extensions.incognitoMode
            || !!MInputMethodQuick.extensions.sensitiveInput
            || (keyboardSettings.incognitoOnPrivacySwitch && privacySwitchActive)
    readonly property bool incognitoMode: keyboardSettings.incognitoMode
            || automaticIncognitoMode
    readonly property bool hardwareKeyboardSuppressed:
            !keyboardSettings.keepVirtualWithHardwareKeyboard
            && hardwareKeyboardAvailable
    readonly property string activePredictionLanguages: keyboard.layout
            && keyboard.layout.activePredictionLanguages !== undefined
            ? String(keyboard.layout.activePredictionLanguages)
            : String(keyboardSettings.enabledLanguages)
    readonly property bool activePredictionsAvailable: activePredictionLanguages.trim() !== ""
    readonly property bool explicitUrlField:
            MInputMethodQuick.contentType === Maliit.UrlContentType
            || urlMetadataAvailable()
    readonly property bool urlField: explicitUrlField || urlShapedEditorText()
    readonly property bool passwordField: MInputMethodQuick.hiddenText
            || !!MInputMethodQuick.extensions.sensitiveInput
	// Some terminal and console editors do not render Maliit's preedit text.
	// Commit each character immediately when the editor explicitly disables
	// prediction, or when its application identity identifies a terminal. URL
	// fields stay on the existing preedit path so swipe/search and URL-history
	// suggestions continue to work.
	readonly property bool immediateCommitField: !urlField
	        && (!MInputMethodQuick.predictionEnabled
	            || terminalInputApplication())
	readonly property bool credentialUsernameField: !passwordField && !urlField
	        && (usernameMetadataAvailable() || emailContentTypeActive()
	            || !MInputMethodQuick.predictionEnabled
	            // Many browser and AppSupport login forms expose their username
	            // editor as ordinary free text. Looking up the encrypted
	            // origin-count index is harmless; the prompt is still shown only
	            // when that exact website/application has a saved login.
	            || MInputMethodQuick.contentType === Maliit.FreeTextContentType)
	readonly property bool credentialFieldCandidate: passwordField
	        || credentialUsernameField
	readonly property bool credentialSavingPrivateBlocked:
            keyboardSettings.incognitoMode
            || !!MInputMethodQuick.extensions.privateMode
            || !!MInputMethodQuick.extensions.incognitoMode
            || (keyboardSettings.incognitoOnPrivacySwitch && privacySwitchActive)
	        || internalCredentialApplication(applicationIdFromMetadata())
	        || internalCredentialApplication(activePolicyApplicationId)
	// Private/password input must never be learned or offered for saving, but
	// using an existing encrypted login is a separate read-only operation. A
	// hidden password editor may expose private/incognito flags automatically;
	// do not let those flags remove the authenticated saved-login affordance.
	readonly property bool credentialLookupPrivateBlocked:
	        credentialSavingPrivateBlocked && !passwordField
    readonly property bool ordinaryPredictionStripEnabled:
            keyboardSettings.predictionEnabled && activePredictionsAvailable
            && !passwordField && (!urlField || urlSuggestionFallbackActive)
            && !hardwareKeyboardSuppressed
            && !keyboardSettings.forcedAppSupportKeyEvents
    readonly property bool urlHistoryStripEnabled:
            keyboardSettings.urlHistoryEnabled && urlField
            && !urlSuggestionFallbackActive
            && !passwordField && !incognitoMode && !hardwareKeyboardSuppressed
            && !keyboardSettings.forcedAppSupportKeyEvents
    readonly property bool showUrlSuggestions: keyboardSettings.urlHistoryEnabled
            && !passwordField && !incognitoMode && urlSuggestionResultsActive
            && !hardwareKeyboardSuppressed
    property var applicationSuggestions: []
    readonly property bool applicationSuggestionsRemovable:
            !!MInputMethodQuick.extensions.autoFillCanRemove
    readonly property bool predictionSuggestionsAvailable: {
        var count = predictionModel.count
        for (var i = 0; i < count; ++i) {
            var item = predictionModel.get(i)
            if (item && displayableSuggestion(item.text) !== "")
                return true
        }
        return false
    }
    readonly property bool showApplicationSuggestions: !hardwareKeyboardSuppressed
            && !keyboardSettings.forcedAppSupportKeyEvents
            && !showUrlSuggestions
            && applicationSuggestionModel.count > 0
            && (MInputMethodQuick.surroundingText.length + preedit.length) < 1
    readonly property string combinedText: {
        if (!showApplicationSuggestions)
            return ""
        var surrounding = MInputMethodQuick.surroundingText
        var position = MInputMethodQuick.cursorPosition
        return surrounding.substr(0, position) + preedit + surrounding.substr(position)
    }

    signal suggestionsUpdated()
    signal typingContinued()

	function endForcedAppSupportSession() {
		if (!keyboardSettings.forcedAppSupportKeyEvents)
			return
		keyboardSettings.forcedAppSupportKeyEvents = false
		helper.typedCall("EndAndroidKeyboard", [], function() {}, function() {})
	}

    function setHardwareKeyboardState(state) {
        var available = String(state) === "available"
        if (hardwareKeyboardAvailable !== available)
            hardwareKeyboardAvailable = available
        if (hardwareKeyboardSuppressed)
            hideForHardwareKeyboard()
    }

    function refreshHardwareKeyboardState() {
        mceKeyboardRequest.typedCall("keyboard_available_state_req", [],
            function(state) {
                futoHandler.setHardwareKeyboardState(state)
            }, function() {
                futoHandler.hardwareKeyboardAvailable = false
            })
    }

    function hideForHardwareKeyboard() {
        cancelVoiceInput()
        cancelSwipeSession()
        predictionTimer.stop()
        nextPredictionTimer.stop()
        urlSuggestionTimer.stop()
        predictionModel.clear()
        applicationSuggestionModel.clear()
        urlSuggestionResultsActive = false
        urlSuggestionFallbackActive = false
        if (keyboard.layout && keyboard.layout.hideControlStrip)
            keyboard.layout.hideControlStrip()
        if (MInputMethodQuick.active)
            MInputMethodQuick.userHide()
    }

    onHardwareKeyboardSuppressedChanged: {
        if (hardwareKeyboardSuppressed)
            hideForHardwareKeyboard()
    }

    function clearCredentialCapture(clearContext) {
        credentialCapturePassword = ""
        credentialCaptureUsername = ""
        credentialCaptureOrigin = ""
        credentialSaveInProgress = false
        credentialCaptureIdleTimer.stop()
        if (clearContext) {
            lastCredentialUsername = ""
            lastCredentialOrigin = ""
        }
    }

    function syncEditorTypedBuffer() {
		if (!passwordField && MInputMethodQuick.surroundingTextValid)
			editorTypedBuffer = String(MInputMethodQuick.surroundingText).slice(-2048)
	}

    function rememberCredentialContext() {
        if (passwordField || credentialSavingPrivateBlocked)
            return
		syncEditorTypedBuffer()
        var value = rawEditorText().trim()
		if (value === "") {
			if (credentialUsernameField)
				lastCredentialUsername = ""
			return
		}
        if (value.length > 320 || /[\r\n]/.test(value))
            return
        if (looksLikeUrlCandidate(value)) {
            lastCredentialOrigin = value
        } else if (value.indexOf(" ") < 0) {
            // Kept only in volatile keyboard memory until the user explicitly
            // accepts or dismisses the save prompt.
            lastCredentialUsername = value
        }
    }

    function credentialOriginFromMetadata() {
        var extensions = MInputMethodQuick.extensions || {}
        for (var key in extensions) {
            var lowerKey = String(key).toLowerCase()
            if (lowerKey.indexOf("origin") < 0
                    && lowerKey.indexOf("domain") < 0
                    && lowerKey.indexOf("host") < 0
                    && lowerKey.indexOf("url") < 0
                    && lowerKey.indexOf("uri") < 0)
                continue
            var candidate = String(extensions[key] || "").trim()
            if (looksLikeUrlCandidate(candidate))
                return candidate
        }
        return ""
    }

	function normalizedApplicationId(value) {
		value = String(value || "").trim()
		if (value.indexOf("/") >= 0)
			value = value.split("/")[0]
		if (value.indexOf(":") >= 0 && value.indexOf("://") < 0)
			value = value.split(":")[0]
		var lowerValue = value.toLocaleLowerCase()
		if (/^(none|null|undefined|unknown|not-applicable|na|0)$/.test(lowerValue)
				|| !/^[A-Za-z0-9][A-Za-z0-9._-]{1,239}$/.test(value))
			return ""
		return lowerValue
	}

	function browserApplicationId(value) {
		value = String(value || "").toLocaleLowerCase()
		return /firefox|fennec|chrome|chromium|browser|brave|opera|vivaldi|edge|duckduckgo/.test(
		        value)
	}

	function terminalInputApplication() {
		var metadataId = normalizedApplicationId(applicationIdFromMetadata())
		var policyId = normalizedApplicationId(activePolicyApplicationId)
		return /terminal|ghosteel|console/.test(metadataId)
		        || /terminal|ghosteel|console/.test(policyId)
	}

	function internalCredentialApplication(value) {
		var applicationId = normalizedApplicationId(value)
		return applicationId === "jolla-settings"
		        || applicationId === "com.jolla.settings"
		        || applicationId === "org.sailfishos.settings"
	}

	function applicationIdFromMetadata() {
		var extensions = MInputMethodQuick.extensions || {}
		for (var key in extensions) {
			var lowerKey = String(key).toLowerCase()
			if (lowerKey.indexOf("application") < 0
					&& lowerKey.indexOf("package") < 0
					&& lowerKey !== "appid" && lowerKey !== "app-id")
				continue
			var candidate = normalizedApplicationId(extensions[key])
			if (candidate !== "")
				return candidate
		}
		return ""
	}

	function refreshAndroidApplicationDisplayName() {
		var packageId = normalizedApplicationId(activeAndroidComponent)
		var serial = ++activeApplicationDisplaySerial
		activeApplicationDisplayName = ""
		activeApplicationDisplayPackage = packageId
		if (packageId === "")
			return

		// AppSupport provides the localized launcher label together with its
		// stable package id. Keep the package id for credential matching, but use
		// the human-facing label in prompts.
		androidApplicationTracker.typedCall("queryIntent", [
			{ "type": "s", "value": "android.intent.action.MAIN" },
			{ "type": "s", "value": "" },
			{ "type": "s", "value": "" },
			{ "type": "s", "value": packageId },
			{ "type": "s", "value": "" },
			{ "type": "s", "value": "" },
			{ "type": "a{sv}", "value": {} }
		], function(apps) {
			if (serial !== futoHandler.activeApplicationDisplaySerial
					|| packageId !== futoHandler.activeApplicationDisplayPackage)
				return
			var label = ""
			if (apps && apps.length > 0 && apps[0] && apps[0].length > 2)
				label = String(apps[0][2] || "").trim()
			futoHandler.activeApplicationDisplayName = label
			if (label !== "") {
				// appHidden/appShown may briefly toggle while AppSupport changes
				// focus. Preserve resolved labels for the lifetime of the keyboard
				// process so the prompt cannot fall back to the package name.
				var labels = {}
				for (var key in futoHandler.applicationDisplayNames)
					labels[key] = futoHandler.applicationDisplayNames[key]
				labels[packageId] = label
				futoHandler.applicationDisplayNames = labels
			}
		}, function() {
			if (serial === futoHandler.activeApplicationDisplaySerial)
				futoHandler.activeApplicationDisplayName = ""
		})
	}

	function credentialOriginDisplayName(value) {
		var origin = String(value || "").trim()
		var originKey = credentialOriginKey(origin)
		if (origin.toLocaleLowerCase().indexOf("app://") === 0) {
			var cachedLabel = String(applicationDisplayNames[originKey] || "").trim()
			if (cachedLabel !== "")
				return cachedLabel
			if (originKey === activeApplicationDisplayPackage
					&& activeApplicationDisplayName.trim() !== "")
				return activeApplicationDisplayName
		}
		return originKey
	}

	function resolveApplicationCredentialOrigin(callback) {
		var candidate = applicationIdFromMetadata()
		if (candidate === "")
			candidate = normalizedApplicationId(activeAndroidComponent)
		if (candidate !== "" && !browserApplicationId(candidate)) {
			androidSurfaceAwaitingIdentity = false
			callback("app://" + candidate)
			return
		}
		applicationCompositor.typedCall(
				"privateTopmostWindowPolicyApplicationId", [], function(applicationId) {
				var policyId = futoHandler.normalizedApplicationId(applicationId)
				futoHandler.activePolicyApplicationId = policyId
				// Android AppSupport exposes a transient hexadecimal surface id
				// here. Its stable package arrives through com.jolla.apkd instead.
				if (/^[0-9a-f]+$/.test(policyId)) {
					futoHandler.androidSurfaceAwaitingIdentity = true
					callback("")
				} else if (policyId === "" || futoHandler.browserApplicationId(policyId)) {
					futoHandler.androidSurfaceAwaitingIdentity = false
					callback("")
				} else {
					futoHandler.androidSurfaceAwaitingIdentity = false
					callback("app://" + policyId)
				}
			}, function() {
				futoHandler.androidSurfaceAwaitingIdentity = false
				callback("")
			})
	}

	function emailContentTypeActive() {
		return typeof Maliit.EmailContentType !== "undefined"
		        && MInputMethodQuick.contentType === Maliit.EmailContentType
	}

	function usernameMetadataAvailable() {
		var extensions = MInputMethodQuick.extensions || {}
		for (var key in extensions) {
			var lowerKey = String(key).toLowerCase()
			var value = extensions[key]
			var valueText = String(value || "").toLowerCase()
			var fieldMetadata = lowerKey.indexOf("hint") >= 0
			        || lowerKey.indexOf("purpose") >= 0
			        || lowerKey.indexOf("autofill") >= 0
			        || lowerKey.indexOf("field") >= 0
			        || lowerKey.indexOf("name") >= 0
			        || lowerKey.indexOf("contenttype") >= 0
			        || lowerKey.indexOf("inputtype") >= 0
			if (fieldMetadata
			        && /user(name)?|e-?mail|login|account|identifier/.test(valueText))
				return true
			if (/username|user-name|loginname|login-name|emailfield|accountname/.test(
			        lowerKey) && (value === true || Number(value) > 0
			                     || valueText !== ""))
				return true
			// Android email and web-email text variations. A plain username
			// normally arrives with predictions disabled and is covered by the
			// conservative fallback in credentialUsernameField.
			if (lowerKey === "androidinputtype" && typeof value === "number") {
				var variation = Number(value) & 0xff0
				if (variation === 0x20 || variation === 0xd0)
					return true
			}
		}
		return false
	}

	function requestCredentialMatch(origin, serial) {
		origin = String(origin || "").trim()
		if (origin === "" || serial !== credentialMatchSerial)
			return
		credentialDebug("lookup serial=" + serial + " origin=" + origin)
		helper.typedCall("CredentialMatchCount", [
			{ "type": "s", "value": origin }
		], function(count) {
			futoHandler.credentialDebug("result serial=" + serial
			                            + " count=" + Number(count)
			                            + " candidate="
			                            + futoHandler.credentialFieldCandidate
			                            + " password=" + futoHandler.passwordField
			                            + " dismissed="
			                            + futoHandler.credentialOfferDismissedForFocus
			                            + " panel="
			                            + futoHandler.passwordVaultPanelOpen)
			if (serial === futoHandler.credentialMatchSerial
					&& futoHandler.credentialFieldCandidate) {
				futoHandler.lastCredentialOrigin = origin
				futoHandler.credentialMatchAvailable = Number(count) > 0
			}
		}, function() {
			if (serial === futoHandler.credentialMatchSerial)
				futoHandler.credentialMatchAvailable = false
		})
	}

	function refreshCredentialMatch() {
		var serial = ++credentialMatchSerial
		credentialMatchAvailable = false
		if (!credentialFieldCandidate || !keyboardSettings.passwordSavingEnabled
				|| credentialLookupPrivateBlocked) {
			credentialDebug("skip candidate=" + credentialFieldCandidate
			                + " enabled=" + keyboardSettings.passwordSavingEnabled
			                + " private=" + credentialLookupPrivateBlocked)
			return
		}
		var origin = credentialOriginFromMetadata()
		if (origin !== "") {
			credentialDebug("metadata-origin=" + origin)
			requestCredentialMatch(origin, serial)
			return
		}
		resolveApplicationCredentialOrigin(function(applicationOrigin) {
			if (serial !== futoHandler.credentialMatchSerial)
				return
			if (applicationOrigin !== "") {
				futoHandler.credentialDebug("application-origin=" + applicationOrigin)
				futoHandler.requestCredentialMatch(applicationOrigin, serial)
				return
			}
			if (futoHandler.androidSurfaceAwaitingIdentity) {
				futoHandler.credentialDebug("waiting-for-android-package")
				return
			}
			// Browser identities are deliberately excluded from application
			// origins. Only there may the URL remembered across the username and
			// password fields be reused.
			if (futoHandler.lastCredentialOrigin !== "") {
				futoHandler.credentialDebug("remembered-origin="
				                            + futoHandler.lastCredentialOrigin)
				futoHandler.requestCredentialMatch(
				        futoHandler.lastCredentialOrigin, serial)
				return
			}
			futoHandler.credentialDebug("recent-url-fallback")
			futoHandler.requestRecentWebsiteCredentialMatch(serial)
		})
	}

	function requestRecentWebsiteCredentialMatch(serial) {
		// Browser password editors do not consistently expose their page URL.
		// Reuse only the newest URL observed during the current working session;
		// never open or advertise a generic all-sites vault.
		helper.typedCall("ListURLs", [], function(resultJson) {
			if (serial !== futoHandler.credentialMatchSerial)
				return
			var entries = []
			try { entries = JSON.parse(String(resultJson)) } catch (error) {}
			if (entries.length < 1) {
				futoHandler.credentialDebug("recent-url empty")
				return
			}
			var newest = entries[0]
			var ageSeconds = Math.floor(Date.now() / 1000)
					- Number(newest.lastUsed || 0)
			var candidate = String(newest.text || "")
			futoHandler.credentialDebug("recent-url age=" + ageSeconds
			                            + " candidate=" + candidate)
			if (ageSeconds >= 0
					&& ageSeconds <= futoHandler.credentialOriginFallbackSeconds
					&& futoHandler.looksLikeUrlCandidate(candidate))
				futoHandler.requestCredentialMatch(candidate, serial)
		}, function() {})
	}

    function finalizeCredentialCapture() {
        if (credentialCapturePassword === "" || credentialCaptureSuppressed)
            return
        credentialCaptureIdleTimer.stop()
        credentialCaptureUsername = lastCredentialUsername
        credentialCaptureOrigin = lastCredentialOrigin
    }

    function captureCredentialKey(key) {
        if (!passwordField || !keyboardSettings.passwordSavingEnabled
                || credentialSavingPrivateBlocked || credentialCaptureSuppressed
                || !key)
            return
        if (key.key === Qt.Key_Return || key.key === Qt.Key_Enter) {
            finalizeCredentialCapture()
            offerCapturedCredential()
            return
        }
        credentialCaptureIdleTimer.stop()
        if (key.key === Qt.Key_Backspace) {
            credentialCapturePassword = credentialCapturePassword.slice(0, -1)
        } else if (key.text && key.text.length > 0) {
            credentialCapturePassword = (credentialCapturePassword
                    + String(key.text)).slice(-4096)
        }
        credentialCaptureUsername = lastCredentialUsername
        credentialCaptureOrigin = lastCredentialOrigin
        if (credentialCapturePassword.length > 0)
            credentialCaptureIdleTimer.restart()
    }

    function finishCredentialOffer() {
        credentialSaveInProgress = false
        credentialCapturePassword = ""
        credentialCaptureUsername = ""
        credentialCaptureOrigin = ""
        credentialPendingPassword = ""
        credentialPendingUsername = ""
        credentialPendingOrigin = ""
        lastCredentialUsername = ""
        lastCredentialOrigin = ""
    }

    function publishCredentialOffer() {
        if (credentialPendingOrigin === "") {
            finishCredentialOffer()
            return
        }
        helper.typedCall("OfferCredentialSave", [
            { "type": "s", "value": credentialPendingOrigin },
            { "type": "s", "value": credentialPendingUsername },
            { "type": "s", "value": credentialPendingPassword }
        ], function(offered) {
            futoHandler.finishCredentialOffer()
        }, function() {
            futoHandler.finishCredentialOffer()
        })
    }

	function resolveCredentialOriginAndOffer() {
		var metadataOrigin = credentialOriginFromMetadata()
		if (metadataOrigin !== "") {
			credentialPendingOrigin = metadataOrigin
			publishCredentialOffer()
			return
		}

		resolveApplicationCredentialOrigin(function(applicationOrigin) {
			if (!futoHandler.credentialSaveInProgress)
				return
			if (futoHandler.internalCredentialApplication(
					String(applicationOrigin).replace(/^app:\/\//i, ""))) {
				futoHandler.finishCredentialOffer()
				return
			}
			if (applicationOrigin !== "") {
				futoHandler.credentialPendingOrigin = applicationOrigin
				futoHandler.publishCredentialOffer()
				return
			}
			if (futoHandler.credentialPendingOrigin !== "") {
				futoHandler.publishCredentialOffer()
				return
			}
			futoHandler.resolveRecentWebsiteAndOffer()
		})
	}

	function resolveRecentWebsiteAndOffer() {
		helper.typedCall("ListURLs", [], function(resultJson) {
            var entries = []
            try { entries = JSON.parse(String(resultJson)) } catch (error) {}
            if (entries.length > 0) {
                var newest = entries[0]
                var ageSeconds = Math.floor(Date.now() / 1000)
                        - Number(newest.lastUsed || 0)
                var candidate = String(newest.text || "")
				if (ageSeconds >= 0
						&& ageSeconds <= futoHandler.credentialOriginFallbackSeconds
                        && futoHandler.looksLikeUrlCandidate(candidate))
                    futoHandler.credentialPendingOrigin = candidate
            }
            futoHandler.publishCredentialOffer()
        }, function() {
            futoHandler.finishCredentialOffer()
        })
    }

    function offerCapturedCredential() {
        if (credentialSaveInProgress || credentialCapturePassword === "")
            return
        credentialPendingPassword = credentialCapturePassword
        credentialPendingUsername = credentialCaptureUsername
        credentialPendingOrigin = credentialCaptureOrigin
        credentialSaveInProgress = true
        credentialCaptureIdleTimer.stop()
        resolveCredentialOriginAndOffer()
    }

    function urlMetadataAvailable() {
        var extensions = MInputMethodQuick.extensions || {}
        for (var key in extensions) {
            var lowerKey = String(key).toLowerCase()
            var value = extensions[key]
            if ((lowerKey === "inputmethodhints" || lowerKey === "inputhints"
                    || lowerKey === "hints") && typeof value === "number"
                    && (Number(value) & Number(Qt.ImhUrlCharactersOnly)) !== 0)
                return true
            if (lowerKey === "androidinputtype" && typeof value === "number"
                    && (Number(value) & 0xfff) === 0x11)
                return true
            if (lowerKey.indexOf("url") >= 0 || lowerKey.indexOf("uri") >= 0) {
                if (value === true || Number(value) > 0
                        || /url|uri|web/i.test(String(value)))
                    return true
            }
            if ((lowerKey.indexOf("purpose") >= 0
                    || lowerKey.indexOf("contenttype") >= 0
                    || lowerKey.indexOf("inputtype") >= 0)
                    && /url|uri|web/i.test(String(value)))
                return true
        }
        return false
    }

    function rawEditorText() {
        if (!MInputMethodQuick.surroundingTextValid)
            return editorTypedBuffer !== "" ? editorTypedBuffer : String(preedit)
        var surrounding = String(MInputMethodQuick.surroundingText)
        var cursor = Math.max(0, Math.min(MInputMethodQuick.cursorPosition,
                                          surrounding.length))
        var before = surrounding.substring(0, cursor)
        var composing = String(preedit)
        // Some Android editors already include Maliit's current preedit in
        // surroundingText. Appending it again turned "twe" into "twewe",
        // making every URL-history lookup miss. Merge only the non-overlapping
        // suffix so both Android and native editor conventions work.
        var overlap = Math.min(before.length, composing.length)
        while (overlap > 0
                && before.substring(before.length - overlap)
                        !== composing.substring(0, overlap))
            --overlap
        return before + composing.substring(overlap)
                + surrounding.substring(cursor)
    }

    function looksLikeUrlCandidate(value) {
        value = String(value).trim()
        if (value === "" || value.length > 2048 || /\s/.test(value)
                || value.indexOf("@") >= 0)
            return false
        if (/^[a-z][a-z0-9+.-]*:\/\//i.test(value)
                || /^www\./i.test(value) || /^localhost(?::\d+)?(?:\/|$)/i.test(value))
            return true
        if (/^(?:\d{1,3}\.){3}\d{1,3}(?::\d+)?(?:\/|$)/.test(value))
            return true
        return /^[^./]+(?:\.[^./]+)+(?:[/:?#].*)?$/.test(value)
    }

    function urlShapedEditorText() {
        return !MInputMethodQuick.hiddenText && looksLikeUrlCandidate(rawEditorText())
    }

    function captureEditorKey(key) {
        if (passwordField || !key)
            return
        if (key.key === Qt.Key_Backspace) {
            editorTypedBuffer = editorTypedBuffer.slice(0, -1)
        } else if (key.key === Qt.Key_Return || key.key === Qt.Key_Enter) {
            return
        } else if (key.text && key.text.length > 0) {
            var text = String(key.text)
            if (/\s/.test(text))
                editorTypedBuffer = ""
            else
                editorTypedBuffer = (editorTypedBuffer + text).slice(-2048)
        }
		// Android browsers can invalidate surroundingText during the focus handoff
		// from username to password. Preserve the typed username on every key so
		// the later password capture never depends on that transient editor state.
		var credentialCandidate = String(editorTypedBuffer || "").trim()
		if (credentialCandidate !== "" && credentialCandidate.length <= 320
				&& credentialCandidate.indexOf(" ") < 0
				&& !looksLikeUrlCandidate(credentialCandidate))
			lastCredentialUsername = credentialCandidate
        if (keyboardSettings.urlHistoryEnabled)
            urlSuggestionTimer.restart()
    }

	ListModel { id: passwordCredentialModel }
	property alias savedCredentialModel: passwordCredentialModel

	function credentialOriginKey(value) {
		value = String(value || "").trim().toLocaleLowerCase()
		value = value.replace(/^[a-z][a-z0-9+.-]*:\/\//i, "")
		return value.split(/[\/?#]/)[0]
	}

	function credentialDebug(message) {
		if (keyboardSettings.debugInputContext)
			console.warn("FUTO_CREDENTIAL " + String(message))
	}

	function resetPasswordVault(lockVault) {
		passwordVaultSelectionSerial++
		passwordVaultPanelOpen = false
		passwordVaultBusy = false
		passwordVaultMessage = ""
		passwordCredentialModel.clear()
		if (keyboard.layout && keyboard.layout.hideSavedCredentialChooser)
			keyboard.layout.hideSavedCredentialChooser()
		if (lockVault && passwordVaultToken !== "")
			helper.typedCall("LockVault", [
				{ "type": "s", "value": passwordVaultToken }
			], function() {}, function() {})
		passwordVaultToken = ""
		passwordVaultRequestedOrigin = ""
	}

	function cancelSavedCredentialChooser() {
		credentialOfferDismissedForFocus = true
		resetPasswordVault(true)
	}

	function loadPasswordCredentials(requestSerial) {
		var requestedToken = passwordVaultToken
		helper.typedCall("ListCredentials", [
			{ "type": "s", "value": requestedToken }
		], function(resultJson) {
			if (requestSerial !== futoHandler.passwordVaultSelectionSerial
					|| requestedToken === ""
					|| requestedToken !== futoHandler.passwordVaultToken)
				return
			var entries = []
			try { entries = JSON.parse(String(resultJson)) } catch (error) {}
			var preferred = []
			var wantedOrigin = futoHandler.credentialOriginKey(
			        futoHandler.passwordVaultRequestedOrigin)
			for (var i = 0; i < entries.length; ++i) {
				var entryOrigin = futoHandler.credentialOriginKey(entries[i].origin)
				if (wantedOrigin !== "" && entryOrigin === wantedOrigin)
					preferred.push(entries[i])
			}
			// Always show every account for this exact website. The user may
			// deliberately want to replace an already typed username with a
			// different saved account.
			var visibleEntries = preferred
			passwordCredentialModel.clear()
			for (var j = 0; j < visibleEntries.length; ++j) {
				var entry = visibleEntries[j]
				var username = String(entry.username || "")
				passwordCredentialModel.append({
					"entryId": String(entry.id),
					"entryText": username !== "" ? username : qsTr("Password only"),
					"entryUsername": username,
					"entryOrigin": String(entry.origin || "")
				})
			}
			passwordVaultBusy = false
			passwordVaultPanelOpen = visibleEntries.length > 0
			passwordVaultMessage = visibleEntries.length === 0
			        ? qsTr("No saved logins") : ""
			if (passwordVaultPanelOpen && keyboard.layout
					&& keyboard.layout.showSavedCredentialChooser) {
				futoHandler.resetSuggestionDisplay()
				keyboard.layout.showSavedCredentialChooser()
			} else if (!passwordVaultPanelOpen) {
				resetPasswordVault(true)
			}
		}, function() {
			if (requestSerial === futoHandler.passwordVaultSelectionSerial) {
				resetPasswordVault(true)
				passwordVaultMessage = qsTr("Password vault locked")
			}
		})
	}

	function openPasswordVault() {
		if (passwordVaultBusy)
			return
		// The credential chooser owns the keyboard surface. Invalidate every
		// outstanding prediction request before device authentication so an old
		// delegate cannot flash over the chooser during its height transition.
		resetSuggestionDisplay()
		var requestSerial = ++passwordVaultSelectionSerial
		passwordVaultBusy = true
		passwordVaultRequestedFromPassword = passwordField
		// Authentication temporarily changes focus and may hide the originating
		// app surface. Bind this chooser transaction to the exact origin that the
		// user tapped, never to whatever focus reports after authentication.
		passwordVaultRequestedOrigin = lastCredentialOrigin
		passwordVaultMessage = qsTr("Authenticating…")
		helper.typedCall("VaultStatus", [], function(status) {
			if (requestSerial !== futoHandler.passwordVaultSelectionSerial)
				return
			status = String(status)
			if (status === "unlocked" && passwordVaultToken !== "") {
				loadPasswordCredentials(requestSerial)
			} else if (status === "locked" || status === "unlocked") {
				helper.typedCall("UnlockVault", [], function(token) {
					if (requestSerial !== futoHandler.passwordVaultSelectionSerial)
						return
					passwordVaultToken = String(token)
					if (passwordVaultToken !== "")
						loadPasswordCredentials(requestSerial)
				}, function() {
					if (requestSerial === futoHandler.passwordVaultSelectionSerial) {
						passwordVaultBusy = false
						passwordVaultMessage = qsTr("Authentication canceled")
					}
				})
			} else {
				passwordVaultBusy = false
				passwordVaultMessage = qsTr("Set up Saved passwords in FUTO Settings")
			}
		}, function() {
			if (requestSerial === futoHandler.passwordVaultSelectionSerial) {
				passwordVaultBusy = false
				passwordVaultMessage = qsTr("Password vault unavailable")
			}
		})
	}

	function selectSavedCredential(entryId, username) {
		if (passwordVaultBusy || passwordVaultToken === "")
			return
		passwordVaultBusy = true
		var selectionSerial = ++passwordVaultSelectionSerial
		var startedFromPassword = passwordVaultRequestedFromPassword
		helper.typedCall("CredentialSecret", [
			{ "type": "s", "value": passwordVaultToken },
			{ "type": "s", "value": String(entryId) },
			{ "type": "s", "value": "password" }
		], function(secret) {
			if (selectionSerial !== futoHandler.passwordVaultSelectionSerial)
				return
			var password = String(secret)
			if (password === "") {
				resetPasswordVault(true)
				return
			}
			var selectedUsername = String(username || "")
			// Close and lock the vault before putting the selected secret into
			// the short-lived autofill transaction.
			resetPasswordVault(true)
			beginCredentialAutofill(selectedUsername, password,
			                            startedFromPassword)
		}, function() {
			if (selectionSerial === futoHandler.passwordVaultSelectionSerial)
				resetPasswordVault(true)
		})
	}

	// Kept as a compatibility entry point for an installed layout that may
	// briefly survive an RPM upgrade until the keyboard process reloads.
	function fillPassword(entryId) {
		for (var i = 0; i < passwordCredentialModel.count; ++i) {
			var entry = passwordCredentialModel.get(i)
			if (String(entry.entryId) === String(entryId)) {
				selectSavedCredential(entryId, entry.entryUsername)
				return
			}
		}
	}

	function replaceCredentialEditorText(value, replacingPassword) {
		value = String(value || "")
		var currentLength = 0
		var cursor = 0
		if (MInputMethodQuick.surroundingTextValid) {
			currentLength = String(MInputMethodQuick.surroundingText).length
			cursor = Math.max(0, Math.min(Number(MInputMethodQuick.cursorPosition),
			                              currentLength))
		} else if (replacingPassword) {
			currentLength = String(credentialCapturePassword || "").length
			cursor = currentLength
		} else {
			currentLength = String(editorTypedBuffer || "").length
			cursor = currentLength
		}
		MInputMethodQuick.sendCommit(value, -cursor, currentLength)
		preedit = ""
		if (replacingPassword) {
			credentialCapturePassword = ""
		} else {
			editorTypedBuffer = value
			lastCredentialUsername = value
		}
	}

	function sendLegacyCredentialFocusStep(backward, attempt) {
		if (backward) {
			// AppSupport and browser input connections disagree about whether a
			// reverse focus traversal is Shift+Tab or Key_Backtab. Alternate on
			// retries so both implementations work.
			if ((attempt % 2) === 0)
				MInputMethodQuick.sendKey(Qt.Key_Tab, Qt.ShiftModifier, "",
				                          Maliit.KeyClick)
			else
				MInputMethodQuick.sendKey(Qt.Key_Backtab, Qt.ShiftModifier, "",
				                          Maliit.KeyClick)
		} else {
			// Some AppSupport browsers treat a Tab event carrying a literal tab
			// character as text input and never advance focus. Alternate the
			// native key-only event with the legacy representation on retries.
			var tabText = (attempt % 2) === 0 ? "" : "\t"
			MInputMethodQuick.sendKey(Qt.Key_Tab, 0, tabText, Maliit.KeyClick)
		}
	}

	function sendCredentialFocusStep(backward) {
		var attempt = credentialAutofillFocusAttempts++
		credentialDebug("focus-step stage=" + credentialAutofillStage
		                + " backward=" + backward
		                + " attempt=" + attempt
		                + " password=" + passwordField)
		var direction = backward ? "previous" : "next"
		helper.typedCall("FocusCredentialField", [
			{ "type": "s", "value": direction }
		], function(moved) {
			if (futoHandler.credentialAutofillStage === 0)
				return
			if (!moved)
				futoHandler.sendLegacyCredentialFocusStep(backward, attempt)
			credentialAutofillStepTimer.restart()
		}, function() {
			if (futoHandler.credentialAutofillStage === 0)
				return
			futoHandler.sendLegacyCredentialFocusStep(backward, attempt)
			credentialAutofillStepTimer.restart()
		})
	}

	function beginCredentialAutofill(username, password, startedFromPassword) {
		cancelCredentialAutofill(false)
		// Closing the chooser exposes the suggestion strip again before the
		// editor has changed focus. Keep the saved-login offer dismissed for the
		// complete autofill transaction so it cannot immediately prompt twice.
		credentialOfferDismissedForFocus = true
		credentialCaptureSuppressed = true
		clearCredentialCapture(true)
		credentialCaptureSuppressed = true
		credentialAutofillUsername = String(username || "")
		credentialAutofillPassword = String(password || "")
		credentialAutofillStepAttempts = 0
		credentialAutofillFocusAttempts = 0
		credentialAutofillTimeout.restart()
		if (credentialAutofillUsername === "" && passwordField) {
			// Password-only apps and pages have no previous username editor.
			// The editor is already focused, so no focus traversal is necessary.
			// Do not send the password as a text commit here.
			credentialOfferDismissedForFocus = true
			cancelCredentialAutofill(false)
			return
		}
		if (startedFromPassword || passwordField) {
			credentialAutofillStage = 1
			credentialAutofillStartTimer.restart()
		} else {
			replaceCredentialEditorText(credentialAutofillUsername, false)
			credentialAutofillStage = 2
			credentialAutofillStartTimer.restart()
		}
	}

	function advanceCredentialAutofill() {
		if (credentialAutofillStage === 0)
			return
		credentialAutofillStepAttempts++
		credentialDebug("advance stage=" + credentialAutofillStage
		                + " step=" + credentialAutofillStepAttempts
		                + " password=" + passwordField
		                + " username=" + credentialUsernameField)
		if (credentialAutofillStage === 1 && !passwordField && !urlField) {
			replaceCredentialEditorText(credentialAutofillUsername, false)
			credentialAutofillStage = 2
			credentialAutofillStepAttempts = 0
			credentialAutofillFocusAttempts = 0
			// Give the editor time to apply the username commit before moving
			// forward and inserting the password.
			credentialAutofillStartTimer.restart()
			return
		}
		if (credentialAutofillStage === 2 && passwordField) {
			// Reaching the password editor completes the handoff. Applications and
			// browsers can populate it as part of their normal credential flow; an
			// extra text commit here would duplicate the password.
			credentialOfferDismissedForFocus = true
			cancelCredentialAutofill(false)
			return
		}
		// Browsers may update their input context a few frames after Tab. Keep
		// polling briefly; the longer timeout also permits a manual tap on the
		// corresponding field if an application does not implement Tab focus.
		if (credentialAutofillStepAttempts === 6
				|| credentialAutofillStepAttempts === 14) {
			sendCredentialFocusStep(credentialAutofillStage === 1)
		} else if (credentialAutofillStepAttempts < 28) {
			credentialAutofillStepTimer.restart()
		}
	}

	function cancelCredentialAutofill(clearOffer) {
		credentialAutofillStartTimer.stop()
		credentialAutofillStepTimer.stop()
		credentialAutofillTimeout.stop()
		credentialAutofillUsername = ""
		credentialAutofillPassword = ""
		credentialAutofillStage = 0
		credentialAutofillStepAttempts = 0
		credentialAutofillFocusAttempts = 0
		credentialCaptureSuppressed = false
		if (clearOffer)
			credentialOfferDismissedForFocus = true
	}

	Timer {
		id: credentialAutofillStartTimer
		interval: 240
		repeat: false
		onTriggered: {
			if (futoHandler.credentialAutofillStage === 1)
				futoHandler.sendCredentialFocusStep(true)
			else if (futoHandler.credentialAutofillStage === 2)
				futoHandler.sendCredentialFocusStep(false)
		}
	}

	Timer {
		id: credentialAutofillStepTimer
		interval: 110
		repeat: false
		onTriggered: futoHandler.advanceCredentialAutofill()
	}

	Timer {
		id: credentialAutofillTimeout
		interval: 20000
		repeat: false
		onTriggered: futoHandler.cancelCredentialAutofill(true)
	}

    function displayableSuggestion(value) {
        if (value === undefined || value === null)
            return ""
        var text = String(value)
        return text.trim() === "" ? "" : text
    }

    function nonEmptySuggestions(values) {
        var result = []
        if (!values || values.length === undefined)
            return result
        for (var i = 0; i < values.length; ++i) {
            var text = displayableSuggestion(values[i])
            if (text !== "")
                result.push(text)
        }
        return result
    }

    function compactUrlSuggestion(value) {
        return String(value).replace(/^[a-z][a-z0-9+.-]*:\/\//i, "")
                .replace(/^([^\/?#]+)\/$/, "$1")
    }

    function refreshApplicationSuggestions() {
        var values = nonEmptySuggestions(
                MInputMethodQuick.extensions.autoFillSuggestions || [])
        applicationSuggestions = values
        applicationSuggestionModel.clear()
        for (var i = 0; i < values.length; ++i)
            applicationSuggestionModel.append({ "text": values[i] })
        suggestionsUpdated()
    }

    function replaceUrlPredictionSuggestions(values) {
        var urls = nonEmptySuggestions(values)
        var compact = []
        var seen = {}
        for (var i = 0; i < urls.length; ++i) {
            var displayed = compactUrlSuggestion(urls[i])
            var key = displayed.toLocaleLowerCase()
            if (displayed !== "" && !seen[key]) {
                seen[key] = true
                compact.push({ "text": displayed, "source": String(urls[i]) })
            }
        }
        predictionModel.clear()
        for (var j = 0; j < compact.length; ++j)
            predictionModel.append(compact[j])
        urlSuggestionResultsActive = compact.length > 0
        urlSuggestionFallbackActive = false
        suggestionsUpdated()
        return compact.length
    }

    function clearUrlPredictionSuggestions() {
        if (urlSuggestionResultsActive)
            predictionModel.clear()
        urlSuggestionResultsActive = false
        urlSuggestionFallbackActive = false
        suggestionsUpdated()
    }

    function replacePredictionSuggestions(values) {
        predictionModel.clear()
        var suggestions = nonEmptySuggestions(values)
        for (var i = 0; i < suggestions.length; ++i)
            predictionModel.append({ "text": suggestions[i],
                                     "source": suggestions[i] })
        return suggestions.length
    }

    ProfileControl {
        id: systemFeedback
    }

    ThemeEffect {
        id: customButtonVibration
        effect: ThemeEffect.PressWeak
    }

    // Silence Jolla's profile-controlled samples only while FUTO is active.
    // FUTO sounds are sent through the isolated helper instead.
    Binding {
        target: SampleCache
        property: "outputEnabled"
        value: !futoHandler.active && systemFeedback.touchscreenToneLevel !== 0
    }

    onSelect: {
        playOptionFeedback()
        if (showUrlSuggestions) {
            var acceptedUrl = String(text)
            urlAcceptedThisFocus = acceptedUrl
            lastCredentialOrigin = acceptedUrl
            ++requestSerial
            ++urlRequestSerial
            predictionTimer.stop()
            nextPredictionTimer.stop()
            urlSuggestionTimer.stop()
            MInputMethodQuick.sendCommit(acceptedUrl, -MInputMethodQuick.cursorPosition,
                                         MInputMethodQuick.surroundingText.length)
            // The URL editor now owns acceptedUrl.  Keeping the old composing
            // prefix here made Enter commit it once more (for example,
            // "tweakers.net" became "tweakers.nettwe").
            preedit = ""
            editorTypedBuffer = acceptedUrl
            nextWordMode = false
            nextContextOverride = ""
            correctionQuery = ""
            correctionCandidate = ""
            clearEditingWord()
            clearUndoCorrection()
            predictionModel.clear()
            learnedUrlSuggestions = []
            urlSuggestionResultsActive = false
            urlSuggestionFallbackActive = false
            suggestionsUpdated()
        } else if (showApplicationSuggestions) {
            MInputMethodQuick.sendCommit(text, -MInputMethodQuick.cursorPosition,
                                         MInputMethodQuick.surroundingText.length)
        } else {
            applyPrediction(text)
        }
    }

    onRemove: {
        playOptionFeedback()
        if (showUrlSuggestions) {
            forgetUrlSuggestion(text, index)
        } else if (showApplicationSuggestions) {
            MInputMethodQuick.sendKey(Qt.Key_Delete, 0x80000000, text)
        } else {
            forgetSuggestion(text, index)
        }
    }

    onPaste: {
        playOptionFeedback()
        if (passwordField && keyboardSettings.passwordSavingEnabled
                && !credentialSavingPrivateBlocked) {
            credentialCapturePassword = (credentialCapturePassword
                    + String(Clipboard.text)).slice(-4096)
            credentialCaptureUsername = lastCredentialUsername
            credentialCaptureOrigin = lastCredentialOrigin
            credentialCaptureIdleTimer.restart()
        }
        if (!passwordField) {
            var pasted = String(Clipboard.text)
            editorTypedBuffer = /\s/.test(pasted) ? ""
                    : (editorTypedBuffer + pasted).slice(-2048)
        }
        commit(preedit)
        MInputMethodQuick.sendCommit(Clipboard.text)
    }

    DBusInterface {
        id: helper
        bus: DBus.SessionBus
        service: "org.hb.FutoKeyboard1"
        path: "/org/hb/FutoKeyboard1"
        iface: "org.hb.FutoKeyboard1"
		signalsEnabled: true
        watchServiceStatus: true

		function contentChanged(packId, state) {
			futoHandler.contentRevision++
			futoHandler.requestSuggestionsSoon()
		}
    }

    DBusInterface {
        id: settingsUi
        bus: DBus.SessionBus
        service: "com.jolla.settings"
        path: "/com/jolla/settings/ui"
        iface: "com.jolla.settings.ui"
    }

	DBusInterface {
		id: applicationCompositor
		bus: DBus.SessionBus
		service: "org.nemomobile.lipstick"
		path: "/"
		iface: "org.nemomobile.compositor"
		watchServiceStatus: true
	}

	DBusInterface {
		id: androidApplicationTracker
		bus: DBus.SessionBus
		service: "com.jolla.apkd"
		path: "/com/jolla/apkd"
		iface: "com.jolla.apkd"
		signalsEnabled: true
		watchServiceStatus: true

		function appOpened(componentName) {
			futoHandler.activeAndroidComponent = String(componentName || "")
		}
		function appShown(componentName) {
			futoHandler.activeAndroidComponent = String(componentName || "")
		}
		function appHidden(componentName) {
			// AppSupport temporarily hides a surface during focus, keyboard, and
			// authentication transitions. Retain its stable identity so credential
			// matching cannot fall back to an unrelated recently visited website.
		}
		function appClosed(componentName) {
			if (futoHandler.normalizedApplicationId(componentName)
					=== futoHandler.normalizedApplicationId(
					        futoHandler.activeAndroidComponent))
				futoHandler.activeAndroidComponent = ""
		}
	}

	onActiveAndroidComponentChanged: {
		refreshAndroidApplicationDisplayName()
		// The input field can gain focus before AppSupport announces the owning
		// package. Retry the exact-origin lookup as soon as that identity arrives;
		// otherwise the offer would remain absent until the app was reopened.
		if (credentialFieldCandidate && credentialAutofillStage === 0
				&& !passwordVaultPanelOpen && !passwordVaultBusy)
			refreshCredentialMatch()
	}

    DBusInterface {
        id: privacySwitch
        bus: DBus.SessionBus
        service: "org.sailfishos.privacyswitch"
        path: "/privacyswitch"
        iface: "org.sailfishos.privacyswitch"
        signalsEnabled: true
        watchServiceStatus: true

        function privacyModeActiveChanged(active) {
            futoHandler.privacySwitchActive = !!active
        }

        onStatusChanged: {
            if (status === DBusInterface.Available)
                futoHandler.refreshPrivacySwitchState()
        }
    }

    // Maliit itself uses these MCE calls to decide whether the on-screen or
    // hardware input source is active. Reusing them keeps FUTO in lock-step
    // with Sailfish's official Text input hardware-keyboard handling.
    DBusInterface {
        id: mceKeyboardRequest
        bus: DBus.SystemBus
        service: "com.nokia.mce"
        path: "/com/nokia/mce/request"
        iface: "com.nokia.mce.request"
        watchServiceStatus: true
        onStatusChanged: {
            if (status === DBusInterface.Available)
                futoHandler.refreshHardwareKeyboardState()
        }
    }

    DBusInterface {
        id: mceKeyboardSignal
        bus: DBus.SystemBus
        service: "com.nokia.mce"
        path: "/com/nokia/mce/signal"
        iface: "com.nokia.mce.signal"
        signalsEnabled: true

        function keyboard_available_state_ind(state) {
            futoHandler.setHardwareKeyboardState(state)
        }
    }

    ConfigurationGroup {
        id: keyboardSettings
        path: "/sailfish/text_input/futo_keyboard"

        property bool languageEnglish: true
        property bool languageDutch: true
        property bool languageTurkish: true
        property string enabledLanguages: "EN,NL,TR"
        property int settingsVersion: 0
        property bool automaticLanguageDetection: true
        property bool nextWordPredictionEnabled: true
        property bool predictionEnabled: true
        property bool autoCorrectionEnabled: false
        property int correctionLevel: 0
        property bool personalLearningEnabled: true
        property bool urlHistoryEnabled: false
        property bool passwordSavingEnabled: true
		property bool debugInputContext: false
        property bool autoSpaceAfterSuggestion: true
        property bool showTypedWord: true
        property int suggestionCount: 12
        property bool smartPunctuationEnabled: true
        property bool doubleSpacePeriodEnabled: true
        property bool autoCapitalizationEnabled: true
        property bool undoCorrectionEnabled: true
        property bool incognitoMode: false
        property bool incognitoOnPrivacySwitch: false
        property real keyboardHeightScale: 1.0
        property int portraitKeyboardMode: 0
        property int landscapeKeyboardMode: 0
        property bool keepVirtualWithHardwareKeyboard: false
        property bool clipboardHistoryEnabled: false
        property int clipboardRetentionSeconds: 3600
        property bool clipboardReturnAfterPaste: true
        property bool keySoundEnabled: false
        property real keySoundVolume: 0.5
        property bool swipeTypingEnabled: true
        // Set only by the Top Menu compatibility action. Android applications
        // which suppress their IME remain in a hidden composition state, so
        // this session must use hardware-style key events instead.
        property bool forcedAppSupportKeyEvents: false
        property bool voiceTypingEnabled: false
        property bool voiceKeyVisible: true
		property bool voicePushToTalkEnabled: false
        property bool voiceLiveTranscriptionEnabled: true
        property bool voiceStopAfterSilence: true
        property int voiceSilenceTimeoutMs: 1300
		property bool desktopToolbarEnabled: false
		property string desktopToolbarOrder:
		    "esc,f1,f2,f3,f4,f5,f6,f7,f8,f9,f10,f11,f12,print,pause,insert,delete,home,end,pageup,pagedown,ctrl,alt,super,tab,menu,numlock,scrolllock,left,up,down,right,backspace,space,enter"
		property string desktopToolbarEnabledKeys:
		    "esc,ctrl,alt,left,down,right,delete"
        property string quickSettingsOrder:
            "language,layouts,keyboardmode,desktopkeys,clipboard,emoji,microphone,sound,incognito,settings"
        property string quickSettingsEnabled:
            "language,layouts,keyboardmode,desktopkeys,clipboard,emoji,microphone,sound,incognito,settings"

		onVoicePushToTalkEnabledChanged: {
			if (voicePushToTalkEnabled)
				voiceStopAfterSilence = false
		}

        onAutoCorrectionEnabledChanged: {
            if (!autoCorrectionEnabled) {
                futoHandler.correctionQuery = ""
                futoHandler.correctionCandidate = ""
            } else {
                futoHandler.requestSuggestionsSoon()
            }
        }
        onEnabledLanguagesChanged: futoHandler.requestSuggestionsSoon()
        onAutomaticLanguageDetectionChanged: futoHandler.requestSuggestionsSoon()
        onNextWordPredictionEnabledChanged: futoHandler.requestSuggestionsSoon()
        onPredictionEnabledChanged: futoHandler.requestSuggestionsSoon()
        onForcedAppSupportKeyEventsChanged: {
            if (forcedAppSupportKeyEvents)
                futoHandler.resetSuggestionDisplay()
        }
        onCorrectionLevelChanged: futoHandler.requestSuggestionsSoon()
        onShowTypedWordChanged: futoHandler.requestSuggestionsSoon()
        onSuggestionCountChanged: futoHandler.requestSuggestionsSoon()
        onUrlHistoryEnabledChanged: {
            if (urlHistoryEnabled)
                urlSuggestionTimer.restart()
            else {
                futoHandler.urlRequestSerial++
                futoHandler.learnedUrlSuggestions = []
                futoHandler.refreshApplicationSuggestions()
            }
        }
        onPasswordSavingEnabledChanged: {
            if (!passwordSavingEnabled)
                futoHandler.clearCredentialCapture(true)
        }
        onClipboardHistoryEnabledChanged: {
            if (clipboardHistoryEnabled)
                futoHandler.captureClipboardText(Clipboard.text)
            else
                clipboardModel.clear()
        }
        onKeepVirtualWithHardwareKeyboardChanged: {
            futoHandler.refreshHardwareKeyboardState()
        }
    }

    ListModel {
        id: predictionModel
    }

    ListModel {
        id: clipboardModel
    }

    property alias clipboardHistoryModel: clipboardModel

    ListModel { id: applicationSuggestionModel }

    Timer {
        id: predictionTimer
        interval: 25
        repeat: false
        onTriggered: futoHandler.requestSuggestions()
    }

    Timer {
        id: nextPredictionTimer
        interval: 70
        repeat: false
        onTriggered: futoHandler.requestNextWords()
    }

    Timer {
        id: editorContextTimer
        interval: 40
        repeat: false
        onTriggered: futoHandler.refreshEditingWord()
    }

    Timer {
        id: urlSuggestionTimer
        interval: 90
        repeat: false
        onTriggered: futoHandler.requestUrlSuggestions()
    }

    // Android AppSupport can keep an editor visibly focused without emitting
    // another Maliit active/focus transition after the keyboard plugin loads.
    // Recover the empty-address-bar history in that state; non-empty URL input
    // continues to use the immediate 90 ms request timer above.
    Timer {
        id: emptyUrlRecoveryTimer
        interval: 400
        repeat: true
        running: keyboardSettings.urlHistoryEnabled
                 && !futoHandler.passwordField && !futoHandler.incognitoMode
        onTriggered: {
            if (futoHandler.urlField && futoHandler.currentUrlCandidate() === ""
                    && (!futoHandler.urlSuggestionResultsActive
                        || predictionModel.count === 0))
                futoHandler.requestUrlSuggestions()
        }
    }

    Timer {
        id: swipeReleaseTimer
        interval: 180
        repeat: false
        onTriggered: futoHandler.resetSwipePath()
    }

    Timer {
        id: voiceLimitTimer
        interval: keyboardSettings.voiceStopAfterSilence
                  && !futoHandler.voicePushToTalk ? 30000 : 300000
        repeat: false
        onTriggered: futoHandler.stopVoiceInput()
    }

	Timer {
		id: voiceLiveTimer
		interval: 850
		repeat: false
		onTriggered: futoHandler.pollVoiceInput()
	}

    Timer {
        id: voiceMessageTimer
        interval: 3500
        repeat: false
        onTriggered: futoHandler.voiceMessage = ""
    }

    Timer {
        id: credentialCaptureIdleTimer
        // Keep the latest password candidate complete, but never display or
        // defer a keyboard-strip prompt. Submission/focus loss publishes the
        // independent Sailfish confirmation immediately.
        interval: 1400
        repeat: false
        onTriggered: futoHandler.finalizeCredentialCapture()
    }

    Component.onCompleted: {
        if (keyboardSettings.settingsVersion < 4) {
            var migrated = []
            if (keyboardSettings.languageEnglish)
                migrated.push("EN")
            if (keyboardSettings.languageDutch)
                migrated.push("NL")
            if (keyboardSettings.languageTurkish)
                migrated.push("TR")
            keyboardSettings.enabledLanguages = migrated.length > 0
                    ? migrated.join(",") : "EN"
        }
        if (keyboardSettings.settingsVersion < 8) {
            // Before v8 the single setting represented only the dedicated
            // microphone key. Preserve that choice for the separated key
            // visibility setting.
            keyboardSettings.voiceKeyVisible = keyboardSettings.voiceTypingEnabled
            keyboardSettings.settingsVersion = 8
        }
        if (keyboardSettings.settingsVersion < 9) {
            var order = quickSettingIds(keyboardSettings.quickSettingsOrder)
            var enabled = quickSettingIds(keyboardSettings.quickSettingsEnabled)
            if (order.indexOf("keyboardmode") < 0) {
                var layoutPosition = order.indexOf("layouts")
                order.splice(layoutPosition >= 0 ? layoutPosition + 1 : 0,
                             0, "keyboardmode")
            }
            if (enabled.indexOf("keyboardmode") < 0)
                enabled.push("keyboardmode")
            keyboardSettings.quickSettingsOrder = order.join(",")
            keyboardSettings.quickSettingsEnabled = enabled.join(",")
            keyboardSettings.settingsVersion = 9
        }
        if (keyboardSettings.settingsVersion < 10) {
            var soundOrder = quickSettingIds(keyboardSettings.quickSettingsOrder)
            var soundEnabled = quickSettingIds(keyboardSettings.quickSettingsEnabled)
            if (soundOrder.indexOf("sound") < 0) {
                var microphonePosition = soundOrder.indexOf("microphone")
                soundOrder.splice(microphonePosition >= 0
                                  ? microphonePosition + 1 : soundOrder.length,
                                  0, "sound")
            }
            if (soundEnabled.indexOf("sound") < 0)
                soundEnabled.push("sound")
            keyboardSettings.quickSettingsOrder = soundOrder.join(",")
            keyboardSettings.quickSettingsEnabled = soundEnabled.join(",")
            keyboardSettings.settingsVersion = 10
        }
        if (keyboardSettings.settingsVersion < 11) {
            var desktopOrder = quickSettingIds(keyboardSettings.quickSettingsOrder)
            var desktopEnabled = quickSettingIds(keyboardSettings.quickSettingsEnabled)
            if (desktopOrder.indexOf("desktopkeys") < 0) {
                var keyboardModePosition = desktopOrder.indexOf("keyboardmode")
                desktopOrder.splice(keyboardModePosition >= 0
                                    ? keyboardModePosition + 1 : desktopOrder.length,
                                    0, "desktopkeys")
            }
            if (desktopEnabled.indexOf("desktopkeys") < 0)
                desktopEnabled.push("desktopkeys")
            keyboardSettings.quickSettingsOrder = desktopOrder.join(",")
            keyboardSettings.quickSettingsEnabled = desktopEnabled.join(",")
            keyboardSettings.settingsVersion = 11
        }
        refreshPrivacySwitchState()
        refreshHardwareKeyboardState()
    }

    function formatText(text) {
        if (text === undefined)
            return ""
        // Theme.highlightText() is intended for ordinary word completion.  In
        // an empty URL editor its empty match can produce an empty StyledText
        // label even though the URL model contains valid results.  URL history
        // is already ranked and filtered by the helper, so render it plainly.
        if (showUrlSuggestions)
            return String(text).replace(/&/g, "&amp;")
                    .replace(/</g, "&lt;").replace(/>/g, "&gt;")
        if (showApplicationSuggestions)
            return Theme.highlightText(text, combinedText, palette.highlightColor)

        var query = futoHandler.activeSuggestionQuery
        var queryLength = query.length
        if (text.substr(0, queryLength).toLocaleLowerCase()
                === query.toLocaleLowerCase()) {
            return "<font color=\"" + palette.highlightColor + "\">"
                    + text.substr(0, queryLength) + "</font>" + text.substr(queryLength)
        }
        return text
    }

    function keySoundVolumeStep() {
        var configuredVolume = Number(keyboardSettings.keySoundVolume)
        if (!isFinite(configuredVolume))
            configuredVolume = 0.5
        return Math.max(1, Math.min(10,
                        Math.round(configuredVolume * 10))) * 10
    }

    function playKeySound(soundKind) {
        if (!keyboardSettings.keySoundEnabled || !soundKind)
            return
        helper.typedCall("PlayKeySound", [
            { "type": "s", "value": soundKind },
            { "type": "i", "value": keySoundVolumeStep() }
        ], function() {}, function() {})
    }

    function playManualKeyFeedback(key, soundKind) {
        if (systemFeedback.touchscreenVibrationLevel !== 0)
            customButtonVibration.play()
        playKeySound(soundKind)
    }

    function playOptionFeedback() {
        playManualKeyFeedback(null, "option")
    }

    function refreshPrivacySwitchState() {
        if (privacySwitch.status !== DBusInterface.Available) {
            privacySwitchActive = false
            return
        }
        privacySwitch.typedCall("privacyModeActive", [], function(active) {
            futoHandler.privacySwitchActive = !!active
        }, function() {
            futoHandler.privacySwitchActive = false
        })
    }

    function forgetSuggestion(word, modelIndex) {
        helper.typedCall("ForgetWord", [
            { "type": "s", "value": String(word) }
        ], function(removed) {
            if (removed && modelIndex >= 0 && modelIndex < predictionModel.count
                    && String(predictionModel.get(modelIndex).text) === String(word)) {
                predictionModel.remove(modelIndex)
                suggestionsUpdated()
            } else if (removed) {
                requestSuggestionsSoon()
            }
        }, function() {})
    }

    function forgetUrlSuggestion(displayText, modelIndex) {
        var source = String(displayText)
        if (modelIndex >= 0 && modelIndex < predictionModel.count) {
            var item = predictionModel.get(modelIndex)
            if (String(item.text) === String(displayText) && item.source)
                source = String(item.source)
        }
        ++urlRequestSerial
        helper.typedCall("RemoveURL", [
            { "type": "s", "value": source }
        ], function(removed) {
            if (!removed)
                return
            for (var i = predictionModel.count - 1; i >= 0; --i) {
                var suggestion = predictionModel.get(i)
                if (String(suggestion.source || suggestion.text) === source)
                    predictionModel.remove(i)
            }
            var remaining = []
            for (var j = 0; j < learnedUrlSuggestions.length; ++j) {
                if (String(learnedUrlSuggestions[j]) !== source)
                    remaining.push(learnedUrlSuggestions[j])
            }
            learnedUrlSuggestions = remaining
            urlSuggestionResultsActive = predictionModel.count > 0
            suggestionsUpdated()
        }, function() {})
    }

    function captureClipboardText(text) {
        if (!keyboardSettings.clipboardHistoryEnabled || futoHandler.incognitoMode)
            return
        text = String(text)
        if (text.trim() === "")
            return
        helper.typedCall("RecordClipboard", [
            { "type": "s", "value": text },
            { "type": "i", "value": Math.round(
                    Number(keyboardSettings.clipboardRetentionSeconds)) }
        ], function(recorded) {
            if (recorded && keyboard.layout && keyboard.layout.clipboardMode)
                futoHandler.refreshClipboardHistory()
        }, function() {})
    }

    function refreshClipboardHistory() {
        if (!keyboardSettings.clipboardHistoryEnabled) {
            clipboardModel.clear()
            return
        }
        helper.typedCall("ListClipboard", [], function(resultJson) {
            var entries = []
            try {
                entries = JSON.parse(String(resultJson))
            } catch (error) {
                entries = []
            }
            clipboardModel.clear()
            for (var i = 0; i < entries.length; ++i) {
                clipboardModel.append({
                    "entryId": String(entries[i].id || ""),
                    "text": String(entries[i].text || ""),
                    "pinned": !!entries[i].pinned,
                    "createdAt": Number(entries[i].createdAt || 0)
                })
            }
        }, function() {
            clipboardModel.clear()
        })
    }

    function pasteClipboardEntry(text) {
        if (preedit !== "")
            commit(preedit)
        MInputMethodQuick.sendCommit(String(text))
        if (keyboardSettings.clipboardReturnAfterPaste
                && keyboard.layout && keyboard.layout.hideClipboardHistory)
            keyboard.layout.hideClipboardHistory()
    }

    function setClipboardPinned(entryId, pinned) {
        helper.typedCall("SetClipboardPinned", [
            { "type": "s", "value": String(entryId) },
            { "type": "b", "value": !!pinned },
            { "type": "i", "value": Math.round(
                    Number(keyboardSettings.clipboardRetentionSeconds)) }
        ], function(changed) {
            if (!changed)
                return
            for (var i = 0; i < clipboardModel.count; ++i) {
                if (String(clipboardModel.get(i).entryId) === String(entryId)) {
                    clipboardModel.setProperty(i, "pinned", !!pinned)
                    break
                }
            }
        }, function() {})
    }

    function deleteClipboardEntry(entryId) {
        helper.typedCall("DeleteClipboard", [
            { "type": "s", "value": String(entryId) }
        ], function(changed) {
            if (!changed)
                return
            for (var i = 0; i < clipboardModel.count; ++i) {
                if (String(clipboardModel.get(i).entryId) === String(entryId)) {
                    clipboardModel.remove(i)
                    break
                }
            }
        }, function() {})
    }

    Connections {
        target: Clipboard
        onTextChanged: futoHandler.captureClipboardText(Clipboard.text)
    }

    function openFutoSettings() {
        if (keyboard.layout && keyboard.layout.hideControlStrip)
            keyboard.layout.hideControlStrip()
        // Dispatch the page request before the keyboard loses focus. Calling
        // userHide() here can unload this handler before its queued D-Bus call
        // reaches Settings, leaving the gear action apparently unresponsive.
        // Opening Settings moves focus away and hides the keyboard naturally.
        settingsUi.call("showPage", [
            "system_settings/system/text_input/futo_keyboard"
        ])
    }

    function toggleIncognitoMode() {
        keyboardSettings.incognitoMode = !keyboardSettings.incognitoMode
        if (keyboard.layout && keyboard.layout.hideControlStrip)
            keyboard.layout.hideControlStrip()
    }

    function quickSettingIds(value) {
        var raw = String(value).split(",")
        var result = []
        for (var i = 0; i < raw.length; ++i) {
            var id = raw[i].trim()
            if (id !== "" && result.indexOf(id) < 0)
                result.push(id)
        }
        return result
    }

	function desktopModifierFlag(keyId) {
		if (keyId === "ctrl") return Qt.ControlModifier
		if (keyId === "alt") return Qt.AltModifier
		if (keyId === "altgr") return 0x40000000
		if (keyId === "super") return Qt.MetaModifier
		return 0
	}

	function desktopModifierState(keyId) {
		var flag = desktopModifierFlag(String(keyId))
		if (flag === 0)
			return 0
		if ((desktopLockedModifiers & flag) !== 0)
			return 2
		return (desktopLatchedModifiers & flag) !== 0 ? 1 : 0
	}

	function desktopModifierName(keyId) {
		if (keyId === "ctrl") return qsTr("Ctrl")
		if (keyId === "alt") return qsTr("Alt")
		if (keyId === "altgr") return qsTr("AltGr")
		if (keyId === "super") return qsTr("Sailfish")
		return String(keyId)
	}

	function desktopModifierSummary() {
		var ready = []
		var locked = []
		var ids = ["ctrl", "alt", "altgr", "super"]
		for (var i = 0; i < ids.length; ++i) {
			var state = desktopModifierState(ids[i])
			if (state === 2)
				locked.push(desktopModifierName(ids[i]))
			else if (state === 1)
				ready.push(desktopModifierName(ids[i]))
		}
		var parts = []
		if (ready.length > 0)
			parts.push(qsTr("%1 ready").arg(ready.join(" + ")))
		if (locked.length > 0)
			parts.push(qsTr("%1 locked").arg(locked.join(" + ")))
		return parts.join(" · ")
	}

	function clearDesktopModifiers() {
		desktopLatchedModifiers = 0
		desktopLockedModifiers = 0
		desktopLastModifierId = ""
		desktopLastModifierTapMs = 0
	}

	function toggleDesktopModifier(keyId) {
		keyId = String(keyId)
		var flag = desktopModifierFlag(keyId)
		if (flag === 0)
			return
		var now = Date.now()
		if ((desktopLockedModifiers & flag) !== 0) {
			desktopLockedModifiers &= ~flag
			desktopLatchedModifiers &= ~flag
		} else if ((desktopLatchedModifiers & flag) !== 0) {
			if (desktopLastModifierId === keyId
					&& now - desktopLastModifierTapMs <= 430) {
				desktopLatchedModifiers &= ~flag
				desktopLockedModifiers |= flag
			} else {
				desktopLatchedModifiers &= ~flag
			}
		} else {
			desktopLatchedModifiers |= flag
		}
		desktopLastModifierId = keyId
		desktopLastModifierTapMs = now
	}

	function desktopKeyCode(keyId) {
		if (keyId === "esc") return Qt.Key_Escape
		if (keyId === "f1") return Qt.Key_F1
		if (keyId === "f2") return Qt.Key_F2
		if (keyId === "f3") return Qt.Key_F3
		if (keyId === "f4") return Qt.Key_F4
		if (keyId === "f5") return Qt.Key_F5
		if (keyId === "f6") return Qt.Key_F6
		if (keyId === "f7") return Qt.Key_F7
		if (keyId === "f8") return Qt.Key_F8
		if (keyId === "f9") return Qt.Key_F9
		if (keyId === "f10") return Qt.Key_F10
		if (keyId === "f11") return Qt.Key_F11
		if (keyId === "f12") return Qt.Key_F12
		if (keyId === "print") return Qt.Key_Print
		if (keyId === "pause") return Qt.Key_Pause
		if (keyId === "insert") return Qt.Key_Insert
		if (keyId === "delete") return Qt.Key_Delete
		if (keyId === "home") return Qt.Key_Home
		if (keyId === "end") return Qt.Key_End
		if (keyId === "pageup") return Qt.Key_PageUp
		if (keyId === "pagedown") return Qt.Key_PageDown
		if (keyId === "tab") return Qt.Key_Tab
		if (keyId === "menu") return Qt.Key_Menu
		if (keyId === "numlock") return Qt.Key_NumLock
		if (keyId === "scrolllock") return Qt.Key_ScrollLock
		if (keyId === "left") return Qt.Key_Left
		if (keyId === "up") return Qt.Key_Up
		if (keyId === "down") return Qt.Key_Down
		if (keyId === "right") return Qt.Key_Right
		if (keyId === "backspace") return Qt.Key_Backspace
		if (keyId === "space") return Qt.Key_Space
		if (keyId === "enter") return Qt.Key_Return
		return Qt.Key_unknown
	}

	function desktopKeyText(keyId) {
		if (keyId === "tab") return "\t"
		if (keyId === "space") return " "
		if (keyId === "enter") return "\n"
		if (keyId === "backspace") return "\b"
		return ""
	}

	function prepareDesktopKeyDispatch() {
		if (preedit !== "") {
			learn(preedit)
			commit(preedit)
		}
		clearEditingWord()
		candidateSpaceIndex = -1
		clearUndoCorrection()
	}

	function sendDesktopKeyCode(keyCode, text) {
		if (keyCode === Qt.Key_unknown)
			return false
		prepareDesktopKeyDispatch()
		MInputMethodQuick.sendKey(keyCode, activeDesktopModifiers,
		                          text || "", Maliit.KeyClick)
		desktopLatchedModifiers = 0
		desktopLastModifierId = ""
		desktopLastModifierTapMs = 0
		return true
	}

	function activateDesktopKey(keyId) {
		keyId = String(keyId)
		if (desktopModifierFlag(keyId) !== 0) {
			toggleDesktopModifier(keyId)
			return true
		}
		return sendDesktopKeyCode(desktopKeyCode(keyId), desktopKeyText(keyId))
	}

	function handleArmedDesktopModifierKey(key) {
		if (activeDesktopModifiers === 0 || !key
				|| key.keyType === KeyType.SymbolKey
				|| key.keyType === KeyType.ShiftKey)
			return false
		var keyCode = Number(key.key)
		var text = String(key.text || "")
		if ((!isFinite(keyCode) || keyCode === 0 || keyCode === Qt.Key_unknown)
				&& text.length === 1)
			keyCode = text.toUpperCase().charCodeAt(0)
		return sendDesktopKeyCode(keyCode, text)
	}

	function nextEnabledSailfishKeyboardIndex() {
		// The enabled Sailfish keyboards belong to the canvas LayoutModel.  The
		// `keyboard` object is the current keyboard surface and does not expose
		// that model, so consulting keyboard.model made this return -1 whenever
		// FUTO itself only had one assigned letter layout.
		var model = (typeof canvas !== "undefined") ? canvas.layoutModel : null
		if (!model || typeof model.get !== "function")
			return -1
		var count = Math.max(0, Number(model.count || 0))
		var enabledCount = 0
		for (var enabledIndex = 0; enabledIndex < count; ++enabledIndex) {
			var enabledCandidate = model.get(enabledIndex)
			if (enabledCandidate && enabledCandidate.enabled
					&& String(enabledCandidate.type || "") !== "emojis")
				enabledCount++
		}
		if (enabledCount < 2)
			return -1
		var current = Math.max(0, Number(canvas.activeIndex || 0))
		for (var offset = 1; offset < count; ++offset) {
			var index = (current + offset) % count
			var candidate = model.get(index)
			if (candidate && candidate.enabled
					&& String(candidate.type || "") !== "emojis")
				return index
		}
		return -1
	}

	function switchToNextSailfishKeyboard() {
		var index = nextEnabledSailfishKeyboardIndex()
		if (index < 0 || typeof canvas === "undefined"
				|| typeof canvas.switchLayout !== "function")
			return false
		playOptionFeedback()
		canvas.switchLayout(index)
		if (keyboard.overriddenLayoutFile !== undefined)
			keyboard.overriddenLayoutFile = ""
		return true
	}

    function quickSettingAvailable(actionId) {
        if (actionId === "language") {
            var localLanguageChoices = keyboard.layout
                    && keyboard.layout.languageSwitchCount !== undefined
                    ? Number(keyboard.layout.languageSwitchCount)
                    : (keyboard.layout ? Number(keyboard.layout.enabledLetterLayoutCount) : 0)
            return keyboard.layout
                    && (localLanguageChoices > 1
                        || nextEnabledSailfishKeyboardIndex() >= 0)
        }
        if (actionId === "clipboard")
            return keyboardSettings.clipboardHistoryEnabled
        if (actionId === "microphone")
            return keyboardSettings.voiceTypingEnabled && !passwordField
        return actionId === "layouts" || actionId === "keyboardmode"
                || actionId === "desktopkeys"
                || actionId === "emoji"
                || actionId === "sound" || actionId === "incognito"
                || actionId === "settings"
    }

    function quickSettingsActions() {
        var order = quickSettingIds(keyboardSettings.quickSettingsOrder)
        var enabled = quickSettingIds(keyboardSettings.quickSettingsEnabled)
        var result = []
        for (var i = 0; i < order.length; ++i) {
            if (enabled.indexOf(order[i]) >= 0 && quickSettingAvailable(order[i]))
                result.push(order[i])
        }
        return result
    }

    function quickSettingIcon(actionId) {
        if (actionId === "language") return "image://theme/icon-m-region"
        if (actionId === "layouts") return "image://theme/icon-m-edit"
        if (actionId === "keyboardmode") return "image://theme/icon-m-text-input"
		if (actionId === "desktopkeys") return "image://theme/icon-m-keyboard"
        if (actionId === "clipboard") return "image://theme/icon-m-clipboard"
        if (actionId === "emoji")
            return "file:///usr/share/futo-keyboard-sailfish/icons/icon-m-emoji.svg"
        if (actionId === "microphone") return "image://theme/icon-m-browser-microphone"
        if (actionId === "sound")
            return keyboardSettings.keySoundEnabled
                    ? "image://theme/icon-m-speaker-on"
                    : "image://theme/icon-m-speaker-mute"
        if (actionId === "incognito") return "image://theme/icon-m-incognito"
        return ""
    }

    function quickSettingLabel(actionId) {
        if (actionId === "language" && keyboard.layout)
            return keyboard.layout.currentLetterLayoutMenuName
        if (actionId === "layouts") return qsTr("Layouts")
        if (actionId === "keyboardmode" && keyboard.layout) {
            if (keyboard.layout.activeKeyboardMode === 1)
                return qsTr("Thumb")
            if (keyboard.layout.activeKeyboardMode === 2)
                return qsTr("Left")
            if (keyboard.layout.activeKeyboardMode === 3)
                return qsTr("Right")
            return qsTr("Full size")
        }
		if (actionId === "desktopkeys") return qsTr("Extra key row")
        if (actionId === "clipboard") return qsTr("Clipboard")
        if (actionId === "emoji") return qsTr("Emoji")
        if (actionId === "microphone") return qsTr("Microphone")
        if (actionId === "sound") return qsTr("Sound")
        if (actionId === "incognito") return qsTr("Incognito")
        return qsTr("Settings")
    }

    function activateQuickSetting(actionId) {
        if (actionId === "sound") {
            keyboardSettings.keySoundEnabled = !keyboardSettings.keySoundEnabled
            // Toggle first so enabling sound produces an immediate preview;
            // disabling it still keeps the normal haptic confirmation.
            playOptionFeedback()
            return
        }
        playOptionFeedback()
        if (!keyboard.layout)
            return
        if (actionId === "language") {
            keyboard.layout.cycleLetterLayout()
        } else if (actionId === "layouts") {
            keyboard.layout.showLayoutEditor()
        } else if (actionId === "keyboardmode") {
            keyboard.layout.setCurrentKeyboardMode(
                        (keyboard.layout.activeKeyboardMode + 1) % 4)
		} else if (actionId === "desktopkeys") {
			keyboardSettings.desktopToolbarEnabled =
			        !keyboardSettings.desktopToolbarEnabled
        } else if (actionId === "clipboard") {
            keyboard.layout.showClipboardHistory()
        } else if (actionId === "emoji") {
            keyboard.layout.showEmojiPicker()
        } else if (actionId === "microphone") {
            // Voice status belongs in the normal top strip.  Close the held-123
            // controls before starting so Listening… is visible immediately.
            if (keyboard.layout.hideControlStrip)
                keyboard.layout.hideControlStrip()
            toggleVoiceInput()
        } else if (actionId === "incognito") {
            toggleIncognitoMode()
        } else if (actionId === "settings") {
            openFutoSettings()
        }
    }

    function toggleVoiceInput() {
        if (voiceRecording)
            stopVoiceInput()
        else if (!voiceBusy)
            startVoiceInput(false)
    }

	function showVoiceMessage(message) {
		voiceMessage = String(message)
		if (voiceMessage !== "")
			voiceMessageTimer.restart()
	}

	function clearVoicePartial() {
		if (voicePartial !== "")
			MInputMethodQuick.sendPreedit("")
		voicePartial = ""
	}

	function updateVoicePartial(text) {
		text = String(text).trim()
		if (text === "" || text === voicePartial)
			return
		voicePartial = text
		MInputMethodQuick.sendPreedit(text)
	}

	function applyVoiceTranscription(transcription, showNoSpeech) {
		voiceLiveTimer.stop()
		voicePollBusy = false
		voiceStopPending = false
		voicePushToTalk = false
		var text = String(transcription).trim()
		if (text === "") {
			clearVoicePartial()
			if (showNoSpeech)
				showVoiceMessage(qsTr("No speech was detected"))
			return
		}
		MInputMethodQuick.sendCommit(text + " ")
		voicePartial = ""
		if (keyboard.shiftState !== ShiftState.LockedShift)
			keyboard.shiftState = ShiftState.AutoShift
		editorContextTimer.restart()
	}

	function startVoiceInput(pushToTalk) {
		if (!keyboardSettings.voiceTypingEnabled || passwordField || voiceBusy
				|| voiceRecording)
			return
		voicePushToTalk = !!pushToTalk
		voiceMessageTimer.stop()
		voiceMessage = ""
		clearVoicePartial()
		voiceStopPending = false
		voiceLiveFailed = false
		voiceBusy = true
		var session = ++voiceSessionSerial
		helper.typedCall("StartVoiceInput", [
			{ "type": "s", "value": enabledLanguages() }
		], function(started) {
			if (session !== futoHandler.voiceSessionSerial) {
				helper.typedCall("CancelVoiceInput", [], function() {}, function() {})
				return
			}
			futoHandler.voiceBusy = false
			futoHandler.voiceRecording = !!started
			if (futoHandler.voiceRecording) {
				if (futoHandler.preedit !== "") {
					var typed = futoHandler.preedit
					futoHandler.learn(typed)
					futoHandler.commit(typed + " ")
				}
				voiceLimitTimer.restart()
				if (keyboardSettings.voiceLiveTranscriptionEnabled)
					voiceLiveTimer.restart()
				if (futoHandler.voicePushToTalk && futoHandler.voiceStopPending) {
					futoHandler.voiceStopPending = false
					futoHandler.stopVoiceInput()
				}
			} else {
				futoHandler.voicePushToTalk = false
				futoHandler.showVoiceMessage(qsTr("Voice input is unavailable"))
			}
		}, function() {
			if (session !== futoHandler.voiceSessionSerial)
				return
			futoHandler.voiceBusy = false
			futoHandler.showVoiceMessage(qsTr("Could not start the microphone"))
		})
	}

	function releaseVoicePushToTalk() {
		if (!voicePushToTalk)
			return
		if (voiceBusy && !voiceRecording) {
			voiceStopPending = true
			return
		}
		if (voiceRecording)
			stopVoiceInput()
	}

	function pollVoiceInput() {
		if (!voiceRecording || voiceBusy || voicePollBusy || voiceLiveFailed
				|| !keyboardSettings.voiceLiveTranscriptionEnabled)
			return
		voicePollBusy = true
		var session = voiceSessionSerial
		helper.typedCall("VoiceInputUpdate", [
			{ "type": "s", "value": enabledLanguages() },
			{ "type": "i", "value": futoHandler.voicePushToTalk
					|| !keyboardSettings.voiceStopAfterSilence ? 0 : Math.round(
						keyboardSettings.voiceSilenceTimeoutMs) }
		], function(updateJson) {
			if (session !== futoHandler.voiceSessionSerial)
				return
			futoHandler.voicePollBusy = false
			var update
			try {
				update = JSON.parse(String(updateJson))
			} catch (error) {
				update = { "recording": true, "final": false, "text": "" }
			}
			if (update.final) {
				futoHandler.voiceRecording = false
				voiceLimitTimer.stop()
				futoHandler.applyVoiceTranscription(update.text, true)
				return
			}
			if (!update.recording) {
				futoHandler.voiceRecording = false
				voiceLimitTimer.stop()
				futoHandler.applyVoiceTranscription(update.text, false)
				return
			}
			futoHandler.updateVoicePartial(update.text)
			if (futoHandler.voiceStopPending) {
				futoHandler.voiceStopPending = false
				futoHandler.stopVoiceInput()
			} else if (futoHandler.voiceRecording) {
				voiceLiveTimer.restart()
			}
		}, function() {
			if (session !== futoHandler.voiceSessionSerial)
				return
			futoHandler.voicePollBusy = false
			futoHandler.voiceLiveFailed = true
			futoHandler.showVoiceMessage(
				qsTr("Live transcription paused; tap the microphone to finish"))
			if (futoHandler.voiceStopPending) {
				futoHandler.voiceStopPending = false
				futoHandler.stopVoiceInput()
			}
		})
	}

	function stopVoiceInput() {
		if (!voiceRecording || voiceBusy)
			return
		if (voicePollBusy) {
			voiceStopPending = true
			return
		}
		voiceLiveTimer.stop()
		voiceLimitTimer.stop()
		voiceRecording = false
		voiceBusy = true
		var session = voiceSessionSerial
		helper.typedCall("StopVoiceInput", [
			{ "type": "s", "value": enabledLanguages() }
		], function(transcription) {
			if (session !== futoHandler.voiceSessionSerial)
				return
			futoHandler.voiceBusy = false
			futoHandler.applyVoiceTranscription(transcription, true)
		}, function() {
			if (session !== futoHandler.voiceSessionSerial)
				return
			futoHandler.voiceBusy = false
			futoHandler.showVoiceMessage(qsTr("Voice transcription failed"))
		})
	}

	function cancelVoiceInput() {
		voiceSessionSerial++
		voiceLiveTimer.stop()
		voiceLimitTimer.stop()
		if (voiceRecording || voiceBusy)
			helper.typedCall("CancelVoiceInput", [], function() {}, function() {})
		voiceRecording = false
		voiceBusy = false
		voicePollBusy = false
		voiceStopPending = false
		voiceLiveFailed = false
		voicePushToTalk = false
		clearVoicePartial()
		voiceMessage = ""
	}

    topItem: Component {
        TopItem {
            id: topStrip
			clip: true

            readonly property bool cursorStatusVisible: futoHandler.cursorMoveMode
			readonly property bool modifierStatusVisible:
			        futoHandler.activeDesktopModifiers !== 0
			        && !keyboardLayout.controlMode
            readonly property bool emojiTabsVisible: keyboardLayout.emojiMode
            readonly property bool emojiSearchVisible: keyboardLayout.emojiSearchMode
            readonly property bool symbolTabsVisible: keyboardLayout.extendedSymbolMode
            readonly property bool controlsVisible: keyboardLayout.controlMode
			readonly property bool voiceStatusVisible: futoHandler.voiceRecording
			        || futoHandler.voiceBusy || futoHandler.voiceMessage !== ""
			readonly property bool credentialSaveVisible: false
			// The live system clipboard is separate from FUTO's optional,
			// persistent clipboard history. Password fields suppress predictions,
			// but must keep the ordinary one-shot Paste action available without
			// recording the copied value in FUTO's history.
			readonly property bool passwordClipboardPasteVisible:
			        futoHandler.passwordField && Clipboard.hasText
			        && !cursorStatusVisible && !modifierStatusVisible
			        && !emojiTabsVisible && !emojiSearchVisible && !symbolTabsVisible
			        && !controlsVisible && !voiceStatusVisible
			        && !keyboardLayout.credentialMode
			readonly property bool passwordVaultVisible:
			        keyboardSettings.passwordSavingEnabled
			        && !cursorStatusVisible
			        && !modifierStatusVisible
			        && !futoHandler.credentialLookupPrivateBlocked
			        && futoHandler.credentialFieldCandidate
			        && futoHandler.credentialMatchAvailable
			        && futoHandler.credentialAutofillStage === 0
			        && !futoHandler.credentialOfferDismissedForFocus
			        && !futoHandler.passwordVaultPanelOpen
			        && !emojiTabsVisible && !emojiSearchVisible && !symbolTabsVisible
			        && !controlsVisible
			        && !voiceStatusVisible && !credentialSaveVisible
			onPasswordVaultVisibleChanged: {
				if (keyboardSettings.debugInputContext)
					futoHandler.credentialDebug("ui-visible=" + passwordVaultVisible
					                            + " strip=" + stripRequired)
			}
            readonly property bool predictionContentAvailable: !cursorStatusVisible
			        && !modifierStatusVisible
                    && !futoHandler.passwordField
                    && (futoHandler.showUrlSuggestions
                    ? predictionModel.count > 0
                    : (futoHandler.showApplicationSuggestions
                       ? applicationSuggestionModel.count > 0
                       : (keyboardSettings.predictionEnabled
                       && futoHandler.activePredictionsAvailable
                       && futoHandler.predictionSuggestionsAvailable)))
			readonly property bool credentialChooserVisible: keyboardLayout.credentialMode
			readonly property bool stripRequired: !credentialChooserVisible
			        && (cursorStatusVisible || modifierStatusVisible
			        || emojiTabsVisible || emojiSearchVisible
			        || symbolTabsVisible
			        || controlsVisible || voiceStatusVisible || credentialSaveVisible
			        || futoHandler.ordinaryPredictionStripEnabled
			        || futoHandler.urlHistoryStripEnabled
					|| passwordClipboardPasteVisible
					|| passwordVaultVisible
			        || predictionContentAvailable)
            height: !futoHandler.hardwareKeyboardSuppressed && stripRequired
                    ? Theme.itemSizeSmall : 0

            SilicaListView {
                id: applicationPredictionList
                anchors.fill: parent
                orientation: ListView.Horizontal
                clip: true
                visible: !topStrip.emojiTabsVisible
                         && !topStrip.cursorStatusVisible
					 && !topStrip.modifierStatusVisible
                         && !topStrip.emojiSearchVisible
                         && !topStrip.symbolTabsVisible
                         && !topStrip.controlsVisible
						 && !topStrip.voiceStatusVisible
						 && !topStrip.credentialSaveVisible
						 && !topStrip.passwordVaultVisible
                         && futoHandler.showApplicationSuggestions
                         && applicationSuggestionModel.count > 0
                model: applicationSuggestionModel
                delegate: BackgroundItem {
                    id: applicationSuggestionDelegate
                    readonly property string suggestionText: String(model.text)
                    width: Math.min(applicationPredictionList.width,
                                    applicationSuggestionLabel.implicitWidth
                                    + 2 * Theme.paddingLarge)
                    height: applicationPredictionList.height

                    onClicked: futoHandler.select(suggestionText, index)

                    Label {
                        id: applicationSuggestionLabel
                        anchors.fill: parent
                        anchors.leftMargin: Theme.paddingLarge
                        anchors.rightMargin: Theme.paddingLarge
                        text: applicationSuggestionDelegate.suggestionText
                        textFormat: Text.PlainText
                        font.pixelSize: Theme.fontSizeSmall
                        verticalAlignment: Text.AlignVCenter
                        truncationMode: TruncationMode.Fade
                    }
                }
            }

            FutoHorizontalPredictionListView {
                id: predictionList
                anchors.fill: parent
                visible: !topStrip.emojiTabsVisible
                         && !topStrip.cursorStatusVisible
					 && !topStrip.modifierStatusVisible
                         && !topStrip.emojiSearchVisible
                         && !topStrip.symbolTabsVisible
                         && !topStrip.controlsVisible
						 && !topStrip.voiceStatusVisible
						 && !topStrip.credentialSaveVisible
						 && !topStrip.passwordVaultVisible
                         && (futoHandler.showUrlSuggestions
                             || !futoHandler.showApplicationSuggestions)
                         && topStrip.predictionContentAvailable
                handler: futoHandler
                model: predictionModel
                canRemove: true

                Connections {
                    target: futoHandler
                    onSuggestionsUpdated: predictionList.predictionsChanged()
                }
            }

			PasteButton {
				id: passwordClipboardPasteButton
				anchors.left: parent.left
				height: parent.height
				z: 20
				visible: topStrip.passwordClipboardPasteVisible
				onClicked: {
					futoHandler.paste(Clipboard.text)
					keyboard.expandedPaste = false
				}
			}

            Label {
                anchors.fill: parent
                anchors.leftMargin: Theme.horizontalPageMargin
                anchors.rightMargin: Theme.horizontalPageMargin
                visible: topStrip.stripRequired
                         && !topStrip.cursorStatusVisible
					 && !topStrip.modifierStatusVisible
                         && !topStrip.emojiTabsVisible
                         && !topStrip.emojiSearchVisible
                         && !topStrip.symbolTabsVisible
                         && !topStrip.controlsVisible
						 && !topStrip.voiceStatusVisible
						 && !topStrip.credentialSaveVisible
						 && !topStrip.passwordVaultVisible
                         && !topStrip.predictionContentAvailable
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                truncationMode: TruncationMode.Fade
                text: futoHandler.urlHistoryStripEnabled
                      ? qsTr("No saved URLs yet") : ""
            }

			Item {
				anchors.fill: parent
				z: 12
				visible: topStrip.cursorStatusVisible

				Row {
					anchors.centerIn: parent
					spacing: Theme.paddingMedium

					Canvas {
						id: cursorMoveIcon
						anchors.verticalCenter: parent.verticalCenter
						width: Theme.iconSizeMedium
						height: width
						property color arrowColor: Theme.highlightColor

						onArrowColorChanged: requestPaint()
						onWidthChanged: requestPaint()
						onHeightChanged: requestPaint()
						onPaint: {
							var context = getContext("2d")
							context.clearRect(0, 0, width, height)
							context.strokeStyle = arrowColor
							context.lineWidth = Math.max(2, width / 16)
							context.lineCap = "round"
							context.lineJoin = "round"
							var centerX = width / 2
							var centerY = height / 2
							var edge = width * 0.17
							var head = width * 0.10
							var gap = width * 0.16

							context.beginPath()
							// Up and down.
							context.moveTo(centerX, centerY - gap)
							context.lineTo(centerX, edge)
							context.moveTo(centerX, edge)
							context.lineTo(centerX - head, edge + head)
							context.moveTo(centerX, edge)
							context.lineTo(centerX + head, edge + head)
							context.moveTo(centerX, centerY + gap)
							context.lineTo(centerX, height - edge)
							context.moveTo(centerX, height - edge)
							context.lineTo(centerX - head, height - edge - head)
							context.moveTo(centerX, height - edge)
							context.lineTo(centerX + head, height - edge - head)
							// Left and right.
							context.moveTo(centerX - gap, centerY)
							context.lineTo(edge, centerY)
							context.moveTo(edge, centerY)
							context.lineTo(edge + head, centerY - head)
							context.moveTo(edge, centerY)
							context.lineTo(edge + head, centerY + head)
							context.moveTo(centerX + gap, centerY)
							context.lineTo(width - edge, centerY)
							context.moveTo(width - edge, centerY)
							context.lineTo(width - edge - head, centerY - head)
							context.moveTo(width - edge, centerY)
							context.lineTo(width - edge - head, centerY + head)
							context.stroke()
						}
					}

					Label {
						anchors.verticalCenter: parent.verticalCenter
						text: futoHandler.cursorSelectionMode
						      ? qsTr("Drag finger to select text")
						      : qsTr("Drag finger to move cursor")
						color: Theme.highlightColor
						font.pixelSize: Theme.fontSizeMedium
						truncationMode: TruncationMode.Fade
					}
				}
			}

			Item {
				anchors.fill: parent
				z: 13
				visible: topStrip.modifierStatusVisible

				Row {
					anchors.centerIn: parent
					spacing: Theme.paddingMedium

					Icon {
						anchors.verticalCenter: parent.verticalCenter
						width: Theme.iconSizeSmall
						height: width
						source: "image://theme/icon-m-keyboard"
						color: Theme.highlightColor
					}

					Label {
						anchors.verticalCenter: parent.verticalCenter
						text: futoHandler.desktopModifierStatusText
						color: Theme.highlightColor
						font.pixelSize: Theme.fontSizeSmall
						truncationMode: TruncationMode.Fade
					}
				}

				MouseArea {
					anchors.fill: parent
					onClicked: futoHandler.clearDesktopModifiers()
				}
			}

			Item {
				anchors.fill: parent
				visible: topStrip.voiceStatusVisible

				Row {
					anchors.centerIn: parent
					spacing: Theme.paddingMedium

					BusyIndicator {
						anchors.verticalCenter: parent.verticalCenter
						size: BusyIndicatorSize.Small
						running: futoHandler.voiceBusy
						visible: running
					}

					Icon {
						anchors.verticalCenter: parent.verticalCenter
						width: Theme.iconSizeSmall
						height: width
						visible: !futoHandler.voiceBusy
						source: "image://theme/icon-m-browser-microphone"
						color: futoHandler.voiceRecording
						       ? Theme.highlightColor : Theme.primaryColor
					}

					Label {
						anchors.verticalCenter: parent.verticalCenter
						text: futoHandler.voiceRecording
						      ? qsTr("Listening…")
						      : futoHandler.voiceBusy
						        ? qsTr("Transcribing on this phone…")
						        : futoHandler.voiceMessage
						color: futoHandler.voiceRecording
						       ? Theme.highlightColor : Theme.primaryColor
						font.pixelSize: Theme.fontSizeSmall
						truncationMode: TruncationMode.Fade
					}
				}
			}

            // When there is nothing to scroll or tap, still claim the gesture.
            // Otherwise the enclosing Jolla PagedView changes keyboard layouts.
            MouseArea {
                anchors.fill: parent
                z: 2
                visible: topStrip.stripRequired
                         && !topStrip.cursorStatusVisible
					 && !topStrip.modifierStatusVisible
                         && !topStrip.emojiTabsVisible
                         && !topStrip.emojiSearchVisible
                         && !topStrip.symbolTabsVisible
                         && !topStrip.controlsVisible
						 && !topStrip.voiceStatusVisible
						 && !topStrip.credentialSaveVisible
						 && !topStrip.passwordVaultVisible
                         && !topStrip.predictionContentAvailable
                preventStealing: true
            }

			BackgroundItem {
				anchors.fill: parent
				anchors.leftMargin: topStrip.passwordClipboardPasteVisible
				        ? passwordClipboardPasteButton.width : 0
				z: 4
				visible: topStrip.passwordVaultVisible
				onClicked: futoHandler.openPasswordVault()

				Row {
					anchors.centerIn: parent
					spacing: Theme.paddingMedium

					Icon {
						anchors.verticalCenter: parent.verticalCenter
						width: Theme.iconSizeSmall
						height: width
						source: "image://theme/icon-m-device-lock"
					}

					Label {
						readonly property string credentialTarget:
						        futoHandler.credentialOriginDisplayName(
						            futoHandler.lastCredentialOrigin)
						anchors.verticalCenter: parent.verticalCenter
						text: futoHandler.passwordVaultMessage !== ""
						      ? futoHandler.passwordVaultMessage
						      : credentialTarget !== ""
						        ? qsTr("Use saved login for %1?").arg(credentialTarget)
						        : qsTr("Use a saved login?")
						color: parent.parent.highlighted
						       ? Theme.highlightColor : Theme.primaryColor
					}
				}
			}

            Row {
                id: emojiTabs
                anchors.fill: parent
                visible: topStrip.emojiTabsVisible

                BackgroundItem {
                    width: topStrip.width / (keyboardLayout.emojiCategoryCount + 1)
                    height: topStrip.height
                    onClicked: {
                        futoHandler.playOptionFeedback()
                        keyboardLayout.startEmojiSearch()
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - Theme.paddingSmall,
                                        Theme.itemSizeSmall)
                        height: Math.min(parent.height - Theme.paddingSmall,
                                         Theme.itemSizeSmall)
                        radius: Theme.paddingMedium
                        color: Theme.rgba(Theme.highlightColor, 0.18)
                        border.width: 1
                        border.color: Theme.rgba(Theme.highlightColor, 0.55)
                        visible: keyboardLayout.emojiPage < 0
                    }

                    Icon {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) * 0.48
                        height: width
                        source: "image://theme/icon-m-search"
                        color: keyboardLayout.emojiPage < 0
                               ? Theme.highlightColor : Theme.primaryColor
                    }

                }

                Repeater {
                    model: keyboardLayout.emojiCategoryCount

                    BackgroundItem {
                        width: topStrip.width / (keyboardLayout.emojiCategoryCount + 1)
                        height: topStrip.height
                        onClicked: {
                            futoHandler.playOptionFeedback()
                            keyboardLayout.selectEmojiPage(index)
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(parent.width - Theme.paddingSmall,
                                            Theme.itemSizeSmall)
                            height: Math.min(parent.height - Theme.paddingSmall,
                                             Theme.itemSizeSmall)
                            radius: Theme.paddingMedium
                            color: Theme.rgba(Theme.highlightColor, 0.18)
                            border.width: 1
                            border.color: Theme.rgba(Theme.highlightColor, 0.55)
                            visible: index === keyboardLayout.emojiPage
                        }

                        Image {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height) * 0.50
                            height: width
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            // Category icons are tiny local assets.  Loading
                            // them synchronously avoids a visibly empty tab
							// strip. These tiny bundled PNGs do not depend on a
							// downloaded emoji style or SVG loader state.
                            asynchronous: false
							source: keyboardLayout.emojiTabAssetPath(index)
                            opacity: index === keyboardLayout.emojiPage ? 1.0 : 0.62
                        }

                    }
                }
            }

            SilicaListView {
                id: symbolTabs
                anchors.fill: parent
                visible: topStrip.symbolTabsVisible
                orientation: ListView.Horizontal
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                model: keyboardLayout.extendedSymbolCategoryCount

                delegate: Item {
                    readonly property bool isCurrentTab:
                            index === keyboardLayout.extendedSymbolPage
                    readonly property string tabName:
                            keyboardLayout.extendedSymbolTabName(index)
                    width: Math.max(Theme.itemSizeMedium,
                                    topStrip.width / Math.min(6,
                                        keyboardLayout.extendedSymbolCategoryCount))
                    height: topStrip.height

                    MouseArea {
                        id: symbolTabMouseArea
                        anchors.fill: parent
                        onClicked: {
                            futoHandler.playOptionFeedback()
                            keyboardLayout.selectExtendedSymbolPage(index)
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - Theme.paddingSmall,
                                        Theme.itemSizeSmall)
                        height: Math.min(parent.height - Theme.paddingSmall,
                                         Theme.itemSizeSmall)
                        radius: Theme.paddingMedium
                        color: Theme.rgba(Theme.highlightColor,
                                          symbolTabMouseArea.pressed ? 0.48 : 0.32)
                        border.width: 2
                        border.color: Theme.highlightColor
                        visible: symbolTabMouseArea.pressed
                                 || index === keyboardLayout.extendedSymbolPage
                    }

                    Label {
                        anchors.centerIn: parent
                        text: keyboardLayout.extendedSymbolTabIcon(index)
                        color: index === keyboardLayout.extendedSymbolPage
                               ? Theme.highlightColor : Theme.primaryColor
                        // The system Symbola fallback already renders these
                        // glyphs in the picker cells, including U+20BF.  The
                        // theme label font does not consistently fall back in
                        // this compact tab delegate, so select it explicitly.
                        font.family: "Symbola"
                        font.pixelSize: Theme.fontSizeSmall
                    }

                }
            }

            Row {
                id: emojiSearchBar
                anchors.fill: parent
                visible: topStrip.emojiSearchVisible

                BackgroundItem {
                    width: Theme.itemSizeMedium
                    height: parent.height
                    onClicked: {
                        futoHandler.playOptionFeedback()
                        keyboardLayout.finishEmojiSearch()
                    }

                    Icon {
                        anchors.centerIn: parent
                        source: "image://theme/icon-m-search"
                        color: Theme.highlightColor
                    }
                }

                Item {
                    width: emojiSearchBar.width - 2 * Theme.itemSizeMedium
                    height: emojiSearchBar.height

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: Theme.paddingSmall
                        anchors.bottomMargin: Theme.paddingSmall
                        radius: Theme.paddingSmall
                        color: Theme.rgba(Theme.primaryColor, 0.08)
                    }

                    Label {
                        id: emojiQueryLabel
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.paddingMedium
                        anchors.rightMargin: Theme.paddingMedium
                        text: keyboardLayout.emojiSearchQuery
                        color: Theme.highlightColor
                        truncationMode: TruncationMode.Fade
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.paddingMedium
                        anchors.rightMargin: Theme.paddingMedium
                        text: qsTr("Type an emoji name, then press Enter")
                        color: Theme.secondaryColor
                        truncationMode: TruncationMode.Fade
                        font.pixelSize: Theme.fontSizeSmall
                        visible: keyboardLayout.emojiSearchQuery === ""
                    }

                    Rectangle {
                        id: emojiSearchCursor
                        x: Math.min(parent.width - Theme.paddingMedium - width,
                                    Theme.paddingMedium + emojiQueryLabel.paintedWidth)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(2, Screen.width / 540)
                        height: Math.round(Theme.fontSizeSmall * 1.15)
                        radius: width / 2
                        color: Theme.highlightColor

                        SequentialAnimation on opacity {
                            running: emojiSearchBar.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.15; duration: 480 }
                            NumberAnimation { to: 1.0; duration: 480 }
                        }
                    }
                }

                BackgroundItem {
                    width: Theme.itemSizeMedium
                    height: parent.height
                    onClicked: {
                        futoHandler.playOptionFeedback()
                        keyboardLayout.cancelEmojiSearch()
                    }

                    Label {
                        anchors.centerIn: parent
                        text: "×"
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeLarge
                    }
                }
            }

            Row {
                id: controlButtons
                anchors.fill: parent
                // Retained as a source reference for the original fixed menu.
                // The configurable row below is the active implementation.
                visible: false
                property int buttonCount: 2
                                          + (keyboardLayout.enabledLetterLayoutCount > 1 ? 1 : 0)
                                          + 1
                                          + (keyboardSettings.clipboardHistoryEnabled ? 1 : 0)

                BackgroundItem {
                    id: layoutGroupButton
                    width: controlButtons.width / controlButtons.buttonCount
                    height: controlButtons.height
                    visible: keyboardLayout.enabledLetterLayoutCount > 1
                    clip: true
                    onClicked: {
                        futoHandler.playOptionFeedback()
                        keyboardLayout.cycleLetterLayout()
                    }

                    Column {
                        anchors.centerIn: parent
                        width: layoutGroupButton.width
                        spacing: 0

                        Item {
                            width: parent.width
                            height: Theme.iconSizeSmall

                            Icon {
                                id: layoutGroupIcon
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Theme.iconSizeSmall
                                height: width
                                source: "image://theme/icon-m-region"
                                color: Theme.primaryColor
                            }

                            Item {
                                id: layoutLanguageTicker
                                anchors.left: layoutGroupIcon.right
                                anchors.leftMargin: Theme.paddingSmall
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.paddingSmall
                                anchors.verticalCenter: layoutGroupIcon.verticalCenter
                                height: layoutLanguageMeasure.implicitHeight
                                clip: true

                                property real textOffset: 0
                                readonly property real fadeWidth: Math.min(
                                    Theme.paddingMedium, width / 3)
                                readonly property real scrollDistance: Math.max(
                                    0, layoutLanguageMeasure.implicitWidth
                                       - width + fadeWidth)
                                readonly property bool overflowing: scrollDistance > 0

                                function restartMarquee() {
                                    textOffset = 0
                                    if (overflowing && visible)
                                        layoutLanguageMarquee.restart()
                                }

                                onWidthChanged: restartMarquee()
                                onVisibleChanged: restartMarquee()

                                Label {
                                    id: layoutLanguageMeasure
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: layoutLanguageTicker.overflowing
                                       ? -layoutLanguageTicker.textOffset : 0
                                    visible: !layoutLanguageTicker.overflowing
                                    text: keyboardLayout.currentLayoutMenuLanguageLabel
                                    color: Theme.highlightColor
                                    font.pixelSize: Theme.fontSizeTiny

                                    onTextChanged: layoutLanguageTicker.restartMarquee()
                                    onImplicitWidthChanged: layoutLanguageTicker.restartMarquee()
                                }

                                // When scrolling is needed, clip the solid text
                                // before the final few pixels.  The slices below
                                // redraw that edge with decreasing opacity, so
                                // it fades into any keyboard ambience rather
                                // than requiring a hard-coded background color.
                                Item {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: Math.max(0, parent.width
                                                    - parent.fadeWidth)
                                    clip: true
                                    visible: parent.overflowing

                                    Label {
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: -layoutLanguageTicker.textOffset
                                        text: keyboardLayout.currentLayoutMenuLanguageLabel
                                        color: Theme.highlightColor
                                        font.pixelSize: Theme.fontSizeTiny
                                    }
                                }

                                Repeater {
                                    model: layoutLanguageTicker.overflowing ? 4 : 0

                                    Item {
                                        x: layoutLanguageTicker.width
                                           - layoutLanguageTicker.fadeWidth
                                           + index * width
                                        width: layoutLanguageTicker.fadeWidth / 4
                                        height: layoutLanguageTicker.height
                                        clip: true
                                        opacity: 0.8 - index * 0.2

                                        Label {
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: -parent.x
                                               - layoutLanguageTicker.textOffset
                                            text: keyboardLayout.currentLayoutMenuLanguageLabel
                                            color: Theme.highlightColor
                                            font.pixelSize: Theme.fontSizeTiny
                                        }
                                    }
                                }

                                SequentialAnimation {
                                    id: layoutLanguageMarquee
                                    running: layoutLanguageTicker.visible
                                             && layoutLanguageTicker.overflowing
                                    loops: Animation.Infinite

                                    PauseAnimation { duration: 850 }
                                    NumberAnimation {
                                        target: layoutLanguageTicker
                                        property: "textOffset"
                                        from: 0
                                        to: layoutLanguageTicker.scrollDistance
                                        duration: Math.max(650,
                                            layoutLanguageTicker.scrollDistance * 45)
                                        easing.type: Easing.Linear
                                    }
                                    PauseAnimation { duration: 700 }
                                    NumberAnimation {
                                        target: layoutLanguageTicker
                                        property: "textOffset"
                                        to: 0
                                        duration: 350
                                        easing.type: Easing.InOutQuad
                                    }
                                    PauseAnimation { duration: 350 }
                                }
                            }
                        }

                        Label {
                            x: Theme.paddingSmall
                            width: parent.width - 2 * Theme.paddingSmall
                            text: keyboardLayout.currentLetterLayoutMenuName
                            font.pixelSize: Theme.fontSizeExtraSmall
                            horizontalAlignment: Text.AlignHCenter
                            truncationMode: TruncationMode.Fade
                        }
                    }
                }

                BackgroundItem {
                    width: controlButtons.width / controlButtons.buttonCount
                    height: controlButtons.height
                    onClicked: {
                        futoHandler.playOptionFeedback()
                        keyboardLayout.showLayoutEditor()
                    }

                    Column {
                        anchors.centerIn: parent
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Theme.iconSizeSmall
                            height: width
                            source: "image://theme/icon-m-edit"
                            color: Theme.primaryColor
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("Layouts")
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }
                }

                BackgroundItem {
                    width: controlButtons.width / controlButtons.buttonCount
                    height: controlButtons.height
                    visible: keyboardSettings.clipboardHistoryEnabled
                    onClicked: {
                        futoHandler.playOptionFeedback()
                        keyboardLayout.showClipboardHistory()
                    }

                    Column {
                        anchors.centerIn: parent
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            // The theme clipboard artwork has more internal
                            // padding than its neighboring action icons.
                            width: Math.round(Theme.iconSizeSmall * 1.18)
                            height: width
                            source: "image://theme/icon-m-clipboard"
                            color: Theme.highlightColor
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("Clipboard")
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }
                }

                BackgroundItem {
                    width: controlButtons.width / controlButtons.buttonCount
                    height: controlButtons.height
                    onClicked: {
                        futoHandler.playOptionFeedback()
                        futoHandler.toggleIncognitoMode()
                    }

                    Column {
                        anchors.centerIn: parent
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Theme.iconSizeSmall
                            height: width
                            // Keep the familiar outline in both states.  The
                            // selected theme asset has unrelated artwork on
                            // this Sailfish release; highlighting communicates
                            // the enabled state without changing the glyph.
                            source: "image://theme/icon-m-incognito"
                            color: futoHandler.incognitoMode
                                   ? Theme.highlightColor : Theme.primaryColor
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("Incognito")
                            color: futoHandler.incognitoMode
                                   ? Theme.highlightColor : Theme.primaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }
                }

                BackgroundItem {
                    width: controlButtons.width / controlButtons.buttonCount
                    height: controlButtons.height
                    onClicked: {
                        futoHandler.playOptionFeedback()
                        futoHandler.openFutoSettings()
                    }

                    Column {
                        anchors.centerIn: parent
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "⚙"
                            color: Theme.highlightColor
                            font.pixelSize: Theme.iconSizeSmall
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("Settings")
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }
                }
            }

            SilicaFlickable {
                id: configuredControlButtons
                anchors.fill: parent
                visible: topStrip.controlsVisible
                clip: true
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                property var actions: futoHandler.quickSettingsActions()
                readonly property int buttonCount: Math.max(1, actions.length)
                readonly property real buttonWidth: Math.max(
                    Theme.itemSizeLarge,
                    width / Math.min(buttonCount, 5))
                contentWidth: configuredControlRow.width
                contentHeight: height
                interactive: contentWidth > width

                Row {
                    id: configuredControlRow
                    width: configuredControlButtons.buttonWidth
                           * configuredControlButtons.buttonCount
                    height: configuredControlButtons.height

                    Repeater {
                        model: configuredControlButtons.actions

                        BackgroundItem {
                            id: quickActionButton
                            property string actionId: String(modelData)
                            property bool languageHoldConsumed: false
                            readonly property bool selectedAction:
                                (actionId === "incognito" && futoHandler.incognitoMode)
                                || (actionId === "microphone"
                                    && futoHandler.voiceRecording)
                                || (actionId === "sound"
                                    && keyboardSettings.keySoundEnabled)
								|| (actionId === "desktopkeys"
								    && keyboardSettings.desktopToolbarEnabled)
                            width: configuredControlButtons.buttonWidth
                            height: configuredControlButtons.height
                            clip: true
                            onPressedChanged: {
                                if (pressed)
                                    languageHoldConsumed = false
                            }
                            onPressAndHold: {
                                if (actionId === "language") {
                                    // Consume the hold even when FUTO is the
                                    // only active keyboard; releasing must not
                                    // turn it into an ordinary layout tap.
                                    languageHoldConsumed = true
                                    futoHandler.switchToNextSailfishKeyboard()
                                }
                            }
                            onClicked: {
                                if (!languageHoldConsumed)
                                    futoHandler.activateQuickSetting(actionId)
                                languageHoldConsumed = false
                            }

                            Column {
                                anchors.centerIn: parent
                                width: quickActionButton.width
                                spacing: 0
                                visible: quickActionButton.actionId !== "language"

                                Item {
                                    width: parent.width
                                    height: Theme.iconSizeSmall

                                    Icon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: quickActionButton.actionId === "clipboard"
                                               ? Math.round(Theme.iconSizeSmall * 1.18)
                                               : Theme.iconSizeSmall
                                        height: width
                                        source: futoHandler.quickSettingIcon(
                                                    quickActionButton.actionId)
                                        visible: quickActionButton.actionId !== "settings"
                                        color: quickActionButton.selectedAction
                                               ? Theme.highlightColor : Theme.primaryColor
                                    }

                                    Label {
                                        anchors.centerIn: parent
                                        visible: quickActionButton.actionId === "settings"
                                        text: "⚙"
                                        color: Theme.primaryColor
                                        font.pixelSize: Theme.iconSizeSmall
                                    }
                                }

                                Label {
                                    x: Theme.paddingSmall
                                    width: parent.width - 2 * Theme.paddingSmall
                                    horizontalAlignment: Text.AlignHCenter
                                    text: futoHandler.quickSettingLabel(
                                              quickActionButton.actionId)
                                    color: quickActionButton.selectedAction
                                           ? Theme.highlightColor : Theme.primaryColor
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    truncationMode: TruncationMode.Fade
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                width: quickActionButton.width
                                spacing: 0
                                visible: quickActionButton.actionId === "language"

                                Item {
                                    width: parent.width
                                    height: Theme.iconSizeSmall

                                    Icon {
                                        id: configuredLanguageIcon
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: Theme.iconSizeSmall
                                        height: width
                                        source: "image://theme/icon-m-region"
                                        color: Theme.primaryColor
                                    }

                                    Item {
                                        id: configuredLanguageTicker
                                        anchors.left: configuredLanguageIcon.right
                                        anchors.leftMargin: Theme.paddingSmall
                                        anchors.right: parent.right
                                        anchors.rightMargin: Theme.paddingSmall
                                        anchors.verticalCenter: configuredLanguageIcon.verticalCenter
                                        height: configuredLanguageText.implicitHeight
                                        clip: true
                                        property real textOffset: 0
                                        readonly property real scrollDistance: Math.max(
                                            0, configuredLanguageText.implicitWidth - width)

                                        Label {
                                            id: configuredLanguageText
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: -configuredLanguageTicker.textOffset
                                            text: keyboardLayout.currentLayoutMenuLanguageLabel
                                            color: Theme.highlightColor
                                            font.pixelSize: Theme.fontSizeTiny
                                        }

                                        SequentialAnimation {
                                            running: configuredLanguageTicker.visible
                                                     && configuredLanguageTicker.scrollDistance > 0
                                            loops: Animation.Infinite
                                            PauseAnimation { duration: 850 }
                                            NumberAnimation {
                                                target: configuredLanguageTicker
                                                property: "textOffset"
                                                from: 0
                                                to: configuredLanguageTicker.scrollDistance
                                                duration: Math.max(650,
                                                    configuredLanguageTicker.scrollDistance * 45)
                                                easing.type: Easing.Linear
                                            }
                                            PauseAnimation { duration: 700 }
                                            NumberAnimation {
                                                target: configuredLanguageTicker
                                                property: "textOffset"
                                                to: 0
                                                duration: 350
                                                easing.type: Easing.InOutQuad
                                            }
                                            PauseAnimation { duration: 350 }
                                        }
                                    }
                                }

                                Label {
                                    x: Theme.paddingSmall
                                    width: parent.width - 2 * Theme.paddingSmall
                                    horizontalAlignment: Text.AlignHCenter
                                    text: keyboardLayout.currentLetterLayoutMenuName
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    truncationMode: TruncationMode.Fade
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: quickSettingsLeftOverflowFade
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.min(Theme.paddingLarge * 1.6, parent.width / 9)
                z: 30
                clip: true
                visible: configuredControlButtons.visible
                         && configuredControlButtons.contentWidth
                            > configuredControlButtons.width + 1
                         && configuredControlButtons.contentX > 1

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.height
                    height: parent.width
                    rotation: -90
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Theme.rgba(Theme.primaryColor, 0.16)
                        }
                        GradientStop {
                            position: 1
                            color: Theme.rgba(Theme.primaryColor, 0.0)
                        }
                    }
                }
            }

            Item {
                id: quickSettingsRightOverflowFade
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.min(Theme.paddingLarge * 1.6, parent.width / 9)
                z: 30
                clip: true
                visible: configuredControlButtons.visible
                         && configuredControlButtons.contentWidth
                            > configuredControlButtons.width + 1
                         && configuredControlButtons.contentX
                            < configuredControlButtons.contentWidth
                              - configuredControlButtons.width - 1

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.height
                    height: parent.width
                    rotation: -90
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Theme.rgba(Theme.primaryColor, 0.0)
                        }
                        GradientStop {
                            position: 1
                            color: Theme.rgba(Theme.primaryColor, 0.16)
                        }
                    }
                }
            }

        }
    }

    verticalItem: Component {
        Item {
            id: verticalContainer
            property int inactivePadding: Theme.paddingMedium
            readonly property Item activeLayout: keyboard.layout
            // The center column belongs to predictions only on the ordinary
            // letter page. Keeping it alive on 123 or a tool page caused stale
            // predictions to cover the landscape picker and control surfaces.
            readonly property bool predictionsVisible: activeLayout
					&& futoHandler.activeDesktopModifiers === 0
                    && !activeLayout.attributes.inSymView
                    && !activeLayout.attributes.inSymView2
                    && !activeLayout.emojiMode
                    && !activeLayout.emojiSearchMode
                    && !activeLayout.extendedSymbolMode
					&& !activeLayout.extraKeysMode
                    && !activeLayout.controlMode
                    && !activeLayout.layoutEditorMode
                    && !activeLayout.clipboardMode
					&& !activeLayout.credentialMode

            SilicaListView {
                id: verticalApplicationList
                anchors.fill: parent
                orientation: ListView.Vertical
                clip: true
                visible: verticalContainer.predictionsVisible
                         && futoHandler.showApplicationSuggestions
                model: applicationSuggestionModel
                delegate: BackgroundItem {
                    id: verticalApplicationDelegate
                    readonly property string suggestionText: String(model.text)
                    width: verticalApplicationList.width
                    height: geometry.keyHeightLandscape

                    onClicked: futoHandler.select(suggestionText, index)

                    Label {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.paddingMedium
                        anchors.rightMargin: Theme.paddingMedium
                        text: verticalApplicationDelegate.suggestionText
                        textFormat: Text.PlainText
                        font.pixelSize: Theme.fontSizeSmall
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        truncationMode: TruncationMode.Fade
                    }
                }
            }

            FutoVerticalPredictionListView {
                id: verticalList
                visible: verticalContainer.predictionsVisible
                         && (futoHandler.showUrlSuggestions
                             || !futoHandler.showApplicationSuggestions)
                handler: futoHandler
                model: predictionModel
                canRemove: true

                Connections {
                    target: futoHandler
                    onSuggestionsUpdated: verticalList.predictionsChanged()
                }

                MouseArea {
                    height: parent.height
                    width: verticalContainer.inactivePadding
                }
                MouseArea {
                    height: parent.height
                    width: verticalContainer.inactivePadding
                    anchors.right: parent.right
                }
            }
        }
    }

    onActiveChanged: {
		if (!editorSessionActive && passwordField) {
			finalizeCredentialCapture()
			offerCapturedCredential()
		}
        if (!editorSessionActive)
            learnCurrentUrl()
        if (!editorSessionActive && preedit !== "") {
            learn(preedit)
            commit(preedit)
        }
        if (!editorSessionActive) {
			clearCommittedSpace()
			endForcedAppSupportSession()
			cancelVoiceInput()
			cancelSwipeSession()
			clearDesktopModifiers()
			cancelCredentialAutofill(false)
			resetPasswordVault(true)
			credentialOfferDismissedForFocus = false
            requestSerial++
            predictionTimer.stop()
            nextPredictionTimer.stop()
            predictionModel.clear()
            urlSuggestionResultsActive = false
            urlSuggestionFallbackActive = false
            nextWordMode = false
            nextContextOverride = ""
            clearEditingWord()
            learnedUrlSuggestions = []
            urlSuggestionTimer.stop()
            editorTypedBuffer = ""
        } else if (active) {
            urlAcceptedThisFocus = ""
            editorTypedBuffer = ""
            editorContextTimer.restart()
            urlSuggestionTimer.restart()
            requestSuggestionsSoon()
        } else {
            // Android AppSupport can transiently deactivate this handler while
            // the Maliit input session and visible FUTO keyboard remain active.
            // Keep URL history alive across that handoff.
            editorContextTimer.restart()
            urlSuggestionTimer.restart()
        }
		refreshApplicationSuggestions()
    }

	onIncognitoModeChanged: {
		if (incognitoMode) {
			learnedUrlSuggestions = []
			// Password and non-predictive username fields automatically use
			// Incognito behavior, but saved-login filling is still allowed there.
			// Cancel only for an explicitly private/manual context.
			if (credentialLookupPrivateBlocked) {
				cancelCredentialAutofill(true)
				resetPasswordVault(true)
			}
		} else if (active && keyboardSettings.urlHistoryEnabled)
			urlSuggestionTimer.restart()
		refreshApplicationSuggestions()
	}

	onPasswordFieldChanged: {
		if (credentialAutofillStage > 0) {
			credentialAutofillStepTimer.restart()
		} else if (passwordField) {
			credentialOfferDismissedForFocus = false
			cancelVoiceInput()
			if (!credentialSaveInProgress) {
				credentialCaptureIdleTimer.stop()
				credentialCapturePassword = ""
				credentialCaptureUsername = lastCredentialUsername
				credentialCaptureOrigin = lastCredentialOrigin
			}
			refreshCredentialMatch()
		} else {
			finalizeCredentialCapture()
			offerCapturedCredential()
			credentialMatchAvailable = false
			credentialMatchSerial++
			resetPasswordVault(true)
		}
		refreshApplicationSuggestions()
	}

	onCredentialUsernameFieldChanged: {
		if (credentialAutofillStage > 0) {
			credentialAutofillStepTimer.restart()
		} else if (credentialUsernameField) {
			credentialOfferDismissedForFocus = false
			refreshCredentialMatch()
		} else if (!passwordField) {
			credentialMatchAvailable = false
			credentialMatchSerial++
			resetPasswordVault(true)
		}
	}

	onLastCredentialOriginChanged: {
		if (credentialFieldCandidate)
			refreshCredentialMatch()
	}

    Connections {
        target: MInputMethodQuick
        onActiveChanged: {
            if (!MInputMethodQuick.active) {
				futoHandler.endForcedAppSupportSession()
				if (futoHandler.passwordField) {
					futoHandler.finalizeCredentialCapture()
					futoHandler.offerCapturedCredential()
				}
                futoHandler.cancelVoiceInput()
				futoHandler.clearDesktopModifiers()
            } else if (keyboardSettings.urlHistoryEnabled) {
                editorContextTimer.restart()
                urlSuggestionTimer.restart()
            }
        }
        onFocusTargetChanged: {
			futoHandler.cancelSwipeSession()
			futoHandler.clearCommittedSpace()
			if (!activeEditor)
				futoHandler.endForcedAppSupportSession()
			// A new editor must not inherit the fallback text buffer from the
			// previous field. The authoritative surrounding text is synchronized
			// below when the application exposes it.
			if (activeEditor && !futoHandler.passwordField)
				futoHandler.editorTypedBuffer = ""
			futoHandler.credentialDebug("focus password="
			        + futoHandler.passwordField
			        + " actionLabel=" + MInputMethodQuick.actionKeyOverride.label
			        + " actionIcon=" + MInputMethodQuick.actionKeyOverride.icon
			        + " actionEnabled=" + MInputMethodQuick.actionKeyOverride.enabled)
			if (futoHandler.credentialAutofillStage > 0)
				credentialAutofillStepTimer.restart()
			else
				futoHandler.credentialOfferDismissedForFocus = false
            if (!activeEditor) {
				futoHandler.rememberCredentialContext()
				if (futoHandler.passwordField) {
					futoHandler.finalizeCredentialCapture()
					futoHandler.offerCapturedCredential()
				}
                futoHandler.learnCurrentUrl()
                // Hiding the keyboard can leave InputHandler.active true when
                // the editor itself retains focus. Voice capture must never
                // outlive the visible keyboard.
                futoHandler.cancelVoiceInput()
            }
            futoHandler.trackSurroundings = activeEditor
            futoHandler.resetSuggestionDisplay()
            if (activeEditor) {
				futoHandler.rememberCredentialContext()
                futoHandler.urlAcceptedThisFocus = ""
                editorContextTimer.restart()
                urlSuggestionTimer.restart()
                futoHandler.requestSuggestionsSoon()
				if (futoHandler.credentialFieldCandidate
						&& futoHandler.credentialAutofillStage === 0)
					futoHandler.refreshCredentialMatch()
            }
			futoHandler.refreshApplicationSuggestions()
        }
        onCursorPositionChanged: {
            if (futoHandler.committedSpaceArmed
                    && futoHandler.committedSpaceExpectedCursor >= 0
                    && MInputMethodQuick.surroundingTextValid
                    && MInputMethodQuick.cursorPosition
                       !== futoHandler.committedSpaceExpectedCursor)
                futoHandler.clearCommittedSpace()
            if (futoHandler.active && futoHandler.preedit === "") {
				futoHandler.syncEditorTypedBuffer()
                editorContextTimer.restart()
                urlSuggestionTimer.restart()
            }
        }
        onEditorStateUpdate: {
            if (futoHandler.trackSurroundings && futoHandler.active
                    && futoHandler.preedit === "") {
				futoHandler.syncEditorTypedBuffer()
				futoHandler.rememberCredentialContext()
                editorContextTimer.restart()
                urlSuggestionTimer.restart()
            }
        }
        onContentTypeChanged: {
            futoHandler.resetSuggestionDisplay()
			futoHandler.refreshApplicationSuggestions()
            editorContextTimer.restart()
            urlSuggestionTimer.restart()
            futoHandler.requestSuggestionsSoon()
			if (futoHandler.credentialFieldCandidate)
				futoHandler.refreshCredentialMatch()
        }
        onExtensionsChanged: {
            futoHandler.resetSuggestionDisplay()
			futoHandler.refreshApplicationSuggestions()
            editorContextTimer.restart()
            urlSuggestionTimer.restart()
            futoHandler.requestSuggestionsSoon()
			if (futoHandler.credentialFieldCandidate)
				futoHandler.refreshCredentialMatch()
        }
    }

    Connections {
        target: keyboard.layout
        ignoreUnknownSignals: true
        onActivePredictionLanguagesChanged: {
            futoHandler.requestSerial++
            predictionModel.clear()
            futoHandler.requestSuggestionsSoon()
        }
    }

    function requestSuggestionsSoon() {
        correctionQuery = ""
        correctionCandidate = ""
        nextPredictionTimer.stop()
        nextContextOverride = ""
        nextWordMode = false
        if (urlField) {
            predictionTimer.stop()
            if (keyboardSettings.urlHistoryEnabled && !passwordField && !incognitoMode) {
                if (learnedUrlSuggestions.length > 0) {
                    replaceUrlPredictionSuggestions(learnedUrlSuggestions)
                } else if (urlSuggestionFallbackActive
                           && activeSuggestionQuery !== ""
                           && activePredictionsAvailable
                           && (keyboardSettings.predictionEnabled
                               || keyboardSettings.autoCorrectionEnabled)) {
                    predictionTimer.restart()
                }
                urlSuggestionTimer.restart()
            } else {
                clearUrlPredictionSuggestions()
            }
            return
        }
        if (urlSuggestionResultsActive)
            clearUrlPredictionSuggestions()
        if (active && activeSuggestionQuery !== "" && !urlField
                && !passwordField && activePredictionsAvailable
                && (keyboardSettings.predictionEnabled
                    || keyboardSettings.autoCorrectionEnabled)) {
            predictionTimer.restart()
        } else {
            predictionTimer.stop()
            if (active && activeSuggestionQuery === "" && !urlField
                    && !passwordField && activePredictionsAvailable
                    && keyboardSettings.predictionEnabled
                    && keyboardSettings.nextWordPredictionEnabled) {
                nextContextOverride = contextBeforeCursor()
                nextPredictionTimer.restart()
            } else {
                predictionModel.clear()
                suggestionsUpdated()
            }
        }
    }

    function resetSuggestionDisplay() {
        requestSerial++
        predictionTimer.stop()
        nextPredictionTimer.stop()
        predictionModel.clear()
        urlSuggestionResultsActive = false
        urlSuggestionFallbackActive = false
        nextWordMode = false
        nextContextOverride = ""
        clearEditingWord()
        suggestionsUpdated()
    }

    function clearEditingWord() {
        editingWord = ""
        editingWordStart = -1
        editingWordLength = 0
    }

    function wordRangeAtCursor() {
        if (!active || preedit !== "" || urlField
                || !MInputMethodQuick.surroundingTextValid
                || MInputMethodQuick.hasSelection || MInputMethodQuick.hiddenText)
            return null

        var text = String(MInputMethodQuick.surroundingText)
        var cursor = Math.max(0, Math.min(MInputMethodQuick.cursorPosition, text.length))
        var probe = -1
        if (cursor > 0 && isInputCharacter(text.charAt(cursor - 1)))
            probe = cursor - 1
        else if (cursor < text.length && isInputCharacter(text.charAt(cursor)))
            probe = cursor
        if (probe < 0)
            return null

        var start = probe
        while (start > 0 && isInputCharacter(text.charAt(start - 1)))
            --start
        var end = probe + 1
        while (end < text.length && isInputCharacter(text.charAt(end)))
            ++end
        return { "text": text.substring(start, end), "start": start,
                 "length": end - start, "cursor": cursor }
    }

    function refreshEditingWord() {
		if (swipeReplacementActive)
			return
        if (preedit !== "") {
            clearEditingWord()
            return
        }
        var range = wordRangeAtCursor()
        if (!range || !activePredictionsAvailable
                || (!keyboardSettings.predictionEnabled
                    && !keyboardSettings.autoCorrectionEnabled)) {
            if (editingWord !== "") {
                requestSerial++
                clearEditingWord()
                predictionTimer.stop()
                predictionModel.clear()
                suggestionsUpdated()
            }
            if (!range)
                requestSuggestionsSoon()
            return
        }
        if (editingWord === range.text && editingWordStart === range.start
                && editingWordLength === range.length)
            return
        requestSerial++
        editingWord = range.text
        editingWordStart = range.start
        editingWordLength = range.length
        requestSuggestionsSoon()
    }

    function currentUrlCandidate() {
        var value = rawEditorText().trim()
        if (value === "" || value.length > 2048 || /\s/.test(value)
                || value.indexOf("@") >= 0)
            return ""
        return value
    }

    function requestUrlSuggestions() {
        if ((!editorSessionActive && !urlField)
                || !keyboardSettings.urlHistoryEnabled
                || incognitoMode || MInputMethodQuick.hiddenText) {
            learnedUrlSuggestions = []
			clearUrlPredictionSuggestions()
			refreshApplicationSuggestions()
            return
        }
        var prefix = currentUrlCandidate()
        // An empty address bar may offer recent URLs when the editor identifies
        // itself as a URL field. In other editors, wait for a non-empty prefix
        // so URL history never replaces ordinary empty-field predictions.
        if (prefix === "" && !urlField) {
            learnedUrlSuggestions = []
			clearUrlPredictionSuggestions()
			refreshApplicationSuggestions()
            return
        }
        var serial = ++urlRequestSerial
        var dispatched = helper.typedCall("SuggestURLs", [
            { "type": "s", "value": prefix },
            { "type": "i", "value": 12 }
        ], function(resultJson) {
            // Android editors may emit several state updates for the same
            // visible prefix.  Those updates start identical DBus requests and
            // increment urlRequestSerial before the first reply arrives.  A
            // strict serial check therefore discarded every correct result.
            // A reply for the text that is still visible is valid regardless
            // of which identical request completed first.
            if (!keyboardSettings.urlHistoryEnabled || futoHandler.incognitoMode
                    || futoHandler.passwordField
                    || futoHandler.currentUrlCandidate() !== prefix) {
                return
            }
            var values = []
            try {
                values = resultJson instanceof Array
                        ? resultJson : JSON.parse(String(resultJson))
            } catch (error) {
                values = []
            }
            futoHandler.learnedUrlSuggestions = futoHandler.nonEmptySuggestions(values)
			if (futoHandler.learnedUrlSuggestions.length > 0) {
                ++futoHandler.requestSerial
			    futoHandler.replaceUrlPredictionSuggestions(
			            futoHandler.learnedUrlSuggestions)
            } else {
                futoHandler.clearUrlPredictionSuggestions()
                futoHandler.urlSuggestionFallbackActive = prefix !== ""
                if (futoHandler.urlSuggestionFallbackActive
                        && futoHandler.activeSuggestionQuery !== ""
                        && futoHandler.activePredictionsAvailable
                        && (keyboardSettings.predictionEnabled
                            || keyboardSettings.autoCorrectionEnabled)) {
                    predictionTimer.restart()
                }
            }
        }, function() {
            if (serial === futoHandler.urlRequestSerial) {
                futoHandler.learnedUrlSuggestions = []
				futoHandler.clearUrlPredictionSuggestions()
				futoHandler.urlSuggestionFallbackActive = prefix !== ""
				if (futoHandler.urlSuggestionFallbackActive
                        && futoHandler.activeSuggestionQuery !== ""
                        && futoHandler.activePredictionsAvailable
                        && (keyboardSettings.predictionEnabled
                            || keyboardSettings.autoCorrectionEnabled)) {
                    predictionTimer.restart()
                }
			}
        })
        if (dispatched === false) {
            learnedUrlSuggestions = []
			clearUrlPredictionSuggestions()
			urlSuggestionFallbackActive = prefix !== ""
			if (urlSuggestionFallbackActive && activeSuggestionQuery !== ""
                    && activePredictionsAvailable
                    && (keyboardSettings.predictionEnabled
                        || keyboardSettings.autoCorrectionEnabled)) {
                predictionTimer.restart()
            }
		}
    }

    function learnCurrentUrl() {
        if (!keyboardSettings.urlHistoryEnabled || !urlField || incognitoMode
                || MInputMethodQuick.hiddenText)
            return
        var candidate = currentUrlCandidate()
        if (candidate === "" || candidate === urlAcceptedThisFocus)
            return
        urlAcceptedThisFocus = candidate
        lastCredentialOrigin = candidate
        helper.typedCall("RecordURL", [
            { "type": "s", "value": candidate }
        ], function() {}, function() {})
    }

    function enabledLanguages() {
        return String(activePredictionLanguages)
    }

    function contextBeforeCursor() {
        if (!MInputMethodQuick.surroundingTextValid)
            return ""
        var position = Math.max(0, Math.min(MInputMethodQuick.cursorPosition,
                                            MInputMethodQuick.surroundingText.length))
        return MInputMethodQuick.surroundingText.substring(0, position)
    }

    function lastWord(text) {
        text = String(text)
        var end = text.length
        while (end > 0 && !isInputCharacter(text.charAt(end - 1)))
            end--
        var start = end
        while (start > 0 && isInputCharacter(text.charAt(start - 1)))
            start--
        return text.substring(start, end)
    }

    function scheduleNextWords(committedWord) {
        if (!active || !activePredictionsAvailable || !keyboardSettings.predictionEnabled
                || !keyboardSettings.nextWordPredictionEnabled) {
            return
        }
        var context = contextBeforeCursor()
        if (committedWord !== "")
            context += (context.length > 0 ? " " : "") + committedWord
        nextContextOverride = context
        nextPredictionTimer.restart()
    }

    function requestNextWords() {
        if (!active || preedit !== "" || passwordField || urlField
                || !activePredictionsAvailable
                || !keyboardSettings.predictionEnabled
                || !keyboardSettings.nextWordPredictionEnabled) {
            nextWordMode = false
            return
        }
        var context = nextContextOverride !== "" ? nextContextOverride : contextBeforeCursor()
        nextContextOverride = ""
        var serial = ++requestSerial
        var configuredLimit = Number(keyboardSettings.suggestionCount)
        var suggestionLimit = isFinite(configuredLimit)
                ? Math.max(3, Math.min(12, Math.round(configuredLimit))) : 12
        var sentenceStart = keyboard.autocaps
        var dispatched = helper.typedCall("NextWords", [
            { "type": "s", "value": enabledLanguages() },
            { "type": "s", "value": context },
            { "type": "i", "value": suggestionLimit },
            { "type": "b", "value": sentenceStart }
        ], function(resultJson) {
            if (serial !== futoHandler.requestSerial || futoHandler.preedit !== "")
                return
            var words = []
            try {
                words = JSON.parse(String(resultJson))
            } catch (error) {
                words = []
            }
            var visibleWordCount = futoHandler.replacePredictionSuggestions(words)
            futoHandler.nextWordMode = visibleWordCount > 0
            futoHandler.suggestionsUpdated()
        }, function() {
            if (serial === futoHandler.requestSerial) {
                predictionModel.clear()
                futoHandler.nextWordMode = false
                futoHandler.suggestionsUpdated()
            }
        })
        if (dispatched === false) {
            predictionModel.clear()
            nextWordMode = false
            suggestionsUpdated()
        }
    }

    function requestSuggestions() {
        var query = activeSuggestionQuery
        if (!active || query === ""
                || (urlField && !urlSuggestionFallbackActive)
                || !activePredictionsAvailable)
            return
        var committedQuery = preedit === "" && editingWord !== ""
        var queryStart = editingWordStart
        var queryLength = editingWordLength
        var serial = ++requestSerial
        var configuredLimit = Number(keyboardSettings.suggestionCount)
        var suggestionLimit = isFinite(configuredLimit)
                ? Math.max(3, Math.min(12, Math.round(configuredLimit))) : 12
        var configuredCorrectionLevel = Number(keyboardSettings.correctionLevel)
        var correctionLevel = isFinite(configuredCorrectionLevel)
                ? Math.max(0, Math.min(2, Math.round(configuredCorrectionLevel))) : 0
        var context = contextBeforeCursor()
        if (committedQuery && MInputMethodQuick.surroundingTextValid)
            context = MInputMethodQuick.surroundingText.substring(0, queryStart)
        var dispatched = helper.typedCall("AnalyzeContext", [
            { "type": "s", "value": enabledLanguages() },
            { "type": "s", "value": String(query) },
            { "type": "s", "value": context },
            { "type": "i", "value": suggestionLimit },
            { "type": "i", "value": correctionLevel },
            { "type": "b", "value": keyboardSettings.showTypedWord },
            { "type": "b", "value": keyboardSettings.automaticLanguageDetection }
        ], function(resultJson) {
            if (serial !== futoHandler.requestSerial
                    || query !== futoHandler.activeSuggestionQuery
                    || (futoHandler.urlField
                        && !futoHandler.urlSuggestionFallbackActive)
                    || committedQuery !== (futoHandler.preedit === ""
                                           && futoHandler.editingWord !== "")
                    || (committedQuery && (queryStart !== futoHandler.editingWordStart
                                           || queryLength !== futoHandler.editingWordLength)))
                return
            var result
            try {
                result = JSON.parse(String(resultJson))
            } catch (error) {
                result = { "suggestions": [], "correction": "" }
            }
            futoHandler.replacePredictionSuggestions(
                keyboardSettings.predictionEnabled && result.suggestions
                ? result.suggestions : [])
            futoHandler.correctionQuery = keyboardSettings.autoCorrectionEnabled ? query : ""
            futoHandler.correctionCandidate = keyboardSettings.autoCorrectionEnabled
                    && result.correction ? String(result.correction) : ""
            if (result.language)
                futoHandler.detectedLanguage = String(result.language)
            futoHandler.nextWordMode = false
            futoHandler.suggestionsUpdated()
        }, function() {
            if (serial === futoHandler.requestSerial) {
                predictionModel.clear()
                futoHandler.correctionQuery = ""
                futoHandler.correctionCandidate = ""
                futoHandler.suggestionsUpdated()
            }
        })
        if (dispatched === false) {
            predictionModel.clear()
            correctionQuery = ""
            correctionCandidate = ""
            suggestionsUpdated()
        }

    }

    function learnWithPrevious(previous, word) {
        if (!word || !activePredictionsAvailable
                || !keyboardSettings.personalLearningEnabled
                || futoHandler.incognitoMode || urlField)
            return
        helper.typedCall("AcceptContext", [
            { "type": "s", "value": enabledLanguages() },
            { "type": "s", "value": previous },
            { "type": "s", "value": String(word) },
            { "type": "s", "value": detectedLanguage }
        ], function() {}, function() {})
    }

    function learn(word) {
        learnWithPrevious(lastWord(contextBeforeCursor()), word)
    }

    function applyPrediction(replacement) {
        if (preedit === "" && editingWord !== "") {
            var replacingSwipe = swipeReplacementActive
            var previousSwipeWord = swipePreviousWord
            var start = editingWordStart
            var length = editingWordLength
            var cursor = MInputMethodQuick.cursorPosition
			var addEditingSpace = keyboardSettings.autoSpaceAfterSuggestion
			        && !urlField && !passwordField
			        && cursor === start + length
			var replacementText = String(replacement)
			        + (addEditingSpace ? " " : "")
            requestSerial++
            predictionTimer.stop()
            nextPredictionTimer.stop()
			MInputMethodQuick.sendCommit(replacementText, start - cursor, length)
            if (addEditingSpace)
                armCommittedSpace(start + replacementText.length)
            clearEditingWord()
			swipeReplacementActive = false
			swipePreviousWord = ""
            correctionQuery = ""
            correctionCandidate = ""
            nextWordMode = false
            predictionModel.clear()
            suggestionsUpdated()
            editorContextTimer.restart()
			if (replacingSwipe) {
				learnWithPrevious(previousSwipeWord, replacement)
				scheduleNextWords(replacement)
			}
            return
        }
        var addSpace = keyboardSettings.autoSpaceAfterSuggestion
        candidateSpaceIndex = addSpace && MInputMethodQuick.surroundingTextValid
                ? MInputMethodQuick.cursorPosition + replacement.length + 1 : -1
        var cursorBeforeSuggestion = MInputMethodQuick.surroundingTextValid
                ? MInputMethodQuick.cursorPosition : -1
        learn(replacement)
        commit(replacement + (addSpace ? " " : ""))
        if (addSpace)
            armCommittedSpace(cursorBeforeSuggestion < 0 ? -1
                              : cursorBeforeSuggestion + replacement.length + 1)
        if (keyboard.shiftState !== ShiftState.LockedShift) {
            keyboard.shiftState = addSpace ? ShiftState.AutoShift : ShiftState.NoShift
        }
        if (addSpace)
            scheduleNextWords(replacement)
    }

    function handleKeyPress() {
		if (spacebarGestureActive) {
			resetSwipePath()
			return true
		}
		if (swipeReplacementActive) {
			swipeReplacementActive = false
			swipePreviousWord = ""
			clearEditingWord()
		}
		// Quick Settings intentionally stays open while its language button is
		// tapped repeatedly. The first subsequent letter touch must close that
		// overlay and begin the gesture immediately instead of consuming the
		// user's first swipe after the language change.
		if (keyboard.layout && keyboard.layout.controlMode
				&& pressedKey && pressedKey.swipeTypingKey === true
				&& keyboard.layout.hideControlStrip) {
			keyboard.layout.hideControlStrip()
		}
		// KeyboardBase treats a downward drag as a dismissal before the swipe
		// decoder can finish.  A press that can begin word swiping owns the
		// complete gesture; Space and non-letter panels deliberately retain the
		// standard Sailfish swipe-down-to-close behavior.
		if (swipeKeyAllowed(pressedKey)
				&& keyboard.closeSwipeActive !== undefined)
			keyboard.closeSwipeActive = false
		captureSwipeKey(pressedKey)
        return false
    }

    function playAutomaticKeySound(key) {
        if (!key || key.manualFeedbackOnPress === true)
            return
        if (key.key === Qt.Key_Return) {
            playKeySound("enter")
        } else if ((key.keyType === KeyType.CharacterKey
                    || key.keyType === KeyType.PopupKey)
                   && key.text !== " ") {
            playKeySound("letter")
        } else if (key.text === " ") {
            playKeySound("letter")
        } else {
            playKeySound("option")
        }
    }

    function handleKeyClick() {
		if (spacebarGestureActive) {
			resetSwipePath()
			return true
		}
        // handleKeyClick is the reliable callback for ordinary CharacterKey
        // instances on the Sailfish keyboard stack used by this phone.
        // Custom keys marked manualFeedbackOnPress already play on touch-down.
        playAutomaticKeySound(pressedKey)
        typingContinued()
		if (handleArmedDesktopModifierKey(pressedKey)) {
			resetSwipePath()
			return true
		}
		captureEditorKey(pressedKey)
		captureCredentialKey(pressedKey)
		if (finishSwipeGesture())
			return true
		resetSwipePath()
        if (keyboard.layout && keyboard.layout.emojiSearchMode
                && keyboard.layout.handleEmojiSearchKey)
            return keyboard.layout.handleEmojiSearchKey(pressedKey)
		if (keyboardSettings.forcedAppSupportKeyEvents
				&& pressedKey
				&& pressedKey.keyType !== KeyType.ShiftKey
				&& pressedKey.keyType !== KeyType.SymbolKey
				&& (pressedKey.key === Qt.Key_Backspace
					|| pressedKey.key === Qt.Key_Space
					|| pressedKey.key === Qt.Key_Return
					|| pressedKey.key === Qt.Key_Enter
					|| String(pressedKey.text || "").length > 0)) {
			preedit = ""
			clearEditingWord()
			helper.typedCall("InjectAndroidKey", [
				{ "type": "i", "value": pressedKey.key },
				{ "type": "s", "value": String(pressedKey.text || "") }
			], function() {}, function() {})
			return true
		}

        var handled = false
        var correctedSpaceIndex = -1
        var punctuationText = pressedKey && pressedKey.text
                ? String(pressedKey.text) : ""
        var punctuationKey = ",.?!:;".indexOf(punctuationText) >= 0
        if (pressedKey.key !== Qt.Key_Space && !punctuationKey)
            clearCommittedSpace()
        keyboard.expandedPaste = false

        if (pressedKey.key !== Qt.Key_Backspace)
            clearUndoCorrection()

        if (pressedKey.key === Qt.Key_Space) {
            if (preedit !== "") {
                var original = preedit
                var accepted = original
                var corrected = keyboardSettings.autoCorrectionEnabled
                        && correctionQuery === original
                        && correctionCandidate !== ""
                        && correctionCandidate.toLocaleLowerCase()
                           !== original.toLocaleLowerCase()
                if (corrected)
                    accepted = correctionCandidate

                var cursorBeforeCommit = MInputMethodQuick.cursorPosition
                learn(accepted)
                commit(accepted + " ")
                armCommittedSpace(MInputMethodQuick.surroundingTextValid
                                  ? cursorBeforeCommit + accepted.length + 1 : -1)
                scheduleNextWords(accepted)
                if (corrected && keyboardSettings.undoCorrectionEnabled
                        && MInputMethodQuick.surroundingTextValid) {
                    undoCorrectionAvailable = true
                    undoOriginalWord = original
                    undoReplacementWord = accepted
                    undoCursorPosition = cursorBeforeCommit + accepted.length + 1
                    correctedSpaceIndex = undoCursorPosition
                }
                keyboard.autocaps = false
            } else if (keyboardSettings.doubleSpacePeriodEnabled
                       && committedSpaceIsCurrent()
                       && committedSpaceAllowsPeriod
                       && smartPunctuationField()) {
                nextContextOverride = contextBeforeCursor()
                MInputMethodQuick.sendCommit(". ", -1, 1)
                clearCommittedSpace()
                nextPredictionTimer.restart()
            } else {
                scheduleNextWords("")
                var cursorBeforeSpace = MInputMethodQuick.surroundingTextValid
                        ? MInputMethodQuick.cursorPosition : -1
                var previousCharacter = cursorBeforeSpace > 0
                        ? MInputMethodQuick.surroundingText.charAt(cursorBeforeSpace - 1) : ""
                var periodAllowed = previousCharacter !== ""
                        && ".?! \n\t".indexOf(previousCharacter) < 0
                MInputMethodQuick.sendCommit(" ")
                armCommittedSpace(cursorBeforeSpace < 0 ? -1
                                  : cursorBeforeSpace + 1, periodAllowed)
            }
            if (keyboard.shiftState !== ShiftState.LockedShift)
                keyboard.shiftState = ShiftState.AutoShift
            handled = true
        } else if (pressedKey.key === Qt.Key_Return) {
            learnCurrentUrl()
			editorTypedBuffer = ""
            if (preedit !== "") {
                learn(preedit)
                commit(preedit)
            }
            if (keyboard.shiftState !== ShiftState.LockedShift)
                keyboard.shiftState = ShiftState.AutoShift
        } else if (pressedKey.key === Qt.Key_Backspace && preedit === ""
                   && keyboardSettings.undoCorrectionEnabled
                   && undoLastCorrection()) {
            handled = true
        } else if (pressedKey.key === Qt.Key_Backspace && preedit !== "") {
            preedit = preedit.substr(0, preedit.length - 1)
            MInputMethodQuick.sendPreedit(preedit)
            requestSuggestionsSoon()
            if (keyboard.shiftState !== ShiftState.LockedShift) {
                keyboard.shiftState = preedit.length === 0
                        ? ShiftState.AutoShift : ShiftState.NoShift
            }
            handled = true
        } else if (pressedKey.key === Qt.Key_Backspace && editingWord !== "") {
            MInputMethodQuick.sendKey(Qt.Key_Backspace, 0, "\b", Maliit.KeyClick)
            clearEditingWord()
            editorContextTimer.restart()
            handled = true
        } else if (pressedKey.text.length !== 0) {
            if (isInputCharacter(pressedKey.text)) {
                if (immediateCommitField) {
					if (preedit !== "")
						commit(preedit)
					MInputMethodQuick.sendCommit(pressedKey.text)
					clearEditingWord()
					if (keyboard.shiftState !== ShiftState.LockedShift)
						keyboard.shiftState = ShiftState.NoShift
				} else if (editingWord !== "") {
                    MInputMethodQuick.sendCommit(pressedKey.text)
                    clearEditingWord()
                    editorContextTimer.restart()
                } else {
                    preedit += pressedKey.text
                    if (keyboard.shiftState !== ShiftState.LockedShift)
                        keyboard.shiftState = ShiftState.NoShift
                    MInputMethodQuick.sendPreedit(preedit)
                    requestSuggestionsSoon()
                }
                handled = true
            } else {
                if (preedit !== "") {
                    learn(preedit)
                    commit(preedit + pressedKey.text)
                } else if (keyboardSettings.smartPunctuationEnabled
                           && punctuationKey && smartPunctuationField()
                           && spaceImmediatelyBeforeCursor()) {
                    MInputMethodQuick.sendCommit(pressedKey.text + " ", -1, 1)
                    preedit = ""
                    clearCommittedSpace()
                } else {
                    MInputMethodQuick.sendCommit(pressedKey.text)
                    clearCommittedSpace()
                }
                handled = true
            }
        } else if (pressedKey.key === Qt.Key_Backspace
                   && MInputMethodQuick.surroundingTextValid
                   && !MInputMethodQuick.hasSelection
                   && MInputMethodQuick.cursorPosition >= 2
                   && !isInputCharacter(MInputMethodQuick.surroundingText.charAt(
                       MInputMethodQuick.cursorPosition - 1))
                   && isInputCharacter(MInputMethodQuick.surroundingText.charAt(
                       MInputMethodQuick.cursorPosition - 2))) {
            var length = 1
            var position = MInputMethodQuick.cursorPosition - 3
            for (; position >= 0 && isInputCharacter(
                     MInputMethodQuick.surroundingText.charAt(position)); --position) {
                length++
            }
            position++
            var word = MInputMethodQuick.surroundingText.substring(position, position + length)
            MInputMethodQuick.sendKey(Qt.Key_Backspace, 0, "\b", Maliit.KeyClick)
            MInputMethodQuick.sendPreedit(word, undefined, -length, length)
            preedit = word
            requestSuggestionsSoon()
            handled = true
        }

        if (pressedKey.keyType !== KeyType.ShiftKey
                && pressedKey.keyType !== KeyType.SymbolKey) {
            candidateSpaceIndex = -1
        }
        if (correctedSpaceIndex > 0)
            candidateSpaceIndex = correctedSpaceIndex
        return handled
    }

	function handleKeyRelease() {
		if (spacebarGestureActive) {
			resetSwipePath()
			return true
		}
		if (swipePath.length > 0)
			swipeReleaseTimer.restart()
		return false
	}

	function swipeKeyAllowed(key) {
		if (spacebarGestureActive || activeDesktopModifiers !== 0
				|| !key || key.swipeTypingKey !== true
				|| !keyboardSettings.swipeTypingEnabled
				|| !active || passwordField || !activePredictionsAvailable
				|| MInputMethodQuick.hasSelection || keyboard.inSymView)
			return false
		var layout = keyboard.layout
		if (!layout || layout.emojiMode || layout.emojiSearchMode || layout.controlMode
				|| layout.extendedSymbolMode || layout.layoutEditorMode
				|| layout.extraKeysMode || layout.clipboardMode || layout.numpadMode)
			return false
		var caption = String(key.caption || "")
		return caption.length === 1 && isLetterCharacter(caption)
	}

	function swipePointForKey(key) {
		var layout = keyboard.layout
		if (!layout || layout.width <= 0 || layout.height <= 0)
			return ""
		var caption = String(key.caption || "")
		if (caption.length !== 1)
			return ""
		var point = key.mapToItem(layout, key.width / 2, key.height / 2)
		var x = Math.max(0, Math.min(1, point.x / layout.width))
		var y = Math.max(0, Math.min(1, point.y / layout.height))
		return caption.charCodeAt(0) + ":" + x.toFixed(5) + ":" + y.toFixed(5)
	}

	function captureSwipeKey(key) {
		swipeReleaseTimer.stop()
		if (!swipeKeyAllowed(key)) {
			resetSwipePath()
			return
		}
		var caption = String(key.caption)
		if (caption === swipeLastKey) {
			suppressSwipePopper(key)
			return
		}
		var point = swipePointForKey(key)
		if (point === "") {
			resetSwipePath()
			return
		}
		var nextPath = swipePath.slice(0)
		nextPath.push(point)
		swipePath = nextPath
		swipeLastKey = caption
		suppressSwipePopper(key)
	}

	function suppressSwipePopper(key) {
		if (swipePath.length < 2 || !keyboard)
			return
		// KeyboardBase assigns every crossed letter to Popper.target before it
		// calls the input handler.  Clearing only that visual target stops the
		// platform's independent 500 ms accent timer; the active touch point
		// retains its pressed key and still completes the swipe normally.
		if (keyboard.lastPressedKey === key)
			keyboard.lastPressedKey = null
	}

	function collectSwipeGeometry(item, result, seen) {
		if (!item)
			return
		if (item.swipeTypingKey === true && item.visible && item.active) {
			var caption = String(item.caption || "")
			if (caption.length === 1 && isLetterCharacter(caption)) {
				var code = caption.charCodeAt(0)
				if (!seen[code]) {
					var point = swipePointForKey(item)
					if (point !== "") {
						seen[code] = true
						result.push(point)
					}
				}
			}
		}
		var children = item.children
		if (!children || children.length === undefined)
			return
		for (var i = 0; i < children.length; ++i)
			collectSwipeGeometry(children[i], result, seen)
	}

	function swipeGeometry() {
		var result = []
		collectSwipeGeometry(keyboard.layout, result, {})
		return result.join(";")
	}

	function resetSwipePath() {
		swipeReleaseTimer.stop()
		swipePath = []
		swipeLastKey = ""
	}

	function cancelSwipeSession() {
		swipeSessionSerial++
		swipeOutstanding = 0
		swipeReplacementActive = false
		swipePreviousWord = ""
		resetSwipePath()
	}

	function beginSpacebarGesture() {
		spacebarGestureGuard.stop()
		spacebarGestureActive = true
		cursorMoveMode = false
		cursorSelectionMode = false
		cancelSwipeSession()
		if (keyboard.closeSwipeActive !== undefined)
			keyboard.closeSwipeActive = false
	}

	function beginCursorMoveMode() {
		// Cursor mode may only be entered by a currently pressed Space gesture.
		// Never resurrect a gesture from a late QML Timer callback after release.
		if (!spacebarGestureActive) {
			cursorMoveMode = false
			return
		}
		cursorMoveMode = true
	}

	function beginCursorSelection() {
		if (spacebarGestureActive && cursorMoveMode)
			cursorSelectionMode = true
	}

	function endCursorSelection() {
		cursorSelectionMode = false
	}

	function endSpacebarGesture(delayed) {
		cancelSwipeSession()
		cursorMoveMode = false
		cursorSelectionMode = false
		if (delayed) {
			// KeyboardBase can deliver the release/click after the Space MouseArea.
			// Keep swallowing that tail briefly so no crossed letter is committed.
			spacebarGestureGuard.restart()
		} else {
			spacebarGestureGuard.stop()
			spacebarGestureActive = false
		}
	}

	Timer {
		id: spacebarGestureGuard
		interval: 120
		repeat: false
		onTriggered: {
			futoHandler.spacebarGestureActive = false
			futoHandler.cursorMoveMode = false
			futoHandler.cursorSelectionMode = false
		}
	}

	function finishSwipeGesture() {
		// Two-letter words such as "as" are valid gestures. Requiring three
		// crossed keys made them impossible regardless of dictionary quality.
		if (swipePath.length < 2 || !swipeKeyAllowed(pressedKey))
			return false
		var serializedPath = swipePath.join(";")
		var geometry = swipeGeometry()
		resetSwipePath()
		if (geometry === "")
			return false

		if (preedit !== "") {
			var typed = preedit
			learn(typed)
			commit(typed + " ")
		}
		var session = swipeSessionSerial
		var context = contextBeforeCursor()
		var previousWord = lastWord(context)
		var configuredLimit = Number(keyboardSettings.suggestionCount)
		var limit = isFinite(configuredLimit)
				? Math.max(3, Math.min(12, Math.round(configuredLimit))) : 12
		// AutoShift means that Sailfish is managing shift automatically; it
		// does not itself mean that this word should be capitalized.  isShifted
		// combines a real one-shot/caps-lock shift with the current autocaps
		// decision, and therefore matches what the user sees on the keys.
		var capitalize = keyboard.shiftState === ShiftState.LockedShift
				|| keyboard.shiftState === ShiftState.LatchedShift
				|| (keyboardSettings.autoCapitalizationEnabled && keyboard.isShifted)
		swipeOutstanding++
		helper.typedCall("SwipeSuggestions", [
			{ "type": "s", "value": enabledLanguages() },
			{ "type": "s", "value": serializedPath },
			{ "type": "s", "value": geometry },
			{ "type": "s", "value": context },
			{ "type": "i", "value": limit },
			{ "type": "b", "value": capitalize }
		], function(resultJson) {
			futoHandler.swipeOutstanding = Math.max(0, futoHandler.swipeOutstanding - 1)
			if (session !== futoHandler.swipeSessionSerial || !futoHandler.active
					|| futoHandler.passwordField)
				return
			var result
			try {
				result = JSON.parse(String(resultJson))
			} catch (error) {
				result = { "suggestions": [], "language": "" }
			}
			var suggestions = futoHandler.nonEmptySuggestions(result.suggestions || [])
			if (suggestions.length < 1)
				return
			var word = suggestions[0]
			if (keyboardSettings.forcedAppSupportKeyEvents) {
				helper.typedCall("InjectAndroidSwipe", [
					{ "type": "s", "value": word }
				], function(inserted) {
					if (!inserted || session !== futoHandler.swipeSessionSerial
							|| !futoHandler.active || futoHandler.passwordField)
						return
					futoHandler.learnWithPrevious(previousWord, word)
					futoHandler.candidateSpaceIndex = -1
					futoHandler.swipeReplacementActive = false
					futoHandler.swipePreviousWord = ""
					futoHandler.clearEditingWord()
					futoHandler.correctionQuery = ""
					futoHandler.correctionCandidate = ""
					futoHandler.nextWordMode = false
					predictionModel.clear()
					if (result.language)
						futoHandler.detectedLanguage = String(result.language)
					if (keyboard.shiftState !== ShiftState.LockedShift) {
						keyboard.autocaps = false
						keyboard.shiftState = ShiftState.AutoShift
					}
					futoHandler.suggestionsUpdated()
				}, function() {})
				return
			}
			var cursor = MInputMethodQuick.cursorPosition
			MInputMethodQuick.sendCommit(word + " ")
			futoHandler.armCommittedSpace(cursor + word.length + 1)
			futoHandler.swipePreviousWord = previousWord
			futoHandler.learnWithPrevious(previousWord, word)
			futoHandler.candidateSpaceIndex = cursor + word.length + 1
			futoHandler.editingWord = word
			futoHandler.editingWordStart = cursor
			futoHandler.editingWordLength = word.length
			futoHandler.swipeReplacementActive = true
			futoHandler.correctionQuery = ""
			futoHandler.correctionCandidate = ""
			futoHandler.nextWordMode = false
			futoHandler.replacePredictionSuggestions(suggestions)
			if (result.language)
				futoHandler.detectedLanguage = String(result.language)
			if (keyboard.shiftState !== ShiftState.LockedShift) {
				// A completed word followed by a space is not a sentence start.
				// Keeping autocaps true here made every subsequent swipe uppercase.
				keyboard.autocaps = false
				keyboard.shiftState = ShiftState.AutoShift
			}
			futoHandler.suggestionsUpdated()
		}, function() {
			futoHandler.swipeOutstanding = Math.max(0, futoHandler.swipeOutstanding - 1)
		})
		return true
	}

    function clearCommittedSpace() {
        committedSpaceArmed = false
        committedSpaceAllowsPeriod = false
        committedSpaceTimestamp = 0
        committedSpaceExpectedCursor = -1
    }

    function armCommittedSpace(expectedCursor, allowPeriod) {
        committedSpaceArmed = true
        committedSpaceAllowsPeriod = allowPeriod === undefined ? true : !!allowPeriod
        committedSpaceTimestamp = Date.now()
        committedSpaceExpectedCursor = Number(expectedCursor)
    }

    function committedSpaceIsCurrent() {
        if (!committedSpaceArmed
                || Date.now() - committedSpaceTimestamp > 1200)
            return false
        // Native and Android editors can publish their cursor update one event
        // late. Trust the space we just committed, but reject it once an
        // authoritative cursor position says the user moved elsewhere.
        return committedSpaceExpectedCursor < 0
                || !MInputMethodQuick.surroundingTextValid
                || MInputMethodQuick.cursorPosition === committedSpaceExpectedCursor
    }

    function spaceImmediatelyBeforeCursor() {
        if (committedSpaceIsCurrent())
            return true
        return MInputMethodQuick.surroundingTextValid
                && MInputMethodQuick.cursorPosition > 0
                && MInputMethodQuick.surroundingText.charAt(
                    MInputMethodQuick.cursorPosition - 1) === " "
    }

    function smartPunctuationField() {
        return !passwordField && !urlField && !immediateCommitField
    }

    function clearUndoCorrection() {
        undoCorrectionAvailable = false
        undoOriginalWord = ""
        undoReplacementWord = ""
        undoCursorPosition = -1
    }

    function undoLastCorrection() {
        if (!undoCorrectionAvailable
                || !MInputMethodQuick.surroundingTextValid
                || MInputMethodQuick.hasSelection
                || MInputMethodQuick.cursorPosition !== undoCursorPosition) {
            clearUndoCorrection()
            return false
        }

        var committed = undoReplacementWord + " "
        var start = MInputMethodQuick.cursorPosition - committed.length
        if (start < 0 || MInputMethodQuick.surroundingText.substring(
                    start, MInputMethodQuick.cursorPosition) !== committed) {
            clearUndoCorrection()
            return false
        }

        var original = undoOriginalWord
        var replacementLength = undoReplacementWord.length
        MInputMethodQuick.sendKey(Qt.Key_Backspace, 0, "\b", Maliit.KeyClick)
        MInputMethodQuick.sendPreedit(original, undefined, -replacementLength, replacementLength)
        preedit = original
        clearUndoCorrection()
        requestSuggestionsSoon()
        if (keyboard.shiftState !== ShiftState.LockedShift)
            keyboard.shiftState = ShiftState.NoShift
        return true
    }

    function isLetterCharacter(character) {
        character = String(character || "")
        if (character.length !== 1)
            return false

		// KeyboardSupport.isLetter() was added after Sailfish OS 5.1. Prefer the
		// platform implementation where available, but keep the input handler
		// usable on older releases instead of throwing during every key click.
		if (KeyboardSupport
		        && typeof KeyboardSupport.isLetter === "function")
			return KeyboardSupport.isLetter(character)

		// Case conversion covers all Latin and Cyrillic layouts. Arabic and
		// Hebrew are uncased, so include their letter blocks explicitly while
		// excluding the punctuation and digit ranges in those scripts.
		if (character.toLocaleUpperCase() !== character.toLocaleLowerCase())
			return true
		var code = character.charCodeAt(0)
		return (code >= 0x05d0 && code <= 0x05ea)
		        || (code >= 0x05ef && code <= 0x05f2)
		        || (code >= 0x0620 && code <= 0x063f)
		        || (code >= 0x0641 && code <= 0x064a)
		        || (code >= 0x066e && code <= 0x066f)
		        || (code >= 0x0671 && code <= 0x06d3)
		        || code === 0x06d5
		        || (code >= 0x06ee && code <= 0x06ef)
		        || (code >= 0x06fa && code <= 0x06fc)
		        || code === 0x06ff
		        || (code >= 0x0750 && code <= 0x077f)
		        || (code >= 0x08a0 && code <= 0x08c7)
		        || (code >= 0xfb1d && code <= 0xfdff)
		        || (code >= 0xfe70 && code <= 0xfefc)
    }

    function isInputCharacter(character) {
        return isLetterCharacter(character) || "'-’".indexOf(character) >= 0
    }

    function sendCursorSteps(horizontalSteps, verticalSteps) {
		var modifiers = cursorSelectionMode ? Qt.ShiftModifier : 0
        horizontalSteps = Math.round(Number(horizontalSteps || 0))
        verticalSteps = Math.round(Number(verticalSteps || 0))
        var horizontalKey = horizontalSteps < 0 ? Qt.Key_Left : Qt.Key_Right
        for (var i = 0; i < Math.abs(horizontalSteps); ++i)
			MInputMethodQuick.sendKey(horizontalKey, modifiers, "", Maliit.KeyClick)
        var verticalKey = verticalSteps < 0 ? Qt.Key_Up : Qt.Key_Down
        for (var j = 0; j < Math.abs(verticalSteps); ++j)
			MInputMethodQuick.sendKey(verticalKey, modifiers, "", Maliit.KeyClick)
    }

    function moveCursor(steps) {
        moveCursor2D(steps, 0)
    }

    function moveCursor2D(horizontalSteps, verticalSteps) {
        horizontalSteps = Math.max(-24, Math.min(24,
                                   Math.round(Number(horizontalSteps))))
        verticalSteps = Math.max(-12, Math.min(12,
                                 Math.round(Number(verticalSteps))))
        if (!isFinite(horizontalSteps))
            horizontalSteps = 0
        if (!isFinite(verticalSteps))
            verticalSteps = 0
        if (horizontalSteps === 0 && verticalSteps === 0)
            return
        if (preedit !== "") {
            learn(preedit)
            commit(preedit)
        }
        // URL editors, especially browser address bars, apply a committed
        // preedit asynchronously. Sending Left/Right in the same call loses
        // those keys. Queue them for the next event-loop turn so cursor
        // control works there exactly as it does in ordinary text fields.
        if (urlField) {
			pendingCursorHorizontalSteps = Math.max(-48, Math.min(48,
			        pendingCursorHorizontalSteps + horizontalSteps))
			pendingCursorVerticalSteps = Math.max(-24, Math.min(24,
			        pendingCursorVerticalSteps + verticalSteps))
            cursorMoveTimer.restart()
        } else {
            sendCursorSteps(horizontalSteps, verticalSteps)
        }
        predictionModel.clear()
        nextWordMode = false
        suggestionsUpdated()
        editorContextTimer.restart()
    }

    Timer {
        id: cursorMoveTimer
        interval: 1
        repeat: false
        onTriggered: {
            var horizontalSteps = futoHandler.pendingCursorHorizontalSteps
            var verticalSteps = futoHandler.pendingCursorVerticalSteps
			futoHandler.pendingCursorHorizontalSteps = 0
			futoHandler.pendingCursorVerticalSteps = 0
			if (horizontalSteps !== 0 || verticalSteps !== 0)
				futoHandler.sendCursorSteps(horizontalSteps, verticalSteps)
        }
    }

    function deletePreviousWord() {
        nextPredictionTimer.stop()
        predictionTimer.stop()
        requestSerial++
        nextWordMode = false
        if (preedit !== "") {
            preedit = ""
            MInputMethodQuick.sendPreedit("")
            predictionModel.clear()
            suggestionsUpdated()
            return
        }
        if (!MInputMethodQuick.surroundingTextValid
                || MInputMethodQuick.cursorPosition <= 0) {
            MInputMethodQuick.sendKey(Qt.Key_Backspace, 0, "\b", Maliit.KeyClick)
            return
        }
        var position = MInputMethodQuick.cursorPosition
        var text = MInputMethodQuick.surroundingText.substring(0, position)
        var start = text.length
        while (start > 0 && !isInputCharacter(text.charAt(start - 1)))
            start--
        while (start > 0 && isInputCharacter(text.charAt(start - 1)))
            start--
        var count = text.length - start
        if (count > 0)
            MInputMethodQuick.sendCommit("", -count, count)
        predictionModel.clear()
        suggestionsUpdated()
    }

    function reset() {
		cancelSwipeSession()
        clearCommittedSpace()
        requestSerial++
        urlRequestSerial++
        predictionTimer.stop()
        nextPredictionTimer.stop()
        urlSuggestionTimer.stop()
        predictionModel.clear()
        urlSuggestionResultsActive = false
        urlSuggestionFallbackActive = false
        learnedUrlSuggestions = []
		refreshApplicationSuggestions()
        preedit = ""
        nextWordMode = false
        nextContextOverride = ""
        correctionQuery = ""
        correctionCandidate = ""
        clearEditingWord()
        clearUndoCorrection()
    }

    function commit(text) {
        clearCommittedSpace()
        requestSerial++
        predictionTimer.stop()
        nextPredictionTimer.stop()
        MInputMethodQuick.sendCommit(text)
        preedit = ""
        nextWordMode = false
        nextContextOverride = ""
        correctionQuery = ""
        correctionCandidate = ""
        clearEditingWord()
        clearUndoCorrection()
        predictionModel.clear()
        urlSuggestionResultsActive = false
        urlSuggestionFallbackActive = false
        suggestionsUpdated()
    }
}
