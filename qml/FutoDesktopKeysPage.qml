/* Choose and arrange the optional desktop-key toolbar. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0

Page {
    id: page
    allowedOrientations: Orientation.All

    readonly property string defaultKeyOrder:
        "esc,f1,f2,f3,f4,f5,f6,f7,f8,f9,f10,f11,f12,print,pause,insert,delete,home,end,pageup,pagedown,ctrl,alt,altgr,super,tab,menu,numlock,scrolllock,left,up,down,right,backspace,space,enter"
    readonly property string defaultEnabledKeys:
        "esc,ctrl,alt,left,down,right,delete"
    property string draggedKeyId: ""
    property int draggedKeyIndex: -1
    property Item draggedKeyContent: null
    property Item draggedKeyOwner: null
    property real draggedKeyPointerY: 0
    property real draggedKeyGrabY: 0
    property real draggedKeyListStartY: 0
    property real draggedKeyStartContentY: 0

    readonly property var knownKeys: [
        { "id": "esc", "label": qsTr("Escape") },
        { "id": "f1", "label": "F1" },
        { "id": "f2", "label": "F2" },
        { "id": "f3", "label": "F3" },
        { "id": "f4", "label": "F4" },
        { "id": "f5", "label": "F5" },
        { "id": "f6", "label": "F6" },
        { "id": "f7", "label": "F7" },
        { "id": "f8", "label": "F8" },
        { "id": "f9", "label": "F9" },
        { "id": "f10", "label": "F10" },
        { "id": "f11", "label": "F11" },
        { "id": "f12", "label": "F12" },
        { "id": "print", "label": qsTr("Print Screen") },
        { "id": "pause", "label": qsTr("Pause") },
        { "id": "insert", "label": qsTr("Insert") },
        { "id": "delete", "label": qsTr("Delete") },
        { "id": "home", "label": qsTr("Home") },
        { "id": "end", "label": qsTr("End") },
        { "id": "pageup", "label": qsTr("Page Up") },
        { "id": "pagedown", "label": qsTr("Page Down") },
        { "id": "ctrl", "label": qsTr("Ctrl") },
        { "id": "alt", "label": qsTr("Alt") },
        { "id": "altgr", "label": qsTr("AltGr") },
        { "id": "super", "label": qsTr("Sailfish key") },
        { "id": "tab", "label": qsTr("Tab") },
        { "id": "menu", "label": qsTr("Menu") },
        { "id": "numlock", "label": qsTr("Num Lock") },
        { "id": "scrolllock", "label": qsTr("Scroll Lock") },
        { "id": "left", "label": qsTr("Left arrow") },
        { "id": "up", "label": qsTr("Up arrow") },
        { "id": "down", "label": qsTr("Down arrow") },
        { "id": "right", "label": qsTr("Right arrow") },
        { "id": "backspace", "label": qsTr("Backspace") },
        { "id": "space", "label": qsTr("Space") },
        { "id": "enter", "label": qsTr("Enter") }
    ]

    ConfigurationGroup {
        id: settings
        path: "/sailfish/text_input/futo_keyboard"
        property bool desktopToolbarEnabled: false
        property string desktopToolbarOrder: page.defaultKeyOrder
        property string desktopToolbarEnabledKeys: page.defaultEnabledKeys
    }

    function splitUnique(value) {
        var raw = String(value).split(",")
        var result = []
        for (var i = 0; i < raw.length; ++i) {
            var keyId = raw[i].trim()
            if (keyId !== "" && result.indexOf(keyId) < 0)
                result.push(keyId)
        }
        return result
    }

    function definition(keyId) {
        for (var i = 0; i < knownKeys.length; ++i) {
            if (knownKeys[i].id === keyId)
                return knownKeys[i]
        }
        return null
    }

    function shortLabel(keyId) {
        if (keyId === "left") return "←"
        if (keyId === "right") return "→"
        if (keyId === "up") return "↑"
        if (keyId === "down") return "↓"
        if (keyId === "super") return "SF"
        if (keyId === "backspace") return "⌫"
        if (keyId === "space") return "␣"
        if (keyId === "enter") return "↵"
        if (keyId === "pageup") return "PgUp"
        if (keyId === "pagedown") return "PgDn"
        if (keyId === "print") return "PrtSc"
        if (keyId === "insert") return "Ins"
        if (keyId === "delete") return "Del"
        if (keyId === "scrolllock") return "Scroll"
        if (keyId === "numlock") return "Num"
        return keyId.length > 0
                ? keyId.charAt(0).toUpperCase() + keyId.slice(1) : ""
    }

    function loadModel() {
        keyModel.clear()
        var order = splitUnique(settings.desktopToolbarOrder)
        var enabled = splitUnique(settings.desktopToolbarEnabledKeys)
        for (var i = 0; i < knownKeys.length; ++i) {
            if (order.indexOf(knownKeys[i].id) < 0)
                order.push(knownKeys[i].id)
        }
        for (var j = 0; j < order.length; ++j) {
            var item = definition(order[j])
            if (item) {
                keyModel.append({
                    "keyId": item.id,
                    "keyLabel": item.label,
                    "keyEnabled": enabled.indexOf(item.id) >= 0
                })
            }
        }
    }

    function saveModel() {
        var order = []
        var enabled = []
        for (var i = 0; i < keyModel.count; ++i) {
            var item = keyModel.get(i)
            order.push(String(item.keyId))
            if (item.keyEnabled)
                enabled.push(String(item.keyId))
        }
        settings.desktopToolbarOrder = order.join(",")
        settings.desktopToolbarEnabledKeys = enabled.join(",")
    }

    function beginKeyDrag(keyId, itemIndex, contentItem, pointerY, grabY) {
        var owner = contentItem.parent
        var floatingPosition = owner.mapToItem(page, contentItem.x, contentItem.y)
        draggedKeyId = String(keyId)
        draggedKeyIndex = itemIndex
        draggedKeyContent = contentItem
        draggedKeyOwner = owner
        draggedKeyPointerY = Number(pointerY)
        draggedKeyGrabY = Number(grabY)
        draggedKeyListStartY = floatingPosition.y
                - itemIndex * Theme.itemSizeLarge
        draggedKeyStartContentY = keyScroller.contentY
        contentItem.parent = page
        contentItem.x = floatingPosition.x
        contentItem.y = floatingPosition.y
        contentItem.z = 1000
        positionKeyDrag()
    }

    function positionKeyDrag() {
        if (draggedKeyIndex < 0 || !draggedKeyContent)
            return
        draggedKeyContent.y = draggedKeyPointerY - draggedKeyGrabY
    }

    function updateKeyDrag(pointerY) {
        if (draggedKeyIndex < 0 || !draggedKeyContent)
            return
        if (pointerY !== undefined && isFinite(Number(pointerY)))
            draggedKeyPointerY = Number(pointerY)
        positionKeyDrag()
        // Derive the list origin from the real row that was grabbed. A
        // zero-height marker maps to y=0 on some Sailfish OS releases even
        // when it is visibly below the page header.
        var listStartY = draggedKeyListStartY
                - (keyScroller.contentY - draggedKeyStartContentY)
        var rowTop = draggedKeyPointerY - draggedKeyGrabY - listStartY
        var target = Math.floor((rowTop + Theme.itemSizeLarge / 2)
                                / Theme.itemSizeLarge)
        target = Math.max(0, Math.min(keyModel.count - 1, target))
        if (target !== draggedKeyIndex) {
            keyModel.move(draggedKeyIndex, target, 1)
            draggedKeyIndex = target
            saveModel()
            positionKeyDrag()
        }
    }

    function endKeyDrag() {
        if (draggedKeyContent && draggedKeyOwner) {
            var restingPosition = draggedKeyContent.mapToItem(draggedKeyOwner, 0, 0)
            draggedKeyContent.parent = draggedKeyOwner
            draggedKeyContent.x = restingPosition.x
            draggedKeyContent.y = restingPosition.y
            draggedKeyContent.z = 0
        }
        draggedKeyId = ""
        draggedKeyIndex = -1
        draggedKeyContent = null
        draggedKeyOwner = null
        draggedKeyListStartY = 0
        draggedKeyStartContentY = 0
    }

    function restoreKeyDefaults() {
        settings.desktopToolbarOrder = defaultKeyOrder
        settings.desktopToolbarEnabledKeys = defaultEnabledKeys
        loadModel()
    }

    ListModel { id: keyModel }
    Component.onCompleted: loadModel()

    Timer {
        interval: 40
        repeat: true
        running: page.draggedKeyIndex >= 0
        onTriggered: {
            if (!page.draggedKeyContent)
                return
            var edge = Theme.itemSizeLarge
            var oldY = keyScroller.contentY
            var maximumY = Math.max(0, keyScroller.contentHeight - keyScroller.height)
            var pointerY = page.draggedKeyPointerY - keyScroller.y
            if (pointerY < edge)
                keyScroller.contentY = Math.max(0, oldY - Theme.paddingMedium)
            else if (pointerY > keyScroller.height - edge)
                keyScroller.contentY = Math.min(maximumY,
                                                oldY + Theme.paddingMedium)
            if (keyScroller.contentY !== oldY)
                page.updateKeyDrag()
        }
    }

    FutoSettingsTestPanel {
        id: testPanel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        pageItem: page
    }

    SilicaFlickable {
        id: keyScroller
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: testPanel.top
        clip: true
        contentHeight: Math.max(height, contentColumn.height + Theme.paddingLarge)
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height && page.draggedKeyIndex < 0
        pressDelay: 140
        VerticalScrollDecorator { flickable: keyScroller }

        Column {
            id: contentColumn
            width: keyScroller.width
            move: Transition {
                NumberAnimation {
                    properties: "x,y"
                    duration: 140
                    easing.type: Easing.InOutQuad
                }
            }

            PageHeader { title: qsTr("Extra key row") }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.desktopToolbarEnabled
                text: qsTr("Show extra key row")
                description: qsTr("Display the selected desktop keys below suggestions. "
                                  + "You can also toggle this from Quick Settings.")
                onClicked: settings.desktopToolbarEnabled = !checked
            }

            SectionHeader { text: qsTr("Keys and order") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Use the checkbox to enable a key, then hold and drag its name "
                           + "to arrange it. The row "
                           + "scrolls horizontally when it does not fit.")
            }
            Item { width: 1; height: Theme.paddingSmall }
            Item { id: keyListStart; width: 1; height: 0 }
            Repeater {
                model: keyModel

                Item {
                    id: keyRow
                    width: contentColumn.width
                    height: Theme.itemSizeLarge
                    z: page.draggedKeyId === keyId ? 100 : 0

                    onYChanged: {
                        if (page.draggedKeyId === keyId)
                            page.positionKeyDrag()
                    }

                    function liftForDragging(pointerY, grabY) {
                        settleAnimation.stop()
                        rowContent.x = 0
                        rowContent.y = 0
                        page.beginKeyDrag(keyId, index, rowContent,
                                          pointerY, grabY)
                    }

                    function returnFromDragging() {
                        settleAnimation.restart()
                    }

                    Item {
                        id: rowContent
                        width: keyRow.width
                        height: keyRow.height
                        Rectangle {
                            anchors.fill: parent
                            color: page.draggedKeyId === keyId
                                   ? Theme.rgba(Theme.highlightColor, 0.24)
                                   : Theme.rgba(Theme.highlightBackgroundColor, 0.0)
                        }

                        Rectangle {
                            id: keyBadge
                            anchors.left: enabledSwitch.right
                            anchors.leftMargin: Theme.paddingMedium
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.itemSizeSmall
                            height: Math.round(Theme.itemSizeSmall * 0.72)
                            radius: Theme.paddingSmall
                            color: Theme.rgba(Theme.primaryColor, 0.10)
                            border.width: 1
                            border.color: Theme.rgba(Theme.primaryColor, 0.18)

                            Label {
                                anchors.centerIn: parent
                                visible: keyId !== "super"
                                text: page.shortLabel(keyId)
                                color: keyEnabled ? Theme.primaryColor
                                                  : Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                                fontSizeMode: Text.Fit
                            }

                            Icon {
                                anchors.centerIn: parent
                                visible: keyId === "super"
                                width: Theme.iconSizeSmall
                                height: width
                                source: "image://theme/icon-m-sailfish"
                                color: keyEnabled ? Theme.primaryColor
                                                  : Theme.secondaryColor
                            }
                        }

                        Label {
                            anchors.left: keyBadge.right
                            anchors.leftMargin: Theme.paddingMedium
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.horizontalPageMargin
                            anchors.verticalCenter: parent.verticalCenter
                            text: keyLabel
                            truncationMode: TruncationMode.Fade
                            color: keyEnabled ? Theme.primaryColor : Theme.secondaryColor
                        }

                        Switch {
                            id: enabledSwitch
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.horizontalPageMargin
                            anchors.verticalCenter: parent.verticalCenter
                            automaticCheck: false
                            checked: keyEnabled
                            onClicked: {
                                keyModel.setProperty(index, "keyEnabled", !keyEnabled)
                                page.saveModel()
                            }
                        }

                        Timer {
                            id: dragStartTimer
                            interval: 180
                            repeat: false
                            onTriggered: {
                                dragArea.dragGesture = true
                                var pointer = dragArea.mapToItem(
                                            page, dragArea.mouseX,
                                            dragArea.mouseY)
                                keyRow.liftForDragging(pointer.y,
                                                       dragArea.mouseY)
                            }
                        }

                        MouseArea {
                            id: dragArea
                            property bool dragGesture: false
                            anchors.left: keyBadge.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            preventStealing: page.draggedKeyId === keyId
                            onPressed: {
                                dragGesture = false
                                dragStartTimer.restart()
                            }
                            onPositionChanged: {
                                if (page.draggedKeyId === keyId) {
                                    var pointer = dragArea.mapToItem(
                                                page, mouse.x, mouse.y)
                                    page.updateKeyDrag(pointer.y)
                                }
                            }
                            onReleased: {
                                dragStartTimer.stop()
                                if (page.draggedKeyId === keyId) {
                                    page.endKeyDrag()
                                    keyRow.returnFromDragging()
                                }
                            }
                            onCanceled: {
                                dragStartTimer.stop()
                                if (page.draggedKeyId === keyId) {
                                    page.endKeyDrag()
                                    keyRow.returnFromDragging()
                                }
                                dragGesture = false
                            }
                            onClicked: {
                                dragGesture = false
                            }
                        }
                    }

                    ParallelAnimation {
                        id: settleAnimation
                        NumberAnimation {
                            target: rowContent
                            property: "x"
                            to: 0
                            duration: 140
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            target: rowContent
                            property: "y"
                            to: 0
                            duration: 140
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }

            Item { width: 1; height: Theme.paddingLarge }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Restore defaults")
                onClicked: page.restoreKeyDefaults()
            }

            Item { width: 1; height: Theme.paddingLarge }
        }
    }
}
