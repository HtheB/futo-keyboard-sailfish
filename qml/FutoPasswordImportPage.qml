/* Import browser/password-manager CSV files into the encrypted vault. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import Nemo.DBus 2.0

Page {
    id: page
    allowedOrientations: Orientation.All

    property string vaultToken: ""
    property var vaultHelper: null
    property bool busy
    property string statusText: ""

    function choosePasswordCSV() {
        if (!busy && vaultToken !== "")
            pageStack.push(csvFilePicker, { "title": qsTr("Select password export") })
    }

    function importPasswords(filePath) {
        filePath = String(filePath || "")
        if (busy || vaultToken === "" || filePath === "")
            return
        busy = true
        statusText = qsTr("Importing passwords…")
        helper.typedCall("ImportPasswordsFromFile", [
            { "type": "s", "value": vaultToken },
            { "type": "s", "value": filePath }
        ], function(resultJson) {
            page.busy = false
            var result = { "imported": 0, "skipped": 0, "error": "" }
            try { result = JSON.parse(String(resultJson)) } catch (error) {}
            if (String(result.error || "") !== "") {
                page.statusText = String(result.error)
                return
            }
            var source = String(result.source || qsTr("password CSV"))
            page.statusText = qsTr("Imported %1 passwords from %2; skipped %3")
                    .arg(Number(result.imported)).arg(source)
                    .arg(Number(result.skipped))
        }, function() {
            page.busy = false
            page.statusText = qsTr("Import failed. Reopen Saved passwords and try again")
        })
    }

    Component {
        id: csvFilePicker
        FilePickerPage {
            nameFilters: [ "*.csv" ]
            onSelectedContentPropertiesChanged: {
                var filePath = selectedContentProperties.filePath
                if (filePath)
                    page.importPasswords(filePath)
            }
        }
    }

    DBusInterface {
        id: helper
        bus: DBus.SessionBus
        service: "org.hb.FutoKeyboard1"
        path: "/org/hb/FutoKeyboard1"
        iface: "org.hb.FutoKeyboard1"
        watchServiceStatus: true
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
        clip: true
        VerticalScrollDecorator { flickable: parent }

        Column {
            id: content
            width: parent.width

            PageHeader { title: qsTr("Import passwords") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Choose a CSV exported by a browser or password manager. "
                           + "FUTO automatically detects Firefox, Chromium browsers, "
                           + "Apple Passwords, 1Password, Bitwarden, LastPass, KeePass, "
                           + "Dropbox Passwords, Keeper, Dashlane, RoboForm, NordPass, "
                           + "Proton Pass, and compatible generic CSV files.")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("CSV files contain plaintext passwords. Delete the export after a successful import.")
            }

            Item { width: 1; height: Theme.paddingLarge }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Choose password export")
                enabled: !page.busy
                onClicked: page.choosePasswordCSV()
            }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: page.busy
                visible: running
                size: BusyIndicatorSize.Small
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
        }
    }
}
