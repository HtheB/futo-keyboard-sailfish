package main

import (
	"bufio"
	"bytes"
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/csv"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"math"
	"net/url"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/godbus/dbus/v5"
	"github.com/godbus/dbus/v5/introspect"
	securezip "github.com/yeka/zip"
)

const (
	busName                   = "org.hb.FutoKeyboard1"
	interfaceName             = "org.hb.FutoKeyboard1"
	keyboardModeChangedSignal = "KeyboardModeChanged"
	contentChangedSignal      = "ContentChanged"
	objectPath                = dbus.ObjectPath("/org/hb/FutoKeyboard1")
	enginePath                = "/usr/libexec/futo-keyboard-engine"
	voicePath                 = "/usr/libexec/futo-keyboard-voice"
	bundledDictionaryDir      = "/usr/share/futo-keyboard-sailfish/dictionaries"
	bundledVoiceModelPath     = "/usr/share/futo-keyboard-sailfish/voice/tiny_acft_q8_0.bin"
	soundDir                  = "/usr/share/futo-keyboard-sailfish/sounds"
	keyringPath               = "/usr/libexec/futo-keyboard-keyring"
	focusPath                 = "/usr/libexec/futo-keyboard-focus"
	appSupportKeyboardPath    = "/usr/libexec/futo-keyboard-appsupport"
	forcedAppSupportDconfPath = "/sailfish/text_input/futo_keyboard/forcedAppSupportKeyEvents"
	vaultAuthAction           = "org.hb.futo.keyboard.saved-login"
	vaultSaveAuthAction       = "org.hb.futo.keyboard.save-login"
	version                   = "0.2.1"
)

func zeroBytes(data []byte) {
	for index := range data {
		data[index] = 0
	}
}

var encryptedFileMagic = []byte("FUTOENC1")

type secureFileCodec struct {
	mu              sync.RWMutex
	key             []byte
	requireKeyWrite bool
}

func (codec *secureFileCodec) setKey(key []byte) error {
	if len(key) != 32 {
		return errors.New("invalid secure-storage key size")
	}
	codec.mu.Lock()
	defer codec.mu.Unlock()
	codec.key = append(codec.key[:0], key...)
	return nil
}

func (codec *secureFileCodec) hasKey() bool {
	codec.mu.RLock()
	defer codec.mu.RUnlock()
	return len(codec.key) == 32
}

func (codec *secureFileCodec) clearKey() {
	codec.mu.Lock()
	defer codec.mu.Unlock()
	for index := range codec.key {
		codec.key[index] = 0
	}
	codec.key = nil
}

func (codec *secureFileCodec) decode(path string, data []byte) ([]byte, error) {
	if !bytes.HasPrefix(data, encryptedFileMagic) {
		return data, nil
	}
	codec.mu.RLock()
	key := append([]byte(nil), codec.key...)
	codec.mu.RUnlock()
	if len(key) != 32 {
		return nil, errors.New("secure storage is locked")
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	offset := len(encryptedFileMagic)
	if len(data) < offset+gcm.NonceSize()+gcm.Overhead() {
		return nil, errors.New("invalid encrypted data")
	}
	nonce := data[offset : offset+gcm.NonceSize()]
	return gcm.Open(nil, nonce, data[offset+gcm.NonceSize():],
		[]byte(filepath.Base(path)))
}

func (codec *secureFileCodec) encode(path string, data []byte) ([]byte, error) {
	codec.mu.RLock()
	key := append([]byte(nil), codec.key...)
	codec.mu.RUnlock()
	if len(key) == 0 {
		return data, nil
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, err
	}
	result := append([]byte(nil), encryptedFileMagic...)
	result = append(result, nonce...)
	return gcm.Seal(result, nonce, data, []byte(filepath.Base(path))), nil
}

func (codec *secureFileCodec) readJSON(path string, value interface{}) error {
	data, err := codec.readFile(path)
	if err != nil {
		return err
	}
	return json.Unmarshal(data, value)
}

func (codec *secureFileCodec) readFile(path string) ([]byte, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return codec.decode(path, data)
}

func (codec *secureFileCodec) writeJSON(path string, value interface{}) error {
	data, err := json.Marshal(value)
	if err != nil {
		return err
	}
	return codec.writeFile(path, data)
}

func (codec *secureFileCodec) writeFile(path string, data []byte) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	if !codec.hasKey() {
		// Learned words, context, URLs and clipboard data must never be
		// persisted as plaintext merely because Sailfish Secrets is locked.
		// Keep the in-memory update for the current helper session and retry
		// after authenticated key access instead.
		if codec.requireKeyWrite {
			return errors.New("secure storage is locked")
		}
		existing, err := os.ReadFile(path)
		if err == nil && bytes.HasPrefix(existing, encryptedFileMagic) {
			return errors.New("secure storage is locked")
		}
		if err != nil && !os.IsNotExist(err) {
			return err
		}
	}
	data, err := codec.encode(path, data)
	if err != nil {
		return err
	}
	temporary := path + ".new"
	if err := os.WriteFile(temporary, data, 0o600); err != nil {
		return err
	}
	if err := os.Chmod(temporary, 0o600); err != nil {
		_ = os.Remove(temporary)
		return err
	}
	return os.Rename(temporary, path)
}

func encryptedPath(path string) bool {
	file, err := os.Open(path)
	if err != nil {
		return false
	}
	defer file.Close()
	prefix := make([]byte, len(encryptedFileMagic))
	_, err = io.ReadFull(file, prefix)
	return err == nil && bytes.Equal(prefix, encryptedFileMagic)
}

