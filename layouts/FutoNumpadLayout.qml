/* Four aligned rows modelled after a phone number/symbol pad. */
import QtQuick 2.0

Column {
    id: numpad

    property Item targetLayout
    property bool secondPage: false
    property bool followRowHeight: false
    height: targetLayout ? 4 * targetLayout.keyHeight : 0
    spacing: 0

    function digit(value) {
        // The dedicated 123 page uses Western digits. Arabic-Indic variants
        // are supplied by each number key's long-press popup.
        return String(value)
    }

    function numberPageLabel() {
        return targetLayout && targetLayout.numberPageLabel
                ? targetLayout.numberPageLabel() : "123"
    }

    FutoNumpadRow {
        width: parent.width
        height: numpad.targetLayout ? numpad.targetLayout.keyHeight : 0
        targetLayout: numpad.targetLayout
		totalSpans: 9
        cells: numpad.secondPage ? [
            { "text": "$" }, { "text": "€" }, { "text": "¥" },
            { "text": "¢" }, { "text": "©" }, { "text": "®" },
			{ "text": "™" }, { "text": "~" }, { "text": "¿" }
        ] : [
            { "text": "#" }, { "text": "€" }, { "text": "&" },
            { "text": "_" }, { "text": "-" }, { "text": numpad.digit("1") },
			{ "text": numpad.digit("2") }, { "text": numpad.digit("3") }, { "text": "?" }
        ]
    }

    FutoNumpadRow {
        width: parent.width
        height: numpad.targetLayout ? numpad.targetLayout.keyHeight : 0
        targetLayout: numpad.targetLayout
		totalSpans: 9
        cells: numpad.secondPage ? [
            { "text": "⇥", "action": "tab" }, { "text": "[" }, { "text": "]" },
            { "text": "{" }, { "text": "}" }, { "text": "<" },
			{ "text": ">" }, { "text": "^" }, { "text": "¡" }
        ] : [
            { "text": "@" }, { "text": "(" }, { "text": ")" },
            { "text": "=" }, { "text": "+" }, { "text": numpad.digit("4") },
			{ "text": numpad.digit("5") }, { "text": numpad.digit("6") }, { "text": "!" }
        ]
    }

    FutoNumpadRow {
        width: parent.width
        height: numpad.targetLayout ? numpad.targetLayout.keyHeight : 0
        targetLayout: numpad.targetLayout
		totalSpans: 9
        cells: numpad.secondPage ? [
            { "text": numpad.numberPageLabel(), "action": "page1" }, { "text": "`" },
            { "text": ";" }, { "text": "÷" }, { "text": "\\" },
            { "text": "|" }, { "text": "¦" }, { "text": "¬" },
			{ "text": "", "action": "backspace" }
        ] : [
            { "text": "{&=", "action": "extendedSymbols" }, { "text": "'" },
            { "text": ":" }, { "text": "%" }, { "text": "/" },
            { "text": numpad.digit("7") }, { "text": numpad.digit("8") }, { "text": numpad.digit("9") },
			{ "text": "", "action": "backspace" }
        ]
    }

    FutoNumpadRow {
        width: parent.width
        height: numpad.targetLayout ? numpad.targetLayout.keyHeight : 0
        targetLayout: numpad.targetLayout
		totalSpans: 9
        cells: numpad.secondPage ? [
            { "text": "ABC", "action": "abc" },
            { "text": "", "action": "space", "span": 3 },
            { "text": "×" }, { "text": "§" }, { "text": "¶" },
			{ "text": "°" }, { "text": "", "action": "enter" }
        ] : [
            { "text": "ABC", "action": "abc" }, { "text": "\"" },
            { "text": "", "action": "space", "span": 2 }, { "text": "*" },
            { "text": "," }, { "text": numpad.digit("0") }, { "text": "." },
			{ "text": "", "action": "enter" }
        ]
    }
}
