package main

import (
	"bufio"
	"encoding/hex"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/godbus/dbus/v5"
)

func TestCompositionWorkerProcess(t *testing.T) {
	if os.Getenv("FUTO_TEST_COMPOSITION_WORKER") != "1" {
		return
	}
	state := compositionState{Consumed: true, Candidates: []compositionCandidate{}}
	encoder := json.NewEncoder(os.Stdout)
	_ = encoder.Encode(state)
	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		parts := strings.SplitN(scanner.Text(), "\t", 2)
		state.Commit = ""
		switch parts[0] {
		case "text":
			text, _ := hex.DecodeString(parts[1])
			if string(text) == "hang" {
				time.Sleep(time.Second)
			}
			if string(text) == "bad" {
				_, _ = os.Stdout.WriteString("{bad response}\n")
				continue
			}
			state.Preedit += string(text)
			state.Candidates = []compositionCandidate{{ID: -1, Text: "東京"}, {ID: 2, Text: "東亰"}}
		case "select", "commit":
			state.Commit = "東京"
			state.Preedit = ""
			state.Candidates = []compositionCandidate{}
		case "reset":
			state.Preedit = ""
			state.Candidates = []compositionCandidate{}
		}
		state.Cursor = len([]rune(state.Preedit))
		_ = encoder.Encode(state)
	}
	os.Exit(0)
}

func newTestComposition(t *testing.T) *compositionSession {
	t.Helper()
	root := t.TempDir()
	data := filepath.Join(root, "japanese")
	if err := os.MkdirAll(data, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(data, "mozc.data"), []byte("fixture"), 0600); err != nil {
		t.Fatal(err)
	}
	session := &compositionSession{dataRoot: root, timeout: 300 * time.Millisecond}
	session.commandFactory = func(_ string, _ ...string) *exec.Cmd {
		command := exec.Command(os.Args[0], "-test.run=^TestCompositionWorkerProcess$")
		command.Env = append(os.Environ(), "FUTO_TEST_COMPOSITION_WORKER=1")
		return command
	}
	t.Cleanup(session.close)
	return session
}

func TestCompositionSessionsRejectOldOwnerTokenAndRevision(t *testing.T) {
	session := newTestComposition(t)
	owner := dbus.Sender(":1.20")
	state, err := session.start(owner, "JA", "qwerty", t.TempDir(), false)
	if err != nil {
		t.Fatal(err)
	}
	for _, attempt := range []struct {
		owner    dbus.Sender
		token    string
		revision uint32
	}{
		{":1.21", state.Session, 0}, {owner, "old-token", 0}, {owner, state.Session, 1},
	} {
		if _, err := session.update(attempt.owner, attempt.token, attempt.revision, "text", "x"); err == nil {
			t.Fatal("stale session accepted")
		}
	}
	first, err := session.update(owner, state.Session, 0, "text", "とうきょう")
	if err != nil || first.Preedit != "とうきょう" || first.Cursor != 5 {
		t.Fatalf("Unicode preedit: %+v %v", first, err)
	}
	if _, err := session.update(owner, state.Session, 0, "text", "duplicate"); err == nil {
		t.Fatal("duplicate command accepted")
	}
	selected, err := session.update(owner, state.Session, 1, "select", "-1")
	if err != nil || selected.Commit != "東京" || selected.Preedit != "" {
		t.Fatalf("candidate id: %+v %v", selected, err)
	}
}

func TestCompositionRejectsUnavailableCandidatesAndProtocolInjection(t *testing.T) {
	session := newTestComposition(t)
	state, err := session.start(":1.20", "JA", "qwerty", t.TempDir(), false)
	if err != nil {
		t.Fatal(err)
	}
	for _, command := range []struct{ operation, value string }{
		{"select", "0"}, {"select", "not-a-number"}, {"key", "32\nreset"},
		{"text", "\x00"}, {"text", "\xff"}, {"unknown", ""},
	} {
		if _, err := session.update(":1.20", state.Session, 0, command.operation, command.value); err == nil {
			t.Fatalf("invalid command accepted: %s", command.operation)
		}
	}
	// Line breaks in text are encoded, never interpreted as extra commands.
	state, err = session.update(":1.20", state.Session, 0, "text", "a\nreset")
	if err != nil || state.Preedit != "a\nreset" {
		t.Fatalf("text quoting: %+v %v", state, err)
	}
}

