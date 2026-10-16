import QtQuick 2.6
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import "FutoCustomLayouts.js" as Custom

Page {
    id: page
    allowedOrientations: Orientation.All
    FutoEditorTooltip {}
    property var document
    property string payload: ""
    readonly property bool testing: status === PageStatus.Active && Qt.application.state === Qt.ApplicationActive
    function synchronize() {
        if (testing && payload !== "") {
            preview.document = payload
            preview.expires = Date.now() + 6000
            focusTimer.restart()
        } else if (preview.document === payload) {
            preview.expires = 0
            preview.document = ""
        }
    }
    ConfigurationGroup {
        id: preview
        path: "/sailfish/text_input/futo_keyboard/layoutEditorPreview"
        property string document: ""
        property double expires: 0
    }
    Component.onCompleted: {
        if (typeof layoutEditorProcessId !== "undefined" && Custom.valid(document, false))
            payload = JSON.stringify({owner: Number(layoutEditorProcessId), layout: Custom.clone(document)})
        synchronize()
    }
    Component.onDestruction: if (preview.document === payload) { preview.expires = 0; preview.document = "" }
    onTestingChanged: synchronize()
    Timer { interval: 2000; running: page.testing; repeat: true; onTriggered: preview.expires = Date.now() + 6000 }
    Timer { id: focusTimer; interval: 180; onTriggered: if (page.testing) { field.forceActiveFocus(); Qt.inputMethod.show() } }
    Row {
        id: toolbar
        width: parent.width
        FutoEditorTool { actionId: "back"; description: qsTr("Back to editor"); onClicked: { Qt.inputMethod.hide(); pageStack.pop() } }
        Label { width: parent.width - 2 * Theme.itemSizeSmall; height: Theme.itemSizeSmall; text: page.document.name; textFormat: Text.PlainText; verticalAlignment: Text.AlignVCenter; truncationMode: TruncationMode.Fade; color: Theme.highlightColor }
        FutoEditorTool { actionId: "clear"; description: qsTr("Clear test text"); onClicked: { field.text = ""; field.forceActiveFocus() } }
    }
    SilicaFlickable {
        anchors.top: toolbar.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.topMargin: Theme.paddingLarge
        contentHeight: field.height
        TextArea {
            id: field
            objectName: "layoutTestText"
            width: parent.width
            placeholderText: qsTr("Try your keyboard here")
            label: qsTr("Test text is not saved or learned")
        }
    }
}