func secretToolKey(operation, kind string) ([]byte, error) {
	path := keyringPath
	if override := os.Getenv("FUTO_SECRETS_HELPER"); override != "" {
		path = override
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	command := exec.CommandContext(ctx, path, operation, kind)
	var output bytes.Buffer
	var diagnostic bytes.Buffer
	command.Stdout = &output
	command.Stderr = &diagnostic
	if err := command.Run(); err != nil {
		message := strings.TrimSpace(diagnostic.String())
		if message != "" {
			return nil, fmt.Errorf("device key store %s %s: %w: %s",
				operation, kind, err, message)
		}
		return nil, fmt.Errorf("device key store %s %s: %w", operation, kind, err)
	}
	rawKey := output.Bytes()
	defer zeroBytes(rawKey)
	if len(rawKey) != 32 {
		return nil, errors.New("device key store returned an invalid key")
	}
	return append([]byte(nil), rawKey...), nil
}

type languageInfo struct {
	Code string
	File string
	Name string
}

var supportedLanguages = []languageInfo{
	{Code: "EN", File: "en_US.fksidx", Name: "English (US)"},
	{Code: "EN_GB", File: "en_GB.fksidx", Name: "English (UK)"},
	{Code: "NL", File: "nl.fksidx", Name: "Nederlands"},
	{Code: "TR", File: "tr.fksidx", Name: "Türkçe"},
	{Code: "DE", File: "de.fksidx", Name: "Deutsch"},
	{Code: "FR", File: "fr.fksidx", Name: "Français"},
	{Code: "ES", File: "es.fksidx", Name: "Español"},
	{Code: "IT", File: "it.fksidx", Name: "Italiano"},
	{Code: "PT_BR", File: "pt_BR.fksidx", Name: "Português (Brasil)"},
	{Code: "PT_PT", File: "pt_PT.fksidx", Name: "Português (Portugal)"},
	{Code: "SV", File: "sv.fksidx", Name: "Svenska"},
	{Code: "NB", File: "nb.fksidx", Name: "Norsk bokmål"},
	{Code: "DA", File: "da.fksidx", Name: "Dansk"},
	{Code: "FI", File: "fi.fksidx", Name: "Suomi"},
	{Code: "PL", File: "pl.fksidx", Name: "Polski"},
	{Code: "CS", File: "cs.fksidx", Name: "Čeština"},
	{Code: "RO", File: "ro.fksidx", Name: "Română"},
	{Code: "SL", File: "sl.fksidx", Name: "Slovenščina"},
	{Code: "HR", File: "hr.fksidx", Name: "Hrvatski"},
	{Code: "LV", File: "lv.fksidx", Name: "Latviešu"},
	{Code: "LT", File: "lt.fksidx", Name: "Lietuvių"},
	{Code: "EL", File: "el.fksidx", Name: "Ελληνικά"},
	{Code: "RU", File: "ru.fksidx", Name: "Русский"},
	{Code: "SR", File: "sr.fksidx", Name: "Српски (ћирилица)"},
	{Code: "SR_LATN", File: "sr_Latn.fksidx", Name: "Srpski (latinica)"},
}

type scoredWord struct {
	Word     string `json:"word"`
	Score    int64  `json:"score"`
	Language string `json:"language,omitempty"`
}

type correctionWord struct {
	Word     string `json:"word"`
	Score    int    `json:"score"`
	Language string `json:"language,omitempty"`
}

type engineAnalysis struct {
	Known       bool             `json:"known"`
	KnownScore  int              `json:"knownScore"`
	Suggestions []scoredWord     `json:"suggestions"`
	Corrections []correctionWord `json:"corrections"`
	Phrases     []string         `json:"phrases"`
}

type combinedAnalysis struct {
	Suggestions []string `json:"suggestions"`
	Correction  string   `json:"correction"`
	Language    string   `json:"language"`
}

type swipeAnalysis struct {
	Suggestions []string `json:"suggestions"`
	Language    string   `json:"language"`
}

type engineProcess struct {
	mu      sync.Mutex
	command *exec.Cmd
	stdin   io.WriteCloser
	stdout  *bufio.Reader
}

func (engine *engineProcess) startLocked() error {
	if engine.command != nil && engine.command.Process != nil {
		return nil
	}
	arguments := make([]string, 0, len(supportedLanguages)*2)
	for _, language := range supportedLanguages {
		dictionaryPath := resolvedDictionaryPath(language.File)
		if dictionaryPath == "" {
			continue
		}
		arguments = append(arguments, "--dictionary",
			language.Code+"="+dictionaryPath)
	}
	if len(arguments) == 0 {
		return errors.New("no prediction dictionaries are installed")
	}
	command := exec.Command(enginePath, arguments...)
	stdin, err := command.StdinPipe()
	if err != nil {
		return err
	}
	stdoutPipe, err := command.StdoutPipe()
	if err != nil {
		_ = stdin.Close()
		return err
	}
	command.Stderr = os.Stderr
	if err := command.Start(); err != nil {
		_ = stdin.Close()
		return err
	}
	engine.command = command
	engine.stdin = stdin
	engine.stdout = bufio.NewReaderSize(stdoutPipe, 32*1024)
	go func(process *exec.Cmd) {
		if err := process.Wait(); err != nil {
			log.Printf("dictionary engine stopped: %v", err)
		}
	}(command)
	return nil
}

func (engine *engineProcess) resetLocked() {
	if engine.stdin != nil {
		_ = engine.stdin.Close()
	}
	if engine.command != nil && engine.command.Process != nil {
		_ = engine.command.Process.Kill()
	}
	engine.command = nil
	engine.stdin = nil
	engine.stdout = nil
}

func (engine *engineProcess) suggest(language, word string, limit int32) ([]string, error) {
	engine.mu.Lock()
	defer engine.mu.Unlock()
	for attempt := 0; attempt < 2; attempt++ {
		if err := engine.startLocked(); err != nil {
			return nil, err
		}
		request := fmt.Sprintf("SUGGEST\t%s\t%d\t%s\n", language, limit, word)
		if _, err := io.WriteString(engine.stdin, request); err != nil {
			engine.resetLocked()
			continue
		}
		response, err := engine.stdout.ReadString('\n')
		if err != nil {
			engine.resetLocked()
			continue
		}
		response = strings.TrimSuffix(response, "\n")
		response = strings.TrimSuffix(response, "\r")
		if strings.HasPrefix(response, "ERROR\t") {
			return nil, errors.New(strings.TrimPrefix(response, "ERROR\t"))
		}
		if !strings.HasPrefix(response, "OK\t") {
			return nil, errors.New("invalid response from dictionary engine")
		}
		var suggestions []string
		if err := json.Unmarshal([]byte(strings.TrimPrefix(response, "OK\t")), &suggestions); err != nil {
			return nil, fmt.Errorf("decode dictionary response: %w", err)
		}
		return suggestions, nil
	}
	return nil, errors.New("dictionary engine is unavailable")
}

func (engine *engineProcess) top(language string, limit int32) ([]string, error) {
	engine.mu.Lock()
	defer engine.mu.Unlock()
	for attempt := 0; attempt < 2; attempt++ {
		if err := engine.startLocked(); err != nil {
			return nil, err
		}
		request := fmt.Sprintf("TOP\t%s\t%d\n", language, limit)
		if _, err := io.WriteString(engine.stdin, request); err != nil {
			engine.resetLocked()
			continue
		}
		response, err := engine.stdout.ReadString('\n')
		if err != nil {
			engine.resetLocked()
			continue
		}
		response = strings.TrimSuffix(strings.TrimSuffix(response, "\n"), "\r")
		if strings.HasPrefix(response, "ERROR\t") {
			return nil, errors.New(strings.TrimPrefix(response, "ERROR\t"))
		}
		if !strings.HasPrefix(response, "OK\t") {
			return nil, errors.New("invalid response from dictionary engine")
		}
		var suggestions []string
		if err := json.Unmarshal([]byte(strings.TrimPrefix(response, "OK\t")),
			&suggestions); err != nil {
			return nil, fmt.Errorf("decode top words: %w", err)
		}
		return suggestions, nil
	}
	return nil, errors.New("dictionary engine is unavailable")
}

func (engine *engineProcess) correct(language, word string) (string, error) {
	engine.mu.Lock()
	defer engine.mu.Unlock()
	for attempt := 0; attempt < 2; attempt++ {
		if err := engine.startLocked(); err != nil {
			return "", err
		}
		request := fmt.Sprintf("CORRECT\t%s\t%s\n", language, word)
		if _, err := io.WriteString(engine.stdin, request); err != nil {
			engine.resetLocked()
			continue
		}
		response, err := engine.stdout.ReadString('\n')
		if err != nil {
			engine.resetLocked()
			continue
		}
		response = strings.TrimSuffix(response, "\n")
		response = strings.TrimSuffix(response, "\r")
		if strings.HasPrefix(response, "ERROR\t") {
			return "", errors.New(strings.TrimPrefix(response, "ERROR\t"))
		}
		if !strings.HasPrefix(response, "OK\t") {
			return "", errors.New("invalid response from dictionary engine")
		}
		var correction string
		if err := json.Unmarshal([]byte(strings.TrimPrefix(response, "OK\t")), &correction); err != nil {
			return "", fmt.Errorf("decode dictionary correction: %w", err)
		}
		return correction, nil
	}
	return "", errors.New("dictionary engine is unavailable")
}

func (engine *engineProcess) analyze(language, word string, limit int32) (engineAnalysis, error) {
	engine.mu.Lock()
	defer engine.mu.Unlock()
	for attempt := 0; attempt < 2; attempt++ {
		if err := engine.startLocked(); err != nil {
			return engineAnalysis{}, err
		}
		request := fmt.Sprintf("ANALYZE\t%s\t%d\t%s\n", language, limit, word)
		if _, err := io.WriteString(engine.stdin, request); err != nil {
			engine.resetLocked()
			continue
		}
		response, err := engine.stdout.ReadString('\n')
		if err != nil {
			engine.resetLocked()
			continue
		}
		response = strings.TrimSuffix(response, "\n")
		response = strings.TrimSuffix(response, "\r")
		if strings.HasPrefix(response, "ERROR\t") {
			return engineAnalysis{}, errors.New(strings.TrimPrefix(response, "ERROR\t"))
		}
		if !strings.HasPrefix(response, "OK\t") {
			return engineAnalysis{}, errors.New("invalid response from dictionary engine")
		}
		var analysis engineAnalysis
		if err := json.Unmarshal([]byte(strings.TrimPrefix(response, "OK\t")), &analysis); err != nil {
			return engineAnalysis{}, fmt.Errorf("decode dictionary analysis: %w", err)
		}
		return analysis, nil
	}
	return engineAnalysis{}, errors.New("dictionary engine is unavailable")
}

func (engine *engineProcess) swipe(language, path, geometry string, limit int32,
	capitalize bool) ([]scoredWord, error) {
	engine.mu.Lock()
	defer engine.mu.Unlock()
	capitalized := 0
	if capitalize {
		capitalized = 1
	}
	for attempt := 0; attempt < 2; attempt++ {
		if err := engine.startLocked(); err != nil {
			return nil, err
		}
		request := fmt.Sprintf("SWIPE\t%s\t%d\t%d\t%s\t%s\n",
			language, limit, capitalized, path, geometry)
		if _, err := io.WriteString(engine.stdin, request); err != nil {
			engine.resetLocked()
			continue
		}
		response, err := engine.stdout.ReadString('\n')
		if err != nil {
			engine.resetLocked()
			continue
		}
		response = strings.TrimSuffix(strings.TrimSuffix(response, "\n"), "\r")
		if strings.HasPrefix(response, "ERROR\t") {
			return nil, errors.New(strings.TrimPrefix(response, "ERROR\t"))
		}
		if !strings.HasPrefix(response, "OK\t") {
			return nil, errors.New("invalid swipe response from dictionary engine")
		}
		var suggestions []scoredWord
		if err := json.Unmarshal([]byte(strings.TrimPrefix(response, "OK\t")),
			&suggestions); err != nil {
			return nil, fmt.Errorf("decode swipe suggestions: %w", err)
		}
		return suggestions, nil
	}
	return nil, errors.New("dictionary engine is unavailable")
}

func (engine *engineProcess) close() {
	engine.mu.Lock()
	defer engine.mu.Unlock()
	engine.resetLocked()
}

func (engine *engineProcess) reload() {
	engine.close()
}

type learnedStore struct {
	mu    sync.Mutex
	path  string
	codec *secureFileCodec
	words map[string]map[string]int
}

func newLearnedStore(path string, codec *secureFileCodec) *learnedStore {
	store := &learnedStore{path: path, codec: codec,
		words: make(map[string]map[string]int)}
	if err := store.reload(); err != nil && !os.IsNotExist(err) {
		log.Printf("ignoring invalid personal dictionary: %v", err)
	}
	return store
}

func (store *learnedStore) reload() error {
	store.mu.Lock()
	defer store.mu.Unlock()
	words := make(map[string]map[string]int)
	if err := store.codec.readJSON(store.path, &words); err != nil {
		return err
	}
	store.words = words
	return nil
}

func (store *learnedStore) accept(language, word string) error {
	store.mu.Lock()
	defer store.mu.Unlock()
	if store.words[language] == nil {
		store.words[language] = make(map[string]int)
	}
	if store.words[language][word] < 1000000 {
		store.words[language][word]++
	}
	return store.saveLocked()
}

func (store *learnedStore) matches(language, prefix string, maximum int) []string {
	store.mu.Lock()
	defer store.mu.Unlock()
	type rankedWord struct {
		word  string
		count int
	}
	prefix = strings.ToLower(prefix)
	var ranked []rankedWord
	for word, count := range store.words[language] {
		if count >= 2 && strings.HasPrefix(strings.ToLower(word), prefix) {
			ranked = append(ranked, rankedWord{word: word, count: count})
		}
	}
	sort.Slice(ranked, func(i, j int) bool {
		if ranked[i].count != ranked[j].count {
			return ranked[i].count > ranked[j].count
		}
		return len(ranked[i].word) < len(ranked[j].word)
	})
	if len(ranked) > maximum {
		ranked = ranked[:maximum]
	}
	result := make([]string, 0, len(ranked))
	for _, item := range ranked {
		result = append(result, item.word)
	}
	return result
}

func (store *learnedStore) contains(language, word string) bool {
	store.mu.Lock()
	defer store.mu.Unlock()
	word = strings.ToLower(word)
	for learnedWord, count := range store.words[language] {
		if count >= 2 && strings.ToLower(learnedWord) == word {
			return true
		}
	}
	return false
}

func (store *learnedStore) matchesLanguages(languages []string, prefix string, maximum int) []string {
	store.mu.Lock()
	defer store.mu.Unlock()
	type rankedWord struct {
		word  string
		count int
	}
	prefix = strings.ToLower(prefix)
	allowed := map[string]bool{"MULTI": true}
	for _, language := range languages {
		allowed[language] = true
	}
	combined := make(map[string]rankedWord)
	for language, words := range store.words {
		if !allowed[language] {
			continue
		}
		for word, count := range words {
			if count < 2 || !strings.HasPrefix(strings.ToLower(word), prefix) {
				continue
			}
			key := strings.ToLower(word)
			current := combined[key]
			current.word = word
			current.count += count
			combined[key] = current
		}
	}
	ranked := make([]rankedWord, 0, len(combined))
	for _, word := range combined {
		ranked = append(ranked, word)
	}
	sort.Slice(ranked, func(i, j int) bool {
		if ranked[i].count != ranked[j].count {
			return ranked[i].count > ranked[j].count
		}
		return len(ranked[i].word) < len(ranked[j].word)
	})
	if len(ranked) > maximum {
		ranked = ranked[:maximum]
	}
	result := make([]string, 0, len(ranked))
	for _, item := range ranked {
		result = append(result, item.word)
	}
	return result
}

func (store *learnedStore) containsLanguages(languages []string, word string) bool {
	store.mu.Lock()
	defer store.mu.Unlock()
	word = strings.ToLower(word)
	allowed := map[string]bool{"MULTI": true}
	for _, language := range languages {
		allowed[language] = true
	}
	for language, words := range store.words {
		if !allowed[language] {
			continue
		}
		for learnedWord, count := range words {
			if count >= 2 && strings.ToLower(learnedWord) == word {
				return true
			}
		}
	}
	return false
}

func (store *learnedStore) clear() error {
	store.mu.Lock()
	defer store.mu.Unlock()
	store.words = make(map[string]map[string]int)
	if err := os.Remove(store.path); err != nil && !os.IsNotExist(err) {
		return err
	}
	return nil
}

func (store *learnedStore) saveLocked() error {
	return store.codec.writeJSON(store.path, store.words)
}

type personalWord struct {
	Word  string `json:"word"`
	Count int    `json:"count"`
}

type urlHistoryEntry struct {
	Text     string `json:"text"`
	Count    int    `json:"count"`
	LastUsed int64  `json:"lastUsed"`
}

type urlHistoryStore struct {
	mu      sync.Mutex
	path    string
	codec   *secureFileCodec
	entries map[string]urlHistoryEntry
}

func newURLHistoryStore(path string, codec *secureFileCodec) *urlHistoryStore {
	store := &urlHistoryStore{path: path, codec: codec,
		entries: make(map[string]urlHistoryEntry)}
	if err := store.reload(); err != nil && !os.IsNotExist(err) {
		log.Printf("ignoring invalid URL history: %v", err)
	}
	return store
}

func (store *urlHistoryStore) reload() error {
	store.mu.Lock()
	defer store.mu.Unlock()
	entries := make(map[string]urlHistoryEntry)
	if err := store.codec.readJSON(store.path, &entries); err != nil {
		return err
	}
	store.entries = normalizeURLHistoryEntries(entries)
	return nil
}

func normalizeURLHistoryValue(value string) (string, string, bool) {
	value = strings.TrimSpace(value)
	if value == "" || len(value) > 2048 || strings.IndexFunc(value, unicode.IsSpace) >= 0 ||
		strings.IndexFunc(value, func(character rune) bool { return unicode.IsControl(character) }) >= 0 {
		return "", "", false
	}
	parseValue := value
	if !strings.Contains(parseValue, "://") {
		parseValue = "https://" + parseValue
	}
	parsed, err := url.ParseRequestURI(parseValue)
	if err != nil || parsed.Hostname() == "" || parsed.User != nil {
		return "", "", false
	}
	host := strings.ToLower(parsed.Hostname())
	if host != "localhost" && !strings.Contains(host, ".") {
		return "", "", false
	}
	// URL history deliberately represents a site, not every page visited on
	// that site.  parsed.Host preserves an explicit port while discarding the
	// path, query and fragment; parsing first ensures the slashes in http:// and
	// https:// are never mistaken for a page-path separator.
	host = strings.ToLower(parsed.Host)
	return host, host, true
}

func normalizeURLHistoryEntries(entries map[string]urlHistoryEntry) map[string]urlHistoryEntry {
	clean := make(map[string]urlHistoryEntry)
	for _, entry := range entries {
		key, display, ok := normalizeURLHistoryValue(entry.Text)
		if !ok || entry.Count < 1 {
			continue
		}
		current := clean[key]
		current.Text = display
		current.Count += entry.Count
		if current.Count > 1000000 {
			current.Count = 1000000
		}
		if entry.LastUsed > current.LastUsed {
			current.LastUsed = entry.LastUsed
		}
		clean[key] = current
	}
	return clean
}

func (store *urlHistoryStore) accept(value string) (bool, error) {
	key, display, ok := normalizeURLHistoryValue(value)
	if !ok {
		return false, nil
	}
	store.mu.Lock()
	defer store.mu.Unlock()
	entry := store.entries[key]
	entry.Text = display
	if entry.Count < 1000000 {
		entry.Count++
	}
	entry.LastUsed = time.Now().Unix()
	store.entries[key] = entry
	return true, store.saveLocked()
}

func urlHistorySearchValue(value string) string {
	value = strings.ToLower(strings.TrimSpace(value))
	if separator := strings.Index(value, "://"); separator >= 0 {
		value = value[separator+3:]
	}
	return strings.TrimPrefix(value, "www.")
}

func (store *urlHistoryStore) suggest(prefix string, maximum int) []string {
	store.mu.Lock()
	defer store.mu.Unlock()
	prefix = strings.ToLower(strings.TrimSpace(prefix))
	searchPrefix := urlHistorySearchValue(prefix)
	type rankedURL struct {
		text     string
		count    int
		lastUsed int64
	}
	ranked := make([]rankedURL, 0, len(store.entries))
	for _, entry := range store.entries {
		entryText := strings.ToLower(entry.Text)
		if prefix != "" && !strings.HasPrefix(entryText, prefix) &&
			!strings.HasPrefix(urlHistorySearchValue(entryText), searchPrefix) {
			continue
		}
		ranked = append(ranked, rankedURL{entry.Text, entry.Count, entry.LastUsed})
	}
	sort.Slice(ranked, func(i, j int) bool {
		if ranked[i].count != ranked[j].count {
			return ranked[i].count > ranked[j].count
		}
		if ranked[i].lastUsed != ranked[j].lastUsed {
			return ranked[i].lastUsed > ranked[j].lastUsed
		}
		return ranked[i].text < ranked[j].text
	})
	if maximum < 1 {
		maximum = 1
	} else if maximum > 20 {
		maximum = 20
	}
	if len(ranked) > maximum {
		ranked = ranked[:maximum]
	}
	result := make([]string, 0, len(ranked))
	for _, entry := range ranked {
		result = append(result, entry.text)
	}
	return result
}

func (store *urlHistoryStore) list() []urlHistoryEntry {
	store.mu.Lock()
	defer store.mu.Unlock()
	result := make([]urlHistoryEntry, 0, len(store.entries))
	for _, entry := range store.entries {
		result = append(result, entry)
	}
	sort.Slice(result, func(i, j int) bool {
		if result[i].LastUsed != result[j].LastUsed {
			return result[i].LastUsed > result[j].LastUsed
		}
		if result[i].Count != result[j].Count {
			return result[i].Count > result[j].Count
		}
		return strings.ToLower(result[i].Text) < strings.ToLower(result[j].Text)
	})
	return result
}

func (store *urlHistoryStore) remove(value string) (bool, error) {
	key, _, ok := normalizeURLHistoryValue(value)
	if !ok {
		return false, nil
	}
	store.mu.Lock()
	defer store.mu.Unlock()
	if _, exists := store.entries[key]; !exists {
		return false, nil
	}
	delete(store.entries, key)
	return true, store.saveLocked()
}

func (store *urlHistoryStore) snapshot() map[string]urlHistoryEntry {
	store.mu.Lock()
	defer store.mu.Unlock()
	result := make(map[string]urlHistoryEntry, len(store.entries))
	for key, entry := range store.entries {
		result[key] = entry
	}
	return result
}

func (store *urlHistoryStore) replace(entries map[string]urlHistoryEntry) error {
	store.mu.Lock()
	defer store.mu.Unlock()
	store.entries = normalizeURLHistoryEntries(entries)
	return store.saveLocked()
}

func (store *urlHistoryStore) clear() error {
	store.mu.Lock()
	defer store.mu.Unlock()
	store.entries = make(map[string]urlHistoryEntry)
	if err := os.Remove(store.path); err != nil && !os.IsNotExist(err) {
		return err
	}
	return nil
}

func (store *urlHistoryStore) saveLocked() error {
	return store.codec.writeJSON(store.path, store.entries)
}

func (store *learnedStore) list() []personalWord {
	store.mu.Lock()
	defer store.mu.Unlock()
	combined := make(map[string]personalWord)
	for _, words := range store.words {
		for word, count := range words {
			key := strings.ToLower(word)
			item := combined[key]
			if item.Word == "" || count > item.Count {
				item.Word = word
			}
			item.Count += count
			combined[key] = item
		}
	}
	result := make([]personalWord, 0, len(combined))
	for _, item := range combined {
		result = append(result, item)
	}
	sort.Slice(result, func(i, j int) bool {
		if result[i].Count != result[j].Count {
			return result[i].Count > result[j].Count
		}
		return strings.ToLower(result[i].Word) < strings.ToLower(result[j].Word)
	})
	return result
}

func (store *learnedStore) addTrusted(word string) error {
	store.mu.Lock()
	defer store.mu.Unlock()
	if store.words["MULTI"] == nil {
		store.words["MULTI"] = make(map[string]int)
	}
	if store.words["MULTI"][word] < 2 {
		store.words["MULTI"][word] = 2
	}
	return store.saveLocked()
}

func (store *learnedStore) removeWord(word string) (bool, error) {
	store.mu.Lock()
	defer store.mu.Unlock()
	removed := false
	for language, words := range store.words {
		for learnedWord := range words {
			if strings.EqualFold(learnedWord, word) {
				delete(words, learnedWord)
				removed = true
			}
		}
		if len(words) == 0 {
			delete(store.words, language)
		}
	}
	if !removed {
		return false, nil
	}
	return true, store.saveLocked()
}

func (store *learnedStore) snapshot() map[string]map[string]int {
	store.mu.Lock()
	defer store.mu.Unlock()
	copyOfWords := make(map[string]map[string]int, len(store.words))
	for language, words := range store.words {
		copyOfWords[language] = make(map[string]int, len(words))
		for word, count := range words {
			copyOfWords[language][word] = count
		}
	}
	return copyOfWords
}

func (store *learnedStore) replace(words map[string]map[string]int) error {
	store.mu.Lock()
	defer store.mu.Unlock()
	clean := make(map[string]map[string]int)
	for language, entries := range words {
		for word, count := range entries {
			if !validWord(word) || count < 1 {
				continue
			}
			if count > 1000000 {
				count = 1000000
			}
			if clean[language] == nil {
				clean[language] = make(map[string]int)
			}
			clean[language][word] = count
		}
	}
	store.words = clean
	return store.saveLocked()
}

type historyData struct {
	Bigrams       map[string]map[string]int `json:"bigrams"`
	LanguageWords map[string]map[string]int `json:"languageWords"`
	Suppressed    map[string]bool           `json:"suppressed,omitempty"`
}

type historyStore struct {
	mu    sync.Mutex
	path  string
	codec *secureFileCodec
	data  historyData
}

func newHistoryStore(path string, codec *secureFileCodec) *historyStore {
	store := &historyStore{path: path, codec: codec, data: historyData{
		Bigrams:       make(map[string]map[string]int),
		LanguageWords: make(map[string]map[string]int),
		Suppressed:    make(map[string]bool),
	}}
	if err := store.reload(); err != nil && !os.IsNotExist(err) {
		log.Printf("ignoring invalid prediction history: %v", err)
	}
	return store
}

func (store *historyStore) reload() error {
	store.mu.Lock()
	defer store.mu.Unlock()
	data := historyData{}
	if err := store.codec.readJSON(store.path, &data); err != nil {
		return err
	}
	store.data = data
	if store.data.Bigrams == nil {
		store.data.Bigrams = make(map[string]map[string]int)
	}
	if store.data.LanguageWords == nil {
		store.data.LanguageWords = make(map[string]map[string]int)
	}
	if store.data.Suppressed == nil {
		store.data.Suppressed = make(map[string]bool)
	}
	return nil
}

func normalizedHistoryWord(word string) string {
	return strings.ToLower(strings.TrimSpace(word))
}

func (store *historyStore) accept(previous, word, language string) error {
	store.mu.Lock()
	defer store.mu.Unlock()
	previous = normalizedHistoryWord(previous)
	word = normalizedHistoryWord(word)
	if word == "" {
		return nil
	}
	if language != "" {
		if store.data.LanguageWords[word] == nil {
			store.data.LanguageWords[word] = make(map[string]int)
		}
		if store.data.LanguageWords[word][language] < 1000000 {
			store.data.LanguageWords[word][language]++
		}
	}
	if previous != "" {
		if store.data.Bigrams[previous] == nil {
			store.data.Bigrams[previous] = make(map[string]int)
		}
		if store.data.Bigrams[previous][word] < 1000000 {
			store.data.Bigrams[previous][word]++
		}
	}
	return store.saveLocked()
}

func (store *historyStore) languageBonus(word, language string) int64 {
	store.mu.Lock()
	defer store.mu.Unlock()
	return int64(store.data.LanguageWords[normalizedHistoryWord(word)][language]) * 25000000
}

func (store *historyStore) bigramBonus(previous, word string) int64 {
	store.mu.Lock()
	defer store.mu.Unlock()
	count := store.data.Bigrams[normalizedHistoryWord(previous)][normalizedHistoryWord(word)]
	if count > 20 {
		count = 20
	}
	return int64(count) * 30000000
}

func (store *historyStore) dominantLanguage(word string, allowed []string) string {
	store.mu.Lock()
	defer store.mu.Unlock()
	counts := store.data.LanguageWords[normalizedHistoryWord(word)]
	best := ""
	bestCount := 0
	for _, language := range allowed {
		if counts[language] > bestCount {
			best = language
			bestCount = counts[language]
		}
	}
	return best
}

func (store *historyStore) next(previous string, maximum int) []string {
	store.mu.Lock()
	defer store.mu.Unlock()
	words := store.data.Bigrams[normalizedHistoryWord(previous)]
	type ranked struct {
		word  string
		count int
	}
	items := make([]ranked, 0, len(words))
	for word, count := range words {
		items = append(items, ranked{word: word, count: count})
	}
	sort.Slice(items, func(i, j int) bool {
		if items[i].count != items[j].count {
			return items[i].count > items[j].count
		}
		return items[i].word < items[j].word
	})
	if len(items) > maximum {
		items = items[:maximum]
	}
	result := make([]string, 0, len(items))
	for _, item := range items {
		result = append(result, item.word)
	}
	return result
}

func (store *historyStore) removeWord(word string) (bool, error) {
	store.mu.Lock()
	defer store.mu.Unlock()
	word = normalizedHistoryWord(word)
	if word == "" {
		return false, nil
	}
	removed := false
	if _, ok := store.data.LanguageWords[word]; ok {
		delete(store.data.LanguageWords, word)
		removed = true
	}
	if _, ok := store.data.Bigrams[word]; ok {
		delete(store.data.Bigrams, word)
		removed = true
	}
	for previous, words := range store.data.Bigrams {
		if _, ok := words[word]; ok {
			delete(words, word)
			removed = true
		}
		if len(words) == 0 {
			delete(store.data.Bigrams, previous)
		}
	}
	if !removed {
		return false, nil
	}
	return true, store.saveLocked()
}

// suppressWord removes all learned ranking context for a word and remembers
// that the user explicitly removed it from the suggestion strip.  Keeping the
// suppression separate from the immutable packaged dictionaries means common
// dictionary words can be hidden without modifying system dictionary files.
func (store *historyStore) suppressWord(word string) (bool, error) {
	store.mu.Lock()
	defer store.mu.Unlock()
	word = normalizedHistoryWord(word)
	if word == "" {
		return false, nil
	}
	changed := !store.data.Suppressed[word]
	store.data.Suppressed[word] = true
	if _, ok := store.data.LanguageWords[word]; ok {
		delete(store.data.LanguageWords, word)
		changed = true
	}
	if _, ok := store.data.Bigrams[word]; ok {
		delete(store.data.Bigrams, word)
		changed = true
	}
	for previous, words := range store.data.Bigrams {
		if _, ok := words[word]; ok {
			delete(words, word)
			changed = true
		}
		if len(words) == 0 {
			delete(store.data.Bigrams, previous)
		}
	}
	if !changed {
		return false, nil
	}
	return true, store.saveLocked()
}

func (store *historyStore) isSuppressed(word string) bool {
	store.mu.Lock()
	defer store.mu.Unlock()
	return store.data.Suppressed[normalizedHistoryWord(word)]
}

func (store *historyStore) snapshot() historyData {
	store.mu.Lock()
	defer store.mu.Unlock()
	data, _ := json.Marshal(store.data)
	var copyOfData historyData
	_ = json.Unmarshal(data, &copyOfData)
	return copyOfData
}

func (store *historyStore) replace(data historyData) error {
	store.mu.Lock()
	defer store.mu.Unlock()
	if data.Bigrams == nil {
		data.Bigrams = make(map[string]map[string]int)
	}
	if data.LanguageWords == nil {
		data.LanguageWords = make(map[string]map[string]int)
	}
	if data.Suppressed == nil {
		data.Suppressed = make(map[string]bool)
	}
	store.data = data
	return store.saveLocked()
}

func (store *historyStore) clear() error {
	store.mu.Lock()
	defer store.mu.Unlock()
	store.data = historyData{Bigrams: make(map[string]map[string]int),
		LanguageWords: make(map[string]map[string]int),
		Suppressed:    make(map[string]bool)}
	if err := os.Remove(store.path); err != nil && !os.IsNotExist(err) {
		return err
	}
	return nil
}

func (store *historyStore) saveLocked() error {
	return store.codec.writeJSON(store.path, store.data)
}

type clipboardEntry struct {
	ID        string `json:"id"`
	Text      string `json:"text"`
	CreatedAt int64  `json:"createdAt"`
	ExpiresAt int64  `json:"expiresAt,omitempty"`
	BootID    string `json:"bootId,omitempty"`
	Pinned    bool   `json:"pinned"`
}

type clipboardStore struct {
	mu      sync.Mutex
	path    string
	codec   *secureFileCodec
	bootID  string
	entries []clipboardEntry
}

func currentBootID() string {
	data, err := os.ReadFile("/proc/sys/kernel/random/boot_id")
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

func newClipboardStore(path string, codec *secureFileCodec) *clipboardStore {
	store := &clipboardStore{path: path, codec: codec, bootID: currentBootID()}
	if err := store.reload(); err != nil && !os.IsNotExist(err) {
		log.Printf("ignoring invalid clipboard history: %v", err)
	}
	store.mu.Lock()
	if store.purgeLocked(time.Now().Unix()) {
		if err := store.saveLocked(); err != nil {
			log.Printf("could not purge clipboard history: %v", err)
		}
	}
	store.mu.Unlock()
	return store
}

func (store *clipboardStore) reload() error {
	store.mu.Lock()
	defer store.mu.Unlock()
	var entries []clipboardEntry
	if err := store.codec.readJSON(store.path, &entries); err != nil {
		return err
	}
	store.entries = entries
	return nil
}

func normalizedClipboardText(value string) string {
	if strings.TrimSpace(value) == "" {
		return ""
	}
	runes := []rune(value)
	if len(runes) > 4096 {
		runes = runes[:4096]
	}
	return string(runes)
}

func (store *clipboardStore) purgeLocked(now int64) bool {
	changed := false
	kept := store.entries[:0]
	for _, entry := range store.entries {
		expired := !entry.Pinned && ((entry.ExpiresAt > 0 && now >= entry.ExpiresAt) ||
			(entry.BootID != "" && entry.BootID != store.bootID))
		if expired {
			changed = true
			continue
		}
		kept = append(kept, entry)
	}
	store.entries = kept
	return changed
}

func (store *clipboardStore) saveLocked() error {
	return store.codec.writeJSON(store.path, store.entries)
}

func clipboardExpiry(now int64, retentionSeconds int32, bootID string) (int64, string) {
	if retentionSeconds < 0 {
		return 0, bootID
	}
	if retentionSeconds < 60 {
		retentionSeconds = 60
	} else if retentionSeconds > 24*60*60 {
		retentionSeconds = 24 * 60 * 60
	}
	return now + int64(retentionSeconds), ""
}

func (store *clipboardStore) record(value string, retentionSeconds int32) (bool, error) {
	value = normalizedClipboardText(value)
	if value == "" {
		return false, nil
	}
	store.mu.Lock()
	defer store.mu.Unlock()
	now := time.Now().Unix()
	store.purgeLocked(now)
	for _, entry := range store.entries {
		if entry.Text == value && entry.Pinned {
			return false, nil
		}
	}
	filtered := store.entries[:0]
	for _, entry := range store.entries {
		if entry.Text != value {
			filtered = append(filtered, entry)
		}
	}
	store.entries = filtered
	expiresAt, bootID := clipboardExpiry(now, retentionSeconds, store.bootID)
	entry := clipboardEntry{
		ID: fmt.Sprintf("%x", time.Now().UnixNano()), Text: value, CreatedAt: now,
		ExpiresAt: expiresAt, BootID: bootID,
	}
	store.entries = append([]clipboardEntry{entry}, store.entries...)
	if len(store.entries) > 100 {
		kept := make([]clipboardEntry, 0, 100)
		for _, candidate := range store.entries {
			if len(kept) < 100 || candidate.Pinned {
				kept = append(kept, candidate)
			}
		}
		store.entries = kept
	}
	return true, store.saveLocked()
}

func (store *clipboardStore) list() ([]clipboardEntry, error) {
	store.mu.Lock()
	defer store.mu.Unlock()
	changed := store.purgeLocked(time.Now().Unix())
	result := append([]clipboardEntry(nil), store.entries...)
	sort.SliceStable(result, func(i, j int) bool {
		if result[i].Pinned != result[j].Pinned {
			return result[i].Pinned
		}
		return result[i].CreatedAt > result[j].CreatedAt
	})
	if changed {
		return result, store.saveLocked()
	}
	return result, nil
}

func (store *clipboardStore) setPinned(id string, pinned bool,
	retentionSeconds int32) (bool, error) {
	store.mu.Lock()
	defer store.mu.Unlock()
	now := time.Now().Unix()
	store.purgeLocked(now)
	for i := range store.entries {
		if store.entries[i].ID != id {
			continue
		}
		store.entries[i].Pinned = pinned
		if pinned {
			store.entries[i].ExpiresAt = 0
			store.entries[i].BootID = ""
		} else {
			store.entries[i].ExpiresAt, store.entries[i].BootID = clipboardExpiry(
				now, retentionSeconds, store.bootID)
		}
		return true, store.saveLocked()
	}
	return false, nil
}

func (store *clipboardStore) remove(id string) (bool, error) {
	store.mu.Lock()
	defer store.mu.Unlock()
	for i := range store.entries {
		if store.entries[i].ID == id {
			store.entries = append(store.entries[:i], store.entries[i+1:]...)
			return true, store.saveLocked()
		}
	}
	return false, nil
}

func (store *clipboardStore) clear() error {
	store.mu.Lock()
	defer store.mu.Unlock()
	store.entries = nil
	if err := os.Remove(store.path); err != nil && !os.IsNotExist(err) {
		return err
	}
	return nil
}

type credentialEntry struct {
	ID        string `json:"id"`
	Label     string `json:"label"`
	Origin    string `json:"origin,omitempty"`
	Username  string `json:"username,omitempty"`
	Password  string `json:"password"`
	CreatedAt int64  `json:"createdAt"`
	UpdatedAt int64  `json:"updatedAt"`
}

type credentialMetadata struct {
	ID       string `json:"id"`
	Label    string `json:"label"`
	Origin   string `json:"origin,omitempty"`
	Username string `json:"username,omitempty"`
}

type vaultStore struct {
	mu         sync.Mutex
	path       string
	codec      *secureFileCodec
	entries    []credentialEntry
	lastAccess time.Time
}

// credentialMatchIndex contains only normalized site names and entry counts.
// It is encrypted with the device-bound learned-data key and lets the keyboard
// decide whether a saved-login affordance is truthful without unlocking the
// password vault or exposing usernames/passwords.
type credentialMatchIndex struct {
	mu      sync.Mutex
	path    string
	codec   *secureFileCodec
	origins map[string]int
}

func newCredentialMatchIndex(path string, codec *secureFileCodec) *credentialMatchIndex {
	index := &credentialMatchIndex{path: path, codec: codec,
		origins: make(map[string]int)}
	if err := index.reload(); err != nil && !os.IsNotExist(err) {
		log.Printf("ignoring invalid credential match index: %v", err)
	}
	return index
}

func (index *credentialMatchIndex) reload() error {
	index.mu.Lock()
	defer index.mu.Unlock()
	origins := make(map[string]int)
	if err := index.codec.readJSON(index.path, &origins); err != nil {
		return err
	}
	index.origins = origins
	return nil
}

func (index *credentialMatchIndex) replace(entries []credentialMetadata) error {
	origins := make(map[string]int)
	for _, entry := range entries {
		origin := normalizeCredentialOrigin(entry.Origin)
		if origin != "" {
			origins[origin]++
		}
	}
	index.mu.Lock()
	defer index.mu.Unlock()
	if err := index.codec.writeJSON(index.path, origins); err != nil {
		return err
	}
	index.origins = origins
	return nil
}

func (index *credentialMatchIndex) count(origin string) int {
	origin = normalizeCredentialOrigin(origin)
	if origin == "" {
		return 0
	}
	index.mu.Lock()
	defer index.mu.Unlock()
	return index.origins[origin]
}

const vaultUnlockDuration = 2 * time.Minute

func newVaultStore(path string) *vaultStore {
	return &vaultStore{path: path, codec: &secureFileCodec{}}
}

func (store *vaultStore) lockLocked() {
	store.codec.clearKey()
	for index := range store.entries {
		store.entries[index].Password = ""
	}
	store.entries = nil
	store.lastAccess = time.Time{}
}

func (store *vaultStore) lock() {
	store.mu.Lock()
	defer store.mu.Unlock()
	store.lockLocked()
}

func (store *vaultStore) unlockedLocked() bool {
	if !store.codec.hasKey() || store.lastAccess.IsZero() ||
		time.Since(store.lastAccess) > vaultUnlockDuration {
		store.lockLocked()
		return false
	}
	return true
}

func (store *vaultStore) status() string {
	store.mu.Lock()
	defer store.mu.Unlock()
	if store.unlockedLocked() {
		return "unlocked"
	}
	if encryptedPath(store.path) {
		return "locked"
	}
	return "not_initialized"
}

func (store *vaultStore) open(key []byte, create bool) error {
	store.mu.Lock()
	defer store.mu.Unlock()
	if err := store.codec.setKey(key); err != nil {
		return err
	}
	var entries []credentialEntry
	err := store.codec.readJSON(store.path, &entries)
	if err != nil {
		if !os.IsNotExist(err) || !create {
			store.lockLocked()
			return err
		}
		entries = []credentialEntry{}
		if err := store.codec.writeJSON(store.path, entries); err != nil {
			store.lockLocked()
			return err
		}
	}
	store.entries = entries
	store.lastAccess = time.Now()
	return nil
}

func (store *vaultStore) list() ([]credentialMetadata, error) {
	store.mu.Lock()
	defer store.mu.Unlock()
	if !store.unlockedLocked() {
		return nil, errors.New("password vault is locked")
	}
	store.lastAccess = time.Now()
	result := make([]credentialMetadata, 0, len(store.entries))
	for _, entry := range store.entries {
		result = append(result, credentialMetadata{ID: entry.ID, Label: entry.Label,
			Origin: entry.Origin, Username: entry.Username})
	}
	sort.SliceStable(result, func(i, j int) bool {
		if strings.ToLower(result[i].Label) != strings.ToLower(result[j].Label) {
			return strings.ToLower(result[i].Label) < strings.ToLower(result[j].Label)
		}
		return strings.ToLower(result[i].Username) < strings.ToLower(result[j].Username)
	})
	return result, nil
}

func credentialMatchesSearch(entry credentialEntry, query string) bool {
	query = strings.ToLower(strings.TrimSpace(query))
	if query == "" {
		return true
	}
	for _, value := range []string{entry.Label, entry.Origin, entry.Username, entry.Password} {
		if strings.Contains(strings.ToLower(value), query) {
			return true
		}
	}
	return false
}

func (store *vaultStore) search(query string) ([]credentialMetadata, error) {
	store.mu.Lock()
	defer store.mu.Unlock()
	if !store.unlockedLocked() {
		return nil, errors.New("password vault is locked")
	}
	store.lastAccess = time.Now()
	result := make([]credentialMetadata, 0, len(store.entries))
	for _, entry := range store.entries {
		if credentialMatchesSearch(entry, query) {
			result = append(result, credentialMetadata{ID: entry.ID, Label: entry.Label,
				Origin: entry.Origin, Username: entry.Username})
		}
	}
	sort.SliceStable(result, func(i, j int) bool {
		if strings.ToLower(result[i].Label) != strings.ToLower(result[j].Label) {
			return strings.ToLower(result[i].Label) < strings.ToLower(result[j].Label)
		}
		return strings.ToLower(result[i].Username) < strings.ToLower(result[j].Username)
	})
	return result, nil
}

func normalizeCredentialOrigin(value string) string {
	value = strings.TrimSpace(value)
	if value == "" || len(value) > 2048 {
		return ""
	}
	parseValue := value
	if !strings.Contains(parseValue, "://") {
		parseValue = "https://" + parseValue
	}
	parsed, err := url.Parse(parseValue)
	if err != nil || parsed.Hostname() == "" || parsed.User != nil {
		return ""
	}
	scheme := strings.ToLower(parsed.Scheme)
	if scheme == "app" {
		// App identities come from Sailfish's compositor application id or
		// Android AppSupport's component/package name. Store only the stable
		// package/desktop id, never an activity path or transient window id.
		host := strings.ToLower(parsed.Hostname())
		if host == "none" || host == "null" || host == "undefined" ||
			host == "unknown" || host == "not-applicable" || host == "na" ||
			host == "0" || len(host) > 240 || !regexp.MustCompile(
			`^[a-z0-9][a-z0-9._-]*$`).MatchString(host) {
			return ""
		}
		return "app://" + host
	}
	if scheme != "http" && scheme != "https" {
		return ""
	}
	host := strings.ToLower(parsed.Hostname())
	if port := parsed.Port(); port != "" {
		host += ":" + port
	}
	return scheme + "://" + host
}

func cleanCredentialText(value string, maximum int) string {
	value = strings.TrimSpace(value)
	value = strings.Map(func(character rune) rune {
		if unicode.IsControl(character) {
			return -1
		}
		return character
	}, value)
	characters := []rune(value)
	if len(characters) > maximum {
		characters = characters[:maximum]
	}
	return string(characters)
}

func randomID() (string, error) {
	data := make([]byte, 16)
	if _, err := io.ReadFull(rand.Reader, data); err != nil {
		return "", err
	}
	return fmt.Sprintf("%x", data), nil
}

func (store *vaultStore) saveLocked() error {
	if !store.unlockedLocked() {
		return errors.New("password vault is locked")
	}
	store.lastAccess = time.Now()
	return store.codec.writeJSON(store.path, store.entries)
}

func (store *vaultStore) upsert(label, origin, username, password string) (bool, error) {
	store.mu.Lock()
	defer store.mu.Unlock()
	if !store.unlockedLocked() {
		return false, errors.New("password vault is locked")
	}
	label = cleanCredentialText(label, 200)
	username = cleanCredentialText(username, 512)
	origin = normalizeCredentialOrigin(origin)
	if len(password) > 4096 || strings.IndexFunc(password, unicode.IsControl) >= 0 {
		return false, nil
	}
	if password == "" || (label == "" && origin == "") {
		return false, nil
	}
	if label == "" {
		label = strings.TrimPrefix(strings.TrimPrefix(origin, "https://"), "http://")
	}
	now := time.Now().Unix()
	for index := range store.entries {
		entry := &store.entries[index]
		if strings.EqualFold(entry.Origin, origin) && entry.Username == username {
			entry.Label = label
			entry.Password = password
			entry.UpdatedAt = now
			return true, store.saveLocked()
		}
	}
	// Earlier keyboard builds could save a credential before the browser origin
	// survived the authentication focus transition. If there is exactly one
	// matching blank-origin entry, upgrade it in place when the origin is later
	// detected instead of creating a duplicate login.
	if origin != "" {
		blankMatch := -1
		for index := range store.entries {
			entry := &store.entries[index]
			if entry.Origin == "" && entry.Username == username {
				if blankMatch >= 0 {
					blankMatch = -1
					break
				}
				blankMatch = index
			}
		}
		if blankMatch >= 0 {
			entry := &store.entries[blankMatch]
			entry.Label = label
			entry.Origin = origin
			entry.Password = password
			entry.UpdatedAt = now
			return true, store.saveLocked()
		}
		// The first modal-save prototype could preserve the site/password while
		// losing the Android username during its field transition. Upgrade one
		// unambiguous blank-username entry for this exact site in place.
		if username != "" {
			blankUsernameMatch := -1
			for index := range store.entries {
				entry := &store.entries[index]
				if strings.EqualFold(entry.Origin, origin) && entry.Username == "" {
					if blankUsernameMatch >= 0 {
						blankUsernameMatch = -1
						break
					}
					blankUsernameMatch = index
				}
			}
			if blankUsernameMatch >= 0 {
				entry := &store.entries[blankUsernameMatch]
				entry.Label = label
				entry.Username = username
				entry.Password = password
				entry.UpdatedAt = now
				return true, store.saveLocked()
			}
		}
	}
	id, err := randomID()
	if err != nil {
		return false, err
	}
	store.entries = append(store.entries, credentialEntry{ID: id, Label: label,
		Origin: origin, Username: username, Password: password,
		CreatedAt: now, UpdatedAt: now})
	return true, store.saveLocked()
}

func (store *vaultStore) update(id, label, origin, username, password string) (bool, error) {
	store.mu.Lock()
	defer store.mu.Unlock()
	if !store.unlockedLocked() {
		return false, errors.New("password vault is locked")
	}
	label = cleanCredentialText(label, 200)
	username = cleanCredentialText(username, 512)
	origin = normalizeCredentialOrigin(origin)
	if id == "" || password == "" || (label == "" && origin == "") ||
		len(password) > 4096 || strings.IndexFunc(password, unicode.IsControl) >= 0 {
		return false, nil
	}
	if label == "" {
		label = strings.TrimPrefix(strings.TrimPrefix(origin, "https://"), "http://")
	}
	target := -1
	for index := range store.entries {
		if store.entries[index].ID == id {
			target = index
			continue
		}
		if strings.EqualFold(store.entries[index].Origin, origin) &&
			store.entries[index].Username == username {
			return false, nil
		}
	}
	if target < 0 {
		return false, nil
	}
	entry := &store.entries[target]
	entry.Label = label
	entry.Origin = origin
	entry.Username = username
	entry.Password = password
	entry.UpdatedAt = time.Now().Unix()
	return true, store.saveLocked()
}

func (store *vaultStore) remove(id string) (bool, error) {
	store.mu.Lock()
	defer store.mu.Unlock()
	if !store.unlockedLocked() {
		return false, errors.New("password vault is locked")
	}
	for index := range store.entries {
		if store.entries[index].ID != id {
			continue
		}
		store.entries[index].Password = ""
		store.entries = append(store.entries[:index], store.entries[index+1:]...)
		return true, store.saveLocked()
	}
	return false, nil
}

func (store *vaultStore) secret(id, field string) (string, error) {
	store.mu.Lock()
	defer store.mu.Unlock()
	if !store.unlockedLocked() {
		return "", errors.New("password vault is locked")
	}
	store.lastAccess = time.Now()
	for _, entry := range store.entries {
		if entry.ID != id {
			continue
		}
		if field == "username" {
			return entry.Username, nil
		}
		if field == "password" {
			return entry.Password, nil
		}
		return "", errors.New("invalid credential field")
	}
	return "", errors.New("credential not found")
}

func (store *vaultStore) snapshot() ([]credentialEntry, error) {
	store.mu.Lock()
	defer store.mu.Unlock()
	if !store.unlockedLocked() {
		return nil, errors.New("password vault is locked")
	}
	store.lastAccess = time.Now()
	entries := make([]credentialEntry, len(store.entries))
	copy(entries, store.entries)
	return entries, nil
}

type credentialImportResult struct {
	Imported         int    `json:"imported"`
	Skipped          int    `json:"skipped"`
	Path             string `json:"path"`
	Source           string `json:"source,omitempty"`
	PasswordRequired bool   `json:"passwordRequired,omitempty"`
	Error            string `json:"error,omitempty"`
}

type credentialExportResult struct {
	Path      string `json:"path,omitempty"`
	Websites  int    `json:"websites"`
	Apps      int    `json:"apps"`
	Protected bool   `json:"protected"`
	Error     string `json:"error,omitempty"`
}

type credentialArchiveManifest struct {
	Format       string   `json:"format"`
	Version      int      `json:"version"`
	CreatedAt    string   `json:"createdAt"`
	RestoreFiles []string `json:"restoreFiles"`
}

const (
	credentialArchiveFormat       = "futo-keyboard-password-export"
	credentialArchiveManifestName = "futo-password-export.json"
	credentialWebChromiumName     = "web-passwords-chromium.csv"
	credentialWebFirefoxName      = "web-passwords-firefox.csv"
	credentialAppName             = "futo-app-passwords.csv"
	credentialArchiveReadmeName   = "README.txt"
)

func normalizedCSVHeader(value string) string {
	value = strings.TrimPrefix(value, "\ufeff")
	value = strings.ToLower(strings.TrimSpace(value))
	return strings.NewReplacer(" ", "", "_", "", "-", "", ".", "").Replace(value)
}

type credentialCSVFormat struct {
	name            string
	requiredHeaders []string
	labelHeaders    []string
	originHeaders   []string
	usernameHeaders []string
	passwordHeaders []string
	typeHeader      string
	loginTypes      map[string]bool
}

func hasCSVHeaders(columns map[string]int, names ...string) bool {
	for _, name := range names {
		if _, ok := columns[name]; !ok {
			return false
		}
	}
	return true
}

func hasAnyCSVHeader(columns map[string]int, names ...string) bool {
	for _, name := range names {
		if _, ok := columns[name]; ok {
			return true
		}
	}
	return false
}

// detectCredentialCSVFormat deliberately identifies format families when
// multiple products export the same columns. An exact product name would be
// misleading for Chromium-family exports, for example.
func detectCredentialCSVFormat(columns map[string]int) (credentialCSVFormat, error) {
	commonLabel := []string{"name", "title", "itemname"}
	commonOrigin := []string{"url", "origin", "hostname", "website", "websiteaddress",
		"loginuri", "loginurl", "uri", "matchurl"}
	commonUsername := []string{"username", "login", "user", "loginusername", "email",
		"loginname"}
	commonPassword := []string{"password", "loginpassword", "pwd"}

	formats := []credentialCSVFormat{
		{
			name:            "Bitwarden",
			requiredHeaders: []string{"type", "loginuri", "loginusername", "loginpassword"},
			labelHeaders:    []string{"name"}, originHeaders: []string{"loginuri"},
			usernameHeaders: []string{"loginusername"}, passwordHeaders: []string{"loginpassword"},
			typeHeader: "type", loginTypes: map[string]bool{"login": true},
		},
		{
			name:            "Apple Passwords / Safari",
			requiredHeaders: []string{"title", "url", "username", "password", "otpauth"},
			labelHeaders:    []string{"title"}, originHeaders: []string{"url"},
			usernameHeaders: []string{"username"}, passwordHeaders: []string{"password"},
		},
		{
			name:            "1Password",
			requiredHeaders: []string{"title", "website", "username", "password"},
			labelHeaders:    []string{"title"}, originHeaders: []string{"website"},
			usernameHeaders: []string{"username"}, passwordHeaders: []string{"password"},
		},
		{
			name:            "Dropbox Passwords",
			requiredHeaders: []string{"title", "website", "login", "password", "otpsecret"},
			labelHeaders:    []string{"title"}, originHeaders: []string{"website"},
			usernameHeaders: []string{"login"}, passwordHeaders: []string{"password"},
		},
		{
			name:            "LastPass",
			requiredHeaders: []string{"url", "username", "password", "extra", "name", "grouping"},
			labelHeaders:    []string{"name"}, originHeaders: []string{"url"},
			usernameHeaders: []string{"username"}, passwordHeaders: []string{"password"},
		},
		{
			name:            "KeePass / KeePassXC",
			requiredHeaders: []string{"group", "title", "username", "password", "url", "notes"},
			labelHeaders:    []string{"title"}, originHeaders: []string{"url"},
			usernameHeaders: []string{"username"}, passwordHeaders: []string{"password"},
		},
		{
			name:            "Keeper",
			requiredHeaders: []string{"title", "login", "password", "websiteaddress"},
			labelHeaders:    []string{"title"}, originHeaders: []string{"websiteaddress"},
			usernameHeaders: []string{"login"}, passwordHeaders: []string{"password"},
		},
		{
			name:            "Dashlane",
			requiredHeaders: []string{"username", "username2", "title", "password", "url"},
			labelHeaders:    []string{"title"}, originHeaders: []string{"url"},
			usernameHeaders: []string{"username", "username2", "username3"},
			passwordHeaders: []string{"password"},
		},
		{
			name:            "RoboForm",
			requiredHeaders: []string{"name", "url", "login", "pwd"},
			labelHeaders:    []string{"name"}, originHeaders: []string{"url", "matchurl"},
			usernameHeaders: []string{"login"}, passwordHeaders: []string{"pwd"},
		},
		{
			name:            "NordPass",
			requiredHeaders: []string{"name", "url", "username", "password", "cardholdername", "cardnumber"},
			labelHeaders:    []string{"name"}, originHeaders: []string{"url"},
			usernameHeaders: []string{"username", "email"}, passwordHeaders: []string{"password"},
		},
		{
			name:            "Proton Pass",
			requiredHeaders: []string{"name", "url", "username", "password", "totp", "vault"},
			labelHeaders:    []string{"name"}, originHeaders: []string{"url"},
			usernameHeaders: []string{"username", "email"}, passwordHeaders: []string{"password"},
		},
		{
			name:            "Firefox",
			requiredHeaders: []string{"url", "username", "password", "httprealm"},
			labelHeaders:    commonLabel, originHeaders: []string{"url"},
			usernameHeaders: []string{"username"}, passwordHeaders: []string{"password"},
		},
		{
			name:            "Chromium browser",
			requiredHeaders: []string{"name", "url", "username", "password"},
			labelHeaders:    []string{"name"}, originHeaders: []string{"url"},
			usernameHeaders: []string{"username"}, passwordHeaders: []string{"password"},
		},
	}
	for _, format := range formats {
		if hasCSVHeaders(columns, format.requiredHeaders...) {
			return format, nil
		}
	}

	// Older Firefox exports may contain only these three columns. They cannot
	// be distinguished from another standards-compliant browser export.
	if hasCSVHeaders(columns, "url", "username", "password") &&
		!hasAnyCSVHeader(columns, "name", "title") {
		return credentialCSVFormat{
			name: "Browser CSV", labelHeaders: commonLabel, originHeaders: []string{"url"},
			usernameHeaders: []string{"username"}, passwordHeaders: []string{"password"},
		}, nil
	}

	if hasAnyCSVHeader(columns, commonPassword...) &&
		hasAnyCSVHeader(columns, commonUsername...) &&
		hasAnyCSVHeader(columns, commonOrigin...) {
		return credentialCSVFormat{
			name: "Generic password CSV", labelHeaders: commonLabel,
			originHeaders: commonOrigin, usernameHeaders: commonUsername,
			passwordHeaders: commonPassword,
		}, nil
	}
	return credentialCSVFormat{}, errors.New("unrecognized password CSV header")
}

func csvValueAt(row []string, columns map[string]int, names ...string) string {
	for _, name := range names {
		if index, ok := columns[name]; ok && index >= 0 && index < len(row) {
			return row[index]
		}
	}
	return ""
}

func (store *vaultStore) importCSVReader(source io.Reader,
	path string) (credentialImportResult, error) {
	result := credentialImportResult{Path: path}
	reader := csv.NewReader(io.LimitReader(source, 20*1024*1024))
	reader.FieldsPerRecord = -1
	headers, err := reader.Read()
	if err != nil {
		return result, errors.New("invalid password CSV header")
	}
	columns := make(map[string]int)
	for index, header := range headers {
		normalized := normalizedCSVHeader(header)
		if normalized == "" {
			continue
		}
		if _, duplicate := columns[normalized]; duplicate {
			return result, errors.New("ambiguous duplicate password CSV header")
		}
		columns[normalized] = index
	}
	format, err := detectCredentialCSVFormat(columns)
	if err != nil {
		return result, err
	}
	result.Source = format.name
	for rowNumber := 0; rowNumber < 10000; rowNumber++ {
		row, readErr := reader.Read()
		if readErr == io.EOF {
			break
		}
		if readErr != nil {
			result.Skipped++
			continue
		}
		if format.typeHeader != "" {
			itemType := strings.ToLower(strings.TrimSpace(csvValueAt(row, columns, format.typeHeader)))
			if !format.loginTypes[itemType] {
				result.Skipped++
				continue
			}
		}
		label := csvValueAt(row, columns, format.labelHeaders...)
		origin := csvValueAt(row, columns, format.originHeaders...)
		username := csvValueAt(row, columns, format.usernameHeaders...)
		password := csvValueAt(row, columns, format.passwordHeaders...)
		added, addErr := store.upsert(label, origin, username, password)
		if addErr != nil {
			return result, addErr
		}
		if added {
			result.Imported++
		} else {
			result.Skipped++
		}
	}
	return result, nil
}

func (store *vaultStore) importCSV(path string) (credentialImportResult, error) {
	result := credentialImportResult{Path: path}
	info, err := os.Stat(path)
	if err != nil || !info.Mode().IsRegular() || info.Size() > 20*1024*1024 {
		return result, errors.New("password CSV was not found or is too large")
	}
	file, err := os.Open(path)
	if err != nil {
		return result, err
	}
	defer file.Close()
	return store.importCSVReader(file, path)
}

type credentialArchiveFile struct {
	name string
	data []byte
}

func encodeCredentialCSV(headers []string, rows [][]string) ([]byte, error) {
	var buffer bytes.Buffer
	writer := csv.NewWriter(&buffer)
	if err := writer.Write(headers); err != nil {
		return nil, err
	}
	for _, row := range rows {
		if err := writer.Write(row); err != nil {
			return nil, err
		}
	}
	writer.Flush()
	if err := writer.Error(); err != nil {
		return nil, err
	}
	return buffer.Bytes(), nil
}

func buildCredentialArchive(entries []credentialEntry,
	createdAt time.Time) ([]credentialArchiveFile, int, int, error) {
	chromiumRows := make([][]string, 0, len(entries))
	firefoxRows := make([][]string, 0, len(entries))
	appRows := make([][]string, 0, len(entries))
	for _, entry := range entries {
		switch {
		case strings.HasPrefix(entry.Origin, "http://") ||
			strings.HasPrefix(entry.Origin, "https://"):
			chromiumRows = append(chromiumRows, []string{
				entry.Label, entry.Origin, entry.Username, entry.Password, "",
			})
			firefoxRows = append(firefoxRows, []string{
				entry.Origin, entry.Username, entry.Password, "",
			})
		default:
			appRows = append(appRows, []string{
				entry.Label, entry.Origin, entry.Username, entry.Password,
			})
		}
	}

	chromiumData, err := encodeCredentialCSV(
		[]string{"name", "url", "username", "password", "note"}, chromiumRows)
	if err != nil {
		return nil, 0, 0, err
	}
	firefoxData, err := encodeCredentialCSV(
		[]string{"url", "username", "password", "httpRealm"}, firefoxRows)
	if err != nil {
		return nil, 0, 0, err
	}
	appData, err := encodeCredentialCSV(
		[]string{"name", "origin", "username", "password"}, appRows)
	if err != nil {
		return nil, 0, 0, err
	}
	manifestData, err := json.MarshalIndent(credentialArchiveManifest{
		Format: credentialArchiveFormat, Version: 1,
		CreatedAt:    createdAt.UTC().Format(time.RFC3339),
		RestoreFiles: []string{credentialWebChromiumName, credentialAppName},
	}, "", "  ")
	if err != nil {
		return nil, 0, 0, err
	}
	readme := []byte("FUTO Keyboard password export\n\n" +
		"Restore the ZIP directly from FUTO Keyboard's Import passwords page.\n" +
		"For Chrome, Chromium, Edge, Brave and similar browsers, extract and import " +
		credentialWebChromiumName + ".\n" +
		"For Firefox, extract and import " + credentialWebFirefoxName + ".\n" +
		credentialAppName + " contains native and Android app accounts for FUTO only.\n\n" +
		"The CSV files contain plaintext passwords after extraction. Keep them private " +
		"and remove extracted copies after importing.\n")
	files := []credentialArchiveFile{
		{name: credentialArchiveManifestName, data: manifestData},
		{name: credentialWebChromiumName, data: chromiumData},
		{name: credentialWebFirefoxName, data: firefoxData},
		{name: credentialAppName, data: appData},
		{name: credentialArchiveReadmeName, data: readme},
	}
	return files, len(chromiumRows), len(appRows), nil
}

func writeCredentialZIP(path, password string, files []credentialArchiveFile) error {
	output, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	if err != nil {
		return err
	}
	succeeded := false
	defer func() {
		_ = output.Close()
		if !succeeded {
			_ = os.Remove(path)
		}
	}()

	archive := securezip.NewWriter(output)
	for _, file := range files {
		var target io.Writer
		if password == "" {
			target, err = archive.Create(file.name)
		} else {
			target, err = archive.Encrypt(file.name, password,
				securezip.AES256Encryption)
		}
		if err != nil {
			_ = archive.Close()
			return err
		}
		if _, err = target.Write(file.data); err != nil {
			_ = archive.Close()
			return err
		}
	}
	if err := archive.Close(); err != nil {
		return err
	}
	if err := output.Sync(); err != nil {
		return err
	}
	if err := output.Close(); err != nil {
		return err
	}
	succeeded = true
	return nil
}

func (service *service) exportCredentials(password string,
	timestamp time.Time) (credentialExportResult, error) {
	result := credentialExportResult{Protected: password != ""}
	if len(password) > 1024 || strings.IndexFunc(password, func(character rune) bool {
		return character == '\x00' || character == '\r' || character == '\n'
	}) >= 0 {
		return result, errors.New("export password is too long or contains unsupported characters")
	}
	entries, err := service.vault.snapshot()
	if err != nil {
		return result, err
	}
	files, websites, apps, err := buildCredentialArchive(entries, timestamp)
	for index := range entries {
		entries[index].Password = ""
	}
	if err != nil {
		return result, err
	}
	defer func() {
		for _, file := range files {
			zeroBytes(file.data)
		}
	}()

	directory := service.backupDirectory
	if directory == "" {
		directory = filepath.Join(service.documentsDir, "FUTO-Keyboard")
	}
	if err := os.MkdirAll(directory, 0o700); err != nil {
		return result, err
	}
	if err := os.Chmod(directory, 0o700); err != nil {
		return result, err
	}
	base := "FUTO-Passwords-" + timestamp.Format("2006-01-02_15-04-05")
	for sequence := 1; sequence <= 1000; sequence++ {
		name := base
		if sequence > 1 {
			name += "-" + strconv.Itoa(sequence)
		}
		path := filepath.Join(directory, name+".zip")
		err = writeCredentialZIP(path, password, files)
		if os.IsExist(err) {
			continue
		}
		if err != nil {
			return result, err
		}
		result.Path = path
		result.Websites = websites
		result.Apps = apps
		return result, nil
	}
	return result, errors.New("could not create a unique password-export filename")
}

func readCredentialArchiveFile(file *securezip.File,
	password string) ([]byte, error) {
	if file.UncompressedSize64 > 20*1024*1024 {
		return nil, errors.New("password CSV in ZIP is larger than 20 MB")
	}
	if file.IsEncrypted() {
		if password == "" {
			return nil, securezip.ErrPassword
		}
		file.SetPassword(password)
	}
	reader, err := file.Open()
	if err != nil {
		return nil, err
	}
	data, readErr := io.ReadAll(io.LimitReader(reader, 20*1024*1024+1))
	closeErr := reader.Close()
	if readErr != nil {
		return nil, readErr
	}
	if closeErr != nil {
		return nil, closeErr
	}
	if len(data) > 20*1024*1024 {
		zeroBytes(data)
		return nil, errors.New("password CSV in ZIP is larger than 20 MB")
	}
	return data, nil
}

func (store *vaultStore) importCredentialZIP(path,
	password string) (credentialImportResult, error) {
	result := credentialImportResult{Path: path, Source: "FUTO password ZIP"}
	archive, err := securezip.OpenReader(path)
	if err != nil {
		return result, err
	}
	defer archive.Close()
	wanted := map[string]bool{
		credentialArchiveManifestName: true,
		credentialWebChromiumName:     true,
		credentialAppName:             true,
	}
	contents := make(map[string][]byte)
	defer func() {
		for _, data := range contents {
			zeroBytes(data)
		}
	}()
	for _, file := range archive.File {
		if file.Name != filepath.Base(file.Name) || !wanted[file.Name] {
			continue
		}
		if _, duplicate := contents[file.Name]; duplicate {
			return result, errors.New("password ZIP contains duplicate files")
		}
		data, readErr := readCredentialArchiveFile(file, password)
		if readErr != nil {
			return result, readErr
		}
		contents[file.Name] = data
	}
	manifestData, ok := contents[credentialArchiveManifestName]
	if !ok {
		return result, errors.New("password ZIP is not a FUTO password export")
	}
	var manifest credentialArchiveManifest
	if err := json.Unmarshal(manifestData, &manifest); err != nil ||
		manifest.Format != credentialArchiveFormat || manifest.Version != 1 {
		return result, errors.New("password ZIP has an unsupported FUTO export format")
	}
	for _, name := range manifest.RestoreFiles {
		if name != credentialWebChromiumName && name != credentialAppName {
			return result, errors.New("password ZIP requests an unsafe restore file")
		}
		data, present := contents[name]
		if !present {
			return result, errors.New("password ZIP is missing a restore file")
		}
		part, importErr := store.importCSVReader(bytes.NewReader(data), path+"/"+name)
		if importErr != nil {
			return result, importErr
		}
		result.Imported += part.Imported
		result.Skipped += part.Skipped
	}
	return result, nil
}

type service struct {
	bus                      *dbus.Conn
	engine                   engineProcess
	codec                    *secureFileCodec
	learned                  *learnedStore
	history                  *historyStore
	urls                     *urlHistoryStore
	clipboard                *clipboardStore
	vault                    *vaultStore
	credentialIndex          *credentialMatchIndex
	content                  *contentManager
	vaultKeyPath             string
	vaultSessionMu           sync.Mutex
	vaultSessions            map[dbus.Sender]vaultSession
	vaultAuthRunMu           sync.Mutex
	vaultAuthMu              sync.Mutex
	vaultAuthPending         *vaultAuthenticationRequest
	clipboardGuardMu         sync.Mutex
	clipboardGuardText       string
	clipboardGuardUntil      time.Time
	soundSlots               chan struct{}
	soundSinkMu              sync.Mutex
	soundSink                string
	soundSinkChecked         time.Time
	voiceMu                  sync.Mutex
	voiceWorkMu              sync.Mutex
	voiceRecording           *voiceRecording
	voiceTranscription       *exec.Cmd
	voiceTranscriptionCancel context.CancelFunc
	voiceDirectory           string
	backupDirectory          string
	backupPath               string
	documentsDir             string
}

type voiceRecording struct {
	command *exec.Cmd
	file    *os.File
	path    string
	started time.Time
}

type voiceActivity struct {
	DurationMillis        int  `json:"duration_ms"`
	SpeechDetected        bool `json:"speech_detected"`
	TrailingSilenceMillis int  `json:"trailing_silence_ms"`
}

type voiceInputUpdate struct {
	Recording             bool   `json:"recording"`
	Final                 bool   `json:"final"`
	Text                  string `json:"text"`
	SpeechDetected        bool   `json:"speech_detected"`
	DurationMillis        int    `json:"duration_ms"`
	TrailingSilenceMillis int    `json:"trailing_silence_ms"`
}

type vaultSession struct {
	Token   string
	Expires time.Time
}

type vaultAuthenticationRequest struct {
	Nonce  string
	Result chan bool
}

func (service *service) connectionPID(name string) (uint32, error) {
	if service.bus == nil || name == "" {
		return 0, errors.New("D-Bus connection is unavailable")
	}
	var pid uint32
	call := service.bus.BusObject().Call(
		"org.freedesktop.DBus.GetConnectionUnixProcessID", 0, name)
	if call.Err != nil {
		return 0, call.Err
	}
	if err := call.Store(&pid); err != nil {
		return 0, err
	}
	return pid, nil
}

// Only the root-owned Settings and Maliit processes may request a vault
// session.  Their well-known names cannot be claimed by an unrelated app while
// the real processes own them, and the unique D-Bus caller must resolve to the
// same kernel PID.
func (service *service) trustedNamedVaultCaller(sender dbus.Sender, name string) bool {
	callerPID, err := service.connectionPID(string(sender))
	if err != nil || callerPID == 0 {
		return false
	}
	trustedPID, trustedErr := service.connectionPID(name)
	return trustedErr == nil && trustedPID == callerPID
}

func (service *service) trustedVaultCaller(sender dbus.Sender) bool {
	for _, name := range []string{"com.jolla.settings", "com.jolla.keyboard"} {
		if service.trustedNamedVaultCaller(sender, name) {
			return true
		}
	}
	return false
}

func (service *service) finishVaultAuthentication(
	sender dbus.Sender, nonce string, approved bool) (bool, *dbus.Error) {
	if !service.trustedNamedVaultCaller(sender, "com.jolla.settings") {
		return false, nil
	}
	service.vaultAuthMu.Lock()
	pending := service.vaultAuthPending
	if pending == nil || nonce == "" || pending.Nonce != nonce {
		service.vaultAuthMu.Unlock()
		return false, nil
	}
	select {
	case pending.Result <- approved:
	default:
	}
	service.vaultAuthMu.Unlock()
	return true, nil
}

func (service *service) CompleteVaultAuthentication(
	sender dbus.Sender, nonce string) (bool, *dbus.Error) {
	return service.finishVaultAuthentication(sender, nonce, true)
}

func (service *service) CancelVaultAuthentication(
	sender dbus.Sender, nonce string) (bool, *dbus.Error) {
	return service.finishVaultAuthentication(sender, nonce, false)
}

// AuthenticateVaultForKeyboard lets the trusted Settings process display the
// single Sailfish Secrets/device-lock interaction required by a keyboard
// request.  The keyboard then receives a caller-bound session without asking
// Sailfish Secrets for the same key a second time.
func (service *service) AuthenticateVaultForKeyboard(
	sender dbus.Sender, nonce string) (bool, *dbus.Error) {
	if !service.trustedNamedVaultCaller(sender, "com.jolla.settings") {
		return false, dbus.MakeFailedError(errors.New("trusted Settings access required"))
	}
	service.vaultAuthMu.Lock()
	pending := service.vaultAuthPending
	valid := pending != nil && nonce != "" && pending.Nonce == nonce
	service.vaultAuthMu.Unlock()
	if !valid {
		return false, dbus.MakeFailedError(errors.New("vault authentication request expired"))
	}

	create := !encryptedPath(service.vault.path)
	operation := "get"
	if create {
		operation = "ensure"
	}
	key, err := secretToolKey(operation, "vault")
	if err == nil {
		err = service.vault.open(key, create)
	}
	zeroBytes(key)
	if err != nil {
		_, _ = service.finishVaultAuthentication(sender, nonce, false)
		return false, dbus.MakeFailedError(err)
	}
	approved, dbusErr := service.finishVaultAuthentication(sender, nonce, true)
	if dbusErr != nil || !approved {
		service.vault.lock()
	}
	return approved, dbusErr
}

func (service *service) PendingVaultAuthentication(
	sender dbus.Sender) (string, *dbus.Error) {
	if !service.trustedNamedVaultCaller(sender, "com.jolla.settings") {
		return "", nil
	}
	service.vaultAuthMu.Lock()
	defer service.vaultAuthMu.Unlock()
	if service.vaultAuthPending == nil {
		return "", nil
	}
	return service.vaultAuthPending.Nonce, nil
}

func (service *service) authenticateVault(sender dbus.Sender) error {
	if !service.trustedVaultCaller(sender) {
		return errors.New("password vault access is restricted to FUTO Settings and the keyboard")
	}
	if service.trustedNamedVaultCaller(sender, "com.jolla.settings") {
		return errors.New("Settings must use its in-page device authentication flow")
	}

	// Ask Sailfish's registered graphical authentication agent directly for the
	// Maliit process that made this trusted D-Bus call.  This produces the stock
	// phone-code/fingerprint overlay above the current app; the former Settings
	// broker opened an unrelated application window before showing the same
	// challenge and broke the login flow's visual continuity.
	callerPID, err := service.connectionPID(string(sender))
	if err != nil || callerPID == 0 {
		return errors.New("could not identify the keyboard for device authentication")
	}
	return service.authenticateVaultPID(callerPID)
}

func (service *service) authenticateVaultPID(callerPID uint32) error {
	return service.authenticateVaultPIDForAction(callerPID, vaultAuthAction)
}

func (service *service) authenticateVaultPIDForAction(callerPID uint32, actionID string) error {
	if callerPID == 0 {
		return errors.New("could not identify the keyboard for device authentication")
	}
	if actionID != vaultAuthAction && actionID != vaultSaveAuthAction {
		return errors.New("unsupported vault authorization action")
	}

	service.vaultAuthRunMu.Lock()
	defer service.vaultAuthRunMu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), 135*time.Second)
	defer cancel()
	command := exec.CommandContext(ctx, "/usr/bin/pkcheck",
		"--action-id", actionID,
		"--process", fmt.Sprintf("%d", callerPID),
		"--allow-user-interaction")
	if err := command.Run(); err != nil {
		if errors.Is(ctx.Err(), context.DeadlineExceeded) {
			return errors.New("device authentication timed out")
		}
		return errors.New("device security-code authentication was canceled or failed")
	}
	return nil
}

