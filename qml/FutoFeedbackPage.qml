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
        watchServiceStatus: true
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

    function setSoundMode(mode) {
        mode = Math.max(0, Math.min(2, Math.floor(Number(mode))))
        settings.keySoundMode = mode
        // Keep the old keys synchronized so downgrading to an earlier build
        // retains the equivalent sound behaviour.
        settings.keySoundEnabled = mode !== 0
        settings.keySoundFollowSystem = mode === 2
        settings.keySoundMigrationDone = true
    }

    function previewKeySound() {
        var mode = soundMode()
        if (mode === 0
				|| (mode === 2 && systemFeedback.touchscreenToneLevel === 0))
            return
        helper.typedCall("PlayKeySound", [
            { "type": "s", "value": "letter" },
            { "type": "i", "value": volumeStep() }
        ], function() {}, function() {})
    }

    Component.onCompleted: {
        if (settings.keySoundMode < 0 || settings.keySoundMode > 2)
            setSoundMode(soundMode())
        soundSelectorReady = true
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
                width: parent.width
                label: qsTr("Play a sound on each key press")
                currentIndex: page.soundMode()
                onCurrentIndexChanged: {
                    if (!page.soundSelectorReady)
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
                text: qsTr("System default follows Sailfish key tones. On plays FUTO key sounds independently of ringtone volume.")
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
