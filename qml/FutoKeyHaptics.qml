import QtQuick 2.0
import QtFeedback 5.0
import Nemo.Ngf 1.0
import "FutoHapticFeedback.js" as Haptics

Item {
    id: feedback
    property int mode: 2
    property bool pulsePending: false
    property bool repeatRequested: false
    property double lastRequestAt: 0
    visible: false

    // Keep the normal, device-tuned keyboard effect. Custom pulses need an
    // explicit stop: some native drivers round every short request up to the
    // same minimum duration. No system-wide motor parameters are changed.
    ThemeEffect { id: normalPulse; effect: ThemeEffect.PressWeak }
    NonGraphicalFeedback {
        id: controlledPulse
        event: "feedback_alert"
        // The declarative NGF API sends signed integers, while native drivers
        // require an unsigned haptic.duration. Use its native sequence and the
        // standard short effect on other backends. The quiet tail keeps the
        // request stoppable without driving the motor for the whole guard time.
        properties: [
            NgfProperty { name: "haptic.sequence"; value: "on=" + Haptics.pulseDuration(feedback.mode) + ",pause=160" },
            NgfProperty { name: "haptic.effect"; value: "short" }
        ]
        onStatusChanged: {
            if (status === NonGraphicalFeedback.Playing) {
                if (feedback.pulsePending && feedback.enabled) {
                    if (!pulseStop.running) pulseStop.restart()
                }
                else
                    controlledPulse.stop()
            } else if (status === NonGraphicalFeedback.Stopped || status === NonGraphicalFeedback.Failed) {
                pulseStop.stop()
                feedback.pulsePending = false
                if (status === NonGraphicalFeedback.Stopped && feedback.repeatRequested && feedback.enabled)
                    repeatDelay.restart()
                else {
                    feedback.repeatRequested = false
                    repeatDelay.stop()
                }
            }
        }
    }
    Timer {
        id: pulseStop
        interval: Haptics.pulseDuration(feedback.mode)
        onTriggered: controlledPulse.stop()
    }
    Timer {
        id: repeatDelay
        interval: 8
        onTriggered: feedback.playQueuedRepeat()
    }

    function playQueuedRepeat() {
        var wanted = repeatRequested && Date.now() - lastRequestAt < 120
        repeatRequested = false
        if (wanted) play()
    }

    function stop() {
        if (pulseStop) pulseStop.stop()
        if (repeatDelay) repeatDelay.stop()
        repeatRequested = false
        pulsePending = false
        if (controlledPulse) controlledPulse.stop()
    }

    function play() {
        if (!enabled || Haptics.mode(mode) === 0) { stop(); return }
        if (Haptics.mode(mode) === 2) {
            stop()
            normalPulse.play()
        } else {
            // Starting is asynchronous. Starting the stop timer here can
            // consume the entire short pulse while its request is still queued.
            // Never extend a pulse when another key arrives: that turns short
            // Light taps into a long, increasingly strong vibration. Retain at
            // most one recent repeat and let the motor stop between pulses.
            lastRequestAt = Date.now()
            if (pulsePending || repeatDelay.running) {
                repeatRequested = true
                return
            }
            pulsePending = true
            controlledPulse.play()
        }
    }

    onEnabledChanged: if (!enabled) stop()
    onModeChanged: stop()
    Component.onDestruction: stop()
}