func (service *service) expireVaultSessionsLocked(now time.Time) {
	for sender, session := range service.vaultSessions {
		if !now.Before(session.Expires) {
			delete(service.vaultSessions, sender)
		}
	}
}

func (service *service) createVaultSession(sender dbus.Sender) (string, error) {
	token, err := randomID()
	if err != nil {
		return "", err
	}
	service.vaultSessionMu.Lock()
	service.expireVaultSessionsLocked(time.Now())
	service.vaultSessions[sender] = vaultSession{
		Token: token, Expires: time.Now().Add(vaultUnlockDuration),
	}
	service.vaultSessionMu.Unlock()
	go service.expireVaultSession(sender, token)
	return token, nil
}

// expireVaultSession guarantees that decrypted vault material is removed even
// when the authorized client disconnects and makes no subsequent D-Bus call.
// The loop follows a session whose expiry was extended by legitimate activity;
// a replacement token gets its own goroutine.
func (service *service) expireVaultSession(sender dbus.Sender, token string) {
	for {
		service.vaultSessionMu.Lock()
		session, ok := service.vaultSessions[sender]
		if !ok || session.Token != token {
			service.vaultSessionMu.Unlock()
			return
		}
		remaining := time.Until(session.Expires)
		if remaining > 0 {
			service.vaultSessionMu.Unlock()
			time.Sleep(remaining)
			continue
		}
		delete(service.vaultSessions, sender)
		noSessions := len(service.vaultSessions) == 0
		service.vaultSessionMu.Unlock()
		if noSessions {
			service.vault.lock()
		}
		return
	}
}

