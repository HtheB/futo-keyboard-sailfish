import QtQuick 2.6
import Sailfish.Silica 1.0
import Nemo.DBus 2.0
import "FutoCustomLayouts.js" as Custom
import "FutoEditorHints.js" as Hints

Page {
    id: editor
    allowedOrientations: Orientation.LandscapeMask
    FutoEditorTooltip {}
    backNavigation: !dirty
    property var document: Custom.blank()
    property int revision: 0
    property int pageIndex: 0
    property int selectedRow: 0
    property int selectedColumn: 0
    property bool dirty: false
    property bool busy: false
    property bool pagePickerOpen: false
    property bool hintDismissed: false
    readonly property bool hintShown: !hintDismissed || message !== ""
    property string message: ""
    property var undoStack: []
    property var redoStack: []
    readonly property var pageData: { revision; return Custom.clone(document.pages[Math.max(0, Math.min(pageIndex, document.pages.length - 1))]) }
    readonly property string pageChoicesJson: {
        revision
        return JSON.stringify(document.pages.map(function(page) { return {id: page.id, name: page.name} }))
    }
    readonly property var pageChoices: JSON.parse(pageChoicesJson)
    // A fresh snapshot also updates controls when a field on the same key changes.
    readonly property var selectedKey: { revision; return pageData && pageData.rows[selectedRow] && pageData.rows[selectedRow][selectedColumn] ? Custom.clone(pageData.rows[selectedRow][selectedColumn]) : null }
    readonly property bool reservedKey: pageData && selectedRow === pageData.rows.length - 1 && selectedColumn === 0
    readonly property var boxes: { revision; return Custom.geometry(pageData.rows, preview.width, preview.height, 0) }
    readonly property var selectedBox: {
        for (var i = 0; i < boxes.length; ++i) if (boxes[i].row === selectedRow && boxes[i].column === selectedColumn) return boxes[i]
        return null
    }
    function remember() { undoStack = undoStack.concat([Custom.clone(document)]).slice(-30); redoStack = [] }
    function editablePage() { return document.pages[pageIndex] }
    function indexForPage(id) {
        for (var i = 0; i < document.pages.length; i++)
            if (document.pages[i].id === id) return i
        return -1
    }
    function choosePage(id) {
        var index = indexForPage(id)
        if (index < 0) return
        pagePicker.cancelInteractions()
        pageIndex = index; select(0, 0)
        pagePickerOpen = false; properties.contentY = 0
    }
    function togglePagePicker() {
        forceActiveFocus()
        pagePicker.cancelInteractions()
        pagePickerOpen = !pagePickerOpen
    }
    function changed() { dirty = true; revision++; message = "" }
    function dismissHint() { hintDismissed = true; message = "" }
    function updateKey(name, value) {
        if (!selectedKey || selectedKey[name] === value) return
        remember(); document.pages[pageIndex].rows[selectedRow][selectedColumn][name] = value; changed()
    }
    function select(row, column) { forceActiveFocus(); selectedRow = row; selectedColumn = column }
    function setWidth(value) {
        value = Math.max(0.25, Math.min(20, value))
        if (!selectedKey || selectedKey.width === value) return
        document.pages[pageIndex].rows[selectedRow][selectedColumn].width = value; changed()
    }
    function updateAlternatives(values) {
        remember()
        var item = document.pages[pageIndex].rows[selectedRow][selectedColumn]
        item.more = values
        if (item.defaultMore >= values.length) item.defaultMore = 0
        changed()
    }
    function chooseCharacter(destination) {
        forceActiveFocus()
        var picker = pageStack.push(Qt.resolvedUrl("FutoEditorCharacterPicker.qml"))
        picker.chosen.connect(function(value) {
            if (destination === "more") {
                if (editor.selectedKey.more.length < 32) editor.updateAlternatives(editor.selectedKey.more.concat([value]))
            } else editor.updateKey(destination, value)
        })
    }
    function testLayout() {
        forceActiveFocus()
        if (!Custom.valid(document, false)) { message = qsTr("Check the key text and page-switch destinations before testing."); return }
        pageStack.push(Qt.resolvedUrl("FutoEditorTestPage.qml"), {document: Custom.clone(document)})
    }
    function undo(redo) {
        var source = redo ? redoStack : undoStack
        if (!source.length) return
        var next = source[source.length - 1]
        if (redo) { redoStack = redoStack.slice(0, -1); undoStack = undoStack.concat([Custom.clone(document)]) }
        else { undoStack = undoStack.slice(0, -1); redoStack = redoStack.concat([Custom.clone(document)]) }
        var selectedId = pageData.id
        document = Custom.clone(next)
        var restored = indexForPage(selectedId)
        pageIndex = restored >= 0 ? restored : Math.min(pageIndex, document.pages.length - 1)
        select(0, 0); changed()
    }
    function save(copy) {
        forceActiveFocus()
        if (busy) return
        saveFeedback.dismiss()
        if (!Custom.valid(document, false)) { message = qsTr("Check the key text and page-switch destinations before saving."); return }
        var value = Custom.clone(document)
        if (copy) value.id = ""
        busy = true
        helper.typedCall("SaveCustomLayout", [{type: "s", value: JSON.stringify(value)}], function(raw) {
            editor.busy = false
            var collection = Custom.parse(String(raw))
            if (!collection) { editor.message = qsTr("Could not read the saved layout"); return }
            var saved = null
            for (var i = 0; i < collection.layouts.length; ++i)
                if (collection.layouts[i].id === value.id) saved = collection.layouts[i]
            if (!saved) saved = collection.layouts[collection.layouts.length - 1]
            if (!saved) { editor.message = qsTr("Could not read the saved layout"); return }
            editor.document = Custom.clone(saved); editor.revision++; editor.dirty = false
            editor.message = ""
            saveFeedback.show(copy ? qsTr("Saved as a new layout") : qsTr("Layout saved"))
        }, function(name, detail) { editor.busy = false; editor.message = String(detail || qsTr("Could not save the layout")) })
    }
    function addKey(action) {
        if (pageData.rows[selectedRow].length >= 48) return
        action = action || "text"
        remember(); editablePage().rows[selectedRow].splice(selectedColumn + 1, 0, Custom.key(action, action === "text" ? "a" : "")); selectedColumn++; changed()
    }
    function deleteKey() {
        if (pageData.rows[selectedRow].length <= 1) {
            remember(); editablePage().rows[selectedRow][0] = Custom.key("spacer"); changed(); return
        }
        remember(); editablePage().rows[selectedRow].splice(selectedColumn, 1); selectedColumn = Math.max(0, selectedColumn - 1); changed()
    }
    function duplicateKey() {
        var row = editablePage().rows[selectedRow]
        if (row.length >= 48) return
        remember(); row.splice(selectedColumn + 1, 0, Custom.clone(selectedKey)); selectedColumn++; changed()
    }
    function addRow() {
        if (pageData.rows.length >= 12) return
        remember(); editablePage().rows.splice(selectedRow + 1, 0, [Custom.key("spacer")]); select(selectedRow + 1, 0); changed()
    }
    function deleteRow() {
        if (pageData.rows.length <= 1) return
        remember(); editablePage().rows.splice(selectedRow, 1); select(Math.max(0, selectedRow - 1), 0); changed()
    }
    function moveRow(delta) {
        var target = selectedRow + delta
        if (target < 0 || target >= pageData.rows.length) return
        remember(); var row = editablePage().rows.splice(selectedRow, 1)[0]; editablePage().rows.splice(target, 0, row); selectedRow = target; changed()
    }
    function editStructure(action) {
        forceActiveFocus()
        pagePicker.cancelInteractions(); pagePickerOpen = false
        if (action === "key-add") addKey()
        else if (action === "key-remove") deleteKey()
        else if (action === "duplicate") duplicateKey()
        else if (action === "gap") addKey("spacer")
        else if (action === "row-add") addRow()
        else if (action === "row-remove") deleteRow()
        else if (action === "up") moveRow(-1)
        else if (action === "down") moveRow(1)
    }
    function addPage() {
        if (document.pages.length >= 16) return
        remember(); var base = "page-" + Date.now().toString(36), id = base, suffix = 2
        while (indexForPage(id) >= 0) id = base + "-" + suffix++
        document.pages.push(Custom.newPage(id, qsTr("New page"), "symbols")); pageIndex = document.pages.length - 1; select(0, 0); changed()
    }
    function deletePage(id) {
        if (document.pages.length <= 1) return
        var removed = id || pageData.id, index = indexForPage(removed)
        if (index < 0) return
        var selectedId = pageData.id
        remember(); document.pages.splice(index, 1)
        pageIndex = selectedId === removed ? Math.min(index, document.pages.length - 1) : indexForPage(selectedId)
        // Removed page targets return to the first remaining page, never a dead end.
        for (var p = 0; p < document.pages.length; ++p)
            for (var r = 0; r < document.pages[p].rows.length; ++r)
                for (var k = 0; k < document.pages[p].rows[r].length; ++k) {
                    var item = document.pages[p].rows[r][k]
                    if (item.action === "page" && item.target === removed) item.target = document.pages[0].id
                }
        if (selectedId === removed) select(0, 0)
        changed()
    }
    function movePage(id, target) {
        var index = indexForPage(id)
        if (index < 0 || target < 0 || target >= document.pages.length || target === index) return
        var selectedId = pageData.id
        remember(); var page = document.pages.splice(index, 1)[0]; document.pages.splice(target, 0, page)
        pageIndex = indexForPage(selectedId); changed()
    }
    function leave() {
        if (!dirty) { pageStack.pop(); return }
        var dialog = pageStack.push(discardDialog)
        dialog.accepted.connect(function() { editor.dirty = false; pageStack.pop() })
    }
    Component {
        id: discardDialog
        Dialog {
            allowedOrientations: Orientation.LandscapeMask
            DialogHeader { title: qsTr("Discard unsaved changes?"); acceptText: qsTr("Discard") }
        }
    }
    DBusInterface {
        id: helper
        bus: DBus.SessionBus; service: "org.hb.FutoKeyboard1"; path: "/org/hb/FutoKeyboard1"; iface: "org.hb.FutoKeyboard1"
        watchServiceStatus: true
    }
    FutoEditorToast {
        id: saveFeedback
        objectName: "saveFeedback"
        pageActive: editor.status === PageStatus.Active && Qt.application.state === Qt.ApplicationActive
    }
    Row {
        id: toolbar
        objectName: "editorToolbar"
        x: Theme.paddingMedium; y: Theme.paddingSmall; width: pageSelector.x - x - Theme.paddingSmall; height: Theme.itemSizeSmall
        spacing: Theme.paddingSmall
        readonly property real toolWidth: Math.min(Theme.itemSizeSmall, (width - 5 * spacing) / 6)
        FutoEditorTool { width: toolbar.toolWidth; actionId: "back"; description: qsTr("Back"); onClicked: editor.leave() }
        FutoEditorTool { width: toolbar.toolWidth; actionId: "undo"; description: qsTr("Undo"); enabled: editor.undoStack.length > 0; onClicked: editor.undo(false) }
        FutoEditorTool { width: toolbar.toolWidth; actionId: "redo"; description: qsTr("Redo"); enabled: editor.redoStack.length > 0; onClicked: editor.undo(true) }
        FutoEditorTool { width: toolbar.toolWidth; actionId: "save"; description: qsTr("Save"); enabled: !editor.busy; onClicked: editor.save(false) }
        FutoEditorTool { width: toolbar.toolWidth; actionId: "save-copy"; description: qsTr("Save as new"); enabled: !editor.busy; onClicked: editor.save(true) }
        FutoEditorTool { objectName: "testLayoutButton"; width: toolbar.toolWidth; actionId: "test"; description: qsTr("Test keyboard"); onClicked: editor.testLayout() }
    }
    Rectangle {
        objectName: "pageToolbarDivider"
        x: pageSelector.x - Theme.paddingSmall / 2
        anchors.verticalCenter: toolbar.verticalCenter
        width: 1; height: toolbar.height - 2 * Theme.paddingMedium
        color: Theme.rgba(Theme.primaryColor, 0.2)
    }
    BackgroundItem {
        id: pageSelector
        objectName: "pageSelector"
        anchors.right: left.right; anchors.rightMargin: Theme.paddingMedium; anchors.top: toolbar.top
        width: left.width * 0.30; height: toolbar.height
        Accessible.name: qsTr("Page") + ": " + editor.pageData.name
        onClicked: editor.togglePagePicker()
        onPressAndHold: Hints.show(pageSelector, qsTr("Pages"))
        Row {
            anchors.right: parent.right; anchors.rightMargin: Theme.paddingSmall; anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.paddingSmall
            Label {
                id: pageCaption
                width: Math.min(implicitWidth, pageSelector.width * 0.4)
                text: qsTr("Page"); truncationMode: TruncationMode.Fade
                color: pageSelector.highlighted ? Theme.highlightColor : Theme.primaryColor
            }
            Label {
                width: Math.max(0, Math.min(implicitWidth, pageSelector.width - pageCaption.width - 3 * Theme.paddingSmall))
                text: editor.pageData.name; textFormat: Text.PlainText; truncationMode: TruncationMode.Fade
                color: Theme.highlightColor
            }
        }
    }
    SilicaFlickable {
        id: left
        z: 1
        anchors.left: parent.left; anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
        width: parent.width * 0.59
        contentWidth: width; contentHeight: height
        interactive: false
        Item {
            id: previewHeader
            width: parent.width; height: layoutName.height
            z: 4
            TextField {
                id: layoutName
                objectName: "editorLayoutName"
                width: parent.width * 0.5; text: editor.document.name; label: qsTr("Layout name")
                onTextChanged: if (activeFocus && text !== editor.document.name) { editor.remember(); editor.document.name = text; editor.changed() }
            }
            FutoEditorActionMenu {
                objectName: "editorKeysMenu"
                x: layoutName.width; width: parent.width * 0.25
                actionGroup: "keys"
                canAddKey: editor.selectedKey && editor.pageData.rows[editor.selectedRow].length < 48
                onActionRequested: editor.editStructure(action)
            }
            FutoEditorActionMenu {
                objectName: "editorRowsMenu"
                x: parent.width * 0.75; width: parent.width * 0.25
                actionGroup: "rows"
                canAddRow: editor.pageData.rows.length < 12
                canDeleteRow: editor.pageData.rows.length > 1
                canMoveUp: editor.selectedRow > 0
                canMoveDown: editor.selectedRow < editor.pageData.rows.length - 1
                onActionRequested: editor.editStructure(action)
            }
        }
        Item {
            id: preview
            objectName: "editorKeyboardPreview"
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: previewHeader.bottom; anchors.bottom: previewHint.top
            anchors.margins: Theme.paddingMedium
            Rectangle { anchors.fill: parent; color: Theme.rgba(Theme.primaryColor, 0.045); radius: Theme.paddingSmall }
            Repeater {
                model: editor.boxes.length
                Rectangle {
                    id: tile
                    objectName: "editorPreviewKey-" + index
                    readonly property var box: editor.boxes[index] || {x: 0, y: 0, width: 0, height: 0, row: 0, column: 0}
                    x: box.x + 2; y: box.y + 2; width: Math.max(1, box.width - 4); height: Math.max(1, box.height - 4)
                    property var dataKey: editor.pageData.rows[box.row] ? editor.pageData.rows[box.row][box.column] || null : null
                    property bool selected: box.row === editor.selectedRow && box.column === editor.selectedColumn
                    visible: dataKey !== null && index < editor.boxes.length
                    color: selected ? Theme.rgba(Theme.highlightColor, 0.3) : dataKey && Custom.showsCard(dataKey, true) ? Theme.rgba(Theme.primaryColor, 0.12) : "transparent"
                    border.width: selected ? 2 : dataKey && dataKey.action === "spacer" ? 1 : 0
                    border.color: selected ? Theme.highlightColor : Theme.rgba(Theme.primaryColor, 0.15); radius: Theme.paddingSmall
                    opacity: pointer.dragging && selected ? 0.22 : 1
                    Label { anchors.fill: parent; anchors.margins: 3; text: tile.dataKey ? Custom.keyLabel(tile.dataKey) : ""; textFormat: Text.PlainText; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: Theme.fontSizeMedium; fontSizeMode: Text.Fit; minimumPixelSize: 8 }
                    Icon { visible: tile.dataKey && tile.dataKey.action === "spacer" && !tile.dataKey.label; anchors.centerIn: parent; width: Math.min(Theme.iconSizeMedium, parent.width * 0.6); height: width; rotation: 90; source: "image://theme/icon-m-scale"; opacity: 0.3 }
                    Label { anchors.right: parent.right; anchors.top: parent.top; text: !tile.dataKey ? "" : tile.box.row === editor.pageData.rows.length - 1 && tile.box.column === 0 ? "⚙" : tile.dataKey.more.length ? tile.dataKey.more[tile.dataKey.defaultMore] : ""; textFormat: Text.PlainText; font.pixelSize: Theme.fontSizeTiny }
                    Rectangle { visible: tile.selected; anchors.right: parent.right; anchors.bottom: parent.bottom; width: Math.min(Theme.paddingLarge, parent.width / 3); height: 5; color: Theme.highlightColor }
                }
            }
            Rectangle {
                visible: pointer.dragging && editor.selectedBox !== null
                x: pointer.ghostX; y: pointer.ghostY; width: editor.selectedBox ? editor.selectedBox.width : 1; height: editor.selectedBox ? editor.selectedBox.height : 1
                z: 2; color: Theme.highlightDimmerColor; border.color: Theme.highlightColor; border.width: 2; radius: Theme.paddingSmall
                Label { anchors.centerIn: parent; text: editor.selectedKey ? Custom.keyLabel(editor.selectedKey) : ""; textFormat: Text.PlainText; font.pixelSize: Theme.fontSizeMedium }
            }
            MouseArea {
                id: pointer
                anchors.fill: parent; z: 3; preventStealing: true
                property bool dragging: false
                property bool resizing: false
                property real startX: 0; property real startY: 0
                property real grabX: 0; property real grabY: 0
                property real ghostX: 0; property real ghostY: 0
                property real initialWeight: 1; property real otherWeight: 1
                onPressed: {
                    editor.pagePickerOpen = false
                    startX = mouse.x; startY = mouse.y; dragging = false; resizing = false
                    for (var i = 0; i < editor.boxes.length; ++i) {
                        var box = editor.boxes[i]
                        if (mouse.x >= box.x && mouse.x < box.x + box.width && mouse.y >= box.y && mouse.y < box.y + box.height) {
                            var wasSelected = editor.selectedRow === box.row && editor.selectedColumn === box.column
                            editor.select(box.row, box.column); grabX = mouse.x - box.x; grabY = mouse.y - box.y
                            ghostX = box.x; ghostY = box.y
                            resizing = wasSelected && grabX > box.width - Math.min(Theme.paddingLarge, box.width / 3) && grabY > box.height - Theme.paddingLarge
                            initialWeight = editor.selectedKey.width; otherWeight = 0
                            for (var k = 0; k < editor.pageData.rows[box.row].length; ++k) if (k !== box.column) otherWeight += editor.pageData.rows[box.row][k].width
                            if (resizing) editor.remember()
                            break
                        }
                    }
                }
                onPositionChanged: {
                    if (resizing) {
                        var pixels = Math.max(1, Math.min(preview.width - 1, preview.width * initialWeight / Math.max(0.25, initialWeight + otherWeight) + mouse.x - startX))
                        var weight = otherWeight > 0 ? otherWeight * pixels / (preview.width - pixels) : initialWeight
                        editor.setWidth(weight)
                    } else if (Math.abs(mouse.x - startX) + Math.abs(mouse.y - startY) > Theme.paddingMedium) {
                        dragging = true; ghostX = mouse.x - grabX; ghostY = mouse.y - grabY
                    }
                }
                onReleased: {
                    if (dragging) {
                        var row = Math.max(0, Math.min(editor.pageData.rows.length - 1, Math.floor(mouse.y / (preview.height / editor.pageData.rows.length))))
                        var column = editor.pageData.rows[row].length
                        for (var i = 0; i < editor.boxes.length; ++i) {
                            var box = editor.boxes[i]
                            if (box.row === row && mouse.x < box.x + box.width / 2) { column = box.column; break }
                        }
                        editor.remember()
                        var moved = Custom.move(editor.document, editor.pageIndex, editor.selectedRow, editor.selectedColumn, row, column)
                        if (moved) { editor.select(moved.row, moved.column); editor.changed() }
                        else editor.message = qsTr("A row must keep at least one key. Delete the row to remove it.")
                    }
                    dragging = false; resizing = false
                }
                onCanceled: { dragging = false; resizing = false }
            }
        }
        Item {
            id: previewHint
            objectName: "editorHintBar"
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: editor.hintShown ? Math.max(hintText.implicitHeight, dismissHintButton.height) + 2 * Theme.paddingSmall : 0
            opacity: editor.hintShown ? 1 : 0
            visible: height > 0
            enabled: editor.hintShown
            clip: true
            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Label {
                id: hintText
                anchors.left: parent.left; anchors.leftMargin: Theme.paddingMedium
                anchors.right: dismissHintButton.left; anchors.rightMargin: Theme.paddingSmall; anchors.verticalCenter: parent.verticalCenter
                text: editor.message || qsTr("Tap to edit. Drag a key to move it. Drag its lower-right handle to resize it.")
                textFormat: Text.PlainText; wrapMode: Text.Wrap; font.pixelSize: Theme.fontSizeExtraSmall; color: editor.message ? Theme.highlightColor : Theme.secondaryColor
            }
            FutoEditorTool {
                id: dismissHintButton
                objectName: "editorHintClose"
                anchors.right: parent.right; anchors.rightMargin: Theme.paddingSmall; anchors.verticalCenter: parent.verticalCenter
                width: Theme.itemSizeExtraSmall; height: width
                icon.source: "image://theme/icon-m-close"
                icon.width: Theme.iconSizeSmall; icon.height: Theme.iconSizeSmall
                Accessible.name: qsTr("Hide hint")
                actionId: "close"; description: qsTr("Hide hint")
                onClicked: editor.dismissHint()
            }
        }
    }
    Rectangle { x: left.width; width: 1; height: parent.height; color: Theme.rgba(Theme.primaryColor, 0.2) }
    Item {
        id: rightPane
        anchors.left: left.right; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
        clip: true
        SilicaFlickable {
            id: properties
            objectName: "keyProperties"
            anchors.fill: parent
            opacity: editor.pagePickerOpen ? 0 : 1
            visible: opacity > 0
            enabled: !editor.pagePickerOpen
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            transform: Translate {
                x: editor.pagePickerOpen ? -Theme.paddingLarge : 0
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }
            contentHeight: controls.height + Theme.paddingLarge
            clip: true
            VerticalScrollDecorator {}
            Column {
                id: controls; width: parent.width
                SectionHeader { text: qsTr("Selected key") }
                FutoEditorComboBox {
                    objectName: "actionSelector"
                    width: parent.width; label: qsTr("Action")
                    selectedIndex: editor.selectedKey ? Custom.actions.indexOf(editor.selectedKey.action) : 0
                    menu: ContextMenu {
                        Repeater { model: Custom.actions; MenuItem { text: modelData === "text" ? qsTr("Insert text") : modelData === "page" ? qsTr("Switch page") : modelData === "spacer" ? qsTr("Empty space") : Custom.labels[modelData] || modelData.toUpperCase(); onClicked: { editor.updateKey("action", modelData); if (modelData === "page") editor.updateKey("target", editor.pageData.id); if (modelData !== "text") editor.updateKey("dead", false) } } }
                    }
                }
                Row {
                    width: parent.width; visible: editor.selectedKey !== null
                    TextField { width: parent.width - Theme.itemSizeSmall; label: editor.selectedKey && editor.selectedKey.action === "spacer" ? qsTr("Label (optional)") : qsTr("Key label (optional)"); text: editor.selectedKey ? editor.selectedKey.label : ""; onTextChanged: if (activeFocus) editor.updateKey("label", text) }
                    FutoEditorTool { actionId: "characters"; description: qsTr("Choose label character"); onClicked: editor.chooseCharacter("label") }
                }
                Row {
                    width: parent.width; visible: editor.selectedKey && editor.selectedKey.action === "text"
                    TextField { width: parent.width - Theme.itemSizeSmall; label: qsTr("Text to insert"); text: editor.selectedKey ? editor.selectedKey.output : ""; onTextChanged: if (activeFocus) editor.updateKey("output", text) }
                    FutoEditorTool { actionId: "characters"; description: qsTr("Choose character"); onClicked: editor.chooseCharacter("output") }
                }
                Row {
                    width: parent.width; visible: editor.selectedKey && editor.selectedKey.action === "text"
                    TextField { width: parent.width - Theme.itemSizeSmall; label: qsTr("Text with Shift (optional)"); text: editor.selectedKey ? editor.selectedKey.shifted || "" : ""; onTextChanged: if (activeFocus) editor.updateKey("shifted", text) }
                    FutoEditorTool { actionId: "characters"; description: qsTr("Choose Shift character"); onClicked: editor.chooseCharacter("shifted") }
                }
                FutoEditorComboBox {
                    objectName: "appearanceSelector"
                    width: parent.width; visible: editor.selectedKey && editor.selectedKey.action !== "spacer"; label: qsTr("Appearance")
                    selectedIndex: editor.selectedKey ? Math.max(0, ["auto", "button", "plain"].indexOf(editor.selectedKey.style || "auto")) : 0
                    menu: ContextMenu {
                        MenuItem { text: qsTr("Default"); onClicked: editor.updateKey("style", "auto") }
                        MenuItem { text: qsTr("Button"); onClicked: editor.updateKey("style", "button") }
                        MenuItem { text: qsTr("Plain"); onClicked: editor.updateKey("style", "plain") }
                    }
                }
                FutoEditorComboBox {
                    objectName: "destinationSelector"
                    width: parent.width; visible: editor.selectedKey && editor.selectedKey.action === "page"; label: qsTr("Destination page")
                    selectedIndex: editor.selectedKey ? Custom.pageIndex(editor.document, editor.selectedKey.target) : 0
                    menu: ContextMenu { Repeater { model: editor.pageChoices; MenuItem { text: modelData.name; onClicked: editor.updateKey("target", modelData.id) } } }
                }
                Row {
                    objectName: "keyWidthControls"
                    width: parent.width
                    FutoEditorRepeatTool {
                        objectName: "keyWidthDecrease"
                        anchors.verticalCenter: parent.verticalCenter
                        actionId: "width-decrease"; description: qsTr("Decrease key width")
                        enabled: editor.selectedKey && editor.selectedKey.width > 0.25
                        onInteractionStarted: editor.remember()
                        onStepRequested: editor.setWidth(Math.round((editor.selectedKey.width - 0.05) * 100) / 100)
                    }
                    Slider {
                        id: keyWidth
                        objectName: "keyWidthSlider"
                        width: parent.width - 2 * Theme.itemSizeSmall; minimumValue: 0.25; maximumValue: 20; stepSize: 0.05; label: qsTr("Key width")
                        valueText: value.toFixed(2)
                        Binding { target: keyWidth; property: "value"; value: editor.selectedKey ? editor.selectedKey.width : 1; when: !keyWidth.pressed }
                        onPressedChanged: { if (pressed) editor.remember() }
                        onValueChanged: if (pressed) editor.setWidth(value)
                    }
                    FutoEditorRepeatTool {
                        objectName: "keyWidthIncrease"
                        anchors.verticalCenter: parent.verticalCenter
                        actionId: "width-increase"; description: qsTr("Increase key width")
                        enabled: editor.selectedKey && editor.selectedKey.width < 20
                        onInteractionStarted: editor.remember()
                        onStepRequested: editor.setWidth(Math.round((editor.selectedKey.width + 0.05) * 100) / 100)
                    }
                }
                TextSwitch {
                    width: parent.width; visible: editor.selectedKey && editor.selectedKey.action === "text"
                    text: qsTr("Use as a dead key"); automaticCheck: false; checked: editor.selectedKey ? editor.selectedKey.dead : false
                    onClicked: editor.updateKey("dead", !checked)
                }
                Label {
                    x: Theme.paddingMedium; width: parent.width - 2 * x; wrapMode: Text.Wrap; font.pixelSize: Theme.fontSizeExtraSmall; color: Theme.secondaryColor
                    visible: editor.reservedKey || editor.selectedKey && editor.selectedKey.action !== "spacer"
                    text: editor.reservedKey ? qsTr("Long-press is reserved for Quick Settings at the bottom-left of every page. Its normal action and width can still change.") : qsTr("Long-press alternatives: one character or text sequence per line.")
                }
                Row {
                    objectName: "longPressAlternativesRow"
                    width: parent.width; visible: !editor.reservedKey && editor.selectedKey && editor.selectedKey.action !== "spacer"
                    TextArea {
                        id: alternatives
                        objectName: "longPressAlternatives"
                        width: parent.width - Theme.itemSizeSmall; label: qsTr("Long-press alternatives")
                        function synchronize() { if (!activeFocus) text = editor.selectedKey ? editor.selectedKey.more.join("\n") : "" }
                        Component.onCompleted: synchronize()
                        onActiveFocusChanged: if (!activeFocus) synchronize()
                        Connections { target: editor; onSelectedKeyChanged: alternatives.synchronize() }
                        onTextChanged: if (activeFocus && editor.selectedKey && text !== editor.selectedKey.more.join("\n")) {
                            var values = text.split("\n").filter(function(value) { return value !== "" })
                            editor.updateAlternatives(values)
                        }
                    }
                    FutoEditorTool { objectName: "longPressCharacterPicker"; anchors.verticalCenter: parent.verticalCenter; actionId: "characters"; description: qsTr("Add long-press character"); onClicked: editor.chooseCharacter("more") }
                }
                FutoEditorComboBox {
                    objectName: "alternativeSelector"
                    width: parent.width; visible: !editor.reservedKey && editor.selectedKey && editor.selectedKey.action !== "spacer" && editor.selectedKey.more.length > 0
                    label: qsTr("Default long-press choice"); selectedIndex: editor.selectedKey && editor.selectedKey.more.length ? editor.selectedKey.defaultMore : -1
                    menu: ContextMenu { Repeater { model: editor.selectedKey ? editor.selectedKey.more : []; MenuItem { text: modelData; onClicked: editor.updateKey("defaultMore", index) } } }
                }
                SectionHeader { text: qsTr("Pages") }
                TextField { width: parent.width; label: qsTr("Page name"); text: editor.pageData.name; onTextChanged: if (activeFocus && text !== editor.pageData.name) { editor.remember(); editor.editablePage().name = text; editor.changed() } }
                FutoEditorComboBox {
                    objectName: "pageTypeSelector"
                    width: parent.width; label: qsTr("Page type"); selectedIndex: ["text", "symbols", "function"].indexOf(editor.pageData.kind)
                    menu: ContextMenu { MenuItem { text: qsTr("Typing (show suggestions)"); onClicked: { editor.remember(); editor.editablePage().kind = "text"; editor.changed() } } MenuItem { text: qsTr("Symbols"); onClicked: { editor.remember(); editor.editablePage().kind = "symbols"; editor.changed() } } MenuItem { text: qsTr("Function keys"); onClicked: { editor.remember(); editor.editablePage().kind = "function"; editor.changed() } } }
                }
            }
        }
        FutoEditorPagePicker {
            id: pagePicker
            objectName: "editorPagePicker"
            anchors.fill: parent
            active: editor.pagePickerOpen && editor.status === PageStatus.Active
            enabled: active
            opacity: editor.pagePickerOpen ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            transform: Translate {
                x: editor.pagePickerOpen ? 0 : Theme.paddingLarge
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }
            pages: editor.pageChoices
            selectedPageId: editor.pageData.id
            onChosen: editor.choosePage(id)
            onReordered: editor.movePage(id, target)
            onDeleteRequested: editor.deletePage(id)
            onAddRequested: editor.addPage()
        }
    }
}
