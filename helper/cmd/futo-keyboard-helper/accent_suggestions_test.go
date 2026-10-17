package main

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestAccentAlternativesSurvivePersonalCompletions(t *testing.T) {
	for _, pair := range [][2]string{
		{"e", "è"}, {"ou", "où"}, {"si", "sí"}, {"schon", "schön"},
		{"e", "é"}, {"een", "één"}, {"все", "всё"}, {"αλλα", "αλλά"},
	} {
		t.Run(pair[1], func(t *testing.T) {
			candidates := []scoredWord{
				{Word: pair[0], Score: 4000000240, SpellingMatch: true},
				{Word: pair[1], Score: 4000000180, SpellingMatch: true},
				{Word: "completion", Score: 3000000240},
			}
			got := mergeRankedSuggestions(pair[0], true,
				[]string{"personalone", "personaltwo", "personalthree"}, candidates, 3)
			want := []string{pair[0], pair[1], "personalone"}
			if !reflect.DeepEqual(got, want) {
				t.Fatalf("short-strip suggestions = %v, want %v", got, want)
			}
			// Accepted context can reorder both spellings, but must never
			// turn a valid word into an automatic correction.
			candidates[1].Score += 30000000
			got = mergeRankedSuggestions(pair[0], false, nil, candidates, 3)
			if got[0] != pair[1] {
				t.Fatalf("learned accent alternative did not move first: %v", got)
			}
			if correction := chooseContextCorrection(true, false, "", "",
				[]correctionWord{{Word: pair[1], Score: 240}}, pair[0], 2); correction != "" {
				t.Fatalf("valid unaccented word was automatically replaced: %q", correction)
			}
		})
	}
}

func TestAccentFamilyLeavesRoomForPersonalCompletions(t *testing.T) {
	got := mergeRankedSuggestions("e", true, []string{"example"}, []scoredWord{
		{Word: "e", Score: 4000000240, SpellingMatch: true},
		{Word: "è", Score: 4000000180, SpellingMatch: true},
		{Word: "é", Score: 4000000170, SpellingMatch: true},
		{Word: "ê", Score: 4000000100, SpellingMatch: true},
	}, 3)
	if want := []string{"e", "è", "example"}; !reflect.DeepEqual(got, want) {
		t.Fatalf("accent family crowded out learning: %v, want %v", got, want)
	}
}

// The opt-in integration test uses actual downloaded dictionaries, not a
// mocked candidate list. The regular engine test also checks both index formats.
func TestDownloadedDictionariesPreserveAndLearnAccentedWords(t *testing.T) {
	directory, worker := os.Getenv("FUTO_TEST_DICTIONARY_DIR"), os.Getenv("FUTO_TEST_DICTIONARY_ENGINE")
	if directory == "" || worker == "" {
		t.Skip("set FUTO_TEST_DICTIONARY_DIR and FUTO_TEST_DICTIONARY_ENGINE for real-pack validation")
	}
	var err error
	directory, err = filepath.Abs(directory)
	if err != nil {
		t.Fatal(err)
	}
	worker, err = filepath.Abs(worker)
	if err != nil {
		t.Fatal(err)
	}
	tests := []struct{ language, file, previous, plain, accented string }{
		{"IT", "it", "Oggi", "e", "è"},
		{"FR", "fr", "aller", "ou", "où"},
		{"ES", "es", "dijo", "si", "sí"},
		{"DE", "de", "wirklich", "schon", "schön"},
		{"PT_PT", "pt_PT", "hoje", "e", "é"},
		{"NL", "nl", "slechts", "een", "één"},
		{"RU", "ru", "это", "все", "всё"},
	}
	root := t.TempDir()
	t.Setenv("FUTO_CONTENT_ROOT", root)
	dictionaries := filepath.Join(root, "dictionaries")
	if err := os.Mkdir(dictionaries, 0700); err != nil {
		t.Fatal(err)
	}
	for _, test := range tests {
		name := test.file + ".fksidx"
		if err := os.Symlink(filepath.Join(directory, name), filepath.Join(dictionaries, name)); err != nil {
			t.Fatal(err)
		}
	}
	codec := &secureFileCodec{}
	svc := &service{engine: engineProcess{executablePath: worker},
		learned: newLearnedStore(filepath.Join(root, "learned.json"), codec),
		history: newHistoryStore(filepath.Join(root, "history.json"), codec)}
	defer svc.engine.close()
	for _, test := range tests {
		t.Run(test.language, func(t *testing.T) {
			for _, typed := range []bool{false, true} {
				result, err := svc.analyzeContext(test.language, test.plain, test.previous,
					3, 1, typed, false, false)
				if err != nil {
					t.Fatal(err)
				}
				if !containsAccentSuggestion(result.Suggestions, test.accented) || result.Correction != "" {
					t.Fatalf("accent alternative missing or valid word replaced: %+v", result)
				}
			}
			if ok, err := svc.AcceptContext(test.language, test.previous, test.accented,
				test.language); !ok || err != nil {
				t.Fatalf("accept accented word: %v / %v", ok, err)
			}
			for _, automatic := range []bool{false, true} {
				result, err := svc.analyzeContext(test.language, test.plain, test.previous,
					3, 1, false, automatic, false)
				if err != nil || len(result.Suggestions) == 0 ||
					result.Suggestions[0] != test.accented || result.Correction != "" {
					t.Fatalf("learned accent context (automatic=%v): %+v / %v", automatic, result, err)
				}
			}
			// Heavy learning of the plain spelling must not undo an accent
			// that the user explicitly typed.
			for i := 0; i < 25; i++ {
				if err := svc.history.accept(test.previous, test.plain, test.language); err != nil {
					t.Fatal(err)
				}
			}
			result, err := svc.analyzeContext(test.language, test.accented, test.previous,
				3, 1, false, false, false)
			if err != nil || len(result.Suggestions) == 0 || result.Suggestions[0] != test.accented {
				t.Fatalf("explicit accent lost: %+v / %v", result, err)
			}
		})
	}
}

func containsAccentSuggestion(words []string, expected string) bool {
	for _, word := range words {
		if word == expected {
			return true
		}
	}
	return false
}