func (service *service) validateVaultSession(sender dbus.Sender, token string) error {
	now := time.Now()
	service.vaultSessionMu.Lock()
	service.expireVaultSessionsLocked(now)
	session, ok := service.vaultSessions[sender]
	if ok && token != "" && session.Token == token {
		session.Expires = now.Add(vaultUnlockDuration)
		service.vaultSessions[sender] = session
		service.vaultSessionMu.Unlock()
		return nil
	}
	noSessions := len(service.vaultSessions) == 0
	service.vaultSessionMu.Unlock()
	if noSessions {
		service.vault.lock()
	}
	return errors.New("password vault authorization expired")
}

func (service *service) closeVaultSession(sender dbus.Sender, token string) {
	service.vaultSessionMu.Lock()
	session, ok := service.vaultSessions[sender]
	if ok && (token == "" || session.Token == token) {
		delete(service.vaultSessions, sender)
	}
	service.expireVaultSessionsLocked(time.Now())
	noSessions := len(service.vaultSessions) == 0
	service.vaultSessionMu.Unlock()
	if noSessions {
		service.vault.lock()
	}
}

func keySoundPath(kind string, volume int32) (string, bool) {
	name := ""
	switch kind {
	case "letter":
		name = "keyboard_letter"
	case "option":
		name = "keyboard_option"
	case "enter":
		name = "pulldown_highlight"
	default:
		return "", false
	}
	if volume < 10 {
		volume = 10
	} else if volume > 100 {
		volume = 100
	}
	volume = ((volume + 5) / 10) * 10
	return filepath.Join(soundDir, fmt.Sprintf("%s-%d.wav", name, volume)), true
}

func choosePulseAudioOutputSink(defaultSink, sinkList string) string {
	defaultSink = strings.TrimSpace(defaultSink)
	if defaultSink != "" && defaultSink != "sink.null" {
		return defaultSink
	}
	running := ""
	primary := ""
	fallback := ""
	for _, line := range strings.Split(sinkList, "\n") {
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		name := fields[1]
		if name == "sink.null" {
			continue
		}
		if fallback == "" {
			fallback = name
		}
		if strings.Contains(name, "primary_output") {
			primary = name
		}
		if len(fields) >= 5 && fields[len(fields)-1] == "RUNNING" {
			running = name
		}
	}
	if running != "" {
		return running
	}
	if primary != "" {
		return primary
	}
	return fallback
}

