import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.DBus 2.0

Page {
    id: page
    allowedOrientations: Orientation.All
    property string requestId: ""
    property string origin: ""
    property string displayName: ""
    property string mode: "save"
    property string username: ""
    property string vaultToken: ""
    property string message: ""
    property bool busy: true
    property bool finished: false
    property bool completing: false
    property bool granted: false
    property int returnAttempts: 0
    backNavigation: !completing

    DBusInterface {
        id: helper
        bus: DBus.SessionBus
        service: "org.hb.FutoKeyboard1"
        path: "/org/hb/FutoKeyboard1"
        iface: "org.hb.FutoKeyboard1"
    }
    FutoDeviceAuthentication {
        id: authentication
        onAccepted: { page.granted = true; returnTimer.restart() }
        onRejected: page.complete("", false)
    }
    Timer {
        id: returnTimer
        interval: 50
        onTriggered: {
            if (!page.granted || page.finished) return
            if (pageStack.busy || pageStack.currentPage !== page) {
                if (++page.returnAttempts < 120) restart()
                else page.complete("", false)
                return
            }
            page.granted = false
            helper.typedCall("PrepareLearnedEncryptionFromAuthenticatedSettings", [], function(prepared) {
                if (!prepared) { page.message = qsTr("Encrypted data could not be unlocked"); page.busy = false; return }
                helper.typedCall("VaultStatus", [], function(status) {
                    helper.typedCall(String(status) === "not_initialized"
                        ? "InitializeVaultFromAuthenticatedSettings" : "UnlockVaultFromAuthenticatedSettings", [], function(token) {
                        page.vaultReady(token)
                    }, function() { page.message = qsTr("Password vault could not be opened"); page.busy = false })
                }, function() { page.message = qsTr("Password vault is unavailable"); page.busy = false })
            }, function() { page.message = qsTr("Encrypted data could not be unlocked"); page.busy = false })
        }
    }

    function vaultReady(token) {
        token = String(token || "")
        if (finished || completing) {
            if (token !== "") helper.typedCall("LockVault", [{"type":"s", "value":token}], function() {}, function() {})
            return
        }
        if (token === "") {
            message = qsTr("Password vault could not be opened")
            busy = false
            return
        }
        vaultToken = token
        // Android's Save button already supplied consent. Device authentication
        // only unlocks the encrypted vault; do not ask to save the login again.
        complete("", true)
    }
    function complete(account, approved) {
        if (finished || completing) return
        completing = true
        busy = true
        helper.typedCall("CompleteAndroidAutofill", [
            {"type":"s", "value":vaultToken}, {"type":"s", "value":requestId},
            {"type":"s", "value":account}, {"type":"b", "value":approved}
        ], function(success) {
            page.completing = false
            if (approved && !success) { page.message = qsTr("The autofill request expired"); page.busy = false; return }
            page.finished = true
            page.lockVault()
            page.closePage()
        }, function() { page.completing = false; page.message = qsTr("Could not finish the autofill request"); page.busy = false })
    }
    function closePage() {
        var window = __silica_applicationwindow_instance
        if (window && typeof window.deactivate === "function") window.deactivate()
        pageStack.pop()
    }
    function lockVault() {
        if (vaultToken !== "") helper.typedCall("LockVault", [{"type":"s", "value":vaultToken}], function() {}, function() {})
        vaultToken = ""
    }
    Component.onCompleted: {
        Qt.inputMethod.hide()
        if (!authentication.requestPermission(qsTr("Save this login in FUTO Keyboard"))) {
            message = qsTr("Device authentication is unavailable")
            busy = false
        }
    }
    Component.onDestruction: {
        if (!finished) helper.typedCall("CompleteAndroidAutofill", [
            {"type":"s", "value":""}, {"type":"s", "value":requestId},
            {"type":"s", "value":""}, {"type":"b", "value":false}
        ], function() {}, function() {})
        lockVault()
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge
        VerticalScrollDecorator {}
        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingLarge
            PageHeader { title: qsTr("Saving login") }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2*x
                text: page.displayName !== "" ? page.displayName : page.origin
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
            }
            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: page.busy
                visible: running
                size: BusyIndicatorSize.Medium
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2*x
                visible: !page.busy
                text: page.username === "" ? qsTr("This login has no username.") : page.username
                wrapMode: Text.Wrap
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                enabled: !page.completing
                text: page.busy ? qsTr("Cancel") : qsTr("Close")
                onClicked: page.complete("", false)
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2*x
                text: page.message
                visible: text !== ""
                wrapMode: Text.Wrap
                color: Theme.highlightColor
            }
        }
    }
}
