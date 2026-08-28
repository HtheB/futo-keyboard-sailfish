PREFIX ?= /usr
DESTDIR ?=
ARCH ?= aarch64
BUILD_DIR ?= build/$(ARCH)
LIBDIR ?= $(PREFIX)/lib64

ENGINE_BINARY ?= $(BUILD_DIR)/futo-keyboard-engine
HELPER_BINARY ?= $(BUILD_DIR)/futo-keyboard-helper
SECRETS_BINARY ?= $(BUILD_DIR)/futo-keyboard-secrets
KEYRING_BINARY ?= $(BUILD_DIR)/futo-keyboard-keyring
FOCUS_BINARY ?= $(BUILD_DIR)/futo-keyboard-focus
VOICE_BINARY ?= $(BUILD_DIR)/futo-keyboard-voice
POLICY_LIBRARY ?= $(BUILD_DIR)/libfuto-maliit-policy.so.1
COMPOSE_PLUGIN ?= $(BUILD_DIR)/libcomposeplatforminputcontextplugin.so
COMPOSE_WRAPPER ?= $(BUILD_DIR)/libafutomaliitcomposewrapper.so
WAYLAND_DEADKEY_HOOK ?= $(BUILD_DIR)/libQt5WaylandClient.so.5.6.3
WAYLAND_DEADKEY_ORIGINAL ?= $(BUILD_DIR)/libQt5WaylandClientFutoOriginal.so.5.6.3
WAYLAND_STOCK_SHA256 ?= $(BUILD_DIR)/stock-wayland.sha256
COMPOSE_ROOT := hardware/compose
VOICE_MODEL ?= voice/models/tiny_acft_q8_0.bin
DICTIONARY_BUILD_DIR ?= build/dictionaries
MALIIT_ROOT := $(DESTDIR)$(PREFIX)/share/maliit/plugins/com/jolla
PACKAGE_ROOT := $(DESTDIR)$(PREFIX)/share/futo-keyboard-sailfish

HANDLER_FILES := \
	qml/FutoInputHandler.qml \
	qml/FutoHorizontalPredictionListView.qml \
	qml/FutoVerticalPredictionListView.qml

LAYOUT_FILES := \
	layouts/FutoCharacterKey.qml \
	layouts/FutoBackspaceKey.qml \
	layouts/FutoCommaKey.qml \
	layouts/FutoEmojiBackKey.qml \
	layouts/FutoEmojiGrid.qml \
	layouts/FutoEmojiKey.qml \
	layouts/FutoEmojiData.js \
	layouts/FutoExtendedSymbolGrid.qml \
	layouts/FutoExtendedSymbolKey.qml \
	layouts/FutoExtendedSymbolsKey.qml \
	layouts/FutoSymbolData.js \
	layouts/FutoLanguageData.js \
	layouts/FutoLetterLayouts.js \
	layouts/FutoLayoutEditor.qml \
	layouts/FutoClipboardPanel.qml \
	layouts/FutoCredentialPanel.qml \
	layouts/FutoEnterKey.qml \
	layouts/FutoKeyboardLayout.qml \
	layouts/FutoNumpadLayout.qml \
	layouts/FutoNumpadRow.qml \
	layouts/FutoQwertyLayout.qml \
	layouts/FutoShiftKey.qml \
	layouts/FutoSpacebarKey.qml \
	layouts/FutoSpacebarRow.qml \
	layouts/FutoSymbolKey.qml \
	layouts/FutoVoiceKey.qml \
	layouts/futo.qml \
	layouts/layouts_futo.conf

