package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

// Opt-in network regression: exercise the production downloader and extractor
// against the published asset, without touching a user's installed content.
func TestPublishedSwipeDownloadAndInstall(t *testing.T) {
	if os.Getenv("FUTO_TEST_CONTENT_DOWNLOAD") != "1" {
		t.Skip("set FUTO_TEST_CONTENT_DOWNLOAD=1 to check the published download")
	}
	directory := t.TempDir()
	root := filepath.Join(directory, "content")
	manifest := filepath.Join("..", "..", "..", "content", "manifest.json")
	manager, err := newContentManager(root, manifest, filepath.Join(directory, "Downloads"))
	if err != nil {
		t.Fatal(err)
	}
	manager.httpClient.Timeout = 60 * time.Second
	item := manager.items["swipe-universal"]
	job := &contentJob{Cancel: make(chan struct{})}
	if err := manager.installContent(item, job); err != nil {
		t.Fatalf("published swipe install failed: %v", err)
	}
	if !manager.installed(item) || manager.installedVersion(item.ID) != item.Version {
		t.Fatal("published swipe pack was not marked installed")
	}
	for name, expected := range map[string]string{
		"honorable_sturgeon/model_fp32.pte": "725242bab5d14345e96ff214e8de2bfbc1f962c232d320df9c24cb82ffd1fbaf",
		"magic_macaw/model_fp32.pte":        "01eaf16ac4bc0f1ed0698c240807f0e95e6d427bcf6de04983ffc50736744d85",
		"hungry_jellyfish/context_lm.pte":   "74d29f56a513c0c60abcd43df3b16a6b68925cdf4e97e51b094a5275ec2810d7",
		"hungry_jellyfish/vocab.txt":        "a7db66376783b5a23ee3d4a2aaa8f2499fd9b35f975e92bcb248664c2cf6ebd1",
	} {
		if got := testFileSHA256(t, filepath.Join(root, "swipe", "models", filepath.FromSlash(name))); got != expected {
			t.Fatalf("published model changed: %s", name)
		}
	}
}
