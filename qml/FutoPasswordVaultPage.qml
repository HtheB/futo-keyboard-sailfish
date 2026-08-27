/* Device-authenticated, encrypted password vault for FUTO Keyboard. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import Nemo.DBus 2.0

Page {
    id: page
    allowedOrientations: Orientation.All
    property string vaultStatus: "unknown"
    property string statusText: ""
    property bool busy
    property string vaultToken: ""
    property bool authenticationAttempted
    property string brokerNonce: ""
    property bool brokerResultSent
    property string authenticationPurpose: ""
    property bool pendingVaultInitialize

    function returnToPreviousPage() {
        returnToPreviousTimer.start()
    }

    function finishBrokerAuthentication(method) {
        if (brokerResultSent)
            return
        brokerResultSent = true
        helper.typedCall(method, [
            { "type": "s", "value": brokerNonce }
        ], function() {
            Qt.quit()
        }, function() {
            Qt.quit()
        })
    }

    function authenticateForKeyboard() {
        if (brokerNonce === "" || brokerResultSent)
            return
        busy = true
        statusText = ""
        authenticationPurpose = "broker"
        if (!deviceAuthentication.requestPermission(
					qsTr("Authenticate to open saved FUTO passwords"))) {
			busy = false
			statusText = qsTr("Device authentication is unavailable")
		}
    }

    function continueBrokerAuthentication() {
		helper.typedCall("PrepareLearnedEncryptionFromAuthenticatedSettings", [],
						 function(prepared) {
			page.finishBrokerAuthentication(prepared
					? "CompleteVaultAuthentication"
					: "CancelVaultAuthentication")
		}, function() {
			page.finishBrokerAuthentication("CancelVaultAuthentication")
		})
    }

    function continueOpeningVault() {
		helper.typedCall("PrepareLearnedEncryptionFromAuthenticatedSettings", [],
						 function(prepared) {
			if (!prepared) {
				page.busy = false
				page.statusText = qsTr("Encrypted data could not be unlocked")
				page.returnToPreviousPage()
				return
			}
			helper.typedCall(page.pendingVaultInitialize
					? "InitializeVaultFromAuthenticatedSettings"
					: "UnlockVaultFromAuthenticatedSettings", [], function(token) {
				page.busy = false
				page.vaultToken = String(token)
				if (page.vaultToken !== "") {
					page.vaultStatus = "unlocked"
					page.statusText = page.pendingVaultInitialize
							? qsTr("Encrypted password vault created")
							: qsTr("Password vault unlocked")
					page.refreshEntries()
				}
			}, function() {
				page.busy = false
				page.statusText = qsTr("Password vault could not be opened")
				page.returnToPreviousPage()
			})
		}, function() {
			page.busy = false
			page.statusText = qsTr("Encrypted data could not be unlocked")
			page.returnToPreviousPage()
		})
    }

    function authenticationAccepted() {
		if (authenticationPurpose === "broker")
			continueBrokerAuthentication()
		else
			continueOpeningVault()
    }

    function authenticationRejected() {
		busy = false
		statusText = qsTr("Authentication canceled")
		if (authenticationPurpose === "broker")
			finishBrokerAuthentication("CancelVaultAuthentication")
		else
			returnToPreviousPage()
    }

    function scheduleAutomaticAccess() {
        if (!authenticationAttempted && !busy
                && (vaultStatus === "locked" || vaultStatus === "not_initialized"))
            automaticAccessTimer.start()
    }

    function refreshStatus() {
        helper.typedCall("VaultStatus", [], function(result) {
            page.vaultStatus = String(result)
            if (page.vaultStatus === "unlocked" && page.vaultToken !== "")
                page.refreshEntries()
            else {
                if (page.vaultStatus === "unlocked")
                    page.vaultStatus = "locked"
                credentialModel.clear()
                page.scheduleAutomaticAccess()
            }
        }, function() {
            page.vaultStatus = "unavailable"
            page.statusText = qsTr("Password vault is unavailable")
        })
    }

    function refreshEntries() {
        helper.typedCall("ListCredentials", [
            { "type": "s", "value": page.vaultToken }
        ], function(resultJson) {
            var entries = []
            try {
                entries = JSON.parse(String(resultJson))
            } catch (error) {
                entries = []
            }
            credentialModel.clear()
            for (var i = 0; i < entries.length; ++i) {
                credentialModel.append({
                    "entryId": String(entries[i].id),
                    "entryLabel": String(entries[i].label),
                    "entryOrigin": String(entries[i].origin || ""),
                    "entryUsername": String(entries[i].username || "")
                })
            }
        }, function() {
            page.vaultStatus = "locked"
            page.vaultToken = ""
            page.statusText = qsTr("Unlock the password vault again")
        })
    }

    function keepVaultSessionAlive() {
        if (vaultToken === "")
            return
        helper.typedCall("ListCredentials", [
            { "type": "s", "value": vaultToken }
        ], function() {}, function() {
            page.vaultStatus = "locked"
            page.vaultToken = ""
            page.statusText = qsTr("Password vault locked. Authenticate again")
        })
    }

    function openVault(initialize) {
        if (busy)
            return
        authenticationAttempted = true
        busy = true
        statusText = ""
		pendingVaultInitialize = initialize
		authenticationPurpose = "settings"
		if (!deviceAuthentication.requestPermission(
					qsTr("Authenticate to open saved FUTO passwords"))) {
			busy = false
			statusText = qsTr("Device authentication is unavailable")
		}
    }

    function choosePasswordCSV() {
        if (busy || vaultStatus !== "unlocked")
            return
        pageStack.push(csvFilePicker, {
            "title": qsTr("Select password export")
        })
    }

    function importPasswords(filePath) {
        if (busy || vaultStatus !== "unlocked")
            return
        filePath = String(filePath || "")
        if (filePath === "")
            return
        busy = true
        statusText = qsTr("Importing passwords…")
        helper.typedCall("ImportPasswordsFromFile", [
            { "type": "s", "value": page.vaultToken },
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
            page.refreshEntries()
        }, function() {
            page.busy = false
            page.statusText = qsTr("Import failed. Unlock the vault and try again")
        })
    }

    Component.onCompleted: {
        if (brokerNonce !== "")
            brokerAuthenticationTimer.start()
        else
            refreshStatus()
    }
    Component.onDestruction: {
        if (brokerNonce !== "" && !brokerResultSent) {
            helper.typedCall("CancelVaultAuthentication", [
                { "type": "s", "value": brokerNonce }
            ], function() {}, function() {})
        } else if (vaultToken !== "") {
            helper.typedCall("LockVault", [
                { "type": "s", "value": vaultToken }
            ], function() {}, function() {})
        }
    }

    ListModel { id: credentialModel }

    FutoDeviceAuthentication {
        id: deviceAuthentication
        onAccepted: page.authenticationAccepted()
        onRejected: page.authenticationRejected()
    }

    Timer {
        id: returnToPreviousTimer
        interval: 60
        repeat: true
        onTriggered: {
            if (pageStack.busy || pageStack.currentPage !== page)
                return
            stop()
            pageStack.pop()
        }
    }

    Timer {
        id: automaticAccessTimer
        interval: 250
        repeat: false
        onTriggered: page.openVault(page.vaultStatus === "not_initialized")
    }

    Timer {
        id: brokerAuthenticationTimer
        interval: 250
        repeat: false
        onTriggered: page.authenticateForKeyboard()
    }

    Timer {
        id: vaultSessionKeepAliveTimer
        interval: 45000
        repeat: true
        running: page.vaultToken !== "" && Qt.application.active
        onTriggered: page.keepVaultSessionAlive()
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

            PageHeader { title: qsTr("Saved passwords") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Passwords are encrypted with a device-bound Sailfish Secrets key. "
                           + "The vault works in native Sailfish and Android AppSupport fields. "
                           + "It stays unlocked while this section is active and locks when you leave it.")
            }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: page.busy
                visible: running
                size: BusyIndicatorSize.Medium
            }

            Column {
                width: parent.width
                visible: page.vaultStatus === "unlocked"

                FutoSettingsMenuItem {
                    width: parent.width
                    text: qsTr("Add account")
                    iconSource: "image://theme/icon-m-edit"
                    onClicked: pageStack.animatorPush(
                            Qt.resolvedUrl("FutoPasswordAddPage.qml"), {
                                "vaultToken": page.vaultToken,
                                "vaultHelper": helper
                            })
                }

                FutoSettingsMenuItem {
                    width: parent.width
                    text: qsTr("Manage passwords")
                    iconSource: "image://theme/icon-m-device-lock"
                    onClicked: pageStack.animatorPush(
                            Qt.resolvedUrl("FutoPasswordManagePage.qml"), {
                                "vaultToken": page.vaultToken,
                                "vaultHelper": helper
                            })
                }

                FutoSettingsMenuItem {
                    width: parent.width
                    text: qsTr("Import passwords")
                    iconSource: "image://theme/icon-m-downloads"
                    onClicked: pageStack.animatorPush(
                            Qt.resolvedUrl("FutoPasswordImportPage.qml"), {
                                "vaultToken": page.vaultToken,
                                "vaultHelper": helper
                            })
                }
            }

            Column {
                width: parent.width
                visible: false

                SectionHeader { text: qsTr("Add or update login") }

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
                    label: qsTr("Website")
                    placeholderText: qsTr("example.com")
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
                    text: qsTr("Save login")
                    onClicked: helper.typedCall("SaveCredential", [
                        { "type": "s", "value": page.vaultToken },
                        { "type": "s", "value": labelField.text },
                        { "type": "s", "value": originField.text },
                        { "type": "s", "value": usernameField.text },
                        { "type": "s", "value": passwordField.text }
                    ], function(saved) {
                        if (saved) {
                            labelField.text = ""
                            originField.text = ""
                            usernameField.text = ""
                            passwordField.text = ""
                            page.statusText = qsTr("Login saved")
                            page.refreshEntries()
                        }
                    }, function() {
                        page.statusText = qsTr("Could not save the login")
                    })
                }

                SectionHeader { text: qsTr("Import passwords") }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    wrapMode: Text.Wrap
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                    text: qsTr("Choose a CSV exported by a browser or password manager. "
                               + "FUTO detects Firefox, Chromium browsers, Apple Passwords, "
                               + "1Password, Bitwarden, LastPass, KeePass, Dropbox Passwords, "
                               + "Keeper, Dashlane, RoboForm, NordPass, Proton Pass, and "
                               + "compatible generic CSV files automatically. "
                               + "CSV files are plaintext; delete them after a successful import.")
                }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Import passwords")
                    enabled: !page.busy
                    onClicked: page.choosePasswordCSV()
                }

                SectionHeader { text: qsTr("Saved logins") }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.secondaryColor
                    text: qsTr("No saved logins yet")
                    visible: credentialModel.count === 0
                }

                Repeater {
                    model: credentialModel

                    BackgroundItem {
                        id: credentialItem
                        width: content.width
                        height: Theme.itemSizeLarge
                        onClicked: {
                            var detailPage = pageStack.push(
                                        Qt.resolvedUrl("FutoCredentialPage.qml"), {
                                            "vaultToken": page.vaultToken,
                                            "vaultHelper": helper,
                                            "entryId": entryId,
                                            "entryLabel": entryLabel,
                                            "entryOrigin": entryOrigin,
                                            "entryUsername": entryUsername
                                        })
                            if (detailPage)
                                detailPage.credentialChanged.connect(page.refreshEntries)
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.horizontalPageMargin
                            anchors.right: deleteButton.left
                            anchors.rightMargin: Theme.paddingMedium
                            anchors.verticalCenter: parent.verticalCenter

                            Label {
                                width: parent.width
                                text: entryLabel
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                text: entryUsername + (entryOrigin !== ""
                                      ? (entryUsername !== "" ? " · " : "") + entryOrigin : "")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                                truncationMode: TruncationMode.Fade
                            }
                        }

                        IconButton {
                            id: deleteButton
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.horizontalPageMargin
                            anchors.verticalCenter: parent.verticalCenter
                            icon.source: "image://theme/icon-m-delete"
                            onClicked: {
                                var deleteId = String(entryId)
                                var deleteToken = String(page.vaultToken)
                                Remorse.itemAction(credentialItem,
                                                   qsTr("Deleting login"), function() {
                                helper.typedCall("DeleteCredential", [
                                    { "type": "s", "value": deleteToken },
                                    { "type": "s", "value": deleteId }
                                ], function() { page.refreshEntries() }, function() {
                                    page.statusText = qsTr("Could not delete the login")
                                })
                            })
                            }
                        }
                    }
                }

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
