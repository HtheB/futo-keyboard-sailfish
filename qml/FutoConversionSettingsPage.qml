/* Language-specific options follow FUTO's Mozc and RIME settings. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0

Page {
    id: page
    allowedOrientations: Orientation.All
    function syncSelectors() {
        pinyinCombo.currentIndex = Math.max(0, pinyinCombo.ids.indexOf(settings.chinesePinyinScheme))
        scriptCombo.currentIndex = Math.max(0, scriptCombo.ids.indexOf(settings.chineseOutputScript))
    }
    Component.onCompleted: syncSelectors()
    ConfigurationGroup {
        id: settings
        path: "/sailfish/text_input/futo_keyboard"
        property bool japaneseFlickOnly: false
        property bool japaneseHalfWidthSpace: false
        property string chinesePinyinScheme: "FullPinyin"
        property string chineseOutputScript: "ByLanguage"
        property string chineseFuzzyPinyin: ""
        onChinesePinyinSchemeChanged: page.syncSelectors()
        onChineseOutputScriptChanged: page.syncSelectors()
    }
    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge
        VerticalScrollDecorator {}
        Column {
            id: content
            width: parent.width
            PageHeader { title: qsTr("Japanese and Chinese") }
            SectionHeader { text: qsTr("Japanese") }
            TextSwitch {
                width: parent.width
                text: qsTr("Flick input only")
                description: qsTr("When off, repeated taps also cycle through kana and Latin letters.")
                checked: settings.japaneseFlickOnly
                automaticCheck: false
                onClicked: settings.japaneseFlickOnly = !checked
            }
            TextSwitch {
                width: parent.width
                text: qsTr("Half-width spaces")
                description: qsTr("Use a narrow space even while typing Japanese.")
                checked: settings.japaneseHalfWidthSpace
                automaticCheck: false
                onClicked: settings.japaneseHalfWidthSpace = !checked
            }
            SectionHeader { text: qsTr("Chinese") }
            ComboBox {
                id: pinyinCombo
                width: parent.width
                automaticSelection: false
                label: qsTr("Pinyin input")
                readonly property var ids: ["FullPinyin", "Natural", "ABC", "FlyPY", "MS", "PYJJ", "ST"]
                currentIndex: Math.max(0, ids.indexOf(settings.chinesePinyinScheme))
                menu: ContextMenu {
                    MenuItem { text: qsTr("Full Pinyin"); onClicked: settings.chinesePinyinScheme = "FullPinyin" }
                    MenuItem { text: qsTr("Double Pinyin"); onClicked: settings.chinesePinyinScheme = "Natural" }
                    MenuItem { text: qsTr("Double Pinyin - ABC"); onClicked: settings.chinesePinyinScheme = "ABC" }
                    MenuItem { text: qsTr("Double Pinyin - flyPY"); onClicked: settings.chinesePinyinScheme = "FlyPY" }
                    MenuItem { text: qsTr("Double Pinyin - MS"); onClicked: settings.chinesePinyinScheme = "MS" }
                    MenuItem { text: qsTr("Double Pinyin - PYJJ"); onClicked: settings.chinesePinyinScheme = "PYJJ" }
                    MenuItem { text: qsTr("Double Pinyin - ST"); onClicked: settings.chinesePinyinScheme = "ST" }
                }
            }
            ComboBox {
                id: scriptCombo
                width: parent.width
                automaticSelection: false
                label: qsTr("Output characters")
                readonly property var ids: ["ByLanguage", "Simplified", "Traditional"]
                currentIndex: Math.max(0, ids.indexOf(settings.chineseOutputScript))
                menu: ContextMenu {
                    MenuItem { text: qsTr("Follow selected language"); onClicked: settings.chineseOutputScript = "ByLanguage" }
                    MenuItem { text: qsTr("Simplified"); onClicked: settings.chineseOutputScript = "Simplified" }
                    MenuItem { text: qsTr("Traditional"); onClicked: settings.chineseOutputScript = "Traditional" }
                }
            }
            SectionHeader { text: qsTr("Fuzzy Pinyin") }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                text: qsTr("Treat selected pronunciations as interchangeable when using Full Pinyin.")
            }
            Repeater {
                model: [{id: "Z_ZH", name: "z / zh"}, {id: "C_CH", name: "c / ch"},
                    {id: "S_SH", name: "s / sh"}, {id: "L_N", name: "l / n"},
                    {id: "F_H", name: "f / h"}, {id: "R_L", name: "r / l"},
                    {id: "K_G", name: "k / g"}, {id: "AN_ANG", name: "an / ang"},
                    {id: "EN_ENG", name: "en / eng"}, {id: "IN_ING", name: "in / ing"},
                    {id: "IAN_IANG", name: "ian / iang"}, {id: "UAN_UANG", name: "uan / uang"}]
                TextSwitch {
                    width: parent.width
                    text: modelData.name
                    automaticCheck: false
                    checked: settings.chineseFuzzyPinyin.split(",").indexOf(modelData.id) >= 0
                    onClicked: {
                        var selected = settings.chineseFuzzyPinyin.split(",").filter(function(id) { return id !== "" })
                        var position = selected.indexOf(modelData.id)
                        if (position < 0) selected.push(modelData.id)
                        else selected.splice(position, 1)
                        settings.chineseFuzzyPinyin = selected.join(",")
                    }
                }
            }
        }
    }
}
