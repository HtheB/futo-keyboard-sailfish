/* Configure and order the actions shown after holding 123. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0

Page {
    id: page
    allowedOrientations: Orientation.All

    readonly property var knownActions: [
        { "id": "language", "label": qsTr("Switch language/layout"),
          "icon": "image://theme/icon-m-region" },
        { "id": "layouts", "label": qsTr("Edit layouts"),
          "icon": "image://theme/icon-m-edit" },
        { "id": "keyboardmode", "label": qsTr("Keyboard mode"),
          "icon": "image://theme/icon-m-text-input" },
        { "id": "clipboard", "label": qsTr("Clipboard"),
          "icon": "image://theme/icon-m-clipboard" },
        { "id": "emoji", "label": qsTr("Emoji"),
          "icon": "file:///usr/share/futo-keyboard-sailfish/icons/icon-m-emoji.svg" },
        { "id": "microphone", "label": qsTr("Microphone"),
          "icon": "image://theme/icon-m-browser-microphone" },
        { "id": "incognito", "label": qsTr("Incognito"),
          "icon": "image://theme/icon-m-incognito" },
        { "id": "settings", "label": qsTr("FUTO Settings"),
          "icon": "image://theme/icon-m-setting" }
    ]

    ConfigurationGroup {
        id: settings
        path: "/sailfish/text_input/futo_keyboard"
        property string quickSettingsOrder:
            "language,layouts,keyboardmode,clipboard,emoji,microphone,incognito,settings"
        property string quickSettingsEnabled:
            "language,layouts,keyboardmode,clipboard,emoji,microphone,incognito,settings"
    }

    function splitUnique(value) {
        var raw = String(value).split(",")
        var result = []
        for (var i = 0; i < raw.length; ++i) {
            var id = raw[i].trim()
            if (id !== "" && result.indexOf(id) < 0)
                result.push(id)
        }
        return result
    }

    function definition(actionId) {
        for (var i = 0; i < knownActions.length; ++i) {
            if (knownActions[i].id === actionId)
                return knownActions[i]
        }
        return null
    }

    function loadModel() {
        actionModel.clear()
        var order = splitUnique(settings.quickSettingsOrder)
        var enabled = splitUnique(settings.quickSettingsEnabled)
        for (var i = 0; i < knownActions.length; ++i) {
            if (order.indexOf(knownActions[i].id) < 0)
                order.push(knownActions[i].id)
        }
        for (var j = 0; j < order.length; ++j) {
            var item = definition(order[j])
            if (item) {
                actionModel.append({
                    "actionId": item.id,
                    "actionLabel": item.label,
                    "actionIcon": item.icon,
                    "actionEnabled": enabled.indexOf(item.id) >= 0
                })
            }
        }
    }

    function saveModel() {
        var order = []
        var enabled = []
        for (var i = 0; i < actionModel.count; ++i) {
            var item = actionModel.get(i)
            order.push(String(item.actionId))
            if (item.actionEnabled)
                enabled.push(String(item.actionId))
        }
        settings.quickSettingsOrder = order.join(",")
        settings.quickSettingsEnabled = enabled.join(",")
    }

    ListModel { id: actionModel }

    Component.onCompleted: loadModel()

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

            PageHeader { title: qsTr("Quick settings") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Choose and arrange the actions shown after holding 123. "
                           + "Unavailable actions, such as Clipboard while clipboard history "
                           + "is off, remain hidden until their feature is enabled.")
            }

            Repeater {
                model: actionModel

                BackgroundItem {
                    width: content.width
                    height: Theme.itemSizeLarge

                    Icon {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.iconSizeSmall
                        height: width
                        // The theme clipboard artwork contains more internal
                        // padding, so enlarge only its glyph while keeping the
                        // fixed icon slot and label alignment unchanged.
                        scale: actionId === "clipboard" ? 1.18 : 1.0
                        source: actionIcon
                        color: parent.highlighted ? Theme.highlightColor
                                                  : Theme.primaryColor
                    }

                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.horizontalPageMargin
                                           + Theme.iconSizeSmall + Theme.paddingMedium
                        anchors.right: upButton.left
                        anchors.rightMargin: Theme.paddingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        text: actionLabel
                        truncationMode: TruncationMode.Fade
                        color: actionEnabled ? Theme.primaryColor : Theme.secondaryColor
                    }

                    IconButton {
                        id: upButton
                        anchors.right: downButton.left
                        anchors.verticalCenter: parent.verticalCenter
                        icon.source: "image://theme/icon-m-up"
                        enabled: index > 0
                        opacity: enabled ? 1.0 : 0.3
                        onClicked: {
                            actionModel.move(index, index - 1, 1)
                            page.saveModel()
                        }
                    }

                    IconButton {
                        id: downButton
                        anchors.right: enabledSwitch.left
                        anchors.verticalCenter: parent.verticalCenter
                        icon.source: "image://theme/icon-m-down"
                        enabled: index + 1 < actionModel.count
                        opacity: enabled ? 1.0 : 0.3
                        onClicked: {
                            actionModel.move(index, index + 1, 1)
                            page.saveModel()
                        }
                    }

                    Switch {
                        id: enabledSwitch
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        checked: actionEnabled
                        onClicked: {
                            actionModel.setProperty(index, "actionEnabled", !actionEnabled)
                            page.saveModel()
                        }
                    }

                    onClicked: {
                        actionModel.setProperty(index, "actionEnabled", !actionEnabled)
                        page.saveModel()
                    }
                }
            }
        }
    }
}
