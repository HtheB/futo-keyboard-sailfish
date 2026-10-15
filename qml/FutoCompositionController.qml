/* Native conversion sessions are independent of ordinary word suggestions. */
import QtQuick 2.0
import "FutoCompositionSession.js" as Conversion

Item {
    id: controller
    visible: false
    property var transport
    enabled: false
    property string language: ""
    property string layoutHint: ""
    property bool privateMode: true
    property var options: ({})
    property bool expanded: false
    property bool hasMore: false
    readonly property bool busy: session ? session.busy : false
    property string preedit: ""
    property string reading: ""
    property int cursor: 0
    property var candidates: []
    property alias candidateModel: candidateItems
    ListModel { id: candidateItems }
    property int revision: 0
    property string message: ""
    property var session: null
    signal result(var state, var request)

    function clear() {
        toggleTimer.stop()
        if (session) session.invalidate()
        preedit = ""
        reading = ""
        candidates = []
        candidateItems.clear()
        cursor = 0
        revision = 0
        message = ""
        expanded = false
        hasMore = false
    }

    function ensureSession() {
        if (!session) {
            session = new Conversion.Session(function(method, args, success, failure) {
                if (controller.transport)
                    controller.transport.typedCall(method, args, success, failure)
                else
                    failure()
            }, function(state, request) {
                controller.preedit = String(state.preedit)
                controller.reading = String(state.input || state.preedit)
                if (controller.layoutHint === "stroke")
                    controller.reading = controller.reading.replace(/[hspnz]/g, function(code) {
                        return ({h: "⼀", s: "⼁", p: "⼃", n: "⼂", z: "⼄"})[code]
                    })
                controller.cursor = Number(state.cursor)
                controller.revision = Number(state.revision)
                controller.hasMore = !!state.hasMore
                controller.candidates = state.candidates
                // Appending to a ListModel preserves scroll position. Replacing
                // an array model would send the candidate view back to the start.
                if (!request || request.operation !== "more") candidateItems.clear()
                for (var i = candidateItems.count; i < state.candidates.length; ++i)
                    candidateItems.append({candidateId: state.candidates[i].id,
                        text: String(state.candidates[i].text), comment: String(state.candidates[i].comment || "")})
                if (request && request.operation === "select") controller.expanded = false
                controller.message = ""
                controller.result(state, request)
            }, function() {
                controller.preedit = ""
                controller.candidates = []
                candidateItems.clear()
                controller.message = qsTr("Conversion is unavailable. Check the language download.")
            })
        }
        if (session.language !== language || session.layout !== layoutHint
                || session.privateMode !== privateMode
                || session.configuration !== JSON.stringify(options)) {
            message = qsTr("Preparing language…")
            session.begin(language, layoutHint, privateMode, options)
        }
    }

    function submit(operation, value, after) {
        if (!enabled) return false
        ensureSession()
        return session.enqueue(operation, value, after)
    }

    function selectCandidate(id, shownRevision) {
        toggleTimer.stop()
        if (enabled && session)
            session.select(id, shownRevision)
    }

    function loadMore() {
        if (enabled && session && !session.busy && hasMore && candidates.length < 2048)
            session.enqueue("more", candidates.length)
    }

    function moveReadingCursor(position) {
        if (enabled && session && !session.busy)
            session.enqueue("cursor", position)
    }

    Timer {
        id: toggleTimer
        interval: 700
        onTriggered: if (controller.enabled && controller.session && controller.preedit !== "")
            controller.session.enqueue("stop-toggle", "")
    }

    function kanaKeyEntered() {
        if (layoutHint.indexOf("12key") === 0 && !options.flickOnly) toggleTimer.restart()
    }

    function finish(after) {
        toggleTimer.stop()
        if (enabled && session && session.language !== ""
                && (session.starting || session.token !== ""))
            return session.enqueue("commit", "", after)
        if (after) after()
        return true
    }

    onEnabledChanged: if (!enabled) clear()
    onLanguageChanged: clear()
    onLayoutHintChanged: clear()
    onPrivateModeChanged: clear()
    onOptionsChanged: clear()
    Component.onDestruction: clear()
}
