/* Inline entry loaded by Sailfish's stock Settings -> Text input page. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.DBus 2.0

Column {
    id: entry
    width: parent.width
    height: childrenRect.height
    spacing: Theme.paddingSmall

    function isCurrentPage() {
        var item = entry
        while (item && item !== pageStack.currentPage) item = item.parent
        return !!item
    }

    // Text input is a page, not a settings-model group. Its inline child cannot
    // be opened with showPage on older Sailfish versions. Route a pending
    // companion request through this stock page, then our own page stack.
    Component.onCompleted: pendingTimer.start()
    DBusInterface {
        id: helper
        bus: DBus.SessionBus
        service: "org.hb.FutoKeyboard1"
        path: "/org/hb/FutoKeyboard1"
        iface: "org.hb.FutoKeyboard1"
        signalsEnabled: true
        function androidAutofillRequested() {
            pendingTimer.attempts = 0
            pendingTimer.restart()
        }
    }
    Timer {
        id: pendingTimer
        interval: 100
        property int attempts: 0
        property string openedRequest: ""
        onTriggered: {
            // The signal arrives before showPage brings Text input forward.
            // Its inline entry may already exist under another Settings page.
            if (!entry.isCurrentPage() || pageStack.busy) {
                if (++attempts < 60) restart()
                return
            }
            helper.typedCall("PendingAndroidAutofill", [], function(json) {
                var request = JSON.parse(String(json))
                if (request.id && request.id !== openedRequest && !pageStack.busy && entry.isCurrentPage()) {
                    openedRequest = String(request.id)
                    pageStack.push(Qt.resolvedUrl("main.qml"), {}, PageStackAction.Immediate)
                }
            }, function() {})
        }
    }

    SectionHeader { text: qsTr("FUTO Keyboard") }

    FutoSettingsMenuItem {
        width: parent.width
        text: qsTr("FUTO Keyboard settings")
        iconSource: "image://theme/icon-m-keyboard"
        onClicked: pageStack.push(Qt.resolvedUrl("main.qml"))
    }
}