func pulseAudioOutputSink() string {
	if !regularFileAvailable("/usr/bin/pactl") {
		return ""
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	info, infoErr := exec.CommandContext(ctx, "/usr/bin/pactl", "info").Output()
	defaultSink := ""
	if infoErr == nil {
		for _, line := range strings.Split(string(info), "\n") {
			if strings.HasPrefix(strings.TrimSpace(line), "Default Sink:") {
				defaultSink = strings.TrimSpace(strings.TrimPrefix(
					strings.TrimSpace(line), "Default Sink:"))
				break
			}
		}
	}
	if defaultSink != "" && defaultSink != "sink.null" {
		return defaultSink
	}
	list, listErr := exec.CommandContext(ctx, "/usr/bin/pactl", "list", "short", "sinks").Output()
	if listErr != nil {
		return ""
	}
	return choosePulseAudioOutputSink(defaultSink, string(list))
}

func (service *service) keySoundOutputSink() string {
	service.soundSinkMu.Lock()
	defer service.soundSinkMu.Unlock()
	if !service.soundSinkChecked.IsZero() &&
		time.Since(service.soundSinkChecked) < 10*time.Second {
		return service.soundSink
	}
	service.soundSink = pulseAudioOutputSink()
	service.soundSinkChecked = time.Now()
	return service.soundSink
}

// PlayKeySound keeps audio out of the Maliit process. QSoundEffect created
// long-lived streams there and could take down every virtual keyboard. paplay
// is short-lived and can fail without affecting text input.  Do not assign a
// media role here: Sailfish's audio policy can silently reroute or suppress
// those very short streams while an editor is active.  Selecting the physical
// sink explicitly is what bypasses the ringtone/silent-profile null sink. The
// bounded slots also prevent a held key from creating unbounded processes.
func (service *service) PlayKeySound(kind string, volume int32) (bool, *dbus.Error) {
	path, ok := keySoundPath(kind, volume)
	if !ok {
		return false, nil
	}
	select {
	case service.soundSlots <- struct{}{}:
	default:
		return false, nil
	}

	arguments := make([]string, 0, 2)
	if sink := service.keySoundOutputSink(); sink != "" {
		arguments = append(arguments, "--device="+sink)
	}
	arguments = append(arguments, path)
	command := exec.Command("/usr/bin/paplay", arguments...)
	command.Stdout = io.Discard
	command.Stderr = io.Discard
	if err := command.Start(); err != nil {
		<-service.soundSlots
		return false, nil
	}
	go func() {
		_ = command.Wait()
		<-service.soundSlots
	}()
	return true, nil
}

func voiceLanguageCodes(languagesCSV string) string {
	mapping := map[string]string{
		"EN": "en", "EN_GB": "en", "NL": "nl", "TR": "tr", "DE": "de",
		"FR": "fr", "ES": "es", "IT": "it", "PT_BR": "pt", "PT_PT": "pt",
		"SV": "sv", "NB": "no", "DA": "da", "FI": "fi", "PL": "pl",
		"CS": "cs", "RO": "ro", "SL": "sl", "HR": "hr", "LV": "lv", "LT": "lt",
		"EL": "el", "RU": "ru", "SR": "sr", "SR_LATN": "sr",
	}
	seen := make(map[string]bool)
	result := make([]string, 0, 4)
	for _, language := range normalizeLanguages(languagesCSV) {
		code := mapping[language]
		if code != "" && !seen[code] {
			seen[code] = true
			result = append(result, code)
		}
	}
	if len(result) == 0 {
		return "en"
	}
	return strings.Join(result, ",")
}

func regularFileAvailable(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.Mode().IsRegular() && info.Size() > 0
}

func pulseAudioInputSource() string {
	if !regularFileAvailable("/usr/bin/pactl") {
		return ""
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	output, err := exec.CommandContext(ctx, "/usr/bin/pactl", "list", "short", "sources").Output()
	if err != nil {
		return ""
	}
	fallback := ""
	for _, line := range strings.Split(string(output), "\n") {
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		name := fields[1]
		lower := strings.ToLower(name)
		if strings.HasSuffix(lower, ".monitor") || strings.Contains(lower, "source.null") {
			continue
		}
		if strings.Contains(lower, "primary_input") {
			return name
		}
		if fallback == "" {
			fallback = name
		}
	}
	return fallback
}

func (service *service) VoiceStatus() (string, *dbus.Error) {
	service.voiceMu.Lock()
	recording := service.voiceRecording != nil
	transcribing := service.voiceTranscription != nil
	service.voiceMu.Unlock()
	_, parecErr := os.Stat("/usr/bin/parec")
	inputSource := pulseAudioInputSource()
	status := map[string]interface{}{
		"available":    regularFileAvailable(voicePath) && resolvedVoiceModelPath() != "" && parecErr == nil && inputSource != "",
		"recording":    recording,
		"transcribing": transcribing,
		"offline":      true,
		"model":        "FUTO Multilingual-39",
		"source":       inputSource,
	}
	data, err := json.Marshal(status)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return string(data), nil
}

func (service *service) StartVoiceInput(languagesCSV string) (bool, *dbus.Error) {
	inputSource := pulseAudioInputSource()
	if !regularFileAvailable(voicePath) || resolvedVoiceModelPath() == "" ||
		!regularFileAvailable("/usr/bin/parec") || inputSource == "" {
		return false, nil
	}
	service.voiceMu.Lock()
	defer service.voiceMu.Unlock()
	if service.voiceRecording != nil || service.voiceTranscription != nil {
		return false, nil
	}
	if err := os.MkdirAll(service.voiceDirectory, 0o700); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	file, err := os.CreateTemp(service.voiceDirectory, "voice-*.pcm")
	if err != nil {
		return false, dbus.MakeFailedError(err)
	}
	_ = file.Chmod(0o600)
	command := exec.Command("/usr/bin/parec", "--device="+inputSource,
		"--raw", "--format=s16le",
		"--rate=16000", "--channels=1", "--client-name=FUTO Keyboard",
		"--stream-name=Voice typing", "--property=media.role=phone")
	command.Stdout = file
	command.Stderr = io.Discard
	if err := command.Start(); err != nil {
		_ = file.Close()
		_ = os.Remove(file.Name())
		return false, nil
	}
	service.voiceRecording = &voiceRecording{
		command: command, file: file, path: file.Name(), started: time.Now(),
	}
	_ = languagesCSV // Language selection is applied when transcription starts.
	return true, nil
}

func finishVoiceRecorder(recording *voiceRecording) {
	if recording == nil {
		return
	}
	if recording.command != nil && recording.command.Process != nil {
		_ = recording.command.Process.Signal(os.Interrupt)
		done := make(chan struct{})
		go func() {
			_ = recording.command.Wait()
			close(done)
		}()
		select {
		case <-done:
		case <-time.After(2 * time.Second):
			_ = recording.command.Process.Kill()
			<-done
		}
	}
	if recording.file != nil {
		_ = recording.file.Close()
	}
}

func (service *service) takeVoiceRecording() *voiceRecording {
	service.voiceMu.Lock()
	defer service.voiceMu.Unlock()
	recording := service.voiceRecording
	service.voiceRecording = nil
	return recording
}

func (service *service) CancelVoiceInput() (bool, *dbus.Error) {
	recording := service.takeVoiceRecording()
	service.voiceMu.Lock()
	transcription := service.voiceTranscription
	transcriptionCancel := service.voiceTranscriptionCancel
	service.voiceTranscription = nil
	service.voiceTranscriptionCancel = nil
	service.voiceMu.Unlock()
	if transcriptionCancel != nil {
		transcriptionCancel()
	}
	if transcription != nil && transcription.Process != nil {
		_ = transcription.Process.Kill()
	}
	if recording == nil {
		if transcription != nil {
			return true, nil
		}
		return false, nil
	}
	finishVoiceRecorder(recording)
	_ = os.Remove(recording.path)
	return true, nil
}

func analyzeVoiceActivity(data []byte) voiceActivity {
	const (
		sampleRate       = 16000
		blockSamples     = sampleRate / 10 // 100 ms
		speechThreshold  = 0.0065
		minimumSpeechRun = 2
	)
	if len(data)%2 != 0 {
		data = data[:len(data)-1]
	}
	sampleCount := len(data) / 2
	result := voiceActivity{DurationMillis: sampleCount * 1000 / sampleRate}
	fullBlocks := sampleCount / blockSamples
	lastSpeechBlock := -1
	speechBlocks := 0
	for block := 0; block < fullBlocks; block++ {
		energy := 0.0
		start := block * blockSamples
		for index := 0; index < blockSamples; index++ {
			offset := (start + index) * 2
			raw := uint16(data[offset]) | uint16(data[offset+1])<<8
			sample := float64(int16(raw)) / 32768.0
			energy += sample * sample
		}
		rms := math.Sqrt(energy / float64(blockSamples))
		if rms >= speechThreshold {
			speechBlocks++
			lastSpeechBlock = block
		}
	}
	result.SpeechDetected = speechBlocks >= minimumSpeechRun
	if result.SpeechDetected && lastSpeechBlock >= 0 {
		lastSpeechEnd := (lastSpeechBlock + 1) * 100
		result.TrailingSilenceMillis = result.DurationMillis - lastSpeechEnd
		if result.TrailingSilenceMillis < 0 {
			result.TrailingSilenceMillis = 0
		}
	}
	return result
}

func voiceSnapshot(path, directory string) (string, []byte, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", nil, err
	}
	if len(data)%2 != 0 {
		data = data[:len(data)-1]
	}
	if len(data) > 1920000 {
		data = data[:1920000]
	}
	file, err := os.CreateTemp(directory, "voice-preview-*.pcm")
	if err != nil {
		return "", nil, err
	}
	previewPath := file.Name()
	_ = file.Chmod(0o600)
	if _, err = file.Write(data); err != nil {
		_ = file.Close()
		_ = os.Remove(previewPath)
		return "", nil, err
	}
	if err = file.Close(); err != nil {
		_ = os.Remove(previewPath)
		return "", nil, err
	}
	return previewPath, data, nil
}

func (service *service) runVoiceTranscription(path, languagesCSV string,
	timeout time.Duration) (string, error) {
	service.voiceWorkMu.Lock()
	defer service.voiceWorkMu.Unlock()
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	modelPath := resolvedVoiceModelPath()
	if modelPath == "" {
		return "", errors.New("offline voice model is not installed")
	}
	command := exec.CommandContext(ctx, voicePath, modelPath,
		path, voiceLanguageCodes(languagesCSV))
	command.Stderr = io.Discard
	service.voiceMu.Lock()
	if service.voiceTranscription != nil {
		service.voiceMu.Unlock()
		return "", errors.New("voice transcription is already running")
	}
	service.voiceTranscription = command
	service.voiceTranscriptionCancel = cancel
	service.voiceMu.Unlock()
	output, err := command.Output()
	service.voiceMu.Lock()
	if service.voiceTranscription == command {
		service.voiceTranscription = nil
		service.voiceTranscriptionCancel = nil
	}
	service.voiceMu.Unlock()
	if ctx.Err() == context.DeadlineExceeded {
		return "", errors.New("voice transcription timed out")
	}
	if err != nil {
		return "", errors.New("voice transcription failed")
	}
	text := strings.TrimSpace(string(output))
	if utf8.RuneCountInString(text) > 4096 {
		return "", errors.New("voice transcription was too long")
	}
	return text, nil
}

func (service *service) finishVoiceInput(languagesCSV string) (string, error) {
	recording := service.takeVoiceRecording()
	if recording == nil {
		return "", nil
	}
	finishVoiceRecorder(recording)
	defer os.Remove(recording.path)
	if time.Since(recording.started) < 300*time.Millisecond {
		return "", nil
	}
	return service.runVoiceTranscription(recording.path, languagesCSV, 90*time.Second)
}

func (service *service) StopVoiceInput(languagesCSV string) (string, *dbus.Error) {
	text, err := service.finishVoiceInput(languagesCSV)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return text, nil
}

func marshalVoiceInputUpdate(update voiceInputUpdate) (string, *dbus.Error) {
	data, err := json.Marshal(update)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return string(data), nil
}

// VoiceInputUpdate returns a private on-device partial transcription.  Once
// speech has been followed by the configured amount of silence, it also stops
// the recorder and returns the final text, so QML never needs a second tap.
func (service *service) VoiceInputUpdate(languagesCSV string,
	silenceTimeoutMillis int32) (string, *dbus.Error) {
	manualStop := silenceTimeoutMillis <= 0
	if !manualStop && silenceTimeoutMillis < 800 {
		silenceTimeoutMillis = 800
	} else if silenceTimeoutMillis > 3000 {
		silenceTimeoutMillis = 3000
	}
	service.voiceMu.Lock()
	recording := service.voiceRecording
	service.voiceMu.Unlock()
	if recording == nil {
		return marshalVoiceInputUpdate(voiceInputUpdate{})
	}

	previewPath, data, err := voiceSnapshot(recording.path, service.voiceDirectory)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	defer os.Remove(previewPath)
	activity := analyzeVoiceActivity(data)
	update := voiceInputUpdate{
		Recording:             true,
		SpeechDetected:        activity.SpeechDetected,
		DurationMillis:        activity.DurationMillis,
		TrailingSilenceMillis: activity.TrailingSilenceMillis,
	}
	hardLimitMillis := 30000
	noSpeechLimitMillis := 10000
	if manualStop {
		// Continuous tap-to-stop and push-to-talk sessions must not end merely
		// because the speaker pauses.  Retain generous safety limits so an
		// abandoned recorder cannot run forever.
		hardLimitMillis = 300000
		noSpeechLimitMillis = 60000
	}
	autoFinish := activity.DurationMillis >= hardLimitMillis ||
		(!activity.SpeechDetected && activity.DurationMillis >= noSpeechLimitMillis) ||
		(!manualStop && activity.SpeechDetected && activity.DurationMillis >= 1000 &&
			activity.TrailingSilenceMillis >= int(silenceTimeoutMillis))
	if autoFinish {
		service.voiceMu.Lock()
		if service.voiceRecording != recording {
			service.voiceMu.Unlock()
			update.Recording = false
			return marshalVoiceInputUpdate(update)
		}
		service.voiceRecording = nil
		service.voiceMu.Unlock()
		finishVoiceRecorder(recording)
		defer os.Remove(recording.path)
		text, transcriptionErr := service.runVoiceTranscription(recording.path,
			languagesCSV, 90*time.Second)
		if transcriptionErr != nil {
			return "", dbus.MakeFailedError(transcriptionErr)
		}
		update.Recording = false
		update.Final = true
		update.Text = text
		return marshalVoiceInputUpdate(update)
	}
	if !activity.SpeechDetected || activity.DurationMillis < 800 || len(data) < 9600 {
		return marshalVoiceInputUpdate(update)
	}
	text, transcriptionErr := service.runVoiceTranscription(previewPath,
		languagesCSV, 20*time.Second)
	if transcriptionErr != nil {
		return "", dbus.MakeFailedError(transcriptionErr)
	}
	service.voiceMu.Lock()
	update.Recording = service.voiceRecording == recording
	service.voiceMu.Unlock()
	if update.Recording {
		update.Text = text
	}
	return marshalVoiceInputUpdate(update)
}

func normalizeLanguage(language string) (string, bool) {
	language = strings.ToUpper(strings.TrimSpace(language))
	for _, supported := range supportedLanguages {
		if language == supported.Code {
			return language, true
		}
	}
	return "", false
}

func normalizeLanguages(value string) []string {
	seen := make(map[string]bool)
	result := make([]string, 0, len(supportedLanguages))
	for _, candidate := range strings.Split(value, ",") {
		language, ok := normalizeLanguage(candidate)
		if ok && !seen[language] {
			seen[language] = true
			result = append(result, language)
		}
	}
	if len(result) == 0 {
		return []string{"EN"}
	}
	return result
}

func languageRuneBonus(language, word string) int64 {
	if language == "EL" || language == "RU" || language == "SR" {
		script := unicode.Greek
		if language == "RU" || language == "SR" {
			script = unicode.Cyrillic
		}
		var bonus int64
		for _, character := range word {
			if unicode.Is(script, character) {
				bonus += 350000000
			}
		}
		return bonus
	}
	sets := map[string]string{
		"TR":      "çğıöşüÇĞİÖŞÜ",
		"DE":      "äöüßÄÖÜẞ",
		"FR":      "àâæçéèêëîïôœùûüÿÀÂÆÇÉÈÊËÎÏÔŒÙÛÜŸ",
		"ES":      "áéíñóúüÁÉÍÑÓÚÜ",
		"IT":      "àèéìíîòóùúÀÈÉÌÍÎÒÓÙÚ",
		"PT_BR":   "áâãàçéêíóôõúüÁÂÃÀÇÉÊÍÓÔÕÚÜ",
		"PT_PT":   "áâãàçéêíóôõúÁÂÃÀÇÉÊÍÓÔÕÚ",
		"SV":      "åäöÅÄÖ",
		"NB":      "æøåÆØÅ",
		"DA":      "æøåÆØÅ",
		"FI":      "äöÄÖ",
		"PL":      "ąćęłńóśźżĄĆĘŁŃÓŚŹŻ",
		"CS":      "áčďéěíňóřšťúůýžÁČĎÉĚÍŇÓŘŠŤÚŮÝŽ",
		"RO":      "ăâîșşțţĂÂÎȘŞȚŢ",
		"SL":      "čšžČŠŽ",
		"HR":      "čćđšžČĆĐŠŽ",
		"SR_LATN": "čćđšžČĆĐŠŽ",
		"LV":      "āčēģīķļņšūžĀČĒĢĪĶĻŅŠŪŽ",
		"LT":      "ąčęėįšųūžĄČĘĖĮŠŲŪŽ",
		"NL":      "ĳĲ",
	}
	characters := sets[language]
	if characters == "" {
		return 0
	}
	var bonus int64
	for _, character := range word {
		if strings.ContainsRune(characters, character) {
			bonus += 350000000
		}
	}
	return bonus
}

func compoundParts(word string) (string, string) {
	lastEnd := -1
	for index, character := range word {
		if character == '-' || character == '\'' || character == '’' {
			lastEnd = index + utf8.RuneLen(character)
		}
	}
	if lastEnd < 0 || lastEnd >= len(word) {
		return "", word
	}
	return word[:lastEnd], word[lastEnd:]
}

func capitalizeWord(word string) string {
	runes := []rune(word)
	if len(runes) > 0 {
		runes[0] = unicode.ToUpper(runes[0])
	}
	return string(runes)
}

func matchTypedCase(candidate, typed string) string {
	if candidate == "" || typed == "" {
		return candidate
	}
	typedRunes := []rune(typed)
	letterCount := 0
	upperCount := 0
	for _, character := range typedRunes {
		if unicode.IsLetter(character) {
			letterCount++
			if unicode.IsUpper(character) {
				upperCount++
			}
		}
	}
	if letterCount > 1 && upperCount == letterCount {
		return strings.ToUpper(candidate)
	}
	if len(typedRunes) > 0 && unicode.IsUpper(typedRunes[0]) {
		return capitalizeWord(candidate)
	}
	return candidate
}

func validWord(word string) bool {
	if word == "" || strings.ContainsAny(word, "\t\r\n") || !utf8.ValidString(word) {
		return false
	}
	count := 0
	for _, character := range word {
		count++
		if !(unicode.IsLetter(character) || character == '\'' || character == '-' || character == '’') {
			return false
		}
	}
	return count > 0 && count <= 48
}

func (service *service) withoutSuppressed(words []string) []string {
	filtered := make([]string, 0, len(words))
	for _, word := range words {
		if !service.history.isSuppressed(word) {
			filtered = append(filtered, word)
		}
	}
	return filtered
}

func mergeSuggestions(typed string, personal, dictionary []string, maximum int) []string {
	result := make([]string, 0, maximum)
	seen := make(map[string]bool)
	appendWord := func(word string) {
		if len(result) >= maximum || word == "" || seen[word] {
			return
		}
		seen[word] = true
		result = append(result, word)
	}
	appendWord(typed)
	for _, word := range personal {
		appendWord(word)
	}
	for _, word := range dictionary {
		appendWord(word)
	}
	return result
}

func correctionThresholds(wordLength, level int) (int, int) {
	if level < 0 {
		level = 0
	} else if level > 2 {
		level = 2
	}
	minimums := [3][3]int{
		{170, 130, 90},
		{155, 115, 75},
		{140, 100, 60},
	}
	margins := [3][2]int{
		{15, 10},
		{10, 7},
		{5, 3},
	}
	lengthBucket := 2
	if wordLength == 3 {
		lengthBucket = 0
	} else if wordLength == 4 {
		lengthBucket = 1
	}
	marginBucket := 1
	if wordLength <= 4 {
		marginBucket = 0
	}
	return minimums[level][lengthBucket], margins[level][marginBucket]
}

func chooseCorrection(candidates []correctionWord, word string, level int) string {
	if len(candidates) == 0 {
		return ""
	}
	bestByWord := make(map[string]correctionWord)
	for _, candidate := range candidates {
		key := strings.ToLower(candidate.Word)
		if candidate.Word == "" || key == strings.ToLower(word) {
			continue
		}
		if current, ok := bestByWord[key]; !ok || candidate.Score > current.Score {
			bestByWord[key] = candidate
		}
	}
	merged := make([]correctionWord, 0, len(bestByWord))
	for _, candidate := range bestByWord {
		merged = append(merged, candidate)
	}
	sort.Slice(merged, func(i, j int) bool {
		if merged[i].Score != merged[j].Score {
			return merged[i].Score > merged[j].Score
		}
		return len(merged[i].Word) < len(merged[j].Word)
	})
	if len(merged) == 0 {
		return ""
	}
	minimum, margin := correctionThresholds(utf8.RuneCountInString(word), level)
	if merged[0].Score < minimum {
		return ""
	}
	if len(merged) > 1 && merged[0].Score-merged[1].Score < margin {
		return ""
	}
	return merged[0].Word
}

func mergeRankedSuggestions(typed string, showTyped bool, personal []string,
	candidates []scoredWord, maximum int) []string {
	sort.SliceStable(candidates, func(i, j int) bool {
		if candidates[i].Score != candidates[j].Score {
			return candidates[i].Score > candidates[j].Score
		}
		return len(candidates[i].Word) < len(candidates[j].Word)
	})
	result := make([]string, 0, maximum)
	seen := make(map[string]bool)
	appendWord := func(word string) {
		key := strings.ToLower(word)
		if len(result) >= maximum || word == "" || seen[key] {
			return
		}
		seen[key] = true
		result = append(result, word)
	}
	if showTyped {
		appendWord(typed)
	}
	for _, word := range personal {
		appendWord(word)
	}
	for _, candidate := range candidates {
		appendWord(candidate.Word)
	}
	return result
}

func (service *service) Suggest(language, word string, limit int32) ([]string, *dbus.Error) {
	language, ok := normalizeLanguage(language)
	if !ok || !validWord(word) {
		return []string{}, nil
	}
	if limit < 1 {
		limit = 1
	} else if limit > 20 {
		limit = 20
	}
	dictionary, err := service.engine.suggest(language, word, limit)
	if err != nil {
		return nil, dbus.MakeFailedError(err)
	}
	dictionary = service.withoutSuppressed(dictionary)
	personal := service.withoutSuppressed(
		service.learned.matches(language, word, int(limit)))
	return mergeSuggestions(word, personal, dictionary, int(limit)), nil
}

func (service *service) Correct(language, word string) (string, *dbus.Error) {
	language, ok := normalizeLanguage(language)
	if !ok || !validWord(word) || service.learned.contains(language, word) {
		return "", nil
	}
	correction, err := service.engine.correct(language, word)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	if service.history.isSuppressed(correction) {
		return "", nil
	}
	return correction, nil
}

func contextWords(context string) []string {
	return strings.FieldsFunc(context, func(character rune) bool {
		return !(unicode.IsLetter(character) || character == '\'' || character == '’' ||
			character == '-')
	})
}

func lastContextWord(context string) string {
	words := contextWords(context)
	if len(words) == 0 {
		return ""
	}
	return words[len(words)-1]
}

func (service *service) analyzeContext(languagesCSV, word, context string,
	limit, correctionLevel int32, showTyped, automaticLanguageDetection bool) (combinedAnalysis, error) {
	result := combinedAnalysis{Suggestions: []string{}}
	if !validWord(word) {
		return result, nil
	}
	if limit < 1 {
		limit = 1
	} else if limit > 20 {
		limit = 20
	}
	languages := normalizeLanguages(languagesCSV)
	previous := lastContextWord(context)
	allKnown := false
	ranked := make([]scoredWord, 0, int(limit)*len(languages))
	corrections := make([]correctionWord, 0, 8*len(languages))
	detectedLanguage := languages[0]
	bestLanguageScore := int64(-1)

	for _, language := range languages {
		analysis, err := service.engine.analyze(language, word, limit)
		if err != nil {
			return result, err
		}
		allKnown = allKnown || analysis.Known
		contextBonus := service.history.languageBonus(previous, language)
		runeBonus := languageRuneBonus(language, word)
		languageScore := contextBonus + runeBonus
		if analysis.Known {
			languageScore += 1000000000 + int64(stdMax(0, analysis.KnownScore))*1000000
		} else if len(analysis.Suggestions) > 0 {
			languageScore += analysis.Suggestions[0].Score / 10
		}
		if !automaticLanguageDetection {
			languageScore = 0
		}
		if languageScore > bestLanguageScore {
			bestLanguageScore = languageScore
			detectedLanguage = language
		}
		for _, candidate := range analysis.Suggestions {
			if service.history.isSuppressed(candidate.Word) {
				continue
			}
			candidate.Language = language
			if automaticLanguageDetection {
				candidate.Score += contextBonus + runeBonus
			}
			ranked = append(ranked, candidate)
		}
		for _, candidate := range analysis.Corrections {
			if service.history.isSuppressed(candidate.Word) {
				continue
			}
			candidate.Language = language
			if automaticLanguageDetection {
				candidate.Score += int(contextBonus/25000000 + runeBonus/350000000*25)
			}
			corrections = append(corrections, candidate)
		}
		for _, phrase := range analysis.Phrases {
			phrase = matchTypedCase(phrase, word)
			if phrase != "" && !strings.EqualFold(phrase, word) &&
				!service.history.isSuppressed(phrase) {
				ranked = append(ranked, scoredWord{Word: phrase,
					Score: 3900000000 + contextBonus + runeBonus, Language: language})
			}
		}
	}
	// If a complete contraction or hyphenated word is not in the dictionaries,
	// complete its final segment while retaining the already typed prefix.
	prefix, suffix := compoundParts(word)
	if !allKnown && prefix != "" && utf8.RuneCountInString(suffix) >= 2 {
		for _, language := range languages {
			analysis, err := service.engine.analyze(language, suffix, limit)
			if err != nil {
				return result, err
			}
			bonus := service.history.languageBonus(previous, language) +
				languageRuneBonus(language, suffix)
			for _, candidate := range analysis.Suggestions {
				candidate.Word = prefix + candidate.Word
				if service.history.isSuppressed(candidate.Word) {
					continue
				}
				candidate.Language = language
				candidate.Score += bonus - 50000000
				ranked = append(ranked, candidate)
			}
		}
	}
	for index := range ranked {
		ranked[index].Word = matchTypedCase(ranked[index].Word, word)
	}
	for index := range corrections {
		corrections[index].Word = matchTypedCase(corrections[index].Word, word)
	}

	personal := service.withoutSuppressed(
		service.learned.matchesLanguages(languages, word, int(limit)))
	for index := range personal {
		personal[index] = matchTypedCase(personal[index], word)
	}
	result.Suggestions = mergeRankedSuggestions(
		word, showTyped, personal, ranked, int(limit))
	result.Language = detectedLanguage
	if !allKnown && !service.learned.containsLanguages(languages, word) {
		result.Correction = chooseCorrection(corrections, word, int(correctionLevel))
	}
	return result, nil
}

func stdMax(left, right int) int {
	if left > right {
		return left
	}
	return right
}

func (service *service) Analyze(languagesCSV, word string, limit, correctionLevel int32,
	showTyped bool) (string, *dbus.Error) {
	return service.AnalyzeContext(languagesCSV, word, "", limit, correctionLevel,
		showTyped, true)
}

func (service *service) AnalyzeContext(languagesCSV, word, context string,
	limit, correctionLevel int32, showTyped, automaticLanguageDetection bool) (string, *dbus.Error) {
	result, err := service.analyzeContext(languagesCSV, word, context, limit,
		correctionLevel, showTyped, automaticLanguageDetection)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	data, err := json.Marshal(result)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return string(data), nil
}

func validSwipePayload(value string, maximum int) bool {
	return value != "" && len(value) <= maximum &&
		!strings.ContainsAny(value, "\t\r\n")
}

// SwipeSuggestions decodes a key-center trajectory entirely on-device.  The
// QML side supplies normalized coordinates from the active visual layout, so
// one decoder works for QWERTY, AZERTY, QWERTZ and the other Latin layouts.
func (service *service) SwipeSuggestions(languagesCSV, path, geometry, context string,
	limit int32, capitalize bool) (string, *dbus.Error) {
	result := swipeAnalysis{Suggestions: []string{}}
	if !validSwipePayload(path, 8192) || !validSwipePayload(geometry, 16384) {
		data, _ := json.Marshal(result)
		return string(data), nil
	}
	if limit < 1 {
		limit = 1
	} else if limit > 20 {
		limit = 20
	}
	languages := normalizeLanguages(languagesCSV)
	previous := lastContextWord(context)
	ranked := make([]scoredWord, 0, int(limit)*len(languages))
	for _, language := range languages {
		candidates, err := service.engine.swipe(language, path, geometry,
			limit, capitalize)
		if err != nil {
			// Enabled languages may intentionally have no downloaded dictionary.
			// Keep swipe results from the installed packs instead of discarding the
			// complete multilingual result when one optional pack is unavailable.
			if strings.Contains(err.Error(), "unknown language") {
				continue
			}
			return "", dbus.MakeFailedError(err)
		}
		bonus := service.history.languageBonus(previous, language)
		for _, candidate := range candidates {
			if service.history.isSuppressed(candidate.Word) {
				continue
			}
			candidate.Language = language
			candidate.Score += bonus + service.history.bigramBonus(previous, candidate.Word)
			ranked = append(ranked, candidate)
		}
	}
	sort.SliceStable(ranked, func(i, j int) bool {
		if ranked[i].Score != ranked[j].Score {
			return ranked[i].Score > ranked[j].Score
		}
		return len(ranked[i].Word) < len(ranked[j].Word)
	})
	seen := make(map[string]bool)
	for _, candidate := range ranked {
		key := strings.ToLower(candidate.Word)
		if candidate.Word == "" || seen[key] {
			continue
		}
		seen[key] = true
		if result.Language == "" {
			result.Language = candidate.Language
		}
		result.Suggestions = append(result.Suggestions, candidate.Word)
		if len(result.Suggestions) >= int(limit) {
			break
		}
	}
	data, err := json.Marshal(result)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return string(data), nil
}

func (service *service) NextWords(languagesCSV, context string, limit int32,
	capitalize bool) (string, *dbus.Error) {
	if limit < 1 {
		limit = 1
	} else if limit > 20 {
		limit = 20
	}
	languages := normalizeLanguages(languagesCSV)
	previous := lastContextWord(context)
	result := make([]string, 0, limit)
	seen := make(map[string]bool)
	appendWord := func(word string) {
		if capitalize {
			word = capitalizeWord(word)
		}
		key := strings.ToLower(word)
		if word == "" || service.history.isSuppressed(word) || seen[key] ||
			len(result) >= int(limit) {
			return
		}
		seen[key] = true
		result = append(result, word)
	}
	for _, word := range service.history.next(previous, int(limit)) {
		appendWord(word)
	}
	preferred := service.history.dominantLanguage(previous, languages)
	ordered := make([]string, 0, len(languages))
	if preferred != "" {
		ordered = append(ordered, preferred)
	}
	for _, language := range languages {
		if language != preferred {
			ordered = append(ordered, language)
		}
	}
	for _, language := range ordered {
		if len(result) >= int(limit) {
			break
		}
		words, err := service.engine.top(language, limit)
		if err != nil {
			return "", dbus.MakeFailedError(err)
		}
		for _, word := range words {
			appendWord(word)
		}
	}
	data, err := json.Marshal(result)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return string(data), nil
}

func (service *service) Accept(language, word string) (bool, *dbus.Error) {
	language, ok := normalizeLanguage(language)
	if !ok || !validWord(word) {
		return false, nil
	}
	if err := service.learned.accept(language, word); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	return true, nil
}

func (service *service) AcceptMulti(languagesCSV, word string) (bool, *dbus.Error) {
	if len(normalizeLanguages(languagesCSV)) == 0 || !validWord(word) {
		return false, nil
	}
	if err := service.learned.accept("MULTI", word); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	return true, nil
}

func (service *service) AcceptContext(languagesCSV, previous, word,
	language string) (bool, *dbus.Error) {
	languages := normalizeLanguages(languagesCSV)
	if !validWord(word) {
		return false, nil
	}
	normalizedLanguage, ok := normalizeLanguage(language)
	if !ok {
		normalizedLanguage = languages[0]
	}
	allowed := false
	for _, candidate := range languages {
		if candidate == normalizedLanguage {
			allowed = true
			break
		}
	}
	if !allowed {
		normalizedLanguage = languages[0]
	}
	if err := service.learned.accept("MULTI", word); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	if err := service.history.accept(previous, word, normalizedLanguage); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	return true, nil
}

func (service *service) RecordURL(value string) (bool, *dbus.Error) {
	recorded, err := service.urls.accept(value)
	if err != nil {
		return false, dbus.MakeFailedError(err)
	}
	return recorded, nil
}

func (service *service) SuggestURLs(prefix string, limit int32) (string, *dbus.Error) {
	data, err := json.Marshal(service.urls.suggest(prefix, int(limit)))
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return string(data), nil
}

func (service *service) ListURLs() (string, *dbus.Error) {
	data, err := json.Marshal(service.urls.list())
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return string(data), nil
}

// Explicit deletion must never fall back to a volatile in-memory change.  A
// helper started while the device-lock collection was closed can still serve
// its current in-memory suggestions, but it cannot persist their removal.
// Retry the noninteractive device-bound key first and, only for this explicit
// user action, allow Sailfish to request device authentication.  Reload the
// encrypted stores after opening the key so deletion is applied to the real
// persisted URL set rather than an empty locked-startup snapshot.
func (service *service) unlockLearnedDataForExplicitWrite() error {
	if service.codec.hasKey() {
		return nil
	}
	key, err := secretToolKey("get", "learned")
	if err != nil {
		key, err = secretToolKey("unlock", "learned")
	}
	if err != nil {
		return err
	}
	defer zeroBytes(key)
	if err := service.codec.setKey(key); err != nil {
		return err
	}
	if encryptedPath(service.learned.path) {
		if err := service.learned.reload(); err != nil {
			return err
		}
	}
	if encryptedPath(service.history.path) {
		if err := service.history.reload(); err != nil {
			return err
		}
	}
	if encryptedPath(service.urls.path) {
		if err := service.urls.reload(); err != nil {
			return err
		}
	}
	if encryptedPath(service.clipboard.path) {
		if err := service.clipboard.reload(); err != nil {
			return err
		}
	}
	return nil
}

func (service *service) RemoveURL(value string) (bool, *dbus.Error) {
	if err := service.unlockLearnedDataForExplicitWrite(); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	removed, err := service.urls.remove(value)
	if err != nil {
		return false, dbus.MakeFailedError(err)
	}
	return removed, nil
}

func (service *service) ClearURLs() (bool, *dbus.Error) {
	hadEntries := len(service.urls.snapshot()) > 0
	if err := service.urls.clear(); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	return hadEntries, nil
}

func (service *service) ListPersonalWords() (string, *dbus.Error) {
	data, err := json.Marshal(service.learned.list())
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return string(data), nil
}

func (service *service) AddPersonalWord(word string) (bool, *dbus.Error) {
	word = strings.TrimSpace(word)
	if !validWord(word) {
		return false, nil
	}
	if err := service.learned.addTrusted(word); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	return true, nil
}

func (service *service) RemovePersonalWord(word string) (bool, *dbus.Error) {
	if !validWord(word) {
		return false, nil
	}
	removed, err := service.learned.removeWord(word)
	if err != nil {
		return false, dbus.MakeFailedError(err)
	}
	return removed, nil
}

func (service *service) ClearPersonalWords() (bool, *dbus.Error) {
	hadWords := len(service.learned.list()) > 0
	if err := service.learned.clear(); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	return hadWords, nil
}

// ForgetWord removes learned data and suppresses the selected word from future
// results. Packaged dictionaries remain immutable; the encrypted suppression
// list is applied to dictionary, correction, next-word and swipe suggestions.
func (service *service) ForgetWord(word string) (bool, *dbus.Error) {
	if !validWord(word) {
		return false, nil
	}
	if err := service.unlockLearnedDataForExplicitWrite(); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	personalRemoved, err := service.learned.removeWord(word)
	if err != nil {
		return false, dbus.MakeFailedError(err)
	}
	historyRemoved, err := service.history.suppressWord(word)
	if err != nil {
		return false, dbus.MakeFailedError(err)
	}
	return personalRemoved || historyRemoved, nil
}

type userBackup struct {
	Version int                        `json:"version"`
	Words   map[string]map[string]int  `json:"words"`
	History historyData                `json:"history"`
	URLs    map[string]urlHistoryEntry `json:"urls,omitempty"`
}

func (service *service) learnedPaths() []string {
	return []string{service.learned.path, service.history.path, service.urls.path,
		service.clipboard.path}
}

func (service *service) LearnedEncryptionStatus() (string, *dbus.Error) {
	encrypted := false
	for _, path := range service.learnedPaths() {
		if encryptedPath(path) {
			encrypted = true
			break
		}
	}
	if encrypted {
		if service.codec.hasKey() {
			return "encrypted", nil
		}
		return "locked", nil
	}
	if service.codec.hasKey() {
		return "encrypted", nil
	}
	return "not_initialized", nil
}

func (service *service) persistLearnedData() error {
	service.learned.mu.Lock()
	err := service.learned.saveLocked()
	service.learned.mu.Unlock()
	if err != nil {
		return err
	}
	service.history.mu.Lock()
	err = service.history.saveLocked()
	service.history.mu.Unlock()
	if err != nil {
		return err
	}
	service.urls.mu.Lock()
	err = service.urls.saveLocked()
	service.urls.mu.Unlock()
	if err != nil {
		return err
	}
	service.clipboard.mu.Lock()
	err = service.clipboard.saveLocked()
	service.clipboard.mu.Unlock()
	return err
}

func (service *service) activateLearnedEncryption(operation string, persist bool) error {
	encrypted := make(map[string]bool)
	for _, path := range service.learnedPaths() {
		encrypted[path] = encryptedPath(path)
	}
	key, err := secretToolKey(operation, "learned")
	if err != nil {
		return err
	}
	defer zeroBytes(key)
	if err := service.codec.setKey(key); err != nil {
		return err
	}
	if encrypted[service.learned.path] {
		if err := service.learned.reload(); err != nil {
			return err
		}
	}
	if encrypted[service.history.path] {
		if err := service.history.reload(); err != nil {
			return err
		}
	}
	if encrypted[service.urls.path] {
		if err := service.urls.reload(); err != nil {
			return err
		}
	}
	if encrypted[service.clipboard.path] {
		if err := service.clipboard.reload(); err != nil {
			return err
		}
	}
	if persist {
		return service.persistLearnedData()
	}
	return nil
}

// InitializeLearnedEncryption creates or opens a device-local encryption key,
// migrates legacy JSON files atomically, and never sends learned data outside
// the FUTO helper.
func (service *service) InitializeLearnedEncryption() (bool, *dbus.Error) {
	if err := service.activateLearnedEncryption("ensure", true); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	return true, nil
}

// PrepareLearnedEncryptionFromAuthenticatedSettings is the only interactive
// unlock entry point.  Settings has already completed DeviceLockQuery before
// calling it. The root-owned key bridge may open the existing device-local key
// or create it on first use without displaying a second authentication view.
func (service *service) PrepareLearnedEncryptionFromAuthenticatedSettings(
	sender dbus.Sender) (bool, *dbus.Error) {
	if !service.trustedNamedVaultCaller(sender, "com.jolla.settings") {
		return false, dbus.MakeFailedError(errors.New("authenticated Settings access required"))
	}
	// Always persist after opening the key. This both preserves already
	// encrypted stores and atomically migrates any mixed/plaintext files which
	// were created while Sailfish Secrets was unavailable.
	if err := service.activateLearnedEncryption("prepare", true); err != nil {
		log.Printf("authenticated learned-data unlock failed: %v", err)
		return false, dbus.MakeFailedError(err)
	}
	return true, nil
}

func (service *service) ExportUserData() (string, *dbus.Error) {
	if !service.codec.hasKey() {
		return "", dbus.MakeFailedError(errors.New("initialize learned-data encryption first"))
	}
	backup := userBackup{Version: 1, Words: service.learned.snapshot(),
		History: service.history.snapshot(), URLs: service.urls.snapshot()}
	data, err := json.MarshalIndent(backup, "", "  ")
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	path, err := service.writeTimestampedLearnedBackup(data, time.Now())
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return path, nil
}

func (service *service) writeTimestampedLearnedBackup(data []byte, timestamp time.Time) (string, error) {
	directory := service.backupDirectory
	if directory == "" {
		directory = filepath.Join(filepath.Dir(service.backupPath), "FUTO-Keyboard")
	}
	if err := os.MkdirAll(directory, 0o700); err != nil {
		return "", err
	}
	if err := os.Chmod(directory, 0o700); err != nil {
		return "", err
	}
	// Keep one stable AES-GCM identity for portable filenames. The actual file
	// may include a timestamp or be renamed later without losing integrity.
	encrypted, err := service.codec.encode(service.backupPath, data)
	if err != nil {
		return "", err
	}
	base := "FUTO-Keyboard-backup-" + timestamp.Format("2006-01-02_15-04-05")
	for sequence := 1; sequence <= 1000; sequence++ {
		name := base
		if sequence > 1 {
			name += "-" + strconv.Itoa(sequence)
		}
		path := filepath.Join(directory, name+".futo")
		file, openErr := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
		if os.IsExist(openErr) {
			continue
		}
		if openErr != nil {
			return "", openErr
		}
		_, writeErr := file.Write(encrypted)
		if writeErr == nil {
			writeErr = file.Sync()
		}
		closeErr := file.Close()
		if writeErr != nil {
			_ = os.Remove(path)
			return "", writeErr
		}
		if closeErr != nil {
			_ = os.Remove(path)
			return "", closeErr
		}
		return path, nil
	}
	return "", errors.New("could not create a unique learned-data backup filename")
}

func selectedLearnedBackupPath(value string) (string, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		return "", errors.New("no learned-data backup was selected")
	}
	if parsed, err := url.Parse(value); err == nil && parsed.Scheme != "" {
		if parsed.Scheme != "file" {
			return "", errors.New("only local learned-data backups can be imported")
		}
		value = parsed.Path
	}
	if decoded, err := url.PathUnescape(value); err == nil {
		value = decoded
	}
	value = filepath.Clean(value)
	if !filepath.IsAbs(value) || !strings.EqualFold(filepath.Ext(value), ".futo") {
		return "", errors.New("select a .futo learned-data backup")
	}
	resolved, err := filepath.EvalSymlinks(value)
	if err != nil || !strings.EqualFold(filepath.Ext(resolved), ".futo") {
		return "", errors.New("the selected learned-data backup could not be found")
	}
	info, err := os.Stat(resolved)
	if err != nil || !info.Mode().IsRegular() {
		return "", errors.New("the selected learned-data backup could not be read")
	}
	if info.Size() <= 0 || info.Size() > 10*1024*1024 {
		return "", errors.New("the selected learned-data backup is empty or larger than 10 MB")
	}
	return resolved, nil
}

