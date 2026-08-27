/* Add one account to the encrypted FUTO password vault. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.DBus 2.0

Page {
    id: page
    allowedOrientations: Orientation.All

    property string vaultToken: ""
    property var vaultHelper: null
    property bool busy
    property string statusText: ""

    function saveLogin() {
        if (busy || vaultToken === "" || passwordField.text === ""
                || (labelField.text.trim() === "" && originField.text.trim() === ""))
            return
        busy = true
        statusText = ""
        helper.typedCall("SaveCredential", [
            { "type": "s", "value": vaultToken },
            { "type": "s", "value": labelField.text },
            { "type": "s", "value": originField.text },
            { "type": "s", "value": usernameField.text },
            { "type": "s", "value": passwordField.text }
        ], function(saved) {
            page.busy = false
            if (saved) {
                labelField.text = ""
                originField.text = ""
                usernameField.text = ""
                passwordField.text = ""
                page.statusText = qsTr("Account saved")
            } else {
                page.statusText = qsTr("Could not save this account. Check the details or duplicate entries")
            }
        }, function() {
            page.busy = false
            page.statusText = qsTr("The vault session expired. Reopen Saved passwords")
        })
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

            PageHeader { title: qsTr("Add account") }

            TextField {
                id: labelField
                width: parent.width
                label: qsTr("Name")
                placeholderText: qsTr("Example: Personal mail")
                inputMethodHints: Qt.ImhNoPredictiveText
            }

            TextField {
                id: originField
                width: parent.width
                label: qsTr("Website or app")
                placeholderText: qsTr("example.com or app://package.name")
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
            }

            TextField {
                id: usernameField
                width: parent.width
                label: qsTr("Username")
                placeholderText: qsTr("Username or email")
                inputMethodHints: Qt.ImhNoPredictiveText
            }

            TextField {
                id: passwordField
                width: parent.width
                label: qsTr("Password")
                placeholderText: qsTr("Password")
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                enabled: !page.busy && passwordField.text !== ""
                         && (labelField.text.trim() !== ""
                             || originField.text.trim() !== "")
                text: qsTr("Save account")
                onClicked: page.saveLogin()
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
