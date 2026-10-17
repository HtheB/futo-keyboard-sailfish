package main

import (
	"bytes"
	"errors"
	"io"
	"os"
	"path/filepath"
	"sync"
	"syscall"

	"github.com/godbus/dbus/v5"
)

const layoutEditorDesktopName = "futo-layout-editor.desktop"
const layoutEditorLauncherName = "futo-layout-editor-launcher.desktop"
const layoutEditorLauncherTemplate = "/usr/share/futo-keyboard-sailfish/editor/" + layoutEditorLauncherName
const layoutEditorLauncherMarker = "\nX-FUTO-Layout-Editor=true\n"

var layoutEditorLauncherMutex sync.Mutex

func layoutEditorLauncherPath() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil || !filepath.IsAbs(home) {
		return "", errors.New("Could not find the application directory")
	}
	return filepath.Join(home, ".local", "share", "applications", layoutEditorLauncherName), nil
}

func migrateLayoutEditorLauncher(path string) error {
	legacy := filepath.Join(filepath.Dir(path), layoutEditorDesktopName)
	data, err := readLayoutEditorLauncher(legacy)
	if err != nil || data == nil {
		// Never move a user's unrelated or symlinked desktop entry.
		return nil
	}
	current, err := readLayoutEditorLauncher(path)
	if err != nil {
		return err
	}
	if current == nil {
		err = os.Rename(legacy, path)
	} else {
		err = os.Remove(legacy)
	}
	if err != nil {
		return errors.New("Could not update the Layout Editor launcher")
	}
	return nil
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

func setLayoutEditorLauncher(template, path string, visible bool) error {
	if _, err := readLayoutEditorLauncher(path); err != nil {
		return err
	}
	if !visible {
		if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
			return errors.New("Could not hide the Layout Editor launcher")
		}
		return nil
	}
	data, err := os.ReadFile(template)
	if err != nil || !bytes.Contains(data, []byte(layoutEditorLauncherMarker)) ||
		!bytes.Contains(data, []byte("\nType=Link\n")) ||
		!bytes.Contains(data, []byte("\nURL=futo-layout-editor://open\n")) ||
		bytes.Count(data, []byte("\nNoDisplay=false\n")) != 1 ||
		bytes.Contains(data, []byte("\nExec=")) {
		return errors.New("Could not read the installed Layout Editor launcher")
	}
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return errors.New("Could not create the application directory")
	}
	file, err := os.CreateTemp(filepath.Dir(path), ".futo-launcher-*")
	if err != nil {
		return errors.New("Could not create the Layout Editor launcher")
	}
	defer os.Remove(file.Name())
	if err = file.Chmod(0644); err == nil {
		_, err = file.Write(data)
	}
	if err == nil {
		err = file.Sync()
	}
	closeErr := file.Close()
	if err == nil {
		err = closeErr
	}
	if err == nil {
		err = os.Rename(file.Name(), path)
	}
	if err != nil {
		return errors.New("Could not save the Layout Editor launcher")
	}
	return nil
}

func (service *service) GetLayoutEditorLauncherVisible() (bool, *dbus.Error) {
	layoutEditorLauncherMutex.Lock()
	defer layoutEditorLauncherMutex.Unlock()
	path, err := layoutEditorLauncherPath()
	if err == nil {
		err = migrateLayoutEditorLauncher(path)
	}
	if err != nil {
		return false, dbus.MakeFailedError(err)
	}
	data, err := readLayoutEditorLauncher(path)
	if err != nil {
		return false, dbus.MakeFailedError(err)
	}
	return bytes.Contains(data, []byte("\nNoDisplay=false\n")), nil
}

func (service *service) SetLayoutEditorLauncherVisible(visible bool) (bool, *dbus.Error) {
	layoutEditorLauncherMutex.Lock()
	defer layoutEditorLauncherMutex.Unlock()
	path, err := layoutEditorLauncherPath()
	if err == nil {
		err = migrateLayoutEditorLauncher(path)
	}
	if err == nil {
		err = setLayoutEditorLauncher(layoutEditorLauncherTemplate, path, visible)
	}
	if err != nil {
		return false, dbus.MakeFailedError(err)
	}
	if service.bus != nil {
		_ = service.bus.Emit(objectPath, interfaceName+".LayoutEditorLauncherChanged", visible)
	}
	return visible, nil
}

// A Link entry is removed directly by Sailfish, never through PackageKit.
// Keep the checkbox in sync without polling when it is removed in the drawer.
func watchLayoutEditorLauncher(path string, changed func(bool)) (io.Closer, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return nil, err
	}
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
	readVisible := func() bool {
		layoutEditorLauncherMutex.Lock()
		defer layoutEditorLauncherMutex.Unlock()
		data, err := readLayoutEditorLauncher(path)
		return err == nil && bytes.Contains(data, []byte("\nNoDisplay=false\n"))
	}
	visible := readVisible()
	go func() {
		buffer := make([]byte, 64*1024)
		for {
			if _, err := file.Read(buffer); err != nil {
				return
			}
			next := readVisible()
			if next != visible {
				visible = next
				changed(next)
			}
		}
	}()
	return file, nil
}

func upgradeLayoutEditorLauncher(template, path string) error {
	if err := migrateLayoutEditorLauncher(path); err != nil {
		return err
	}
	data, err := readLayoutEditorLauncher(path)
	if err != nil || data == nil || bytes.Contains(data, []byte("\nType=Link\n")) {
		return err
	}
	return setLayoutEditorLauncher(template, path, bytes.Contains(data, []byte("\nNoDisplay=false\n")))
}
