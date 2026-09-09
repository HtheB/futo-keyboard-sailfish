/* Period key which shows the marks it holds and offers different ones per page.
 *
 * Beside the letters it offers the sentence marks and the comma, highlighting
 * the period so a press without moving still types one. On the symbol page it
 * offers the bullet and the ellipsis instead, highlighting the ellipsis, which
 * the stock key cannot do: its popup always highlights the key's own text.
 */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import com.jolla.keyboard 1.0
import ".."

FutoCharacterKey {
    id: periodKey

    caption: "."
    captionShifted: "."
    symView: "."
    symView2: "."
    letterAccents: "!,.?"
    letterAccentsShifted: "!,.?"
    // Already among the alternates, so it is highlighted rather than inserted.
    secondarySymbol: "."
    secondaryHintEligible: false
    // Comma, Space and Enter carry no separated-key card, so neither does this.
    separatedKeyCardEligible: false
    popupAlways: true
    implicitWidth: punctuationKeyWidth
    fixedWidth: !splitActive
    separator: SeparatorState.HiddenSeparator

    // The symbol table answers for every "." on the symbol page; beside the
    // letters this key answers for itself instead.
    function symbolPopupChoices(base) {
        return attributes.inSymView ? "•…" : ""
    }

    function symbolPopupDefault(base) {
        return attributes.inSymView ? "…" : ""
    }

    ConfigurationGroup {
        id: periodVisualSettings
        path: "/sailfish/text_input/futo_keyboard"
        property bool secondarySymbolsEnabled: true
    }

    // Matches the hint the letter keys draw, so the row reads as one piece.
    Label {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Math.max(1, Theme.paddingSmall / 4)
        anchors.rightMargin: Theme.paddingMedium
        color: parent.palette.primaryColor
        font.pixelSize: Math.max(Theme.fontSizeTiny,
                                 Math.round(parent.pixelSize * 0.43))
        text: ",!?"
        visible: periodVisualSettings.secondarySymbolsEnabled
                 && !attributes.inSymView
        opacity: 0.72
    }
}
