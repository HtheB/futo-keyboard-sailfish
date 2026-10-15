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
             && LetterLayouts.imeHint(layoutIndex) !== "12key"
             && !targetLayout.emojiMode && !targetLayout.extendedSymbolMode
             && !targetLayout.extraKeysMode && !targetLayout.layoutEditorMode
             && !targetLayout.clipboardMode && !targetLayout.credentialMode
             && !targetLayout.numpadMode
             && !(targetLayout.topRowSymbolPage !== undefined
                  && targetLayout.topRowSymbolPage)
             && !(targetLayout.topRowSecondSymbolPage !== undefined
                  && targetLayout.topRowSecondSymbolPage)
    separateButtonSizes: (targetLayout && targetLayout.thumbMode)
                         || LetterLayouts.usesIndependentSizing(layoutIndex)
    splitIndex: Math.ceil(keyCount / 2)

    // Use one unit for both thumb clusters and every letter row. The stock
    // row still distributes the unused space and preserves staggered rows.
    function maximumBasicButtonWidth(shareableWidth) {
        if (targetLayout && targetLayout.thumbLetterKeyWidth > 0)
            return targetLayout.thumbLetterKeyWidth
        if (avoidanceWidth > 0) {
            var split = splitIndex > 0 ? splitIndex : Math.floor(children.length / 2)
            var halfWidth = (shareableWidth - avoidanceWidth) / 2
            return Math.min(_maximumButtonWidthPart(halfWidth, 0, split),
                            _maximumButtonWidthPart(halfWidth, split, children.length))
        }
        return _maximumButtonWidthPart(shareableWidth, 0, children.length)
    }

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
