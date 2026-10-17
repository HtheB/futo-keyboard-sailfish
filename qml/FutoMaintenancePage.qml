/* Maintenance actions for FUTO Keyboard settings. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.DBus 2.0

Page {
    id: page
    allowedOrientations: Orientation.All

    property QtObject settingsPage
    property string statusText: ""
    property bool launcherVisible: false
    property bool launcherReady: false
    property bool launcherBusy: false

    function refreshLauncherVisibility() {
        if (launcherBusy) return
        launcherBusy = true
        helper.typedCall("GetLayoutEditorLauncherVisible", [], function(visible) {
            page.launcherVisible = Boolean(visible)
            page.launcherReady = true
            page.launcherBusy = false
        }, function() {
            page.launcherBusy = false
            page.launcherReady = false
            page.statusText = qsTr("Could not read the Layout Editor launcher setting")
        })
    }

    function setLauncherVisibility(visible) {
        if (launcherBusy || !launcherReady) return
        launcherBusy = true
        statusText = ""
        helper.typedCall("SetLayoutEditorLauncherVisible", [
            { "type": "b", "value": visible }
        ], function(applied) {
            page.launcherVisible = Boolean(applied)
            page.launcherBusy = false
        }, function() {
            page.launcherBusy = false
            page.statusText = qsTr("Could not change the Layout Editor launcher setting")
        })
    }

    DBusInterface {
        id: helper
        bus: DBus.SessionBus
        service: "org.hb.FutoKeyboard1"
        path: "/org/hb/FutoKeyboard1"
        iface: "org.hb.FutoKeyboard1"
        signalsEnabled: true
        watchServiceStatus: true
        onStatusChanged: if (status === DBusInterface.Available)
                             page.refreshLauncherVisibility()
        function layoutEditorLauncherChanged(visible) {
            page.launcherVisible = Boolean(visible)
            page.launcherReady = true
        }
    }

    onStatusChanged: if (status === PageStatus.Active)
                         refreshLauncherVisibility()
    Component.onCompleted: refreshLauncherVisibility()

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

            PageHeader { title: qsTr("Maintenance") }

            TextSwitch {
                objectName: "layoutEditorLauncherSwitch"
                width: parent.width
                text: qsTr("Show Layout Editor in app drawer")
                description: qsTr("The editor is always available from FUTO Keyboard settings.")
                automaticCheck: false
                checked: page.launcherVisible
                enabled: page.launcherReady && !page.launcherBusy
                onClicked: page.setLauncherVisibility(!checked)
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
                Separator {
                    objectName: "layoutEditorLauncherSeparator"
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 2 * x
                    color: Theme.primaryColor
                }
            }

            BackgroundItem {
                width: parent.width
                height: Math.max(Theme.itemSizeLarge,
                                 resetLabels.height + 2 * Theme.paddingMedium)

                onClicked: Remorse.popupAction(page, qsTr("Restoring defaults"), function() {
                    if (page.settingsPage)
                        page.settingsPage.resetDefaults()
                    page.statusText = qsTr("Defaults restored")
                })

                Icon {
                    id: resetIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.iconSizeMedium
                    height: width
                    source: "image://theme/icon-m-refresh"
                    color: parent.highlighted ? Theme.highlightColor
                                              : Theme.primaryColor
                }

                Column {
                    id: resetLabels
                    anchors.left: resetIcon.right
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.paddingLarge
                    anchors.rightMargin: Theme.horizontalPageMargin

                    Label {
                        width: parent.width
                        text: qsTr("Restore default settings")
                        color: parent.parent.highlighted
                               ? Theme.highlightColor : Theme.primaryColor
                        truncationMode: TruncationMode.Fade
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Reset FUTO Keyboard options while keeping learned words and clipboard data.")
                        color: parent.parent.highlighted
                               ? Theme.secondaryHighlightColor : Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                        wrapMode: Text.Wrap
                    }
                }
            }


            BackgroundItem {
                width: parent.width
                height: Math.max(Theme.itemSizeLarge,
                                 uninstallLabels.height + 2 * Theme.paddingMedium)

                // The warning page requires an explicit button press before
                // it replaces itself with the removal progress page.
                onClicked: pageStack.push(
                               Qt.resolvedUrl("FutoUninstallDialog.qml"))

                Icon {
                    id: uninstallIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.iconSizeMedium
                    height: width
                    source: "image://theme/icon-m-reset"
                    color: parent.highlighted ? Theme.highlightColor
                                              : Theme.primaryColor
                }

                Column {
                    id: uninstallLabels
                    anchors.left: uninstallIcon.right
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.paddingLarge
                    anchors.rightMargin: Theme.horizontalPageMargin

                    Label {
                        width: parent.width
                        text: qsTr("Uninstall FUTO Keyboard")
                        color: parent.parent.highlighted
                               ? Theme.highlightColor : Theme.primaryColor
                        truncationMode: TruncationMode.Fade
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Remove the keyboard from this device. Sailfish asks you to "
                                   + "confirm, and switches back to its own keyboard.")
                        color: parent.parent.highlighted
                               ? Theme.secondaryHighlightColor : Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                        wrapMode: Text.Wrap
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                horizontalAlignment: Text.AlignHCenter
                color: Theme.highlightColor
                // Failures arrive as whole sentences from the package tools,
                // which run off the screen unless they are allowed to wrap.
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                text: page.statusText
                visible: text !== ""
            }
        }
    }
}
