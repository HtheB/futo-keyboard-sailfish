/* Lazily loaded Emoji 17 data and grid. */
import QtQuick 2.0
import "FutoEmojiData.js" as EmojiData

Item {
    id: panel

    property Item targetLayout
    property int searchRevision

    width: targetLayout ? targetLayout.width : 0
    height: targetLayout ? 3 * targetLayout.keyHeight : 0

    function entriesForCodes(codes) {
        var result = []
        if (!codes || codes.length === undefined)
            return result
        for (var i = 0; i < codes.length; ++i) {
            var entry = EmojiData.entryForCode(String(codes[i]))
            if (entry)
                result.push(entry)
        }
        return result
    }

    function entriesForPage(page, query, languages, recentCodes) {
        if (page < 0) {
            if (!searchProvider.item)
                return []
            return entriesForCodes(searchProvider.item.matchingCodes(query, languages))
        }
        if (page === 0)
            return entriesForCodes(recentCodes)
        var categoryIndex = Math.max(0, Math.min(EmojiData.categories.length - 1,
                                                 page - 1))
        return EmojiData.categories[categoryIndex]
    }

    FutoEmojiGrid {
        anchors.fill: parent
        targetLayout: panel.targetLayout
        dataRevision: panel.searchRevision
    }

    Loader {
        id: searchProvider
        active: panel.targetLayout && panel.targetLayout.emojiPage < 0
        asynchronous: false
        source: "FutoEmojiSearchProvider.qml"
        onLoaded: panel.searchRevision++
    }
}
