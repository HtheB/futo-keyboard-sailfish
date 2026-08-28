/* Export website and app passwords as an optional AES-256 protected ZIP. */
import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.DBus 2.0

Page {
	id: page
	allowedOrientations: Orientation.All

	property string vaultToken: ""
	property var vaultHelper: null
	property bool busy
	property string statusText: ""

	function startExport() {
		if (busy || vaultToken === "")
			return
		if (passwordField.text !== confirmPasswordField.text) {
			statusText = qsTr("The passwords do not match")
			confirmPasswordField.forceActiveFocus()
			return
		}
		if (passwordField.text === "") {
			pageStack.push(unprotectedWarning)
			return
		}
		performExport(passwordField.text)
	}

	function performExport(exportPassword) {
		if (busy)
			return
		busy = true
		statusText = qsTr("Exporting passwords…")
		helper.typedCall("ExportPasswords", [
			{ "type": "s", "value": vaultToken },
			{ "type": "s", "value": exportPassword }
		], function(resultJson) {
			page.busy = false
			passwordField.text = ""
			confirmPasswordField.text = ""
			var result = { "path": "", "websites": 0, "apps": 0,
				"protected": false, "error": "" }
			try { result = JSON.parse(String(resultJson)) } catch (error) {}
			if (String(result.error || "") !== "") {
				page.statusText = String(result.error)
				return
			}
			page.statusText = qsTr("Exported %1 website and %2 app accounts to:\n%3")
					.arg(Number(result.websites)).arg(Number(result.apps))
					.arg(String(result.path))
		}, function() {
			page.busy = false
			passwordField.text = ""
			confirmPasswordField.text = ""
			page.statusText = qsTr("The vault session expired. Reopen Saved passwords")
		})
	}

	Component {
		id: unprotectedWarning
		Dialog {
			id: warningDialog
			canAccept: true
			onAccepted: page.performExport("")

			SilicaFlickable {
				anchors.fill: parent
				contentHeight: warningContent.height

				Column {
					id: warningContent
					width: parent.width
					spacing: Theme.paddingLarge

					DialogHeader {
						dialog: warningDialog
						acceptText: qsTr("Export unprotected")
						cancelText: qsTr("Cancel")
					}

					Label {
						x: Theme.horizontalPageMargin
						width: parent.width - 2 * x
						wrapMode: Text.Wrap
						color: Theme.highlightColor
						font.pixelSize: Theme.fontSizeLarge
						text: qsTr("Export without a password?")
					}

					Label {
						x: Theme.horizontalPageMargin
						width: parent.width - 2 * x
						wrapMode: Text.Wrap
						color: Theme.secondaryColor
						text: qsTr("Anyone who obtains this ZIP can read every exported username and password. Only continue if you intentionally want an unprotected export.")
					}
				}
			}
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

			PageHeader { title: qsTr("Export passwords") }

			Label {
				x: Theme.horizontalPageMargin
				width: parent.width - 2 * x
				wrapMode: Text.Wrap
				color: Theme.secondaryColor
				text: qsTr("The ZIP can be restored directly in FUTO. It also contains separate CSV files for Chromium-family browsers, Firefox, and FUTO app accounts. The export is saved in Documents/FUTO-Keyboard.")
			}

			Item {
				width: 1
				height: 2 * Theme.paddingLarge
			}

			TextField {
				id: passwordField
				width: parent.width
				label: qsTr("ZIP password")
				placeholderText: qsTr("Choose a password, or deliberately leave empty")
				echoMode: TextInput.Password
				inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
				EnterKey.iconSource: "image://theme/icon-m-enter-next"
				EnterKey.onClicked: confirmPasswordField.forceActiveFocus()
			}

			TextField {
				id: confirmPasswordField
				width: parent.width
				label: qsTr("Confirm ZIP password")
				placeholderText: qsTr("Enter the same password again")
				echoMode: TextInput.Password
				inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
				EnterKey.iconSource: "image://theme/icon-m-enter-accept"
				EnterKey.onClicked: page.startExport()
			}

			Button {
				anchors.horizontalCenter: parent.horizontalCenter
				enabled: !page.busy
				text: qsTr("Export passwords")
				onClicked: page.startExport()
			}

			BusyIndicator {
				anchors.horizontalCenter: parent.horizontalCenter
				running: page.busy
				visible: running
				size: BusyIndicatorSize.Small
			}

			Label {
				x: Theme.horizontalPageMargin
				width: parent.width - 2 * x
				horizontalAlignment: Text.AlignHCenter
				wrapMode: Text.Wrap
				color: Theme.highlightColor
				font.pixelSize: Theme.fontSizeSmall
				text: page.statusText
				visible: text !== ""
			}
		}
	}
}
