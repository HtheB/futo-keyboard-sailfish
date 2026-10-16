import QtQuick 2.6
import Sailfish.Silica 1.0

Canvas {
    id: glyph
    property string actionId
    property color color: Theme.primaryColor
    onActionIdChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onAvailableChanged: if (available) requestPaint()
    onVisibleChanged: if (visible && available) requestPaint()
    Component.onCompleted: if (available) requestPaint()
    onPaint: {
        var c = getContext("2d")
        c.clearRect(0, 0, width, height); c.save(); c.scale(width / 32, height / 32)
        c.strokeStyle = color; c.fillStyle = color; c.lineWidth = 1.8; c.lineCap = "round"; c.lineJoin = "round"
        function line(points) { c.beginPath(); c.moveTo(points[0], points[1]); for (var p = 2; p < points.length; p += 2) c.lineTo(points[p], points[p + 1]); c.stroke() }
        var name = actionId
        if (name === "undo" || name === "redo") {
            if (name === "redo") { c.translate(32, 0); c.scale(-1, 1) }
            line([11, 6, 5, 12, 11, 18]); c.beginPath(); c.moveTo(6, 12); c.lineTo(19, 12); c.bezierCurveTo(30, 12, 30, 26, 19, 26); c.lineTo(14, 26); c.stroke()
        } else if (name === "save" || name === "save-copy") {
            line([5, 4, 23, 4, 28, 9, 28, 28, 5, 28, 5, 4]); c.strokeRect(10, 4, 12, 8); c.strokeRect(10, 19, 13, 9)
            if (name === "save-copy") { c.clearRect(19, 19, 13, 13); line([25, 21, 25, 30]); line([21, 25, 30, 25]) }
        } else if (name === "test") {
            c.strokeRect(3, 7, 23, 16); for (var k = 0; k < 3; ++k) c.strokeRect(7 + k * 6, 11, 2, 2)
            line([8, 19, 20, 19]); c.clearRect(21, 18, 11, 14); line([24, 20, 31, 25, 24, 30, 24, 20])
        } else if (name === "characters") {
            for (var r = 0; r < 3; ++r) for (var col = 0; col < 3; ++col) c.strokeRect(4 + col * 9, 4 + r * 9, 6, 6)
        }
        c.restore()
    }
}
