package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

const launcherFixture = "[Desktop Entry]\nType=Link\nName=FUTO Layout Editor\nIcon=futo-keyboard-sailfish\nURL=futo-layout-editor://open\nNoDisplay=false\nX-FUTO-Layout-Editor=true\n"

func TestLayoutEditorLauncherDefaultsAndToggle(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	path, err := layoutEditorLauncherPath()
	if err != nil || path != filepath.Join(home, ".local", "share", "applications", layoutEditorLauncherName) {
		t.Fatal(path, err)
	}
	if layoutEditorLauncherName == layoutEditorDesktopName {
		t.Fatal("the optional icon must not shadow the system desktop entry")
	}
	application := &service{}
	if visible, err := application.GetLayoutEditorLauncherVisible(); err != nil || visible {
		t.Fatal("launcher should be hidden until explicitly enabled", visible, err)
	}
	template := filepath.Join(home, "template.desktop")
	if err := os.WriteFile(template, []byte(launcherFixture), 0644); err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 2; i++ {
		if err := setLayoutEditorLauncher(template, path, true); err != nil {
			t.Fatal(err)
		}
		if visible, err := application.GetLayoutEditorLauncherVisible(); err != nil || !visible {
			t.Fatal("enabled launcher not reported", visible, err)
		}
	}
	data, _ := os.ReadFile(path)
	info, _ := os.Stat(path)
	if !bytes.Contains(data, []byte("\nNoDisplay=false\n")) || !bytes.Contains(data, []byte("\nType=Link\n")) || bytes.Contains(data, []byte("\nExec=")) || info.Mode().Perm() != 0644 {
		t.Fatal("incorrect launcher contents or permissions")
	}
	original, _ := os.ReadFile(template)
	if string(original) != launcherFixture {
		t.Fatal("the package-owned launcher must not be modified")
	}
	// The file itself persists the choice when the helper or phone restarts.
	restarted := &service{}
	if visible, err := restarted.GetLayoutEditorLauncherVisible(); err != nil || !visible {
		t.Fatal("launcher choice did not persist", visible, err)
	}
	for i := 0; i < 2; i++ {
		if visible, err := application.SetLayoutEditorLauncherVisible(false); err != nil || visible {
			t.Fatal("could not hide launcher", visible, err)
		}
	}
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatal("hidden launcher override remains")
	}
	entries, _ := os.ReadDir(filepath.Dir(path))
	if len(entries) != 0 {
		t.Fatal("temporary launcher files remain")
	}
}

func TestLayoutEditorLauncherPreservesUnrelatedEntries(t *testing.T) {
	directory := t.TempDir()
	template := filepath.Join(directory, "template.desktop")
	path := filepath.Join(directory, layoutEditorLauncherName)
	if err := os.WriteFile(template, []byte(launcherFixture), 0644); err != nil {
		t.Fatal(err)
	}
	foreign := []byte("[Desktop Entry]\nName=My shortcut\nExec=/usr/bin/true\n")
	if err := os.WriteFile(path, foreign, 0644); err != nil {
		t.Fatal(err)
	}
	for _, visible := range []bool{true, false} {
		if setLayoutEditorLauncher(template, path, visible) == nil {
			t.Fatal("modified an unowned launcher entry")
		}
	}
	data, _ := os.ReadFile(path)
	if !bytes.Equal(data, foreign) {
		t.Fatal("unrelated launcher entry changed")
	}
	if err := os.Remove(path); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(template, path); err != nil {
		t.Fatal(err)
	}
	for _, visible := range []bool{true, false} {
		if setLayoutEditorLauncher(template, path, visible) == nil {
			t.Fatal("followed or replaced a launcher symlink")
		}
	}
	data, _ = os.ReadFile(template)
	if string(data) != launcherFixture {
		t.Fatal("symlink target changed")
	}
}

func TestLayoutEditorLauncherRejectsInvalidTemplates(t *testing.T) {
	directory := t.TempDir()
	template := filepath.Join(directory, "template.desktop")
	path := filepath.Join(directory, "applications", layoutEditorLauncherName)
	for _, invalid := range []string{"", "[Desktop Entry]\nNoDisplay=false\n", strings.Replace(launcherFixture, "Type=Link", "Type=Application", 1), strings.Replace(launcherFixture, "NoDisplay=false", "NoDisplay=true", 1), strings.Replace(launcherFixture, "URL=futo-layout-editor://open", "URL=https://example.com", 1), launcherFixture + "Exec=/usr/bin/true\n"} {
		if err := os.WriteFile(template, []byte(invalid), 0644); err != nil {
			t.Fatal(err)
		}
		if setLayoutEditorLauncher(template, path, true) == nil {
			t.Fatal("accepted an invalid launcher template")
		}
		if _, err := os.Stat(path); !os.IsNotExist(err) {
			t.Fatal("failed toggle created a launcher entry")
		}
	}
}

