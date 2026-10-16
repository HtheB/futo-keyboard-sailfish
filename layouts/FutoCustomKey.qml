import QtQuick 2.6
import Sailfish.Silica 1.0
import com.jolla.keyboard 1.0
import "FutoCustomLayouts.js" as Custom

FutoCharacterKey {
    id: customKey
    property Item targetLayout
    property var definition: Custom.key("spacer")
    property bool reservedQuickSettings: false
    readonly property string customAction: definition.action
    readonly property bool customDeadKey: !!definition.dead && popupHighlightedOutput === ""
    readonly property var customDefinition: definition
    property bool heldForSettings: false
    caption: Custom.keyLabel(definition)
    captionShifted: definition.action === "text" && (!definition.label || definition.label === definition.output)
                    ? definition.shifted || definition.output.toUpperCase() : caption
    keyOutput: definition.action === "text" ? definition.output : definition.action === "space" ? " " : ""
    keyOutputShifted: definition.action === "text" ? definition.shifted || definition.output.toUpperCase() : keyOutput
    key: definition.action === "backspace" ? Qt.Key_Backspace : definition.action === "enter" ? Qt.Key_Return
         : definition.action === "space" ? Qt.Key_Space : definition.action === "shift" ? Qt.Key_Shift : Qt.Key_unknown
    keyType: definition.action === "shift" ? KeyType.ShiftKey
             : definition.action === "backspace" ? KeyType.BackspaceKey
             : KeyType.CharacterKey
    readonly property string swipeCharacter: definition.output
    swipeTypingKey: definition.action === "text" && definition.output.length === 1 && !definition.dead && targetLayout.customPageIsText
    popupPreviewEligible: definition.action === "text" && !reservedQuickSettings
    repeat: definition.action === "backspace" && !reservedQuickSettings
    implicitSeparator: false
    readonly property int modifierState: targetLayout.handler && targetLayout.handler.desktopModifierState
            ? targetLayout.handler.desktopModifierState(customAction) : 0
    enabled: definition.action !== "spacer" || reservedQuickSettings
    symView: ""; symView2: ""
    exactAlternativeMode: true
    exactPopupSet: true
    plainTextKeyLabel: true
    exactPopupDefaultIndex: definition.defaultMore
    explicitPopupDefault: reservedQuickSettings || !definition.more.length ? "" : definition.more[definition.defaultMore]
    letterAccents: ""; letterAccentsShifted: ""
    // The panel owns custom cards so Space, Enter and all other actions can
    // use exactly the same per-key appearance, independently of their type.
    separatedKeyCardEligible: false
    secondarySymbol: reservedQuickSettings || definition.action === "spacer" ? "" : definition.more.length ? definition.more[definition.defaultMore] : ""
    secondaryHintCaption: reservedQuickSettings ? "⚙" : secondarySymbol
    popupAlways: !reservedQuickSettings && definition.more.length > 0
    function symbolPopupChoices(base) { return "" }
    function symbolPopupDefault(base) { return secondarySymbol }
    function activeStructuredChoices() {
        if (reservedQuickSettings || !definition.more.length) return []
        var result = []
        for (var i = 0; i < definition.more.length; ++i)
            result.push({caption: definition.more[i], output: definition.more[i]})
        return result
    }
    // A single alternative still needs one placeholder to arm the stock
    // popper. Its real output is supplied by the selected default.
    function hasPopupChoices() { return !reservedQuickSettings && definition.more.length > 0 }
    function popupChoices() {
        if (popupArmed || reservedQuickSettings) return ""
        return definition.more.length ? placeholderAccents(Math.max(0, definition.more.length - 1)) : ""
    }
    Rectangle {
        anchors.fill: parent; anchors.margins: Theme.paddingSmall / 2
        visible: customKey.modifierState > 0 || customKey.definition.dead && customKey.targetLayout && customKey.targetLayout.handler
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
        if (reservedQuickSettings) {
            cancelSecondaryPopup()
            if (pressed && !gesturePreviewSuppressed) { heldForSettings = false; settingsHold.restart() }
            else settingsHold.stop()
        } else if (pressed && !gesturePreviewSuppressed) armSecondaryPopup()
        else cancelSecondaryPopup()
    }
}
