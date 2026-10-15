package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
	"testing"
)

func TestCompositionNativeJapaneseOptions(t *testing.T) {
	workers, data := os.Getenv("FUTO_TEST_COMPOSITION_WORKERS"), os.Getenv("FUTO_TEST_COMPOSITION_DATA")
	if workers == "" || data == "" {
		t.Skip("native workers required")
	}
	for _, scenario := range []struct {
		name, layout, input, expected string
		flick, half                   bool
	}{
		{"tap-cycle", "12key", "22", "き", false, false},
		{"flick-only", "12key", "22", "かか", true, false},
		{"latin-cycle", "12key-latin", "22", "b", false, false},
		{"full-space", "qwerty", "", "　", true, false},
		{"half-space", "qwerty", "", " ", true, true},
	} {
		t.Run(scenario.name, func(t *testing.T) {
			session := &compositionSession{workerDir: workers, dataRoot: data}
			t.Cleanup(session.close)
			options := compositionOptions{FlickOnly: scenario.flick, HalfWidthSpace: scenario.half, Correction: true}
			state, err := session.startOptions(":1.20", "JA", scenario.layout, t.TempDir(), true, options, true)
			if err != nil {
				t.Fatal(err)
			}
			for _, character := range scenario.input {
				state, err = session.update(":1.20", state.Session, state.Revision, "text", string(character))
				if err != nil {
					t.Fatal(err)
				}
			}
			if scenario.input != "" {
				if state.Preedit != scenario.expected {
					t.Fatalf("composition: %q expected %q", state.Preedit, scenario.expected)
				}
				state, err = session.update(":1.20", state.Session, state.Revision, "stop-toggle", "")
				if err != nil {
					t.Fatal(err)
				}
				state, err = session.update(":1.20", state.Session, state.Revision, "text", "2")
				expectedNext := scenario.expected + "か"
				if scenario.layout == "12key-latin" {
					expectedNext = scenario.expected + "a"
				}
				if err != nil || state.Preedit != expectedNext {
					t.Fatalf("cycle timeout: %q %v", state.Preedit, err)
				}
			} else {
				state, err = session.update(":1.20", state.Session, state.Revision, "key", "32")
				// Mozc passes a literal half-width Space back to the editor.
				literalSpace := scenario.half && !state.Consumed && state.Commit == "" && state.Preedit == ""
				if err != nil || state.Commit != scenario.expected && !literalSpace {
					t.Fatalf("space: %q expected %q (%v)", state.Commit, scenario.expected, err)
				}
			}
		})
	}
}

