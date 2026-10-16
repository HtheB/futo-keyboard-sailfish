import QtQuick 2.6
import Sailfish.Silica 1.0

ComboBox {
    id: combo
    // Silica rewrites currentIndex while loading/rebuilding its menu, which
    // removes a direct QML binding. Keep the document's selection separate.
    property int selectedIndex: -1
    property bool synchronizing: false
    automaticSelection: false
    onSelectedIndexChanged: selectionSync.restart()
    onCurrentIndexChanged: if (!synchronizing && currentIndex !== selectedIndex) selectionSync.restart()
    Component.onCompleted: selectionSync.restart()
    Timer {
        id: selectionSync
        interval: 0
        onTriggered: {
            if (combo.currentIndex === combo.selectedIndex) return
            // An empty/rebuilding menu may reject an index. Do not feed that
            // rejection back into an unbounded zero-interval retry loop.
            combo.synchronizing = true
            combo.currentIndex = combo.selectedIndex
            combo.synchronizing = false
        }
    }
}
