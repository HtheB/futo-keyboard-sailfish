package main

import (
	"encoding/json"
	"errors"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"unicode/utf8"
)

func layoutFixture() customLayout {
	return customLayout{Format: "futo-layout", Version: 1, Name: "My keyboard", Pages: []customLayoutPage{{ID: "main", Name: "ABC", Kind: "text", Rows: [][]customLayoutKey{{
		{Action: "text", Label: "è", Output: "è", Width: 1, More: []json.RawMessage{json.RawMessage(`"ë"`), json.RawMessage(`"ö"`)}},
		{Action: "backspace", Width: 2, More: []json.RawMessage{}},
		{Action: "backspace", Width: 0.5, More: []json.RawMessage{}},
	}}}}}
}
func TestCustomLayoutValidation(t *testing.T) {
	fixture := layoutFixture()
	if err := validateCustomLayout(&fixture, false); err != nil {
		t.Fatal(err)
	}
	if len(fixture.Pages[0].Rows[0][0].More) != 0 {
		t.Fatal("bottom-left Quick Settings must not be overridden")
	}
	tests := []struct {
		name   string
		change func(*customLayout)
	}{
		{"code action", func(l *customLayout) { l.Pages[0].Rows[0][1].Action = "exec" }},
		{"joined actions", func(l *customLayout) { l.Pages[0].Rows[0][1].Action = "text|space" }},
		{"missing page", func(l *customLayout) { l.Pages[0].Rows[0][1].Action = "page"; l.Pages[0].Rows[0][1].Target = "missing" }},
		{"empty rows", func(l *customLayout) { l.Pages[0].Rows = nil }},
		{"zero width", func(l *customLayout) { l.Pages[0].Rows[0][0].Width = 0 }},
		{"invalid appearance", func(l *customLayout) { l.Pages[0].Rows[0][0].Style = "script" }},
		{"bad identifier", func(l *customLayout) { l.ID = "../../path" }},
		{"dead action", func(l *customLayout) { l.Pages[0].Rows[0][1].Dead = true }},
		{"null text", func(l *customLayout) { l.Pages[0].Rows[0][0].Output = "\x00" }},
		{"new version", func(l *customLayout) { l.Version = 999 }},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			l := layoutFixture()
			test.change(&l)
			if validateCustomLayout(&l, false) == nil {
				t.Fatal("accepted invalid layout")
			}
		})
	}
	raw, _ := json.Marshal(layoutFixture())
	if _, err := decodeCustomLayout(append(raw, []byte(" {}")...)); err == nil {
		t.Fatal("accepted trailing JSON")
	}
	if _, err := decodeCustomLayout([]byte(strings.Replace(string(raw), `"version":1`, `"version":1,"language":"EN"`, 1))); err == nil {
		t.Fatal("accepted language binding")
	}
	if _, err := decodeCustomLayout([]byte(strings.Repeat(" ", customLayoutLimit+1))); err == nil {
		t.Fatal("accepted oversized file")
	}
}
func TestCustomLayoutAppearanceAndGaps(t *testing.T) {
	for _, style := range []string{"", "auto", "button", "plain"} {
		l := layoutFixture()
		l.Pages[0].Rows[0][0].Style = style
		l.Pages[0].Rows[0][1].Action = "spacer"
		raw, err := json.Marshal(l)
		if err != nil {
			t.Fatal(err)
		}
		decoded, err := decodeCustomLayout(raw)
		if err != nil {
			t.Fatal(style, err)
		}
		if decoded.Pages[0].Rows[0][0].Style != style || decoded.Pages[0].Rows[0][1].Action != "spacer" {
			t.Fatal("appearance or gap lost on round trip")
		}
	}
}