func TestCompositionPrivateSessionAndSwitchCleanUp(t *testing.T) {
	session := newTestComposition(t)
	profile := t.TempDir()
	first, err := session.start(":1.20", "JA", "qwerty", profile, true)
	if err != nil {
		t.Fatal(err)
	}
	privateDir := session.private
	if privateDir == "" {
		t.Fatal("private profile not isolated")
	}
	if err := os.WriteFile(filepath.Join(privateDir, "history"), []byte("sensitive"), 0600); err != nil {
		t.Fatal(err)
	}
	second, err := session.start(":1.20", "JA", "qwerty", profile, false)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(privateDir); !os.IsNotExist(err) {
		t.Fatal("private history retained")
	}
	if _, err := session.update(":1.20", first.Session, 0, "text", "late"); err == nil {
		t.Fatal("old field result accepted")
	}
	if first.Session == second.Session {
		t.Fatal("session token reused")
	}
	session.close()
	if _, err := session.update(":1.20", second.Session, 0, "text", "late"); err == nil {
		t.Fatal("closed session accepted")
	}
}

func TestCompositionWorkerFailureClosesSession(t *testing.T) {
	for _, text := range []string{"bad", "hang"} {
		t.Run(text, func(t *testing.T) {
			session := newTestComposition(t)
			state, err := session.start(":1.20", "JA", "qwerty", t.TempDir(), false)
			if err != nil {
				t.Fatal(err)
			}
			if _, err := session.update(":1.20", state.Session, 0, "text", text); err == nil {
				t.Fatal("broken worker accepted")
			}
			if session.command != nil {
				t.Fatal("broken worker retained")
			}
		})
	}
}

func TestCompositionEngineLanguageMapping(t *testing.T) {
	for _, item := range []struct{ language, layout, engine, schema string }{
		{"JA", "qwerty", "mozc", "qwerty"}, {"JA", "12key", "mozc", "12key"},
		{"ZH", "qwerty", "rime", "luna_pinyin_simp"},
		{"ZH_HANT", "qwerty", "rime", "luna_pinyin"}, {"ZH", "stroke", "rime", "stroke"},
	} {
		engine, schema, err := compositionEngine(item.language, item.layout)
		if err != nil || engine != item.engine || schema != item.schema {
			t.Fatalf("wrong engine: %+v", item)
		}
	}
	for _, language := range []string{"EN", "NL", "IW", "KO", "JA;exec"} {
		if _, _, err := compositionEngine(language, "stroke"); err == nil {
			t.Fatalf("ordinary language reached conversion: %s", language)
		}
	}
	for _, layout := range []string{"stroke", "12key;exec", "../qwerty", ""} {
		if _, _, err := compositionEngine("JA", layout); err == nil {
			t.Fatalf("unrecognized Japanese layout accepted: %s", layout)
		}
	}
}

func TestCompositionJapaneseLayoutDispatch(t *testing.T) {
	for _, layout := range []string{"qwerty", "12key"} {
		session := newTestComposition(t)
		factory := session.commandFactory
		var arguments []string
		session.commandFactory = func(worker string, args ...string) *exec.Cmd {
			arguments = append([]string(nil), args...)
			return factory(worker, args...)
		}
		if _, err := session.start(":1.20", "JA", layout, t.TempDir(), true); err != nil {
			t.Fatal(err)
		}
		if len(arguments) != 4 || arguments[2] != "private" || arguments[3] != layout {
			t.Fatalf("Mozc did not receive its selected layout: %v", arguments)
		}
	}
}
