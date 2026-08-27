/* On-demand personal dictionary manager for FUTO Keyboard. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.DBus 2.0

Page {
    id: page
    allowedOrientations: Orientation.All
    property string statusText: ""
    property bool authorizationInherited: false
    readonly property bool accessGranted: authorizationInherited

    function refreshWords() {
        helper.typedCall("ListPersonalWords", [], function(resultJson) {
            var words = []
            try {
                words = JSON.parse(String(resultJson))
            } catch (error) {
                words = []
            }
            personalWords.clear()
            for (var i = 0; i < words.length; ++i) {
                personalWords.append({ "word": String(words[i].word),
                                       "frequency": Number(words[i].count) })
            }
        }, function() {
            page.statusText = qsTr("Could not read learned words")
        })
    }

    Component.onCompleted: {
        if (authorizationInherited)
            refreshWords()
    }

    ListModel { id: personalWords }

    DBusInterface {
        id: helper
        bus: DBus.SessionBus
        service: "org.hb.FutoKeyboard1"
        path: "/org/hb/FutoKeyboard1"
        iface: "org.hb.FutoKeyboard1"
        watchServiceStatus: true
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        visible: page.accessGranted
        model: personalWords
        VerticalScrollDecorator {}

        header: Column {
            width: listView.width

            PageHeader { title: qsTr("Personal dictionary") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("This list is loaded only while this page is open. A learned word is "
                           + "trusted for correction after it has been used twice.")
            }

            TextField {
                id: personalWordInput
                width: parent.width
                label: qsTr("Add a personal word")
                placeholderText: qsTr("Word")
                inputMethodHints: Qt.ImhNoPredictiveText
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                enabled: personalWordInput.text.trim() !== ""
                text: qsTr("Add word")
                onClicked: helper.typedCall("AddPersonalWord", [
                    { "type": "s", "value": personalWordInput.text.trim() }
                ], function(added) {
                    page.statusText = added ? qsTr("Personal word added")
                                            : qsTr("That is not a valid word")
                    if (added) {
                        personalWordInput.text = ""
                        page.refreshWords()
                    }
                }, function() {
                    page.statusText = qsTr("Could not add the word")
                })
            }

            SectionHeader {
                text: qsTr("Learned words") + " (" + personalWords.count + ")"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: visible ? implicitHeight + Theme.paddingLarge : 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                text: qsTr("No learned words yet")
                visible: personalWords.count === 0
            }
        }

        delegate: Item {
            width: listView.width
            height: Theme.itemSizeSmall

            Label {
                anchors.left: parent.left
                anchors.leftMargin: Theme.horizontalPageMargin
                anchors.right: removeButton.left
                anchors.verticalCenter: parent.verticalCenter
                truncationMode: TruncationMode.Fade
                text: word + (frequency > 1 ? "  ·  " + frequency : "")
            }

            IconButton {
                id: removeButton
                anchors.right: parent.right
                anchors.rightMargin: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                icon.source: "image://theme/icon-m-delete"
                onClicked: helper.typedCall("RemovePersonalWord", [
                    { "type": "s", "value": word }
                ], function() {
                    page.refreshWords()
                }, function() {
                    page.statusText = qsTr("Could not remove the word")
                })
            }
        }

        footer: Column {
            width: listView.width
            spacing: Theme.paddingMedium

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Clear learned words")
                visible: personalWords.count > 0
                onClicked: Remorse.popupAction(page, qsTr("Clearing learned data"), function() {
                    helper.typedCall("ClearPersonalWords", [], function(cleared) {
                        page.statusText = cleared ? qsTr("Learned data cleared")
                                                  : qsTr("No learned data was cleared")
                        page.refreshWords()
                    }, function() {
                        page.statusText = qsTr("Could not clear learned data")
                    })
                })
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: page.statusText
                visible: text !== ""
            }

            Item { width: 1; height: Theme.paddingLarge }
        }
    }

    Item {
        anchors.fill: parent
        visible: !page.accessGranted

        PageHeader { title: qsTr("Personal dictionary") }

        Label {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Theme.horizontalPageMargin
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: Theme.secondaryColor
            text: qsTr("Open this page through Manage learned data")
        }
    }
}
