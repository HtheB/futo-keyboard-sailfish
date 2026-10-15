package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCompositionOptionsValidatedAndPorted(t *testing.T) {
	for scheme, schema := range doublePinyinSchemas {
		options, err := parseCompositionOptions(`{"pinyinScheme":"` + scheme + `","fuzzyPinyin":"Z_ZH,AN_ANG","outputScript":"Traditional"}`)
		if err != nil || options.simplified("ZH") || options.PinyinScheme != scheme {
			t.Fatalf("invalid option: %s %v", scheme, err)
		}
		profile := t.TempDir()
		if schema == "" {
			schema = "luna_pinyin"
		}
		if err := prepareRimeProfileOptions(profile, schema, false, true, options); err != nil {
			t.Fatal(err)
		}
		data, _ := os.ReadFile(filepath.Join(profile, schema+".custom.yaml"))
		if !strings.Contains(string(data), "translator/enable_user_dict: true") {
			t.Fatal("learning patch missing")
		}
		if schema == "luna_pinyin" && !strings.Contains(string(data), "derive/^zh/z/") {
			t.Fatal("upstream fuzzy derivation missing")
		}
	}
	for _, raw := range []string{`{"pinyinScheme":"../x"}`, `{"outputScript":"unknown"}`, `{"fuzzyPinyin":"Z_ZH\npatch:"}`} {
		if _, err := parseCompositionOptions(raw); err == nil {
			t.Fatal("unvalidated configuration accepted")
		}
	}
}

func TestCompositionLearningEncryptedAndPrivate(t *testing.T) {
	codec := &secureFileCodec{requireKeyWrite: true}
	if err := codec.setKey(bytes.Repeat([]byte{31}, 32)); err != nil {
		t.Fatal(err)
	}
	profile, err := conversionRuntimeDirectory()
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(profile)
	if err := os.WriteFile(filepath.Join(profile, "user_history.db"), []byte("private phrase 日本"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(profile, "build"), 0700); err != nil {
		t.Fatal(err)
	}
	_ = os.WriteFile(filepath.Join(profile, "build", "public.bin"), []byte("public dictionary"), 0600)
	path := filepath.Join(t.TempDir(), "mozc-history.enc")
	if err := saveConversionProfile(codec, path, profile); err != nil {
		t.Fatal(err)
	}
	raw, _ := os.ReadFile(path)
	if !bytes.HasPrefix(raw, encryptedFileMagic) || bytes.Contains(raw, []byte("private phrase")) {
		t.Fatal("plaintext learning stored")
	}
	second, err := conversionRuntimeDirectory()
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(second)
	if err := restoreConversionProfile(codec, path, second); err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(filepath.Join(second, "user_history.db"))
	if string(data) != "private phrase 日本" {
		t.Fatal("learning not restored")
	}
	if _, err := os.Stat(filepath.Join(second, "build")); !os.IsNotExist(err) {
		t.Fatal("public cache included in learning")
	}
	codec.clearKey()
	if err := saveConversionProfile(codec, path, profile); err == nil {
		t.Fatal("locked learning must never write plaintext")
	}
	unchanged, _ := os.ReadFile(path)
	if !bytes.Equal(raw, unchanged) {
		t.Fatal("locked storage replaced encrypted history")
	}
	for _, name := range []string{"..", "../escape", "/absolute", "safe/../../escape", "symlink\\escape"} {
		if conversionProfileFile(name) {
			t.Fatal("unsafe archive path")
		}
	}
}

func TestCompositionClearLearningDiscardsActiveProfileAndKeepsPublicData(t *testing.T) {
	root := t.TempDir()
	directory := filepath.Join(root, "composition")
	if err := os.MkdirAll(directory, 0700); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"mozc-history.enc", "rime-history.enc", "public-dictionary.bin"} {
		if err := os.WriteFile(filepath.Join(directory, name), []byte("test data"), 0600); err != nil {
			t.Fatal(err)
		}
	}
	profile, err := conversionRuntimeDirectory()
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(profile)
	session := compositionSession{private: profile, historyPath: filepath.Join(directory, "mozc-history.enc"), cleanExit: true}
	if err := session.clearLearning(root); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"mozc-history.enc", "rime-history.enc"} {
		if _, err := os.Stat(filepath.Join(directory, name)); !os.IsNotExist(err) {
			t.Fatal("conversion history survived clearing")
		}
	}
	if _, err := os.Stat(profile); !os.IsNotExist(err) {
		t.Fatal("active learning profile survived clearing")
	}
	if _, err := os.Stat(filepath.Join(directory, "public-dictionary.bin")); err != nil {
		t.Fatal("public dictionary removed", err)
	}
	if err := session.clearLearning(root); err != nil {
		t.Fatal("repeated clearing failed", err)
	}
}