func TestCustomLayoutLongPressActions(t *testing.T) {
	for _, action := range []string{"emoji", "shift", "enter", "space", "backspace", "left", "ctrl", "f12", "page"} {
		layout := layoutFixture()
		key := &layout.Pages[0].Rows[0][1]
		key.HoldAction = action
		if action == "page" {
			key.HoldTarget = "main"
		}
		raw, _ := json.Marshal(layout)
		decoded, err := decodeCustomLayout(raw)
		if err != nil || decoded.Pages[0].Rows[0][1].HoldAction != action {
			t.Fatal(action, err)
		}
	}
	for _, action := range []string{"exec", "text", "spacer", "shift|emoji"} {
		layout := layoutFixture()
		layout.Pages[0].Rows[0][1].HoldAction = action
		if validateCustomLayout(&layout, false) == nil {
			t.Fatal("invalid long-press action accepted", action)
		}
	}
	layout := layoutFixture()
	layout.Pages[0].Rows[0][1].HoldAction = "page"
	layout.Pages[0].Rows[0][1].HoldTarget = "missing"
	if validateCustomLayout(&layout, false) == nil {
		t.Fatal("missing long-press page accepted")
	}
	layout = layoutFixture()
	layout.Pages[0].Rows[0][0].HoldAction = "emoji"
	if err := validateCustomLayout(&layout, false); err != nil {
		t.Fatal(err)
	}
	if layout.Pages[0].Rows[0][0].HoldAction != "" {
		t.Fatal("Quick Settings can be overridden")
	}
}
func TestCustomLayoutMixedAlternativesAndMacros(t *testing.T) {
	url := "https://example.test/" + strings.Repeat("long-path/", 100)
	macro, _ := json.Marshal(map[string]string{"text": url, "label": "Website"})
	layout := layoutFixture()
	key := &layout.Pages[0].Rows[0][1]
	key.Action = "text"
	key.Output = url
	key.Label = "Website"
	key.More = []json.RawMessage{json.RawMessage(`"www."`), macro, json.RawMessage(`{"action":"backspace"}`), json.RawMessage(`{"action":"page","target":"main"}`)}
	raw, _ := json.Marshal(layout)
	decoded, err := decodeCustomLayout(raw)
	if err != nil {
		t.Fatal(err)
	}
	got := decoded.Pages[0].Rows[0][1]
	if got.Output != url || len(got.More) != 4 || string(got.More[1]) != string(macro) {
		t.Fatal("macro or mixed choices lost")
	}
	for _, invalid := range []string{`{"text":"url","action":"enter"}`, `{"text":"url","target":"main"}`, `{"action":"exec"}`, `{"action":"page","target":"missing"}`, `{"text":""}`, `{"text":"url","label":null}`, `{"action":"enter","text":null}`, `{"text":"url","command":"run"}`} {
		copy := layoutFixture()
		copy.Pages[0].Rows[0][1].More = []json.RawMessage{json.RawMessage(invalid)}
		if validateCustomLayout(&copy, false) == nil {
			t.Fatal("accepted invalid choice", invalid)
		}
	}
	for _, size := range []int{2048, 2049} {
		value, _ := json.Marshal(strings.Repeat("😀", size))
		_, err := decodeCustomAlternative(value)
		if (err == nil) != (size == 2048) {
			t.Fatal("incorrect Unicode macro limit", size, err)
		}
	}
}
func TestCustomLayoutSaveImportAndRollback(t *testing.T) {
	original := customLayoutsWriteSetting
	customLayoutsWriteSetting = func(key, value string) error {
		if key != customLayoutsSetting {
			t.Fatal("wrong setting")
		}
		return nil
	}
	t.Cleanup(func() { customLayoutsWriteSetting = original })
	service := &service{dataDirectory: t.TempDir()}
	fixture := layoutFixture()
	raw, _ := json.Marshal(fixture)
	result, err := service.SaveCustomLayout(string(raw))
	if err != nil {
		t.Fatal(err)
	}
	var stored customLayoutCollection
	if json.Unmarshal([]byte(result), &stored) != nil || len(stored.Layouts) != 1 || !customLayoutID.MatchString(stored.Layouts[0].ID) {
		t.Fatal("missing stable ID")
	}
	before, _ := os.ReadFile(service.customLayoutsPath())
	customLayoutsWriteSetting = func(string, string) error { return errors.New("write failed") }
	fixture.ID = stored.Layouts[0].ID
	fixture.Name = "Changed"
	raw, _ = json.Marshal(fixture)
	if _, err := service.SaveCustomLayout(string(raw)); err == nil {
		t.Fatal("did not report mirror failure")
	}
	after, _ := os.ReadFile(service.customLayoutsPath())
	if string(before) != string(after) {
		t.Fatal("failed save damaged previous layouts")
	}
	customLayoutsWriteSetting = func(string, string) error { return nil }
	path := filepath.Join(t.TempDir(), "shared.futolayout")
	if err := os.WriteFile(path, raw, 0600); err != nil {
		t.Fatal(err)
	}
	imported, err := service.ImportCustomLayout("file://" + path)
	if err != nil {
		t.Fatal(err)
	}
	if json.Unmarshal([]byte(imported), &stored) != nil || len(stored.Layouts) != 2 || stored.Layouts[0].ID == stored.Layouts[1].ID {
		t.Fatal("import overwrote existing layout")
	}
	if _, err := service.ImportCustomLayout("https://example.test/layout.futolayout"); err == nil {
		t.Fatal("accepted network import")
	}
	link := filepath.Join(t.TempDir(), "link.futolayout")
	if err := os.Symlink(path, link); err != nil {
		t.Fatal(err)
	}
	if _, err := service.ImportCustomLayout(link); err == nil {
		t.Fatal("accepted symlink")
	}
	if _, err := service.DeleteCustomLayout(stored.Layouts[0].ID); err != nil {
		t.Fatal(err)
	}
	listed, err := service.ListCustomLayouts()
	if err != nil {
		t.Fatal(err)
	}
	if json.Unmarshal([]byte(listed), &stored) != nil || len(stored.Layouts) != 1 {
		t.Fatal("delete failed")
	}
	if info, _ := os.Stat(service.customLayoutsPath()); info.Mode().Perm() != 0600 {
		t.Fatal("layout file permissions")
	}
}

