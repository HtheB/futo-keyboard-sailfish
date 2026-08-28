/* Configure and order the actions shown after holding 123. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0

Page {
    id: page
    allowedOrientations: Orientation.All

    readonly property string defaultActionOrder:
        "language,layouts,keyboardmode,desktopkeys,clipboard,emoji,microphone,sound,incognito,settings"
    readonly property string defaultEnabledActions: defaultActionOrder
    property string draggedActionId: ""
    property int draggedActionIndex: -1
    property Item draggedActionContent: null
    property Item draggedActionOwner: null
    property real draggedActionPointerY: 0
    property real draggedActionGrabY: 0
    property real draggedActionListStartY: 0
    property real draggedActionStartContentY: 0

    readonly property var knownActions: [
        { "id": "language", "label": qsTr("Switch language/layout"),
          "icon": "image://theme/icon-m-region" },
        { "id": "layouts", "label": qsTr("Edit layouts"),
          "icon": "image://theme/icon-m-edit" },
        { "id": "keyboardmode", "label": qsTr("Keyboard mode"),
          "icon": "image://theme/icon-m-text-input" },
        { "id": "desktopkeys", "label": qsTr("Extra key row"),
          "icon": "image://theme/icon-m-keyboard" },
        { "id": "clipboard", "label": qsTr("Clipboard"),
          "icon": "image://theme/icon-m-clipboard" },
        { "id": "emoji", "label": qsTr("Emoji"),
          "icon": "file:///usr/share/futo-keyboard-sailfish/icons/icon-m-emoji.svg" },
        { "id": "microphone", "label": qsTr("Microphone"),
          "icon": "image://theme/icon-m-browser-microphone" },
        { "id": "sound", "label": qsTr("Keyboard sounds"),
          "icon": "image://theme/icon-m-speaker-on" },
        { "id": "incognito", "label": qsTr("Incognito"),
          "icon": "image://theme/icon-m-incognito" },
        { "id": "settings", "label": qsTr("FUTO Settings"),
          "icon": "image://theme/icon-m-setting" }
    ]

    ConfigurationGroup {
        id: settings
        path: "/sailfish/text_input/futo_keyboard"
        property string quickSettingsOrder: page.defaultActionOrder
        property string quickSettingsEnabled: page.defaultEnabledActions
    }

    function splitUnique(value) {
        var raw = String(value).split(",")
        var result = []
        for (var i = 0; i < raw.length; ++i) {
            var id = raw[i].trim()
            if (id !== "" && result.indexOf(id) < 0)
                result.push(id)
        }
        return result
    }

    function definition(actionId) {
        for (var i = 0; i < knownActions.length; ++i) {
            if (knownActions[i].id === actionId)
                return knownActions[i]
        }
        return null
    }

    function loadModel() {
        actionModel.clear()
        var order = splitUnique(settings.quickSettingsOrder)
        var enabled = splitUnique(settings.quickSettingsEnabled)
        for (var i = 0; i < knownActions.length; ++i) {
            if (order.indexOf(knownActions[i].id) < 0)
                order.push(knownActions[i].id)
        }
        for (var j = 0; j < order.length; ++j) {
            var item = definition(order[j])
            if (item) {
                actionModel.append({
                    "actionId": item.id,
                    "actionLabel": item.label,
                    "actionIcon": item.icon,
                    "actionEnabled": enabled.indexOf(item.id) >= 0
                })
            }
        }
    }

    function saveModel() {
        var order = []
        var enabled = []
        for (var i = 0; i < actionModel.count; ++i) {
            var item = actionModel.get(i)
            order.push(String(item.actionId))
            if (item.actionEnabled)
                enabled.push(String(item.actionId))
        }
        settings.quickSettingsOrder = order.join(",")
        settings.quickSettingsEnabled = enabled.join(",")
    }

    function beginActionDrag(actionId, itemIndex, contentItem, pointerY, grabY) {
        var owner = contentItem.parent
        var floatingPosition = owner.mapToItem(page, contentItem.x, contentItem.y)
        draggedActionId = String(actionId)
        draggedActionIndex = itemIndex
        draggedActionContent = contentItem
        draggedActionOwner = owner
        draggedActionPointerY = Number(pointerY)
        draggedActionGrabY = Number(grabY)
        draggedActionListStartY = floatingPosition.y
                - itemIndex * Theme.itemSizeLarge
        draggedActionStartContentY = actionScroller.contentY
        contentItem.parent = page
        contentItem.x = floatingPosition.x
        contentItem.y = floatingPosition.y
        contentItem.z = 1000
        positionActionDrag()
    }

    function positionActionDrag() {
        if (draggedActionIndex < 0 || !draggedActionContent)
            return
        draggedActionContent.y = draggedActionPointerY - draggedActionGrabY
    }

    function updateActionDrag(pointerY) {
        if (draggedActionIndex < 0 || !draggedActionContent)
            return
        if (pointerY !== undefined && isFinite(Number(pointerY)))
            draggedActionPointerY = Number(pointerY)
        positionActionDrag()
        // Base the list origin on the actual row that was pressed. Mapping a
        // zero-height marker returns y=0 on Sailfish OS 5.2, irrespective of
        // its visible location below the description text.
        var listStartY = draggedActionListStartY
                - (actionScroller.contentY - draggedActionStartContentY)
        var rowTop = draggedActionPointerY - draggedActionGrabY - listStartY
        var target = Math.floor((rowTop + Theme.itemSizeLarge / 2)
                                / Theme.itemSizeLarge)
        target = Math.max(0, Math.min(actionModel.count - 1, target))
        if (target !== draggedActionIndex) {
            actionModel.move(draggedActionIndex, target, 1)
            draggedActionIndex = target
            saveModel()
            positionActionDrag()
        }
    }

    function endActionDrag() {
        if (draggedActionContent && draggedActionOwner) {
            var restingPosition = draggedActionContent.mapToItem(draggedActionOwner, 0, 0)
            draggedActionContent.parent = draggedActionOwner
            draggedActionContent.x = restingPosition.x
            draggedActionContent.y = restingPosition.y
            draggedActionContent.z = 0
        }
        draggedActionId = ""
        draggedActionIndex = -1
        draggedActionContent = null
        draggedActionOwner = null
        draggedActionListStartY = 0
        draggedActionStartContentY = 0
    }

    function restoreActionDefaults() {
        settings.quickSettingsOrder = defaultActionOrder
        settings.quickSettingsEnabled = defaultEnabledActions
        loadModel()
    }

    ListModel { id: actionModel }

    Component.onCompleted: loadModel()

    Timer {
        interval: 40
        repeat: true
        running: page.draggedActionIndex >= 0
        onTriggered: {
            if (!page.draggedActionContent)
                return
            var edge = Theme.itemSizeLarge
            var oldY = actionScroller.contentY
            var maximumY = Math.max(0, actionScroller.contentHeight
                                    - actionScroller.height)
            var pointerY = page.draggedActionPointerY - actionScroller.y
            if (pointerY < edge)
                actionScroller.contentY = Math.max(0, oldY - Theme.paddingMedium)
            else if (pointerY > actionScroller.height - edge)
                actionScroller.contentY = Math.min(maximumY,
                                                   oldY + Theme.paddingMedium)
            if (actionScroller.contentY !== oldY)
                page.updateActionDrag()
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
        id: actionScroller
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: testPanel.top
        contentHeight: content.height + Theme.paddingLarge
        clip: true
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height && page.draggedActionIndex < 0
        pressDelay: 140
        VerticalScrollDecorator { flickable: actionScroller }

        Column {
            id: content
            width: parent.width
            move: Transition {
                NumberAnimation {
                    properties: "x,y"
                    duration: 140
                    easing.type: Easing.InOutQuad
                }
            }

            PageHeader { title: qsTr("Quick settings") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Choose and arrange the actions shown after holding 123. "
                           + "Unavailable actions, such as Clipboard while clipboard history "
                           + "is off, remain hidden until their feature is enabled. Use the "
                           + "checkbox to enable an action, then hold and drag its name to "
                           + "arrange it.")
            }

            Item { id: actionListStart; width: 1; height: 0 }

            Repeater {
                model: actionModel

                Item {
                    id: actionRow
                    width: content.width
                    height: Theme.itemSizeLarge
                    z: page.draggedActionId === actionId ? 100 : 0

                    onYChanged: {
                        if (page.draggedActionId === actionId)
                            page.positionActionDrag()
                    }

                    function liftForDragging(pointerY, grabY) {
                        settleAnimation.stop()
                        rowContent.x = 0
                        rowContent.y = 0
                        page.beginActionDrag(actionId, index, rowContent,
                                             pointerY, grabY)
                    }

                    function returnFromDragging() {
                        settleAnimation.restart()
                    }

                    Item {
                        id: rowContent
                        width: actionRow.width
                        height: actionRow.height
                        Rectangle {
                            anchors.fill: parent
                            color: page.draggedActionId === actionId
                                   ? Theme.rgba(Theme.highlightColor, 0.24)
                                   : Theme.rgba(Theme.highlightBackgroundColor, 0.0)
                        }

                        Icon {
                            id: actionIconItem
                            anchors.left: enabledSwitch.right
                            anchors.leftMargin: Theme.paddingMedium
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.iconSizeSmall
                            height: width
                            // The theme clipboard artwork contains more internal
                            // padding, so enlarge only its glyph while keeping the
                            // fixed icon slot and label alignment unchanged.
                            scale: actionId === "clipboard" ? 1.18 : 1.0
                            source: actionIcon
                            color: actionEnabled ? Theme.primaryColor
                                                 : Theme.secondaryColor
                        }

                        Label {
                            anchors.left: actionIconItem.right
                            anchors.leftMargin: Theme.paddingMedium
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.horizontalPageMargin
                            anchors.verticalCenter: parent.verticalCenter
                            text: actionLabel
                            truncationMode: TruncationMode.Fade
                            color: actionEnabled ? Theme.primaryColor : Theme.secondaryColor
                        }

                        Switch {
                            id: enabledSwitch
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.horizontalPageMargin
                            anchors.verticalCenter: parent.verticalCenter
                            automaticCheck: false
                            checked: actionEnabled
                            onClicked: {
                                actionModel.setProperty(index, "actionEnabled", !actionEnabled)
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
                                actionRow.liftForDragging(pointer.y,
                                                          dragArea.mouseY)
                            }
                        }

                        MouseArea {
                            id: dragArea
                            property bool dragGesture: false
                            anchors.left: actionIconItem.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            preventStealing: page.draggedActionId === actionId
                            onPressed: {
                                dragGesture = false
                                dragStartTimer.restart()
                            }
                            onPositionChanged: {
                                if (page.draggedActionId === actionId) {
                                    var pointer = dragArea.mapToItem(
                                                page, mouse.x, mouse.y)
                                    page.updateActionDrag(pointer.y)
                                }
                            }
                            onReleased: {
                                dragStartTimer.stop()
                                if (page.draggedActionId === actionId) {
                                    page.endActionDrag()
                                    actionRow.returnFromDragging()
                                }
                            }
                            onCanceled: {
                                dragStartTimer.stop()
                                if (page.draggedActionId === actionId) {
                                    page.endActionDrag()
                                    actionRow.returnFromDragging()
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
                onClicked: page.restoreActionDefaults()
            }

            Item { width: 1; height: Theme.paddingLarge }
        }
    }
}
