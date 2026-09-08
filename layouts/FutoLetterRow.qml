/* A fixed-capacity row whose active cells come from a generated FUTO layout. */
import QtQuick 2.0
import com.jolla.keyboard 1.0
import ".."
import "FutoLetterLayouts.js" as LetterLayouts

KeyboardRow {
    id: row

    property Item targetLayout
    property int layoutIndex
    property int rowIndex
    readonly property int keyCount: LetterLayouts.rowLength(layoutIndex, rowIndex)

    opacity: targetLayout && targetLayout.cursorMoveMode ? 0 : 1
    visible: targetLayout && rowIndex < LetterLayouts.rowCount(layoutIndex)
             && !targetLayout.emojiMode && !targetLayout.extendedSymbolMode
             && !targetLayout.extraKeysMode && !targetLayout.layoutEditorMode
             && !targetLayout.clipboardMode && !targetLayout.credentialMode
             && !targetLayout.numpadMode
             && !(targetLayout.qwertySymbolPage !== undefined
                  && targetLayout.qwertySymbolPage)
             && !(targetLayout.qwertySecondSymbolPage !== undefined
                  && targetLayout.qwertySecondSymbolPage)
    separateButtonSizes: LetterLayouts.usesIndependentSizing(layoutIndex)
    splitIndex: Math.ceil(keyCount / 2)

    FutoLayoutKey { targetLayout: row.targetLayout; layoutIndex: row.layoutIndex; rowIndex: row.rowIndex; columnIndex: 0 }
    FutoLayoutKey { targetLayout: row.targetLayout; layoutIndex: row.layoutIndex; rowIndex: row.rowIndex; columnIndex: 1 }
    FutoLayoutKey { targetLayout: row.targetLayout; layoutIndex: row.layoutIndex; rowIndex: row.rowIndex; columnIndex: 2 }
    FutoLayoutKey { targetLayout: row.targetLayout; layoutIndex: row.layoutIndex; rowIndex: row.rowIndex; columnIndex: 3 }
    FutoLayoutKey { targetLayout: row.targetLayout; layoutIndex: row.layoutIndex; rowIndex: row.rowIndex; columnIndex: 4 }
    FutoLayoutKey { targetLayout: row.targetLayout; layoutIndex: row.layoutIndex; rowIndex: row.rowIndex; columnIndex: 5 }
    FutoLayoutKey { targetLayout: row.targetLayout; layoutIndex: row.layoutIndex; rowIndex: row.rowIndex; columnIndex: 6 }
    FutoLayoutKey { targetLayout: row.targetLayout; layoutIndex: row.layoutIndex; rowIndex: row.rowIndex; columnIndex: 7 }
    FutoLayoutKey { targetLayout: row.targetLayout; layoutIndex: row.layoutIndex; rowIndex: row.rowIndex; columnIndex: 8 }
    FutoLayoutKey { targetLayout: row.targetLayout; layoutIndex: row.layoutIndex; rowIndex: row.rowIndex; columnIndex: 9 }
    FutoLayoutKey { targetLayout: row.targetLayout; layoutIndex: row.layoutIndex; rowIndex: row.rowIndex; columnIndex: 10 }
    FutoLayoutKey { targetLayout: row.targetLayout; layoutIndex: row.layoutIndex; rowIndex: row.rowIndex; columnIndex: 11 }
}
