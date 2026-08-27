import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import Nemo.DBus 2.0

Page {
    id: page
    allowedOrientations: Orientation.All
    property bool modeControlsReady: false
    property bool applyingKeyboardMode: false
    property double modeSyncSuppressedUntil: 0

    function migrateLegacyKeyboardModes() {
        if (settings.keyboardModeVersion >= 1)
            return
        if (settings.portraitKeyboardMode === 2
                && settings.portraitOneHandSide === 1)
            settings.portraitKeyboardMode = 3
        if (settings.landscapeKeyboardMode === 2
                && settings.landscapeOneHandSide === 1)
            settings.landscapeKeyboardMode = 3
        settings.keyboardModeVersion = 1
    }

    function applyKeyboardMode(orientation, mode) {
        mode = Math.max(0, Math.min(3, Math.round(Number(mode))))
        applyingKeyboardMode = true
        if (orientation === "portrait") {
            if (settings.portraitKeyboardMode !== mode)
                settings.portraitKeyboardMode = mode
            if (portraitModeCombo.currentIndex !== mode)
                portraitModeCombo.currentIndex = mode
        } else if (orientation === "landscape") {
            if (settings.landscapeKeyboardMode !== mode)
                settings.landscapeKeyboardMode = mode
            if (landscapeModeCombo.currentIndex !== mode)
                landscapeModeCombo.currentIndex = mode
        }
        applyingKeyboardMode = false
    }

    function setKeyboardMode(orientation, mode) {
        settings.keyboardModeVersion = 1
        modeSyncSuppressedUntil = Date.now() + 700
        page.applyKeyboardMode(orientation, mode)
        helper.typedCall("SetKeyboardMode", [
            { "type": "s", "value": orientation },
            { "type": "i", "value": Math.round(Number(mode)) }
        ], function(appliedMode) {
            page.applyKeyboardMode(orientation, appliedMode)
            page.modeSyncSuppressedUntil = 0
        }, function() {})
    }

    function synchronizeKeyboardModes() {
        if (!modeControlsReady || Date.now() < modeSyncSuppressedUntil
                || helper.status !== DBusInterface.Available)
            return
        helper.typedCall("GetKeyboardModes", [], function(resultJson) {
            var result
            try {
                result = JSON.parse(String(resultJson))
            } catch (error) {
                return
            }
            page.applyKeyboardMode("portrait", Number(result.portrait))
            page.applyKeyboardMode("landscape", Number(result.landscape))
        }, function() {})
    }

    ConfigurationGroup {
        id: settings
        path: "/sailfish/text_input/futo_keyboard"
        property bool numberRowEnabled: false
        property int symbolNumberLayout: 0
        property bool secondarySymbolsEnabled: true
        property bool separatedKeysEnabled: true
        property real keyGapScale: 1.0
        property real keyFontScale: 1.0
        property real keyboardHeightScale: 1.0
        property bool keyPreviewEnabled: true
        property int secondaryKeyHoldMs: 500
        property int portraitKeyboardMode: 0
        property int landscapeKeyboardMode: 0
        property int portraitOneHandSide: 1
        property int landscapeOneHandSide: 1
        property int keyboardModeVersion: 0
        property bool keepVirtualWithHardwareKeyboard: false
        property bool hardwareDeadKeysEnabled: false
    }

    DBusInterface {
        id: helper
        bus: DBus.SessionBus
        service: "org.hb.FutoKeyboard1"
        path: "/org/hb/FutoKeyboard1"
        iface: "org.hb.FutoKeyboard1"
        signalsEnabled: true
        watchServiceStatus: true

        function keyboardModeChanged(orientation, mode) {
            page.applyKeyboardMode(String(orientation), Number(mode))
        }
    }

    Timer {
        interval: 200
        repeat: true
        running: page.status === PageStatus.Active
                 && helper.status === DBusInterface.Available
        onTriggered: page.synchronizeKeyboardModes()
    }

    Component.onCompleted: {
        migrateLegacyKeyboardModes()
        modeControlsReady = true
        synchronizeKeyboardModes()
    }

    FutoSettingsTestPanel {
        id: testPanel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        pageItem: page
        resizeEnabled: true
    }

    SilicaFlickable {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: testPanel.top
        contentHeight: content.height + Theme.paddingLarge
        clip: true
        VerticalScrollDecorator { flickable: parent }

        Column {
            id: content
            width: parent.width
            PageHeader { title: qsTr("Appearance and keys") }

            SectionHeader { text: qsTr("Keyboard mode") }

            ComboBox {
                id: portraitModeCombo
                width: parent.width
                label: qsTr("Portrait mode")
                currentIndex: Math.max(0, Math.min(3,
                                                   settings.portraitKeyboardMode))
                onCurrentIndexChanged: {
                    if (page.modeControlsReady
                            && !page.applyingKeyboardMode
                            && currentIndex !== settings.portraitKeyboardMode)
                        page.setKeyboardMode("portrait", currentIndex)
                }
                menu: ContextMenu {
                    MenuItem { text: qsTr("Full size") }
                    MenuItem { text: qsTr("Thumb typing") }
                    MenuItem { text: qsTr("One-handed left") }
                    MenuItem { text: qsTr("One-handed right") }
                }
            }

            ComboBox {
                id: landscapeModeCombo
                width: parent.width
                label: qsTr("Landscape mode")
                currentIndex: Math.max(0, Math.min(3,
                                                   settings.landscapeKeyboardMode))
                onCurrentIndexChanged: {
                    if (page.modeControlsReady
                            && !page.applyingKeyboardMode
                            && currentIndex !== settings.landscapeKeyboardMode)
                        page.setKeyboardMode("landscape", currentIndex)
                }
                menu: ContextMenu {
                    MenuItem { text: qsTr("Full size") }
                    MenuItem { text: qsTr("Thumb typing") }
                    MenuItem { text: qsTr("One-handed left") }
                    MenuItem { text: qsTr("One-handed right") }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Choose the left or right one-handed position directly. Portrait and "
                           + "landscape modes are stored independently.")
            }

            SectionHeader { text: qsTr("Keys") }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.numberRowEnabled
                text: qsTr("Show number row")
                onClicked: settings.numberRowEnabled = !checked
            }

            ComboBox {
                width: parent.width
                label: qsTr("Numbers on the 123 page")
                currentIndex: Math.max(0, Math.min(1, settings.symbolNumberLayout))
                onCurrentIndexChanged: settings.symbolNumberLayout = currentIndex
                menu: ContextMenu {
                    MenuItem { text: qsTr("Numbers across the top") }
                    MenuItem { text: qsTr("Numpad arrangement") }
                }
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.secondarySymbolsEnabled
                text: qsTr("Show symbols above letter keys")
                onClicked: settings.secondarySymbolsEnabled = !checked
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.separatedKeysEnabled
                text: qsTr("Separated key caps")
                onClicked: settings.separatedKeysEnabled = !checked
            }

            Slider {
                width: parent.width
                enabled: settings.separatedKeysEnabled
                label: qsTr("Space between key caps")
                minimumValue: 0.5
                maximumValue: 2.0
                stepSize: 0.1
                value: Math.max(minimumValue, Math.min(maximumValue, settings.keyGapScale))
                valueText: Math.round(value * 100) + "%"
                onReleased: settings.keyGapScale = Math.round(value * 10) / 10
            }

            Slider {
                width: parent.width
                label: qsTr("Key label size")
                minimumValue: 0.8
                maximumValue: 1.3
                stepSize: 0.1
                value: Math.max(minimumValue, Math.min(maximumValue, settings.keyFontScale))
                valueText: Math.round(value * 100) + "%"
                onReleased: settings.keyFontScale = Math.round(value * 10) / 10
            }

            Slider {
                width: parent.width
                label: qsTr("Keyboard height")
				minimumValue: 0.50
                maximumValue: 1.30
                stepSize: 0.05
                value: Math.max(minimumValue, Math.min(maximumValue,
                                                       settings.keyboardHeightScale))
                valueText: Math.round(value * 100) + "%"
                onReleased: settings.keyboardHeightScale = Math.round(value * 20) / 20
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Drag the highlighted line above the test field for a live height preview.")
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.keyPreviewEnabled
                text: qsTr("Show key pop-up previews")
                onClicked: settings.keyPreviewEnabled = !checked
            }

            Slider {
                width: parent.width
                label: qsTr("Hold duration for secondary keys")
                minimumValue: 200
                maximumValue: 1200
                stepSize: 50
                value: Math.max(minimumValue, Math.min(maximumValue,
                                                       settings.secondaryKeyHoldMs))
                valueText: Math.round(value) + " ms"
                onReleased: settings.secondaryKeyHoldMs = Math.round(value / 50) * 50
            }

            SectionHeader { text: qsTr("Hardware keyboard") }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.keepVirtualWithHardwareKeyboard
                text: qsTr("Keep virtual keyboard visible")
                description: qsTr("Show FUTO and its prediction strip alongside a detected "
                                  + "built-in, USB, or Bluetooth keyboard. When off, Sailfish "
                                  + "hides the virtual keyboard automatically.")
                onClicked: {
                    var wanted = !checked
                    settings.keepVirtualWithHardwareKeyboard = wanted
                    helper.typedCall("SetKeepVirtualKeyboardWithHardware", [
                        { "type": "b", "value": wanted }
                    ], function(applied) {
                        if (!applied)
                            settings.keepVirtualWithHardwareKeyboard = !wanted
                    }, function() {
                        settings.keepVirtualWithHardwareKeyboard = !wanted
                    })
                }
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.hardwareDeadKeysEnabled
                text: qsTr("Enable dead keys on hardware keyboards")
                description: qsTr("Use the international dead-key variant where required; "
                                  + "national layouts use their standard dead-key behavior.")
                onClicked: {
                    var wanted = !checked
                    settings.hardwareDeadKeysEnabled = wanted
                    helper.typedCall("SetHardwareDeadKeys", [
                        { "type": "b", "value": wanted }
                    ], function(variant) {}, function() {
                        settings.hardwareDeadKeysEnabled = !wanted
                    })
                }
            }
        }
    }
}
