import QtQuick 2.6
import Sailfish.Silica 1.0
import "FutoLetterLayouts.js" as Layouts

Dialog {
    id: picker
    allowedOrientations: Orientation.LandscapeMask
    property int selectedIndex: -1
    canAccept: selectedIndex >= 0
    property var choices: []
    function filter(text) {
        var result = []
        for (var i = 0; i < Layouts.builtinCount; ++i)
            if ((!Layouts.imeHint(i) || Layouts.imeHint(i) === "qwerty")
                    && Layouts.name(i).toLowerCase().indexOf(text.toLowerCase()) >= 0)
                result.push({index: i, name: Layouts.name(i)})
        choices = result
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
            Label { x: Theme.horizontalPageMargin; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; textFormat: Text.PlainText; color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor }
            onClicked: { picker.selectedIndex = modelData.index; picker.accept() }
        }
    }
}
