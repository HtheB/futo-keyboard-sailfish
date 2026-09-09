/* Shows the removal happening, and refuses to be left until it has.
 *
 * A successful removal takes the helper down with it, so the service going
 * away is what says the package is gone. Only a removal that did not happen
 * has anyone left to report it, and it arrives as UninstallFailed.
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

    // There is nothing to go back to while it is working, and nothing left to
    // go back to once it has worked. A failure leaves everything in place, so
    // then the way back matters.
    backNavigation: phase === "failed"
    showNavigationIndicator: phase === "failed"

    function succeed() {
        if (phase !== "removing")
            return
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
            page.succeed()
        }
    }

    Timer {
        id: failTimer
        interval: 5 * 60 * 1000
        running: page.phase === "removing"
        onTriggered: page.fail(qsTr("The removal did not finish."))
    }

    Component.onCompleted: {
        helper.typedCall("UninstallKeyboard", [], function() {}, function() {})
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
                        return qsTr("Sailfish has switched back to its own "
                                    + "keyboard.")
                    if (page.phase === "failed")
                        return page.message !== ""
                                ? page.message
                                : qsTr("Nothing was changed on this device.")
                    return qsTr("This takes a moment. Please keep this page open.")
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
