%global _userunitdir /usr/lib/systemd/user
%global _licensedir /usr/share/licenses
%global __strip /bin/true
%global _missing_build_ids_terminate_build 0

Name:           futo-keyboard-sailfish
Version:        0.2.1
Release:        1
Summary:        FUTO-derived local keyboard and predictions for Sailfish OS
License:        LicenseRef-FUTO-Source-First-1.1-kb AND BSD-3-Clause AND CC-BY-4.0 AND CC-BY-SA-4.0 AND Apache-2.0 AND Unicode-3.0 AND MIT AND OFL-1.1 AND (LGPL-2.1-only OR LGPL-3.0-only)
Source0:        %{name}-%{version}.tar.gz
ExclusiveArch:  aarch64 armv7hl i486

BuildRequires:  make

Requires:       jolla-keyboard
Requires:       maliit-framework-wayland
Requires:       nemo-qml-plugin-dbus-qt5
Requires:       nemo-qml-plugin-configuration-qt5
Requires:       nemo-qml-plugin-devicelock
Requires:       nemo-qml-plugin-systemsettings
Requires:       libngf-qt5-declarative
Requires:       qt5-qtfeedback
Requires:       jolla-settings-system
Requires:       qt5-qtsvg
Requires:       pulseaudio
Requires:       libstdc++
Requires:       systemd
Requires:       libsailfishsecrets
Requires:       sailfishsecretsdaemon
Requires:       sailfish-components-pickers-qt5
Requires:       polkit
Requires:       qt5-qtwayland-wayland_egl >= 5.6.3

%description
An independent, modified Sailfish OS integration using FUTO Keyboard dictionary
data. It provides one native FUTO layout with simultaneous suggestions across
25 selectable prediction languages, per-language visual layout assignment,
automatic language weighting, context and next-word learning, configurable typo
correction, keyboard-layout-aware swipe typing, optional offline FUTO voice typing,
private clipboard history, an on-device personal dictionary, and
keyboard appearance, gesture, sound and vibration controls. The same native
keyboard is available to Android AppSupport through Sailfish OS.

This is not an official FUTO product and is for personal, noncommercial use
under the included FUTO Source First License.

%prep
%setup -q

%build
make -f packaging/Makefile check ARCH=%{_target_cpu} \
    BUILD_DIR=build/%{_target_cpu} LIBDIR=%{_libdir}

%install
rm -rf %{buildroot}
make -f packaging/Makefile install DESTDIR=%{buildroot} PREFIX=%{_prefix} \
    ARCH=%{_target_cpu} BUILD_DIR=build/%{_target_cpu} LIBDIR=%{_libdir}

%post
/usr/libexec/futo-keyboard-install-wayland-deadkey-hook || :
/usr/libexec/futo-keyboard-install-textinput-bottom-hook || :
/usr/bin/systemctl-user daemon-reload >/dev/null 2>&1 || :
/usr/bin/systemctl-user reload dbus.service >/dev/null 2>&1 || :
/usr/bin/systemctl-user restart futo-keyboard-helper.service >/dev/null 2>&1 || :
/usr/bin/systemctl-user try-restart maliit-server.service >/dev/null 2>&1 || :

%preun
if [ "$1" -eq 0 ]; then
    /usr/bin/systemctl-user stop futo-keyboard-helper.service >/dev/null 2>&1 || :
    /usr/libexec/futo-keyboard-remove-textinput-bottom-hook || :
    /usr/libexec/futo-keyboard-remove-wayland-deadkey-hook || :
fi

%postun
/usr/bin/systemctl-user daemon-reload >/dev/null 2>&1 || :
/usr/bin/systemctl-user reload dbus.service >/dev/null 2>&1 || :
/usr/bin/systemctl-user try-restart maliit-server.service >/dev/null 2>&1 || :

