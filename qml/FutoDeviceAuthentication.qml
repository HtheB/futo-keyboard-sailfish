/* Fingerprint/security-code authentication matching Launcher Combined. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import org.nemomobile.devicelock 1.0
import com.jolla.settings.system 1.0

Item {
    id: root
    width: 0
    height: 0

    readonly property int strongMethods: Authenticator.SecurityCode
                                         | Authenticator.Fingerprint
    readonly property bool available:
            (authenticator.availableMethods & strongMethods) !== 0
    property bool pending
    property bool requestDispatched
    property bool grantReceived
    property bool authenticationEnded
    property int availabilityAttempts
    property string promptText: ""
    property var inputPage
    property var delayedAction

    signal accepted()
    signal rejected()

    function requestPermission(message) {
        if (pending)
            return false
        promptText = String(message || "")
        requestDispatched = false
        grantReceived = false
        authenticationEnded = false
        availabilityAttempts = 0
        pending = true
        if (available)
            authenticationStart.restart()
        else
            availabilityTimer.restart()
        return true
    }

    function tryFinish() {
        if (!pending || !grantReceived || !authenticationEnded)
            return
        availabilityTimer.stop()
        authenticationTimeout.stop()
        requestDispatched = false
        grantReceived = false
        authenticationEnded = false
        pending = false
        accepted()
    }

    function runWhenPageStackNotBusy(action) {
        if (pageStack.busy)
            delayedAction = action
        else {
            delayedAction = undefined
            action()
        }
    }

    function showAuthenticationPage(feedback, data, unavailable) {
        runWhenPageStackNotBusy(function() {
            if (!root.pending)
                return
            var animator = pageStack.animatorPush(
                    Qt.resolvedUrl("FutoDeviceLockInputPage.qml"),
                    { "authentication": authenticationInput })
            animator.pageCompleted.connect(function(dialog) {
                root.inputPage = dialog
                if (!root.pending) {
                    root.closeAuthenticationPage()
                    return
                }
                if (unavailable)
                    authenticationInput.error(feedback, data)
                else
                    authenticationInput.feedback(feedback, data)
            })
        })
    }

    function closeAuthenticationPage() {
        runWhenPageStackNotBusy(function() {
            if (root.inputPage && pageStack.currentPage === root.inputPage)
                pageStack.pop()
            root.inputPage = undefined
        })
    }

    function fail() {
        if (!pending)
            return
        authenticationStart.stop()
        availabilityTimer.stop()
        authenticationTimeout.stop()
        requestDispatched = false
        grantReceived = false
        authenticationEnded = false
        pending = false
        closeAuthenticationPage()
        rejected()
    }

    Authenticator {
        id: authenticator

        onPermissionGranted: {
            if (!root.pending)
                return
            if (method === Authenticator.SecurityCode
                    || method === Authenticator.Fingerprint) {
                root.grantReceived = true
                root.tryFinish()
            } else {
                root.fail()
            }
        }
        onAborted: root.fail()
        onAvailableMethodsChanged: {
            if (root.pending && !root.requestDispatched && root.available) {
                availabilityTimer.stop()
                authenticationStart.restart()
            }
        }
    }

    AuthenticationInput {
        id: authenticationInput

        signal reset()

        registered: root.pending
        active: root.pending

        onAuthenticationStarted: {
            reset()
            root.showAuthenticationPage(feedback, data, false)
            authenticationTimeout.restart()
        }
        onAuthenticationUnavailable: {
            reset()
            root.showAuthenticationPage(error, data, true)
            authenticationTimeout.restart()
        }
        onAuthenticationEnded: {
            reset()
            if (confirmed) {
                root.authenticationEnded = true
                root.closeAuthenticationPage()
                root.tryFinish()
            } else {
                root.fail()
            }
        }
    }

    Timer {
        id: authenticationStart
        interval: 0
        repeat: false
        onTriggered: {
            if (!root.pending)
                return
            if (!root.available) {
                availabilityTimer.restart()
                return
            }
            root.requestDispatched = true
            authenticator.requestPermission(root.promptText, {}, root.strongMethods)
            authenticationTimeout.restart()
        }
    }

    Connections {
        target: pageStack
        onBusyChanged: {
            if (!pageStack.busy && root.delayedAction) {
                var action = root.delayedAction
                root.delayedAction = undefined
                action()
            }
        }
    }

    Timer {
        id: availabilityTimer
        interval: 100
        repeat: true
        onTriggered: {
            if (!root.pending || root.requestDispatched) {
                stop()
            } else if (root.available) {
                stop()
                authenticationStart.restart()
            } else if (++root.availabilityAttempts >= 20) {
                stop()
                root.fail()
            }
        }
    }

    Timer {
        id: authenticationTimeout
        interval: 60000
        repeat: false
        onTriggered: root.fail()
    }

    Component.onDestruction: {
        if (pending) {
            pending = false
			if (requestDispatched)
				authenticator.cancel()
		}
    }
}
