package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func languageIsolationService(t *testing.T) *service {
	t.Helper()
	root := t.TempDir()
	t.Setenv("FUTO_CONTENT_ROOT", root)
	dictionaries := filepath.Join(root, "dictionaries")
	if err := os.Mkdir(dictionaries, 0700); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"en_US.fksidx", "is.fksidx"} {
		if err := os.WriteFile(filepath.Join(dictionaries, name), []byte("fixture"), 0600); err != nil {
			t.Fatal(err)
		}
	}
	worker := filepath.Join(root, "dictionary-worker")
	script := `#!/bin/sh
while IFS="$(printf '\t')" read -r operation language limit word; do
    case "$language" in
        IS) candidate=íslenska ;;
        *) candidate=english ;;
    esac
    case "$operation" in
        TOP) printf 'OK\t["%s"]\n' "$candidate" ;;
        ANALYZE) printf 'OK\t{"known":false,"suggestions":[{"word":"%s","score":1}],"corrections":[],"phrases":[]}\n' "$candidate" ;;
        *) printf 'ERROR\tunexpected operation\n' ;;
    esac
done
`
	if err := os.WriteFile(worker, []byte(script), 0700); err != nil {
		t.Fatal(err)
	}
	codec := &secureFileCodec{}
	svc := &service{
		codec:   codec,
		engine:  engineProcess{executablePath: worker},
		learned: newLearnedStore(filepath.Join(root, "learned.json"), codec),
		history: newHistoryStore(filepath.Join(root, "history.json"), codec),
	}
	t.Cleanup(svc.engine.close)
	return svc
}

func acceptLanguageWord(t *testing.T, svc *service, language, previous, word string) {
	t.Helper()
	for i := 0; i < 2; i++ {
		if ok, err := svc.AcceptContext(language, previous, word, language); err != nil || !ok {
			t.Fatalf("accept %s word: %v / %v", language, ok, err)
		}
	}
}

func assertLanguageWords(t *testing.T, got string, expected []string) {
	t.Helper()
	var words []string
	if err := json.Unmarshal([]byte(got), &words); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(words, expected) {
		t.Fatalf("suggestions = %v, want %v", words, expected)
	}
}

func TestSeparateLanguagesFilterTypedAndNextWordSuggestions(t *testing.T) {
	svc := languageIsolationService(t)
	acceptLanguageWord(t, svc, "EN", "hello", "world")
	acceptLanguageWord(t, svc, "IS", "hello", "vinur")
	for _, automatic := range []bool{false, true} {
		result, err := svc.analyzeContext("IS", "wor", "hello", 4, 1, false, automatic, false)
		if err != nil || result.Language != "IS" || !reflect.DeepEqual(result.Suggestions, []string{"íslenska"}) {
			t.Fatalf("Icelandic typed suggestions (automatic=%v): %v / %v", automatic, result, err)
		}
	}
	for _, test := range []struct{ language, expected string }{{"IS", "vinur"}, {"EN", "world"}} {
		got, err := svc.NextWords(test.language, "hello", 1, false, false)
		if err != nil {
			t.Fatal(err)
		}
		assertLanguageWords(t, got, []string{test.expected})
	}
	combined, err := svc.NextWords("EN,IS", "hello", 2, false, false)
	if err != nil {
		t.Fatal(err)
	}
	assertLanguageWords(t, combined, []string{"vinur", "world"})
	if _, exists := svc.learned.snapshot()["MULTI"]; exists {
		t.Fatal("new automatically learned words were stored in the shared bucket")
	}
}

func TestLegacySharedWordsRespectRecordedLanguageWithoutDataLoss(t *testing.T) {
	svc := languageIsolationService(t)
	if err := svc.codec.setKey(testEncryptionKey()); err != nil {
		t.Fatal(err)
	}
	for _, test := range []struct{ language, word string }{{"EN", "world"}, {"IS", "vinur"}} {
		for i := 0; i < 3; i++ {
			if err := svc.learned.accept("MULTI", test.word); err != nil {
				t.Fatal(err)
			}
			if err := svc.history.accept("hello", test.word, test.language); err != nil {
				t.Fatal(err)
			}
		}
	}
	// A deliberately added, untagged word is not mistaken for English data.
	if err := svc.learned.addTrusted("worfuto"); err != nil {
		t.Fatal(err)
	}
	beforeWords, beforeHistory := svc.learned.snapshot(), svc.history.snapshot()
	svc.learned = newLearnedStore(svc.learned.path, svc.codec)
	svc.history = newHistoryStore(svc.history.path, svc.codec)
	allowShared := func(word string) bool { return svc.history.wordAllowedInLanguages(word, []string{"IS"}) }
	if got := svc.learned.matchesLanguages([]string{"IS"}, "wor", 1, allowShared); !reflect.DeepEqual(got, []string{"worfuto"}) {
		t.Fatalf("legacy foreign word displaced the allowed word: %v", got)
	}
	if svc.learned.containsLanguages([]string{"IS"}, "WORLD", allowShared) {
		t.Fatal("English legacy word prevented Icelandic autocorrection")
	}
	if !svc.learned.containsLanguages([]string{"IS"}, "VINUR", allowShared) {
		t.Fatal("Icelandic legacy word was lost")
	}
	got, err := svc.NextWords("IS", "hello", 1, false, false)
	if err != nil {
		t.Fatal(err)
	}
	assertLanguageWords(t, got, []string{"vinur"})
	if !reflect.DeepEqual(beforeWords, svc.learned.snapshot()) || !reflect.DeepEqual(beforeHistory, svc.history.snapshot()) {
		t.Fatal("language filtering changed existing learned data")
	}
}