%files
%defattr(0644,root,root,0755)
%license %{_licensedir}/%{name}/FUTO-SOURCE-FIRST-LICENSE.md
%license %{_licensedir}/%{name}/FUTO-VOICE-SOURCE-FIRST-LICENSE.md
%license %{_licensedir}/%{name}/JOLLA-BSD-LICENSE.txt
%license %{_licensedir}/%{name}/EMOJI-ATTRIBUTION.md
%license %{_licensedir}/%{name}/TWEMOJI-GRAPHICS-LICENSE.txt
%license %{_licensedir}/%{name}/OPENMOJI-LICENSE.txt
%license %{_licensedir}/%{name}/NOTO-EMOJI-SVG-LICENSE.txt
%license %{_licensedir}/%{name}/UNICODE-LICENSE.txt
%license %{_licensedir}/%{name}/FUTO-LAYOUTS-ATTRIBUTION.md
%license %{_licensedir}/%{name}/HUNGARIAN-DICTIONARY-ATTRIBUTION.md
%license %{_licensedir}/%{name}/LIBX11-COMPOSE-LICENSE.txt
%license %{_licensedir}/%{name}/QT-COMPOSE-NOTICE.md
%license %{_licensedir}/%{name}/AMIRI-FONT-LICENSE.txt
%license %{_licensedir}/%{name}/YEKA-ZIP-LICENSE.txt
%license %{_licensedir}/%{name}/MODIFIED-NOTICE.md
%attr(0755,root,root) %{_libexecdir}/futo-keyboard-engine
%attr(0755,root,root) %{_libexecdir}/futo-keyboard-helper
%attr(0755,root,root) %{_libexecdir}/futo-keyboard-secrets
%attr(4755,root,root) %{_libexecdir}/futo-keyboard-keyring
%attr(4755,root,root) %{_libexecdir}/futo-keyboard-focus
%attr(4755,root,root) %{_libexecdir}/futo-keyboard-appsupport
%attr(0755,root,root) %{_libexecdir}/futo-keyboard-voice
%attr(0755,root,root) %{_libexecdir}/futo-keyboard-install-wayland-deadkey-hook
%attr(0755,root,root) %{_libexecdir}/futo-keyboard-remove-wayland-deadkey-hook
%attr(0755,root,root) %{_libexecdir}/futo-keyboard-install-textinput-bottom-hook
%attr(0755,root,root) %{_libexecdir}/futo-keyboard-remove-textinput-bottom-hook
%attr(0755,root,root) %{_libdir}/libfuto-maliit-policy.so.1
%attr(0755,root,root) %{_libdir}/qt5/plugins/platforminputcontexts/libcomposeplatforminputcontextplugin.so
%attr(0755,root,root) %{_libdir}/qt5/plugins/platforminputcontexts/libafutomaliitcomposewrapper.so
%{_datadir}/X11/locale/en_US.UTF-8/Compose
%{_datadir}/X11/locale/compose.dir
%{_datadir}/X11/locale/locale.alias
%{_datadir}/futo-keyboard-sailfish/
%{_datadir}/maliit/plugins/com/jolla/FutoInputHandler.qml
%{_datadir}/maliit/plugins/com/jolla/FutoHorizontalPredictionListView.qml
%{_datadir}/maliit/plugins/com/jolla/FutoVerticalPredictionListView.qml
%{_datadir}/maliit/plugins/com/jolla/handlers/FutoInputHandler.qml
%{_datadir}/maliit/plugins/com/jolla/handlers/FutoHorizontalPredictionListView.qml
%{_datadir}/maliit/plugins/com/jolla/handlers/FutoVerticalPredictionListView.qml
%{_datadir}/jolla-settings/pages/futo-keyboard-sailfish/
%{_datadir}/jolla-settings/entries/futo-keyboard.json
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoCharacterKey.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoBackspaceKey.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoCommaKey.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoEmojiBackKey.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoEmojiGrid.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoEmojiKey.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoEmojiData.js
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoExtendedSymbolGrid.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoExtendedSymbolKey.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoExtendedSymbolsKey.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoDesktopKey.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoDesktopKeyData.js
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoDesktopKeyGrid.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoDesktopKeyRow.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoDesktopToolbar.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoDesktopToolbarSide.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoSymbolData.js
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoLanguageData.js
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoLetterLayouts.js
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoLayoutEditor.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoClipboardPanel.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoCredentialPanel.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoEnterKey.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoKeyboardLayout.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoNumpadLayout.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoNumpadRow.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoQwertyLayout.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoShiftKey.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoSpacebarKey.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoSpacebarRow.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoSymbolKey.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/FutoVoiceKey.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/futo.qml
%{_datadir}/maliit/plugins/com/jolla/layouts/layouts_futo.conf
%{_datadir}/dbus-1/services/org.hb.FutoKeyboard1.service
%{_datadir}/polkit-1/rules.d/49-futo-keyboard-secrets.rules
%{_datadir}/polkit-1/actions/org.hb.futo.keyboard.policy
%{_userunitdir}/futo-keyboard-helper.service
%{_userunitdir}/maliit-server.service.d/10-futo-hardware-policy.conf

%changelog
* Sat Aug 29 2026 HtheB - 0.2.1-1
- Add an optional Top Menu action that can force the keyboard to appear in
  Android apps which normally do not show a keyboard.
- Holding the language/layout Quick Settings button switches to another enabled
  Sailfish OS keyboard.
- Prevent secondary-character popups during swipe typing.

* Sat Aug 29 2026 HtheB - 0.2.0-2
- Show the language/layout Quick Settings item when another Sailfish keyboard
  is enabled, even if FUTO itself uses only one letter layout.
- Switch keyboards through Sailfish's active LayoutModel instead of the current
  FUTO keyboard surface.

* Fri Aug 28 2026 HtheB - 0.2.0-1
- Add the Fn keyboard page, configurable extra-key row, sticky desktop
  modifiers, and drag-and-drop organizers.
- Add vertical cursor movement, second-finger text selection, and terminal
  input compatibility improvements.
- Add Greek, Russian, Serbian Cyrillic and Serbian Latin predictions, plus
  Slovenian, Croatian/Serbian Latin and Serbian Cyrillic layouts.
- Improve compatibility with Sailfish OS 5.1, including swipe typing, Quick
  Settings, symbol and emoji tabs, and blank emoji rendering.

* Fri Aug 28 2026 HtheB - 0.1.0-1
- First public Sailfish OS release, including the native FUTO keyboard,
  downloadable content packs, offline voice typing and optional dictionaries.
- Split saved-password management into searchable Websites and Apps views;
  search covers encrypted password contents without exposing them in listings.
- Keep an authenticated vault session alive while its Settings section is in
  active use, and preserve login IDs across Sailfish remorse-delete countdowns.
- Exclude FUTO's own Settings fields from login-saving prompts.
- Offer saved logins only for an exact encrypted site match; never expose a
  generic vault action that ends in an empty result.
- Move login-saving confirmation out of the keyboard strip into Sailfish's
  native modal authorization surface after the login form closes.
- Preserve Android-browser usernames across transient invalid editor context so
  encrypted entries contain the website, username and password together.
