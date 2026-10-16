import QtQuick 2.6

FutoEditorTool {
    id: tool
    signal interactionStarted()
    signal stepRequested()
    property int repeatedSteps: 0
    onPressedChanged: {
        if (pressed && enabled) {
            repeatedSteps = 0
            interactionStarted()
            stepRequested()
            if (pressed && enabled) delay.restart()
        } else {
            delay.stop()
            repetition.stop()
        }
    }
    Timer {
        id: delay
        interval: 520
        onTriggered: if (tool.pressed && tool.enabled) {
            tool.stepRequested()
            if (tool.pressed && tool.enabled) { repetition.interval = 140; repetition.start() }
        }
    }
    Timer {
        id: repetition
        repeat: true
        interval: 140
        onTriggered: {
            if (!tool.pressed || !tool.enabled) { stop(); return }
            tool.stepRequested()
            tool.repeatedSteps++
            interval = tool.repeatedSteps >= 12 ? 55 : tool.repeatedSteps >= 5 ? 90 : 140
        }
    }
}
