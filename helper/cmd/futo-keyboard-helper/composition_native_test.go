package main

import (
	"os"
	"path/filepath"
	"strconv"
	"testing"
	"time"

	"github.com/godbus/dbus/v5"
)

// These tests exercise rebuilt upstream engines and actual FUTO conversion
// data. The ordinary unit suite uses a fixture process and never downloads.
func TestCompositionNative(t *testing.T) {
	workers := os.Getenv("FUTO_TEST_COMPOSITION_WORKERS")
	data := os.Getenv("FUTO_TEST_COMPOSITION_DATA")
	if workers == "" || data == "" {
		t.Skip("set FUTO_TEST_COMPOSITION_WORKERS and FUTO_TEST_COMPOSITION_DATA")
	}
	for _, scenario := range []struct {
		language, layout, input, expected string
	}{
		{"JA", "qwerty", "nihon", "日本"},
		{"JA", "qwerty", "toukyou", "東京"},
		{"JA", "12key", "j&/", "日本"},
		{"JA", "12key", "2[", "が"},
		{"JA", "12key", "6]", "ぱ"},
		{"JA", "12key", "|", "こ"},
		{"ZH", "qwerty", "nihao", "你好"},
		{"ZH", "qwerty", "hanyu", "汉语"},
		{"ZH_HANT", "qwerty", "hanyu", "漢語"},
		{"ZH", "stroke", "h", "一"},
		{"ZH", "stroke", "h", "会"},
		{"ZH_HANT", "stroke", "h", "會"},
	} {
		t.Run(scenario.language+"-"+scenario.input, func(t *testing.T) {
			session := &compositionSession{workerDir: workers, dataRoot: data}
			t.Cleanup(session.close)
			owner := dbus.Sender(":1.20")
			profile := t.TempDir()
			state, err := session.start(owner, scenario.language, scenario.layout, profile, true)
			if err != nil {
				t.Fatal(err)
			}
			update := func(operation, text string) compositionState {
				t.Helper()
				result, err := session.update(owner, state.Session, state.Revision, operation, text)
				if err != nil {
					t.Fatal(err)
				}
				state = result
				return result
			}
			for _, character := range scenario.input {
				if update("text", string(character)).Commit != "" {
					t.Fatal("input prematurely committed")
				}
			}
			if state.Preedit == "" {
				t.Fatal("missing composition")
			}
			id := ""
			for _, candidate := range state.Candidates {
				if candidate.Text == scenario.expected {
					id = strconv.Itoa(candidate.ID)
					break
				}
			}
			if id == "" {
				t.Fatalf("missing %s candidate in %v", scenario.expected, state.Candidates)
			}
			selected := update("select", id)
			if selected.Commit != scenario.expected || selected.Preedit != "" {
				t.Fatalf("selection: %+v", selected)
			}
			if update("reset", "").Commit != "" {
				t.Fatal("reset committed text")
			}
			update("text", "n")
			if update("key", "65288").Preedit != "" {
				t.Fatal("Backspace did not remove composition")
			}
			privatePath := session.private
			if !session.end(owner, state.Session) {
				t.Fatal("session did not close")
			}
			if _, err := os.Stat(filepath.Join(privatePath, "user.yaml")); !os.IsNotExist(err) {
				t.Fatal("private profile survived")
			}
			started := time.Now()
			warm, err := session.start(owner, scenario.language, scenario.layout, profile, true)
			if err != nil || warm.Preedit != "" || warm.Commit != "" {
				t.Fatalf("warm private session: %+v %v", warm, err)
			}
			if elapsed := time.Since(started); elapsed > 2*time.Second {
				t.Fatalf("repeated dictionary deployment: %v", elapsed)
			}
			t.Logf("warm start: %v", time.Since(started))
		})
	}
}
