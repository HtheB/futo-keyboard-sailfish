import QtQuick 2.0
import QtFeedback 5.0
import Sailfish.Silica 1.0
import Nemo.DBus 2.0
import Nemo.Configuration 1.0
import org.nemomobile.systemsettings 1.0

Page {
    id: page
    allowedOrientations: Orientation.All
    property bool soundSelectorReady: false
    property bool soundSelectorSyncing: false
    property double soundSyncSuppressedUntil: 0

    ConfigurationGroup {
        id: settings
        path: "/sailfish/text_input/futo_keyboard"
        property bool keySoundEnabled: false
        property bool keySoundFollowSystem: true
        property bool keySoundMigrationDone: false
        property int keySoundMode: -1
        property real keySoundVolume: 0.5
    }

    ProfileControl { id: systemFeedback }
    ThemeEffect { id: vibrationPreview; effect: ThemeEffect.PressWeak }

    DBusInterface {
        id: helper
        bus: DBus.SessionBus
        service: "org.hb.FutoKeyboard1"
        path: "/org/hb/FutoKeyboard1"
        iface: "org.hb.FutoKeyboard1"
        signalsEnabled: true
        watchServiceStatus: true

        function keySoundModeChanged(mode) {
            page.applySoundMode(Number(mode))
        }
    }

    function volumeStep() {
        var configuredVolume = Number(settings.keySoundVolume)
        if (!isFinite(configuredVolume))
            configuredVolume = 0.5
        return Math.max(1, Math.min(10,
                        Math.round(configuredVolume * 10))) * 10
    }

    function soundMode() {
        var mode = Number(settings.keySoundMode)
        if (isFinite(mode) && mode >= 0 && mode <= 2)
            return Math.floor(mode)
        if (!settings.keySoundMigrationDone)
            return 2
        return !settings.keySoundEnabled ? 0
                : settings.keySoundFollowSystem ? 2 : 1
    }

    function applySoundMode(mode) {
        mode = Math.max(0, Math.min(2, Math.floor(Number(mode))))
        soundSelectorSyncing = true
        settings.keySoundMode = mode
        // Keep the old keys synchronized so downgrading to an earlier build
        // retains the equivalent sound behaviour.
        settings.keySoundEnabled = mode !== 0
        settings.keySoundFollowSystem = mode === 2
        settings.keySoundMigrationDone = true
        if (soundModeCombo.currentIndex !== mode)
            soundModeCombo.currentIndex = mode
        soundSelectorSyncing = false
    }

    function setSoundMode(mode) {
        mode = Math.max(0, Math.min(2, Math.floor(Number(mode))))
        soundSyncSuppressedUntil = Date.now() + 700
        applySoundMode(mode)
        helper.typedCall("SetKeySoundMode", [
            { "type": "i", "value": mode }
        ], function(appliedMode) {
            page.applySoundMode(Number(appliedMode))
            page.soundSyncSuppressedUntil = 0
        }, function() {})
    }

    function synchronizeSoundMode() {
        if (!soundSelectorReady || Date.now() < soundSyncSuppressedUntil
                || helper.status !== DBusInterface.Available)
            return
        helper.typedCall("GetKeySoundMode", [], function(mode) {
            page.applySoundMode(Number(mode))
        }, function() {})
    }

    function systemKeySoundActive() {
        var profileName = String(systemFeedback.profile || "")
        var ringtoneVolume = Number(systemFeedback.ringerVolume)
        return systemFeedback.touchscreenToneLevel !== 0
                && profileName !== "silent"
                && (!isFinite(ringtoneVolume) || ringtoneVolume > 0)
    }

    function previewKeySound() {
        var mode = soundMode()
        if (mode === 0 || (mode === 2 && !systemKeySoundActive()))
            return
        helper.typedCall("PlayKeySound", [
            { "type": "s", "value": "letter" },
            { "type": "i", "value": volumeStep() }
        ], function() {}, function() {})
    }

    Component.onCompleted: {
        soundSelectorReady = true
        if (settings.keySoundMode < 0 || settings.keySoundMode > 2) {
            setSoundMode(soundMode())
        } else {
            applySoundMode(soundMode())
            synchronizeSoundMode()
        }
    }

    Timer {
        interval: 200
        repeat: true
        running: page.status === PageStatus.Active
                 && helper.status === DBusInterface.Available
        onTriggered: page.synchronizeSoundMode()
    }

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
            PageHeader { title: qsTr("Sound and vibration") }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: systemFeedback.touchscreenVibrationLevel !== 0
                text: qsTr("Vibrate on each key press")
                description: qsTr("Uses Sailfish touch vibration. FUTO also applies it to its "
                                  + "emoji, clipboard, layout, and quick-action controls.")
                onClicked: {
                    systemFeedback.touchscreenVibrationLevel = checked ? 0 : 1
                    if (!checked)
                        vibrationPreview.play()
                }
            }

            ComboBox {
                id: soundModeCombo
                width: parent.width
                label: qsTr("Play a sound on each key press")
                currentIndex: page.soundMode()
                onCurrentIndexChanged: {
                    if (!page.soundSelectorReady || page.soundSelectorSyncing)
                        return
                    page.setSoundMode(currentIndex)
                    if (currentIndex !== 0)
                        page.previewKeySound()
                }
                menu: ContextMenu {
                    MenuItem { text: qsTr("Off") }
                    MenuItem { text: qsTr("On") }
                    MenuItem { text: qsTr("System default") }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("System default follows Sailfish key tones and Silent mode. On plays FUTO key sounds independently of ringtone volume.")
            }

            Slider {
                width: parent.width
                enabled: page.soundMode() !== 0
                minimumValue: 10
                maximumValue: 100
                stepSize: 10
                value: Math.round(settings.keySoundVolume * 100)
                label: qsTr("Key sound loudness")
                valueText: Math.round(value) + "%"
                onValueChanged: settings.keySoundVolume = Math.round(value) / 100
                onReleased: page.previewKeySound()
            }
        }
    }
}