func mergeLearnedWords(current, imported map[string]map[string]int) map[string]map[string]int {
	if current == nil {
		current = make(map[string]map[string]int)
	}
	for language, words := range imported {
		if current[language] == nil {
			current[language] = make(map[string]int)
		}
		for word, count := range words {
			if count > current[language][word] {
				current[language][word] = count
			}
		}
	}
	return current
}

func mergeNestedHistoryCounts(current, imported map[string]map[string]int) map[string]map[string]int {
	if current == nil {
		current = make(map[string]map[string]int)
	}
	for group, entries := range imported {
		if current[group] == nil {
			current[group] = make(map[string]int)
		}
		for value, count := range entries {
			if count < 1 {
				continue
			}
			if count > 1000000 {
				count = 1000000
			}
			if count > current[group][value] {
				current[group][value] = count
			}
		}
	}
	return current
}

func mergeHistory(current, imported historyData) historyData {
	current.Bigrams = mergeNestedHistoryCounts(current.Bigrams, imported.Bigrams)
	current.LanguageWords = mergeNestedHistoryCounts(current.LanguageWords, imported.LanguageWords)
	if current.Suppressed == nil {
		current.Suppressed = make(map[string]bool)
	}
	for word, suppressed := range imported.Suppressed {
		if suppressed {
			current.Suppressed[word] = true
		}
	}
	return current
}

func mergeURLHistory(current, imported map[string]urlHistoryEntry) map[string]urlHistoryEntry {
	if current == nil {
		current = make(map[string]urlHistoryEntry)
	}
	for key, importedEntry := range normalizeURLHistoryEntries(imported) {
		currentEntry := current[key]
		if currentEntry.Text == "" {
			currentEntry.Text = importedEntry.Text
		}
		if importedEntry.Count > currentEntry.Count {
			currentEntry.Count = importedEntry.Count
		}
		if importedEntry.LastUsed > currentEntry.LastUsed {
			currentEntry.LastUsed = importedEntry.LastUsed
		}
		current[key] = currentEntry
	}
	return current
}

func (service *service) importUserDataFromPath(path string) (bool, error) {
	if !service.codec.hasKey() {
		return false, errors.New("initialize learned-data encryption first")
	}
	info, err := os.Stat(path)
	if err != nil || !info.Mode().IsRegular() || info.Size() > 10*1024*1024 {
		return false, nil
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		return false, err
	}
	if !bytes.HasPrefix(raw, encryptedFileMagic) {
		return false, errors.New("the selected backup is not an encrypted FUTO backup")
	}
	// Exported learned-data backups use a stable authenticated filename. This
	// lets the user move or rename a backup and still select it through the
	// picker without weakening AES-GCM integrity protection.
	decodePath := path
	if bytes.HasPrefix(raw, encryptedFileMagic) {
		decodePath = service.backupPath
	}
	data, err := service.codec.decode(decodePath, raw)
	if err != nil {
		return false, err
	}
	defer zeroBytes(data)
	var backup userBackup
	if err := json.Unmarshal(data, &backup); err != nil || backup.Version != 1 {
		return false, nil
	}
	// Restore is deliberately non-destructive. Keep everything learned on this
	// phone, add missing backup entries, and preserve the higher confidence/
	// recency values when the same item exists in both datasets.
	words := mergeLearnedWords(service.learned.snapshot(), backup.Words)
	history := mergeHistory(service.history.snapshot(), backup.History)
	urls := mergeURLHistory(service.urls.snapshot(), backup.URLs)
	if err := service.learned.replace(words); err != nil {
		return false, err
	}
	if err := service.history.replace(history); err != nil {
		return false, err
	}
	if err := service.urls.replace(urls); err != nil {
		return false, err
	}
	return true, nil
}

func (service *service) ImportUserDataFromFile(path string) (bool, *dbus.Error) {
	selectedPath, err := selectedLearnedBackupPath(path)
	if err != nil {
		return false, dbus.MakeFailedError(err)
	}
	imported, err := service.importUserDataFromPath(selectedPath)
	if err != nil {
		return false, dbus.MakeFailedError(err)
	}
	return imported, nil
}

func (service *service) ClearPersonalDictionary() (bool, *dbus.Error) {
	if err := service.learned.clear(); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	if err := service.history.clear(); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	if err := service.urls.clear(); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	return true, nil
}

func (service *service) VaultStatus(sender dbus.Sender) (string, *dbus.Error) {
	service.vaultSessionMu.Lock()
	service.expireVaultSessionsLocked(time.Now())
	_, authorized := service.vaultSessions[sender]
	noSessions := len(service.vaultSessions) == 0
	service.vaultSessionMu.Unlock()
	if authorized {
		return "unlocked", nil
	}
	if noSessions {
		service.vault.lock()
	}
	if encryptedPath(service.vault.path) {
		return "locked", nil
	}
	return "not_initialized", nil
}

