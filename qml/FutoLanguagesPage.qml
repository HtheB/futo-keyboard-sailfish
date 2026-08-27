/* Language selection subpage for FUTO Keyboard. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import Nemo.DBus 2.0
// The settings page is installed separately from the Maliit layout files.
// Keep a packaged copy beside this page so the import also resolves on-device.
import "FutoLetterLayouts.js" as LetterLayouts

Page {
    id: page
    allowedOrientations: Orientation.All
    property string statusText: ""
    property bool dictionaryContentReady: false
    property var installedDictionaries: ({})
    property string pendingDictionaryCode: ""

    onStatusChanged: {
        if (status === PageStatus.Active && pendingDictionaryCode !== ""
                && !dictionaryDownloadNavigation.running)
            dictionaryDownloadNavigation.start()
    }

    Timer {
        id: dictionaryDownloadNavigation
        interval: 1
        repeat: false
        onTriggered: {
            var code = page.pendingDictionaryCode
            page.pendingDictionaryCode = ""
            pageStack.push(Qt.resolvedUrl("FutoContentListPage.qml"), {
                "packKind": "dictionary",
                "pageTitle": qsTr("Dictionaries"),
                "requestedPackId": page.dictionaryPackId(code)
            })
        }
    }

    function dictionaryPackId(code) {
        return "dictionary-" + String(code).toLowerCase().replace("_", "-")
                    .replace(/^en$/, "en-us")
    }

    function refreshDictionaryContent() {
        if (helper.status !== DBusInterface.Available)
            return
        helper.typedCall("ContentStatus", [], function(resultJson) {
            var result
            try {
                result = JSON.parse(String(resultJson))
            } catch (error) {
                page.statusText = qsTr("Could not check installed dictionaries")
                return
            }
            var installed = {}
            var items = result.items || []
            for (var i = 0; i < items.length; ++i) {
                if (String(items[i].kind) === "dictionary")
                    installed[String(items[i].id)] = !!items[i].installed
            }
            page.installedDictionaries = installed
            page.dictionaryContentReady = true
            page.statusText = ""
        }, function() {
            page.statusText = qsTr("Could not check installed dictionaries")
        })
    }

    function openDictionaryDownloads(code, title) {
        var dialog = pageStack.push(Qt.resolvedUrl("FutoContentRequiredDialog.qml"), {
            "contentName": qsTr("%1 dictionary").arg(title),
            "explanation": qsTr("Predictions for this language need its offline dictionary. "
                                + "Open the Dictionaries downloader to install it?")
        })
        dialog.accepted.connect(function() {
            page.pendingDictionaryCode = code
        })
    }

    function enabledCodes() {
        var raw = String(settings.enabledLanguages).split(",")
        var result = []
        for (var i = 0; i < raw.length; ++i) {
            var code = raw[i].trim()
            if (code !== "" && result.indexOf(code) < 0)
                result.push(code)
        }
        return result
    }

    function languageEnabled(code) {
        return enabledCodes().indexOf(code) >= 0
    }

    function setLanguage(code, title, enabled) {
        var codes = enabledCodes()
        var index = codes.indexOf(code)
        if (!enabled && index >= 0 && codes.length <= 1) {
            statusText = qsTr("At least one prediction language must stay enabled")
            return
        }
        if (enabled && index < 0 && predictionSupported(code)) {
            if (!dictionaryContentReady) {
                statusText = qsTr("Checking installed dictionaries…")
                refreshDictionaryContent()
                return
            }
            if (!installedDictionaries[dictionaryPackId(code)]) {
                openDictionaryDownloads(code, title)
                return
            }
        }
        if (enabled && index < 0)
            codes.push(code)
        else if (!enabled && index >= 0)
            codes.splice(index, 1)
        settings.enabledLanguages = codes.join(",")
        statusText = ""
    }

    function layoutAssignments() {
        var result = {}
        try {
            result = JSON.parse(String(settings.layoutAssignments))
        } catch (error) {
            result = {}
        }
        return result && typeof result === "object" ? result : {}
    }

    function assignedLayout(code) {
        var assignments = layoutAssignments()
        var manualAssignments = manualAssignmentFlags()
        var value = Number(assignments[String(code)])
        return isFinite(value) && (languageEnabled(code) || manualAssignments[String(code)])
                ? LetterLayouts.clampedIndex(value)
                : LetterLayouts.defaultForLanguage(code)
    }

    function manualAssignmentFlags() {
        var result = {}
        try {
            result = JSON.parse(String(settings.manualLayoutAssignments))
        } catch (error) {
            result = {}
        }
        return result && typeof result === "object" ? result : {}
    }

    function predictionSupported(code) {
        return code !== "AR" && code !== "EL" && code !== "RU"
    }

    ConfigurationGroup {
        id: settings
        path: "/sailfish/text_input/futo_keyboard"
        property string enabledLanguages: "EN,NL,TR"
        property string layoutAssignments: "{}"
        property string manualLayoutAssignments: "{}"
        property bool automaticLanguageDetection: true
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
            page.refreshDictionaryContent()
        }

        onStatusChanged: {
            if (status === DBusInterface.Available)
                page.refreshDictionaryContent()
        }
    }

    Component.onCompleted: refreshDictionaryContent()

    ListModel {
        id: languageModel
        ListElement { code: "CS"; title: "Čeština" }
        ListElement { code: "DA"; title: "Dansk" }
        ListElement { code: "DE"; title: "Deutsch" }
        ListElement { code: "EN_GB"; title: "English (UK)" }
        ListElement { code: "EN"; title: "English (US)" }
        ListElement { code: "ES"; title: "Español" }
        ListElement { code: "FR"; title: "Français" }
        ListElement { code: "HR"; title: "Hrvatski" }
        ListElement { code: "IT"; title: "Italiano" }
        ListElement { code: "LV"; title: "Latviešu" }
        ListElement { code: "LT"; title: "Lietuvių" }
        ListElement { code: "NL"; title: "Nederlands" }
        ListElement { code: "NB"; title: "Norsk bokmål" }
        ListElement { code: "PL"; title: "Polski" }
        ListElement { code: "PT_BR"; title: "Português (Brasil)" }
        ListElement { code: "PT_PT"; title: "Português (Portugal)" }
        ListElement { code: "RO"; title: "Română" }
        ListElement { code: "SL"; title: "Slovenščina" }
        ListElement { code: "FI"; title: "Suomi" }
        ListElement { code: "SV"; title: "Svenska" }
        ListElement { code: "TR"; title: "Türkçe" }
        // Non-Latin scripts are grouped after the Latin layouts.
        ListElement { code: "EL"; title: "Ελληνικά" }
        ListElement { code: "RU"; title: "Русский" }
        ListElement { code: "AR"; title: "العربية" }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge
        VerticalScrollDecorator { flickable: parent }

        Column {
            id: content
            width: parent.width

            PageHeader { title: qsTr("Prediction languages") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Every enabled language is checked for each word. Keep the set focused "
                           + "for faster suggestions and better automatic ranking.")
            }

            TextSwitch {
                width: parent.width
                automaticCheck: false
                checked: settings.automaticLanguageDetection
                text: qsTr("Detect and rank active languages automatically")
                description: qsTr("Languages sharing the current layout are checked together.")
                onClicked: settings.automaticLanguageDetection = !checked
            }

            Repeater {
                model: languageModel
                BackgroundItem {
                    id: languageItem
                    width: content.width
                    height: Math.max(Theme.itemSizeLarge,
                                     languageLabels.height + 2 * Theme.paddingMedium)
                    onClicked: page.setLanguage(code, title, !page.languageEnabled(code))

                    Switch {
                        id: languageSwitch
                        width: Theme.itemSizeSmall
                        anchors {
                            left: parent.left
                            leftMargin: Theme.horizontalPageMargin
                            verticalCenter: parent.verticalCenter
                        }
                        checked: page.languageEnabled(code)
                        onClicked: page.setLanguage(code, title, !page.languageEnabled(code))
                    }

                    Column {
                        id: languageLabels
                        anchors {
                            // A Sailfish Switch has a deliberately large invisible
                            // touch target.  Anchoring to its right edge therefore
                            // leaves a conspicuous blank area after the visible
                            // checkbox.  Position the labels from the row instead.
                            left: parent.left
                            leftMargin: Theme.horizontalPageMargin
                                        + Theme.iconSizeMedium
                                        + Theme.paddingSmall
                            right: parent.right
                            rightMargin: Theme.horizontalPageMargin
                            verticalCenter: parent.verticalCenter
                        }

                        Label {
                            // Keep right-to-left shaping and alignment inside a
                            // compact label beside the switch. Giving Arabic the
                            // full row width would place it at the screen edge.
                            width: Math.min(implicitWidth, languageLabels.width)
                            horizontalAlignment: code === "AR"
                                                 ? Text.AlignRight : Text.AlignLeft
                            color: languageItem.highlighted
                                   ? Theme.highlightColor : Theme.primaryColor
                            text: title
                            truncationMode: TruncationMode.Fade
                        }

                        Label {
                            width: parent.width
                            color: languageItem.highlighted
                                   ? Theme.secondaryHighlightColor : Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            text: qsTr("%1%2").arg(
                                  LetterLayouts.name(page.assignedLayout(code))).arg(
                                  !page.predictionSupported(code)
                                  ? qsTr(" · direct typing only")
                                  : page.dictionaryContentReady
                                    && !page.installedDictionaries[page.dictionaryPackId(code)]
                                  ? qsTr(" · download required") : "")
                            truncationMode: TruncationMode.Fade
                        }
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                text: page.statusText
                visible: text !== ""
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Assign layouts visually from the keyboard: hold 123 and choose "
                           + "Edit layouts. Languages assigned to the same layout are predicted "
                           + "together.")
            }
        }
    }
}
