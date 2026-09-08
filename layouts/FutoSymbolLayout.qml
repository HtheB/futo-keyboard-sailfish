/* The two symbol rows of the QWERTY 123 page.
 *
 * The page cannot be drawn by lending the letter rows their secondary symbols:
 * it holds ten symbols where the home row has nine keys and eight where the
 * bottom row has seven, so it carries its own arrangement. The digits above it
 * stay the number row, and the space bar row below it is the ordinary one.
 */
import QtQuick 2.0

Column {
    id: symbols

    property Item targetLayout
    property bool followRowHeight: false
    height: targetLayout ? 2 * targetLayout.keyHeight : 0
    opacity: targetLayout && targetLayout.cursorMoveMode ? 0 : 1
    spacing: 0

    function mark(value) {
        return targetLayout && targetLayout.punctuationForLayout
                ? targetLayout.punctuationForLayout(value) : String(value)
    }

    FutoNumpadRow {
        width: parent.width
        height: symbols.targetLayout ? symbols.targetLayout.keyHeight : 0
        targetLayout: symbols.targetLayout
        totalSpans: 10
        cells: [
            { "text": "@" }, { "text": "#" }, { "text": "€" }, { "text": "&" },
            { "text": "_" }, { "text": "-" }, { "text": "(" }, { "text": ")" },
            { "text": "=" }, { "text": symbols.mark("%") }
        ]
    }

    FutoNumpadRow {
        width: parent.width
        height: symbols.targetLayout ? symbols.targetLayout.keyHeight : 0
        targetLayout: symbols.targetLayout
        totalSpans: 10
        cells: [
            { "text": "{&=", "action": "extendedSymbols" },
            { "text": "\"" }, { "text": "*" }, { "text": "'" },
            { "text": symbols.mark(":") }, { "text": "/" },
            { "text": "!" }, { "text": symbols.mark("?") }, { "text": "+" },
            { "text": "", "action": "backspace" }
        ]
    }
}
