/* View, copy, edit and delete one encrypted saved login. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.DBus 2.0

Page {
    id: page
    allowedOrientations: Orientation.All

    property string vaultToken: ""
    property var vaultHelper: null
    property string entryId: ""
    property string entryLabel: ""
    property string entryOrigin: ""
    property string entryUsername: ""
    property bool editMode
    property bool busy
    property bool passwordVisible
    property string statusText: ""
    property string originalLabel: ""
    property string originalOrigin: ""
    property string originalUsername: ""
    property string originalPassword: ""

    signal credentialChanged()

    function loadPassword() {
        busy = true
        helper.typedCall("CredentialSecret", [
            { "type": "s", "value": vaultToken },
            { "type": "s", "value": entryId },
            { "type": "s", "value": "password" }
        ], function(password) {
            busy = false
            passwordField.text = String(password)
            originalPassword = passwordField.text
            securityTimer.restart()
        }, function() {
            busy = false
            statusText = qsTr("The vault session expired. Reopen Saved passwords")
        })
    }

    function beginEditing() {
        originalLabel = labelField.text
        originalOrigin = originField.text
        originalUsername = usernameField.text
        originalPassword = passwordField.text
        editMode = true
        statusText = ""
    }

    function cancelEditing() {
        labelField.text = originalLabel
        originField.text = originalOrigin
        usernameField.text = originalUsername
        passwordField.text = originalPassword
        editMode = false
        passwordVisible = false
        statusText = ""
    }

    function saveChanges() {
        if (busy || passwordField.text === ""
                || (labelField.text.trim() === "" && originField.text.trim() === ""))
            return
        busy = true
        helper.typedCall("UpdateCredential", [
            { "type": "s", "value": vaultToken },
            { "type": "s", "value": entryId },
            { "type": "s", "value": labelField.text },
            { "type": "s", "value": originField.text },
            { "type": "s", "value": usernameField.text },
            { "type": "s", "value": passwordField.text }
        ], function(updated) {
            busy = false
            if (updated) {
                entryLabel = labelField.text.trim()
                entryOrigin = originField.text.trim()
                entryUsername = usernameField.text.trim()
                originalLabel = labelField.text
                originalOrigin = originField.text
                originalUsername = usernameField.text
                originalPassword = passwordField.text
                editMode = false
                passwordVisible = false
                securityTimer.restart()
                statusText = qsTr("Login updated")
                credentialChanged()
            } else {
                statusText = qsTr("Could not update this login. Check for a duplicate")
            }
        }, function() {
            busy = false
            statusText = qsTr("Could not update this login")
        })
    }

    function copyValue(value, description, sensitive) {
        value = String(value)
        if (value === "")
            return
        helper.typedCall("SuppressClipboardCapture", [
            { "type": "s", "value": vaultToken },
            { "type": "s", "value": value }
        ], function(accepted) {
            if (!accepted) {
                statusText = qsTr("Could not copy securely")
                return
            }
            Clipboard.text = value
            securityTimer.restart()
            statusText = sensitive
                    ? qsTr("%1 copied. Clear the system clipboard when finished").arg(description)
                    : qsTr("%1 copied").arg(description)
        }, function() {
            statusText = qsTr("Could not copy securely")
        })
    }

    function deleteCredential() {
        helper.typedCall("DeleteCredential", [
            { "type": "s", "value": vaultToken },
            { "type": "s", "value": entryId }
        ], function(deleted) {
            if (deleted) {
                credentialChanged()
                pageStack.pop()
            } else {
                statusText = qsTr("Could not delete this login")
            }
        }, function() {
            statusText = qsTr("Could not delete this login")
        })
    }

    Component.onCompleted: {
        labelField.text = entryLabel
        originField.text = entryOrigin
        usernameField.text = entryUsername
        originalLabel = entryLabel
        originalOrigin = entryOrigin
        originalUsername = entryUsername
        loadPassword()
    }

    onStatusChanged: {
        if (status !== PageStatus.Active)
            passwordVisible = false
    }

    DBusInterface {
        id: helper
        bus: DBus.SessionBus
        service: "org.hb.FutoKeyboard1"
        path: "/org/hb/FutoKeyboard1"
        iface: "org.hb.FutoKeyboard1"
        watchServiceStatus: true
    }

    Timer {
        id: securityTimer
        interval: 120000
        repeat: false
        onTriggered: {
            passwordField.text = ""
            page.passwordVisible = false
            pageStack.pop()
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge
        clip: true
        VerticalScrollDecorator { flickable: parent }

        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingSmall

            PageHeader { title: qsTr("Login details") }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: page.busy
                visible: running
                size: BusyIndicatorSize.Medium
            }

            TextField {
                id: labelField
                width: parent.width
                label: qsTr("Name")
                placeholderText: qsTr("Name")
                readOnly: !page.editMode
                inputMethodHints: Qt.ImhNoPredictiveText
            }

            TextField {
                id: originField
                width: parent.width
                label: qsTr("Website")
                placeholderText: qsTr("Website")
                readOnly: !page.editMode
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Copy website")
                enabled: originField.text !== ""
                onClicked: page.copyValue(originField.text, qsTr("Website"), false)
            }

            TextField {
                id: usernameField
                width: parent.width
                label: qsTr("Username")
                placeholderText: qsTr("Username")
                readOnly: !page.editMode
                inputMethodHints: Qt.ImhNoPredictiveText
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Copy username")
                enabled: usernameField.text !== ""
                onClicked: page.copyValue(usernameField.text, qsTr("Username"), false)
            }

            TextField {
                id: passwordField
                width: parent.width
                label: qsTr("Password")
                placeholderText: qsTr("Password")
                readOnly: !page.editMode
                echoMode: page.passwordVisible ? TextInput.Normal : TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
            }

            TextSwitch {
                width: parent.width
                text: qsTr("Show password")
                checked: page.passwordVisible
                automaticCheck: false
                onClicked: page.passwordVisible = !page.passwordVisible
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Copy password")
                enabled: passwordField.text !== ""
                onClicked: page.copyValue(passwordField.text, qsTr("Password"), true)
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !page.editMode
                text: qsTr("Edit login")
                onClicked: page.beginEditing()
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: page.editMode
                spacing: Theme.paddingMedium

                Button {
                    text: qsTr("Cancel")
                    onClicked: page.cancelEditing()
                }

                Button {
                    text: qsTr("Save")
                    enabled: !page.busy && passwordField.text !== ""
                             && (labelField.text.trim() !== ""
                                 || originField.text.trim() !== "")
                    onClicked: page.saveChanges()
                }
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !page.editMode
                text: qsTr("Delete login")
                onClicked: Remorse.popupAction(page, qsTr("Deleting login"), function() {
                    page.deleteCredential()
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
        }
    }
}
