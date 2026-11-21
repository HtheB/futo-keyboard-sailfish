package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestModelLettersFoldsFrenchAccents(t *testing.T) {
	cases := map[string]string{"été": "ete", "Déjà": "Deja", "cœur": "coeur", "reçu": "recu", "maïs": "mais"}
	for in, want := range cases {
		if got := modelLetters("FR", in); got != want {
			t.Errorf("modelLetters(FR, %q) = %q, want %q", in, got, want)
		}
	}
	if got := modelLetters("EN", "café"); got != "café" {
		t.Errorf("English input must be left alone, got %q", got)
	}
}

func TestPredictionModelForLanguage(t *testing.T) {
	root := t.TempDir()
	t.Setenv("FUTO_CONTENT_ROOT", root)
	if got := predictionModelFor("FR"); got != "" && filepath.Dir(got) == filepath.Join(root, "prediction") {
		t.Fatalf("no French model installed, got %q", got)
	}
	dir := filepath.Join(root, "prediction")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	fr := filepath.Join(dir, frenchPredictionModelFile)
	if err := os.WriteFile(fr, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	for _, language := range []string{"FR", "FR_CA", "FR_CH"} {
		if got := predictionModelFor(language); got != fr {
			t.Errorf("predictionModelFor(%s) = %q, want %q", language, got, fr)
		}
	}
	if got := predictionModelFor("DE"); got != "" {
		t.Errorf("German has no context model, got %q", got)
	}
}

// Needs the host-built worker and both models:
// FUTO_TEST_WORKER, FUTO_TEST_MODEL_EN, FUTO_TEST_MODEL_FR.
func TestPredictionProcessSwitchesModel(t *testing.T) {
	worker, en, fr := os.Getenv("FUTO_TEST_WORKER"), os.Getenv("FUTO_TEST_MODEL_EN"), os.Getenv("FUTO_TEST_MODEL_FR")
	if worker == "" || en == "" || fr == "" {
		t.Skip("worker or models not provided")
	}
	t.Setenv("FUTO_PREDICTION_ENGINE", worker)
	var engine predictionPool
	defer engine.close()
	first, err := engine.predict(en, "Thank you very", "", 1.0)
	if err != nil {
		t.Fatal(err)
	}
	second, err := engine.predict(fr, "Il a", "ete", 4.0)
	if err != nil {
		t.Fatal(err)
	}
	again, err := engine.predict(en, "Thank you very", "", 1.0)
	if err != nil {
		t.Fatal(err)
	}
	if len(engine.workers) != 2 {
		t.Fatalf("want one worker per model, got %d", len(engine.workers))
	}
	enWorker := engine.workers[en]
	if enWorker.command == nil || len(again.Suggestions) == 0 {
		t.Fatal("English worker should have stayed alive across the language change")
	}
	t.Logf("EN next: %+v", first.Suggestions)
	t.Logf("FR correction: %+v", second.Suggestions)
	found := false
	for _, s := range second.Suggestions {
		found = found || s.Word == "été"
	}
	if !found {
		t.Errorf("French model did not offer été: %+v", second.Suggestions)
	}
}

func TestPromoteModelWords(t *testing.T) {
	words := func(list ...string) []scoredWord {
		out := make([]scoredWord, len(list))
		for i, w := range list {
			out[i] = scoredWord{Word: w, Language: "FR"}
		}
		return out
	}
	model := []predictionModelSuggestion{{Word: "à"}, {Word: "pour"}, {Word: "avec"}}
	got := promoteModelWords(words("PT", "pur", "pour", "pire"), model, 6)
	if got[0].Word != "pour" || got[1].Word != "PT" || got[2].Word != "pur" || got[3].Word != "pire" {
		t.Fatalf("unexpected order %+v", got)
	}
	unchanged := promoteModelWords(words("maison", "raison"), model, 6)
	if unchanged[0].Word != "maison" {
		t.Fatalf("no model match must keep the gesture order, got %+v", unchanged)
	}
	far := promoteModelWords(words("a", "b", "c", "pour"), model, 3)
	if far[0].Word != "a" {
		t.Fatalf("a word outside the window must not move, got %+v", far)
	}
}

func TestPromoteModelWordsAddsMissingGestureWord(t *testing.T) {
	ranked := []scoredWord{{Word: "PT", Language: "FR"}, {Word: "pe", Language: "FR"}, {Word: "pur", Language: "FR"}}
	model := []predictionModelSuggestion{{Word: "pour"}, {Word: "par"}, {Word: "pas"}}
	got := promoteModelWords(ranked, model, 12)
	if got[0].Word != "pour" || len(got) != 4 {
		t.Fatalf("pour should be added first, got %+v", got)
	}
	ranked = []scoredWord{{Word: "PT", Language: "FR"}, {Word: "Pur", Language: "FR"}}
	got = promoteModelWords(ranked, model, 12)
	if got[0].Word != "Pour" {
		t.Fatalf("sentence-start capital expected, got %+v", got)
	}
	// "dans" ends with s, far from t: not a plausible reading of this gesture.
	ranked = []scoredWord{{Word: "PT", Language: "FR"}}
	got = promoteModelWords(ranked, []predictionModelSuggestion{{Word: "dans"}}, 12)
	if got[0].Word != "PT" || len(got) != 1 {
		t.Fatalf("unrelated word must not be added, got %+v", got)
	}
}

func TestNearKeyAzerty(t *testing.T) {
	for _, pair := range []string{"rt", "re", "rr", "ml", "wq", "cd", "nj"} {
		r := []rune(pair)
		if !nearKey(r[0], r[1]) {
			t.Errorf("%c and %c should be neighbours", r[0], r[1])
		}
	}
	for _, pair := range []string{"rs", "ap", "wm"} {
		r := []rune(pair)
		if nearKey(r[0], r[1]) {
			t.Errorf("%c and %c should not be neighbours", r[0], r[1])
		}
	}
}
