import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import Nemo.DBus 2.0

Page {
    id: page
    allowedOrientations: Orientation.All
    property string statusText: ""

    readonly property var retentionValues: [1800, 3600, 10800, 18000,
                                             36000, 86400, -1]

    function retentionIndex(value) {
        var index = retentionValues.indexOf(Number(value))
        return index >= 0 ? index : 1
    }

    ConfigurationGroup {
        id: settings
        path: "/sailfish/text_input/futo_keyboard"
        property bool clipboardHistoryEnabled: false
        property int clipboardRetentionSeconds: 3600
        property bool clipboardReturnAfterPaste: true
    }

    DBusInterface {
        id: helper
        bus: DBus.SessionBus
        service: "org.hb.FutoKeyboard1"
        path: "/org/hb/FutoKeyboard1"
        iface: "org.hb.FutoKeyboard1"
    }

    FutoSettingsTestPanel {
        id: testPanel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        pageItem: page
    }

    SilicaFlickable {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: testPanel.top
        contentHeight: content.height + Theme.paddingLarge
        VerticalScrollDecorator { flickable: parent }

        Column {
            id: content
            width: parent.width
            PageHeader { title: qsTr("Clipboard") }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.clipboardHistoryEnabled
                text: qsTr("Save clipboard history")
                description: qsTr("Stores a bounded list of copied text in a private local file. "
                                  + "Clipboard changes are ignored while FUTO is in a password, "
                                  + "private, or manual Incognito field.")
                onClicked: settings.clipboardHistoryEnabled = !checked
            }

            ComboBox {
                width: parent.width
                enabled: settings.clipboardHistoryEnabled
                label: qsTr("Delete unpinned clips after")
                currentIndex: page.retentionIndex(settings.clipboardRetentionSeconds)
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && currentIndex < page.retentionValues.length)
                        settings.clipboardRetentionSeconds = page.retentionValues[currentIndex]
                }
                menu: ContextMenu {
                    MenuItem { text: qsTr("30 minutes") }
                    MenuItem { text: qsTr("1 hour") }
                    MenuItem { text: qsTr("3 hours") }
                    MenuItem { text: qsTr("5 hours") }
                    MenuItem { text: qsTr("10 hours") }
                    MenuItem { text: qsTr("24 hours") }
                    MenuItem { text: qsTr("At reboot") }
                }
            }

            TextSwitch {
                width: parent.width
                enabled: settings.clipboardHistoryEnabled
                automaticCheck: false
                checked: settings.clipboardReturnAfterPaste
                text: qsTr("Return to keyboard after pasting")
                description: qsTr("When disabled, Clipboard stays open so the same or several "
                                  + "items can be pasted repeatedly. Use Back to return manually.")
                onClicked: settings.clipboardReturnAfterPaste = !checked
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Open Clipboard from the hold-123 menu. Tap an entry to paste it, or "
                           + "pin it to keep it across expiration and reboot.")
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Clear clipboard history")
                onClicked: Remorse.popupAction(page, qsTr("Clearing clipboard history"), function() {
                    helper.typedCall("ClearClipboardHistory", [], function() {
                        page.statusText = qsTr("Clipboard history cleared")
                    }, function() {
                        page.statusText = qsTr("Could not clear clipboard history")
                    })
                })
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                horizontalAlignment: Text.AlignHCenter
                color: Theme.highlightColor
                text: page.statusText
                visible: text !== ""
            }
        }
    }
}
