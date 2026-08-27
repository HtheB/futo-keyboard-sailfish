import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import Nemo.DBus 2.0
import com.jolla.settings.system 1.0

Page {
    id: page
    allowedOrientations: Orientation.All
    property bool authenticationBusy
    property bool authenticationGranted
    property int authenticationReturnAttempts
    property string authenticationPurpose: ""
    property bool pendingProtectionValue
    property bool pendingVaultInitialize
    property string statusText: ""

    function beginAuthentication(purpose) {
        if (authenticationBusy)
            return
        authenticationBusy = true
        authenticationGranted = false
        authenticationReturnAttempts = 0
        authenticationPurpose = purpose
        statusText = ""
        // Close the permanent test input before the system authentication
        // page is pushed.  Keeping an input-method client active while
        // DeviceLock creates its own input page can deadlock jolla-settings.
        Qt.inputMethod.hide()
        authenticationLaunchTimer.restart()
    }

    function openLearnedData() {
        if (settings.personalDictionaryProtected) {
            beginAuthentication("learned")
            return
        }
        pageStack.animatorPush(Qt.resolvedUrl("FutoLearnedDataPage.qml"), {
            "accessGranted": true
        })
    }

    function openSavedPasswords() {
        if (authenticationBusy)
            return
        authenticationBusy = true
        statusText = ""
        helper.typedCall("VaultStatus", [], function(result) {
            page.pendingVaultInitialize = String(result) === "not_initialized"
            page.authenticationBusy = false
            page.beginAuthentication("vault")
        }, function() {
            page.authenticationBusy = false
            page.statusText = qsTr("Password vault is unavailable")
        })
    }

    function continueAuthenticatedAction() {
        if (authenticationPurpose === "protection") {
            settings.personalDictionaryProtected = pendingProtectionValue
            statusText = pendingProtectionValue
                    ? qsTr("Protection enabled") : qsTr("Protection disabled")
            authenticationPurpose = ""
            authenticationBusy = false
            return
        }

        var destination = authenticationPurpose
        helper.typedCall("PrepareLearnedEncryptionFromAuthenticatedSettings", [],
                         function(prepared) {
            if (!prepared) {
                page.authenticationPurpose = ""
                page.authenticationBusy = false
                page.statusText = qsTr("Encrypted data could not be unlocked")
                return
            }
            if (destination === "learned") {
                page.authenticationPurpose = ""
                page.authenticationBusy = false
                pageStack.animatorPush(Qt.resolvedUrl("FutoLearnedDataPage.qml"),
                                       { "accessGranted": true })
                return
            }
            helper.typedCall(page.pendingVaultInitialize
                    ? "InitializeVaultFromAuthenticatedSettings"
                    : "UnlockVaultFromAuthenticatedSettings", [], function(token) {
                page.authenticationPurpose = ""
                page.authenticationBusy = false
                token = String(token)
                if (token === "") {
                    page.statusText = qsTr("Password vault could not be opened")
                    return
                }
                pageStack.animatorPush(Qt.resolvedUrl("FutoPasswordVaultPage.qml"), {
                    "vaultToken": token,
                    "vaultStatus": "unlocked",
                    "authenticationAttempted": true
                })
            }, function() {
                page.authenticationPurpose = ""
                page.authenticationBusy = false
                page.statusText = qsTr("Password vault could not be opened")
            })
        }, function() {
            page.authenticationPurpose = ""
            page.authenticationBusy = false
            page.statusText = qsTr("Encrypted data could not be unlocked")
        })
    }

    function requestProtectionChange(nextValue) {
        if (authenticationBusy)
            return
        pendingProtectionValue = nextValue
        beginAuthentication("protection")
    }

    function authenticationCanceled() {
        authenticationGranted = false
        authenticationReturnTimer.stop()
        authenticationPurpose = ""
        authenticationBusy = false
        statusText = qsTr("Authentication canceled")
    }

    ConfigurationGroup {
        id: settings
        path: "/sailfish/text_input/futo_keyboard"
        property bool personalLearningEnabled: true
        property bool urlHistoryEnabled: false
        property bool incognitoMode: false
        property bool incognitoOnPrivacySwitch: false
        property bool hideKeyPreviewsInIncognito: false
        property bool personalDictionaryProtected: false
        property bool passwordSavingEnabled: true
    }

    // Select the same strong methods as Launcher Combined, including
    // fingerprint, and use a real page for responsive PIN fallback.
    FutoDeviceAuthentication {
        id: deviceAuthentication
        onAccepted: {
            page.authenticationGranted = true
            page.authenticationReturnAttempts = 0
            authenticationReturnTimer.restart()
        }
        onRejected: page.authenticationCanceled()
    }

    Timer {
        id: authenticationLaunchTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (!page.authenticationBusy || page.authenticationPurpose === "")
                return
            var message = page.authenticationPurpose === "vault"
                    ? qsTr("Open saved FUTO passwords")
                    : page.authenticationPurpose === "learned"
                      ? qsTr("Open learned FUTO data")
                      : qsTr("Change personal dictionary protection")
            if (!deviceAuthentication.requestPermission(message)) {
                page.statusText = qsTr("Device authentication is unavailable")
                page.authenticationCanceled()
            }
        }
    }

    // PermissionGranted and AuthenticationEnded may arrive in either order.
    // Wait until the authentication input has returned to this page before
    // opening the destination, otherwise it could pop the new page again.
    Timer {
        id: authenticationReturnTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (!page.authenticationGranted || !page.authenticationBusy)
                return
            if (pageStack.busy || pageStack.currentPage !== page) {
                if (++page.authenticationReturnAttempts < 120)
                    restart()
                else {
                    page.authenticationGranted = false
                    page.authenticationPurpose = ""
                    page.authenticationBusy = false
                    page.statusText = qsTr("Device authentication did not finish")
                }
                return
            }
            page.authenticationGranted = false
            page.continueAuthenticatedAction()
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
            PageHeader { title: qsTr("Privacy and learning") }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.personalLearningEnabled
                text: qsTr("Learn words I use")
                description: qsTr("Learning remains local to this phone.")
                onClicked: settings.personalLearningEnabled = !checked
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.urlHistoryEnabled
                text: qsTr("Learn frequently used URLs")
                description: qsTr("Optional and off by default. Saved URLs are suggested after "
                                  + "their first successful entry. Incognito and password fields "
                                  + "never learn or show URL history.")
                onClicked: settings.urlHistoryEnabled = !checked
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.incognitoMode
                text: qsTr("Incognito mode")
                description: qsTr("Stops word, context, recent-emoji, and clipboard learning. "
                                  + "Password fields activate private handling automatically.")
                onClicked: settings.incognitoMode = !checked
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.hideKeyPreviewsInIncognito
                text: qsTr("Hide key pop-up previews in Incognito")
                description: qsTr("Suppresses pressed-key previews during manual Incognito, "
                                  + "private/password input, and Privacy Switch Incognito.")
                onClicked: settings.hideKeyPreviewsInIncognito = !checked
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.incognitoOnPrivacySwitch
                text: qsTr("Incognito with Privacy Switch")
                description: qsTr("Automatically stops FUTO learning while the Jolla Phone's "
                                  + "physical Privacy Switch is enabled.")
                onClicked: settings.incognitoOnPrivacySwitch = !checked
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.personalDictionaryProtected
                enabled: !page.authenticationBusy
                text: qsTr("Protect personal dictionary")
                description: qsTr("Requires device authentication to open or change it.")
                onClicked: page.requestProtectionChange(!checked)
            }

            FutoSettingsMenuItem {
                width: parent.width
                text: qsTr("Manage learned data")
                iconSource: "image://theme/icon-m-text-input"
                enabled: !page.authenticationBusy
                onClicked: page.openLearnedData()
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.passwordSavingEnabled
                text: qsTr("Offer to save passwords")
                description: qsTr("Shows a Save or Not now prompt while you enter a new "
                                  + "password. Passwords are stored only in the encrypted, "
                                  + "device-authenticated vault.")
                onClicked: settings.passwordSavingEnabled = !checked
            }

            FutoSettingsMenuItem {
                width: parent.width
                text: qsTr("Saved passwords")
                iconSource: "image://theme/icon-m-device-lock"
                enabled: !page.authenticationBusy
                onClicked: page.openSavedPasswords()
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                text: page.statusText
                visible: text !== ""
            }
        }
    }
}