SETTINGS_QML := \
	FutoSettingsPage.qml \
	FutoLanguagesPage.qml \
	FutoTypingPage.qml \
	FutoPrivacyPage.qml \
	FutoAppearancePage.qml \
	FutoGesturesPage.qml \
	FutoVoicePage.qml \
	FutoContentPage.qml \
	FutoContentListPage.qml \
	FutoContentRequiredDialog.qml \
	FutoQuickSettingsPage.qml \
	FutoEmojiSettingsPage.qml \
	FutoClipboardSettingsPage.qml \
	FutoFeedbackPage.qml \
	FutoMaintenancePage.qml \
	FutoDeviceAuthentication.qml \
	FutoDeviceLockInputPage.qml \
	FutoSettingsTestPanel.qml \
	FutoSettingsMenuItem.qml \
	FutoLearnedDataPage.qml \
	FutoPersonalWordsPage.qml \
	FutoUrlHistoryPage.qml \
	FutoPasswordVaultPage.qml \
	FutoPasswordAddPage.qml \
	FutoPasswordManagePage.qml \
	FutoPasswordImportPage.qml \
	FutoPasswordExportPage.qml \
	FutoCredentialPage.qml \
	FutoAboutPage.qml \
	FutoCredit.qml \
	FutoMemorial.qml \
	FutoTextInputSettings.qml

DICTIONARY_FILES := \
	en_US.fksidx en_GB.fksidx nl.fksidx tr.fksidx de.fksidx fr.fksidx \
	es.fksidx it.fksidx pt_BR.fksidx pt_PT.fksidx sv.fksidx nb.fksidx \
	da.fksidx fi.fksidx pl.fksidx cs.fksidx ro.fksidx sl.fksidx \
	hr.fksidx lv.fksidx lt.fksidx

