/* Shows the removal happening, and refuses to be left until it has.
 *
 * The already-running helper survives long enough to report PackageKit's
 * result and apply the cleanup choices selected on the warning page.
 */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.DBus 2.0

Page {
    id: page
    allowedOrientations: Orientation.All

    // "removing", "done" or "failed"
    property string phase: "removing"
    property string message: ""
    property bool removeSettings: true
    property bool removeLearned: true
    property bool removePasswords: true
    property bool removeContent: true

    // There is nothing to go back to while it is working, and nothing left to
    // go back to once it has worked. A failure leaves everything in place, so
    // then the way back matters.
    backNavigation: phase === "failed"
    showNavigationIndicator: phase === "failed"

    function succeed(reason) {
        if (phase !== "removing")
            return
        message = String(reason || "")
        phase = "done"
        failTimer.stop()
    }

    function fail(reason) {
        if (phase !== "removing")
            return
        message = String(reason || "")
        phase = "failed"
        failTimer.stop()
    }

    DBusInterface {
        id: helper
        bus: DBus.SessionBus
        service: "org.hb.FutoKeyboard1"
        path: "/org/hb/FutoKeyboard1"
        iface: "org.hb.FutoKeyboard1"
        signalsEnabled: true

        function uninstallFailed(reason) {
            page.fail(reason)
        }

        function uninstallFinished(reason) {
            page.succeed(reason)
        }
    }

    Timer {
        id: failTimer
        interval: 5 * 60 * 1000
        running: page.phase === "removing"
        onTriggered: page.fail(qsTr("The removal did not finish."))
    }

    Component.onCompleted: {
        helper.typedCall("UninstallKeyboard", [
            { "type": "b", "value": page.removeSettings },
            { "type": "b", "value": page.removeLearned },
            { "type": "b", "value": page.removePasswords },
            { "type": "b", "value": page.removeContent }
        ], function() {}, function() {})
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge

        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: page.phase === "done" ? qsTr("Uninstalled")
                     : page.phase === "failed" ? qsTr("Still installed")
                     : qsTr("Uninstalling")
            }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                size: BusyIndicatorSize.Large
                running: page.phase === "removing"
                visible: running
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeLarge
                text: page.phase === "done"
                      ? qsTr("FUTO Keyboard has been removed")
                      : page.phase === "failed"
                        ? qsTr("FUTO Keyboard was not removed")
                        : qsTr("Removing FUTO Keyboard")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: {
                    if (page.phase === "done")
                        return page.message !== ""
                                ? page.message
                                : qsTr("Sailfish has switched back to its own "
                                       + "keyboard. The selected FUTO data "
                                       + "has been removed.")
                    if (page.phase === "failed")
                        return page.message !== ""
                                ? page.message
                                : qsTr("Nothing was changed on this device.")
                    return qsTr("The home screen will restart during removal. "
                                + "The display may briefly go dark before "
                                + "returning. This is expected; please wait "
                                + "for the process to finish.")
                }
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Close")
                visible: page.phase === "done"
                // Nothing on the pages behind this one describes anything that
                // still exists, so leave the settings application rather than
                // returning to them. Silica's own window closer is tried first
                // and Qt.quit() covers the case where this page is hosted
                // somewhere that does not provide one.
                // Settings keeps its own copy of the entry list, so the
                // keyboard stays under Text Input until the application is
                // started again. It cannot end itself - its window offers no
                // close and it ignores Qt.quit() - so the helper, which is
                // still running with its files already deleted, does it.
                onClicked: {
                    helper.typedCall("CloseSettings", [], function() {},
                                     function() {})
                    var settingsWindow = __silica_applicationwindow_instance
                    if (settingsWindow
                            && typeof settingsWindow.deactivate === "function") {
                        settingsWindow.deactivate()
                    }
                }
            }
        }
    }
}
