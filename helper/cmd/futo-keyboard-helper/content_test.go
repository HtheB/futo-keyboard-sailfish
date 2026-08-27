package main

import (
	"archive/tar"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func writeTestContentArchive(t *testing.T, filename, name string, data []byte) {
	t.Helper()
	file, err := os.Create(filename)
	if err != nil {
		t.Fatal(err)
	}
	compressed := gzip.NewWriter(file)
	archive := tar.NewWriter(compressed)
	if err := archive.WriteHeader(&tar.Header{
		Name: name,
		Mode: 0o644,
		Size: int64(len(data)),
	}); err != nil {
		t.Fatal(err)
	}
	if _, err := archive.Write(data); err != nil {
		t.Fatal(err)
	}
	if err := archive.Close(); err != nil {
		t.Fatal(err)
	}
	if err := compressed.Close(); err != nil {
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}
}

func testFileSHA256(t *testing.T, filename string) string {
	t.Helper()
	data, err := os.ReadFile(filename)
	if err != nil {
		t.Fatal(err)
	}
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}

func TestContentManagerInstallsAndRemovesVerifiedLocalPack(t *testing.T) {
	directory := t.TempDir()
	root := filepath.Join(directory, "content")
	downloads := filepath.Join(directory, "Downloads")
	localPacks := filepath.Join(downloads, "FUTO-Keyboard-content")
	if err := os.MkdirAll(localPacks, 0o700); err != nil {
		t.Fatal(err)
	}
	archiveName := "futo-content-dictionary-test-1.tar.gz"
	archivePath := filepath.Join(localPacks, archiveName)
	payload := []byte("verified dictionary data")
	writeTestContentArchive(t, archivePath, "dictionaries/test.fksidx", payload)
	archiveInfo, err := os.Stat(archivePath)
	if err != nil {
		t.Fatal(err)
	}
	manifest := contentManifest{
		FormatVersion:  1,
		ContentVersion: "test-1",
		Items: []contentItem{{
			ID:             "dictionary-test",
			Kind:           "dictionary",
			Name:           "Test",
			Version:        "1",
			Archive:        archiveName,
			SHA256:         testFileSHA256(t, archivePath),
			DownloadBytes:  archiveInfo.Size(),
			InstalledBytes: int64(len(payload)),
			Paths:          []string{"dictionaries/test.fksidx"},
		}},
	}
	manifestPath := filepath.Join(directory, "manifest.json")
	manifestData, err := json.Marshal(manifest)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(manifestPath, manifestData, 0o600); err != nil {
		t.Fatal(err)
	}
	manager, err := newContentManager(root, manifestPath, downloads)
	if err != nil {
		t.Fatal(err)
	}
	started, err := manager.startInstall("dictionary-test")
	if err != nil || !started {
		t.Fatalf("start install = %v, %v", started, err)
	}
	deadline := time.Now().Add(5 * time.Second)
	for {
		status := manager.status().Items[0]
		if status.State == "installed" {
			break
		}
		if status.State == "failed" {
			t.Fatalf("install failed: %s", status.Message)
		}
		if time.Now().After(deadline) {
			t.Fatal("content install timed out")
		}
		time.Sleep(10 * time.Millisecond)
	}
	installed, err := os.ReadFile(filepath.Join(root, "dictionaries", "test.fksidx"))
	if err != nil || string(installed) != string(payload) {
		t.Fatalf("installed data = %q, %v", installed, err)
	}
	removed, err := manager.remove("dictionary-test")
	if err != nil || !removed {
		t.Fatalf("remove = %v, %v", removed, err)
	}
	if _, err := os.Stat(filepath.Join(root, "dictionaries", "test.fksidx")); !os.IsNotExist(err) {
		t.Fatalf("removed content still exists: %v", err)
	}
}

func TestContentManifestRejectsTraversal(t *testing.T) {
	directory := t.TempDir()
	manifest := contentManifest{
		FormatVersion: 1,
		Items: []contentItem{{
			ID:             "dictionary-test",
			Kind:           "dictionary",
			Name:           "Test",
			Version:        "1",
			Archive:        "test.tar.gz",
			SHA256:         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
			DownloadBytes:  1,
			InstalledBytes: 1,
			Paths:          []string{"../outside"},
		}},
	}
	data, err := json.Marshal(manifest)
	if err != nil {
		t.Fatal(err)
	}
	filename := filepath.Join(directory, "manifest.json")
	if err := os.WriteFile(filename, data, 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := loadContentManifest(filename); err == nil {
		t.Fatal("accepted traversal path")
	}
}
