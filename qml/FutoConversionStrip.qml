/* Candidate text and readings come from Mozc/RIME, not the word predictor. */
import QtQuick 2.0
import Sailfish.Silica 1.0

Item {
    id: strip
    property var controller
    property real expandedHeight: Theme.itemSizeLarge * 3
    readonly property bool expanded: controller && controller.expanded
    readonly property bool readingVisible: controller && controller.language !== "JA"
            && controller.preedit !== ""
    readonly property int readingHeight: readingVisible ? Theme.fontSizeSmall + Theme.paddingSmall : 0
    readonly property int shownRevision: controller ? controller.revision : 0
    implicitHeight: Theme.itemSizeSmall + readingHeight

    TextInput {
        id: reading
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.paddingMedium
        height: strip.readingHeight
        visible: strip.readingVisible
        text: strip.controller ? strip.controller.reading : ""
        color: Theme.highlightColor
        font.pixelSize: Theme.fontSizeSmall
        readOnly: true
        clip: true
        cursorVisible: strip.readingVisible
        cursorPosition: strip.controller ? Math.min(text.length, strip.controller.cursor) : 0
        MouseArea {
            anchors.fill: parent
            onClicked: strip.controller.moveReadingCursor(reading.positionAt(mouse.x, mouse.y))
        }
    }

    SilicaListView {
        id: list
        anchors.left: parent.left
        anchors.right: expandButton.left
        anchors.bottom: parent.bottom
        height: Theme.itemSizeSmall
        orientation: ListView.Horizontal
        clip: true
        model: strip.controller ? strip.controller.candidateModel : null
        delegate: BackgroundItem {
            id: candidate
            width: Math.min(list.width, Math.max(Theme.itemSizeSmall,
                    label.implicitWidth + 2 * Theme.paddingLarge))
            height: list.height
            readonly property int candidateRevision: strip.shownRevision
            onClicked: strip.controller.selectCandidate(model.candidateId, candidateRevision)
            Label {
                id: label
                anchors.centerIn: parent
                text: String(model.text)
                textFormat: Text.PlainText
                color: candidate.down ? Theme.highlightColor : Theme.primaryColor
                font.pixelSize: Theme.fontSizeMedium
            }
        }
        HorizontalScrollDecorator {}
        onContentXChanged: if (strip.controller && contentX + width >= contentWidth - Theme.itemSizeLarge) strip.controller.loadMore()
        onCountChanged: if (count === 0) positionViewAtBeginning()
    }

    IconButton {
        id: expandButton
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: Theme.itemSizeSmall
        height: Theme.itemSizeSmall
        enabled: strip.controller && strip.controller.candidates.length > 0
        icon.source: strip.expanded ? "image://theme/icon-m-up" : "image://theme/icon-m-down"
        onClicked: strip.controller.expanded = !strip.expanded
    }

    Label {
        anchors.fill: list
        anchors.leftMargin: Theme.paddingMedium
        anchors.rightMargin: Theme.paddingMedium
        visible: list.count === 0
        text: strip.controller && strip.controller.message !== ""
              ? strip.controller.message : qsTr("Type to see conversions")
        textFormat: Text.PlainText
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.secondaryColor
        verticalAlignment: Text.AlignVCenter
        truncationMode: TruncationMode.Fade
    }

    Rectangle {
        anchors.top: parent.bottom
        width: parent.width
        height: strip.expandedHeight
        visible: strip.expanded
        color: Theme.overlayBackgroundColor
        SilicaGridView {
            id: grid
            anchors.fill: parent
            clip: true
            cellWidth: width / Math.max(2, Math.floor(width / (Theme.itemSizeLarge * 1.5)))
            cellHeight: Theme.itemSizeLarge
            model: strip.controller ? strip.controller.candidateModel : null
            delegate: BackgroundItem {
                id: tile
                width: grid.cellWidth
                height: grid.cellHeight
                readonly property int candidateRevision: strip.shownRevision
                onClicked: strip.controller.selectCandidate(model.candidateId, candidateRevision)
                Column {
                    anchors.centerIn: parent
                    width: parent.width - 2 * Theme.paddingSmall
                    Label {
                        width: parent.width
                        text: String(model.text)
                        textFormat: Text.PlainText
                        color: tile.down ? Theme.highlightColor : Theme.primaryColor
                        horizontalAlignment: Text.AlignHCenter
                        truncationMode: TruncationMode.Fade
                    }
                    Label {
                        width: parent.width
                        text: String(model.comment || "")
                        textFormat: Text.PlainText
                        visible: text !== ""
                        font.pixelSize: Theme.fontSizeTiny
                        color: Theme.secondaryColor
                        horizontalAlignment: Text.AlignHCenter
                        truncationMode: TruncationMode.Fade
                    }
                }
            }
            onContentYChanged: if (strip.controller && contentY + height >= contentHeight - cellHeight * 2) strip.controller.loadMore()
            VerticalScrollDecorator {}
        }
    }
}