func TestLayoutEditorLauncherMigratesOwnedShortcut(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	path, _ := layoutEditorLauncherPath()
	legacy := filepath.Join(filepath.Dir(path), layoutEditorDesktopName)
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		t.Fatal(err)
	}
	visible := []byte(launcherFixture)
	if err := os.WriteFile(legacy, visible, 0644); err != nil {
		t.Fatal(err)
	}
	application := &service{}
	if enabled, err := application.GetLayoutEditorLauncherVisible(); err != nil || !enabled {
		t.Fatal("existing choice was not retained", enabled, err)
	}
	if _, err := os.Lstat(legacy); !os.IsNotExist(err) {
		t.Fatal("old same-name shortcut remains")
	}
	if err := os.WriteFile(legacy, visible, 0644); err != nil {
		t.Fatal(err)
	}
	if err := migrateLayoutEditorLauncher(path); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Lstat(legacy); !os.IsNotExist(err) {
		t.Fatal("duplicate owned shortcut remains")
	}
	if enabled, err := application.SetLayoutEditorLauncherVisible(false); err != nil || enabled {
		t.Fatal("could not hide migrated shortcut", enabled, err)
	}
	foreign := []byte("[Desktop Entry]\nName=My custom shortcut\n")
	if err := os.WriteFile(legacy, foreign, 0644); err != nil {
		t.Fatal(err)
	}
	if enabled, err := application.GetLayoutEditorLauncherVisible(); err != nil || enabled {
		t.Fatal("unrelated shortcut was treated as an enabled FUTO entry", enabled, err)
	}
	data, _ := os.ReadFile(legacy)
	if !bytes.Equal(data, foreign) {
		t.Fatal("an unrelated shortcut was modified")
	}
}

func TestLayoutEditorLauncherUpgradeToRemovableLink(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	path, _ := layoutEditorLauncherPath()
	legacy := filepath.Join(filepath.Dir(path), layoutEditorDesktopName)
	template := filepath.Join(home, "template.desktop")
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(template, []byte(launcherFixture), 0644); err != nil {
		t.Fatal(err)
	}
	old := []byte("[Desktop Entry]\nType=Application\nExec=/usr/bin/futo-layout-editor\nNoDisplay=false\nX-FUTO-Layout-Editor=true\n")
	for _, oldPath := range []string{legacy, path} {
		if err := os.WriteFile(oldPath, old, 0644); err != nil {
			t.Fatal(err)
		}
		if err := upgradeLayoutEditorLauncher(template, path); err != nil {
			t.Fatal(err)
		}
		data, err := os.ReadFile(path)
		if err != nil || string(data) != launcherFixture {
			t.Fatal("application entry was not replaced by a removable link", err)
		}
		if _, err := os.Stat(legacy); !os.IsNotExist(err) {
			t.Fatal("old launcher remains")
		}
	}
	if err := os.Remove(path); err != nil {
		t.Fatal(err)
	}
	if err := upgradeLayoutEditorLauncher(template, path); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatal("upgrade enabled a hidden shortcut")
	}
}

func TestLayoutEditorLauncherWatchesExternalRemoval(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	path, _ := layoutEditorLauncherPath()
	template := filepath.Join(home, "template.desktop")
	if err := os.WriteFile(template, []byte(launcherFixture), 0644); err != nil {
		t.Fatal(err)
	}
	if err := setLayoutEditorLauncher(template, path, true); err != nil {
		t.Fatal(err)
	}
	changes := make(chan bool, 10)
	watcher, err := watchLayoutEditorLauncher(path, func(visible bool) { changes <- visible })
	if err != nil {
		t.Fatal(err)
	}
	defer watcher.Close()
	checkChange := func(want bool) {
		t.Helper()
		select {
		case visible := <-changes:
			if visible != want {
				t.Fatal("incorrect shortcut state", visible, want)
			}
		case <-time.After(3 * time.Second):
			t.Fatal("shortcut change was not reported")
		}
	}
	// This is the filesystem operation performed by Sailfish for Type=Link.
	if err := os.Remove(path); err != nil {
		t.Fatal(err)
	}
	checkChange(false)
	if visible, err := (&service{}).GetLayoutEditorLauncherVisible(); err != nil || visible {
		t.Fatal("removing the shortcut did not turn off the setting", visible, err)
	}
	if err := setLayoutEditorLauncher(template, path, true); err != nil {
		t.Fatal(err)
	}
	checkChange(true)
	if err := os.WriteFile(filepath.Join(filepath.Dir(path), "unrelated.desktop"), []byte("Other app"), 0644); err != nil {
		t.Fatal(err)
	}
	select {
	case <-changes:
		t.Fatal("an unrelated launcher caused a false change")
	case <-time.After(50 * time.Millisecond):
	}
}
