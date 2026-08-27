/* Authenticated entry point for FUTO's learned words, context and URL history. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import Nemo.DBus 2.0
import Nemo.Configuration 1.0

Page {
    id: page
    allowedOrientations: Orientation.All

    property bool accessGranted: !privacySettings.personalDictionaryProtected
    property bool authenticationBusy
	property bool importBusy
    property string statusText: ""
	property string encryptionStatus: "unknown"

	function refreshEncryptionStatus() {
		helper.typedCall("LearnedEncryptionStatus", [], function(result) {
			page.encryptionStatus = String(result)
			if ((page.encryptionStatus === "locked"
					|| page.encryptionStatus === "not_initialized") && page.accessGranted
					&& !page.authenticationBusy) {
				if (privacySettings.personalDictionaryProtected)
					authenticationTimer.start()
				else
					unprotectedEncryptionTimer.start()
			}
		}, function() {
			page.encryptionStatus = "unavailable"
		})
	}

	function prepareUnprotectedEncryption() {
		if (authenticationBusy || privacySettings.personalDictionaryProtected)
			return
		authenticationBusy = true
		statusText = ""
		helper.typedCall("InitializeLearnedEncryption", [], function(initialized) {
			page.authenticationBusy = false
			if (initialized) {
				page.encryptionStatus = "encrypted"
				page.accessGranted = true
			} else {
				page.statusText = qsTr("Learned data could not be opened")
			}
		}, function() {
			page.authenticationBusy = false
			page.statusText = qsTr("Learned data could not be opened")
			page.refreshEncryptionStatus()
		})
	}

	function chooseLearnedBackup() {
		if (importBusy || encryptionStatus !== "encrypted")
			return
		pageStack.push(learnedBackupPicker, {
			"title": qsTr("Select learned-data backup")
		})
	}

	function importLearnedBackup(filePath) {
		if (importBusy || encryptionStatus !== "encrypted")
			return
		filePath = String(filePath || "")
		if (filePath === "")
			return
		importBusy = true
		statusText = qsTr("Importing learned data…")
		helper.typedCall("ImportUserDataFromFile", [
			{ "type": "s", "value": filePath }
		], function(imported) {
			page.importBusy = false
			page.statusText = imported
					? qsTr("Learned data imported")
					: qsTr("The selected file is not a valid FUTO backup")
		}, function() {
			page.importBusy = false
			page.statusText = qsTr("Could not import the selected backup")
		})
	}

    function unlockLearnedData() {
		helper.typedCall("PrepareLearnedEncryptionFromAuthenticatedSettings", [],
						 function(prepared) {
			page.authenticationBusy = false
			if (prepared) {
				page.encryptionStatus = "encrypted"
				page.accessGranted = true
				page.statusText = qsTr("Learned data unlocked and encrypted")
			}
		}, function() {
			page.authenticationBusy = false
			if (privacySettings.personalDictionaryProtected)
				page.accessGranted = false
			page.statusText = qsTr("Learned data could not be unlocked")
			page.refreshEncryptionStatus()
		})
    }

    function requestAccess() {
        if (authenticationBusy
                || (accessGranted && encryptionStatus !== "locked"
					&& encryptionStatus !== "not_initialized"))
            return
        authenticationBusy = true
        statusText = ""
        if (!deviceAuthentication.requestPermission(
					qsTr("Authenticate to open learned FUTO data"))) {
            page.authenticationBusy = false
            page.statusText = qsTr("Device authentication is unavailable")
		}
    }

    ConfigurationGroup {
        id: privacySettings
        path: "/sailfish/text_input/futo_keyboard"
        property bool personalDictionaryProtected: false
    }

    FutoDeviceAuthentication {
        id: deviceAuthentication
        onAccepted: page.unlockLearnedData()
        onRejected: {
            page.authenticationBusy = false
            page.statusText = qsTr("Authentication canceled")
        }
    }

    DBusInterface {
        id: helper
        bus: DBus.SessionBus
        service: "org.hb.FutoKeyboard1"
        path: "/org/hb/FutoKeyboard1"
        iface: "org.hb.FutoKeyboard1"
        watchServiceStatus: true
    }

	Component.onCompleted: {
		refreshEncryptionStatus()
		if (!accessGranted)
			authenticationTimer.start()
	}

	Timer {
		id: authenticationTimer
		interval: 250
		repeat: false
		onTriggered: page.requestAccess()
	}

	Timer {
		id: unprotectedEncryptionTimer
		interval: 0
		repeat: false
		onTriggered: page.prepareUnprotectedEncryption()
	}

	Component {
		id: learnedBackupPicker

		FilePickerPage {
			nameFilters: [ "*.futo" ]
			onSelectedContentPropertiesChanged: {
				var filePath = selectedContentProperties.filePath
				if (filePath)
					page.importLearnedBackup(filePath)
			}
		}
	}

    FutoSettingsTestPanel {
        id: testPanel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        pageItem: page
    }

    SilicaFlickable {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: testPanel.top
        contentHeight: content.height + Theme.paddingLarge
        clip: true
        VerticalScrollDecorator { flickable: parent }

        Column {
            id: content
            width: parent.width

            PageHeader { title: qsTr("Manage learned data") }

            Column {
                width: parent.width
				visible: page.accessGranted
				spacing: Theme.paddingSmall

				SectionHeader { text: qsTr("Encryption") }

				Label {
					x: Theme.horizontalPageMargin
					width: parent.width - 2 * x
					wrapMode: Text.Wrap
					color: page.encryptionStatus === "encrypted"
					       ? Theme.highlightColor : Theme.secondaryColor
					font.pixelSize: Theme.fontSizeSmall
					text: page.encryptionStatus === "encrypted"
					      ? qsTr("Words, context, URLs and clipboard history are encrypted at rest.")
					      : (page.encryptionStatus === "locked"
					         ? qsTr("Learned data is encrypted at rest and currently locked.")
					         : qsTr("Encryption is prepared automatically after device authentication."))
				}

                FutoSettingsMenuItem {
                    width: parent.width
                    text: qsTr("Words")
                    iconSource: "image://theme/icon-m-text-input"
                    onClicked: pageStack.push(Qt.resolvedUrl("FutoPersonalWordsPage.qml"), {
                        authorizationInherited: true
                    })
                }

                FutoSettingsMenuItem {
                    width: parent.width
                    text: qsTr("URLs")
                    iconSource: "image://theme/icon-m-link"
                    onClicked: pageStack.push(Qt.resolvedUrl("FutoUrlHistoryPage.qml"), {
                        authorizationInherited: true
                    })
                }

                SectionHeader { text: qsTr("Backup") }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
					enabled: page.encryptionStatus === "encrypted"
                    text: qsTr("Export learned data")
                    onClicked: helper.typedCall("ExportUserData", [], function(path) {
						page.statusText = qsTr("Encrypted backup exported to %1").arg(String(path))
                    }, function() {
                        page.statusText = qsTr("Could not export learned data")
                    })
                }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
					enabled: page.encryptionStatus === "encrypted" && !page.importBusy
                    text: qsTr("Import learned data")
					onClicked: page.chooseLearnedBackup()
                }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Clear all learned data")
                    onClicked: Remorse.popupAction(page, qsTr("Clearing learned data"), function() {
                        helper.typedCall("ClearPersonalDictionary", [], function(cleared) {
                            page.statusText = cleared ? qsTr("Learned data cleared")
                                                      : qsTr("No learned data was cleared")
                        }, function() {
                            page.statusText = qsTr("Could not clear learned data")
                        })
                    })
                }
            }

            Item {
                width: parent.width
				visible: !page.accessGranted
                height: page.accessGranted ? 0 : Math.max(Theme.itemSizeHuge * 2,
                                                           lockedColumn.height)

                Column {
                    id: lockedColumn
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: Theme.paddingLarge

                    BusyIndicator {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: BusyIndicatorSize.Large
                        running: page.authenticationBusy
                        visible: running
                    }

                    Label {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * x
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        color: Theme.secondaryColor
                        text: page.authenticationBusy
                              ? qsTr("Waiting for device authentication…")
                              : (page.statusText !== "" ? page.statusText
                                 : qsTr("Authenticate to manage learned data"))
                    }

                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: page.accessGranted ? page.statusText : ""
                visible: text !== ""
            }
        }
    }
}
