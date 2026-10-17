package main

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"syscall"
	"unicode"
	"unicode/utf8"

	"github.com/godbus/dbus/v5"
)

// Layout documents are inert, versioned data. They cannot name QML files,
// commands, image URLs or input engines. No language or dictionary is stored.
type customLayoutKey struct {
	Action      string            `json:"action"`
	Label       string            `json:"label"`
	Output      string            `json:"output"`
	Shifted     string            `json:"shifted,omitempty"`
	Width       float64           `json:"width"`
	More        []json.RawMessage `json:"more"`
	DefaultMore int               `json:"defaultMore"`
	Dead        bool              `json:"dead"`
	Target      string            `json:"target,omitempty"`
	Style       string            `json:"style,omitempty"`
	HoldAction  string            `json:"holdAction,omitempty"`
	HoldTarget  string            `json:"holdTarget,omitempty"`
}
type customLayoutPage struct {
	ID   string              `json:"id"`
	Name string              `json:"name"`
	Kind string              `json:"kind"`
	Rows [][]customLayoutKey `json:"rows"`
}
type customLayout struct {
	Format  string             `json:"format"`
	Version int                `json:"version"`
	ID      string             `json:"id"`
	Name    string             `json:"name"`
	Pages   []customLayoutPage `json:"pages"`
}
type customLayoutCollection struct {
	Version int            `json:"version"`
	Layouts []customLayout `json:"layouts"`
}

const customLayoutLimit = 256 * 1024
const customLayoutsLimit = 2 * 1024 * 1024
const customLayoutsSetting = "/sailfish/text_input/futo_keyboard/customLayoutsJson"

var customLayoutsMutex sync.Mutex
var customLayoutsWriteSetting = dconfWrite
var customLayoutID = regexp.MustCompile(`^custom-[a-f0-9]{32}$`)
var customPageID = regexp.MustCompile(`^[a-zA-Z0-9_-]{1,48}$`)

func customActionAllowed(action string) bool {
	return !strings.ContainsRune(action, '|') && strings.Contains("|text|space|backspace|enter|shift|page|emoji|symbols|language|clipboard|voice|copy|cut|paste|selectall|hide|esc|tab|delete|insert|home|end|pageup|pagedown|left|right|up|down|ctrl|alt|altgr|super|menu|print|pause|numlock|scrolllock|f1|f2|f3|f4|f5|f6|f7|f8|f9|f10|f11|f12|spacer|", "|"+action+"|")
}
func layoutTextValid(value string, maximum int) bool {
	return utf8.ValidString(value) && utf8.RuneCountInString(value) <= maximum && !strings.ContainsRune(value, 0)
}
func validateCustomLayout(layout *customLayout, requireID bool) error {
	if layout.Format != "futo-layout" || layout.Version != 1 {
		return errors.New("This layout format or version is not supported")
	}
	layout.Name = strings.TrimSpace(layout.Name)
	if layout.Name == "" || !layoutTextValid(layout.Name, 80) || (requireID && !customLayoutID.MatchString(layout.ID)) || (layout.ID != "" && !customLayoutID.MatchString(layout.ID)) {
		return errors.New("The layout needs a valid name and identifier")
	}
	if len(layout.Pages) < 1 || len(layout.Pages) > 16 {
		return errors.New("A layout needs between 1 and 16 pages")
	}
	pages := map[string]bool{}
	count := 0
	for pi := range layout.Pages {
		page := &layout.Pages[pi]
		if !customPageID.MatchString(page.ID) || pages[page.ID] || strings.TrimSpace(page.Name) == "" || !layoutTextValid(page.Name, 48) {
			return errors.New("Each page needs a unique identifier and a name")
		}
		pages[page.ID] = true
		if page.Kind != "text" && page.Kind != "symbols" && page.Kind != "function" {
			return errors.New("Unknown page type")
		}
		if len(page.Rows) < 1 || len(page.Rows) > 12 {
			return errors.New("A page needs between 1 and 12 rows")
		}
		for ri := range page.Rows {
			row := page.Rows[ri]
			if len(row) < 1 || len(row) > 48 {
				return errors.New("A row needs between 1 and 48 keys")
			}
			count += len(row)
			for ki := range row {
				key := &page.Rows[ri][ki]
				if !customActionAllowed(key.Action) || !layoutTextValid(key.Label, 40) || !layoutTextValid(key.Output, 2048) || !layoutTextValid(key.Shifted, 2048) {
					return errors.New("Invalid key action or text")
				}
				if key.Style != "" && key.Style != "auto" && key.Style != "button" && key.Style != "plain" {
					return errors.New("Unknown key appearance")
				}
				if key.HoldAction != "" && (!customActionAllowed(key.HoldAction) || key.HoldAction == "text" || key.HoldAction == "spacer") {
					return errors.New("Invalid long-press action")
				}
				if !layoutTextValid(key.HoldTarget, 48) {
					return errors.New("Invalid long-press destination")
				}
				if math.IsNaN(key.Width) || math.IsInf(key.Width, 0) || key.Width < 0.25 || key.Width > 20 {
					return errors.New("Key width must be between 0.25 and 20")
				}
				if key.Action == "text" && key.Output == "" {
					return errors.New("A character key needs text to insert")
				}
				if key.Dead && (key.Action != "text" || utf8.RuneCountInString(key.Output) != 1) {
					return errors.New("A dead key must insert one character")
				}
				if len(key.More) > 32 || key.DefaultMore < 0 || key.DefaultMore >= len(key.More) && key.DefaultMore != 0 {
					return errors.New("Invalid long-press selection")
				}
				for _, raw := range key.More {
					if _, err := decodeCustomAlternative(raw); err != nil {
						return err
					}
				}
				if key.More == nil {
					key.More = []json.RawMessage{}
				}
				// Protection belongs to the position, not an editable key flag.
				if ri == len(page.Rows)-1 && ki == 0 {
					key.More = []json.RawMessage{}
					key.DefaultMore = 0
					key.HoldAction = ""
					key.HoldTarget = ""
				}
			}
		}
	}
	if count > 2048 {
		return errors.New("The layout has too many keys")
	}
	for _, page := range layout.Pages {
		for _, row := range page.Rows {
			for _, key := range row {
				if key.Action == "page" && !pages[key.Target] {
					return errors.New("A page-switch key refers to a missing page")
				}
				if key.HoldAction == "page" && !pages[key.HoldTarget] {
					return errors.New("A long-press action refers to a missing page")
				}
				for _, raw := range key.More {
					alternative, _ := decodeCustomAlternative(raw)
					if alternative.Action == "page" && !pages[alternative.Target] {
						return errors.New("A long-press action refers to a missing page")
					}
				}
			}
		}
	}
	return nil
}

