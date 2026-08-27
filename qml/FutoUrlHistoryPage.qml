/* On-demand URL history manager for FUTO Keyboard. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.DBus 2.0

Page {
    id: page
    allowedOrientations: Orientation.All
    property bool authorizationInherited: false
    property string statusText: ""

    function refreshURLs() {
        if (!authorizationInherited)
            return
        helper.typedCall("ListURLs", [], function(resultJson) {
            var urls = []
            try {
                urls = JSON.parse(String(resultJson))
            } catch (error) {
                urls = []
            }
            urlModel.clear()
            for (var i = 0; i < urls.length; ++i) {
                urlModel.append({ "urlText": String(urls[i].text),
                                  "frequency": Number(urls[i].count),
                                  "lastUsed": Number(urls[i].lastUsed) })
            }
        }, function() {
            page.statusText = qsTr("Could not read saved URLs")
        })
    }

    Component.onCompleted: refreshURLs()

    ListModel { id: urlModel }

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
        visible: page.authorizationInherited
        model: urlModel
        VerticalScrollDecorator {}

        header: Column {
            width: listView.width
            PageHeader { title: qsTr("Saved URLs") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("URLs are stored only when URL history is enabled. Password and "
                           + "Incognito fields are excluded.")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: visible ? implicitHeight + Theme.paddingLarge : 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                text: qsTr("No saved URLs yet")
                visible: urlModel.count === 0
            }
        }

        delegate: Item {
            width: listView.width
            height: Theme.itemSizeSmall

            Label {
                anchors.left: parent.left
                anchors.leftMargin: Theme.horizontalPageMargin
                anchors.right: removeButton.left
                anchors.rightMargin: Theme.paddingMedium
                anchors.verticalCenter: parent.verticalCenter
                truncationMode: TruncationMode.Fade
                text: urlText + (frequency > 1 ? "  ·  " + frequency : "")
            }

            IconButton {
                id: removeButton
                anchors.right: parent.right
                anchors.rightMargin: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                icon.source: "image://theme/icon-m-delete"
                onClicked: helper.typedCall("RemoveURL", [
                    { "type": "s", "value": urlText }
                ], function() {
                    page.refreshURLs()
                }, function() {
                    page.statusText = qsTr("Could not remove the URL")
                })
            }
        }

        footer: Column {
            width: listView.width
            spacing: Theme.paddingMedium

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: urlModel.count > 0
                text: qsTr("Clear saved URLs")
                onClicked: Remorse.popupAction(page, qsTr("Clearing saved URLs"), function() {
                    helper.typedCall("ClearURLs", [], function() {
                        page.refreshURLs()
                    }, function() {
                        page.statusText = qsTr("Could not clear saved URLs")
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
}
