/* Straight row that preserves the empty centre of landscape Thumb mode. */
import QtQuick 2.0

Item {
    id: desktopRow

    property Item targetLayout
    property var cells: []
    property int totalSpans: 10
    property int splitSpan: Math.ceil(totalSpans / 2)
    property bool followRowHeight: true
    property bool compact: false

    function spanBefore(itemIndex) {
        var result = 0
        for (var i = 0; i < itemIndex && i < cells.length; ++i)
            result += Number(cells[i].span || 1)
        return result
    }

    Repeater {
        model: desktopRow.cells

        Item {
            id: cell
            property var definition: modelData
            readonly property real logicalStart: desktopRow.spanBefore(index)
            readonly property real logicalSpan: Number(definition.span || 1)
            readonly property bool split: desktopRow.targetLayout
                    && desktopRow.targetLayout.splitActive
            readonly property real gap: split
                    ? Number(desktopRow.targetLayout.avoidanceWidth) : 0
            readonly property real sideWidth: (desktopRow.width - gap) / 2
            readonly property bool onRight: split
                    && logicalStart >= desktopRow.splitSpan
            readonly property real sideSpans: onRight
                    ? desktopRow.totalSpans - desktopRow.splitSpan
                    : desktopRow.splitSpan

            x: !split
               ? desktopRow.width * logicalStart / desktopRow.totalSpans
               : onRight
                 ? desktopRow.width / 2 + gap / 2
                   + sideWidth * (logicalStart - desktopRow.splitSpan) / sideSpans
                 : sideWidth * logicalStart / sideSpans
            width: !split
                   ? desktopRow.width * logicalSpan / desktopRow.totalSpans
                   : sideWidth * logicalSpan / sideSpans
            height: desktopRow.height

            FutoDesktopKey {
                anchors.fill: parent
                targetLayout: desktopRow.targetLayout
                keyId: String(cell.definition.id)
                compact: desktopRow.compact
            }
        }
    }
}
