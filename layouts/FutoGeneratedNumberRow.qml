/* Explicit number row from FUTO layouts such as Gurmukhi and Marathi. */
import QtQuick 2.0
import com.jolla.keyboard 1.0
import ".."
import "FutoLetterLayouts.js" as LetterLayouts

KeyboardRow {
    id: row
    property Item targetLayout
    property int layoutIndex
    readonly property int keyCount: LetterLayouts.numberRowLength(layoutIndex)

    followRowHeight: false
    height: targetLayout ? targetLayout.keyHeight : 0
    opacity: targetLayout && targetLayout.cursorMoveMode ? 0 : 1
    separateButtonSizes: true
    splitIndex: Math.ceil(keyCount / 2)

    FutoNumberKey { keyData: LetterLayouts.numberKey(row.layoutIndex, 0) }
    FutoNumberKey { keyData: LetterLayouts.numberKey(row.layoutIndex, 1) }
    FutoNumberKey { keyData: LetterLayouts.numberKey(row.layoutIndex, 2) }
    FutoNumberKey { keyData: LetterLayouts.numberKey(row.layoutIndex, 3) }
    FutoNumberKey { keyData: LetterLayouts.numberKey(row.layoutIndex, 4) }
    FutoNumberKey { keyData: LetterLayouts.numberKey(row.layoutIndex, 5) }
    FutoNumberKey { keyData: LetterLayouts.numberKey(row.layoutIndex, 6) }
    FutoNumberKey { keyData: LetterLayouts.numberKey(row.layoutIndex, 7) }
    FutoNumberKey { keyData: LetterLayouts.numberKey(row.layoutIndex, 8) }
    FutoNumberKey { keyData: LetterLayouts.numberKey(row.layoutIndex, 9) }
    FutoNumberKey { keyData: LetterLayouts.numberKey(row.layoutIndex, 10) }
    FutoNumberKey { keyData: LetterLayouts.numberKey(row.layoutIndex, 11) }
}
