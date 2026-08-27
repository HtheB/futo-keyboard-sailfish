/* Download/remove controls for one optional-content category. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.DBus 2.0

Page {
    id: page
    allowedOrientations: Orientation.All

    property string packKind: "dictionary"
    property string pageTitle: qsTr("Content packs")
    property string requestedPackId: ""
    property string statusText: ""
    property bool refreshPending: false

    function formatBytes(value) {
        value = Math.max(0, Number(value))
        if (value >= 1000000)
            return (Math.round(value / 100000) / 10) + " MB"
        if (value >= 1000)
            return Math.round(value / 1000) + " kB"
        return Math.round(value) + " B"
    }

    function categoryDescription() {
        if (packKind === "emoji")
            return qsTr("Install the emoji artwork styles you want to use.")
        if (packKind === "voice")
            return qsTr("Install the model for private offline voice typing.")
        return qsTr("Install dictionaries only for the languages you use.")
    }

    function emojiPreviewStyle(packId) {
        return packId === "emoji-openmoji" ? "openmoji"
             : packId === "emoji-noto" ? "noto" : "twemoji"
    }

    function emojiPreviewSource(packId, codepoint) {
        var style = emojiPreviewStyle(packId)
        var extension = style === "noto" ? ".png" : ".svg"
        return "file:///usr/share/futo-keyboard-sailfish/content-previews/emoji/"
                + style + "/" + codepoint + extension
    }

    function contentSortName(item) {
        // Sort Čeština as Cestina instead of placing Č after the unaccented
        // Latin alphabet. Keep the localized display name untouched.
        if (String(item.id) === "dictionary-cs")
            return "cestina"
        return String(item.name).toLowerCase()
    }

    function refresh() {
        if (helper.status !== DBusInterface.Available || refreshPending)
            return
        refreshPending = true
        helper.typedCall("ContentStatus", [], function(resultJson) {
            page.refreshPending = false
            var result
            try {
                result = JSON.parse(String(resultJson))
            } catch (error) {
                page.statusText = qsTr("Could not read downloadable content")
                return
            }

            var sourceItems = result.items || []
            var items = []
            for (var sourceIndex = 0; sourceIndex < sourceItems.length; ++sourceIndex) {
                if (String(sourceItems[sourceIndex].kind) === page.packKind)
                    items.push(sourceItems[sourceIndex])
            }
            items.sort(function(left, right) {
                var installedDifference = Number(!!right.installed) - Number(!!left.installed)
                if (installedDifference !== 0)
                    return installedDifference
                var leftName = page.contentSortName(left)
                var rightName = page.contentSortName(right)
                return leftName < rightName ? -1 : leftName > rightName ? 1 : 0
            })

            var rebuild = contentModel.count !== items.length
            if (!rebuild) {
                for (var currentIndex = 0; currentIndex < items.length; ++currentIndex) {
                    if (contentModel.get(currentIndex).packId !== String(items[currentIndex].id)) {
                        rebuild = true
                        break
                    }
                }
            }
            if (rebuild)
                contentModel.clear()

            for (var i = 0; i < items.length; ++i) {
                var item = items[i]
                var values = {
                    "packId": String(item.id),
                    "packName": String(item.name),
                    "archiveName": String(item.archive),
                    "downloadBytes": Number(item.downloadBytes),
                    "installedBytes": Number(item.installedBytes),
                    "installed": !!item.installed,
                    "available": !!item.available,
                    "packState": String(item.state || "idle"),
                    "doneBytes": Number(item.doneBytes || 0),
                    "totalBytes": Number(item.totalBytes || item.downloadBytes || 0),
                    "message": String(item.message || ""),
                    "sectionName": item.installed ? qsTr("Installed") : qsTr("Not installed")
                }
                if (rebuild) {
                    contentModel.append(values)
                } else {
                    for (var role in values)
                        contentModel.setProperty(i, role, values[role])
                }
            }
        }, function() {
            page.refreshPending = false
            page.statusText = qsTr("The FUTO helper is not responding")
        })
    }

    function startInstall(packId) {
        helper.typedCall("InstallContent", [
            { "type": "s", "value": String(packId) }
        ], function(started) {
            if (!started)
                page.statusText = qsTr("That content pack is already busy")
            page.refresh()
        }, function() {
            page.statusText = qsTr("Could not start the download")
            page.refresh()
        })
    }

    function cancelInstall(packId) {
        helper.typedCall("CancelContentInstall", [
            { "type": "s", "value": String(packId) }
        ], function(cancelled) {
            page.statusText = cancelled ? qsTr("Cancelling download") : ""
            page.refresh()
        }, function() {
            page.statusText = qsTr("Could not cancel the download")
        })
    }

    function removePack(packId, packName) {
        Remorse.popupAction(page, qsTr("Removing %1").arg(packName), function() {
            helper.typedCall("RemoveContent", [
                { "type": "s", "value": String(packId) }
            ], function(removed) {
                page.statusText = removed ? qsTr("Content removed")
                                          : qsTr("Content was already absent")
                page.refresh()
            }, function() {
                page.statusText = qsTr("Could not remove the content")
                page.refresh()
            })
        })
    }

    ListModel { id: contentModel }

    DBusInterface {
        id: helper
        bus: DBus.SessionBus
        service: "org.hb.FutoKeyboard1"
        path: "/org/hb/FutoKeyboard1"
        iface: "org.hb.FutoKeyboard1"
        signalsEnabled: true
        watchServiceStatus: true

        function contentChanged(packId, state) {
            page.refresh()
        }

        onStatusChanged: {
            if (status === DBusInterface.Available)
                page.refresh()
        }
    }

    Timer {
        interval: 1200
        repeat: true
        running: page.status === PageStatus.Active
                 && helper.status === DBusInterface.Available
        onTriggered: page.refresh()
    }

    Component.onCompleted: refresh()

    FutoSettingsTestPanel {
        id: testPanel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        pageItem: page
    }

    SilicaListView {
        id: contentList
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: testPanel.top
        clip: true
        model: contentModel
        section.property: "sectionName"
        section.criteria: ViewSection.FullString
        section.delegate: SectionHeader { text: section }

        header: Column {
            width: contentList.width

            PageHeader { title: page.pageTitle }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: page.categoryDescription()
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.statusText !== ""
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: page.statusText
            }
        }

        delegate: BackgroundItem {
            id: packRow
            width: contentList.width
            readonly property real verticalPadding: page.packKind === "emoji"
                    ? Theme.paddingLarge : Theme.paddingSmall
            height: Math.max(Theme.itemSizeLarge,
                             detailsColumn.height + 2 * verticalPadding)
            enabled: installed || available || packState === "downloading"
                     || packState === "installing"

            readonly property bool busy: packState === "downloading"
                                         || packState === "installing"
            readonly property int progressPercent: totalBytes > 0
                    ? Math.max(0, Math.min(100, Math.round(doneBytes * 100 / totalBytes))) : 0

            Column {
                id: detailsColumn
                spacing: page.packKind === "emoji" ? Theme.paddingSmall : 0
                anchors.left: parent.left
                anchors.leftMargin: Theme.horizontalPageMargin
                anchors.right: actionLabel.left
                anchors.rightMargin: Theme.paddingMedium
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    text: packName
                    color: packRow.highlighted || packId === page.requestedPackId
                           ? Theme.highlightColor : Theme.primaryColor
                }

                Row {
                    visible: page.packKind === "emoji"
                    height: visible ? Theme.iconSizeMedium : 0
                    spacing: Theme.paddingMedium

                    Image {
                        width: Theme.iconSizeMedium
                        height: width
                        fillMode: Image.PreserveAspectFit
                        source: page.emojiPreviewSource(packId, "1f600")
                    }
                    Image {
                        width: Theme.iconSizeMedium
                        height: width
                        fillMode: Image.PreserveAspectFit
                        source: page.emojiPreviewSource(packId, "1f44d")
                    }
                    Image {
                        width: Theme.iconSizeMedium
                        height: width
                        fillMode: Image.PreserveAspectFit
                        source: page.emojiPreviewSource(packId, "1f389")
                    }
                    Image {
                        width: Theme.iconSizeMedium
                        height: width
                        fillMode: Image.PreserveAspectFit
                        source: page.emojiPreviewSource(packId, "2764")
                    }
                }

                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    text: packState === "downloading"
                          ? qsTr("Downloading %1% · %2").arg(packRow.progressPercent)
                                .arg(page.formatBytes(downloadBytes))
                          : packState === "installing" ? qsTr("Installing…")
                          : packState === "failed" ? message
                          : installed ? qsTr("Installed · %1").arg(page.formatBytes(installedBytes))
                          : available ? qsTr("%1 download · %2 installed")
                                .arg(page.formatBytes(downloadBytes))
                                .arg(page.formatBytes(installedBytes))
                          : qsTr("Download source not configured")
                }
            }

            Label {
                id: actionLabel
                anchors.right: parent.right
                anchors.rightMargin: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                color: packRow.highlighted ? Theme.highlightColor : Theme.primaryColor
                text: packRow.busy ? qsTr("Cancel")
                      : installed ? qsTr("Remove")
                      : packState === "failed" ? qsTr("Retry")
                      : available ? qsTr("Download") : qsTr("Unavailable")
            }

            onClicked: {
                page.statusText = ""
                if (packRow.busy)
                    page.cancelInstall(packId)
                else if (installed)
                    page.removePack(packId, packName)
                else
                    page.startInstall(packId)
            }
        }

        VerticalScrollDecorator {}

        ViewPlaceholder {
            enabled: contentModel.count === 0
            text: qsTr("No content catalog available")
            hintText: qsTr("Restart the FUTO helper and try again")
        }
    }
}
