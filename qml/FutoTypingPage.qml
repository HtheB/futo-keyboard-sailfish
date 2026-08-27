import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0

Page {
    id: page
    allowedOrientations: Orientation.All

    ConfigurationGroup {
        id: settings
        path: "/sailfish/text_input/futo_keyboard"
        property bool predictionEnabled: true
        property bool nextWordPredictionEnabled: true
        property bool autoCorrectionEnabled: false
        property int correctionLevel: 0
        property bool showTypedWord: true
        property bool autoSpaceAfterSuggestion: true
        property int suggestionCount: 12
        property bool smartPunctuationEnabled: true
        property bool doubleSpacePeriodEnabled: true
        property bool autoCapitalizationEnabled: true
        property bool undoCorrectionEnabled: true
        property bool centerPredictions: false
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
            PageHeader { title: qsTr("Typing and predictions") }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.autoCapitalizationEnabled
                text: qsTr("Capitalize sentences automatically")
                description: qsTr("Shift and Caps Lock still work when this is disabled.")
                onClicked: settings.autoCapitalizationEnabled = !checked
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.predictionEnabled
                text: qsTr("Word suggestions and spelling checks")
                description: qsTr("Turning this off also disables automatic correction and lets "
                                  + "the suggestion strip collapse completely.")
                onClicked: {
                    settings.predictionEnabled = !checked
                    if (!settings.predictionEnabled)
                        settings.autoCorrectionEnabled = false
                }
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.nextWordPredictionEnabled
                enabled: settings.predictionEnabled
                text: qsTr("Next-word suggestions")
                onClicked: settings.nextWordPredictionEnabled = !checked
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.showTypedWord
                enabled: settings.predictionEnabled
                text: qsTr("Keep my exact spelling as the first suggestion")
                onClicked: settings.showTypedWord = !checked
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.centerPredictions
                enabled: settings.predictionEnabled
                text: qsTr("Center suggestions when they fit")
                description: qsTr("Short prediction rows are centered. Long rows remain "
                                  + "left-aligned and scroll normally.")
                onClicked: settings.centerPredictions = !checked
            }

            Slider {
                width: parent.width
                enabled: settings.predictionEnabled
                label: qsTr("Number of suggestions")
                minimumValue: 3
                maximumValue: 12
                stepSize: 1
                value: Math.max(minimumValue, Math.min(maximumValue, settings.suggestionCount))
                valueText: Math.round(value)
                onReleased: settings.suggestionCount = Math.round(value)
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.autoSpaceAfterSuggestion
                enabled: settings.predictionEnabled
                text: qsTr("Add a space after tapping a suggestion")
                onClicked: settings.autoSpaceAfterSuggestion = !checked
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.autoCorrectionEnabled
                enabled: settings.predictionEnabled
                text: qsTr("Correct typos when pressing Space")
                description: qsTr("A word valid in any active language is never replaced.")
                onClicked: settings.autoCorrectionEnabled = !checked
            }

            ComboBox {
                width: parent.width
                enabled: settings.predictionEnabled && settings.autoCorrectionEnabled
                label: qsTr("Correction strength")
                currentIndex: Math.max(0, Math.min(2, settings.correctionLevel))
                onCurrentIndexChanged: settings.correctionLevel = currentIndex
                menu: ContextMenu {
                    MenuItem { text: qsTr("Conservative") }
                    MenuItem { text: qsTr("Balanced") }
                    MenuItem { text: qsTr("Aggressive") }
                }
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.undoCorrectionEnabled
                enabled: settings.autoCorrectionEnabled
                text: qsTr("Backspace restores an auto-corrected word")
                onClicked: settings.undoCorrectionEnabled = !checked
            }

            SectionHeader { text: qsTr("Punctuation") }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.smartPunctuationEnabled
                text: qsTr("Remove the space before punctuation")
                onClicked: settings.smartPunctuationEnabled = !checked
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.doubleSpacePeriodEnabled
                text: qsTr("Double Space inserts a period")
                onClicked: settings.doubleSpacePeriodEnabled = !checked
            }
        }
    }
}