func TestCustomLayoutExportNames(t *testing.T) {
	for _, test := range []struct{ name, want string }{
		{"My QWERTY", "My QWERTY"},
		{"Français – العربية", "Français – العربية"},
		{"../../My/keyboard", "My-keyboard"},
		{"My\nkeyboard:*?", "My-keyboard"},
		{`My\keyboard`, "My-keyboard"},
		{" .. / ", "Keyboard layout"},
		{"CON", "Keyboard CON"},
		{"aux.layout", "Keyboard aux.layout"},
		{"COM1", "Keyboard COM1"},
		{"LPT9", "Keyboard LPT9"},
		{"COM10", "COM10"},
	} {
		if got := customLayoutExportName(test.name); got != test.want {
			t.Errorf("%q: got %q, want %q", test.name, got, test.want)
		}
	}
	if name := customLayoutExportName(strings.Repeat("界", 80)); len(name) > 200 || !utf8.ValidString(name) {
		t.Fatal("long Unicode name must fit the filename without splitting a character")
	}
}

func TestCustomLayoutExportPreservesExistingFiles(t *testing.T) {
	directory := t.TempDir()
	original := filepath.Join(directory, "My keyboard.futolayout")
	if err := os.WriteFile(original, []byte("Keep this file"), 0600); err != nil {
		t.Fatal(err)
	}
	link := filepath.Join(directory, "My keyboard_2.futolayout")
	if err := os.Symlink(original, link); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(filepath.Join(directory, "My keyboard_3.futolayout"), 0700); err != nil {
		t.Fatal(err)
	}
	file, err := createCustomLayoutExport(directory, "My keyboard")
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()
	if filepath.Base(file.Name()) != "My keyboard_4.futolayout" {
		t.Fatal("existing files, symlinks and directories must be skipped")
	}
	if data, err := os.ReadFile(original); err != nil || string(data) != "Keep this file" {
		t.Fatal("existing export was overwritten")
	}
	if info, err := os.Lstat(link); err != nil || info.Mode()&os.ModeSymlink == 0 {
		t.Fatal("existing symlink was replaced")
	}
}

func TestCustomLayoutExport(t *testing.T) {
	original := customLayoutsWriteSetting
	customLayoutsWriteSetting = func(string, string) error { return nil }
	t.Cleanup(func() { customLayoutsWriteSetting = original })
	home := t.TempDir()
	t.Setenv("HOME", home)
	service := &service{dataDirectory: t.TempDir()}
	fixture := layoutFixture()
	fixture.Name = "Français #1 100%"
	raw, _ := json.Marshal(fixture)
	saved, dbusErr := service.SaveCustomLayout(string(raw))
	if dbusErr != nil {
		t.Fatal(dbusErr)
	}
	var collection customLayoutCollection
	if err := json.Unmarshal([]byte(saved), &collection); err != nil {
		t.Fatal(err)
	}
	for _, filename := range []string{"Français #1 100%.futolayout", "Français #1 100%_2.futolayout"} {
		path, dbusErr := service.ExportCustomLayout(collection.Layouts[0].ID)
		if dbusErr != nil {
			t.Fatal(dbusErr)
		}
		if path != filepath.Join(home, "Documents", "FUTO-Keyboard", "Layouts", filename) {
			t.Fatalf("unexpected export path: %s", path)
		}
		data, err := os.ReadFile(path)
		if err != nil {
			t.Fatal(err)
		}
		layout, err := decodeCustomLayout(data)
		if err != nil || layout.ID != "" || layout.Name != fixture.Name {
			t.Fatal("export must keep the layout name and omit the installed ID")
		}
		if info, err := os.Stat(path); err != nil || info.Mode().Perm() != 0600 {
			t.Fatal("exports must have private permissions")
		}
		if _, dbusErr := service.ImportCustomLayout(path); dbusErr != nil {
			t.Fatal("export cannot be imported", dbusErr)
		}
		fileURL := (&url.URL{Scheme: "file", Path: path}).String()
		if _, dbusErr := service.ImportCustomLayout(fileURL); dbusErr != nil {
			t.Fatal("export URL cannot be imported", dbusErr)
		}
	}
}
