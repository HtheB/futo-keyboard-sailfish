package main

import (
	"bytes"
	"context"
	"errors"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/godbus/dbus/v5"
)

const layoutEditorDesktopName = "futo-layout-editor.desktop"
const layoutEditorLauncherName = "futo-layout-editor-launcher.desktop"
const layoutEditorLauncherPackage = "futo-layout-editor-launcher"
const layoutEditorLauncherRPM = "/usr/share/futo-keyboard-sailfish/editor/launcher.rpm"
const layoutEditorLauncherInstaller = "/usr/libexec/futo-keyboard-launcher-install"
const layoutEditorSystemLauncher = "/usr/share/applications/" + layoutEditorLauncherName
const layoutEditorLauncherMarker = "\nX-FUTO-Layout-Editor=true\n"

var layoutEditorLauncherMutex sync.Mutex

func layoutEditorLauncherPath() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil || !filepath.IsAbs(home) {
		return "", errors.New("Could not find the application directory")
	}
	return filepath.Join(home, ".local", "share", "applications", layoutEditorLauncherName), nil
}

func readLayoutEditorLauncher(path string) ([]byte, error) {
	file, err := os.OpenFile(path, os.O_RDONLY|syscall.O_NONBLOCK|syscall.O_NOFOLLOW, 0)
	if os.IsNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, errors.New("Could not read the Layout Editor launcher")
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil || !info.Mode().IsRegular() || info.Size() > 16*1024 {
		return nil, errors.New("Could not read the Layout Editor launcher")
	}
	data, err := io.ReadAll(io.LimitReader(file, 16*1024+1))
	data = bytes.ReplaceAll(data, []byte("\r\n"), []byte("\n"))
	if err != nil || len(data) > 16*1024 || !bytes.Contains(data, []byte(layoutEditorLauncherMarker)) {
		return nil, errors.New("An existing custom launcher entry cannot be changed")
	}
	return data, nil
}

func layoutEditorLauncherVisible(path string) bool {
	data, err := readLayoutEditorLauncher(path)
	return err == nil && bytes.Contains(data, []byte("\nType=Application\n")) &&
		bytes.Contains(data, []byte("\nNoDisplay=false\n"))
}

// Older releases used per-user shortcuts. Remove only entries carrying our
// marker, and only after the replacement operation has succeeded.
func removeLegacyLayoutEditorLaunchers(path string) error {
	for _, entry := range []string{path, filepath.Join(filepath.Dir(path), layoutEditorDesktopName)} {
		data, err := readLayoutEditorLauncher(entry)
		if err != nil {
			return err
		}
		if data != nil {
			if err := os.Remove(entry); err != nil && !os.IsNotExist(err) {
				return errors.New("Could not update the Layout Editor launcher")
			}
		}
	}
	return nil
}

func legacyLayoutEditorLauncherVisible(path string) bool {
	for _, entry := range []string{path, filepath.Join(filepath.Dir(path), layoutEditorDesktopName)} {
		data, err := readLayoutEditorLauncher(entry)
		if err == nil && bytes.Contains(data, []byte("\nNoDisplay=false\n")) {
			return true
		}
	}
	return false
}

type layoutEditorPackageCommand func(context.Context, string, ...string) ([]byte, error)

func runLayoutEditorPackageCommand(ctx context.Context, name string, args ...string) ([]byte, error) {
	return exec.CommandContext(ctx, name, args...).CombinedOutput()
}

// The keyboard does not depend on this optional package. Removing the icon
// therefore removes only its desktop file, never the editor or keyboard.
func changeLayoutEditorLauncherPackage(ctx context.Context, visible bool, run layoutEditorPackageCommand) error {
	if visible {
		// This fixed-operation bridge validates its parent, package ownership
		// and permissions before invoking PackageKit with a clean environment.
		_, err := run(ctx, layoutEditorLauncherInstaller)
		if err != nil {
			return errors.New("Could not show the Layout Editor in the app drawer")
		}
		return nil
	}
	output, err := run(ctx, "/bin/rpm", "-q", "--queryformat",
		"%{NAME};%{VERSION}-%{RELEASE};%{ARCH};installed", layoutEditorLauncherPackage)
	if err != nil {
		return errors.New("Could not identify the Layout Editor launcher package")
	}
	id := strings.TrimSpace(string(output))
	fields := strings.Split(id, ";")
	if len(fields) != 4 || fields[0] != layoutEditorLauncherPackage ||
		fields[1] == "" || fields[2] != "noarch" || fields[3] != "installed" {
		return errors.New("Could not identify the Layout Editor launcher package")
	}
	// Deliberately omit --autoremove: no dependencies may be removed with it.
	if _, err := run(ctx, packageKitClientPath, "--plain", "-y", "remove", id); err != nil {
		return errors.New("Could not hide the Layout Editor from the app drawer")
	}
	return nil
}

