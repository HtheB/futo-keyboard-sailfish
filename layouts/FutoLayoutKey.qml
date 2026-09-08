/* Dynamic key cell for layouts generated from FUTO's canonical catalogue. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import "FutoLetterLayouts.js" as LetterLayouts

Item {
    id: cell

    property Item targetLayout
    property int layoutIndex
    property int rowIndex
    property int columnIndex
    property var keyData: LetterLayouts.key(layoutIndex, rowIndex, columnIndex)
    readonly property string keyKind: String(keyData.kind || "gap")
    property bool active: keyKind !== "gap"
            && (keyKind !== "shift" || !targetLayout
                || !targetLayout.usesLocalizedDigits
                || targetLayout.attributes.inSymView)
    property bool fixedWidth: keyKind !== "character" && keyKind !== "gap"
    // KeyboardRow identifies ordinary keys through this property on its
    // direct children.  The real CharacterKey is loaded one level below, so
    // mirror the row-layout contract on this wrapper as well.
    property string symView: keyKind === "character"
            ? LetterLayouts.secondarySymbolForLayout(
                  layoutIndex, rowIndex, columnIndex) : ""
    property bool implicitSeparator: true
    property real leftPadding: 0
    property real rightPadding: 0

    implicitWidth: keyKind === "shift" && targetLayout
                   ? targetLayout.shiftKeyWidth
                   : keyKind === "delete" && targetLayout
                     ? targetLayout.shiftKeyWidth : 0

    Loader {
        anchors.fill: parent
        sourceComponent: cell.keyKind === "character" ? characterComponent
                         : cell.keyKind === "shift" ? shiftComponent
                         : cell.keyKind === "delete" ? deleteComponent : null
        asynchronous: false
    }

    Component {
        id: characterComponent
        FutoCharacterKey {
            active: cell.active
            leftPadding: cell.leftPadding
            rightPadding: cell.rightPadding
            caption: LetterLayouts.caption(cell.layoutIndex, cell.rowIndex,
                                           cell.columnIndex, false)
            captionShifted: LetterLayouts.caption(cell.layoutIndex, cell.rowIndex,
                                                  cell.columnIndex, true)
            keyOutput: LetterLayouts.output(cell.layoutIndex, cell.rowIndex,
                                            cell.columnIndex, false)
            keyOutputShifted: LetterLayouts.output(cell.layoutIndex, cell.rowIndex,
                                                   cell.columnIndex, true)
            preferredFontFamily: targetLayout
                    ? targetLayout.keyFontFamilyForLayout(cell.layoutIndex) : ""
            specialArabicFontFamily: targetLayout
                    ? targetLayout.specialArabicSymbolFontFamily
                    : "Noto Naskh Arabic"
            androidRiyalFontFamily: targetLayout
                    ? targetLayout.androidRiyalSymbolFontFamily
                    : "FUTO Android Riyal"
            secondarySymbol: cell.symView
            symView: secondarySymbol
            symView2: targetLayout
                      ? targetLayout.secondSymbolAt(cell.rowIndex, cell.columnIndex) : ""
            exactAlternativeMode: LetterLayouts.hasExactAlternatives(cell.layoutIndex)
            letterAlternativeChoices: targetLayout
                    ? LetterLayouts.alternativeChoices(
                          cell.layoutIndex, cell.rowIndex, cell.columnIndex,
                          targetLayout.currentLayoutLanguageCodes, false) : []
            letterAlternativeChoicesShifted: targetLayout
                    ? LetterLayouts.alternativeChoices(
                          cell.layoutIndex, cell.rowIndex, cell.columnIndex,
                          targetLayout.currentLayoutLanguageCodes, true) : []
        }
    }

    Component {
        id: shiftComponent
        FutoShiftKey {
            active: cell.active
            leftPadding: cell.leftPadding
            rightPadding: cell.rightPadding
            targetLayout: cell.targetLayout
        }
    }

    Component {
        id: deleteComponent
        FutoBackspaceKey {
            active: cell.active
            leftPadding: cell.leftPadding
            rightPadding: cell.rightPadding
        }
    }
}
