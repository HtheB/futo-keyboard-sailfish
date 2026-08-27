/* Categorized, vertically scrollable picker for the phone's supported symbols. */
import QtQuick 2.0
import Sailfish.Silica 1.0

Item {
    id: symbolGrid

    property Item targetLayout
    property bool followRowHeight: false
    // QML Positioners do not inherit a width from their parent.  Give this
    // custom picker an explicit width so its Flow cells never collapse at x=0.
    width: parent ? parent.width : (targetLayout ? targetLayout.width : 0)
    readonly property int columns: targetLayout && targetLayout.portraitMode ? 8 : 12
    readonly property int rows: targetLayout && targetLayout.numberRowEnabled ? 4 : 3
    readonly property var entries: targetLayout
            ? targetLayout.extendedSymbolEntriesForPage() : []
    readonly property bool culturalPage: targetLayout
            && targetLayout.extendedSymbolCategoryIdForPage
            && targetLayout.extendedSymbolCategoryIdForPage() === "cultural"
    // Keep the model string-only for Qt 5.6 compatibility. Empty strings are
    // reserved grid cells following a wide Arabic presentation-form key.
    readonly property var displayEntries: culturalPage
            ? packCulturalEntries(entries) : packWideEntries(entries)
    readonly property bool split: targetLayout && targetLayout.splitActive
    readonly property real splitGap: split ? Number(targetLayout.avoidanceWidth) : 0
    height: targetLayout ? rows * targetLayout.keyHeight : 0

    FontLoader {
        id: amiriFont
        source: "file:///usr/share/futo-keyboard-sailfish/fonts/Amiri-Regular.ttf"
    }

    function cellSpan(value) {
        if (!value || value.length === 0)
            return 1
        var codepoint = value.charCodeAt(0)
        if (codepoint === 0xFDFB) // Decomposed Jalla Jalaluhu label
            return 2
        if (codepoint === 0xFDFD) // Full besmele ligature
            return 4
        return 1
    }

    function packWideEntries(values) {
        var result = []
        var usedColumns = 0
        if (!values)
            return result
        for (var i = 0; i < values.length; ++i) {
            var value = String(values[i])
            var span = Math.min(columns, cellSpan(value))
            // Move a wide key to the next row when it cannot fully fit.
            while (usedColumns > 0 && usedColumns + span > columns) {
                result.push("")
                ++usedColumns
                if (usedColumns === columns)
                    usedColumns = 0
            }
            result.push(value)
            for (var reserved = 1; reserved < span; ++reserved)
                result.push("")
            usedColumns += span
            if (usedColumns === columns)
                usedColumns = 0
        }
        return result
    }

    function isArabicReligiousLigature(value) {
        if (!value || value.length === 0)
            return false
        var codepoint = value.charCodeAt(0)
        return codepoint >= 0xFDF0 && codepoint <= 0xFDFD
    }

    function appendRtlRows(result, values) {
        var row = []
        var remaining = columns
        var hasValue = false

        function resetRow() {
            row = []
            for (var column = 0; column < columns; ++column)
                row.push("")
            remaining = columns
            hasValue = false
        }

        function appendRow() {
            for (var column = 0; column < columns; ++column)
                result.push(row[column])
        }

        resetRow()
        for (var i = 0; i < values.length; ++i) {
            var value = String(values[i])
            var span = Math.min(columns, cellSpan(value))
            // Keep both specialized Qur'anic stop signs together at the
            // right-hand start of their final RTL row in narrow portrait.
            if (value.charCodeAt(0) === 0xFDF0 && remaining < 2) {
                appendRow()
                resetRow()
            }
            if (hasValue && span > remaining) {
                appendRow()
                resetRow()
            }

            // CharacterKey widths extend toward the right. Put the key at the
            // left edge of its occupied cells while allocating logical items
            // from the right edge toward the left.
            var startColumn = remaining - span
            row[startColumn] = value
            remaining = startColumn
            hasValue = true
        }
        if (hasValue)
            appendRow()
    }

    function packCulturalEntries(values) {
        var arabicEntries = []
        var remainingEntries = []
        var inArabicPrefix = true
        for (var i = 0; i < values.length; ++i) {
            var value = String(values[i])
            if (inArabicPrefix && isArabicReligiousLigature(value))
                arabicEntries.push(value)
            else {
                inArabicPrefix = false
                remainingEntries.push(value)
            }
        }

        var result = []
        // The Arabic block reads naturally from the upper-right toward the
        // left and wraps to a new row at the right. Padding completes its last
        // RTL row before the following LTR cultural symbols begin.
        appendRtlRows(result, arabicEntries)
        return result.concat(packWideEntries(remainingEntries))
    }

    SilicaFlickable {
        id: grid
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: Math.ceil(symbolGrid.displayEntries.length
                                 / symbolGrid.columns) * cellHeight
        readonly property real cellWidth: (width - symbolGrid.splitGap)
                                          / symbolGrid.columns
        readonly property real cellHeight: symbolGrid.targetLayout
                ? symbolGrid.targetLayout.keyHeight : 0

        function positionViewAtBeginning() {
            contentY = 0
        }

        // Qt 5.6 handles string-array models reliably; object arrays can
        // silently instantiate no delegates on this Sailfish build.
        Repeater {
            model: symbolGrid.displayEntries

            Item {
                readonly property int cellColumn: index % symbolGrid.columns
                readonly property int cellRow: Math.floor(index / symbolGrid.columns)
                x: cellColumn * grid.cellWidth
                   + (symbolGrid.split && cellColumn >= symbolGrid.columns / 2
                      ? symbolGrid.splitGap : 0)
                y: cellRow * grid.cellHeight
                width: grid.cellWidth
                height: grid.cellHeight

                FutoExtendedSymbolKey {
                    visible: String(modelData) !== ""
                    width: grid.cellWidth * symbolGrid.cellSpan(String(modelData))
                    height: grid.cellHeight
                    symbolText: String(modelData)
                    arabicFontFamily: amiriFont.name
                    targetLayout: symbolGrid.targetLayout
                }
            }
        }

        VerticalScrollDecorator {}
    }

    Label {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingLarge
        visible: symbolGrid.targetLayout
                 && symbolGrid.targetLayout.extendedSymbolPage === 0
                 && symbolGrid.entries.length === 0
        text: qsTr("Hold a symbol in another tab to add it to Favorites")
        color: Theme.secondaryColor
        font.pixelSize: Theme.fontSizeSmall
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
    }

    Connections {
        target: targetLayout
        onExtendedSymbolPageChanged: grid.positionViewAtBeginning()
        onExtendedSymbolModeChanged: {
            if (targetLayout.extendedSymbolMode)
                grid.positionViewAtBeginning()
        }
    }
}
