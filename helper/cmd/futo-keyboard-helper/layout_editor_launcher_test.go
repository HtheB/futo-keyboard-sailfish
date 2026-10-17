package main

import (
	"bytes"
	"context"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"testing"
	"time"
)

const launcherFixture = "[Desktop Entry]\nType=Application\nName=FUTO Layout Editor\nIcon=futo-keyboard-sailfish\nExec=/usr/bin/invoker --type=silica-qt5 --single-instance /usr/bin/futo-layout-editor\nNoDisplay=false\nX-FUTO-Layout-Editor=true\n"
const legacyLauncherFixture = "[Desktop Entry]\nType=Link\nURL=futo-layout-editor://open\nNoDisplay=false\nX-FUTO-Layout-Editor=true\n"

func TestLayoutEditorLauncherDefaultsMigrationAndToggle(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	path, err := layoutEditorLauncherPath()
	if err != nil || path != filepath.Join(home, ".local", "share", "applications", layoutEditorLauncherName) {
		t.Fatal(path, err)
	}
	systemPath := filepath.Join(t.TempDir(), layoutEditorLauncherName)
	if layoutEditorLauncherVisible(systemPath) || legacyLayoutEditorLauncherVisible(path) {
		t.Fatal("new installations must leave the icon hidden")
	}
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		t.Fatal(err)
	}
	oldPath := filepath.Join(filepath.Dir(path), layoutEditorDesktopName)
	for _, entry := range []string{path, oldPath} {
		if err := os.WriteFile(entry, []byte(legacyLauncherFixture), 0644); err != nil {
			t.Fatal(err)
		}
	}
	if !legacyLayoutEditorLauncherVisible(path) {
		t.Fatal("old choice lost")
	}
	calls := 0
	change := func(visible bool) error {
		calls++
		if visible {
			return os.WriteFile(systemPath, []byte(launcherFixture), 0644)
		}
		return os.Remove(systemPath)
	}
	for _, visible := range []bool{true, true, false, false, true} {
		if err := setLayoutEditorLauncherPackage(systemPath, path, visible, change); err != nil {
			t.Fatal(err)
		}
		if layoutEditorLauncherVisible(systemPath) != visible {
			t.Fatal("incorrect launcher state")
		}
		for _, entry := range []string{path, oldPath} {
			if _, err := os.Lstat(entry); !os.IsNotExist(err) {
				t.Fatal("duplicate user entry remains")
			}
		}
	}
	if calls != 3 {
		t.Fatal("unnecessary package transactions", calls)
	}
	// Native app-drawer X removes the optional package's desktop file.
	if err := os.Remove(systemPath); err != nil {
		t.Fatal(err)
	}
	if layoutEditorLauncherVisible(systemPath) {
		t.Fatal("native removal must turn the setting off")
	}
}

func TestLayoutEditorLauncherFailuresPreserveChoice(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, layoutEditorLauncherName)
	systemPath := filepath.Join(dir, "system.desktop")
	if err := os.WriteFile(path, []byte(legacyLauncherFixture), 0644); err != nil {
		t.Fatal(err)
	}
	for _, change := range []func(bool) error{
		func(bool) error { return errors.New("cancelled") },
		func(bool) error { return nil }, // A successful command without a desktop file is not success.
	} {
		if setLayoutEditorLauncherPackage(systemPath, path, true, change) == nil {
			t.Fatal("failed update reported success")
		}
		data, _ := os.ReadFile(path)
		if string(data) != legacyLauncherFixture {
			t.Fatal("failed update destroyed the existing choice")
		}
	}
	if err := os.WriteFile(systemPath, []byte(launcherFixture), 0644); err != nil {
		t.Fatal(err)
	}
	if setLayoutEditorLauncherPackage(systemPath, path, false, func(bool) error { return errors.New("cancelled") }) == nil {
		t.Fatal("cancelled removal reported success")
	}
	if !layoutEditorLauncherVisible(systemPath) || !legacyLayoutEditorLauncherVisible(path) {
		t.Fatal("failed removal changed the state")
	}
}

