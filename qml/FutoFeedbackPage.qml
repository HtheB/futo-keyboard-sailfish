import QtQuick 2.0
import QtFeedback 5.0
import Sailfish.Silica 1.0
import Nemo.DBus 2.0
import Nemo.Configuration 1.0
import org.nemomobile.systemsettings 1.0

Page {
    id: page
    allowedOrientations: Orientation.All

    ConfigurationGroup {
        id: settings
        path: "/sailfish/text_input/futo_keyboard"
        property bool keySoundEnabled: false
        property bool keySoundMigrationDone: false
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
        watchServiceStatus: true
    }

    function volumeStep() {
        var configuredVolume = Number(settings.keySoundVolume)
        if (!isFinite(configuredVolume))
            configuredVolume = 0.5
        return Math.max(1, Math.min(10,
                        Math.round(configuredVolume * 10))) * 10
    }

    function previewKeySound() {
        if (!settings.keySoundEnabled)
            return
        helper.typedCall("PlayKeySound", [
            { "type": "s", "value": "letter" },
            { "type": "i", "value": volumeStep() }
        ], function() {}, function() {})
    }

    Component.onCompleted: {
        if (!settings.keySoundMigrationDone) {
            settings.keySoundEnabled = systemFeedback.touchscreenToneLevel !== 0
            settings.keySoundMigrationDone = true
        }
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

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.keySoundEnabled
                text: qsTr("Play a sound on each key press")
                description: qsTr("FUTO sound is independent of ringtone volume. Playback runs "
                                  + "outside the keyboard process so a sound failure cannot hide the keyboard.")
                onClicked: {
                    var enabled = !checked
                    settings.keySoundEnabled = enabled
                    if (enabled)
                        page.previewKeySound()
                }
            }

            Slider {
                width: parent.width
                enabled: settings.keySoundEnabled
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
