import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.DBus 2.0

Page {
    id: page
    allowedOrientations: Orientation.All
    readonly property string packageName: "org.htheb.futo.autofill"
    readonly property string activityName: packageName + ".ConfigureActivity"
    property bool checking: false
    property int refreshSerial: 0
    property bool stateReady: false
    readonly property bool initialLoading: !stateReady
    property bool installed: false
    property bool enabled: false
    property bool active: false
    property bool busy: false
    property bool configuring: false
    property bool configurationLeftPage: false
    property string message: ""

    Component.onCompleted: refresh()
    onStatusChanged: if (status === PageStatus.Active) refresh()
    Connections {
        target: Qt.application
        onActiveChanged: {
            if (!Qt.application.active && page.configuring) page.configurationLeftPage = true
            if (Qt.application.active && page.status === PageStatus.Active) {
                if (page.configurationLeftPage) {
                    page.configuring = false
                    page.configurationLeftPage = false
                }
                refreshTimer.restart()
            }
        }
    }

    DBusInterface {
        id: appSupport
        bus: DBus.SessionBus
        service: "com.jolla.apkd"
        path: "/com/jolla/apkd"
        iface: "com.jolla.apkd"
    }
    DBusInterface {
        id: helper
        bus: DBus.SessionBus
        service: "org.hb.FutoKeyboard1"
        path: "/org/hb/FutoKeyboard1"
        iface: "org.hb.FutoKeyboard1"
    }
    Timer { id: refreshTimer; interval: 1500; onTriggered: page.refresh() }
    Timer {
        interval: 2000
        repeat: true
        running: page.status === PageStatus.Active && Qt.application.active
                 && page.installed && !page.busy && !page.checking && !page.configuring
        onTriggered: page.refresh()
    }
    RemorsePopup { id: uninstallRemorse }

    function refresh() {
        if (busy || checking) return
        checking = true
        var serial = ++refreshSerial
        appSupport.typedCall("queryIntent", [
            {"type":"s", "value":"org.htheb.futo.autofill.CONFIGURE"},
            {"type":"s", "value":""}, {"type":"s", "value":""},
            {"type":"s", "value":packageName}, {"type":"s", "value":""},
            {"type":"s", "value":""}, {"type":"a{sv}", "value":({})}
        ], function(apps) {
            if (serial !== page.refreshSerial) return
            page.installed = apps && apps.length > 0
            helper.typedCall("GetAndroidAutofillState", [], function(json) {
                if (serial !== page.refreshSerial) return
                var state = JSON.parse(String(json))
                page.active = state.active === true
                page.enabled = page.installed && state.enabled === true && page.active
                page.checking = false
                page.stateReady = true
                // A prepared bridge is not a selected Android autofill service.
                // Cancellation must not leave the switch checked or the listener on.
                if (state.enabled === true && (!page.installed || (!page.active && !page.configuring)))
                    page.setEnabled(false)
            }, function() {
                if (serial !== page.refreshSerial) return
                page.checking = false
                page.stateReady = true
                page.message = qsTr("Android autofill is unavailable")
            })
        }, function() {
            if (serial !== page.refreshSerial) return
            page.checking = false
            page.stateReady = true
            page.message = qsTr("Android AppSupport is not available on this phone.")
        })
    }

    function invalidateRefresh() {
        // Explicit actions supersede an in-flight background status reply.
        refreshSerial++
        checking = false
    }

    function installCompanion() {
        invalidateRefresh()
        busy = true
        appSupport.typedCall("installFile", [{"type":"s", "value":
            "/usr/share/futo-keyboard-sailfish/android/FutoAutofill.apk"}], function(success) {
            page.busy = false
            page.message = success ? qsTr("Companion installed. Tap Set up Android autofill to continue.")
                                   : qsTr("Installation was canceled or failed")
            refreshTimer.restart()
        }, function() {
            page.busy = false
            page.message = qsTr("Could not install the Android companion")
        })
    }

    function setEnabled(value) {
        if (busy) return
        invalidateRefresh()
        busy = true
        message = ""
        helper.typedCall("SetAndroidAutofillEnabled", [{"type":"b", "value":value}], function(success) {
            if (value && success) {
                helper.typedCall("GetAndroidAutofillState", [], function(json) {
                    var state = JSON.parse(String(json))
                    page.busy = false
                    if (state.enabled === true && state.active === true) {
                        page.active = true
                        page.enabled = true
                        page.configuring = false
                    } else page.configureCompanion(true)
                }, function() { page.configurationFailed(qsTr("Could not check Android autofill")) })
            }
            else {
                page.busy = false
                page.enabled = false
                page.active = false
                page.configuring = false
            }
        }, function() {
            page.busy = false
            page.message = qsTr("Could not change Android autofill")
        })
    }

    function configureCompanion(setupOnly) {
        invalidateRefresh()
        busy = true
        configuring = true
        configurationLeftPage = false
        message = ""
        helper.typedCall("AndroidAutofillSetupToken", [], function(token) {
            if (!token) { page.configurationFailed(qsTr("Could not configure the companion")); return }
            appSupport.typedCall("launchIntent", [
                {"type":"s", "value":setupOnly === true ? "org.htheb.futo.autofill.ENABLE"
                                                        : "org.htheb.futo.autofill.CONFIGURE"},
                {"type":"s", "value":""}, {"type":"s", "value":""},
                {"type":"s", "value":page.packageName},
                {"type":"s", "value":page.activityName}, {"type":"s", "value":""},
                {"type":"a{sv}", "value":({"bridge_token":String(token)})}
            ], function() {
                page.busy = false
                if (!page.active) helper.typedCall("ShowAndroidAutofillSetupToast", [])
            }, function() {
                page.configurationFailed(qsTr("Could not open Android autofill settings"))
            })
        }, function() { page.configurationFailed(qsTr("Could not configure the companion")) })
    }

    function configurationFailed(reason) {
        busy = false
        configuring = false
        setEnabled(false)
        message = reason
    }

    function uninstallCompanion() {
        invalidateRefresh()
        busy = true
        helper.typedCall("SetAndroidAutofillEnabled", [{"type":"b", "value":false}], function() {
            appSupport.typedCall("removePackage", [{"type":"s", "value":page.packageName}], function(success) {
                page.busy = false
                page.message = success ? qsTr("Companion removed. Your saved passwords were kept.")
                                       : qsTr("Could not remove the companion")
                refreshTimer.restart()
            }, function() { page.busy = false; page.message = qsTr("Could not remove the companion") })
        }, function() { page.busy = false; page.message = qsTr("Could not disable Android autofill") })
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge
        VerticalScrollDecorator {}
        PullDownMenu {
            visible: page.installed
            MenuItem {
                text: qsTr("Uninstall companion")
                enabled: !page.busy
                onClicked: uninstallRemorse.execute(qsTr("Removing Android companion"), function() { page.uninstallCompanion() })
            }
        }
        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingLarge
            PageHeader { title: qsTr("Android™ AppSupport") }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2*x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                text: qsTr("Optional autofill for Android apps and supported browsers. Install the companion, then select FUTO Autofill in Android settings. Your passwords stay in FUTO's encrypted vault.")
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !page.initialLoading && !page.installed
                enabled: !page.busy
                text: qsTr("Install Android companion")
                onClicked: page.installCompanion()
            }
            TextSwitch {
                width: parent.width
                visible: page.installed
                enabled: !page.initialLoading && !page.busy && !page.configuring
                checked: page.enabled
                automaticCheck: false
                text: qsTr("Android autofill")
                description: qsTr("Use FUTO's saved logins in Android apps.")
                onClicked: page.setEnabled(!checked)
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: page.installed
                enabled: !page.busy && !page.configuring
                text: page.enabled ? qsTr("Open Android autofill settings") : qsTr("Set up Android autofill")
                onClicked: page.enabled ? page.configureCompanion(false) : page.setEnabled(true)
            }
            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                // Background checks stay quiet; explicit actions show progress
                // below the controls without pushing those controls around.
                running: page.initialLoading || page.busy
                visible: running
                size: BusyIndicatorSize.Medium
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2*x
                wrapMode: Text.Wrap
                visible: page.message !== ""
                text: page.message
                color: Theme.highlightColor
            }
        }
    }
}
