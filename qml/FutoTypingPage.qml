import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import Nemo.DBus 2.0

Page {
    id: page
    allowedOrientations: Orientation.All

    property bool predictionContentReady: false
    property bool predictionModelInstalled: false
    property bool pendingPredictionDownloads: false
    property bool requestedPredictionEnable: false

    onStatusChanged: {
        if (status === PageStatus.Active) {
            refreshPredictionContent()
            if (pendingPredictionDownloads && !predictionDownloadNavigation.running)
                predictionDownloadNavigation.start()
        }
    }

    Timer {
        id: predictionDownloadNavigation
        interval: 1
        repeat: false
        onTriggered: {
            page.pendingPredictionDownloads = false
            pageStack.push(Qt.resolvedUrl("FutoContentListPage.qml"), {
                "packKind": "prediction",
                "pageTitle": qsTr("Prediction models"),
                "requestedPackId": "prediction-english-futo"
            })
        }
    }

    function setContextPredictionEnabled(enabled) {
        settings.contextPredictionEnabled = !!enabled
        helper.typedCall("SetContextPredictionEnabled", [
            { "type": "b", "value": !!enabled }
        ], function() {}, function() {})
    }

    function refreshPredictionContent() {
        if (helper.status !== DBusInterface.Available)
            return
        helper.typedCall("ContentStatus", [], function(resultJson) {
            var result
            try {
                result = JSON.parse(String(resultJson))
            } catch (error) {
                return
            }
            var installed = false
            var items = result.items || []
            for (var i = 0; i < items.length; ++i) {
                if (String(items[i].id) === "prediction-english-futo") {
                    installed = !!items[i].installed
                    break
                }
            }
            page.predictionModelInstalled = installed
            page.predictionContentReady = true
            if (installed && page.requestedPredictionEnable) {
                page.setContextPredictionEnabled(true)
                page.requestedPredictionEnable = false
            } else if (!installed && settings.contextPredictionEnabled) {
                page.setContextPredictionEnabled(false)
            } else if (!installed && page.status === PageStatus.Active
                       && !page.pendingPredictionDownloads
                       && !predictionDownloadNavigation.running) {
                page.requestedPredictionEnable = false
            }
        })
    }

    function openPredictionDownloads() {
        var dialog = pageStack.push(Qt.resolvedUrl("FutoContentRequiredDialog.qml"), {
            "contentName": qsTr("context-aware English prediction model"),
            "explanation": qsTr("Context-aware predictions need the optional English model. "
                                + "Open the Prediction models downloader to install it?")
        })
        dialog.accepted.connect(function() {
            page.requestedPredictionEnable = true
            page.pendingPredictionDownloads = true
        })
    }

    ConfigurationGroup {
        id: settings
        path: "/sailfish/text_input/futo_keyboard"
        property bool predictionEnabled: true
        property bool contextPredictionEnabled: true
        property bool nextWordPredictionEnabled: true
        property bool allowSuggestionsWithSpaces: true
        property bool autoCorrectionEnabled: false
        property bool punctuationCorrectionEnabled: false
        property int correctionLevel: 0
        property bool showTypedWord: true
        property bool autoSpaceAfterSuggestion: true
        property int suggestionCount: 12
        property bool smartPunctuationEnabled: true
        property bool spaceAfterPunctuationEnabled: false
        property bool doubleSpacePeriodEnabled: true
        property bool autoCapitalizationEnabled: true
        property bool undoCorrectionEnabled: true
        property bool centerPredictions: false
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
            if (String(packId) === "prediction-english-futo")
                page.refreshPredictionContent()
        }

        onStatusChanged: {
            if (status === DBusInterface.Available)
                page.refreshPredictionContent()
        }
    }

    Component.onCompleted: refreshPredictionContent()

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
                    if (!settings.predictionEnabled) {
                        settings.autoCorrectionEnabled = false
                        settings.punctuationCorrectionEnabled = false
                    }
                }
            }

            TextSwitch {
                width: parent.width
                enabled: settings.predictionEnabled
                         && (page.predictionContentReady
                             || settings.contextPredictionEnabled)
                automaticCheck: false
                checked: settings.contextPredictionEnabled
                text: qsTr("Use context-aware English model")
                description: page.predictionModelInstalled
                        ? qsTr("Uses the downloaded model for better English corrections "
                               + "and next-word suggestions.")
                        : qsTr("Requires the optional English prediction model download.")
                onClicked: {
                    if (!checked && !page.predictionModelInstalled)
                        page.openPredictionDownloads()
                    else
                        page.setContextPredictionEnabled(!checked)
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
                checked: settings.allowSuggestionsWithSpaces
                enabled: settings.predictionEnabled
                text: qsTr("Suggestions containing spaces")
                description: qsTr("Turn this off to suggest only single words, without "
                                  + "splitting words or suggesting phrases.")
                onClicked: settings.allowSuggestionsWithSpaces = !checked
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
                enabled: settings.predictionEnabled
                         && (settings.autoCorrectionEnabled
                             || settings.punctuationCorrectionEnabled)
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
                enabled: settings.predictionEnabled
                         && (settings.autoCorrectionEnabled
                             || settings.punctuationCorrectionEnabled)
                text: qsTr("Backspace restores an auto-corrected word")
                onClicked: settings.undoCorrectionEnabled = !checked
            }

            SectionHeader { text: qsTr("Punctuation") }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.punctuationCorrectionEnabled
                enabled: settings.predictionEnabled
                text: qsTr("Correct typos when pressing punctuation")
                description: qsTr("Uses the correction shown above the keyboard. "
                                  + "Web addresses, email addresses, and private fields "
                                  + "are left unchanged.")
                onClicked: settings.punctuationCorrectionEnabled = !checked
            }

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
                checked: settings.spaceAfterPunctuationEnabled
                text: qsTr("Add space after punctuation")
                description: qsTr("Separates a punctuation mark from the word "
                                  + "which follows it. Web and email addresses "
                                  + "are left as they are typed.")
                onClicked: settings.spaceAfterPunctuationEnabled = !checked
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