func TestLayoutEditorLauncherPreservesUnrelatedEntries(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, layoutEditorLauncherName)
	systemPath := filepath.Join(dir, "system.desktop")
	foreign := []byte("[Desktop Entry]\nName=My shortcut\nExec=/usr/bin/true\n")
	if err := os.WriteFile(path, foreign, 0644); err != nil {
		t.Fatal(err)
	}
	change := func(bool) error { t.Fatal("must not change packages before checking unrelated entries"); return nil }
	for _, visible := range []bool{true, false} {
		if setLayoutEditorLauncherPackage(systemPath, path, visible, change) == nil {
			t.Fatal("modified an unowned entry")
		}
	}
	data, _ := os.ReadFile(path)
	if !bytes.Equal(data, foreign) {
		t.Fatal("unrelated shortcut changed")
	}
	if err := os.Remove(path); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(systemPath, path); err != nil {
		t.Fatal(err)
	}
	for _, visible := range []bool{true, false} {
		if setLayoutEditorLauncherPackage(systemPath, path, visible, change) == nil {
			t.Fatal("followed a symlink")
		}
	}
}

func TestLayoutEditorLauncherPackageCommands(t *testing.T) {
	ctx := context.Background()
	var calls [][]string
	run := func(_ context.Context, name string, args ...string) ([]byte, error) {
		calls = append(calls, append([]string{name}, args...))
		if name == "/bin/rpm" {
			return []byte("futo-layout-editor-launcher;0.9.5-1;noarch;installed"), nil
		}
		return nil, nil
	}
	if err := changeLayoutEditorLauncherPackage(ctx, true, run); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(calls, [][]string{{layoutEditorLauncherInstaller}}) {
		t.Fatal("installation must use only the bundled local package", calls)
	}
	calls = nil
	if err := changeLayoutEditorLauncherPackage(ctx, false, run); err != nil {
		t.Fatal(err)
	}
	want := [][]string{{"/bin/rpm", "-q", "--queryformat", "%{NAME};%{VERSION}-%{RELEASE};%{ARCH};installed", layoutEditorLauncherPackage},
		{packageKitClientPath, "--plain", "-y", "remove", "futo-layout-editor-launcher;0.9.5-1;noarch;installed"}}
	if !reflect.DeepEqual(calls, want) {
		t.Fatal("removal must name the exact launcher and omit autoremove", calls)
	}
	for _, id := range []string{"futo-keyboard-sailfish;0.9.5-2;aarch64;installed", "futo-layout-editor-launcher;0.9.5-1;noarch;installed\nother", "futo-layout-editor-launcher;0.9.5-1;aarch64;installed"} {
		count := 0
		bad := func(_ context.Context, name string, args ...string) ([]byte, error) { count++; return []byte(id), nil }
		if changeLayoutEditorLauncherPackage(ctx, false, bad) == nil || count != 1 {
			t.Fatal("unsafe package removal", id, count)
		}
	}
	fail := func(context.Context, string, ...string) ([]byte, error) { return nil, errors.New("failed") }
	for _, visible := range []bool{true, false} {
		if changeLayoutEditorLauncherPackage(ctx, visible, fail) == nil {
			t.Fatal("transaction failure ignored")
		}
	}
}

func TestLayoutEditorLauncherWatchesExternalRemoval(t *testing.T) {
	path := filepath.Join(t.TempDir(), layoutEditorLauncherName)
	if err := os.WriteFile(path, []byte(launcherFixture), 0644); err != nil {
		t.Fatal(err)
	}
	changes := make(chan bool, 10)
	watcher, err := watchLayoutEditorLauncher(path, func(visible bool) { changes <- visible })
	if err != nil {
		t.Fatal(err)
	}
	defer watcher.Close()
	check := func(want bool) {
		t.Helper()
		select {
		case visible := <-changes:
			if visible != want {
				t.Fatal("wrong launcher state", visible, want)
			}
		case <-time.After(3 * time.Second):
			t.Fatal("launcher change not reported")
		}
	}
	if err := os.Remove(path); err != nil {
		t.Fatal(err)
	}
	check(false)
	if err := os.WriteFile(path, []byte(launcherFixture), 0644); err != nil {
		t.Fatal(err)
	}
	check(true)
	if err := os.WriteFile(filepath.Join(filepath.Dir(path), "other.desktop"), []byte("Other app"), 0644); err != nil {
		t.Fatal(err)
	}
	select {
	case <-changes:
		t.Fatal("unrelated entry caused a false change")
	case <-time.After(50 * time.Millisecond):
	}
}
