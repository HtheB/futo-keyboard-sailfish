/* Period key which shows the marks it holds and offers the comma among them.
 *
 * It extends the stock PeriodKey rather than CharacterKey so the punctuation
 * width, split handling and separator behaviour stay exactly as Sailfish
 * defines them; only the alternates and the printed hint are ours.
 */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import ".."

PeriodKey {
    accents: "!,.?"
    accentsShifted: "!,.?"

    ConfigurationGroup {
        id: visualSettings
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
        visible: visualSettings.secondarySymbolsEnabled
                 && !attributes.inSymView
        opacity: 0.72
    }
}
