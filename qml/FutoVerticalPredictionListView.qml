// Landscape prediction strip with a per-word, self-canceling remove mode.
import QtQuick 2.6
import Sailfish.Silica 1.0
import com.meego.maliitquick 1.0
import com.jolla.keyboard 1.0

PredictionListView {
    id: view

    property int removalIndex: -1
    clip: true

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

    Component.onCompleted: {
        if (Clipboard.hasText)
            stateChange.restart()
    }

    onPredictionsChanged: {
        cancelRemoval()
        if (!stateChange.running)
            positionViewAtIndex(0, ListView.Beginning)
    }
    onCanRemoveChanged: {
        if (!canRemove)
            cancelRemoval()
    }

    header: PasteButtonVertical {
        visible: Clipboard.hasText
        width: view.width
        height: visible ? geometry.keyHeightLandscape : 0
        popupParent: view.parent
        popupAnchor: 2
        onClicked: {
            view.cancelRemoval()
            view.handler.paste(Clipboard.text)
        }
    }

    delegate: BackgroundItem {
        id: delegate

        readonly property bool removing: index === view.removalIndex
        width: parent.width
        height: geometry.keyHeightLandscape

        onClicked: {
            if (view.removalIndex >= 0)
                view.cancelRemoval()
            else
                view.handler.select(model.text, model.index)
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
            width: delegate.width - (delegate.removing ? Theme.itemSizeExtraSmall : 0)
            height: delegate.height
            text: view.handler.formatText(model.text)
            font.pixelSize: Theme.fontSizeSmall
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            textFormat: Text.StyledText
            fontSizeMode: Text.HorizontalFit

            Behavior on width { NumberAnimation { duration: 100 } }
        }

        IconButton {
            x: delegate.width - width
            width: Theme.itemSizeExtraSmall
            height: delegate.height
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
            view.positionViewAtBeginning()
            stateChange.restart()
        }
    }
    Connections {
        target: MInputMethodQuick
        onFocusTargetChanged: {
            view.cancelRemoval()
            view.positionViewAtBeginning()
            stateChange.restart()
        }
    }

    Timer { id: removalTimer; interval: 3000; onTriggered: view.cancelRemoval() }
    Timer { id: stateChange; interval: 1000 }
}
