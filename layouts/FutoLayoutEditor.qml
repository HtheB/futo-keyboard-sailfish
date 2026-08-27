/* Per-language visual layout editor for the FUTO keyboard surface. */
import QtQuick 2.0
import Sailfish.Silica 1.0

Item {
    id: editor

    property Item targetLayout
    property string selectedLanguage: ""
    readonly property var enabledLanguages: targetLayout
                                            ? targetLayout.enabledPredictionLanguages() : []
    readonly property var layoutChoices: targetLayout && selectedLanguage !== ""
                                         ? targetLayout.compatibleLetterLayouts(selectedLanguage)
                                         : []

    function selectedLayout() {
        return targetLayout && selectedLanguage !== ""
                ? targetLayout.layoutForLanguage(selectedLanguage) : 0
    }

    function feedback() {
        if (targetLayout && targetLayout.handler
                && targetLayout.handler.playOptionFeedback)
            targetLayout.handler.playOptionFeedback()
    }

    function syncSelection() {
        var wanted = selectedLayout()
        var index = layoutChoices.indexOf(wanted)
        previewList.currentIndex = Math.max(0, index)
        previewList.positionViewAtIndex(previewList.currentIndex, ListView.Center)
    }

    function ensureLanguage() {
        if (enabledLanguages.length < 1) {
            selectedLanguage = "EN"
        } else if (enabledLanguages.indexOf(selectedLanguage) < 0) {
            selectedLanguage = enabledLanguages[0]
        }
        syncTimer.restart()
    }

    Component.onCompleted: ensureLanguage()
    onEnabledLanguagesChanged: ensureLanguage()
    onSelectedLanguageChanged: syncTimer.restart()

    Timer {
        id: syncTimer
        interval: 0
        onTriggered: editor.syncSelection()
    }

    Rectangle {
        anchors.fill: parent
        // Match the softly raised keyboard surface.  overlayBackgroundColor
        // is effectively black on this device and made the editor look like
        // an unrelated full-black page.
        color: Theme.rgba(Theme.primaryColor, 0.12)
    }

    Item {
        id: header
        anchors.top: parent.top
        width: parent.width
        height: Math.max(Theme.itemSizeSmall, editor.height * 0.15)

        IconButton {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            icon.source: "image://theme/icon-m-back"
            onClicked: {
                editor.feedback()
                targetLayout.hideLayoutEditor()
            }
        }

        Label {
            anchors.centerIn: parent
            text: qsTr("Layout for %1").arg(
                      targetLayout ? targetLayout.languageName(editor.selectedLanguage) : "")
            color: Theme.highlightColor
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    ListView {
        id: previewList
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: editor.height - header.height - languageTabs.height
        orientation: ListView.Horizontal
        spacing: Theme.paddingMedium
        clip: true
        model: editor.layoutChoices
        snapMode: ListView.SnapOneItem
        boundsBehavior: Flickable.StopAtBounds
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: width * 0.11
        preferredHighlightEnd: width * 0.89

        onMovementEnded: {
            if (currentIndex >= 0 && currentIndex < editor.layoutChoices.length) {
                editor.feedback()
                targetLayout.assignLayoutToLanguage(editor.selectedLanguage,
                                                    editor.layoutChoices[currentIndex])
            }
        }

        header: Item { width: previewList.width * 0.11; height: 1 }
        footer: Item { width: previewList.width * 0.11; height: 1 }

        delegate: BackgroundItem {
            id: previewCard
            property int layoutIndex: Number(modelData)
            width: previewList.width * 0.78
            height: previewList.height
            onClicked: {
                editor.feedback()
                previewList.currentIndex = index
                targetLayout.assignLayoutToLanguage(editor.selectedLanguage, layoutIndex)
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: Theme.paddingSmall
                radius: Theme.paddingSmall
                color: Theme.rgba(Theme.primaryColor, 0.08)
                border.width: targetLayout.layoutForLanguage(editor.selectedLanguage)
                              === previewCard.layoutIndex ? 2 : 1
                border.color: targetLayout.layoutForLanguage(editor.selectedLanguage)
                              === previewCard.layoutIndex
                              ? Theme.highlightColor : Theme.secondaryColor
            }

            Column {
                id: keyRows
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: layoutName.top
                anchors.margins: Theme.paddingMedium
                spacing: 2

                Repeater {
                    model: 3
                    Row {
                        id: miniRow
                        property int rowIndex: index
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: (keyRows.height - 4) / 3
                        spacing: 2

                        Repeater {
                            model: targetLayout.rowLengthForLayout(previewCard.layoutIndex,
                                                                   miniRow.rowIndex)
                            Rectangle {
                                width: Math.max(18, (previewCard.width - 2 * Theme.paddingLarge
                                                    - (targetLayout.rowLengthForLayout(
                                                           previewCard.layoutIndex,
                                                           miniRow.rowIndex) - 1) * 2)
                                                   / Math.max(1, targetLayout.rowLengthForLayout(
                                                                  previewCard.layoutIndex,
                                                                  miniRow.rowIndex)))
                                height: miniRow.height
                                radius: 2
                                color: Theme.rgba(Theme.primaryColor, 0.12)
                                Label {
                                    anchors.centerIn: parent
                                    text: targetLayout.letterForLayout(previewCard.layoutIndex,
                                                                       miniRow.rowIndex, index)
                                    font.pixelSize: Theme.fontSizeTiny
                                }
                            }
                        }
                    }
                }
            }

            Label {
                id: layoutName
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.paddingSmall
                anchors.horizontalCenter: parent.horizontalCenter
                text: targetLayout.letterLayoutName(previewCard.layoutIndex)
                color: targetLayout.layoutForLanguage(editor.selectedLanguage)
                       === previewCard.layoutIndex
                       ? Theme.highlightColor : Theme.primaryColor
                font.pixelSize: Theme.fontSizeSmall
                font.bold: targetLayout.layoutForLanguage(editor.selectedLanguage)
                           === previewCard.layoutIndex
            }

            Label {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.paddingMedium
                text: "✓"
                color: Theme.highlightColor
                visible: targetLayout.layoutForLanguage(editor.selectedLanguage)
                         === previewCard.layoutIndex
                font.pixelSize: Theme.fontSizeMedium
            }
        }
    }

    Flickable {
        id: languageTabs
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(Theme.itemSizeSmall, editor.height * 0.18)
        contentWidth: languageRow.width
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Row {
            id: languageRow
            height: parent.height
            Repeater {
                model: editor.enabledLanguages
                BackgroundItem {
                    width: Math.max(Theme.itemSizeLarge * 1.7,
                                    languageLabel.implicitWidth + 2 * Theme.paddingLarge)
                    height: languageTabs.height
                    onClicked: {
                        editor.feedback()
                        editor.selectedLanguage = String(modelData)
                    }

                    Label {
                        id: languageLabel
                        anchors.centerIn: parent
                        text: targetLayout.languageName(String(modelData))
                        color: editor.selectedLanguage === String(modelData)
                               ? Theme.highlightColor : Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: Theme.paddingLarge
                        anchors.rightMargin: Theme.paddingLarge
                        height: 3
                        color: Theme.highlightColor
                        visible: editor.selectedLanguage === String(modelData)
                    }
                }
            }
        }
    }
}
