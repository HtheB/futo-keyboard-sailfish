%global _missing_build_ids_terminate_build 0

Name:           futo-layout-editor-launcher
Version:        0.9.6
Release:        1
Summary:        Optional FUTO Layout Editor app-drawer shortcut
License:        BSD-3-Clause
Source0:        futo-layout-editor-launcher.desktop
BuildArch:      noarch
AutoReqProv:    no
Requires:       futo-keyboard-sailfish >= 0.9.6

%description
An optional app-drawer shortcut for FUTO Layout Editor. Removing this package
hides the shortcut without removing FUTO Keyboard or any saved layouts.

%prep

%build

%install
install -Dm0644 %{SOURCE0} %{buildroot}/usr/share/applications/futo-layout-editor-launcher.desktop

%files
%defattr(0644,root,root,0755)
/usr/share/applications/futo-layout-editor-launcher.desktop
