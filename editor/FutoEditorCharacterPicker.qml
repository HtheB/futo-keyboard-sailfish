import QtQuick 2.6
import Sailfish.Silica 1.0
import "FutoEditorCharacters.js" as Characters

Page {
    id: page
    allowedOrientations: Orientation.LandscapeMask
    FutoEditorTooltip {}
    property int category: 0
    signal chosen(string character)
    function scrollTabs(direction) {
        tabs.cancelFlick()
        tabScroll.stop()
        var start = tabs.originX
        var end = start + Math.max(0, tabs.contentWidth - tabs.width)
        tabScroll.to = Math.max(start, Math.min(end, tabs.contentX + direction * tabs.width * 0.8))
        tabScroll.restart()
    }
    Row {
        id: toolbar
        width: parent.width
        FutoEditorTool { actionId: "back"; description: qsTr("Back to editor"); onClicked: pageStack.pop() }
        Label {
            width: parent.width - Theme.itemSizeSmall; height: Theme.itemSizeSmall
            text: qsTr("Choose character") + " - " + Characters.categories[page.category].name
            textFormat: Text.PlainText; verticalAlignment: Text.AlignVCenter; color: Theme.highlightColor
        }
    }
    Item {
        id: tabBar
        anchors.top: toolbar.bottom; width: parent.width; height: Theme.itemSizeSmall
        FutoEditorTool {
            id: moreLeft
            objectName: "moreCategoriesLeft"
            anchors.left: parent.left
            width: Theme.itemSizeExtraSmall; height: parent.height
            visible: !tabs.atXBeginning
            actionId: "left"; description: qsTr("Previous categories")
            icon.width: Theme.iconSizeSmall; icon.height: Theme.iconSizeSmall
            Accessible.name: qsTr("More categories to the left")
            onClicked: page.scrollTabs(-1)
        }
        SilicaListView {
            id: tabs
            objectName: "characterTabs"
            anchors.left: moreLeft.right; anchors.right: moreRight.left; height: parent.height
            orientation: ListView.Horizontal; clip: true
            model: Characters.categories
            onDraggingChanged: if (dragging) tabScroll.stop()
            HorizontalScrollDecorator {}
            delegate: BackgroundItem {
                width: Theme.itemSizeMedium; height: tabs.height
                Rectangle { anchors.fill: parent; anchors.margins: Theme.paddingSmall; radius: Theme.paddingSmall; color: Theme.rgba(Theme.highlightColor, 0.25); visible: page.category === index }
                Label { anchors.centerIn: parent; text: modelData.icon; textFormat: Text.PlainText; font.pixelSize: Theme.fontSizeMedium; color: page.category === index ? Theme.highlightColor : Theme.primaryColor }
                onClicked: { page.category = index; grid.positionViewAtBeginning() }
                Accessible.name: modelData.name
            }
        }
        FutoEditorTool {
            id: moreRight
            objectName: "moreCategoriesRight"
            anchors.right: parent.right
            width: Theme.itemSizeExtraSmall; height: parent.height
            visible: !tabs.atXEnd
            actionId: "right"; description: qsTr("Next categories")
            icon.width: Theme.iconSizeSmall; icon.height: Theme.iconSizeSmall
            Accessible.name: qsTr("More categories to the right")
            onClicked: page.scrollTabs(1)
        }
        NumberAnimation { id: tabScroll; target: tabs; property: "contentX"; duration: 180; easing.type: Easing.OutQuad }
    }
    SilicaGridView {
        id: grid
        objectName: "characterGrid"
        anchors.top: tabBar.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: Theme.paddingMedium
        clip: true
        cellWidth: width / Math.max(1, Math.floor(width / Theme.itemSizeSmall))
        cellHeight: Theme.itemSizeSmall
        model: Characters.characters(page.category)
        VerticalScrollDecorator {}
        delegate: BackgroundItem {
            width: grid.cellWidth; height: grid.cellHeight
            Rectangle { anchors.fill: parent; anchors.margins: 2; radius: Theme.paddingSmall; color: Theme.rgba(Theme.primaryColor, 0.07) }
            Label {
                anchors.fill: parent; anchors.margins: Theme.paddingSmall
                text: Characters.display(modelData); textFormat: Text.PlainText
                font.pixelSize: Theme.fontSizeLarge; fontSizeMode: Text.Fit; minimumPixelSize: Theme.fontSizeTiny
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
            onClicked: { page.chosen(modelData); pageStack.pop() }
        }
    }
}
