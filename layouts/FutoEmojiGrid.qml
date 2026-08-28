/* Complete, scrollable Emoji 17 grid with searchable categories and tones. */
import QtQuick 2.0
import Sailfish.Silica 1.0

Item {
    id: emojiGrid

    property Item targetLayout
    property bool followRowHeight: false
    property Item toneSourceKey
    property var toneVariants: []
    property int toneStyle
    property string toneSelectedCode: ""
    readonly property int contentRevision: targetLayout && targetLayout.handler
            && targetLayout.handler.contentRevision !== undefined
            ? targetLayout.handler.contentRevision : 0
    readonly property int columns: {
        var scale = targetLayout ? Number(targetLayout.emojiSizeScale) : 1.0
        if (!isFinite(scale))
            scale = 1.0
        var normalColumns = targetLayout && targetLayout.portraitMode ? 8 : 10
        var result = Math.max(5, Math.min(14, Math.round(normalColumns / scale)))
        // A split picker needs the same number of keys on both thumb sides.
        if (targetLayout && targetLayout.splitActive && result % 2 !== 0)
            result = Math.max(6, result - 1)
        return result
    }
    readonly property var entries: targetLayout ? targetLayout.emojiEntriesForPage() : []
    readonly property bool split: targetLayout && targetLayout.splitActive
    readonly property real splitGap: split ? Number(targetLayout.avoidanceWidth) : 0
    height: targetLayout ? 3 * targetLayout.keyHeight : 0

    function openTonePicker(key) {
        toneSourceKey = key
        var snapshot = [key.baseVariant()]
        for (var i = 0; i < key.variants.length; ++i)
            snapshot.push(key.variants[i])
        toneVariants = snapshot
        toneStyle = key.emojiStyle
        toneSelectedCode = key.effectiveVariant ? key.effectiveVariant.c : ""
        tonePopup.visible = true
        toneGrid.positionViewAtBeginning()
    }

    function closeTonePicker() {
        tonePopup.visible = false
        toneSourceKey = null
        toneVariants = []
        toneSelectedCode = ""
    }

    function feedback() {
        if (targetLayout && targetLayout.handler
                && targetLayout.handler.playOptionFeedback)
            targetLayout.handler.playOptionFeedback()
    }

    function toneAssetPath(code, bundled) {
        var directory = toneStyle === 1 ? "openmoji" : toneStyle === 2 ? "noto" : "twemoji"
        var home = String(StandardPaths.home)
        var userRoot = (home.indexOf("file://") === 0 ? home : "file://" + home)
                + "/.local/share/futo-keyboard-sailfish/content/emoji/"
        var root = bundled ? "file:///usr/share/futo-keyboard-sailfish/emoji/" : userRoot
        return root + directory + "/" + String(code).toLowerCase()
                + (toneStyle === 2 ? ".png" : ".svg")
                + "?r=" + contentRevision
    }

    SilicaListView {
        id: grid
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        readonly property real cellWidth: (width - emojiGrid.splitGap)
                                          / emojiGrid.columns
        readonly property real cellHeight: cellWidth
        model: Math.ceil(emojiGrid.entries.length / emojiGrid.columns)

        delegate: Item {
            id: emojiRow
            width: grid.width
            height: grid.cellHeight
            readonly property int rowIndex: index
            readonly property int firstEntry: rowIndex * emojiGrid.columns
            readonly property int entryCount: Math.min(
                    emojiGrid.columns,
                    Math.max(0, emojiGrid.entries.length - firstEntry))

            Repeater {
                model: emojiRow.entryCount

                FutoEmojiKey {
                    id: emojiDelegate
                    readonly property int cellColumn: index
                    readonly property var entry:
                            emojiGrid.entries[emojiRow.firstEntry + cellColumn]
                    x: cellColumn * grid.cellWidth
                       + (emojiGrid.split && cellColumn >= emojiGrid.columns / 2
                          ? emojiGrid.splitGap : 0)
                    width: grid.cellWidth
                    height: grid.cellHeight
                    emojiText: entry ? entry.t : ""
                    assetCode: entry ? entry.c : ""
                    variants: entry && entry.v ? entry.v : []
                    emojiStyle: targetLayout.emojiStyle
                    skinTone: targetLayout.emojiSkinTone
                    onToneRequested: emojiGrid.openTonePicker(emojiDelegate)
                    onEmojiCommitted: targetLayout.recordEmoji(baseCode)
                }
            }
        }

        VerticalScrollDecorator {}
    }

    Label {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.horizontalPageMargin
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: Theme.secondaryColor
        text: targetLayout && targetLayout.emojiPage === 0
              ? qsTr("No recent emoji yet") : qsTr("No emoji match this search")
        visible: emojiGrid.entries.length === 0
    }

    MouseArea {
        anchors.fill: parent
        z: 20
        visible: tonePopup.visible
        onClicked: {
            emojiGrid.feedback()
            emojiGrid.closeTonePicker()
        }
    }

    Rectangle {
        id: tonePopup
        z: 21
        visible: false
        anchors.centerIn: parent
        readonly property int itemCount: emojiGrid.toneVariants.length
        readonly property int columnCount: Math.min(6, Math.max(1, itemCount))
        readonly property int rowCount: Math.ceil(itemCount / columnCount)
        width: Math.min(parent.width - 2 * Theme.paddingMedium,
                        columnCount * Theme.itemSizeMedium)
        height: Math.min(parent.height - 2 * Theme.paddingMedium,
                         Math.min(4, rowCount) * Theme.itemSizeMedium)
        radius: Theme.paddingSmall
        color: Theme.rgba(Theme.highlightDimmerColor, 0.98)
        border.width: 1
        border.color: Theme.highlightColor

        GridView {
            id: toneGrid
            anchors.fill: parent
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cellWidth: tonePopup.width / tonePopup.columnCount
            cellHeight: Theme.itemSizeMedium
            model: emojiGrid.toneVariants

            delegate: BackgroundItem {
                id: toneDelegate
                width: toneGrid.cellWidth
                height: toneGrid.cellHeight
                readonly property var variant: modelData
                property bool bundledFallback: false

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    color: "transparent"
                    border.width: toneDelegate.variant
                                  && toneDelegate.variant.c === emojiGrid.toneSelectedCode ? 2 : 0
                    border.color: Theme.highlightColor
                }

                Image {
                    id: toneImage
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) * 0.72
                    height: width
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    source: !toneDelegate.variant ? ""
                            : emojiGrid.toneAssetPath(toneDelegate.variant.c,
                                                      toneDelegate.bundledFallback)
                    onStatusChanged: {
                        if (status === Image.Error && !toneDelegate.bundledFallback)
                            toneDelegate.bundledFallback = true
                    }
                }

                Label {
                    anchors.centerIn: parent
                    width: parent.width * 0.8
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Math.min(parent.width, parent.height) * 0.52
                    color: Theme.primaryColor
                    text: toneDelegate.variant ? toneDelegate.variant.t : ""
                    visible: toneImage.status === Image.Error || toneImage.source === ""
                }

                onVariantChanged: bundledFallback = false

                onClicked: {
                    emojiGrid.feedback()
                    if (emojiGrid.toneSourceKey)
                        emojiGrid.toneSourceKey.triggerVariant(index)
                    emojiGrid.closeTonePicker()
                }
            }

            VerticalScrollDecorator {}
        }
    }

    Connections {
        target: targetLayout
        onEmojiPageChanged: {
            grid.positionViewAtBeginning()
            emojiGrid.closeTonePicker()
        }
        onEmojiModeChanged: {
            if (targetLayout.emojiMode)
                grid.positionViewAtBeginning()
            else
                emojiGrid.closeTonePicker()
        }
        onEmojiSizeScaleChanged: grid.positionViewAtBeginning()
    }
}
