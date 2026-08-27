// FUTO-specific prediction strip with a per-word, self-canceling remove mode.
import QtQuick 2.6
import Sailfish.Silica 1.0
import com.jolla.keyboard 1.0
import Nemo.Configuration 1.0

PredictionListView {
    id: view

    property int removalIndex: -1
    property real predictionItemsWidth: 0
    readonly property real _maximumLabelWidth: width - (2 * Theme.paddingLarge)
    readonly property real centeredHeaderWidth: predictionSettings.centerPredictions
            && predictionItemsWidth > 0 && predictionItemsWidth < width
            ? Math.max(0, (width - predictionItemsWidth) / 2) : 0

    orientation: ListView.Horizontal

    ConfigurationGroup {
        id: predictionSettings
        path: "/sailfish/text_input/futo_keyboard"
        property bool centerPredictions: false
        onCenterPredictionsChanged: geometryTimer.restart()
    }

    function refreshPredictionGeometry() {
        var total = 0
        var items = contentItem ? contentItem.children : []
        for (var i = 0; i < items.length; ++i) {
            if (items[i].predictionDelegate)
                total += Number(items[i].width)
        }
        predictionItemsWidth = total
        positionViewAtBeginning()
    }

    function cancelRemoval() {
        removalTimer.stop()
        removalIndex = -1
        showRemoveButton = false
        currentIndex = -1
    }

    function beginRemoval(index) {
        removalIndex = index
        currentIndex = index
        showRemoveButton = true
        removalTimer.restart()
    }

    onPredictionsChanged: {
        cancelRemoval()
        geometryTimer.restart()
    }
    onCanRemoveChanged: {
        if (!canRemove)
            cancelRemoval()
    }

    header: Item {
        width: Math.max(view.centeredHeaderWidth, pasteButton.width)
        height: view.height

        PasteButton {
            id: pasteButton
            anchors.left: parent.left
            onClicked: {
                view.cancelRemoval()
                view.handler.paste(Clipboard.text)
                keyboard.expandedPaste = false
            }
        }
    }

    delegate: BackgroundItem {
        id: delegate

        property bool predictionDelegate: true
        readonly property bool removing: index === view.removalIndex
        readonly property real buttonMargin: removing
                ? Theme.itemSizeExtraSmall : Theme.paddingLarge
        width: Theme.paddingLarge + label.width + buttonMargin
        height: view.height

        Behavior on width { NumberAnimation { duration: 100 } }
        onWidthChanged: geometryTimer.restart()

        onClicked: {
            if (view.removalIndex >= 0) {
                view.cancelRemoval()
            } else {
                view.handler.select(model.text, model.index)
            }
        }

        onPressAndHold: {
            if (view.canRemove && !delegate.removing) {
                view.beginRemoval(index)
                delegate.HorizontalAutoScroll.keepVisible = Qt.binding(function() {
                    return delegate.ListView.isCurrentItem
                })
            } else {
                view.cancelRemoval()
            }
        }

        Label {
            id: label

            x: Theme.paddingLarge
            width: Math.min(implicitWidth,
                            view._maximumLabelWidth + Theme.paddingLarge
                            - delegate.buttonMargin)
            height: delegate.height
            text: view.handler.formatText(model.text)
            font.pixelSize: Theme.fontSizeSmall
            verticalAlignment: Text.AlignVCenter
            truncationMode: TruncationMode.Fade
            textFormat: Text.StyledText
        }

        IconButton {
            x: label.x + label.width
            height: delegate.height
            width: delegate.height
            icon.source: "image://theme/icon-m-input-remove"
            enabled: delegate.removing
            opacity: delegate.removing ? 1 : 0

            onClicked: {
                removalTimer.stop()
                view.handler.remove(model.text, model.index)
                view.cancelRemoval()
            }

            Behavior on opacity { FadeAnimator { duration: 100 } }
        }
    }

    Connections {
        target: handler
        ignoreUnknownSignals: true
        onTypingContinued: view.cancelRemoval()
    }

    Connections {
        target: Clipboard
        onTextChanged: {
            view.cancelRemoval()
            if (Clipboard.hasText)
                positionerTimer.restart()
        }
    }

    Timer {
        id: removalTimer
        interval: 3000
        onTriggered: view.cancelRemoval()
    }

    Timer {
        id: positionerTimer
        interval: 10
        onTriggered: view.refreshPredictionGeometry()
    }

    Timer {
        id: geometryTimer
        interval: 1
        repeat: false
        onTriggered: view.refreshPredictionGeometry()
    }
}
