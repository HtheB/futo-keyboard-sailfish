/* Fourth keyboard layer containing the keys normally found on a desktop. */
import QtQuick 2.0

Column {
    id: desktopGrid

    property Item targetLayout
    height: targetLayout ? 4 * targetLayout.keyHeight : 0
    spacing: 0

    FutoDesktopKeyRow {
        width: parent.width
        height: desktopGrid.targetLayout ? desktopGrid.targetLayout.keyHeight : 0
        targetLayout: desktopGrid.targetLayout
        cells: [
            { "id": "esc" }, { "id": "f1" }, { "id": "f2" },
            { "id": "f3" }, { "id": "f4" }, { "id": "f5" },
            { "id": "f6" }, { "id": "f7" }, { "id": "f8" },
            { "id": "f9" }
        ]
    }

    FutoDesktopKeyRow {
        width: parent.width
        height: desktopGrid.targetLayout ? desktopGrid.targetLayout.keyHeight : 0
        targetLayout: desktopGrid.targetLayout
        cells: [
            { "id": "tab" }, { "id": "f10" }, { "id": "f11" },
            { "id": "f12" }, { "id": "print" }, { "id": "insert" },
            { "id": "home" }, { "id": "pageup" }, { "id": "pause" },
            { "id": "backspace" }
        ]
    }

    FutoDesktopKeyRow {
        width: parent.width
        height: desktopGrid.targetLayout ? desktopGrid.targetLayout.keyHeight : 0
        targetLayout: desktopGrid.targetLayout
        cells: [
            { "id": "numbers" }, { "id": "abc" }, { "id": "numlock" },
            { "id": "scrolllock" }, { "id": "menu" }, { "id": "delete" },
            { "id": "end" }, { "id": "pagedown" }, { "id": "up" },
            { "id": "enter" }
        ]
    }

    FutoDesktopKeyRow {
        width: parent.width
        height: desktopGrid.targetLayout ? desktopGrid.targetLayout.keyHeight : 0
        targetLayout: desktopGrid.targetLayout
        cells: [
            { "id": "ctrl" }, { "id": "super" }, { "id": "alt" },
            { "id": "space", "span": 3 }, { "id": "altgr" }, { "id": "left" },
            { "id": "down" }, { "id": "right" }
        ]
    }
}
