/* Scrollable private clipboard history shown inside the keyboard. */
import QtQuick 2.0
import Sailfish.Silica 1.0

Item {
    id: panel

    property Item targetLayout
    // InputHandler is a QObject, not a visual Item. Keeping this QtObject-typed
    // avoids a type-assignment failure that would prevent the layout loading.
    property QtObject targetHandler

    Rectangle {
        anchors.fill: parent
        // The normal key rows are hidden while this panel is visible, so a
        // transparent item exposes the black compositor surface.  Recreate
        // the keyboard's softly raised ambience surface here instead.
        color: Theme.rgba(Theme.primaryColor, 0.12)
    }

    Item {
        id: header
        anchors.top: parent.top
        width: parent.width
        height: targetLayout ? targetLayout.keyHeight : Theme.itemSizeSmall

        IconButton {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            icon.source: "image://theme/icon-m-back"
            onClicked: {
                if (targetHandler)
                    targetHandler.playOptionFeedback()
                targetLayout.hideClipboardHistory()
            }
        }

        Label {
            anchors.centerIn: parent
            text: qsTr("Clipboard")
            color: Theme.highlightColor
            font.pixelSize: Theme.fontSizeMedium
        }
    }

    SilicaListView {
        id: historyList
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: targetHandler ? targetHandler.clipboardHistoryModel : null

        delegate: BackgroundItem {
            id: entryDelegate
            property string deleteEntryId: ""
            width: historyList.width
            height: Math.max(Theme.itemSizeMedium, entryText.implicitHeight + Theme.paddingLarge)
            onClicked: {
                targetHandler.playOptionFeedback()
                targetHandler.pasteClipboardEntry(model.text)
            }

            RemorseItem {
                id: deleteRemorse
            }

            Label {
                id: entryText
                anchors.left: parent.left
                anchors.right: pinButton.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Theme.paddingLarge
                anchors.rightMargin: Theme.paddingSmall
                text: String(model.text).replace(/\n/g, " ↵ ")
                maximumLineCount: 2
                wrapMode: Text.Wrap
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeSmall
            }

            IconButton {
                id: pinButton
                anchors.right: deleteButton.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.itemSizeSmall
                height: parent.height
                icon.source: model.pinned ? "image://theme/icon-m-favorite-selected"
                                             : "image://theme/icon-m-favorite"
                onClicked: {
                    targetHandler.playOptionFeedback()
                    targetHandler.setClipboardPinned(model.entryId, !model.pinned)
                }
            }

            IconButton {
                id: deleteButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.itemSizeSmall
                height: parent.height
                icon.source: "image://theme/icon-m-delete"
                onClicked: {
                    targetHandler.playOptionFeedback()
                    entryDelegate.deleteEntryId = String(model.entryId)
                    deleteRemorse.execute(entryDelegate, qsTr("Deleting"), function() {
                        targetHandler.deleteClipboardEntry(entryDelegate.deleteEntryId)
                    })
                }
            }
        }

        ViewPlaceholder {
            enabled: historyList.count === 0
            text: qsTr("Clipboard history is empty")
            hintText: qsTr("Copy text while Incognito mode is off")
        }

        VerticalScrollDecorator {}
    }
}
