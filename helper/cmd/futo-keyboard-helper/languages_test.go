package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestEveryCatalogueLanguageNormalizes(t *testing.T) {
	seen := make(map[string]bool)
	files := make(map[string]bool)
	for _, language := range supportedLanguages {
		code, ok := normalizeLanguage(strings.ToLower(language.Code))
		if seen[language.Code] || !ok || code != language.Code {
			t.Fatalf("invalid or duplicate runtime locale: %s", language.Code)
		}
		seen[language.Code] = true
		files[language.File] = true
		if language.Name == "" || language.Name == language.Code {
			t.Fatalf("missing language name: %s", language.Code)
		}
	}
	if len(seen) != 73 || len(files) != 62 {
		t.Fatalf("registry has %d locales / %d dictionaries, want 73 / 62", len(seen), len(files))
	}
}

// Opt-in integration test: use real installed pack bytes through the helper's
// actual path resolution and worker protocol, one dictionary at a time.
func TestAllDownloadedDictionaryPredictions(t *testing.T) {
	directory := os.Getenv("FUTO_TEST_DICTIONARY_DIR")
	worker := os.Getenv("FUTO_TEST_DICTIONARY_ENGINE")
	if directory == "" || worker == "" {
		t.Skip("set FUTO_TEST_DICTIONARY_DIR and FUTO_TEST_DICTIONARY_ENGINE for real-pack validation")
	}
	for _, language := range supportedLanguages {
		t.Run(language.Code, func(t *testing.T) {
			root := t.TempDir()
			t.Setenv("FUTO_CONTENT_ROOT", root)
			if err := os.Mkdir(filepath.Join(root, "dictionaries"), 0700); err != nil {
				t.Fatal(err)
			}
			if err := os.Symlink(filepath.Join(directory, language.File), filepath.Join(root, "dictionaries", language.File)); err != nil {
				t.Fatal(err)
			}
			engine := engineProcess{executablePath: worker}
			defer engine.close()
			code, _ := normalizeLanguage(language.Code)
			words, err := engine.top(code, 3)
			if err != nil || len(words) == 0 {
				t.Fatalf("installed dictionary returned no predictions: %v / %v", words, err)
			}
			matches, err := engine.suggest(language.Code, words[0], 8)
			if err != nil || len(matches) == 0 {
				t.Fatalf("typed prediction failed: %v / %v", matches, err)
			}
			analysis, err := engine.analyze(language.Code, words[0], 8)
			if err != nil || !analysis.Known {
				t.Fatalf("downloaded dictionary word was not recognized: %s / %v", words[0], err)
			}
		})
	}
}