EMOJI_STYLES := twemoji openmoji noto
EMOJI_EXPECTED_FILES := 3944
EMOJI_PREVIEW_CODEPOINTS := 1f600 1f44d 1f389 2764
EMOJI_TAB_CODEPOINTS := 1f550 1f600 1f44b 1f43b 1f354 1f697 26bd 1f4a1 2764 1f3f3
SOUND_FILES := $(wildcard assets/sounds/*.wav)
SOUND_EXPECTED_FILES := 30
ICON_FILES := assets/icons/icon-m-emoji.svg
FONT_FILES := assets/fonts/Amiri-Regular.ttf

.PHONY: check install

check:
	@test -s "$(ENGINE_BINARY)" || { echo "Missing $(ARCH) engine" >&2; exit 1; }
	@test -s "$(HELPER_BINARY)" || { echo "Missing $(ARCH) helper" >&2; exit 1; }
	@test -s "$(SECRETS_BINARY)" || { echo "Missing $(ARCH) Secrets bridge" >&2; exit 1; }
	@test -s "$(KEYRING_BINARY)" || { echo "Missing $(ARCH) device key store" >&2; exit 1; }
	@test -s "$(FOCUS_BINARY)" || { echo "Missing restricted focus bridge" >&2; exit 1; }
	@test -s "$(VOICE_BINARY)" || { echo "Missing $(ARCH) voice worker" >&2; exit 1; }
	@for file in $(HANDLER_FILES); do test -s "$$file" || exit 1; done
	@for file in $(SETTINGS_QML); do test -s "qml/$$file" || exit 1; done
	@test -s content/manifest.json || exit 1
	@grep -q '"formatVersion": 1' content/manifest.json || exit 1
	@test -s packaging/polkit/49-futo-keyboard-secrets.rules || exit 1
	@test -s packaging/polkit/org.hb.futo.keyboard.policy || exit 1
	@test -s "$(POLICY_LIBRARY)" || exit 1
	@test -s "$(COMPOSE_PLUGIN)" || { echo "Missing $(ARCH) Qt Compose plugin" >&2; exit 1; }
	@test -s "$(COMPOSE_WRAPPER)" || { echo "Missing $(ARCH) Maliit Compose wrapper" >&2; exit 1; }
	@test -s "$(WAYLAND_DEADKEY_HOOK)" || { echo "Missing QtWayland dead-key hook" >&2; exit 1; }
	@test -s "$(WAYLAND_DEADKEY_ORIGINAL)" || { echo "Missing renamed stock QtWayland client" >&2; exit 1; }
	@test -s "$(WAYLAND_STOCK_SHA256)" || { echo "Missing QtWayland stock checksum" >&2; exit 1; }
	@readelf -d "$(WAYLAND_DEADKEY_HOOK)" | \
		grep -q 'Shared library: \[libQt5WaylandClientFutoOriginal.so.5\]' || \
		{ echo "QtWayland hook does not depend on the renamed stock client" >&2; exit 1; }
	@readelf -d "$(WAYLAND_DEADKEY_ORIGINAL)" | \
		grep -q 'Library soname: \[libQt5WaylandClientFutoOriginal.so.5\]' || \
		{ echo "Renamed stock QtWayland client has the wrong SONAME" >&2; exit 1; }
	@test -s packaging/scripts/install-wayland-deadkey-hook.sh || exit 1
	@test -s packaging/scripts/remove-wayland-deadkey-hook.sh || exit 1
	@test -s packaging/scripts/install-textinput-bottom-hook.sh || exit 1
	@test -s packaging/scripts/remove-textinput-bottom-hook.sh || exit 1
	@test -s packaging/patches/textinput-bottom-settings.patch || exit 1
	@grep -q 'FutoTextInputSettings.qml' packaging/patches/textinput-bottom-settings.patch || exit 1
	@! grep -q '^settings=' layouts/layouts_futo.conf || exit 1
	@test -s packaging/systemd/maliit-server.service.d/10-futo-hardware-policy.conf || exit 1
	@test -s $(COMPOSE_ROOT)/en_US.UTF-8/Compose || exit 1
	@test -s $(COMPOSE_ROOT)/compose.dir || exit 1
	@test -s $(COMPOSE_ROOT)/locale.alias || exit 1
	@grep -q '^<dead_acute> <space>.*apostrophe' \
		$(COMPOSE_ROOT)/en_US.UTF-8/Compose || exit 1
	@grep -q '^<dead_acute> <e>.*eacute' \
		$(COMPOSE_ROOT)/en_US.UTF-8/Compose || exit 1
	@grep -q 'org.sailfishos.secrets.authentication' \
		packaging/polkit/49-futo-keyboard-secrets.rules || exit 1
	@grep -q 'org.hb.futo.keyboard.saved-login' \
		packaging/polkit/org.hb.futo.keyboard.policy || exit 1
	@grep -q 'org.hb.futo.keyboard.save-login' \
		packaging/polkit/org.hb.futo.keyboard.policy || exit 1
	@for file in $(LAYOUT_FILES); do test -s "$$file" || exit 1; done
	@test -s emoji/manifest.json || exit 1
	@grep -q '"unicodeVersion": "17.0"' emoji/manifest.json || exit 1
	@grep -q '"fullyQualifiedSequences": 3944' emoji/manifest.json || exit 1
	@for style in twemoji openmoji; do \
		for codepoint in $(EMOJI_PREVIEW_CODEPOINTS); do \
			test -s "emoji/$$style/$$codepoint.svg" || exit 1; \
		done; \
	done
	@for codepoint in $(EMOJI_PREVIEW_CODEPOINTS); do \
		test -s "emoji/noto/$$codepoint.png" || exit 1; \
	done
	@for codepoint in $(EMOJI_TAB_CODEPOINTS); do \
		test -s "emoji/noto/$$codepoint.png" || exit 1; \
	done
	@test -s LICENSES/EMOJI-ATTRIBUTION.md || exit 1
	@test -s LICENSES/TWEMOJI-GRAPHICS-LICENSE.txt || exit 1
	@test -s LICENSES/OPENMOJI-LICENSE.txt || exit 1
	@test -s LICENSES/NOTO-EMOJI-SVG-LICENSE.txt || exit 1
	@test -s LICENSES/UNICODE-LICENSE.txt || exit 1
	@test -s LICENSES/FUTO-LAYOUTS-ATTRIBUTION.md || exit 1
	@test -s LICENSES/LIBX11-COMPOSE-LICENSE.txt || exit 1
	@test -s LICENSES/QT-COMPOSE-NOTICE.md || exit 1
	@test -s LICENSES/FUTO-VOICE-SOURCE-FIRST-LICENSE.md || exit 1
	@test -s LICENSES/AMIRI-FONT-LICENSE.txt || exit 1
	@test -s LICENSES/YEKA-ZIP-LICENSE.txt || exit 1
	@test "$$(printf '%s\n' $(SOUND_FILES) | wc -l)" -eq $(SOUND_EXPECTED_FILES) || exit 1
	@test -z "$$(find assets/sounds -maxdepth 1 -type f -name '*.wav' -size 0 -print -quit)" || exit 1
	@for file in $(ICON_FILES); do test -s "$$file" || exit 1; done
	@for file in $(FONT_FILES); do test -s "$$file" || exit 1; done

install: check
	install -Dm0755 "$(ENGINE_BINARY)" "$(DESTDIR)$(PREFIX)/libexec/futo-keyboard-engine"
	install -Dm0755 "$(HELPER_BINARY)" "$(DESTDIR)$(PREFIX)/libexec/futo-keyboard-helper"
	install -Dm0755 "$(SECRETS_BINARY)" "$(DESTDIR)$(PREFIX)/libexec/futo-keyboard-secrets"
	install -Dm0755 "$(KEYRING_BINARY)" "$(DESTDIR)$(PREFIX)/libexec/futo-keyboard-keyring"
	install -Dm0755 "$(FOCUS_BINARY)" "$(DESTDIR)$(PREFIX)/libexec/futo-keyboard-focus"
	install -Dm0755 "$(VOICE_BINARY)" "$(DESTDIR)$(PREFIX)/libexec/futo-keyboard-voice"
	install -Dm0755 "$(POLICY_LIBRARY)" \
		"$(DESTDIR)$(LIBDIR)/libfuto-maliit-policy.so.1"
	install -Dm0755 "$(COMPOSE_PLUGIN)" \
		"$(DESTDIR)$(LIBDIR)/qt5/plugins/platforminputcontexts/libcomposeplatforminputcontextplugin.so"
	install -Dm0755 "$(COMPOSE_WRAPPER)" \
		"$(DESTDIR)$(LIBDIR)/qt5/plugins/platforminputcontexts/libafutomaliitcomposewrapper.so"
	install -Dm0755 "$(WAYLAND_DEADKEY_HOOK)" \
		"$(PACKAGE_ROOT)/hardware/libQt5WaylandClient.so.5.6.3"
	install -Dm0755 "$(WAYLAND_DEADKEY_ORIGINAL)" \
		"$(PACKAGE_ROOT)/hardware/libQt5WaylandClientFutoOriginal.so.5.6.3"
	install -Dm0644 "$(WAYLAND_STOCK_SHA256)" \
		"$(PACKAGE_ROOT)/hardware/stock-wayland.sha256"
	install -d "$(DESTDIR)$(PREFIX)/libexec"
	sed 's#@FUTO_LIBDIR@#$(LIBDIR)#g' packaging/scripts/install-wayland-deadkey-hook.sh > \
		"$(DESTDIR)$(PREFIX)/libexec/futo-keyboard-install-wayland-deadkey-hook"
	chmod 0755 "$(DESTDIR)$(PREFIX)/libexec/futo-keyboard-install-wayland-deadkey-hook"
	sed 's#@FUTO_LIBDIR@#$(LIBDIR)#g' packaging/scripts/remove-wayland-deadkey-hook.sh > \
		"$(DESTDIR)$(PREFIX)/libexec/futo-keyboard-remove-wayland-deadkey-hook"
	chmod 0755 "$(DESTDIR)$(PREFIX)/libexec/futo-keyboard-remove-wayland-deadkey-hook"
	install -Dm0755 packaging/scripts/install-textinput-bottom-hook.sh \
		"$(DESTDIR)$(PREFIX)/libexec/futo-keyboard-install-textinput-bottom-hook"
	install -Dm0755 packaging/scripts/remove-textinput-bottom-hook.sh \
		"$(DESTDIR)$(PREFIX)/libexec/futo-keyboard-remove-textinput-bottom-hook"
	install -Dm0644 packaging/patches/textinput-bottom-settings.patch \
		"$(PACKAGE_ROOT)/integration/textinput-bottom-settings.patch"
	install -Dm0644 "$(COMPOSE_ROOT)/en_US.UTF-8/Compose" \
		"$(DESTDIR)$(PREFIX)/share/X11/locale/en_US.UTF-8/Compose"
	install -Dm0644 "$(COMPOSE_ROOT)/compose.dir" \
		"$(DESTDIR)$(PREFIX)/share/X11/locale/compose.dir"
	install -Dm0644 "$(COMPOSE_ROOT)/locale.alias" \
		"$(DESTDIR)$(PREFIX)/share/X11/locale/locale.alias"
	@for file in $(HANDLER_FILES); do \
		install -Dm0644 "$$file" "$(MALIIT_ROOT)/handlers/$$(basename "$$file")"; \
	done
	install -Dm0644 qml/FutoSettingsPage.qml \
		"$(DESTDIR)$(PREFIX)/share/jolla-settings/pages/futo-keyboard-sailfish/main.qml"
	@for file in $(filter-out FutoSettingsPage.qml,$(SETTINGS_QML)); do \
		install -Dm0644 "qml/$$file" \
			"$(DESTDIR)$(PREFIX)/share/jolla-settings/pages/futo-keyboard-sailfish/$$file"; \
	done
	install -Dm0644 layouts/FutoLetterLayouts.js \
		"$(DESTDIR)$(PREFIX)/share/jolla-settings/pages/futo-keyboard-sailfish/FutoLetterLayouts.js"
	@for file in $(LAYOUT_FILES); do \
		install -Dm0644 "$$file" "$(MALIIT_ROOT)/layouts/$$(basename "$$file")"; \
	done
	install -Dm0644 content/manifest.json "$(PACKAGE_ROOT)/content/manifest.json"
	@for style in twemoji openmoji; do \
		for codepoint in $(EMOJI_PREVIEW_CODEPOINTS); do \
			install -Dm0644 "emoji/$$style/$$codepoint.svg" \
				"$(PACKAGE_ROOT)/content-previews/emoji/$$style/$$codepoint.svg"; \
		done; \
	done
	@for codepoint in $(EMOJI_PREVIEW_CODEPOINTS); do \
		install -Dm0644 "emoji/noto/$$codepoint.png" \
			"$(PACKAGE_ROOT)/content-previews/emoji/noto/$$codepoint.png"; \
	done
	install -d "$(PACKAGE_ROOT)/emoji-tabs"
	@for codepoint in $(EMOJI_TAB_CODEPOINTS); do \
		install -m0644 "emoji/noto/$$codepoint.png" \
			"$(PACKAGE_ROOT)/emoji-tabs/$$codepoint.png"; \
	done
	install -d "$(PACKAGE_ROOT)/icons"
	@for file in $(ICON_FILES); do \
		install -m0644 "$$file" "$(PACKAGE_ROOT)/icons/"; \
	done
	install -d "$(PACKAGE_ROOT)/sounds"
	@for file in $(SOUND_FILES); do \
		install -m0644 "$$file" "$(PACKAGE_ROOT)/sounds/"; \
	done
	install -d "$(PACKAGE_ROOT)/fonts"
	@for file in $(FONT_FILES); do \
		install -m0644 "$$file" "$(PACKAGE_ROOT)/fonts/"; \
	done
	install -Dm0644 packaging/dbus/org.hb.FutoKeyboard1.service \
		"$(DESTDIR)$(PREFIX)/share/dbus-1/services/org.hb.FutoKeyboard1.service"
	install -Dm0644 packaging/systemd/futo-keyboard-helper.service \
		"$(DESTDIR)$(PREFIX)/lib/systemd/user/futo-keyboard-helper.service"
	install -d "$(DESTDIR)$(PREFIX)/lib/systemd/user/maliit-server.service.d"
	sed 's#@FUTO_LIBDIR@#$(LIBDIR)#g' packaging/systemd/maliit-server.service.d/10-futo-hardware-policy.conf > \
		"$(DESTDIR)$(PREFIX)/lib/systemd/user/maliit-server.service.d/10-futo-hardware-policy.conf"
	install -Dm0644 packaging/polkit/49-futo-keyboard-secrets.rules \
		"$(DESTDIR)$(PREFIX)/share/polkit-1/rules.d/49-futo-keyboard-secrets.rules"
	install -Dm0644 packaging/polkit/org.hb.futo.keyboard.policy \
		"$(DESTDIR)$(PREFIX)/share/polkit-1/actions/org.hb.futo.keyboard.policy"
	install -Dm0644 LICENSES/FUTO-SOURCE-FIRST-LICENSE.md \
		"$(DESTDIR)$(PREFIX)/share/licenses/futo-keyboard-sailfish/FUTO-SOURCE-FIRST-LICENSE.md"
	install -Dm0644 LICENSES/FUTO-VOICE-SOURCE-FIRST-LICENSE.md \
		"$(DESTDIR)$(PREFIX)/share/licenses/futo-keyboard-sailfish/FUTO-VOICE-SOURCE-FIRST-LICENSE.md"
	install -Dm0644 LICENSES/JOLLA-BSD-LICENSE.txt \
		"$(DESTDIR)$(PREFIX)/share/licenses/futo-keyboard-sailfish/JOLLA-BSD-LICENSE.txt"
	install -Dm0644 LICENSES/EMOJI-ATTRIBUTION.md \
		"$(DESTDIR)$(PREFIX)/share/licenses/futo-keyboard-sailfish/EMOJI-ATTRIBUTION.md"
	install -Dm0644 LICENSES/TWEMOJI-GRAPHICS-LICENSE.txt \
		"$(DESTDIR)$(PREFIX)/share/licenses/futo-keyboard-sailfish/TWEMOJI-GRAPHICS-LICENSE.txt"
	install -Dm0644 LICENSES/OPENMOJI-LICENSE.txt \
		"$(DESTDIR)$(PREFIX)/share/licenses/futo-keyboard-sailfish/OPENMOJI-LICENSE.txt"
	install -Dm0644 LICENSES/NOTO-EMOJI-SVG-LICENSE.txt \
		"$(DESTDIR)$(PREFIX)/share/licenses/futo-keyboard-sailfish/NOTO-EMOJI-SVG-LICENSE.txt"
	install -Dm0644 LICENSES/UNICODE-LICENSE.txt \
		"$(DESTDIR)$(PREFIX)/share/licenses/futo-keyboard-sailfish/UNICODE-LICENSE.txt"
	install -Dm0644 LICENSES/FUTO-LAYOUTS-ATTRIBUTION.md \
		"$(DESTDIR)$(PREFIX)/share/licenses/futo-keyboard-sailfish/FUTO-LAYOUTS-ATTRIBUTION.md"
	install -Dm0644 LICENSES/LIBX11-COMPOSE-LICENSE.txt \
		"$(DESTDIR)$(PREFIX)/share/licenses/futo-keyboard-sailfish/LIBX11-COMPOSE-LICENSE.txt"
	install -Dm0644 LICENSES/QT-COMPOSE-NOTICE.md \
		"$(DESTDIR)$(PREFIX)/share/licenses/futo-keyboard-sailfish/QT-COMPOSE-NOTICE.md"
	install -Dm0644 LICENSES/AMIRI-FONT-LICENSE.txt \
		"$(DESTDIR)$(PREFIX)/share/licenses/futo-keyboard-sailfish/AMIRI-FONT-LICENSE.txt"
	install -Dm0644 LICENSES/YEKA-ZIP-LICENSE.txt \
		"$(DESTDIR)$(PREFIX)/share/licenses/futo-keyboard-sailfish/YEKA-ZIP-LICENSE.txt"
	install -Dm0644 MODIFIED-NOTICE.md \
		"$(DESTDIR)$(PREFIX)/share/licenses/futo-keyboard-sailfish/MODIFIED-NOTICE.md"
