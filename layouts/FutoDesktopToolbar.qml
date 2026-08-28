/* User-configurable horizontally scrolling row below the suggestion strip. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import "FutoDesktopKeyData.js" as DesktopKeys

Item {
    id: toolbar

    property Item targetLayout
    property bool followRowHeight: true
    readonly property var orderedKeys: toolbarKeys()

    ConfigurationGroup {
        id: settings
        path: "/sailfish/text_input/futo_keyboard"
        property bool desktopToolbarEnabled: false
        property string desktopToolbarOrder: DesktopKeys.ids().join(",")
        property string desktopToolbarEnabledKeys:
            "esc,ctrl,alt,left,down,right,delete"
        onDesktopToolbarEnabledChanged: resizeTimer.restart()
        onDesktopToolbarOrderChanged: resizeTimer.restart()
        onDesktopToolbarEnabledKeysChanged: resizeTimer.restart()
    }

    Timer {
        id: resizeTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (toolbar.targetLayout && toolbar.targetLayout.updateSizes)
                toolbar.targetLayout.updateSizes()
        }
    }

    function toolbarKeys() {
        var order = DesktopKeys.completeOrder(settings.desktopToolbarOrder)
        var enabled = DesktopKeys.splitUnique(settings.desktopToolbarEnabledKeys)
        var result = []
        for (var i = 0; i < order.length; ++i) {
            if (enabled.indexOf(order[i]) >= 0)
                result.push(order[i])
        }
        return result
    }

    function sideKeys(rightSide) {
        var splitAt = Math.ceil(orderedKeys.length / 2)
        return rightSide ? orderedKeys.slice(splitAt) : orderedKeys.slice(0, splitAt)
    }

    visible: settings.desktopToolbarEnabled && orderedKeys.length > 0
             && targetLayout && !targetLayout.extraKeysMode
             && !targetLayout.emojiMode && !targetLayout.emojiSearchMode
             && !targetLayout.extendedSymbolMode
             && !targetLayout.layoutEditorMode && !targetLayout.clipboardMode
             && !targetLayout.credentialMode && !targetLayout.cursorMoveMode
    height: visible && targetLayout ? targetLayout.keyHeight : 0

    Row {
        anchors.fill: parent
        visible: toolbar.visible && toolbar.targetLayout
                 && toolbar.targetLayout.splitActive

        FutoDesktopToolbarSide {
            width: (parent.width - toolbar.targetLayout.avoidanceWidth) / 2
            height: parent.height
            targetLayout: toolbar.targetLayout
            keyIds: toolbar.sideKeys(false)
        }

        Item {
            width: toolbar.targetLayout.avoidanceWidth
            height: parent.height
        }

        FutoDesktopToolbarSide {
            width: (parent.width - toolbar.targetLayout.avoidanceWidth) / 2
            height: parent.height
            targetLayout: toolbar.targetLayout
            keyIds: toolbar.sideKeys(true)
        }
    }

    FutoDesktopToolbarSide {
        anchors.fill: parent
        visible: toolbar.visible && toolbar.targetLayout
                 && !toolbar.targetLayout.splitActive
        targetLayout: toolbar.targetLayout
        keyIds: toolbar.orderedKeys
    }
}
