/* Manage encrypted saved logins, separated into website and app tabs. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.DBus 2.0

Page {
    id: page
    allowedOrientations: Orientation.All

    property string vaultToken: ""
    property var vaultHelper: null
    property int selectedTab: 0
    property string statusText: ""
    property string searchQuery: ""
    property bool busy
    property var secretMatchIds: ({})
    property int searchSerial
    property string rawEntriesJson: ""
    property string rawSearchJson: ""
    property string rawAppNameUpdateJson: ""
    property var allEntries: []
    property var visibleEntries: []
    readonly property int visibleCount: visibleEntries.length

    onSelectedTabChanged: rebuildModels()

    // Nemo.DBus invokes callbacks in a JavaScript scope where ListModel ids are
    // unreliable on the Qt version shipped by Sailfish OS.  Keep the data as
    // plain page-owned arrays so callback results never mutate a ListModel.
    onRawEntriesJsonChanged: {
        if (rawEntriesJson === "")
            return
        var entries = []
        try { entries = JSON.parse(rawEntriesJson) } catch (error) {}
        var loadedEntries = []
        for (var i = 0; i < entries.length; ++i) {
            var entry = entries[i]
            loadedEntries.push({
                "entryId": String(entry.id),
                "entryLabel": String(entry.label),
                "entryOrigin": String(entry.origin || ""),
                "entryUsername": String(entry.username || ""),
                "entryAppName": ""
            })
        }
        allEntries = loadedEntries
        rebuildModels()
        for (var j = 0; j < allEntries.length; ++j) {
            var loadedEntry = allEntries[j]
            if (String(loadedEntry.entryOrigin).toLocaleLowerCase()
                    .indexOf("app://") === 0)
                resolveAppName(String(loadedEntry.entryId),
                               String(loadedEntry.entryOrigin))
        }
    }

    onRawSearchJsonChanged: {
        if (rawSearchJson === "")
            return
        var response = null
        try { response = JSON.parse(rawSearchJson) } catch (error) {}
        if (!response || Number(response.serial) !== searchSerial)
            return
        var entries = []
        try { entries = JSON.parse(String(response.result)) } catch (error2) {}
        var matches = {}
        for (var i = 0; i < entries.length; ++i)
            matches[String(entries[i].id)] = true
        secretMatchIds = matches
        rebuildModels()
    }

    onRawAppNameUpdateJsonChanged: {
        if (rawAppNameUpdateJson === "")
            return
        var update = null
        try { update = JSON.parse(rawAppNameUpdateJson) } catch (error) {}
        if (!update)
            return
        var updatedEntries = []
        for (var i = 0; i < allEntries.length; ++i) {
            var oldEntry = allEntries[i]
            updatedEntries.push({
                "entryId": String(oldEntry.entryId),
                "entryLabel": String(oldEntry.entryLabel),
                "entryOrigin": String(oldEntry.entryOrigin),
                "entryUsername": String(oldEntry.entryUsername),
                "entryAppName": String(oldEntry.entryId) === String(update.entryId)
                                ? String(update.appName)
                                : String(oldEntry.entryAppName)
            })
        }
        allEntries = updatedEntries
        rebuildModels()
    }

    function refreshEntries() {
        if (vaultToken === "") {
            statusText = qsTr("The vault session expired. Reopen Saved passwords")
            return
        }
        busy = true
        helper.typedCall("ListCredentials", [
            { "type": "s", "value": vaultToken }
        ], function(resultJson) {
            page.busy = false
            page.rawEntriesJson = String(resultJson)
        }, function() {
            page.busy = false
            page.statusText = qsTr("The vault session expired. Reopen Saved passwords")
        })
    }

	function rebuildModels() {
		var query = String(searchQuery || "").trim().toLocaleLowerCase()
		var results = []
		for (var i = 0; i < allEntries.length; ++i) {
			var entry = allEntries[i]
			var appEntry = String(entry.entryOrigin).toLocaleLowerCase()
			        .indexOf("app://") === 0
			if ((selectedTab === 1) !== appEntry)
				continue
			var searchable = (String(entry.entryLabel) + "\n"
			        + String(entry.entryOrigin) + "\n"
			        + String(entry.entryUsername) + "\n"
			        + String(entry.entryAppName)).toLocaleLowerCase()
			if (query !== "" && !secretMatchIds[String(entry.entryId)]
					&& searchable.indexOf(query) < 0)
				continue
		results.push({
			"entryId": String(entry.entryId),
			"entryLabel": String(entry.entryLabel),
			"entryOrigin": String(entry.entryOrigin),
			"entryUsername": String(entry.entryUsername),
			"entryAppName": String(entry.entryAppName)
		})
		}
		visibleEntries = results
	}

	function searchEntries() {
		var query = String(searchQuery || "").trim()
		var serial = ++searchSerial
		if (query === "") {
			secretMatchIds = ({})
			rebuildModels()
			return
		}
		helper.typedCall("SearchCredentials", [
			{ "type": "s", "value": vaultToken },
			{ "type": "s", "value": query }
        ], function(resultJson) {
            if (serial !== page.searchSerial)
                return
            page.rawSearchJson = JSON.stringify({
                "serial": serial,
                "result": String(resultJson)
            })
		}, function() {
			if (serial === page.searchSerial)
				page.statusText = qsTr("Search failed. Reopen Saved passwords")
		})
	}

	function resolveAppName(entryId, origin) {
		var packageId = String(origin || "").replace(/^app:\/\//i, "").split(/[\/?#]/)[0]
		if (packageId === "")
			return
		androidApplicationTracker.typedCall("queryIntent", [
			{ "type": "s", "value": "android.intent.action.MAIN" },
			{ "type": "s", "value": "" },
			{ "type": "s", "value": "" },
			{ "type": "s", "value": packageId },
			{ "type": "s", "value": "" },
			{ "type": "s", "value": "" },
			{ "type": "a{sv}", "value": {} }
		], function(apps) {
			var appName = ""
			if (apps && apps.length > 0 && apps[0] && apps[0].length > 2)
				appName = String(apps[0][2] || "").trim()
            if (appName === "")
                return
            page.rawAppNameUpdateJson = JSON.stringify({
                "entryId": String(entryId),
                "appName": appName
            })
		}, function() {})
	}

    function openCredential(entryId, entryLabel, entryOrigin, entryUsername) {
        var detailPage = pageStack.push(Qt.resolvedUrl("FutoCredentialPage.qml"), {
            "vaultToken": vaultToken,
            "vaultHelper": vaultHelper,
            "entryId": entryId,
            "entryLabel": entryLabel,
            "entryOrigin": entryOrigin,
            "entryUsername": entryUsername
        })
        if (detailPage)
            detailPage.credentialChanged.connect(page.refreshEntries)
    }

    function deleteCredentialWithRemorse(item, credentialId) {
        // Remorse runs its callback several seconds later.  Preserve primitive
        // values now instead of resolving delegate roles after that delay.
        var deleteId = String(credentialId)
        var deleteToken = String(vaultToken)
        statusText = ""
        Remorse.itemAction(item, qsTr("Deleting login"), function() {
            helper.typedCall("DeleteCredential", [
                { "type": "s", "value": deleteToken },
                { "type": "s", "value": deleteId }
            ], function(deleted) {
                if (deleted) {
                    page.statusText = ""
                    page.refreshEntries()
                } else {
                    page.statusText = qsTr("The login was already removed")
                    page.refreshEntries()
                }
            }, function() {
                page.statusText = qsTr("Could not delete the login. Reopen Saved passwords")
            })
        })
    }

    Component.onCompleted: refreshEntries()

    DBusInterface {
        id: helper
        bus: DBus.SessionBus
        service: "org.hb.FutoKeyboard1"
        path: "/org/hb/FutoKeyboard1"
        iface: "org.hb.FutoKeyboard1"
        watchServiceStatus: true
    }

	DBusInterface {
		id: androidApplicationTracker
		bus: DBus.SessionBus
		service: "com.jolla.apkd"
		path: "/com/jolla/apkd"
		iface: "com.jolla.apkd"
		watchServiceStatus: true
	}

	Timer {
		id: searchTimer
		interval: 180
		repeat: false
		onTriggered: page.searchEntries()
	}

    FutoSettingsTestPanel {
        id: testPanel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        pageItem: page
    }

    SilicaListView {
        id: credentialList
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: testPanel.top
        clip: true
        model: page.visibleEntries
        VerticalScrollDecorator { flickable: credentialList }

        header: Column {
            width: credentialList.width

            PageHeader { title: qsTr("Manage passwords") }

            SearchField {
                id: searchField
                width: parent.width
                placeholderText: qsTr("Search saved logins")
                EnterKey.enabled: text.length > 0
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: {
                    searchTimer.stop()
                    page.searchEntries()
                    focus = false
                }
                onTextChanged: {
                    page.searchQuery = text
                    page.statusText = ""
                    searchTimer.restart()
                }
            }

            Item {
                width: parent.width
                height: Theme.itemSizeSmall

                Row {
                    anchors.fill: parent

                    Repeater {
                        model: [ qsTr("Websites"), qsTr("Apps") ]

                        BackgroundItem {
                            width: credentialList.width / 2
                            height: Theme.itemSizeSmall
                            onClicked: page.selectedTab = index

                            Rectangle {
                                anchors.fill: parent
                                color: page.selectedTab === index
                                       ? Theme.rgba(Theme.highlightColor, 0.14)
                                       : "transparent"
                            }

                            Label {
                                anchors.centerIn: parent
                                text: modelData
                                color: page.selectedTab === index
                                       ? Theme.highlightColor : Theme.primaryColor
                                font.bold: page.selectedTab === index
                            }
                        }
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: text !== "" ? implicitHeight + 2 * Theme.paddingMedium : 0
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: page.statusText
                visible: text !== ""
            }
        }

        delegate: BackgroundItem {
            id: credentialItem
            property var credential: modelData
            property string entryId: credential ? String(credential.entryId) : ""
            property string entryLabel: credential ? String(credential.entryLabel) : ""
            property string entryOrigin: credential ? String(credential.entryOrigin) : ""
            property string entryUsername: credential ? String(credential.entryUsername) : ""
            property string entryAppName: credential ? String(credential.entryAppName) : ""
            width: credentialList.width
            height: Theme.itemSizeLarge
            onClicked: page.openCredential(entryId, entryLabel,
                                            entryOrigin, entryUsername)

            Column {
                anchors.left: parent.left
                anchors.leftMargin: Theme.horizontalPageMargin
                anchors.right: deleteButton.left
                anchors.rightMargin: Theme.paddingMedium
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    width: parent.width
                    text: entryAppName !== "" ? entryAppName : entryLabel
                    truncationMode: TruncationMode.Fade
                }

                Label {
                    width: parent.width
                    text: entryUsername + (entryOrigin !== ""
                          ? (entryUsername !== "" ? " · " : "") + entryOrigin : "")
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    truncationMode: TruncationMode.Fade
                }
            }

            IconButton {
                id: deleteButton
                anchors.right: parent.right
                anchors.rightMargin: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                icon.source: "image://theme/icon-m-delete"
                onClicked: page.deleteCredentialWithRemorse(credentialItem,
                                                            credentialItem.entryId)
            }
        }

        ViewPlaceholder {
            enabled: !page.busy && page.visibleCount === 0
            text: page.searchQuery.trim() !== ""
                  ? qsTr("No matching saved logins")
                  : (page.selectedTab === 0
                     ? qsTr("No saved website logins")
                     : qsTr("No saved app logins"))
        }

        BusyIndicator {
            anchors.centerIn: parent
            running: page.busy
            visible: running
            size: BusyIndicatorSize.Medium
        }
    }
}
