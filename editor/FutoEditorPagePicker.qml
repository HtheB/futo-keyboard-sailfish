import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: picker
    property var pages: []
    property bool active: true
    property string selectedPageId: ""
    property string pendingDeleteId: ""
    property var pendingRemorse: null
    property int deleteRequestSerial: 0
    property string draggedId: ""
    property string draggedName: ""
    property int draggedIndex: -1
    property bool settling: false
    property real pointerY: 0
    property real grabY: 0
    readonly property bool dragging: draggedIndex >= 0
    readonly property real rowHeight: Theme.itemSizeLarge
    signal chosen(string id)
    signal reordered(string id, int target)
    signal deleteRequested(string id)
    signal addRequested()
    clip: true

    function cancelDeletion() {
        var remorse = pendingRemorse
        deleteRequestSerial++
        pendingDeleteId = ""
        pendingRemorse = null
        if (remorse) remorse.cancel()
    }
    function cancelInteractions() {
        cancelDeletion()
        if (dragging) finishDrag(false)
        dropAnimation.stop()
        settling = false; draggedId = ""; draggedName = ""
    }
    function synchronize() {
        cancelDeletion()
        if (dragging) { finishDrag(false); return }
        for (var i = 0; i < pages.length; i++) {
            var found = -1
            for (var j = i; j < pageModel.count; j++)
                if (pageModel.get(j).pageId === pages[i].id) { found = j; break }
            if (found < 0) pageModel.insert(i, {pageId: pages[i].id, pageName: pages[i].name})
            else {
                if (found !== i) pageModel.move(found, i, 1)
                pageModel.setProperty(i, "pageName", pages[i].name)
            }
        }
        if (pageModel.count > pages.length) pageModel.remove(pages.length, pageModel.count - pages.length)
    }
    function requestDeletion(id, row) {
        if (!active || pages.length <= 1 || dragging || settling) return
        cancelDeletion()
        pendingDeleteId = id
        var serial = deleteRequestSerial
        pendingRemorse = Remorse.itemAction(row, qsTr("Deleting page"), function() {
            if (picker.deleteRequestSerial !== serial || picker.pendingDeleteId !== id) return
            picker.pendingDeleteId = ""; picker.pendingRemorse = null
            if (picker.active && picker.pages.length > 1)
                picker.deleteRequested(id)
        })
        if (!pendingRemorse) pendingDeleteId = ""
    }
    function beginDrag(id, name, index, y, offset) {
        if (!active) return
        dropAnimation.stop(); settling = false
        cancelDeletion()
        draggedId = id; draggedName = name; draggedIndex = index
        pointerY = y; grabY = offset
        floatingRow.y = y - offset
    }
    function updateDrag(y) {
        if (!dragging) return
        if (y !== undefined) pointerY = y
        floatingRow.y = pointerY - grabY
        var listTop = pageList.mapToItem(picker, 0, 0).y
        var top = pointerY - grabY - listTop + pageList.contentY - pageList.originY
        var target = Math.max(0, Math.min(pageModel.count - 1, Math.floor((top + rowHeight / 2) / rowHeight)))
        if (target !== draggedIndex) {
            pageModel.move(draggedIndex, target, 1)
            draggedIndex = target
        }
    }
    function finishDrag(commit) {
        if (!dragging) return
        var id = draggedId, target = draggedIndex, startY = floatingRow.y
        draggedIndex = -1
        if (commit) reordered(id, target)
        synchronize()
        if (commit && active) {
            settling = true
            dropAnimation.from = startY
            dropAnimation.to = pageList.mapToItem(picker, 0, 0).y + pageList.originY + target * rowHeight - pageList.contentY
            dropAnimation.restart()
        } else { draggedId = ""; draggedName = "" }
    }
    onPagesChanged: { synchronize(); if (active && !draggedId) showSelection.restart() }
    onActiveChanged: {
        if (active) { synchronize(); showSelection.restart() }
        else cancelInteractions()
    }
    Component.onCompleted: synchronize()
    Component.onDestruction: cancelDeletion()

    ListModel { id: pageModel }
    NumberAnimation {
        id: dropAnimation
        target: floatingRow; property: "y"; duration: 180; easing.type: Easing.OutCubic
        onStopped: { picker.settling = false; picker.draggedId = ""; picker.draggedName = "" }
    }
    Connections {
        target: picker.pendingRemorse
        onCanceled: { picker.pendingDeleteId = ""; picker.pendingRemorse = null }
    }
    Timer {
        id: showSelection
        interval: 0
        onTriggered: {
            if (!picker.active || picker.dragging || picker.settling) return
            for (var i = 0; i < pageModel.count; i++)
                if (pageModel.get(i).pageId === picker.selectedPageId) {
                    pageList.positionViewAtIndex(i, ListView.Contain)
                    break
                }
        }
    }
    Timer {
        interval: 16; repeat: true; running: picker.dragging && picker.active
        onTriggered: {
            var y = picker.pointerY - pageList.mapToItem(picker, 0, 0).y
            var edge = Math.min(picker.rowHeight * 0.6, pageList.height / 4)
            var step = y < edge ? -8 : y > pageList.height - edge ? 8 : 0
            var next = Math.max(pageList.originY, Math.min(pageList.originY + Math.max(0, pageList.contentHeight - pageList.height), pageList.contentY + step))
            if (next !== pageList.contentY) {
                pageList.contentY = next
                picker.updateDrag()
            }
        }
    }
    Item {
        id: header
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: Theme.itemSizeSmall
        SectionHeader {
            anchors.left: parent.left; anchors.right: addPage.left; anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Pages")
        }
        FutoEditorTool {
            id: addPage
            objectName: "addEditorPage"
            anchors.right: parent.right; anchors.rightMargin: Theme.horizontalPageMargin
            actionId: "page-add"; description: qsTr("Add page")
            enabled: picker.pages.length < 16 && !picker.dragging && !picker.settling
            onClicked: { picker.cancelDeletion(); picker.addRequested() }
        }
    }
    SilicaListView {
        id: pageList
        objectName: "editorPagesList"
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: header.bottom; anchors.bottom: parent.bottom
        model: pageModel
        currentIndex: -1
        interactive: !picker.dragging && !picker.settling
        cacheBuffer: picker.rowHeight * 16
        clip: true
        move: Transition { NumberAnimation { properties: "x,y"; duration: 180; easing.type: Easing.OutCubic } }
        displaced: Transition { NumberAnimation { properties: "x,y"; duration: 180; easing.type: Easing.OutCubic } }
        add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 } }
        remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 180 } }
        VerticalScrollDecorator {}
        delegate: ListItem {
            id: pageRow
            objectName: "editorPage-" + pageId
            width: pageList.width
            contentHeight: picker.rowHeight
            onClicked: { picker.cancelInteractions(); picker.chosen(pageId) }
            Item {
                id: rowContent
                anchors.fill: parent
                opacity: picker.draggedId === pageId ? 0 : 1
                Rectangle {
                    anchors.fill: parent
                    color: pageId === picker.selectedPageId ? Theme.rgba(Theme.highlightColor, 0.10) : "transparent"
                }
                Item {
                    id: grip
                    anchors.left: parent.left; anchors.leftMargin: Theme.paddingSmall
                    width: Theme.itemSizeSmall; height: parent.height
                    Icon { anchors.centerIn: parent; source: "image://theme/icon-m-menu"; color: Theme.secondaryColor }
                    MouseArea {
                        objectName: "editorPageDrag-" + pageId
                        anchors.fill: parent
                        preventStealing: true
                        Accessible.name: qsTr("Drag to reorder page")
                        onPressed: {
                            picker.forceActiveFocus()
                            var point = mapToItem(picker, mouse.x, mouse.y)
                            picker.beginDrag(pageId, pageName, index, point.y, mouse.y)
                        }
                        onPositionChanged: if (picker.dragging) {
                            var point = mapToItem(picker, mouse.x, mouse.y)
                            picker.updateDrag(point.y)
                        }
                        onReleased: picker.finishDrag(true)
                        onCanceled: picker.finishDrag(false)
                    }
                }
                Label {
                    anchors.left: grip.right; anchors.leftMargin: Theme.paddingMedium
                    anchors.right: deleteButton.left; anchors.rightMargin: Theme.paddingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    text: pageName; textFormat: Text.PlainText; truncationMode: TruncationMode.Fade
                    color: pageId === picker.selectedPageId ? Theme.highlightColor : Theme.primaryColor
                }
                FutoEditorTool {
                    id: deleteButton
                    objectName: "deleteEditorPage-" + pageId
                    anchors.right: parent.right; anchors.rightMargin: Theme.paddingSmall; anchors.verticalCenter: parent.verticalCenter
                    actionId: "page-remove"; description: qsTr("Delete page")
                    enabled: picker.pages.length > 1 && !picker.dragging && !picker.settling
                    Accessible.name: qsTr("Delete page")
                    onClicked: picker.requestDeletion(pageId, rowContent)
                }
            }
        }
    }
    Rectangle {
        id: floatingRow
        objectName: "editorDraggedPage"
        visible: picker.dragging || picker.settling
        anchors.left: pageList.left; anchors.right: pageList.right
        height: picker.rowHeight
        z: 10
        color: Theme.highlightDimmerColor
        Icon {
            anchors.left: parent.left; anchors.leftMargin: Theme.paddingSmall + (Theme.itemSizeSmall - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            source: "image://theme/icon-m-menu"
        }
        Label {
            x: Theme.paddingSmall + Theme.itemSizeSmall + Theme.paddingMedium
            width: parent.width - x - Theme.itemSizeSmall
            anchors.verticalCenter: parent.verticalCenter
            text: picker.draggedName; textFormat: Text.PlainText; truncationMode: TruncationMode.Fade
            color: Theme.highlightColor
        }
    }
}
