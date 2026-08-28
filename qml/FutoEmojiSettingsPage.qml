import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import Nemo.DBus 2.0

Page {
    id: page
    allowedOrientations: Orientation.All
    property string statusText: ""
    property bool emojiContentReady: false
    property bool emojiSelectionReady: false
    property bool restoringEmojiStyle: false
    property var installedEmojiPacks: ({})
    property int pendingEmojiDownloadStyle: -1

    onStatusChanged: {
        if (status === PageStatus.Active) {
            refreshEmojiContent()
            if (pendingEmojiDownloadStyle >= 0 && !emojiDownloadNavigation.running)
                emojiDownloadNavigation.start()
        }
    }

    Timer {
        id: emojiDownloadNavigation
        interval: 1
        repeat: false
        onTriggered: {
            var styleIndex = page.pendingEmojiDownloadStyle
            page.pendingEmojiDownloadStyle = -1
            pageStack.push(Qt.resolvedUrl("FutoContentListPage.qml"), {
                "packKind": "emoji",
                "pageTitle": qsTr("Emoji styles"),
                "requestedPackId": page.emojiPackId(styleIndex)
            })
        }
    }

    function emojiPackId(styleIndex) {
        return styleIndex === 1 ? "emoji-openmoji"
             : styleIndex === 2 ? "emoji-noto"
             : styleIndex === 0 ? "emoji-twemoji" : ""
    }

    function emojiStyleName(styleIndex) {
        return styleIndex === 1 ? "OpenMoji Color"
             : styleIndex === 2 ? "Noto Color Emoji"
             : styleIndex === 0 ? "Twemoji" : qsTr("Sailfish OS (built-in)")
    }

    // Preserve the existing stored style values while presenting the built-in
    // Sailfish style first in the user-facing list.
    function comboIndexToStyle(comboIndex) {
        return comboIndex === 0 ? 3 : comboIndex - 1
    }

    function styleToComboIndex(styleIndex) {
        return styleIndex === 3 ? 0 : Math.max(0, Math.min(2, styleIndex)) + 1
    }

    function firstAvailableEmojiStyle(installed) {
        for (var styleIndex = 0; styleIndex < 3; ++styleIndex) {
            if (installed[emojiPackId(styleIndex)])
                return styleIndex
        }
        return 3
    }

    function refreshEmojiContent() {
        if (helper.status !== DBusInterface.Available)
            return
        helper.typedCall("ContentStatus", [], function(resultJson) {
            var result
            try {
                result = JSON.parse(String(resultJson))
            } catch (error) {
                page.statusText = qsTr("Could not check installed emoji styles")
                return
            }
            var installed = {}
            var items = result.items || []
            for (var i = 0; i < items.length; ++i) {
                if (String(items[i].kind) === "emoji")
                    installed[String(items[i].id)] = !!items[i].installed
            }
            page.installedEmojiPacks = installed
            page.emojiContentReady = true
            var selectedPackId = page.emojiPackId(settings.emojiStyle)
            if (selectedPackId !== "" && !installed[selectedPackId])
                settings.emojiStyle = page.firstAvailableEmojiStyle(installed)
            page.statusText = ""
        }, function() {
            page.statusText = qsTr("Could not check installed emoji styles")
        })
    }

    function openEmojiDownloads(styleIndex) {
        var dialog = pageStack.push(Qt.resolvedUrl("FutoContentRequiredDialog.qml"), {
            "contentName": page.emojiStyleName(styleIndex),
            "explanation": qsTr("This emoji artwork is not installed yet. Open the Emoji "
                                + "styles downloader to install it?")
        })
        dialog.accepted.connect(function() {
            // Wait for the confirmation dialog's pop transition to finish.
            // Pushing here directly leaves the underlying page half-visible.
            page.pendingEmojiDownloadStyle = styleIndex
        })
    }

    function chooseEmojiStyle(styleIndex) {
        if (styleIndex === settings.emojiStyle)
            return
        var packId = emojiPackId(styleIndex)
        if (packId !== "" && !installedEmojiPacks[packId]) {
            restoringEmojiStyle = true
            emojiStyleCombo.currentIndex = styleToComboIndex(settings.emojiStyle)
            restoringEmojiStyle = false
            openEmojiDownloads(styleIndex)
            return
        }
        settings.emojiStyle = styleIndex
    }

    function recentEmojiCount() {
        var entries = []
        try { entries = JSON.parse(String(settings.recentEmojis)) } catch (error) {}
        return entries && entries.length !== undefined ? entries.length : 0
    }

    ConfigurationGroup {
        id: settings
        path: "/sailfish/text_input/futo_keyboard"
        property bool emojiLongPressEnabled: true
        property int emojiStyle: 3
        property int emojiSkinTone: 0
        property real emojiSizeScale: 1.0
        property string recentEmojis: "[]"
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
            if (String(packId).indexOf("emoji-") === 0)
                page.refreshEmojiContent()
        }

        onStatusChanged: {
            if (status === DBusInterface.Available)
                page.refreshEmojiContent()
        }
    }

    Component.onCompleted: {
        emojiSelectionReady = true
        refreshEmojiContent()
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
        clip: true
        VerticalScrollDecorator { flickable: parent }

        Column {
            id: content
            width: parent.width
            PageHeader { title: qsTr("Emoji") }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.emojiLongPressEnabled
                text: qsTr("Hold Enter for emojis")
                onClicked: settings.emojiLongPressEnabled = !checked
            }

            ComboBox {
                id: emojiStyleCombo
                width: parent.width
                enabled: settings.emojiLongPressEnabled && page.emojiContentReady
                label: qsTr("Emoji style")
                currentIndex: page.styleToComboIndex(settings.emojiStyle)
                onCurrentIndexChanged: {
                    if (page.emojiSelectionReady && !page.restoringEmojiStyle)
                        page.chooseEmojiStyle(page.comboIndexToStyle(currentIndex))
                }
                menu: ContextMenu {
                    MenuItem { text: qsTr("Sailfish OS (built-in)") }
                    MenuItem { text: "Twemoji" }
                    MenuItem { text: "OpenMoji Color" }
                    MenuItem { text: "Noto Color Emoji" }
                }
            }

            ComboBox {
                width: parent.width
                enabled: settings.emojiLongPressEnabled
                label: qsTr("Default emoji skin tone")
                currentIndex: Math.max(0, Math.min(5, settings.emojiSkinTone))
                onCurrentIndexChanged: settings.emojiSkinTone = currentIndex
                menu: ContextMenu {
                    MenuItem { text: qsTr("Default yellow") }
                    MenuItem { text: qsTr("Light") }
                    MenuItem { text: qsTr("Medium-light") }
                    MenuItem { text: qsTr("Medium") }
                    MenuItem { text: qsTr("Medium-dark") }
                    MenuItem { text: qsTr("Dark") }
                }
            }

            Slider {
                width: parent.width
                enabled: settings.emojiLongPressEnabled
                label: qsTr("Emoji size")
                minimumValue: 0.65
                maximumValue: 1.35
                stepSize: 0.05
                value: Math.max(minimumValue, Math.min(maximumValue, settings.emojiSizeScale))
                valueText: Math.round(value * 100) + "%"
                onReleased: settings.emojiSizeScale = Math.round(value * 20) / 20
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Hold supported people or gestures for a one-time skin-tone choice. "
                           + "Use a smaller size to fit more emoji on screen.")
            }

            SectionHeader { text: qsTr("Recent emoji") }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Clear emoji history")
                enabled: page.recentEmojiCount() > 0
                onClicked: Remorse.popupAction(
                               page, qsTr("Clearing emoji history"), function() {
                    settings.recentEmojis = "[]"
                    page.statusText = qsTr("Emoji history cleared")
                })
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.statusText !== ""
                horizontalAlignment: Text.AlignHCenter
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: page.statusText
            }
        }
    }
}