func TestEveryPredictionLanguageKeepsItsOwnLearning(t *testing.T) {
	svc := languageIsolationService(t)
	probeWord := func(code string) string {
		return "probe" + strings.Map(func(r rune) rune {
			if r == '_' {
				return 'x'
			}
			if r >= '0' && r <= '9' {
				return 'a' + r - '0'
			}
			return r
		}, strings.ToLower(code))
	}
	for _, locale := range supportedLanguages {
		word := probeWord(locale.Code)
		acceptLanguageWord(t, svc, locale.Code, "seed", word)
	}
	for _, locale := range supportedLanguages {
		t.Run(locale.Code, func(t *testing.T) {
			word := probeWord(locale.Code)
			allowShared := func(candidate string) bool {
				return svc.history.wordAllowedInLanguages(candidate, []string{locale.Code})
			}
			if got := svc.learned.matchesLanguages([]string{locale.Code}, "probe", 4, allowShared); !reflect.DeepEqual(got, []string{word}) {
				t.Fatalf("personal suggestions = %v, want only %s", got, word)
			}
			got, err := svc.NextWords(locale.Code, "seed", 1, false, false)
			if err != nil {
				t.Fatal(err)
			}
			assertLanguageWords(t, got, []string{word})
		})
	}
}

func TestLearningUsesSelectedLanguageWhenDetectionIsStale(t *testing.T) {
	svc := languageIsolationService(t)
	if ok, err := svc.AcceptContext("IS", "hello", "vinur", "EN"); err != nil || !ok {
		t.Fatalf("accept selected language: %v / %v", ok, err)
	}
	if svc.learned.snapshot()["IS"]["vinur"] != 1 || svc.history.snapshot().LanguageWords["vinur"]["EN"] != 0 {
		t.Fatal("stale detected language overrode the selected language")
	}
}

// Opt-in integration test against the actual dictionary worker and pack bytes.
func TestDownloadedEnglishIcelandicLanguageIsolation(t *testing.T) {
	directory, worker := os.Getenv("FUTO_TEST_DICTIONARY_DIR"), os.Getenv("FUTO_TEST_DICTIONARY_ENGINE")
	if directory == "" || worker == "" {
		t.Skip("set FUTO_TEST_DICTIONARY_DIR and FUTO_TEST_DICTIONARY_ENGINE for real-pack validation")
	}
	var err error
	directory, err = filepath.Abs(directory)
	if err != nil {
		t.Fatal(err)
	}
	root := t.TempDir()
	t.Setenv("FUTO_CONTENT_ROOT", root)
	dictionaries := filepath.Join(root, "dictionaries")
	if err := os.Mkdir(dictionaries, 0700); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"en_US.fksidx", "is.fksidx"} {
		if err := os.Symlink(filepath.Join(directory, name), filepath.Join(dictionaries, name)); err != nil {
			t.Fatal(err)
		}
	}
	codec := &secureFileCodec{}
	svc := &service{engine: engineProcess{executablePath: worker},
		learned: newLearnedStore(filepath.Join(root, "learned.json"), codec),
		history: newHistoryStore(filepath.Join(root, "history.json"), codec)}
	defer svc.engine.close()
	const englishWord, icelandicWord = "englishonlylearnedtoken", "íslenskureynsluorð"
	acceptLanguageWord(t, svc, "EN", "sharedcontext", englishWord)
	acceptLanguageWord(t, svc, "IS", "sharedcontext", icelandicWord)
	for _, legacy := range []bool{false, true} {
		if legacy {
			if err := svc.learned.replace(map[string]map[string]int{"MULTI": {englishWord: 3, icelandicWord: 3}}); err != nil {
				t.Fatal(err)
			}
		}
		for _, automatic := range []bool{false, true} {
			result, err := svc.analyzeContext("IS", englishWord, "sharedcontext", 4, 1, false, automatic, false)
			if err != nil || result.Language != "IS" {
				t.Fatalf("Icelandic analysis failed: %v / %v", result, err)
			}
			for _, word := range result.Suggestions {
				if strings.EqualFold(word, englishWord) {
					t.Fatalf("English learning leaked through real Icelandic worker (legacy=%v): %v", legacy, result.Suggestions)
				}
			}
		}
		result, err := svc.analyzeContext("EN", englishWord, "sharedcontext", 4, 1, false, false, false)
		if err != nil || len(result.Suggestions) == 0 || result.Suggestions[0] != englishWord {
			t.Fatalf("English learning was not retained: %v / %v", result, err)
		}
		for _, test := range []struct{ language, expected string }{{"IS", icelandicWord}, {"EN", englishWord}} {
			got, err := svc.NextWords(test.language, "sharedcontext", 1, false, false)
			if err != nil {
				t.Fatal(err)
			}
			assertLanguageWords(t, got, []string{test.expected})
		}
	}
}