type customLayoutAlternative struct {
	Action string  `json:"action"`
	Target string  `json:"target,omitempty"`
	Text   *string `json:"text,omitempty"`
	Label  *string `json:"label,omitempty"`
}

func decodeCustomAlternative(raw json.RawMessage) (customLayoutAlternative, error) {
	var text string
	if json.Unmarshal(raw, &text) == nil && text != "" && layoutTextValid(text, 2048) {
		return customLayoutAlternative{}, nil
	}
	var alternative customLayoutAlternative
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&alternative); err != nil {
		return alternative, errors.New("Invalid long-press choice")
	}
	var fields map[string]json.RawMessage
	if json.Unmarshal(raw, &fields) != nil || fields == nil {
		return alternative, errors.New("Invalid long-press choice")
	}
	for name, value := range fields {
		if bytes.Equal(value, []byte("null")) || alternative.Text != nil && name != "text" && name != "label" || alternative.Text == nil && name != "action" && name != "target" {
			return alternative, errors.New("Invalid long-press choice")
		}
	}
	if alternative.Text != nil && *alternative.Text != "" && layoutTextValid(*alternative.Text, 2048) &&
		(alternative.Label == nil || layoutTextValid(*alternative.Label, 40)) && alternative.Action == "" && alternative.Target == "" {
		return alternative, nil
	}
	if alternative.Text != nil || alternative.Label != nil || !customActionAllowed(alternative.Action) || alternative.Action == "text" || alternative.Action == "spacer" || !layoutTextValid(alternative.Target, 48) {
		return alternative, errors.New("Invalid long-press choice")
	}
	return alternative, nil
}
func decodeCustomLayout(data []byte) (customLayout, error) {
	var layout customLayout
	if len(data) > customLayoutLimit || !utf8.Valid(data) {
		return layout, errors.New("Layout file is too large or is not UTF-8 text")
	}
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&layout); err != nil {
		return layout, errors.New("This is not a valid FUTO layout file")
	}
	if err := decoder.Decode(new(interface{})); err != io.EOF {
		return layout, errors.New("Unexpected data after layout")
	}
	err := validateCustomLayout(&layout, false)
	return layout, err
}
func (service *service) customLayoutsPath() string {
	return filepath.Join(service.dataDirectory, "custom-layouts.json")
}
func (service *service) readCustomLayouts() (customLayoutCollection, error) {
	collection := customLayoutCollection{Version: 1, Layouts: []customLayout{}}
	info, err := os.Lstat(service.customLayoutsPath())
	if os.IsNotExist(err) {
		return collection, nil
	}
	if err != nil || !info.Mode().IsRegular() || info.Size() > customLayoutsLimit {
		return collection, errors.New("Could not read custom layouts")
	}
	data, err := os.ReadFile(service.customLayoutsPath())
	if err != nil {
		return collection, err
	}
	if json.Unmarshal(data, &collection) != nil || collection.Version != 1 || len(collection.Layouts) > 64 {
		return collection, errors.New("Custom layout storage is invalid")
	}
	seen := map[string]bool{}
	for i := range collection.Layouts {
		if err := validateCustomLayout(&collection.Layouts[i], true); err != nil {
			return collection, err
		}
		if seen[collection.Layouts[i].ID] {
			return collection, errors.New("Duplicate layout identifier")
		}
		seen[collection.Layouts[i].ID] = true
	}
	return collection, nil
}
func writeLayoutFile(path string, data []byte) error {
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return err
	}
	file, err := os.CreateTemp(filepath.Dir(path), ".layout-*")
	if err != nil {
		return err
	}
	defer os.Remove(file.Name())
	if _, err = file.Write(data); err == nil {
		err = file.Sync()
	}
	closeErr := file.Close()
	if err == nil {
		err = closeErr
	}
	if err != nil {
		return err
	}
	return os.Rename(file.Name(), path)
}
func (service *service) persistCustomLayouts(collection customLayoutCollection) (string, error) {
	data, err := json.Marshal(collection)
	if err != nil || len(data) > customLayoutsLimit {
		return "", errors.New("Custom layout storage is full")
	}
	previous, err := service.readCustomLayouts()
	if err != nil {
		return "", err
	}
	if err = writeLayoutFile(service.customLayoutsPath(), data); err != nil {
		return "", err
	}
	if err = customLayoutsWriteSetting(customLayoutsSetting, quoteDconfString(string(data))); err != nil {
		old, _ := json.Marshal(previous)
		_ = writeLayoutFile(service.customLayoutsPath(), old)
		return "", errors.New("Could not update keyboard layouts")
	}
	if service.bus != nil {
		_ = service.bus.Emit(objectPath, interfaceName+".CustomLayoutsChanged", string(data))
	}
	return string(data), nil
}
func (service *service) ListCustomLayouts() (string, *dbus.Error) {
	customLayoutsMutex.Lock()
	defer customLayoutsMutex.Unlock()
	collection, err := service.readCustomLayouts()
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	data, err := json.Marshal(collection)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return string(data), nil
}
func (service *service) SaveCustomLayout(document string) (string, *dbus.Error) {
	customLayoutsMutex.Lock()
	defer customLayoutsMutex.Unlock()
	layout, err := decodeCustomLayout([]byte(document))
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	collection, err := service.readCustomLayouts()
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	if layout.ID == "" {
		if len(collection.Layouts) >= 64 {
			return "", dbus.MakeFailedError(errors.New("Up to 64 custom layouts can be saved"))
		}
		var random [16]byte
		if _, err := rand.Read(random[:]); err != nil {
			return "", dbus.MakeFailedError(err)
		}
		layout.ID = "custom-" + hex.EncodeToString(random[:])
		collection.Layouts = append(collection.Layouts, layout)
	} else {
		found := false
		for i := range collection.Layouts {
			if collection.Layouts[i].ID == layout.ID {
				collection.Layouts[i] = layout
				found = true
				break
			}
		}
		if !found {
			return "", dbus.MakeFailedError(errors.New("This layout no longer exists; save a new copy"))
		}
	}
	result, err := service.persistCustomLayouts(collection)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return result, nil
}
func (service *service) DeleteCustomLayout(id string) (string, *dbus.Error) {
	customLayoutsMutex.Lock()
	defer customLayoutsMutex.Unlock()
	collection, err := service.readCustomLayouts()
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	index := -1
	for i := range collection.Layouts {
		if collection.Layouts[i].ID == id {
			index = i
			break
		}
	}
	if index < 0 {
		return "", dbus.MakeFailedError(errors.New("Layout not found"))
	}
	collection.Layouts = append(collection.Layouts[:index], collection.Layouts[index+1:]...)
	result, err := service.persistCustomLayouts(collection)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return result, nil
}
func customLayoutExportName(name string) string {
	name = strings.Map(func(r rune) rune {
		if unicode.IsControl(r) || strings.ContainsRune(`<>:"/\|?*`, r) {
			return '-'
		}
		return r
	}, name)
	for len(name) > 200 {
		_, size := utf8.DecodeLastRuneInString(name)
		name = name[:len(name)-size]
	}
	name = strings.Trim(name, " .-")
	if name == "" {
		return "Keyboard layout"
	}
	// Shared layouts should also have usable filenames on Windows.
	stem := strings.ToUpper(strings.SplitN(name, ".", 2)[0])
	if stem == "CON" || stem == "PRN" || stem == "AUX" || stem == "NUL" ||
		len(stem) == 4 && (strings.HasPrefix(stem, "COM") || strings.HasPrefix(stem, "LPT")) && stem[3] >= '1' && stem[3] <= '9' {
		name = "Keyboard " + name
	}
	return name
}
func createCustomLayoutExport(directory, name string) (*os.File, error) {
	base := customLayoutExportName(name)
	for copy := 1; copy <= 10000; copy++ {
		filename := base + ".futolayout"
		if copy > 1 {
			filename = fmt.Sprintf("%s_%d.futolayout", base, copy)
		}
		file, err := os.OpenFile(filepath.Join(directory, filename), os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
		if os.IsExist(err) {
			continue
		}
		return file, err
	}
	return nil, errors.New("Could not create a unique layout export filename")
}
func (service *service) ExportCustomLayout(id string) (string, *dbus.Error) {
	customLayoutsMutex.Lock()
	defer customLayoutsMutex.Unlock()
	collection, err := service.readCustomLayouts()
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	for _, layout := range collection.Layouts {
		if layout.ID == id {
			layout.ID = ""
			data, _ := json.MarshalIndent(layout, "", "  ")
			home, err := os.UserHomeDir()
			if err != nil {
				return "", dbus.MakeFailedError(err)
			}
			directory := filepath.Join(home, "Documents", "FUTO-Keyboard", "Layouts")
			if err := os.MkdirAll(directory, 0700); err != nil {
				return "", dbus.MakeFailedError(err)
			}
			file, err := createCustomLayoutExport(directory, layout.Name)
			if err != nil {
				return "", dbus.MakeFailedError(err)
			}
			path := file.Name()
			_, err = file.Write(data)
			if err == nil {
				err = file.Sync()
			}
			closeErr := file.Close()
			if err == nil {
				err = closeErr
			}
			if err != nil {
				_ = os.Remove(path)
				return "", dbus.MakeFailedError(err)
			}
			return path, nil
		}
	}
	return "", dbus.MakeFailedError(errors.New("Layout not found"))
}
func (service *service) ImportCustomLayout(path string) (string, *dbus.Error) {
	if !filepath.IsAbs(path) {
		selected, err := url.Parse(path)
		if err != nil || selected.Scheme != "file" || selected.Host != "" && selected.Host != "localhost" {
			return "", dbus.MakeFailedError(errors.New("Select a local layout file"))
		}
		path = selected.Path
	}
	if !filepath.IsAbs(path) || !strings.EqualFold(filepath.Ext(path), ".futolayout") {
		return "", dbus.MakeFailedError(errors.New("Select a .futolayout file"))
	}
	file, err := os.OpenFile(path, os.O_RDONLY|syscall.O_NONBLOCK|syscall.O_NOFOLLOW, 0)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil || !info.Mode().IsRegular() {
		return "", dbus.MakeFailedError(errors.New("Select a regular layout file"))
	}
	data, err := io.ReadAll(io.LimitReader(file, customLayoutLimit+1))
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	layout, err := decodeCustomLayout(data)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	layout.ID = "" // A shared file can never overwrite an installed layout.
	encoded, _ := json.Marshal(layout)
	return service.SaveCustomLayout(string(encoded))
}
func (service *service) OpenLayoutEditor() *dbus.Error {
	command := exec.Command("/usr/bin/invoker", "--type=silica-qt5", "--single-instance", "/usr/bin/futo-layout-editor")
	if err := command.Start(); err != nil {
		return dbus.MakeFailedError(errors.New("Could not open the layout editor"))
	}
	go command.Wait()
	return nil
}
