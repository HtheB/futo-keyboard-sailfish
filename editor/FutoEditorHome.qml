import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import Nemo.DBus 2.0
import "FutoCustomLayouts.js" as Custom
import "FutoLetterLayouts.js" as Layouts

Page {
    id: home
    allowedOrientations: Orientation.LandscapeMask
    property var layouts: []
    property string message: ""
    property bool busy: false

    function load(raw) {
        var data = Custom.parse(String(raw))
        if (!data) { message = qsTr("Could not read custom layouts"); return }
        layouts = data.layouts
        message = ""
    }
    function refresh() {
        if (helper.status === DBusInterface.Available)
            helper.typedCall("ListCustomLayouts", [], function(raw) { home.load(raw) }, function() { home.message = qsTr("Could not read custom layouts") })
    }
    function edit(document, duplicate) {
        var copy = Custom.clone(document)
        if (duplicate) { copy.id = ""; copy.name += qsTr(" copy") }
        pageStack.push(Qt.resolvedUrl("FutoEditorPage.qml"), {document: copy})
    }
    function copyBuiltin() {
        var picker = pageStack.push(Qt.resolvedUrl("FutoTemplatePicker.qml"))
        picker.accepted.connect(function() {
            var copy = Custom.fromBuiltin(picker.selectedIndex, Layouts)
            if (copy) home.edit(copy, false)
        })
    }
    function exportLayout(id, share) {
        if (busy) return
        busy = true
        message = ""
        helper.typedCall("ExportCustomLayout", [{type: "s", value: id}], function(path) {
            home.busy = false
            path = String(path)
            if (!path || path.charAt(0) !== "/" || path.slice(-11) !== ".futolayout") {
                home.exportFailed(); return
            }
            pageStack.push(Qt.resolvedUrl("FutoEditorExportPage.qml"), {filePath: path, shareImmediately: !!share})
        }, function() { home.busy = false; home.exportFailed() })
    }
    function exportFailed() { message = qsTr("Could not export the layout"); feedback.show(message) }
    function showAbout() { pageStack.push(Qt.resolvedUrl("FutoEditorAboutPage.qml")) }
    DBusInterface {
        id: helper
        bus: DBus.SessionBus; service: "org.hb.FutoKeyboard1"; path: "/org/hb/FutoKeyboard1"; iface: "org.hb.FutoKeyboard1"
        watchServiceStatus: true
        onStatusChanged: if (status === DBusInterface.Available) home.refresh()
    }
    onStatusChanged: if (status === PageStatus.Active) refresh()
    Component.onCompleted: refresh()
    RemorsePopup { id: deleteRemorse }
    FutoEditorToast {
        id: feedback
        objectName: "homeFeedback"
        duration: 5000
        pageActive: home.status === PageStatus.Active && Qt.application.state === Qt.ApplicationActive
    }
    Component {
        id: importPicker
        FilePickerPage {
            allowedOrientations: Orientation.LandscapeMask
            title: qsTr("Import keyboard layout")
            nameFilters: ["*.futolayout"]
            onSelectedContentPropertiesChanged: {
                var path = selectedContentProperties.filePath
                if (path) helper.typedCall("ImportCustomLayout", [{type: "s", value: String(path)}], function(raw) {
                    home.load(raw)
                    home.message = qsTr("Layout imported. Select it in the keyboard's Layout view.")
                }, function(name, detail) { home.message = String(detail || qsTr("Could not import this layout")) })
            }
        }
    }
    PageHeader { id: header; title: qsTr("FUTO Layout Editor") }
    SilicaFlickable {
        id: actions
        objectName: "editorHomeActions"
        anchors.left: parent.left; anchors.top: header.bottom; anchors.bottom: parent.bottom
        width: parent.width * 0.44
        clip: true
        contentHeight: actionsColumn.height + Theme.paddingLarge
        VerticalScrollDecorator {}
        Column {
            id: actionsColumn
            width: parent.width
            FutoSettingsMenuItem {
                objectName: "newLayoutButton"
                showArrow: false
                width: parent.width; enabled: !home.busy
                text: qsTr("New blank layout"); iconSource: "image://theme/icon-m-add"
                onClicked: home.edit(Custom.blank(qsTr("My layout")), false)
            }
            FutoSettingsMenuItem {
                objectName: "copyLayoutButton"
                showArrow: false
                width: parent.width; enabled: !home.busy
                text: qsTr("Copy existing layout"); iconSource: "image://theme/icon-m-clipboard"
                onClicked: home.copyBuiltin()
            }
            FutoSettingsMenuItem {
                objectName: "importLayoutButton"
                showArrow: false
                width: parent.width; enabled: !home.busy
                text: qsTr("Import"); iconSource: "image://theme/icon-m-downloads"
                onClicked: pageStack.push(importPicker)
            }
            FutoSettingsMenuItem {
                objectName: "editorAboutButton"
                showArrow: false
                width: parent.width; enabled: !home.busy
                text: qsTr("About"); iconSource: "image://theme/icon-m-about"
                onClicked: home.showAbout()
            }
            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                size: BusyIndicatorSize.Small; running: home.busy
                visible: running; height: visible ? implicitHeight : 0
            }
            Label {
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                visible: home.message !== ""; text: home.message; textFormat: Text.PlainText
                wrapMode: Text.Wrap; color: Theme.highlightColor
            }
        }
    }
    Rectangle {
        anchors.left: actions.right; anchors.top: header.bottom; anchors.bottom: parent.bottom
        anchors.topMargin: Theme.paddingMedium; anchors.bottomMargin: Theme.paddingLarge
        width: 1; color: Theme.rgba(Theme.primaryColor, 0.08)
    }
    SectionHeader {
        id: savedHeader
        objectName: "savedLayoutsHeader"
        anchors.left: actions.right; anchors.right: parent.right; anchors.top: header.bottom
        anchors.leftMargin: Theme.horizontalPageMargin; anchors.rightMargin: header.rightMargin
        text: qsTr("Saved layouts")
    }
    SilicaFlickable {
        objectName: "editorHomeSavedLayouts"
        anchors.left: actions.right; anchors.right: parent.right
        anchors.top: savedHeader.bottom; anchors.bottom: parent.bottom
        clip: true
        contentHeight: savedColumn.height + Theme.paddingLarge
        VerticalScrollDecorator {}
        Column {
            id: savedColumn
            width: parent.width
            Label {
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                visible: home.layouts.length === 0
                text: qsTr("Start with a blank keyboard or copy an existing layout.")
                wrapMode: Text.Wrap; color: Theme.secondaryColor
            }
            Repeater {
                model: home.layouts
                ListItem {
                    id: entry
                    objectName: "savedLayout-" + layoutDocument.id
                    readonly property var layoutDocument: modelData
                    width: savedColumn.width
                    contentHeight: Theme.itemSizeMedium
                    enabled: !home.busy
                    onClicked: home.edit(layoutDocument, false)
                    Label { x: Theme.horizontalPageMargin; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 2 * x; text: entry.layoutDocument.name + qsTr(" (Custom)"); textFormat: Text.PlainText; truncationMode: TruncationMode.Fade }
                    menu: ContextMenu {
                        MenuItem { text: qsTr("Edit"); onClicked: home.edit(entry.layoutDocument, false) }
                        MenuItem { text: qsTr("Duplicate"); onClicked: home.edit(entry.layoutDocument, true) }
                        MenuItem { objectName: "exportLayoutMenuItem"; text: qsTr("Export"); onClicked: home.exportLayout(entry.layoutDocument.id, false) }
                        MenuItem { objectName: "shareLayoutMenuItem"; text: qsTr("Share"); onClicked: home.exportLayout(entry.layoutDocument.id, true) }
                        MenuItem {
                            text: qsTr("Delete")
                            onClicked: {
                                var id = entry.layoutDocument.id
                                deleteRemorse.execute(qsTr("Deleting layout"), function() {
                                    helper.typedCall("DeleteCustomLayout", [{type: "s", value: id}], function(raw) { home.load(raw) }, function() { home.message = qsTr("Could not delete the layout") })
                                })
                            }
                        }
                    }
                }
            }
        }
    }
}
