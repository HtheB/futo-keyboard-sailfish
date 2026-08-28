/* One independently scrolling half of the desktop-key toolbar. */
import QtQuick 2.0
import Sailfish.Silica 1.0

SilicaFlickable {
    id: side

    property Item targetLayout
    property var keyIds: []
    readonly property real buttonWidth: Math.max(Theme.itemSizeMedium,
                                                  height * 1.28)
    clip: true
    flickableDirection: Flickable.HorizontalFlick
    boundsBehavior: Flickable.StopAtBounds
    pressDelay: 140
    contentWidth: keyRow.width
    contentHeight: height
    interactive: contentWidth > width

    Row {
        id: keyRow
        width: side.buttonWidth * side.keyIds.length
        height: side.height

        Repeater {
            model: side.keyIds

            FutoDesktopKey {
                width: side.buttonWidth
                height: side.height
                targetLayout: side.targetLayout
                keyId: String(modelData)
                compact: true
            }
        }
    }

    // Viewport-anchored edge veils. They move with contentX in content
    // coordinates, which keeps them fixed at the visible edges of Flickable.
    Item {
        id: leftOverflowFade
        x: side.contentX
        y: 0
        width: Math.min(Theme.paddingLarge * 1.6, side.width / 7)
        height: side.height
        z: 100
        clip: true
        visible: side.contentWidth > side.width + 1 && side.contentX > 1

        Rectangle {
            anchors.centerIn: parent
            width: parent.height
            height: parent.width
            rotation: -90
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.rgba(Theme.primaryColor, 0.16)
                }
                GradientStop {
                    position: 1
                    color: Theme.rgba(Theme.primaryColor, 0.0)
                }
            }
        }
    }

    Item {
        id: rightOverflowFade
        x: side.contentX + side.width - width
        y: 0
        width: Math.min(Theme.paddingLarge * 1.6, side.width / 7)
        height: side.height
        z: 100
        clip: true
        visible: side.contentWidth > side.width + 1
                 && side.contentX < side.contentWidth - side.width - 1

        Rectangle {
            anchors.centerIn: parent
            width: parent.height
            height: parent.width
            rotation: -90
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.rgba(Theme.primaryColor, 0.0)
                }
                GradientStop {
                    position: 1
                    color: Theme.rgba(Theme.primaryColor, 0.16)
                }
            }
        }
    }
}
