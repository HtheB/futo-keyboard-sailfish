package main

import (
	"bytes"
	"encoding/json"
	"net/url"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

func testEncryptionKey() []byte {
	return bytes.Repeat([]byte{0x5a}, 32)
}

func TestSecureFileCodecEncryptsAuthenticatesAndBindsFilename(t *testing.T) {
	directory := t.TempDir()
	path := filepath.Join(directory, "learned.json")
	codec := &secureFileCodec{}
	if err := codec.setKey(testEncryptionKey()); err != nil {
		t.Fatal(err)
	}
	want := map[string]int{"private": 3}
	if err := codec.writeJSON(path, want); err != nil {
		t.Fatal(err)
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.HasPrefix(raw, encryptedFileMagic) || bytes.Contains(raw, []byte("private")) {
		t.Fatal("encrypted store exposed plaintext")
	}
	var got map[string]int
	if err := codec.readJSON(path, &got); err != nil || !reflect.DeepEqual(got, want) {
		t.Fatalf("decrypt = %#v, %v", got, err)
	}

	tampered := append([]byte(nil), raw...)
	tampered[len(tampered)-1] ^= 0x01
	if err := os.WriteFile(path, tampered, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := codec.readJSON(path, &got); err == nil {
		t.Fatal("tampered encrypted data was accepted")
	}
	if err := os.WriteFile(path, raw, 0o600); err != nil {
		t.Fatal(err)
	}
	copyPath := filepath.Join(directory, "swapped.json")
	if err := os.WriteFile(copyPath, raw, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := codec.readJSON(copyPath, &got); err == nil {
		t.Fatal("encrypted data was accepted under a different filename")
	}
}

func TestLockedCodecCannotOverwriteEncryptedStore(t *testing.T) {
	path := filepath.Join(t.TempDir(), "protected.json")
	unlocked := &secureFileCodec{}
	if err := unlocked.setKey(testEncryptionKey()); err != nil {
		t.Fatal(err)
	}
	if err := unlocked.writeJSON(path, map[string]int{"kept": 1}); err != nil {
		t.Fatal(err)
	}
	before, _ := os.ReadFile(path)
	if err := (&secureFileCodec{}).writeJSON(path, map[string]int{}); err == nil {
		t.Fatal("locked codec overwrote encrypted data")
	}
	after, _ := os.ReadFile(path)
	if !bytes.Equal(before, after) {
		t.Fatal("locked write changed encrypted data")
	}
}

func TestCredentialMatchIndexIsEncryptedAndExact(t *testing.T) {
	path := filepath.Join(t.TempDir(), "password-vault-index.json")
	codec := &secureFileCodec{requireKeyWrite: true}
	if err := codec.setKey(testEncryptionKey()); err != nil {
		t.Fatal(err)
	}
	index := newCredentialMatchIndex(path, codec)
	entries := []credentialMetadata{
		{Origin: "https://example.com/login"},
		{Origin: "example.com/another-page"},
		{Origin: "https://other.example/"},
		{Origin: ""},
	}
	if err := index.replace(entries); err != nil {
		t.Fatal(err)
	}
	if got := index.count("https://example.com/account"); got != 2 {
		t.Fatalf("example.com match count = %d, want 2", got)
	}
	if got := index.count("https://unknown.example/"); got != 0 {
		t.Fatalf("unknown-site match count = %d, want 0", got)
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.HasPrefix(raw, encryptedFileMagic) || bytes.Contains(raw, []byte("example.com")) {
		t.Fatal("credential match index exposed saved sites")
	}
}

func TestCredentialOriginsSupportWebsitesAndApplications(t *testing.T) {
	tests := map[string]string{
		"example.com/login":                         "https://example.com",
		"HTTPS://Example.COM:8443/account":          "https://example.com:8443",
		"app://harbour-notes":                       "app://harbour-notes",
		"app://Com.Example.Login/.PasswordActivity": "app://com.example.login",
		"app://none":                                "",
		"app://transient window id":                 "",
		"file:///tmp/login":                         "",
	}
	for input, want := range tests {
		if got := normalizeCredentialOrigin(input); got != want {
			t.Errorf("normalizeCredentialOrigin(%q) = %q, want %q", input, got, want)
		}
	}
	if got := credentialDisplayOrigin("app://com.example.login"); got != "com.example.login" {
		t.Fatalf("credentialDisplayOrigin(app) = %q", got)
	}
}

func TestCredentialSearchMatchesMetadataAndPasswordWithoutExposingSecret(t *testing.T) {
	entry := credentialEntry{
		ID: "one", Label: "Smart Life", Origin: "app://com.tuya.smartlife",
		Username: "person@example.com", Password: "Unique-Coffee-Password",
	}
	for _, query := range []string{"smart", "TUYA", "person@", "coffee-password"} {
		if !credentialMatchesSearch(entry, query) {
			t.Errorf("credential search did not match %q", query)
		}
	}
	if credentialMatchesSearch(entry, "unrelated") {
		t.Fatal("credential search matched unrelated text")
	}
}

func TestInternalSettingsCredentialOriginsAreExcluded(t *testing.T) {
	for _, origin := range []string{
		"app://jolla-settings",
		"app://com.jolla.settings",
		"app://org.sailfishos.settings",
	} {
		if !internalCredentialOrigin(origin) {
			t.Errorf("internalCredentialOrigin(%q) = false", origin)
		}
	}
	for _, origin := range []string{
		"app://com.example.login",
		"https://example.com",
		"",
	} {
		if internalCredentialOrigin(origin) {
			t.Errorf("internalCredentialOrigin(%q) = true", origin)
		}
	}
}

func TestLearnedCodecNeverCreatesPlaintextWhileLocked(t *testing.T) {
	path := filepath.Join(t.TempDir(), "learned.json")
	codec := &secureFileCodec{requireKeyWrite: true}
	if err := codec.writeJSON(path, map[string]int{"private": 1}); err == nil {
		t.Fatal("locked learned codec created a plaintext store")
	}
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatalf("locked learned codec wrote a file: %v", err)
	}
}

func TestAuthenticatedPreparationEncryptsMixedLearnedStores(t *testing.T) {
	directory := t.TempDir()
	helperPath := filepath.Join(directory, "secrets-helper")
	if err := os.WriteFile(helperPath,
		[]byte("#!/bin/sh\nprintf 'ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ'\n"), 0o700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("FUTO_SECRETS_HELPER", helperPath)

	personalPath := filepath.Join(directory, "personal-dictionary.json")
	historyPath := filepath.Join(directory, "prediction-history.json")
	urlPath := filepath.Join(directory, "url-history.json")
	clipboardPath := filepath.Join(directory, "clipboard-history.json")
	personal := map[string]map[string]int{"EN": {"hello": 3}}
	urls := map[string]urlHistoryEntry{"tweakers.net": {
		Text: "tweakers.net", Count: 2, LastUsed: 123,
	}}
	personalJSON, _ := json.Marshal(personal)
	urlJSON, _ := json.Marshal(urls)
	if err := os.WriteFile(personalPath, personalJSON, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(urlPath, urlJSON, 0o600); err != nil {
		t.Fatal(err)
	}

	writer := &secureFileCodec{}
	if err := writer.setKey(testEncryptionKey()); err != nil {
		t.Fatal(err)
	}
	history := historyData{
		Bigrams:       map[string]map[string]int{"hello": {"world": 2}},
		LanguageWords: map[string]map[string]int{"EN": {"hello": 3}},
	}
	if err := writer.writeJSON(historyPath, history); err != nil {
		t.Fatal(err)
	}

	codec := &secureFileCodec{}
	service := &service{
		codec:     codec,
		learned:   newLearnedStore(personalPath, codec),
		history:   newHistoryStore(historyPath, codec),
		urls:      newURLHistoryStore(urlPath, codec),
		clipboard: newClipboardStore(clipboardPath, codec),
	}
	if err := service.activateLearnedEncryption("prepare", true); err != nil {
		t.Fatal(err)
	}
	for _, path := range service.learnedPaths() {
		if !encryptedPath(path) {
			t.Fatalf("store was not encrypted: %s", filepath.Base(path))
		}
	}
	if got := service.learned.snapshot(); !reflect.DeepEqual(got, personal) {
		t.Fatalf("personal words changed during migration: %#v", got)
	}
	if got := service.urls.snapshot(); !reflect.DeepEqual(got, urls) {
		t.Fatalf("URLs changed during migration: %#v", got)
	}
	if got := service.history.snapshot(); !reflect.DeepEqual(got, history) {
		t.Fatalf("prediction history changed during migration: %#v", got)
	}
}

func TestVaultMetadataAndSecretAreSeparated(t *testing.T) {
	path := filepath.Join(t.TempDir(), "vault.json")
	store := newVaultStore(path)
	if err := store.open(testEncryptionKey(), true); err != nil {
		t.Fatal(err)
	}
	if saved, err := store.upsert("Example", "example.com/login", "person@example.com",
		"synthetic-password"); err != nil || !saved {
		t.Fatalf("save = %v, %v", saved, err)
	}
	metadata, err := store.list()
	if err != nil || len(metadata) != 1 {
		t.Fatalf("metadata = %#v, %v", metadata, err)
	}
	encoded, _ := json.Marshal(metadata)
	if bytes.Contains(encoded, []byte("synthetic-password")) {
		t.Fatal("metadata exposed a password")
	}
	secret, err := store.secret(metadata[0].ID, "password")
	if err != nil || secret != "synthetic-password" {
		t.Fatalf("secret retrieval = %q, %v", secret, err)
	}
	store.lock()
	if _, err := store.secret(metadata[0].ID, "password"); err == nil {
		t.Fatal("locked vault returned a password")
	}
	if err := store.open(testEncryptionKey(), false); err != nil {
		t.Fatal(err)
	}
	metadata, err = store.list()
	if err != nil || len(metadata) != 1 {
		t.Fatalf("reopened metadata = %#v, %v", metadata, err)
	}
}

func TestVaultUpsertBackfillsSingleBlankOrigin(t *testing.T) {
	store := newVaultStore(filepath.Join(t.TempDir(), "vault.json"))
	if err := store.open(testEncryptionKey(), true); err != nil {
		t.Fatal(err)
	}
	if saved, err := store.upsert("Saved login", "", "person@example.com",
		"old-password"); err != nil || !saved {
		t.Fatalf("initial save = %v, %v", saved, err)
	}
	if saved, err := store.upsert("example.com", "https://example.com/login",
		"person@example.com", "new-password"); err != nil || !saved {
		t.Fatalf("backfill save = %v, %v", saved, err)
	}
	metadata, err := store.list()
	if err != nil || len(metadata) != 1 {
		t.Fatalf("metadata = %#v, %v", metadata, err)
	}
	if metadata[0].Origin != "https://example.com" {
		t.Fatalf("origin = %q", metadata[0].Origin)
	}
	secret, err := store.secret(metadata[0].ID, "password")
	if err != nil || secret != "new-password" {
		t.Fatalf("secret retrieval = %q, %v", secret, err)
	}
}

func TestVaultUpsertBackfillsSingleBlankUsername(t *testing.T) {
	store := newVaultStore(filepath.Join(t.TempDir(), "vault.json"))
	if err := store.open(testEncryptionKey(), true); err != nil {
		t.Fatal(err)
	}
	if saved, err := store.upsert("example.com", "https://example.com", "",
		"old-password"); err != nil || !saved {
		t.Fatalf("initial save = %v, %v", saved, err)
	}
	if saved, err := store.upsert("example.com", "https://example.com/login",
		"person@example.com", "new-password"); err != nil || !saved {
		t.Fatalf("username backfill = %v, %v", saved, err)
	}
	metadata, err := store.list()
	if err != nil || len(metadata) != 1 {
		t.Fatalf("metadata = %#v, %v", metadata, err)
	}
	if metadata[0].Username != "person@example.com" {
		t.Fatalf("username = %q", metadata[0].Username)
	}
}

func TestEmptyLegacyVaultMigratesToWrappedKey(t *testing.T) {
	directory := t.TempDir()
	vaultPath := filepath.Join(directory, "password-vault.json")
	legacyVault := newVaultStore(vaultPath)
	if err := legacyVault.open(bytes.Repeat([]byte{0x21}, 32), true); err != nil {
		t.Fatal(err)
	}
	legacyVault.lock()

	codec := &secureFileCodec{}
	if err := codec.setKey(testEncryptionKey()); err != nil {
		t.Fatal(err)
	}
	service := &service{
		codec:        codec,
		vault:        newVaultStore(vaultPath),
		vaultKeyPath: filepath.Join(directory, "password-vault-key.bin"),
	}
	migrated, err := service.migrateEmptyLegacyVault()
	if err != nil || !migrated {
		t.Fatalf("migration = %v, %v", migrated, err)
	}
	if _, err := os.Stat(vaultPath + ".legacy-empty"); err != nil {
		t.Fatalf("legacy backup: %v", err)
	}
	wrapped, err := os.ReadFile(service.vaultKeyPath)
	if err != nil || !bytes.HasPrefix(wrapped, encryptedFileMagic) {
		t.Fatalf("wrapped key was not encrypted: %v", err)
	}
	entries, err := service.vault.list()
	if err != nil || len(entries) != 0 {
		t.Fatalf("migrated entries = %#v, %v", entries, err)
	}

	service.vault.lock()
	opened, err := service.openVaultFromWrappedKey(false)
	if err != nil || !opened {
		t.Fatalf("wrapped reopen = %v, %v", opened, err)
	}
}

func TestPasswordCSVFormatDetectionAndImport(t *testing.T) {
	tests := []struct {
		name     string
		csv      string
		source   string
		imported int
		skipped  int
	}{
		{"firefox", "url,username,password,httpRealm\nhttps://example.com,a,first,\n",
			"Firefox", 1, 0},
		{"chromium", "name,url,username,password,note\nExample,https://example.org,b,second,\n",
			"Chromium browser", 1, 0},
		{"apple", "Title,URL,Username,Password,Notes,OTPAuth\nExample,https://apple.example,b2,second2,,\n",
			"Apple Passwords / Safari", 1, 0},
		{"onepassword", "Title,Website,Username,Password,One-time password,Favorite status,Archived status,Tags,Notes\nExample,https://one.example,c,third,,,,,\n",
			"1Password", 1, 0},
		{"bitwarden", "folder,favorite,type,name,notes,fields,reprompt,login_uri,login_username,login_password,login_totp\n,,login,Example,,,,https://bitwarden.example,d,fourth,\n,,note,Not a login,ignore me,,,,,,,\n",
			"Bitwarden", 1, 1},
		{"lastpass", "url,username,password,extra,name,grouping,fav\nhttps://lastpass.example,e,fifth,,Example,,0\n",
			"LastPass", 1, 0},
		{"keepassxc", "Group,Title,Username,Password,URL,Notes\nRoot,Example,f,sixth,https://keepass.example,\n",
			"KeePass / KeePassXC", 1, 0},
		{"dropbox", "title,website,login,password,notes,otpSecret\nExample,https://dropbox.example,g,seventh,,\n",
			"Dropbox Passwords", 1, 0},
		{"keeper", "Folder,Title,Login,Password,Website Address,Notes\n,Example,h,eighth,https://keeper.example,\n",
			"Keeper", 1, 0},
		{"dashlane", "username,username2,username3,title,password,note,url,category,otpSecret\ni,,,Example,ninth,,https://dashlane.example,,\n",
			"Dashlane", 1, 0},
		{"roboform", "Name,Url,MatchUrl,Login,Pwd,Note\nExample,https://roboform.example,,j,tenth,\n",
			"RoboForm", 1, 0},
		{"nordpass", "name,url,username,password,note,cardholdername,cardnumber,cvc,expirydate,zipcode,folder,full_name,phone_number,email,address1,address2,city,country,state,totp,shared_folder\nExample,https://nordpass.example,j2,tenth2,,,,,,,,,,,,,,,,,\n",
			"NordPass", 1, 0},
		{"protonpass", "name,url,email,username,password,note,totp,vault\nExample,https://proton.example,,j3,tenth3,,,Personal\n",
			"Proton Pass", 1, 0},
		{"generic", "item_name,login_url,email,login-password\nExample,https://generic.example,k,eleventh\n",
			"Generic password CSV", 1, 0},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			directory := t.TempDir()
			path := filepath.Join(directory, "passwords.csv")
			if err := os.WriteFile(path, []byte(test.csv), 0o600); err != nil {
				t.Fatal(err)
			}
			store := newVaultStore(filepath.Join(directory, "vault.json"))
			if err := store.open(testEncryptionKey(), true); err != nil {
				t.Fatal(err)
			}
			result, err := store.importCSV(path)
			if err != nil || result.Source != test.source ||
				result.Imported != test.imported || result.Skipped != test.skipped {
				t.Fatalf("import = %#v, %v", result, err)
			}
			metadata, err := store.list()
			if err != nil || len(metadata) != test.imported || metadata[0].Origin == "" {
				t.Fatalf("metadata = %#v, %v", metadata, err)
			}
		})
	}
}

func TestPasswordCSVRejectsAmbiguousOrUnsupportedHeaders(t *testing.T) {
	for _, csvData := range []string{
		"name,password\nExample,secret\n",
		"name,url,username,password,Password\nExample,https://example.com,a,b,c\n",
	} {
		directory := t.TempDir()
		path := filepath.Join(directory, "passwords.csv")
		if err := os.WriteFile(path, []byte(csvData), 0o600); err != nil {
			t.Fatal(err)
		}
		store := newVaultStore(filepath.Join(directory, "vault.json"))
		if err := store.open(testEncryptionKey(), true); err != nil {
			t.Fatal(err)
		}
		if _, err := store.importCSV(path); err == nil {
			t.Fatalf("unsupported CSV was accepted: %q", csvData)
		}
	}
}

func TestSelectedPasswordCSVPathAcceptsPickerURLAndRejectsOtherFiles(t *testing.T) {
	directory := t.TempDir()
	path := filepath.Join(directory, "Chrome Passwords.csv")
	if err := os.WriteFile(path, []byte("name,url,username,password\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	pickerURL := (&url.URL{Scheme: "file", Path: path}).String()
	got, err := selectedPasswordCSVPath(pickerURL)
	if err != nil || got != path {
		t.Fatalf("selected path = %q, %v; want %q", got, err, path)
	}
	textPath := filepath.Join(directory, "passwords.txt")
	if err := os.WriteFile(textPath, []byte("not a CSV"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := selectedPasswordCSVPath(textPath); err == nil {
		t.Fatal("non-CSV password file was accepted")
	}
}

func TestSelectedRenamedLearnedBackupImportsFromPickerPath(t *testing.T) {
	directory := t.TempDir()
	exportPath := filepath.Join(directory, "FUTO-Keyboard-backup.futo")
	selectedPath := filepath.Join(directory, "my-keyboard-backup.futo")
	codec := &secureFileCodec{requireKeyWrite: true}
	if err := codec.setKey(testEncryptionKey()); err != nil {
		t.Fatal(err)
	}
	backup := userBackup{
		Version: 1,
		Words:   map[string]map[string]int{"EN": {"sailfish": 3}},
		History: historyData{
			Bigrams: map[string]map[string]int{
				"hello": {"world": 2, "sailfish": 3},
			},
			LanguageWords: map[string]map[string]int{"EN": {"sailfish": 3}},
		},
		URLs: map[string]urlHistoryEntry{
			"example.com": {Text: "example.com", Count: 2, LastUsed: 100},
			"backup.test": {Text: "backup.test", Count: 4, LastUsed: 200},
		},
	}
	plain, err := json.Marshal(backup)
	if err != nil {
		t.Fatal(err)
	}
	encrypted, err := codec.encode(exportPath, plain)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(selectedPath, encrypted, 0o600); err != nil {
		t.Fatal(err)
	}
	pickerURL := (&url.URL{Scheme: "file", Path: selectedPath}).String()
	resolved, err := selectedLearnedBackupPath(pickerURL)
	if err != nil || resolved != selectedPath {
		t.Fatalf("selected backup = %q, %v; want %q", resolved, err, selectedPath)
	}
	service := &service{
		codec:           codec,
		learned:         newLearnedStore(filepath.Join(directory, "personal.json"), codec),
		history:         newHistoryStore(filepath.Join(directory, "history.json"), codec),
		urls:            newURLHistoryStore(filepath.Join(directory, "urls.json"), codec),
		backupDirectory: filepath.Join(directory, "Documents", "FUTO-Keyboard"),
		backupPath:      exportPath,
	}
	if err := service.learned.replace(map[string]map[string]int{
		"EN": {"phone": 7, "sailfish": 5},
	}); err != nil {
		t.Fatal(err)
	}
	if err := service.history.replace(historyData{
		Bigrams:       map[string]map[string]int{"hello": {"world": 8}},
		LanguageWords: map[string]map[string]int{"EN": {"phone": 7}},
		Suppressed:    map[string]bool{"forgotten": true},
	}); err != nil {
		t.Fatal(err)
	}
	if err := service.urls.replace(map[string]urlHistoryEntry{
		"example.com": {Text: "example.com", Count: 9, LastUsed: 300},
	}); err != nil {
		t.Fatal(err)
	}
	imported, err := service.importUserDataFromPath(resolved)
	if err != nil || !imported {
		t.Fatalf("renamed backup import = %v, %v", imported, err)
	}
	words := service.learned.snapshot()["EN"]
	if words["phone"] != 7 || words["sailfish"] != 5 {
		t.Fatalf("learned-word merge = %#v, expected current words and higher count", words)
	}
	history := service.history.snapshot()
	if history.Bigrams["hello"]["world"] != 8 ||
		history.Bigrams["hello"]["sailfish"] != 3 || !history.Suppressed["forgotten"] {
		t.Fatalf("history merge = %#v", history)
	}
	urls := service.urls.snapshot()
	if urls["example.com"].Count != 9 || urls["example.com"].LastUsed != 300 ||
		urls["backup.test"].Count != 4 {
		t.Fatalf("URL merge = %#v", urls)
	}

	plaintextPath := filepath.Join(directory, "plaintext.futo")
	if err := os.WriteFile(plaintextPath, plain, 0o600); err != nil {
		t.Fatal(err)
	}
	if imported, err := service.importUserDataFromPath(plaintextPath); err == nil || imported {
		t.Fatal("plaintext file with .futo extension was accepted")
	}
	textPath := filepath.Join(directory, "backup.txt")
	if err := os.WriteFile(textPath, encrypted, 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := selectedLearnedBackupPath(textPath); err == nil {
		t.Fatal("unsupported learned-data file extension was accepted")
	}

	timestamp := time.Date(2026, time.August, 27, 15, 4, 5, 0, time.Local)
	first, err := service.writeTimestampedLearnedBackup(plain, timestamp)
	if err != nil {
		t.Fatal(err)
	}
	second, err := service.writeTimestampedLearnedBackup(plain, timestamp)
	if err != nil {
		t.Fatal(err)
	}
	if filepath.Base(first) != "FUTO-Keyboard-backup-2026-08-27_15-04-05.futo" ||
		filepath.Base(second) != "FUTO-Keyboard-backup-2026-08-27_15-04-05-2.futo" {
		t.Fatalf("unique backup names = %q and %q", first, second)
	}
	if filepath.Dir(first) != service.backupDirectory || first == second {
		t.Fatalf("backup paths were not unique in the FUTO folder: %q, %q", first, second)
	}
	firstRaw, err := os.ReadFile(first)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := codec.decode(exportPath, firstRaw); err != nil {
		t.Fatalf("timestamped backup did not retain the stable encryption identity: %v", err)
	}
}

func TestValidWord(t *testing.T) {
	for _, word := range []string{"hello", "don't", "co-op", "Türkçe"} {
		if !validWord(word) {
			t.Fatalf("expected %q to be a valid word", word)
		}
	}
	for _, word := range []string{"", "two words", "line\nbreak", "hello!"} {
		if validWord(word) {
			t.Fatalf("expected %q to be rejected", word)
		}
	}
}

func TestLearnedStoreContainsCaseInsensitively(t *testing.T) {
	store := newLearnedStore(filepath.Join(t.TempDir(), "personal.json"), &secureFileCodec{})
	if err := store.accept("EN", "Sailfish"); err != nil {
		t.Fatal(err)
	}
	if store.contains("EN", "sailfish") {
		t.Fatal("one use should not yet make a personal word trusted")
	}
	if err := store.accept("EN", "Sailfish"); err != nil {
		t.Fatal(err)
	}
	if !store.contains("EN", "sailfish") {
		t.Fatal("accepted personal word was not found")
	}
	if store.contains("NL", "sailfish") {
		t.Fatal("personal word leaked across language dictionaries")
	}
}

func TestMergeSuggestionsKeepsTypedWordFirst(t *testing.T) {
	got := mergeSuggestions("helo", []string{"Helo", "hello"},
		[]string{"helo", "hello", "help"}, 4)
	want := []string{"helo", "Helo", "hello", "help"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("mergeSuggestions() = %#v, want %#v", got, want)
	}
}

func TestNormalizeLanguagesDeduplicatesAndFallsBack(t *testing.T) {
	got := normalizeLanguages("nl, EN,xx,nl,TR,de,FR")
	want := []string{"NL", "EN", "TR", "DE", "FR"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("normalizeLanguages() = %#v, want %#v", got, want)
	}
	if got := normalizeLanguages("invalid"); !reflect.DeepEqual(got, []string{"EN"}) {
		t.Fatalf("normalizeLanguages fallback = %#v", got)
	}
}

func TestDistinctiveLettersPreferTheirLanguage(t *testing.T) {
	if languageRuneBonus("TR", "ışık") <= languageRuneBonus("EN", "ışık") {
		t.Fatal("Turkish letters did not prefer Turkish")
	}
	if languageRuneBonus("PL", "żółty") <= languageRuneBonus("DE", "żółty") {
		t.Fatal("Polish letters did not prefer Polish")
	}
}

func TestCompoundPartsHandlesUnicodeApostrophe(t *testing.T) {
	prefix, suffix := compoundParts("l’école")
	if prefix != "l’" || suffix != "école" {
		t.Fatalf("compoundParts = %q, %q", prefix, suffix)
	}
}

func TestMatchTypedCase(t *testing.T) {
	tests := map[string]string{
		"hello|he":    "hello",
		"hello|He":    "Hello",
		"hello|HE":    "HELLO",
		"l’école|L’é": "L’école",
	}
	for input, want := range tests {
		parts := strings.SplitN(input, "|", 2)
		if got := matchTypedCase(parts[0], parts[1]); got != want {
			t.Fatalf("matchTypedCase(%q, %q) = %q, want %q",
				parts[0], parts[1], got, want)
		}
	}
}

func TestHistoryLearnsNextWordAndLanguage(t *testing.T) {
	store := newHistoryStore(filepath.Join(t.TempDir(), "history.json"), &secureFileCodec{})
	if err := store.accept("hello", "world", "EN"); err != nil {
		t.Fatal(err)
	}
	if err := store.accept("hello", "world", "EN"); err != nil {
		t.Fatal(err)
	}
	if err := store.accept("hello", "there", "EN"); err != nil {
		t.Fatal(err)
	}
	if got := store.next("hello", 2); !reflect.DeepEqual(got, []string{"world", "there"}) {
		t.Fatalf("next words = %#v", got)
	}
	if got := store.dominantLanguage("world", []string{"NL", "EN"}); got != "EN" {
		t.Fatalf("dominant language = %q", got)
	}
}

func TestHistoryRemoveWordForgetsEveryContext(t *testing.T) {
	store := newHistoryStore(filepath.Join(t.TempDir(), "history.json"), &secureFileCodec{})
	for _, previous := range []string{"hello", "goodbye"} {
		if err := store.accept(previous, "Sailfish", "EN"); err != nil {
			t.Fatal(err)
		}
	}
	if err := store.accept("Sailfish", "rocks", "EN"); err != nil {
		t.Fatal(err)
	}
	removed, err := store.removeWord("sailFISH")
	if err != nil || !removed {
		t.Fatalf("removeWord result = %v, %v", removed, err)
	}
	if got := store.next("hello", 4); len(got) != 0 {
		t.Fatalf("removed word remains as a next word: %#v", got)
	}
	if got := store.next("sailfish", 4); len(got) != 0 {
		t.Fatalf("removed word remains as a context key: %#v", got)
	}
	if got := store.dominantLanguage("sailfish", []string{"EN"}); got != "" {
		t.Fatalf("removed word retains language history: %q", got)
	}
}

func TestHistorySuppressWordPersistsDictionaryBlock(t *testing.T) {
	path := filepath.Join(t.TempDir(), "history.json")
	codec := &secureFileCodec{}
	store := newHistoryStore(path, codec)
	if err := store.accept("hello", "Sailfish", "EN"); err != nil {
		t.Fatal(err)
	}
	changed, err := store.suppressWord("sailFISH")
	if err != nil || !changed || !store.isSuppressed("Sailfish") {
		t.Fatalf("suppressWord result = %v, %v, suppressed=%v",
			changed, err, store.isSuppressed("Sailfish"))
	}
	reloaded := newHistoryStore(path, codec)
	if !reloaded.isSuppressed("SAILFISH") {
		t.Fatal("suppression did not survive reload")
	}
	if got := reloaded.next("hello", 4); len(got) != 0 {
		t.Fatalf("suppressed word remains in learned context: %#v", got)
	}
}

func TestPersonalDictionaryManagement(t *testing.T) {
	store := newLearnedStore(filepath.Join(t.TempDir(), "personal.json"), &secureFileCodec{})
	if err := store.addTrusted("Sailfish"); err != nil {
		t.Fatal(err)
	}
	words := store.list()
	if len(words) != 1 || words[0].Word != "Sailfish" || words[0].Count < 2 {
		t.Fatalf("personal words = %#v", words)
	}
	removed, err := store.removeWord("sailfish")
	if err != nil || !removed || len(store.list()) != 0 {
		t.Fatalf("remove result = %v, %v, %#v", removed, err, store.list())
	}
}

func TestChooseCorrectionUsesGlobalRunnerUp(t *testing.T) {
	candidates := []correctionWord{
		{Word: "the", Score: 190},
		{Word: "ten", Score: 180},
	}
	if got := chooseCorrection(candidates, "teh", 0); got != "" {
		t.Fatalf("ambiguous multilingual correction = %q, want empty", got)
	}
	if got := chooseCorrection(candidates[:1], "teh", 0); got != "the" {
		t.Fatalf("high-confidence correction = %q, want the", got)
	}
}

func TestMergeRankedSuggestionsDeduplicatesAcrossLanguages(t *testing.T) {
	candidates := []scoredWord{
		{Word: "Hello", Score: 200},
		{Word: "hello", Score: 190},
		{Word: "help", Score: 180},
	}
	got := mergeRankedSuggestions("hel", true, []string{"Helm"}, candidates, 4)
	want := []string{"hel", "Helm", "Hello", "help"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("mergeRankedSuggestions() = %#v, want %#v", got, want)
	}
}

func TestLegacyLayoutsMapToUnifiedFuto(t *testing.T) {
	for _, legacy := range []string{"futo_en.qml", "futo_nl.qml", "futo_tr.qml"} {
		if got := replaceLegacyLayout(legacy); got != "futo.qml" {
			t.Fatalf("replaceLegacyLayout(%q) = %q", legacy, got)
		}
	}
	if got := replaceLegacyLayout("en.qml"); got != "en.qml" {
		t.Fatalf("stock layout changed to %q", got)
	}
}

func TestHardwareDeadKeyVariantUsesAvailableXKBVariants(t *testing.T) {
	rules := []byte(`! layout
  us              English (US)
  de              German
! variant
  intl            us: English (US, intl., with dead keys)
  nodeadkeys      us: English (US, no dead keys)
  nodeadkeys      de: German (no dead keys)
! option
`)
	tests := []struct {
		layout  string
		enabled bool
		want    string
	}{
		{layout: "us", enabled: true, want: "intl"},
		{layout: "us", enabled: false, want: "nodeadkeys"},
		{layout: "de", enabled: true, want: ""},
		{layout: "de", enabled: false, want: "nodeadkeys"},
		{layout: "ar", enabled: true, want: ""},
	}
	for _, test := range tests {
		if got := deadKeyVariantFromRules(rules, test.layout, test.enabled); got != test.want {
			t.Fatalf("deadKeyVariantFromRules(%q, %v) = %q, want %q",
				test.layout, test.enabled, got, test.want)
		}
	}
}

func TestKeyboardModeSettingKeepsOrientationsSeparate(t *testing.T) {
	key, mode, err := keyboardModeSetting("portrait", 2)
	if err != nil || key != "/sailfish/text_input/futo_keyboard/portraitKeyboardMode" || mode != 2 {
		t.Fatalf("portrait setting = %q, %d, %v", key, mode, err)
	}
	key, mode, err = keyboardModeSetting("landscape", 9)
	if err != nil || key != "/sailfish/text_input/futo_keyboard/landscapeKeyboardMode" || mode != 3 {
		t.Fatalf("landscape setting = %q, %d, %v", key, mode, err)
	}
	if _, _, err := keyboardModeSetting("both", 1); err == nil {
		t.Fatal("accepted a shared orientation")
	}
}

func TestKeyboardModeSignalIsIntrospected(t *testing.T) {
	iface := helperIntrospectionInterface(&service{})
	if len(iface.Signals) != 2 {
		t.Fatalf("signal count = %d, want 2", len(iface.Signals))
	}
	signal := iface.Signals[0]
	if signal.Name != keyboardModeChangedSignal {
		t.Fatalf("signal name = %q, want %q", signal.Name,
			keyboardModeChangedSignal)
	}
	if len(signal.Args) != 2 || signal.Args[0].Type != "s" ||
		signal.Args[1].Type != "i" {
		t.Fatalf("signal arguments = %#v, want (s, i)", signal.Args)
	}
	contentSignal := iface.Signals[1]
	if contentSignal.Name != contentChangedSignal || len(contentSignal.Args) != 2 ||
		contentSignal.Args[0].Type != "s" || contentSignal.Args[1].Type != "s" {
		t.Fatalf("content signal = %#v, want ContentChanged(s, s)", contentSignal)
	}
}

func TestStoredKeyboardModeClampsAndDefaults(t *testing.T) {
	tests := map[string]int32{
		"0":       0,
		"2":       2,
		"3":       3,
		"9":       3,
		"-1":      0,
		"":        0,
		"invalid": 0,
	}
	for value, want := range tests {
		if got := storedKeyboardMode(value); got != want {
			t.Fatalf("storedKeyboardMode(%q) = %d, want %d", value, got, want)
		}
	}
}

func TestPreferredActiveLayoutRepairsMissingKeyboard(t *testing.T) {
	enabled := parseEnabledLayouts("['nl.qml', 'futo.qml', 'futo_en.qml']")
	wantEnabled := []string{"nl.qml", "futo.qml"}
	if !reflect.DeepEqual(enabled, wantEnabled) {
		t.Fatalf("parseEnabledLayouts() = %#v, want %#v", enabled, wantEnabled)
	}
	if got := preferredActiveLayout(enabled, "en.qml"); got != "futo.qml" {
		t.Fatalf("invalid active layout repaired to %q, want futo.qml", got)
	}
	if got := preferredActiveLayout(enabled, "nl.qml"); got != "nl.qml" {
		t.Fatalf("valid active layout changed to %q", got)
	}
	if got := preferredActiveLayout([]string{"nl.qml"}, "en.qml"); got != "nl.qml" {
		t.Fatalf("stock fallback = %q, want nl.qml", got)
	}
	if got := preferredPreviousLayout(enabled, "futo.qml", "en.qml"); got != "nl.qml" {
		t.Fatalf("invalid previous layout repaired to %q, want nl.qml", got)
	}
	if got := preferredPreviousLayout(enabled, "nl.qml", "futo.qml"); got != "futo.qml" {
		t.Fatalf("valid previous layout changed to %q", got)
	}
}

func TestClipboardHistoryPinsDeduplicatesAndPersists(t *testing.T) {
	path := filepath.Join(t.TempDir(), "clipboard.json")
	store := newClipboardStore(path, &secureFileCodec{})
	if recorded, err := store.record("first", 3600); err != nil || !recorded {
		t.Fatalf("record first: recorded=%v err=%v", recorded, err)
	}
	if recorded, err := store.record("first", 3600); err != nil || !recorded {
		t.Fatalf("refresh first: recorded=%v err=%v", recorded, err)
	}
	entries, err := store.list()
	if err != nil || len(entries) != 1 {
		t.Fatalf("deduplicated list: len=%d err=%v", len(entries), err)
	}
	if changed, err := store.setPinned(entries[0].ID, true, 3600); err != nil || !changed {
		t.Fatalf("pin: changed=%v err=%v", changed, err)
	}
	reloaded := newClipboardStore(path, &secureFileCodec{})
	entries, err = reloaded.list()
	if err != nil || len(entries) != 1 || !entries[0].Pinned || entries[0].Text != "first" {
		t.Fatalf("reloaded pinned entry: %#v err=%v", entries, err)
	}
	if recorded, err := reloaded.record("first", 3600); err != nil || recorded {
		t.Fatalf("pinned duplicate should be ignored: recorded=%v err=%v", recorded, err)
	}
}

func TestClipboardHistoryRejectsBlankAndClears(t *testing.T) {
	store := newClipboardStore(filepath.Join(t.TempDir(), "clipboard.json"), &secureFileCodec{})
	if recorded, err := store.record("  \n", 3600); err != nil || recorded {
		t.Fatalf("blank record: recorded=%v err=%v", recorded, err)
	}
	_, _ = store.record("kept", 3600)
	if err := store.clear(); err != nil {
		t.Fatal(err)
	}
	entries, err := store.list()
	if err != nil || len(entries) != 0 {
		t.Fatalf("clear list: len=%d err=%v", len(entries), err)
	}
}

func TestURLHistorySuggestsAfterFirstUseAndPersists(t *testing.T) {
	path := filepath.Join(t.TempDir(), "urls.json")
	store := newURLHistoryStore(path, &secureFileCodec{})
	recorded, err := store.accept("https://example.com/docs")
	if err != nil || !recorded {
		t.Fatalf("accept: recorded=%v err=%v", recorded, err)
	}
	got := newURLHistoryStore(path, &secureFileCodec{}).suggest("https://exa", 8)
	if !reflect.DeepEqual(got, []string{"example.com"}) {
		t.Fatalf("persisted suggestions = %#v", got)
	}
	for _, prefix := range []string{"exa", "www.exa", "https://exa"} {
		got = newURLHistoryStore(path, &secureFileCodec{}).suggest(prefix, 8)
		if !reflect.DeepEqual(got, []string{"example.com"}) {
			t.Fatalf("suggestions for %q = %#v", prefix, got)
		}
	}
	if entries := store.list(); len(entries) != 1 || entries[0].Text != got[0] {
		t.Fatalf("listed entries = %#v", entries)
	}
	if removed, err := store.remove(got[0]); err != nil || !removed {
		t.Fatalf("remove: removed=%v err=%v", removed, err)
	}
	if got := store.suggest("", 8); len(got) != 0 {
		t.Fatalf("suggested removed URL: %#v", got)
	}
}

func TestURLHistoryMergesPagePathsIntoOneSite(t *testing.T) {
	path := filepath.Join(t.TempDir(), "urls.json")
	store := newURLHistoryStore(path, &secureFileCodec{})
	for _, value := range []string{
		"https://Example.com/first/page?query=yes#section",
		"example.com/second/page",
		"http://example.com/third",
	} {
		if recorded, err := store.accept(value); err != nil || !recorded {
			t.Fatalf("accept %q: recorded=%v err=%v", value, recorded, err)
		}
	}
	entries := store.list()
	if len(entries) != 1 || entries[0].Text != "example.com" || entries[0].Count != 3 {
		t.Fatalf("site-normalized entries = %#v", entries)
	}
	if got := newURLHistoryStore(path, &secureFileCodec{}).suggest("exa", 8); !reflect.DeepEqual(got, []string{"example.com"}) {
		t.Fatalf("site-normalized suggestions = %#v", got)
	}
}

func TestURLHistoryRejectsCredentialsWhitespaceAndNonURLs(t *testing.T) {
	store := newURLHistoryStore(filepath.Join(t.TempDir(), "urls.json"), &secureFileCodec{})
	for _, value := range []string{"not-a-url", "https://user:secret@example.com/",
		"https://example.com/has space"} {
		if recorded, err := store.accept(value); err != nil || recorded {
			t.Fatalf("accepted unsafe URL %q: recorded=%v err=%v", value, recorded, err)
		}
	}
}

func TestKeySoundPathWhitelistsKindAndClampsVolume(t *testing.T) {
	tests := []struct {
		kind   string
		volume int32
		want   string
	}{
		{kind: "letter", volume: 1, want: "keyboard_letter-10.wav"},
		{kind: "option", volume: 64, want: "keyboard_option-60.wav"},
		{kind: "enter", volume: 99, want: "pulldown_highlight-100.wav"},
	}
	for _, test := range tests {
		path, ok := keySoundPath(test.kind, test.volume)
		if !ok || filepath.Base(path) != test.want {
			t.Fatalf("keySoundPath(%q, %d) = %q, %v; want %q, true",
				test.kind, test.volume, path, ok, test.want)
		}
	}
	if path, ok := keySoundPath("../../escape", 50); ok || path != "" {
		t.Fatalf("invalid sound kind accepted: %q, %v", path, ok)
	}
}

func TestChoosePulseAudioOutputSinkAvoidsNullSink(t *testing.T) {
	sinks := "0\tsink.primary_output\tmodule-droid-card.c\ts16le 2ch 48000Hz\tSUSPENDED\n" +
		"1\tsink.fast\tmodule-droid-card.c\ts16le 2ch 48000Hz\tSUSPENDED\n" +
		"2\tsink.null\tmodule-null-sink.c\ts16le 2ch 48000Hz\tRUNNING\n"
	if got := choosePulseAudioOutputSink("sink.null", sinks); got != "sink.primary_output" {
		t.Fatalf("sink = %q, want sink.primary_output", got)
	}
	if got := choosePulseAudioOutputSink("bluez_output.headset", sinks); got != "bluez_output.headset" {
		t.Fatalf("default Bluetooth sink = %q", got)
	}
	runningSinks := sinks +
		"3\tbluez_output.headset\tmodule-bluez5-device.c\ts16le 2ch 48000Hz\tRUNNING\n"
	if got := choosePulseAudioOutputSink("sink.null", runningSinks); got != "bluez_output.headset" {
		t.Fatalf("running sink = %q, want Bluetooth sink", got)
	}
}

func pcmActivityBlocks(blocks int, amplitude int16) []byte {
	data := make([]byte, blocks*1600*2)
	raw := uint16(amplitude)
	for offset := 0; offset < len(data); offset += 2 {
		data[offset] = byte(raw)
		data[offset+1] = byte(raw >> 8)
	}
	return data
}

func TestAnalyzeVoiceActivityFindsSpeechAndTrailingSilence(t *testing.T) {
	data := append(pcmActivityBlocks(5, 0), pcmActivityBlocks(6, 1800)...)
	data = append(data, pcmActivityBlocks(14, 0)...)
	activity := analyzeVoiceActivity(data)
	if !activity.SpeechDetected {
		t.Fatal("speech was not detected")
	}
	if activity.DurationMillis != 2500 {
		t.Fatalf("duration = %d ms, want 2500 ms", activity.DurationMillis)
	}
	if activity.TrailingSilenceMillis != 1400 {
		t.Fatalf("trailing silence = %d ms, want 1400 ms",
			activity.TrailingSilenceMillis)
	}
}

func TestAnalyzeVoiceActivityRejectsSilence(t *testing.T) {
	activity := analyzeVoiceActivity(pcmActivityBlocks(20, 0))
	if activity.SpeechDetected || activity.TrailingSilenceMillis != 0 {
		t.Fatalf("silence activity = %#v", activity)
	}
}
