package main

import (
	"archive/zip"
	"bytes"
	"errors"
	"os"
	"path/filepath"
	"testing"
)

type zipFixture struct {
	name, data string
	mode       os.FileMode
}

func writeZIPFixture(t *testing.T, entries []zipFixture) (string, []byte) {
	t.Helper()
	var data bytes.Buffer
	writer := zip.NewWriter(&data)
	for _, entry := range entries {
		header := &zip.FileHeader{Name: entry.name, Method: zip.Store}
		mode := entry.mode
		if mode == 0 {
			mode = 0600
		}
		header.SetMode(mode)
		file, err := writer.CreateHeader(header)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := file.Write([]byte(entry.data)); err != nil {
			t.Fatal(err)
		}
	}
	if err := writer.Close(); err != nil {
		t.Fatal(err)
	}
	filename := filepath.Join(t.TempDir(), "input.zip")
	if err := os.WriteFile(filename, data.Bytes(), 0600); err != nil {
		t.Fatal(err)
	}
	return filename, data.Bytes()
}

func TestContentZIPExtractionSafety(t *testing.T) {
	for _, scenario := range []struct {
		name    string
		entries []zipFixture
		size    int64
		good    bool
	}{
		{"valid", []zipFixture{{"schema.yaml", "abc", 0}, {"opencc/dict.txt", "de", 0}}, 5, true},
		{"traversal", []zipFixture{{"../escape", "x", 0}}, 1, false},
		{"absolute", []zipFixture{{"/escape", "x", 0}}, 1, false},
		{"backslash", []zipFixture{{`nested\escape`, "x", 0}}, 1, false},
		{"symlink", []zipFixture{{"escape", "../other", os.ModeSymlink | 0600}}, 8, false},
		{"duplicate", []zipFixture{{"same", "a", 0}, {"same", "b", 0}}, 2, false},
		{"expansion", []zipFixture{{"big", "abc", 0}}, 2, false},
		{"short", []zipFixture{{"short", "ab", 0}}, 3, false},
	} {
		t.Run(scenario.name, func(t *testing.T) {
			archive, _ := writeZIPFixture(t, scenario.entries)
			destination := filepath.Join(t.TempDir(), "installed")
			err := extractContentZIP(archive, destination, scenario.size, nil)
			if (err == nil) != scenario.good {
				t.Fatalf("extraction = %v", err)
			}
			if scenario.good {
				data, err := os.ReadFile(filepath.Join(destination, "opencc/dict.txt"))
				if err != nil || string(data) != "de" {
					t.Fatalf("data: %s, %v", data, err)
				}
			}
		})
	}
}

func TestContentZIPCRCAndCancellation(t *testing.T) {
	archive, data := writeZIPFixture(t, []zipFixture{{"schema.yaml", "unique-payload", 0}})
	cancelled := make(chan struct{})
	close(cancelled)
	if err := extractContentZIP(archive, t.TempDir(), 14, cancelled); err == nil {
		t.Fatal("cancelled extraction succeeded")
	}
	position := bytes.Index(data, []byte("unique-payload"))
	if position < 0 {
		t.Fatal("fixture payload missing")
	}
	data[position] ^= 1
	if err := os.WriteFile(archive, data, 0600); err != nil {
		t.Fatal(err)
	}
	if err := extractContentZIP(archive, t.TempDir(), 14, nil); err == nil {
		t.Fatal("corrupt ZIP accepted")
	}
}

func TestContentZIPVerifiedInstallationAndPreparationRollback(t *testing.T) {
	archive, _ := writeZIPFixture(t, []zipFixture{{"schema.yaml", "abc", 0}})
	root := t.TempDir()
	local := filepath.Join(t.TempDir(), "FUTO-Keyboard-content")
	if err := os.MkdirAll(local, 0700); err != nil {
		t.Fatal(err)
	}
	payload, _ := os.ReadFile(archive)
	if err := os.WriteFile(filepath.Join(local, "fixture.dict"), payload, 0600); err != nil {
		t.Fatal(err)
	}
	item := contentItem{ID: "composition-test", Kind: "composition", Version: "1",
		Archive: "fixture.dict", ArchiveFormat: "zip", SHA256: testFileSHA256(t, archive),
		DownloadBytes: int64(len(payload)), InstalledBytes: 3, Paths: []string{"composition/test"}}
	manager := &contentManager{root: root, downloadsDir: filepath.Dir(local),
		manifest: contentManifest{Items: []contentItem{item}},
		items:    map[string]contentItem{item.ID: item}, jobs: map[string]*contentJob{}}
	job := &contentJob{State: "installing", Cancel: make(chan struct{})}
	manager.jobs[item.ID] = job
	prepared := false
	manager.afterInstall = func(pack contentItem, cancel <-chan struct{}) error {
		if manager.status().Items[0].Installed {
			t.Fatal("unprepared conversion content was enabled")
		}
		data, err := os.ReadFile(filepath.Join(root, "composition/test/schema.yaml"))
		if err != nil || string(data) != "abc" {
			t.Fatal("preparation did not see verified data")
		}
		prepared = true
		return nil
	}
	if err := manager.installContent(item, job); err != nil {
		t.Fatal(err)
	}
	if !prepared || !manager.installed(item) {
		t.Fatal("pack was not installed/prepared")
	}
	oldPath := filepath.Join(root, "composition/test/schema.yaml")
	if err := os.WriteFile(oldPath, []byte("previous"), 0600); err != nil {
		t.Fatal(err)
	}
	manager.afterInstall = func(contentItem, <-chan struct{}) error { return errors.New("preparation failed") }
	if err := manager.installContent(item, job); err == nil {
		t.Fatal("preparation failure was ignored")
	}
	old, err := os.ReadFile(oldPath)
	if err != nil || string(old) != "previous" {
		t.Fatal("failed preparation overwrote existing data")
	}
}