func setLayoutEditorLauncherPackage(systemPath, legacyPath string, visible bool, change func(bool) error) error {
	// Reject unrelated entries before making any package changes.
	for _, entry := range []string{legacyPath, filepath.Join(filepath.Dir(legacyPath), layoutEditorDesktopName)} {
		if _, err := readLayoutEditorLauncher(entry); err != nil {
			return err
		}
	}
	if layoutEditorLauncherVisible(systemPath) != visible {
		if err := change(visible); err != nil {
			return err
		}
		if layoutEditorLauncherVisible(systemPath) != visible {
			return errors.New("The Layout Editor launcher could not be updated")
		}
	}
	return removeLegacyLayoutEditorLaunchers(legacyPath)
}

func (service *service) GetLayoutEditorLauncherVisible() (bool, *dbus.Error) {
	return layoutEditorLauncherVisible(layoutEditorSystemLauncher), nil
}

func (service *service) SetLayoutEditorLauncherVisible(visible bool) (bool, *dbus.Error) {
	layoutEditorLauncherMutex.Lock()
	defer layoutEditorLauncherMutex.Unlock()
	path, err := layoutEditorLauncherPath()
	if err == nil {
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
		defer cancel()
		err = setLayoutEditorLauncherPackage(layoutEditorSystemLauncher, path, visible, func(show bool) error {
			return changeLayoutEditorLauncherPackage(ctx, show, runLayoutEditorPackageCommand)
		})
	}
	if err != nil {
		return false, dbus.MakeFailedError(err)
	}
	service.emitLayoutEditorLauncherChanged(visible)
	return visible, nil
}

func (service *service) emitLayoutEditorLauncherChanged(visible bool) {
	if service.bus != nil {
		_ = service.bus.Emit(objectPath, interfaceName+".LayoutEditorLauncherChanged", visible)
	}
}

func (service *service) upgradeLayoutEditorLauncher() {
	path, err := layoutEditorLauncherPath()
	if err != nil {
		return
	}
	// Do not block D-Bus startup or RPM post-install on a package transaction.
	// Existing users keep their choice; new installations remain hidden.
	if legacyLayoutEditorLauncherVisible(path) {
		if _, err := service.SetLayoutEditorLauncherVisible(true); err != nil {
			log.Print("Could not update the Layout Editor shortcut")
		}
	}
}

// Native app-drawer removal changes the package-owned desktop entry. Watch
// that directory rather than polling so the checkbox follows it immediately.
func watchLayoutEditorLauncher(path string, changed func(bool)) (io.Closer, error) {
	fd, err := syscall.InotifyInit1(syscall.IN_CLOEXEC | syscall.IN_NONBLOCK)
	if err != nil {
		return nil, err
	}
	file := os.NewFile(uintptr(fd), "layout-editor-launcher-watch")
	if _, err := syscall.InotifyAddWatch(fd, filepath.Dir(path),
		syscall.IN_CREATE|syscall.IN_DELETE|syscall.IN_MOVED_TO|syscall.IN_MOVED_FROM|syscall.IN_CLOSE_WRITE); err != nil {
		file.Close()
		return nil, err
	}
	visible := layoutEditorLauncherVisible(path)
	go func() {
		buffer := make([]byte, 64*1024)
		for {
			if _, err := file.Read(buffer); err != nil {
				return
			}
			next := layoutEditorLauncherVisible(path)
			if next != visible {
				visible = next
				changed(next)
			}
		}
	}()
	return file, nil
}
