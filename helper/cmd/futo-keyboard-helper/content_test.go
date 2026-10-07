package main

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"testing"
	"time"
)

type testRoundTripper func(*http.Request) (*http.Response, error)

func (transport testRoundTripper) RoundTrip(request *http.Request) (*http.Response, error) {
	return transport(request)
}

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

func TestContentManagerInstallsAndRemovesVerifiedRawFile(t *testing.T) {
	directory := t.TempDir()
	root := filepath.Join(directory, "content")
	downloads := filepath.Join(directory, "Downloads")
	localPacks := filepath.Join(downloads, "FUTO-Keyboard-content")
	if err := os.MkdirAll(localPacks, 0o700); err != nil {
		t.Fatal(err)
	}
	filename := "voice-input-test.bin"
	source := filepath.Join(localPacks, filename)
	payload := []byte("verified raw voice model")
	if err := os.WriteFile(source, payload, 0o600); err != nil {
		t.Fatal(err)
	}
	manifest := contentManifest{
		FormatVersion: 1, ContentVersion: "test-1",
		Items: []contentItem{{
			ID: "voice-test", Kind: "voice", Name: "Voice test", Version: "1",
			Archive: filename, RawFile: true, SHA256: testFileSHA256(t, source),
			DownloadBytes: int64(len(payload)), InstalledBytes: int64(len(payload)),
			Paths: []string{"voice/test.bin"},
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
	started, err := manager.startInstall("voice-test")
	if err != nil || !started {
		t.Fatalf("start raw install = %v, %v", started, err)
	}
	deadline := time.Now().Add(5 * time.Second)
	for {
		status := manager.status().Items[0]
		if status.State == "installed" {
			break
		}
		if status.State == "failed" {
			t.Fatalf("raw install failed: %s", status.Message)
		}
		if time.Now().After(deadline) {
			t.Fatal("raw content install timed out")
		}
		time.Sleep(10 * time.Millisecond)
	}
	installed, err := os.ReadFile(filepath.Join(root, "voice", "test.bin"))
	if err != nil || string(installed) != string(payload) {
		t.Fatalf("installed raw data = %q, %v", installed, err)
	}
	removed, err := manager.remove("voice-test")
	if err != nil || !removed {
		t.Fatalf("remove raw content = %v, %v", removed, err)
	}
}

func TestResolvedPredictionModelPathUsesInstalledModel(t *testing.T) {
	model := filepath.Join(t.TempDir(), "ml4_q6_k.gguf")
	if err := os.WriteFile(model, []byte("model"), 0o600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("FUTO_PREDICTION_MODEL", model)
	if got := resolvedPredictionModelPath(); got != model {
		t.Fatalf("prediction model path = %q, want %q", got, model)
	}
	if err := os.Remove(model); err != nil {
		t.Fatal(err)
	}
	if got := resolvedPredictionModelPath(); got != "" {
		t.Fatalf("missing prediction model resolved as %q", got)
	}
}

func TestContentManagerKeepsVerifiedRawFileAcrossManifestRevision(t *testing.T) {
	directory := t.TempDir()
	root := filepath.Join(directory, "content")
	voiceDirectory := filepath.Join(root, "voice")
	if err := os.MkdirAll(voiceDirectory, 0o700); err != nil {
		t.Fatal(err)
	}
	payload := []byte("existing verified voice model")
	modelPath := filepath.Join(voiceDirectory, "model.bin")
	if err := os.WriteFile(modelPath, payload, 0o600); err != nil {
		t.Fatal(err)
	}
	sum := sha256.Sum256(payload)
	item := contentItem{
		ID: "voice-test", Kind: "voice", Name: "Voice test", Version: "new",
		Archive: "voice-test.bin", RawFile: true,
		SHA256: hex.EncodeToString(sum[:]), DownloadBytes: int64(len(payload)),
		InstalledBytes: int64(len(payload)), Paths: []string{"voice/model.bin"},
	}
	manager := &contentManager{root: root}
	oldMarker := installedContentMarker{
		ID: "voice-test", Version: "old", SHA256: "old-archive-checksum",
		InstalledAt: time.Now().Add(-time.Hour).Unix(),
	}
	markerData, err := json.Marshal(oldMarker)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Dir(manager.markerPath(item.ID)), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(manager.markerPath(item.ID), markerData, 0o600); err != nil {
		t.Fatal(err)
	}
	if !manager.installed(item) {
		t.Fatal("verified raw content should remain installed across a manifest revision")
	}
	if got := manager.installedVersion(item.ID); got != item.Version {
		t.Fatalf("repaired marker version = %q, want %q", got, item.Version)
	}
}

func TestContentManagerRejectsChangedRawFileAcrossManifestRevision(t *testing.T) {
	directory := t.TempDir()
	root := filepath.Join(directory, "content")
	voiceDirectory := filepath.Join(root, "voice")
	if err := os.MkdirAll(voiceDirectory, 0o700); err != nil {
		t.Fatal(err)
	}
	payload := []byte("different voice model bytes")
	modelPath := filepath.Join(voiceDirectory, "model.bin")
	if err := os.WriteFile(modelPath, payload, 0o600); err != nil {
		t.Fatal(err)
	}
	expected := sha256.Sum256([]byte("expected voice model bytes"))
	item := contentItem{
		ID: "voice-test", Kind: "voice", Name: "Voice test", Version: "new",
		Archive: "voice-test.bin", RawFile: true,
		SHA256: hex.EncodeToString(expected[:]), DownloadBytes: int64(len(payload)),
		InstalledBytes: int64(len(payload)), Paths: []string{"voice/model.bin"},
	}
	manager := &contentManager{root: root}
	oldMarker := installedContentMarker{ID: "voice-test", Version: "old"}
	markerData, err := json.Marshal(oldMarker)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Dir(manager.markerPath(item.ID)), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(manager.markerPath(item.ID), markerData, 0o600); err != nil {
		t.Fatal(err)
	}
	if manager.installed(item) {
		t.Fatal("changed raw content must not be accepted as installed")
	}
}

func TestContentDownloadFallsBackAfterPrimaryFailure(t *testing.T) {
	t.Setenv("FUTO_CONTENT_BASE_URL", "")
	directory := t.TempDir()
	payload := []byte("fallback voice model")
	sum := sha256.Sum256(payload)
	item := contentItem{
		ID: "voice-test", Archive: "voice-test.bin", RawFile: true,
		DownloadURL: "https://primary.invalid/voice-test.bin",
		FallbackURL: "https://fallback.invalid/voice-test.bin",
		SHA256:      hex.EncodeToString(sum[:]), DownloadBytes: int64(len(payload)),
		InstalledBytes: int64(len(payload)), Paths: []string{"voice/test.bin"},
	}
	requests := make([]string, 0, 2)
	manager := &contentManager{
		root: directory,
		httpClient: &http.Client{Transport: testRoundTripper(func(request *http.Request) (*http.Response, error) {
			requests = append(requests, request.URL.Host)
			status := http.StatusNotFound
			body := []byte("missing")
			if request.URL.Host == "fallback.invalid" {
				status = http.StatusOK
				body = payload
			}
			return &http.Response{
				StatusCode: status,
				Body:       io.NopCloser(bytes.NewReader(body)),
				Header:     make(http.Header),
				Request:    request,
			}, nil
		})},
		jobs: map[string]*contentJob{"voice-test": {
			State: "downloading", TotalBytes: int64(len(payload)), Cancel: make(chan struct{}),
		}},
	}
	destination := filepath.Join(directory, "voice-test.part")
	if err := manager.obtainArchive(item, manager.jobs[item.ID], destination); err != nil {
		t.Fatal(err)
	}
	if len(requests) != 2 || requests[0] != "primary.invalid" || requests[1] != "fallback.invalid" {
		t.Fatalf("download requests = %#v", requests)
	}
	installed, err := os.ReadFile(destination)
	if err != nil || !bytes.Equal(installed, payload) {
		t.Fatalf("downloaded fallback = %q, %v", installed, err)
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