func (service *service) InitializeVault(sender dbus.Sender) (string, *dbus.Error) {
	if err := service.authenticateVault(sender); err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return service.initializeVaultSession(sender)
}

func encryptedPayloadLength(path string) (int, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return 0, err
	}
	if !bytes.HasPrefix(data, encryptedFileMagic) {
		return 0, errors.New("vault is not encrypted")
	}
	block, err := aes.NewCipher(make([]byte, 32))
	if err != nil {
		return 0, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return 0, err
	}
	length := len(data) - len(encryptedFileMagic) - gcm.NonceSize() - gcm.Overhead()
	if length < 0 {
		return 0, errors.New("invalid encrypted vault")
	}
	return length, nil
}

func (service *service) openVaultFromWrappedKey(create bool) (bool, error) {
	key, err := service.codec.readFile(service.vaultKeyPath)
	if os.IsNotExist(err) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	defer zeroBytes(key)
	if len(key) != 32 {
		return false, errors.New("wrapped vault key has an invalid length")
	}
	if err := service.vault.open(key, create); err != nil {
		return false, err
	}
	return true, nil
}

func (service *service) cacheVaultKey(key []byte) error {
	if len(key) != 32 {
		return errors.New("vault key has an invalid length")
	}
	if !service.codec.hasKey() {
		return errors.New("device-bound learned-data key is unavailable")
	}
	return service.codec.writeFile(service.vaultKeyPath, key)
}

// An empty encrypted vault has a two-byte JSON payload: [].  It contains no
// credentials to migrate, so it can safely move to the device-authenticated
// wrapped-key format without displaying a second Sailfish Secrets dialog.
func (service *service) migrateEmptyLegacyVault() (bool, error) {
	length, err := encryptedPayloadLength(service.vault.path)
	if err != nil || length != 2 {
		return false, err
	}
	if !service.codec.hasKey() {
		return false, errors.New("device-bound learned-data key is unavailable")
	}
	key := make([]byte, 32)
	if _, err := io.ReadFull(rand.Reader, key); err != nil {
		return false, err
	}
	defer zeroBytes(key)
	backupPath := service.vault.path + ".legacy-empty"
	if _, err := os.Stat(backupPath); err == nil {
		return false, errors.New("empty legacy vault backup already exists")
	} else if !os.IsNotExist(err) {
		return false, err
	}
	if err := service.cacheVaultKey(key); err != nil {
		return false, err
	}
	if err := os.Rename(service.vault.path, backupPath); err != nil {
		_ = os.Remove(service.vaultKeyPath)
		return false, err
	}
	if err := service.vault.open(key, true); err != nil {
		_ = os.Remove(service.vaultKeyPath)
		_ = os.Rename(backupPath, service.vault.path)
		return false, err
	}
	return true, nil
}

func (service *service) createWrappedVault() error {
	if !service.codec.hasKey() {
		return errors.New("device-bound learned-data key is unavailable")
	}
	key := make([]byte, 32)
	if _, err := io.ReadFull(rand.Reader, key); err != nil {
		return err
	}
	defer zeroBytes(key)
	if err := service.cacheVaultKey(key); err != nil {
		return err
	}
	if err := service.vault.open(key, true); err != nil {
		_ = os.Remove(service.vaultKeyPath)
		return err
	}
	return nil
}

func (service *service) ensureVaultOpen(create bool) error {
	if service.vault.status() == "unlocked" {
		return nil
	}
	opened, err := service.openVaultFromWrappedKey(create)
	if err != nil || opened {
		return err
	}
	if encryptedPath(service.vault.path) {
		migrated, migrationErr := service.migrateEmptyLegacyVault()
		if migrationErr == nil && migrated {
			return nil
		}
		// Preserve non-empty legacy vaults.  Their existing Sailfish Secrets
		// key is requested once, then wrapped for all later authentications.
		operation := "get"
		key, keyErr := secretToolKey(operation, "vault")
		if keyErr != nil {
			if migrationErr != nil {
				return fmt.Errorf("vault migration failed: %v; legacy unlock failed: %w",
					migrationErr, keyErr)
			}
			return keyErr
		}
		defer zeroBytes(key)
		if err := service.vault.open(key, false); err != nil {
			return err
		}
		if err := service.cacheVaultKey(key); err != nil {
			log.Printf("could not cache the authenticated vault key: %v", err)
		}
		return nil
	}
	if !create {
		return errors.New("password vault is not initialized")
	}
	return service.createWrappedVault()
}

func (service *service) initializeVaultSession(sender dbus.Sender) (string, *dbus.Error) {
	if err := service.ensureVaultOpen(true); err != nil {
		return "", dbus.MakeFailedError(err)
	}
	token, err := service.createVaultSession(sender)
	if err != nil {
		service.vault.lock()
		return "", dbus.MakeFailedError(err)
	}
	return token, nil
}

func (service *service) UnlockVault(sender dbus.Sender) (string, *dbus.Error) {
	if err := service.authenticateVault(sender); err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return service.unlockVaultSession(sender)
}

func (service *service) unlockVaultSession(sender dbus.Sender) (string, *dbus.Error) {
	if err := service.ensureVaultOpen(false); err != nil {
		return "", dbus.MakeFailedError(err)
	}
	token, err := service.createVaultSession(sender)
	if err != nil {
		service.vault.lock()
		return "", dbus.MakeFailedError(err)
	}
	return token, nil
}

// Settings performs device authentication in its own trusted page stack.
// These entry points may only be called by the process that currently owns
// com.jolla.settings; Maliit and all other clients must use the brokered
// InitializeVault/UnlockVault methods above.
func (service *service) InitializeVaultFromAuthenticatedSettings(
	sender dbus.Sender) (string, *dbus.Error) {
	if !service.trustedNamedVaultCaller(sender, "com.jolla.settings") {
		return "", dbus.MakeFailedError(errors.New("authenticated Settings access required"))
	}
	return service.initializeVaultSession(sender)
}

func (service *service) UnlockVaultFromAuthenticatedSettings(
	sender dbus.Sender) (string, *dbus.Error) {
	if !service.trustedNamedVaultCaller(sender, "com.jolla.settings") {
		return "", dbus.MakeFailedError(errors.New("authenticated Settings access required"))
	}
	return service.unlockVaultSession(sender)
}

func (service *service) LockVault(sender dbus.Sender, token string) (bool, *dbus.Error) {
	service.closeVaultSession(sender, token)
	return true, nil
}

func (service *service) refreshCredentialIndex(entries []credentialMetadata) {
	if service.credentialIndex == nil {
		return
	}
	if err := service.credentialIndex.replace(entries); err != nil {
		log.Printf("could not update credential match index: %v", err)
	}
}

func credentialDisplayOrigin(origin string) string {
	if strings.HasPrefix(origin, "app://") {
		return strings.TrimPrefix(origin, "app://")
	}
	origin = strings.TrimPrefix(strings.TrimPrefix(origin, "https://"), "http://")
	return strings.TrimSuffix(origin, "/")
}

// The Settings application hosts FUTO's own vault-management forms. Those
// editors must never be treated as third-party login forms or generate a
// second "save login" confirmation for a credential being added manually.
func internalCredentialOrigin(origin string) bool {
	origin = normalizeCredentialOrigin(origin)
	if !strings.HasPrefix(origin, "app://") {
		return false
	}
	applicationID := strings.TrimPrefix(origin, "app://")
	switch applicationID {
	case "jolla-settings", "com.jolla.settings", "org.sailfishos.settings":
		return true
	default:
		return false
	}
}

func (service *service) lockVaultWhenNoSessions() {
	service.vaultSessionMu.Lock()
	service.expireVaultSessionsLocked(time.Now())
	noSessions := len(service.vaultSessions) == 0
	service.vaultSessionMu.Unlock()
	if noSessions {
		service.vault.lock()
	}
}

// OfferCredentialSave uses Sailfish's native modal authorization surface as
// the save confirmation itself.  There is no notification and no deferred
// keyboard prompt; canceling the modal discards the candidate immediately.
func (service *service) OfferCredentialSave(sender dbus.Sender, origin, username,
	password string) (bool, *dbus.Error) {
	if !service.trustedNamedVaultCaller(sender, "com.jolla.keyboard") {
		return false, dbus.MakeFailedError(errors.New("trusted keyboard access required"))
	}
	origin = normalizeCredentialOrigin(origin)
	username = cleanCredentialText(username, 512)
	if origin == "" || internalCredentialOrigin(origin) || password == "" || len(password) > 4096 ||
		strings.IndexFunc(password, unicode.IsControl) >= 0 {
		return false, nil
	}
	callerPID, err := service.connectionPID(string(sender))
	if err != nil || callerPID == 0 {
		return false, dbus.MakeFailedError(errors.New("could not identify the keyboard"))
	}
	if err := service.authenticateVaultPIDForAction(callerPID, vaultSaveAuthAction); err != nil {
		return false, nil
	}
	if err := service.ensureVaultOpen(true); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	saved, err := service.vault.upsert(credentialDisplayOrigin(origin), origin,
		username, password)
	if err != nil {
		service.lockVaultWhenNoSessions()
		return false, dbus.MakeFailedError(err)
	}
	if saved {
		if entries, listErr := service.vault.list(); listErr == nil {
			service.refreshCredentialIndex(entries)
		}
	}
	service.lockVaultWhenNoSessions()
	return saved, nil
}

// CredentialMatchCount never opens the password vault.  It reads only the
// encrypted origin-count index, and only the trusted keyboard/Settings process
// can ask.  An empty or unknown site therefore cannot produce a misleading
// saved-login prompt.
func (service *service) CredentialMatchCount(sender dbus.Sender, origin string) (int32, *dbus.Error) {
	if !service.trustedVaultCaller(sender) || service.credentialIndex == nil {
		return 0, nil
	}
	if internalCredentialOrigin(origin) {
		return 0, nil
	}
	count := service.credentialIndex.count(origin)
	if count > math.MaxInt32 {
		count = math.MaxInt32
	}
	return int32(count), nil
}

func (service *service) ListCredentials(sender dbus.Sender, token string) (string, *dbus.Error) {
	if err := service.validateVaultSession(sender, token); err != nil {
		return "", dbus.MakeFailedError(err)
	}
	entries, err := service.vault.list()
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	service.refreshCredentialIndex(entries)
	data, err := json.Marshal(entries)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return string(data), nil
}

// SearchCredentials performs password matching inside the unlocked encrypted
// vault and returns metadata only. Bulk plaintext passwords never cross D-Bus.
func (service *service) SearchCredentials(sender dbus.Sender, token, query string) (string, *dbus.Error) {
	if err := service.validateVaultSession(sender, token); err != nil {
		return "", dbus.MakeFailedError(err)
	}
	query = strings.TrimSpace(query)
	if len(query) > 512 || strings.IndexFunc(query, unicode.IsControl) >= 0 {
		return "[]", nil
	}
	entries, err := service.vault.search(query)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	data, err := json.Marshal(entries)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return string(data), nil
}

func (service *service) SaveCredential(sender dbus.Sender, token, label, origin, username,
	password string) (bool, *dbus.Error) {
	if err := service.validateVaultSession(sender, token); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	saved, err := service.vault.upsert(label, origin, username, password)
	if err != nil {
		return false, dbus.MakeFailedError(err)
	}
	if saved {
		if entries, listErr := service.vault.list(); listErr == nil {
			service.refreshCredentialIndex(entries)
		}
	}
	return saved, nil
}

func (service *service) UpdateCredential(sender dbus.Sender, token, id, label, origin,
	username, password string) (bool, *dbus.Error) {
	if err := service.validateVaultSession(sender, token); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	updated, err := service.vault.update(id, label, origin, username, password)
	if err != nil {
		return false, dbus.MakeFailedError(err)
	}
	if updated {
		if entries, listErr := service.vault.list(); listErr == nil {
			service.refreshCredentialIndex(entries)
		}
	}
	return updated, nil
}

func (service *service) DeleteCredential(sender dbus.Sender, token, id string) (bool, *dbus.Error) {
	if err := service.validateVaultSession(sender, token); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	deleted, err := service.vault.remove(id)
	if err != nil {
		return false, dbus.MakeFailedError(err)
	}
	if deleted {
		if entries, listErr := service.vault.list(); listErr == nil {
			service.refreshCredentialIndex(entries)
		}
	}
	return deleted, nil
}

// CredentialSecret returns only the single value explicitly selected by the
// user. Bulk listings never include passwords and no credential is logged.
func (service *service) CredentialSecret(sender dbus.Sender, token, id, field string) (string, *dbus.Error) {
	if err := service.validateVaultSession(sender, token); err != nil {
		return "", dbus.MakeFailedError(err)
	}
	value, err := service.vault.secret(id, field)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return value, nil
}

func firstRegularFile(directory string, names []string) string {
	for _, name := range names {
		path := filepath.Join(directory, name)
		if info, err := os.Stat(path); err == nil && info.Mode().IsRegular() {
			return path
		}
	}
	return ""
}

func selectedPasswordImportPath(value string) (string, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		return "", errors.New("No password export was selected")
	}
	if parsed, err := url.Parse(value); err == nil && parsed.Scheme != "" {
		if parsed.Scheme != "file" {
			return "", errors.New("Only local password exports can be imported")
		}
		value = parsed.Path
	}
	if decoded, err := url.PathUnescape(value); err == nil {
		value = decoded
	}
	value = filepath.Clean(value)
	ext := strings.ToLower(filepath.Ext(value))
	if !filepath.IsAbs(value) || (ext != ".csv" && ext != ".zip") {
		return "", errors.New("Select a local .csv or .zip password export")
	}
	resolved, err := filepath.EvalSymlinks(value)
	if err != nil {
		return "", errors.New("The selected password export could not be found")
	}
	info, err := os.Stat(resolved)
	if err != nil || !info.Mode().IsRegular() {
		return "", errors.New("The selected password export could not be read")
	}
	maximum := int64(20 * 1024 * 1024)
	if ext == ".zip" {
		maximum = 50 * 1024 * 1024
	}
	if info.Size() <= 0 || info.Size() > maximum {
		return "", errors.New("The selected password export is empty or too large")
	}
	return resolved, nil
}

func selectedPasswordCSVPath(value string) (string, error) {
	path, err := selectedPasswordImportPath(value)
	if err != nil {
		return "", err
	}
	if !strings.EqualFold(filepath.Ext(path), ".csv") {
		return "", errors.New("Select a local .csv password export")
	}
	return path, nil
}

func friendlyPasswordImportError(err error) string {
	if err == nil {
		return ""
	}
	message := err.Error()
	switch {
	case errors.Is(err, securezip.ErrPassword):
		return "The ZIP password is missing or incorrect"
	case strings.Contains(message, "header"):
		return "This CSV does not have a recognized password-export header"
	case strings.Contains(message, "ZIP") || strings.Contains(message, "zip"):
		return message
	default:
		return "The selected password export could not be imported"
	}
}

func marshalCredentialImportResult(result credentialImportResult) (string, *dbus.Error) {
	data, err := json.Marshal(result)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return string(data), nil
}

func (service *service) ImportPasswordsFromFile(sender dbus.Sender, token,
	path string) (string, *dbus.Error) {
	return service.importPasswordsFromFile(sender, token, path, "")
}

func (service *service) ImportPasswordsFromFileWithPassword(sender dbus.Sender,
	token, path, password string) (string, *dbus.Error) {
	return service.importPasswordsFromFile(sender, token, path, password)
}

func (service *service) importPasswordsFromFile(sender dbus.Sender, token,
	path, password string) (string, *dbus.Error) {
	if err := service.validateVaultSession(sender, token); err != nil {
		return "", dbus.MakeFailedError(err)
	}
	selectedPath, err := selectedPasswordImportPath(path)
	if err != nil {
		return marshalCredentialImportResult(credentialImportResult{Error: err.Error()})
	}
	var result credentialImportResult
	var importErr error
	if strings.EqualFold(filepath.Ext(selectedPath), ".zip") {
		result, importErr = service.vault.importCredentialZIP(selectedPath, password)
	} else {
		result, importErr = service.vault.importCSV(selectedPath)
	}
	if errors.Is(importErr, securezip.ErrPassword) {
		result.PasswordRequired = true
	}
	result.Error = friendlyPasswordImportError(importErr)
	if importErr == nil {
		if entries, listErr := service.vault.list(); listErr == nil {
			service.refreshCredentialIndex(entries)
		}
	}
	return marshalCredentialImportResult(result)
}

func (service *service) ExportPasswords(sender dbus.Sender, token,
	password string) (string, *dbus.Error) {
	if err := service.validateVaultSession(sender, token); err != nil {
		return "", dbus.MakeFailedError(err)
	}
	result, exportErr := service.exportCredentials(password, time.Now())
	if exportErr != nil {
		result.Error = "The password export could not be created"
	}
	data, err := json.Marshal(result)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return string(data), nil
}

func (service *service) importBrowserPasswords(sender dbus.Sender, token string,
	names []string) (string, *dbus.Error) {
	if err := service.validateVaultSession(sender, token); err != nil {
		return "", dbus.MakeFailedError(err)
	}
	path := firstRegularFile(service.documentsDir, names)
	if path == "" {
		return "", dbus.MakeFailedError(errors.New("password CSV not found in Documents"))
	}
	result, err := service.vault.importCSV(path)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	if entries, listErr := service.vault.list(); listErr == nil {
		service.refreshCredentialIndex(entries)
	}
	data, err := json.Marshal(result)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return string(data), nil
}

func (service *service) ImportFirefoxPasswords(sender dbus.Sender, token string) (string, *dbus.Error) {
	return service.importBrowserPasswords(sender, token, []string{
		"logins.csv", "firefox-passwords.csv", "Firefox Passwords.csv",
	})
}

func (service *service) ImportChromePasswords(sender dbus.Sender, token string) (string, *dbus.Error) {
	return service.importBrowserPasswords(sender, token, []string{
		"Chrome Passwords.csv", "chrome-passwords.csv", "passwords.csv",
		"Google Password Manager Passwords.csv",
	})
}

func (service *service) ListSupportedLanguages() (string, *dbus.Error) {
	data, err := json.Marshal(supportedLanguages)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return string(data), nil
}

func (service *service) SuppressClipboardCapture(
	sender dbus.Sender, token, text string) (bool, *dbus.Error) {
	if !service.trustedNamedVaultCaller(sender, "com.jolla.settings") ||
		text == "" || len(text) > 4096 {
		return false, nil
	}
	if err := service.validateVaultSession(sender, token); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	service.clipboardGuardMu.Lock()
	service.clipboardGuardText = text
	service.clipboardGuardUntil = time.Now().Add(5 * time.Second)
	service.clipboardGuardMu.Unlock()
	return true, nil
}

func (service *service) consumeClipboardGuard(text string) bool {
	service.clipboardGuardMu.Lock()
	defer service.clipboardGuardMu.Unlock()
	if service.clipboardGuardText == "" || time.Now().After(service.clipboardGuardUntil) {
		service.clipboardGuardText = ""
		service.clipboardGuardUntil = time.Time{}
		return false
	}
	if service.clipboardGuardText != text {
		return false
	}
	service.clipboardGuardText = ""
	service.clipboardGuardUntil = time.Time{}
	return true
}

func (service *service) RecordClipboard(text string,
	retentionSeconds int32) (bool, *dbus.Error) {
	if service.consumeClipboardGuard(text) {
		return false, nil
	}
	recorded, err := service.clipboard.record(text, retentionSeconds)
	if err != nil {
		return false, dbus.MakeFailedError(err)
	}
	return recorded, nil
}

func (service *service) ListClipboard() (string, *dbus.Error) {
	entries, err := service.clipboard.list()
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	data, err := json.Marshal(entries)
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return string(data), nil
}

func (service *service) SetClipboardPinned(id string, pinned bool,
	retentionSeconds int32) (bool, *dbus.Error) {
	changed, err := service.clipboard.setPinned(id, pinned, retentionSeconds)
	if err != nil {
		return false, dbus.MakeFailedError(err)
	}
	return changed, nil
}

func (service *service) DeleteClipboard(id string) (bool, *dbus.Error) {
	changed, err := service.clipboard.remove(id)
	if err != nil {
		return false, dbus.MakeFailedError(err)
	}
	return changed, nil
}

func (service *service) ClearClipboardHistory() (bool, *dbus.Error) {
	if err := service.clipboard.clear(); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	return true, nil
}

func (service *service) Ping() (string, *dbus.Error) {
	return version, nil
}

var (
	showAndroidKeyboardMu      sync.Mutex
	showAndroidKeyboardRunning bool
	forcedAppSupportUntil      time.Time
	androidKeyInjectionMu      sync.Mutex
	maliitRecoveryMu           sync.Mutex
	maliitRecoveryRunning      bool
)

func showAndroidKeyboardWithRetries() {
	defer func() {
		showAndroidKeyboardMu.Lock()
		showAndroidKeyboardRunning = false
		showAndroidKeyboardMu.Unlock()
	}()

	context, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	for attempt := 0; attempt < 3; attempt++ {
		command := exec.CommandContext(context, appSupportKeyboardPath)
		command.Stdout = io.Discard
		command.Stderr = io.Discard
		if err := command.Run(); err != nil {
			log.Printf("could not show Android AppSupport keyboard (attempt %d): %v",
				attempt+1, err)
		}
		if attempt == 2 {
			break
		}
		select {
		case <-context.Done():
			return
		case <-time.After(time.Second):
		}
	}
}

// ShowAndroidKeyboard is the fire-and-forget Top Menu action used for Android
// apps that focus a text field without asking AppSupport to display its remote
// IME.  Some apps immediately hide the first request, so the helper repeats it
// briefly.  The set-user-ID bridge accepts no arguments and can only request
// that the keyboard be shown.
func (service *service) ShowAndroidKeyboard() *dbus.Error {
	if err := exec.Command("/usr/bin/dconf", "write", forcedAppSupportDconfPath,
		"true").Run(); err != nil {
		log.Printf("could not enable forced AppSupport key events: %v", err)
	}
	showAndroidKeyboardMu.Lock()
	forcedAppSupportUntil = time.Now().Add(10 * time.Minute)
	if !showAndroidKeyboardRunning {
		showAndroidKeyboardRunning = true
		go showAndroidKeyboardWithRetries()
	}
	showAndroidKeyboardMu.Unlock()
	return nil
}

