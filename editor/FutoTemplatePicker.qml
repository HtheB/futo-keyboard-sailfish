import QtQuick 2.6
import Sailfish.Silica 1.0
import "FutoLetterLayouts.js" as Layouts
import "FutoEditorLayoutSearch.js" as LayoutSearch

Dialog {
    id: picker
    allowedOrientations: Orientation.LandscapeMask
    property int selectedIndex: -1
    canAccept: selectedIndex >= 0
    property var choices: []
    property var searchIndex: []
    function filter(text) {
        if (searchIndex.length === 0)
            searchIndex = LayoutSearch.build(Layouts)
        choices = LayoutSearch.filter(searchIndex, text)
    }
    Component.onCompleted: filter("")
    Column {
        id: header; width: parent.width
        DialogHeader { title: qsTr("Copy a keyboard layout"); acceptText: qsTr("Copy") }
        SearchField { width: parent.width; placeholderText: qsTr("Find a layout"); onTextChanged: picker.filter(text) }
    }
    SilicaListView {
        anchors.top: header.bottom; anchors.bottom: parent.bottom; width: parent.width
        model: picker.choices; clip: true
        VerticalScrollDecorator {}
        delegate: BackgroundItem {
            width: ListView.view.width
            highlighted: pressed || picker.selectedIndex === modelData.index
            Label {
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                anchors.verticalCenter: parent.verticalCenter
                // Keep the native name before its English hint in mixed RTL text.
                text: "\u200e" + modelData.name; textFormat: Text.PlainText
                horizontalAlignment: Text.AlignLeft; elide: Text.ElideRight
                color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
            }
            onClicked: { picker.selectedIndex = modelData.index; picker.accept() }
        }
    }
}