func TestCompositionNativeEncryptedLearning(t *testing.T) {
	workers, data := os.Getenv("FUTO_TEST_COMPOSITION_WORKERS"), os.Getenv("FUTO_TEST_COMPOSITION_DATA")
	if workers == "" || data == "" {
		t.Skip("native workers required")
	}
	for _, scenario := range []struct{ language, input, expected, engine string }{
		{"JA", "nihon", "日本", "mozc"}, {"ZH", "nihao", "你好", "rime"},
	} {
		t.Run(scenario.language, func(t *testing.T) {
			codec := &secureFileCodec{requireKeyWrite: true}
			if err := codec.setKey(bytes.Repeat([]byte{47}, 32)); err != nil {
				t.Fatal(err)
			}
			session := &compositionSession{workerDir: workers, dataRoot: data, codec: codec}
			t.Cleanup(session.close)
			profile := t.TempDir()
			options := compositionOptions{FlickOnly: true, PinyinScheme: "FullPinyin", OutputScript: "ByLanguage", Correction: true}
			state, err := session.startOptions(":1.20", scenario.language, "qwerty", profile, false, options, true)
			if err != nil {
				t.Fatal(err)
			}
			for _, character := range scenario.input {
				state, err = session.update(":1.20", state.Session, state.Revision, "text", string(character))
				if err != nil {
					t.Fatal(err)
				}
			}
			id := ""
			for _, item := range state.Candidates {
				if item.Text == scenario.expected {
					id = strconv.Itoa(item.ID)
					break
				}
			}
			if id == "" {
				t.Fatalf("missing conversion: %v", state.Candidates)
			}
			state, err = session.update(":1.20", state.Session, state.Revision, "select", id)
			if err != nil || state.Commit != scenario.expected {
				t.Fatalf("commit: %+v %v", state, err)
			}
			if scenario.language == "JA" && len(state.Candidates) == 0 {
				t.Fatal("missing native next-word suggestions after commit")
			}
			runtime := session.private
			session.close()
			if _, err := os.Stat(runtime); !os.IsNotExist(err) {
				t.Fatal("plaintext runtime survived session close")
			}
			history := filepath.Join(profile, "composition", scenario.engine+"-history.enc")
			raw, err := os.ReadFile(history)
			if err != nil || !bytes.HasPrefix(raw, encryptedFileMagic) {
				t.Fatalf("missing encrypted engine history: %v", err)
			}
			clear, err := codec.readFile(history)
			if err != nil {
				t.Fatal(err)
			}
			var files map[string][]byte
			if err := json.Unmarshal(clear, &files); err != nil || len(files) == 0 {
				t.Fatalf("no native learning files: %v", err)
			}
			zeroBytes(clear)
			state, err = session.startOptions(":1.20", scenario.language, "qwerty", profile, false, options, true)
			if err != nil || session.historyPath != history {
				t.Fatalf("normal history restore: %v", err)
			}
			for name := range files {
				// LevelDB rotates its numbered log files when it reopens.
				if scenario.engine == "rime" {
					name = filepath.Dir(name)
				}
				if _, err := os.Stat(filepath.Join(session.private, name)); err != nil {
					t.Fatalf("engine history not restored: %s %v", name, err)
				}
			}
			session.close()
			raw, _ = os.ReadFile(history)
			state, err = session.startOptions(":1.20", scenario.language, "qwerty", profile, true, options, true)
			if err != nil || session.historyPath != "" {
				t.Fatalf("private history isolation: %v", err)
			}
			session.close()
			unchanged, _ := os.ReadFile(history)
			if !bytes.Equal(raw, unchanged) {
				t.Fatal("Incognito changed encrypted learning")
			}
		})
	}
}

func TestCompositionNativeChineseOptions(t *testing.T) {
	workers, data := os.Getenv("FUTO_TEST_COMPOSITION_WORKERS"), os.Getenv("FUTO_TEST_COMPOSITION_DATA")
	if workers == "" || data == "" {
		t.Skip("native workers required")
	}
	for scheme := range doublePinyinSchemas {
		t.Run(scheme, func(t *testing.T) {
			session := &compositionSession{workerDir: workers, dataRoot: data}
			t.Cleanup(session.close)
			options := compositionOptions{PinyinScheme: scheme, OutputScript: "Simplified", Correction: true}
			state, err := session.startOptions(":1.20", "ZH_HANT", "qwerty", t.TempDir(), true, options, true)
			if err != nil {
				t.Fatal(err)
			}
			for _, character := range "ni" {
				state, err = session.update(":1.20", state.Session, state.Revision, "text", string(character))
				if err != nil {
					t.Fatal(err)
				}
			}
			found := false
			for _, item := range state.Candidates {
				if item.Text == "你" {
					found = true
				}
			}
			if !found {
				t.Fatalf("missing native ni conversion: %v", state.Candidates)
			}
			if state.HasMore {
				state, err = session.update(":1.20", state.Session, state.Revision, "more", strconv.Itoa(len(state.Candidates)))
				if err != nil || len(state.Candidates) <= 64 {
					t.Fatalf("candidate paging: %v %d", err, len(state.Candidates))
				}
			}
			state, err = session.update(":1.20", state.Session, state.Revision, "cursor", "1")
			if err != nil || state.Cursor != 1 {
				t.Fatalf("reading cursor: %+v %v", state, err)
			}
			state, err = session.update(":1.20", state.Session, state.Revision, "text", "x")
			if err != nil || state.Input != "nxi" {
				t.Fatalf("middle edit: %+v %v", state, err)
			}
		})
	}
}