func androidInputArgument(key int32, text string) (string, string, bool) {
	switch key {
	case 0x01000000:
		return "keyevent", "KEYCODE_ESCAPE", true
	case 0x01000001, 0x01000002:
		return "keyevent", "KEYCODE_TAB", true
	case 0x01000003:
		return "keyevent", "KEYCODE_DEL", true
	case 0x01000004, 0x01000005:
		return "keyevent", "KEYCODE_ENTER", true
	case 0x01000007:
		return "keyevent", "KEYCODE_FORWARD_DEL", true
	case 0x01000010:
		return "keyevent", "KEYCODE_MOVE_HOME", true
	case 0x01000011:
		return "keyevent", "KEYCODE_MOVE_END", true
	case 0x01000012:
		return "keyevent", "KEYCODE_DPAD_LEFT", true
	case 0x01000013:
		return "keyevent", "KEYCODE_DPAD_UP", true
	case 0x01000014:
		return "keyevent", "KEYCODE_DPAD_RIGHT", true
	case 0x01000015:
		return "keyevent", "KEYCODE_DPAD_DOWN", true
	case 0x01000016:
		return "keyevent", "KEYCODE_PAGE_UP", true
	case 0x01000017:
		return "keyevent", "KEYCODE_PAGE_DOWN", true
	case 0x20:
		return "keyevent", "KEYCODE_SPACE", true
	}
	if len(text) == 1 && text[0] >= 0x21 && text[0] <= 0x7e {
		return "text", text, true
	}
	return "", "", false
}

func validAndroidSwipeWord(word string) bool {
	if word == "" || len(word) > 256 || !utf8.ValidString(word) ||
		utf8.RuneCountInString(word) > 64 {
		return false
	}
	for _, character := range word {
		if !(unicode.IsLetter(character) || character == '\'' ||
			character == '’' || character == '-') {
			return false
		}
	}
	return true
}

// InjectAndroidKey is available only for a short period after the user invokes
// the explicit Top Menu compatibility action.  The privileged bridge performs
// a second validation and accepts only one printable ASCII character or a
// small fixed set of navigation/editing keys.
func (service *service) InjectAndroidKey(sender dbus.Sender, key int32,
	text string) (bool, *dbus.Error) {
	if !service.trustedNamedVaultCaller(sender, "com.jolla.keyboard") {
		return false, nil
	}
	showAndroidKeyboardMu.Lock()
	enabled := time.Now().Before(forcedAppSupportUntil)
	showAndroidKeyboardMu.Unlock()
	if !enabled {
		return false, nil
	}

	mode, value, valid := androidInputArgument(key, text)
	if !valid {
		return false, nil
	}

	androidKeyInjectionMu.Lock()
	defer androidKeyInjectionMu.Unlock()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	command := exec.CommandContext(ctx, appSupportKeyboardPath, mode, value)
	command.Stdout = io.Discard
	command.Stderr = io.Discard
	if err := command.Run(); err != nil {
		log.Printf("could not inject Android AppSupport key: %v", err)
		return false, nil
	}
	return true, nil
}

// InjectAndroidSwipe commits one decoded swipe word and its trailing space
// through Android's direct-input channel.  The ordinary Maliit commit protocol
// is unavailable precisely in the applications for which Top Menu compatibility
// mode is needed, so keeping both operations under one lock also preserves their
// order.  The privileged bridge independently rejects whitespace and controls.
func (service *service) InjectAndroidSwipe(sender dbus.Sender,
	word string) (bool, *dbus.Error) {
	if !service.trustedNamedVaultCaller(sender, "com.jolla.keyboard") ||
		!validAndroidSwipeWord(word) {
		return false, nil
	}
	showAndroidKeyboardMu.Lock()
	enabled := time.Now().Before(forcedAppSupportUntil)
	showAndroidKeyboardMu.Unlock()
	if !enabled {
		return false, nil
	}

	androidKeyInjectionMu.Lock()
	defer androidKeyInjectionMu.Unlock()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	for _, input := range [][2]string{
		{"text", word},
		{"keyevent", "KEYCODE_SPACE"},
	} {
		command := exec.CommandContext(ctx, appSupportKeyboardPath,
			input[0], input[1])
		command.Stdout = io.Discard
		command.Stderr = io.Discard
		if err := command.Run(); err != nil {
			log.Printf("could not inject Android AppSupport swipe word: %v", err)
			return false, nil
		}
	}
	return true, nil
}

// EndAndroidKeyboard closes the host-forced keyboard and invalidates its
// short-lived injection permission.  This lets the next Android application
// establish a normal IME session and resize its window above the keyboard.
func (service *service) EndAndroidKeyboard(sender dbus.Sender) *dbus.Error {
	if !service.trustedNamedVaultCaller(sender, "com.jolla.keyboard") {
		return dbus.MakeFailedError(errors.New("Maliit access required"))
	}
	showAndroidKeyboardMu.Lock()
	forcedAppSupportUntil = time.Time{}
	showAndroidKeyboardMu.Unlock()
	if err := exec.Command("/usr/bin/dconf", "write", forcedAppSupportDconfPath,
		"false").Run(); err != nil {
		log.Printf("could not disable forced AppSupport key events: %v", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	command := exec.CommandContext(ctx, appSupportKeyboardPath, "hide")
	command.Stdout = io.Discard
	command.Stderr = io.Discard
	if err := command.Run(); err != nil {
		log.Printf("could not close forced Android AppSupport keyboard: %v", err)
	}
	// A host-forced AppSupport keyboard bypasses Android's ordinary IME state.
	// After it closes, the first subsequent Maliit editor can otherwise inherit
	// a stale connection and render keys without accepting input. Restart Maliit
	// after this D-Bus call returns so the next editor starts cleanly.
	maliitRecoveryMu.Lock()
	if !maliitRecoveryRunning {
		maliitRecoveryRunning = true
		go func() {
			defer func() {
				maliitRecoveryMu.Lock()
				maliitRecoveryRunning = false
				maliitRecoveryMu.Unlock()
			}()
			time.Sleep(250 * time.Millisecond)
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			command := exec.CommandContext(ctx, "/usr/bin/systemctl", "--user",
				"restart", "maliit-server.service")
			command.Stdout = io.Discard
			command.Stderr = io.Discard
			if err := command.Run(); err != nil {
				log.Printf("could not reset Maliit after forced AppSupport input: %v", err)
			}
		}()
	}
	maliitRecoveryMu.Unlock()
	return nil
}

var dconfQuotedValue = regexp.MustCompile(`'([^']*)'`)

func replaceLegacyLayout(layout string) string {
	switch layout {
	case "futo_en.qml", "futo_nl.qml", "futo_tr.qml":
		return "futo.qml"
	default:
		return layout
	}
}

func dconfRead(key string) (string, error) {
	output, err := exec.Command("/usr/bin/dconf", "read", key).Output()
	return strings.TrimSpace(string(output)), err
}

func dconfWrite(key, value string) error {
	return exec.Command("/usr/bin/dconf", "write", key, value).Run()
}

func hardwarePolicyMarkerPath() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(home, ".local", "share", "futo-keyboard-sailfish",
		"keep-virtual-hardware")
}

func writeHardwarePolicyMarker(enabled bool) error {
	path := hardwarePolicyMarkerPath()
	if path == "" {
		return errors.New("home directory is unavailable")
	}
	if !enabled {
		if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
			return err
		}
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	return os.WriteFile(path, []byte("enabled\n"), 0o600)
}

func scheduleMaliitRestart() {
	go func() {
		time.Sleep(300 * time.Millisecond)
		// Use restart rather than try-restart: Sailfish may have stopped Maliit
		// completely while a hardware keyboard was the only input source, and
		// enabling the simultaneous on-screen keyboard must bring it back.
		command := exec.Command("/usr/bin/systemctl", "--user", "restart",
			"maliit-server.service")
		command.Stdout = io.Discard
		command.Stderr = io.Discard
		if err := command.Run(); err != nil {
			log.Printf("could not restart Maliit after hardware policy change: %v", err)
		}
	}()
}

// SetKeepVirtualKeyboardWithHardware changes only Maliit's decision about
// showing the virtual surface. Lipstick continues to receive the real device,
// so physical keys remain usable alongside FUTO.
func (service *service) SetKeepVirtualKeyboardWithHardware(enabled bool) (bool, *dbus.Error) {
	if err := writeHardwarePolicyMarker(enabled); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	scheduleMaliitRestart()
	return true, nil
}

// FocusCredentialField performs one hardware-equivalent Tab gesture. Some
// Wayland clients ignore Tab sent through the text-input protocol, so the
// tightly restricted setuid bridge is used only by the real Maliit process.
func (service *service) FocusCredentialField(sender dbus.Sender,
	direction string) (bool, *dbus.Error) {
	if !service.trustedNamedVaultCaller(sender, "com.jolla.keyboard") {
		log.Printf("rejected focus navigation from untrusted D-Bus caller")
		return false, dbus.MakeFailedError(errors.New("untrusted keyboard caller"))
	}
	direction = strings.ToLower(strings.TrimSpace(direction))
	if direction != "next" && direction != "previous" {
		return false, dbus.MakeFailedError(errors.New("invalid focus direction"))
	}
	context, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	command := exec.CommandContext(context, focusPath, direction)
	command.Stdout = io.Discard
	command.Stderr = io.Discard
	if err := command.Run(); err != nil {
		log.Printf("focus navigation %s failed: %v", direction, err)
		return false, dbus.MakeFailedError(errors.New("focus navigation failed"))
	}
	return true, nil
}

func xkbVariantExists(layout, variant string) bool {
	data, err := os.ReadFile("/usr/share/X11/xkb/rules/evdev.lst")
	if err != nil {
		return false
	}
	return xkbVariantExistsInRules(data, layout, variant)
}

func xkbVariantExistsInRules(data []byte, layout, variant string) bool {
	inVariants := false
	for _, line := range strings.Split(string(data), "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "!") {
			inVariants = trimmed == "! variant"
			continue
		}
		if !inVariants || trimmed == "" {
			continue
		}
		fields := strings.Fields(trimmed)
		if len(fields) >= 2 && fields[0] == variant &&
			strings.TrimSuffix(fields[1], ":") == layout {
			return true
		}
	}
	return false
}

func deadKeyVariant(layout string, enabled bool) string {
	data, err := os.ReadFile("/usr/share/X11/xkb/rules/evdev.lst")
	if err != nil {
		return ""
	}
	return deadKeyVariantFromRules(data, layout, enabled)
}

func deadKeyVariantFromRules(data []byte, layout string, enabled bool) string {
	if enabled {
		// English layouts need their explicit international variant. Most
		// national layouts already use dead keys in their default variant.
		if xkbVariantExistsInRules(data, layout, "intl") {
			return "intl"
		}
		return ""
	}
	if xkbVariantExistsInRules(data, layout, "nodeadkeys") {
		return "nodeadkeys"
	}
	return ""
}

func (service *service) SetHardwareDeadKeys(enabled bool) (string, *dbus.Error) {
	const base = "/desktop/lipstick-jolla-home/"
	layoutValue, err := dconfRead(base + "layout")
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	layout := strings.Trim(layoutValue, "'\"")
	if layout == "" {
		layout = "us"
	}
	variant := deadKeyVariant(layout, enabled)
	if err := dconfWrite(base+"variant", quoteDconfString(variant)); err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return variant, nil
}

func keyboardModeSetting(orientation string, mode int32) (string, int32, error) {
	orientation = strings.ToLower(strings.TrimSpace(orientation))
	if orientation != "portrait" && orientation != "landscape" {
		return "", 0, fmt.Errorf("unsupported keyboard orientation %q", orientation)
	}
	if mode < 0 {
		mode = 0
	} else if mode > 3 {
		mode = 3
	}
	key := "/sailfish/text_input/futo_keyboard/" + orientation + "KeyboardMode"
	return key, mode, nil
}

// SetKeyboardMode persists exactly one orientation and broadcasts it to both
// the Settings process and Maliit. This avoids two independent QML config
// objects mirroring or overwriting each other's ComboBox state.
func (service *service) SetKeyboardMode(orientation string, mode int32) (int32, *dbus.Error) {
	key, appliedMode, err := keyboardModeSetting(orientation, mode)
	if err != nil {
		return 0, dbus.MakeFailedError(err)
	}
	if err := dconfWrite(key, fmt.Sprintf("%d", appliedMode)); err != nil {
		return 0, dbus.MakeFailedError(err)
	}
	if service.bus != nil {
		if err := service.bus.Emit(objectPath,
			interfaceName+"."+keyboardModeChangedSignal,
			strings.ToLower(strings.TrimSpace(orientation)), appliedMode); err != nil {
			log.Printf("could not broadcast keyboard mode: %v", err)
		}
	}
	return appliedMode, nil
}

func storedKeyboardMode(value string) int32 {
	parsed, err := strconv.Atoi(strings.TrimSpace(value))
	if err != nil || parsed < 0 {
		return 0
	}
	if parsed > 3 {
		return 3
	}
	return int32(parsed)
}

// GetKeyboardModes lets an already-open Settings page reconcile its controls
// even on Sailfish builds where cross-process ConfigurationGroup notifications
// are delayed until the page is recreated.
func (service *service) GetKeyboardModes() (string, *dbus.Error) {
	portrait, err := dconfRead(
		"/sailfish/text_input/futo_keyboard/portraitKeyboardMode")
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	landscape, err := dconfRead(
		"/sailfish/text_input/futo_keyboard/landscapeKeyboardMode")
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	result, err := json.Marshal(map[string]int32{
		"portrait":  storedKeyboardMode(portrait),
		"landscape": storedKeyboardMode(landscape),
	})
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return string(result), nil
}

func helperIntrospectionInterface(application interface{}) introspect.Interface {
	return introspect.Interface{
		Name:    interfaceName,
		Methods: introspect.Methods(application),
		Signals: []introspect.Signal{
			{
				Name: keyboardModeChangedSignal,
				Args: []introspect.Arg{
					{Name: "orientation", Type: "s"},
					{Name: "mode", Type: "i"},
				},
			},
			{
				Name: contentChangedSignal,
				Args: []introspect.Arg{
					{Name: "id", Type: "s"},
					{Name: "state", Type: "s"},
				},
			},
		},
	}
}

func quoteDconfString(value string) string {
	value = strings.ReplaceAll(value, `\`, `\\`)
	value = strings.ReplaceAll(value, `'`, `\'`)
	return "'" + value + "'"
}

func parseEnabledLayouts(value string) []string {
	matches := dconfQuotedValue.FindAllStringSubmatch(value, -1)
	layouts := make([]string, 0, len(matches))
	seen := make(map[string]bool)
	for _, match := range matches {
		layout := replaceLegacyLayout(match[1])
		if layout != "" && !seen[layout] {
			seen[layout] = true
			layouts = append(layouts, layout)
		}
	}
	return layouts
}

func preferredActiveLayout(enabled []string, active string) string {
	for _, layout := range enabled {
		if layout == active {
			return active
		}
	}
	for _, layout := range enabled {
		if layout == "futo.qml" {
			return layout
		}
	}
	if len(enabled) > 0 {
		return enabled[0]
	}
	return active
}

func preferredPreviousLayout(enabled []string, active, previous string) string {
	for _, layout := range enabled {
		if layout == previous {
			return previous
		}
	}
	for _, layout := range enabled {
		if layout != active {
			return layout
		}
	}
	return active
}

func migrateLegacyLayouts() {
	const enabledKey = "/sailfish/text_input/enabled_layouts"
	const activeKey = "/sailfish/text_input/active_layout"
	const previousKey = "/sailfish/text_input/previous_layout"

	var enabledLayouts []string
	enabledValue, err := dconfRead(enabledKey)
	if err == nil && enabledValue != "" {
		matches := dconfQuotedValue.FindAllStringSubmatch(enabledValue, -1)
		enabledLayouts = make([]string, 0, len(matches))
		seen := make(map[string]bool)
		changed := false
		for _, match := range matches {
			layout := replaceLegacyLayout(match[1])
			changed = changed || layout != match[1]
			if layout != "" && !seen[layout] {
				seen[layout] = true
				enabledLayouts = append(enabledLayouts, layout)
			} else if seen[layout] {
				changed = true
			}
		}
		if changed && len(enabledLayouts) > 0 {
			quoted := make([]string, 0, len(enabledLayouts))
			for _, layout := range enabledLayouts {
				quoted = append(quoted, quoteDconfString(layout))
			}
			if err := dconfWrite(enabledKey, "["+strings.Join(quoted, ", ")+"]"); err != nil {
				log.Printf("could not migrate enabled layouts: %v", err)
			} else {
				log.Printf("migrated legacy FUTO layouts to futo.qml")
			}
		}
	}

	activeValue, err := dconfRead(activeKey)
	activeLayout := ""
	if err == nil {
		matches := dconfQuotedValue.FindStringSubmatch(activeValue)
		if len(matches) == 2 {
			activeLayout = replaceLegacyLayout(matches[1])
			wantedLayout := preferredActiveLayout(enabledLayouts, activeLayout)
			if wantedLayout != matches[1] {
				if err := dconfWrite(activeKey, quoteDconfString(wantedLayout)); err != nil {
					log.Printf("could not repair active keyboard layout: %v", err)
				} else {
					log.Printf("repaired active keyboard layout from %s to %s",
						matches[1], wantedLayout)
				}
			}
		} else if len(enabledLayouts) > 0 {
			wantedLayout := preferredActiveLayout(enabledLayouts, "")
			activeLayout = wantedLayout
			if err := dconfWrite(activeKey, quoteDconfString(wantedLayout)); err != nil {
				log.Printf("could not migrate active layout: %v", err)
			}
		}
	}

	previousValue, err := dconfRead(previousKey)
	if err == nil && len(enabledLayouts) > 0 {
		matches := dconfQuotedValue.FindStringSubmatch(previousValue)
		previousLayout := ""
		if len(matches) == 2 {
			previousLayout = replaceLegacyLayout(matches[1])
		}
		wantedLayout := preferredPreviousLayout(enabledLayouts, activeLayout, previousLayout)
		if wantedLayout != previousLayout || (len(matches) == 2 && previousLayout != matches[1]) {
			if err := dconfWrite(previousKey, quoteDconfString(wantedLayout)); err != nil {
				log.Printf("could not repair previous keyboard layout: %v", err)
			} else {
				log.Printf("repaired previous keyboard layout from %s to %s",
					previousLayout, wantedLayout)
			}
		}
	}
}

func main() {
	syscall.Umask(0o077)
	log.SetFlags(log.LstdFlags | log.LUTC)
	log.SetPrefix("futo-keyboard-helper: ")
	migrateLegacyLayouts()
	if value, policyErr := dconfRead(
		"/sailfish/text_input/futo_keyboard/keepVirtualWithHardwareKeyboard"); policyErr == nil {
		if markerErr := writeHardwarePolicyMarker(value == "true"); markerErr != nil {
			log.Printf("could not synchronize hardware-keyboard policy: %v", markerErr)
		}
	}
	connection, err := dbus.ConnectSessionBus()
	if err != nil {
		log.Fatal(err)
	}
	defer connection.Close()

	home, err := os.UserHomeDir()
	if err != nil {
		log.Fatal(err)
	}
	dataDirectory := filepath.Join(home, ".local", "share", "futo-keyboard-sailfish")
	manifestPath := bundledContentManifestPath
	if override := strings.TrimSpace(os.Getenv("FUTO_CONTENT_MANIFEST")); override != "" {
		manifestPath = override
	}
	contentRoot := optionalContentRoot()
	content, contentErr := newContentManager(contentRoot, manifestPath,
		filepath.Join(home, "Downloads"))
	if contentErr != nil {
		log.Printf("content manager unavailable: %v", contentErr)
		content = nil
	}
	codec := &secureFileCodec{requireKeyWrite: true}
	if key, keyErr := secretToolKey("get", "learned"); keyErr == nil {
		if err := codec.setKey(key); err != nil {
			log.Printf("could not initialize learned-data encryption: %v", err)
		}
		for index := range key {
			key[index] = 0
		}
	}
	application := &service{
		bus:       connection,
		codec:     codec,
		learned:   newLearnedStore(filepath.Join(dataDirectory, "personal-dictionary.json"), codec),
		history:   newHistoryStore(filepath.Join(dataDirectory, "prediction-history.json"), codec),
		urls:      newURLHistoryStore(filepath.Join(dataDirectory, "url-history.json"), codec),
		clipboard: newClipboardStore(filepath.Join(dataDirectory, "clipboard-history.json"), codec),
		vault:     newVaultStore(filepath.Join(dataDirectory, "password-vault.json")),
		credentialIndex: newCredentialMatchIndex(
			filepath.Join(dataDirectory, "password-vault-index.json"), codec),
		content:         content,
		vaultKeyPath:    filepath.Join(dataDirectory, "password-vault-key.bin"),
		vaultSessions:   make(map[dbus.Sender]vaultSession),
		soundSlots:      make(chan struct{}, 4),
		voiceDirectory:  filepath.Join(dataDirectory, "voice"),
		backupDirectory: filepath.Join(home, "Documents", "FUTO-Keyboard"),
		backupPath:      filepath.Join(home, "Documents", "FUTO-Keyboard-backup.futo"),
		documentsDir:    filepath.Join(home, "Documents"),
	}
	if application.content != nil {
		application.content.onChanged = func(item contentItem, state string) {
			if item.Kind == "dictionary" {
				application.engine.reload()
			}
			if item.Kind == "voice" && state == "removed" {
				_, _ = application.CancelVoiceInput()
			}
			if emitErr := application.bus.Emit(objectPath,
				interfaceName+"."+contentChangedSignal, item.ID, state); emitErr != nil {
				log.Printf("could not emit content change for %s: %v", item.ID, emitErr)
			}
		}
	}
	if codec.hasKey() {
		migrationNeeded := false
		for _, path := range application.learnedPaths() {
			if _, statErr := os.Stat(path); statErr == nil && !encryptedPath(path) {
				migrationNeeded = true
				break
			}
		}
		if migrationNeeded {
			if persistErr := application.persistLearnedData(); persistErr != nil {
				log.Printf("could not migrate learned data to encryption: %v", persistErr)
			}
		}
	}
	defer application.engine.close()
	defer application.CancelVoiceInput()

	if err := connection.Export(application, objectPath, interfaceName); err != nil {
		log.Fatal(err)
	}
	node := &introspect.Node{
		Name: string(objectPath),
		Interfaces: []introspect.Interface{
			helperIntrospectionInterface(application),
			introspect.IntrospectData,
		},
	}
	if err := connection.Export(introspect.NewIntrospectable(node), objectPath,
		"org.freedesktop.DBus.Introspectable"); err != nil {
		log.Fatal(err)
	}
	reply, err := connection.RequestName(busName, dbus.NameFlagDoNotQueue)
	if err != nil {
		log.Fatal(err)
	}
	if reply != dbus.RequestNameReplyPrimaryOwner {
		log.Fatal("another FUTO Keyboard helper already owns the service")
	}
	signals := make(chan os.Signal, 1)
	signal.Notify(signals, syscall.SIGINT, syscall.SIGTERM)
	<-signals
}
