import QtQuick 2.6
import Sailfish.Silica 1.0
import com.jolla.keyboard 1.0
import "FutoCustomLayouts.js" as Custom

FutoCharacterKey {
    id: customKey
    property Item targetLayout
    property var definition: Custom.key("spacer")
    property bool reservedQuickSettings: false
    readonly property var alternatives: reservedQuickSettings ? [] : Custom.alternatives(definition)
    readonly property string customAction: popupHighlightedOutput !== "" ? "text" : definition.action
    readonly property bool customDeadKey: !!definition.dead && popupHighlightedOutput === ""
    readonly property var customDefinition: definition
    readonly property bool customLiteralText: customAction === "text" && !Custom.textValid(text, 1)
    property bool heldForSettings: false
    property int charactersWhenPressed: 0
    property bool quickPicking: false
    caption: definition.action === "hide" && !definition.label ? "" : definition.action === "shift" && !definition.label ? (attributes.isShiftLocked ? "⇪" : "⇧") : Custom.keyLabel(definition)
    captionShifted: definition.action === "text" && (!definition.label || definition.label === definition.output)
                    ? Custom.compactLabel(Custom.shiftedOutput(definition), 12) : caption
    keyOutput: customAction === "text" ? definition.output : customAction === "space" ? " " : ""
    keyOutputShifted: customAction === "text" ? Custom.shiftedOutput(definition) : keyOutput
    keyText: popupHighlightedText === "\uF8FEhide" ? "" : popupHighlightedText !== "" ? popupHighlightedText : baseKeyText()
    key: customAction === "backspace" ? Qt.Key_Backspace : customAction === "enter" ? Qt.Key_Return
         : customAction === "space" ? Qt.Key_Space : customAction === "shift" ? Qt.Key_Shift : Qt.Key_unknown
    keyType: customAction === "shift" ? KeyType.ShiftKey
             : customAction === "backspace" ? KeyType.BackspaceKey
             : KeyType.CharacterKey
    readonly property string swipeCharacter: definition.output
    swipeTypingKey: definition.action === "text" && definition.output.length === 1 && !definition.dead && targetLayout.customPageIsText
    popupPreviewEligible: definition.action === "text" && !reservedQuickSettings
    repeat: definition.action === "backspace" && !reservedQuickSettings && alternatives.length === 0
    implicitSeparator: false
    readonly property int modifierState: targetLayout.handler && targetLayout.handler.desktopModifierState
            ? targetLayout.handler.desktopModifierState(customAction) : 0
    enabled: definition.action !== "spacer" || reservedQuickSettings
    symView: ""; symView2: ""
    exactAlternativeMode: true
    exactPopupSet: true
    plainTextKeyLabel: true
    fitPopupLabels: true
    exactPopupDefaultIndex: Custom.alternativeIndex(definition)
    explicitPopupDefault: alternatives.length ? Custom.alternativeOutput(alternatives[exactPopupDefaultIndex], exactPopupDefaultIndex) : ""
    explicitPopupDefaultCaption: alternatives.length ? Custom.alternativeCaption(alternatives[exactPopupDefaultIndex]) : ""
    letterAccents: ""; letterAccentsShifted: ""
    // The panel owns custom cards so Space, Enter and all other actions can
    // use exactly the same per-key appearance, independently of their type.
    separatedKeyCardEligible: false
    secondarySymbol: explicitPopupDefault
    secondaryHintCaption: reservedQuickSettings ? "⚙" : explicitPopupDefaultCaption === "\uF8FEhide" ? "" : explicitPopupDefaultCaption
    popupAlways: alternatives.length > 0
    function symbolPopupChoices(base) { return "" }
    function symbolPopupDefault(base) { return secondarySymbol }
    function activeStructuredChoices() {
        if (!alternatives.length) return []
        var result = []
        for (var i = 0; i < alternatives.length; ++i)
            result.push({caption: Custom.alternativeCaption(alternatives[i]), output: Custom.alternativeOutput(alternatives[i], i)})
        return result
    }
    function choiceForPopupOutput(output) {
        for (var i = 0; i < alternatives.length; ++i)
            if (Custom.alternativeOutput(alternatives[i], i) === output)
                return alternatives[i]
        return null
    }
    onSecondaryPopupOpening: if (targetLayout.handler) targetLayout.handler.customPopupSource = customKey
    FutoHideKeyboardIcon {
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.paddingMedium, parent.height * 0.65); height: width
        color: customKey.palette.primaryColor
        visible: customKey.definition.action === "hide" && !customKey.definition.label || customKey.popupHighlightedText === "\uF8FEhide"
    }
    FutoHideKeyboardIcon {
        anchors.top: parent.top; anchors.right: parent.right; anchors.rightMargin: Theme.paddingMedium
        width: customKey.pixelSize * 0.65; height: width
        color: customKey.palette.primaryColor
        visible: !customKey.reservedQuickSettings && customKey.explicitPopupDefaultCaption === "\uF8FEhide"
    }
    // A single alternative still needs one placeholder to arm the stock
    // popper. Its real output is supplied by the selected default.
    function hasPopupChoices() { return alternatives.length > 0 }
    function popupChoices() {
        if (popupArmed || reservedQuickSettings) return ""
        return alternatives.length ? placeholderAccents(Math.max(0, alternatives.length - 1)) : ""
    }
    Rectangle {
        anchors.fill: parent; anchors.margins: Theme.paddingSmall / 2
        visible: customKey.definition.action === "shift" && attributes.isShifted || customKey.modifierState > 0 || customKey.definition.dead && customKey.targetLayout && customKey.targetLayout.handler
                 && customKey.targetLayout.handler.customPendingDeadKey === customKey.definition.output
        color: customKey.modifierState > 0 ? Theme.rgba(Theme.highlightColor, customKey.modifierState === 2 ? 0.35 : 0.15) : "transparent"
        border.color: Theme.highlightColor; border.width: 2; radius: Theme.paddingSmall
    }
    Timer {
        id: settingsHold
        interval: 520
        onTriggered: if (customKey.pressed && !customKey.gesturePreviewSuppressed) { customKey.heldForSettings = true; customKey.targetLayout.showControlStrip() }
    }
    onPressedChanged: {
        if (definition.action === "shift") {
            if (pressed) {
                keyboard.cancelGesture()
                quickPicking = !keyboard.isShifted && keyboard.lastInitialKey === customKey
                if (quickPicking) keyboard.shiftState = ShiftState.LatchedShift
                charactersWhenPressed = keyboard.characterKeyCounter
            }
            keyboard.shiftKeyPressed = pressed
            keyboard.updatePopper()
        }
        if (reservedQuickSettings) {
            cancelSecondaryPopup()
            if (pressed && !gesturePreviewSuppressed) { heldForSettings = false; settingsHold.restart() }
            else settingsHold.stop()
        } else if (pressed && !gesturePreviewSuppressed) armSecondaryPopup()
        else cancelSecondaryPopup()
    }
    onClicked: if (customAction === "shift" && !heldForSettings) {
        if (keyboard.characterKeyCounter > charactersWhenPressed)
            keyboard.shiftState = ShiftState.NoShift
        else if (!quickPicking)
            keyboard.cycleShift()
    }
}
