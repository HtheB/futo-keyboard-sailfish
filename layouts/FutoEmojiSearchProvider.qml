import QtQuick 2.0
import "FutoEmojiSearchData.js" as EmojiSearchData

Item {
    visible: false
    function matchingCodes(query, languages) {
        return EmojiSearchData.search(query, languages)
    }
}
