import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import Nemo.DBus 2.0

Page {
    id: page
    allowedOrientations: Orientation.All
    property bool swipeContentReady: false
    property bool swipeModelInstalled: false
    property bool pendingSwipeDownloads: false

    onStatusChanged: {
        if (status === PageStatus.Active && pendingSwipeDownloads
                && !swipeDownloadNavigation.running)
            swipeDownloadNavigation.start()
    }

    Timer {
        id: swipeDownloadNavigation
        interval: 1
        repeat: false
        onTriggered: {
            page.pendingSwipeDownloads = false
            pageStack.push(Qt.resolvedUrl("FutoContentListPage.qml"), {
                "packKind": "swipe",
                "pageTitle": qsTr("Swipe typing"),
                "requestedPackId": "swipe-universal"
            })
        }
    }

    function refreshSwipeContent() {
        if (helper.status !== DBusInterface.Available)
            return
        helper.typedCall("ContentStatus", [], function(resultJson) {
            var result
            try {
                result = JSON.parse(String(resultJson))
            } catch (error) {
                return
            }
            var installed = false
            var items = result.items || []
            for (var i = 0; i < items.length; ++i) {
                if (String(items[i].id) === "swipe-universal") {
                    installed = !!items[i].installed
                    break
                }
            }
            page.swipeModelInstalled = installed
            page.swipeContentReady = true
            if (!installed && settings.swipeTypingEnabled)
                settings.swipeTypingEnabled = false
        })
    }

    function openSwipeDownloads() {
        var dialog = pageStack.push(Qt.resolvedUrl("FutoContentRequiredDialog.qml"), {
            "contentName": qsTr("FUTO Swipe model"),
            "explanation": qsTr("Swipe typing needs the universal FUTO Swipe model. "
                                + "Open the Swipe typing downloader to install it?")
        })
        dialog.accepted.connect(function() {
            page.pendingSwipeDownloads = true
        })
    }

    ConfigurationGroup {
        id: settings
        path: "/sailfish/text_input/futo_keyboard"
        property bool spacebarCursorControlEnabled: true
        property bool swipeDeleteEnabled: true
        property bool swipeTypingEnabled: true
    }

    DBusInterface {
        id: helper
        bus: DBus.SessionBus
        service: "org.hb.FutoKeyboard1"
        path: "/org/hb/FutoKeyboard1"
        iface: "org.hb.FutoKeyboard1"
        signalsEnabled: true
        watchServiceStatus: true

        function contentChanged(packId, state) {
            if (String(packId) === "swipe-universal")
                page.refreshSwipeContent()
        }

        onStatusChanged: {
            if (status === DBusInterface.Available)
                page.refreshSwipeContent()
        }
    }

    Component.onCompleted: refreshSwipeContent()

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
            PageHeader { title: qsTr("Typing gestures") }

            TextSwitch {
                width: parent.width
                enabled: page.swipeContentReady || settings.swipeTypingEnabled
                automaticCheck: false
                checked: settings.swipeTypingEnabled
                text: qsTr("Swipe across letters to type")
                description: qsTr("Release your finger to insert the best matching word. "
                                  + "Alternatives appear in the suggestion strip.")
                onClicked: {
                    if (!checked && !page.swipeModelInstalled)
                        page.openSwipeDownloads()
                    else
                        settings.swipeTypingEnabled = !checked
                }
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.spacebarCursorControlEnabled
                text: qsTr("Hold Space to move the cursor")
                description: qsTr("Hold and drag in any direction. Swipe downward quickly on Space to close the keyboard.")
                onClicked: settings.spacebarCursorControlEnabled = !checked
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.swipeDeleteEnabled
                text: qsTr("Swipe Backspace to delete words")
                onClicked: settings.swipeDeleteEnabled = !checked
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Swiping never changes to another Sailfish keyboard. Horizontal layout "
                           + "swiping is available only inside FUTO's visual layout editor.")
            }
        }
    }
}
