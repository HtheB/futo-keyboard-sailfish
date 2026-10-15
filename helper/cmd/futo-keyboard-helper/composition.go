package main

// Dedicated conversion sessions; ordinary typing never passes through these
// workers. A session belongs to one editor generation and one D-Bus caller.
import (
	"bufio"
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"github.com/godbus/dbus/v5"
)

type compositionCandidate struct {
	ID      int    `json:"id"`
	Text    string `json:"text"`
	Comment string `json:"comment"`
}

type compositionState struct {
	Session          string                 `json:"session"`
	Revision         uint32                 `json:"revision"`
	Consumed         bool                   `json:"consumed"`
	Commit           string                 `json:"commit"`
	Preedit          string                 `json:"preedit"`
	Input            string                 `json:"input"`
	Cursor           int                    `json:"cursor"`
	Candidates       []compositionCandidate `json:"candidates"`
	HasMore          bool                   `json:"hasMore"`
	AppendCandidates bool                   `json:"appendCandidates"`
}

type compositionReply struct {
	state compositionState
	err   error
}

type compositionSession struct {
	mu          sync.Mutex
	owner       dbus.Sender
	state       compositionState
	command     *exec.Cmd
	input       io.WriteCloser
	output      <-chan compositionReply
	finished    <-chan struct{}
	private     string
	codec       *secureFileCodec
	historyPath string
	cleanExit   bool
	failed      bool
	// These overrides are used only by host tests, never by D-Bus arguments.
	workerDir      string
	dataRoot       string
	timeout        time.Duration
	commandFactory func(string, ...string) *exec.Cmd
}

func compositionEngine(language, layout string) (string, string, error) {
	switch language {
	case "JA":
		if layout == "qwerty" || layout == "12key" || layout == "12key-latin" || layout == "12key-number" {
			return "mozc", layout, nil
		}
	case "ZH", "ZH_HANT":
		schema := "luna_pinyin_simp"
		if language == "ZH_HANT" {
			schema = "luna_pinyin"
		}
		switch layout {
		case "qwerty":
			return "rime", schema, nil
		case "stroke":
			return "rime", "stroke", nil
		}
	}
	return "", "", errors.New("unsupported conversion language or layout")
}

func (session *compositionSession) closeLocked() {
	if session.input != nil {
		_ = session.input.Close()
	}
	if session.command != nil && session.command.Process != nil {
		if session.finished != nil {
			select {
			case <-session.finished:
			case <-time.After(3 * time.Second):
				_ = session.command.Process.Kill()
				<-session.finished
			}
		}
	}
	if session.cleanExit && !session.failed && session.historyPath != "" && session.private != "" {
		// A failed worker must never replace the last good encrypted snapshot.
		_ = saveConversionProfile(session.codec, session.historyPath, session.private)
	}
	if session.private != "" {
		// Only our freshly created, uniquely named private session directory.
		_ = os.RemoveAll(session.private)
	}
	session.command, session.input, session.output, session.finished = nil, nil, nil, nil
	session.private = ""
	session.historyPath = ""
	session.cleanExit = false
	session.failed = false
	session.owner = ""
	session.state = compositionState{}
}

func (session *compositionSession) close() {
	session.mu.Lock()
	defer session.mu.Unlock()
	session.closeLocked()
}

func (session *compositionSession) clearLearning(profileRoot string) error {
	session.mu.Lock()
	defer session.mu.Unlock()
	// Discard the active profile before deleting snapshots, so shutting down
	// a worker cannot recreate history the user has just asked to erase.
	session.historyPath = ""
	session.closeLocked()
	for _, engine := range []string{"mozc", "rime"} {
		path := filepath.Join(profileRoot, "composition", engine+"-history.enc")
		if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
			return err
		}
	}
	return nil
}

func (session *compositionSession) readLocked(starting bool) (compositionState, error) {
	timeout := session.timeout
	if timeout == 0 {
		timeout = 5 * time.Second
		if starting {
			timeout = 90 * time.Second // First-time RIME dictionary deployment.
		}
	}
	select {
	case reply := <-session.output:
		if reply.err == nil {
			state := reply.state
			if !utf8.ValidString(state.Preedit) || !utf8.ValidString(state.Commit) || !utf8.ValidString(state.Input) ||
				state.Cursor < 0 || state.Cursor > utf8.RuneCountInString(state.Preedit)+utf8.RuneCountInString(state.Input) ||
				len(state.Candidates) > 256 || len(state.Commit)+len(state.Preedit) > 65536 {
				return compositionState{}, errors.New("invalid conversion response")
			}
			ids := make(map[int]bool)
			for _, item := range state.Candidates {
				if ids[item.ID] || !utf8.ValidString(item.Text) || !utf8.ValidString(item.Comment) {
					return compositionState{}, errors.New("invalid conversion candidate")
				}
				ids[item.ID] = true
			}
			return state, nil
		}
		return compositionState{}, errors.New("conversion worker stopped")
	case <-time.After(timeout):
		return compositionState{}, errors.New("conversion worker did not respond")
	}
}

func (session *compositionSession) start(owner dbus.Sender, language, layout, profileRoot string,
	private bool) (compositionState, error) {
	return session.startOptions(owner, language, layout, profileRoot, private,
		compositionOptions{FlickOnly: true, PinyinScheme: "FullPinyin", OutputScript: "ByLanguage", Correction: true}, false)
}

func (session *compositionSession) startOptions(owner dbus.Sender, language, layout, profileRoot string,
	private bool, options compositionOptions, configured bool) (compositionState, error) {
	engine, schema, err := compositionEngine(language, layout)
	if err != nil {
		return compositionState{}, err
	}
	if engine == "rime" && layout == "qwerty" && doublePinyinSchemas[options.PinyinScheme] != "" {
		schema = doublePinyinSchemas[options.PinyinScheme]
	}
	session.mu.Lock()
	defer session.mu.Unlock()
	if owner == "" || (session.command != nil && session.owner != owner) {
		return compositionState{}, errors.New("conversion session belongs to another editor")
	}
	session.closeLocked()
	// A locked key is a private, non-learning session, never plaintext fallback.
	if session.codec == nil || !session.codec.hasKey() {
		private = true
	}
	workerDir := session.workerDir
	if workerDir == "" {
		workerDir = "/usr/libexec"
	}
	dataRoot := session.dataRoot
	if dataRoot == "" {
		dataRoot = filepath.Join(optionalContentRoot(), "composition")
	}
	data := filepath.Join(dataRoot, "japanese", "mozc.data")
	if engine == "rime" {
		data = filepath.Join(dataRoot, "chinese")
	}
	if info, statErr := os.Stat(data); statErr != nil || (engine == "mozc" && info.IsDir()) ||
		(engine == "rime" && !info.IsDir()) {
		return compositionState{}, errors.New("download the conversion dictionary first")
	}
	profile, err := conversionRuntimeDirectory()
	if err != nil {
		return compositionState{}, err
	}
	session.private = profile
	mode := "learn"
	if private {
		mode = "private"
	} else {
		session.historyPath = filepath.Join(profileRoot, "composition", engine+"-history.enc")
		if err := restoreConversionProfile(session.codec, session.historyPath, profile); err != nil {
			session.closeLocked()
			return compositionState{}, errors.New("cannot unlock conversion learning")
		}
	}
	if engine == "rime" {
		if err := prepareRimeProfileOptions(profile, schema, options.simplified(language), !private, options); err != nil {
			session.closeLocked()
			return compositionState{}, errors.New("cannot configure Chinese conversion")
		}
	}
	arguments := []string{data, profile, mode, layout}
	if engine == "mozc" && configured {
		arguments = append(arguments, options.mozcFlags())
	}
	if engine == "rime" {
		arguments = []string{data, profile, schema, mode}
		if session.commandFactory == nil {
			cache, err := prepareRimeCache(workerDir, data, profileRoot, schema, options.simplified(language), !private, options, nil)
			if err != nil {
				session.closeLocked()
				return compositionState{}, err
			}
			arguments = append(arguments, cache)
		}
	}
	factory := session.commandFactory
	if factory == nil {
		factory = exec.Command
	}
	command := factory(filepath.Join(workerDir, "futo-keyboard-"+engine), arguments...)
	// Engine libraries may log words and paths. Discard stderr, and return
	// only deliberately generic errors to the UI.
	command.Stderr = io.Discard
	input, err := command.StdinPipe()
	if err != nil {
		session.closeLocked()
		return compositionState{}, errors.New("cannot open conversion input")
	}
	output, err := command.StdoutPipe()
	if err != nil {
		_ = input.Close()
		session.closeLocked()
		return compositionState{}, errors.New("cannot open conversion output")
	}
	if err = command.Start(); err != nil {
		_ = input.Close()
		_ = output.Close()
		session.closeLocked()
		return compositionState{}, errors.New("conversion engine is unavailable")
	}
	responses := make(chan compositionReply, 1)
	finished := make(chan struct{})
	session.command, session.input, session.output, session.finished = command, input, responses, finished
	go func() {
		defer close(finished)
		scanner := bufio.NewScanner(output)
		scanner.Buffer(make([]byte, 4096), 1024*1024)
		for scanner.Scan() {
			var state compositionState
			err := json.Unmarshal(scanner.Bytes(), &state)
			select {
			case responses <- compositionReply{state: state, err: err}:
			default:
				// A worker must produce exactly one response per command.
				_ = command.Process.Kill()
			}
			if err != nil {
				break
			}
		}
		session.cleanExit = command.Wait() == nil
		select {
		case responses <- compositionReply{err: io.EOF}:
		default:
		}
	}()
	state, err := session.readLocked(true)
	if err != nil {
		session.failed = true
		session.closeLocked()
		return compositionState{}, err
	}
	token := make([]byte, 16)
	if _, err := rand.Read(token); err != nil {
		session.closeLocked()
		return compositionState{}, errors.New("cannot create conversion session")
	}
	state.Session, state.Revision = hex.EncodeToString(token), 0
	session.owner, session.state = owner, state
	return state, nil
}

// RIME's incognito option alone does not disable its user dictionary. Like
// FUTO's ChineseIME, deploy a schema patch that explicitly controls learning.
// A private session also has an isolated temporary profile, so it cannot read
// the user's earlier learned words. No arbitrary YAML comes from D-Bus.
func prepareRimeProfile(profile, schema string, simplified, learning bool) error {
	return prepareRimeProfileOptions(profile, schema, simplified, learning, compositionOptions{Correction: true})
}

func prepareRimeProfileOptions(profile, schema string, simplified, learning bool, options compositionOptions) error {
	patch := fmt.Sprintf("patch:\n  translator/enable_user_dict: %t\n"+
		"  translator/enable_correction: %t\n"+
		"  switches/+:\n    - name: futo_zh_simp\n      reset: %d\n"+
		"      states: [ 漢字, 汉字 ]\n  simplifier/option_name: futo_zh_simp\n",
		learning, options.Correction, map[bool]int{true: 1, false: 0}[simplified])
	if strings.HasPrefix(schema, "luna_pinyin") && options.FuzzyPinyin != "" {
		patch += "  speller/algebra/+:\n"
		for _, mode := range strings.Split(options.FuzzyPinyin, ",") {
			for _, rule := range fuzzyPinyinDerivations[mode] {
				patch += "    - " + rule + "\n"
			}
		}
	}
	if schema == "stroke" {
		patch += "  engine/filters/+:\n    - simplifier\n"
	}
	for name, text := range map[string]string{
		schema + ".custom.yaml": patch,
		"default.custom.yaml":   "patch:\n  schema_list:\n    - schema: " + schema + "\n",
	} {
		path := filepath.Join(profile, name)
		if previous, err := os.ReadFile(path); err == nil && bytes.Equal(previous, []byte(text)) {
			continue // Avoid unnecessarily redeploying dictionaries on each focus.
		}
		if err := os.WriteFile(path, []byte(text), 0600); err != nil {
			return err
		}
	}
	return nil
}

var rimeDeploymentMutex sync.Mutex

func preparePrivateRimeCache(workers, data, profileRoot, schema string, simplified bool) (string, error) {
	return preparePrivateRimeCacheWithCancel(workers, data, profileRoot, schema, simplified, nil)
}

func preparePrivateRimeCacheWithCancel(workers, data, profileRoot, schema string,
	simplified bool, cancelled <-chan struct{}) (string, error) {
	return prepareRimeCache(workers, data, profileRoot, schema, simplified, false, compositionOptions{Correction: true}, cancelled)
}

func prepareRimeCache(workers, data, profileRoot, schema string, simplified, learning bool,
	options compositionOptions, cancelled <-chan struct{}) (string, error) {
	rimeDeploymentMutex.Lock()
	defer rimeDeploymentMutex.Unlock()
	info, err := os.Stat(data)
	if err != nil {
		return "", errors.New("Chinese input data is unavailable")
	}
	// Includes the installed-data generation, script and schema. This cache
	// contains only compiled public dictionaries, never typed input or history.
	configuration, _ := json.Marshal(options)
	generation := sha256.Sum256([]byte(fmt.Sprintf("v2:%s:%d:%t:%s:%t:%s", data,
		info.ModTime().UnixNano(), simplified, schema, learning, configuration)))
	cacheProfile := filepath.Join(profileRoot, "composition", "dictionary-cache",
		fmt.Sprintf("%x", generation[:12]))
	compiled := filepath.Join(cacheProfile, "build")
	if regularFileAvailable(filepath.Join(cacheProfile, ".ready")) &&
		regularFileAvailable(filepath.Join(compiled, schema+".schema.yaml")) {
		return compiled, nil
	}
	if err := os.MkdirAll(cacheProfile, 0700); err != nil {
		return "", errors.New("cannot prepare Chinese dictionaries")
	}
	if err := prepareRimeProfileOptions(cacheProfile, schema, simplified, learning, options); err != nil {
		return "", errors.New("cannot configure private Chinese dictionaries")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()
	if cancelled != nil {
		go func() {
			select {
			case <-cancelled:
				cancel()
			case <-ctx.Done():
			}
		}()
	}
	command := exec.CommandContext(ctx, filepath.Join(workers, "futo-keyboard-rime"),
		data, cacheProfile, schema, "prepare")
	command.Stderr, command.Stdout = io.Discard, io.Discard
	if err := command.Run(); err != nil ||
		!regularFileAvailable(filepath.Join(compiled, schema+".schema.yaml")) {
		return "", errors.New("Chinese dictionary preparation failed")
	}
	if err := os.WriteFile(filepath.Join(cacheProfile, ".ready"), []byte("1\n"), 0600); err != nil {
		return "", errors.New("cannot retain compiled Chinese dictionaries")
	}
	return compiled, nil
}

func (session *compositionSession) end(owner dbus.Sender, token string) bool {
	session.mu.Lock()
	defer session.mu.Unlock()
	if session.owner != owner || session.state.Session != token || token == "" {
		return false
	}
	session.closeLocked()
	return true
}

func (session *compositionSession) ownerDisconnected(owner dbus.Sender) {
	session.mu.Lock()
	defer session.mu.Unlock()
	if session.owner == owner {
		session.closeLocked()
	}
}

func compositionJSON(state compositionState, err error) (string, *dbus.Error) {
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	encoded, err := json.Marshal(state)
	if err != nil {
		return "", dbus.MakeFailedError(errors.New("cannot encode conversion response"))
	}
	return string(encoded), nil
}

func (service *service) StartComposition(owner dbus.Sender, language, layout string,
	private bool) (string, *dbus.Error) {
	return compositionJSON(service.composition.start(owner, language, layout,
		service.dataDirectory, private))
}

func (service *service) StartCompositionWithOptions(owner dbus.Sender, language, layout string,
	private bool, raw string) (string, *dbus.Error) {
	options, err := parseCompositionOptions(raw)
	if err != nil {
		return compositionJSON(compositionState{}, err)
	}
	return compositionJSON(service.composition.startOptions(owner, language, layout,
		service.dataDirectory, private, options, true))
}

func (service *service) UpdateComposition(owner dbus.Sender, token string, revision uint32,
	operation, value string) (string, *dbus.Error) {
	return compositionJSON(service.composition.update(owner, token, revision, operation, value))
}

func (service *service) EndComposition(owner dbus.Sender, token string) (bool, *dbus.Error) {
	return service.composition.end(owner, token), nil
}

func (session *compositionSession) update(owner dbus.Sender, token string, revision uint32,
	operation, value string) (compositionState, error) {
	session.mu.Lock()
	defer session.mu.Unlock()
	if session.command == nil || session.owner != owner || session.state.Session != token ||
		session.state.Revision != revision {
		return compositionState{}, errors.New("conversion session is no longer current")
	}
	argument := ""
	switch operation {
	case "text":
		if value == "" || len(value) > 4096 || !utf8.ValidString(value) || strings.ContainsRune(value, 0) {
			return compositionState{}, errors.New("invalid conversion text")
		}
		argument = hex.EncodeToString([]byte(value))
	case "key":
		allowed := map[string]bool{"32": true, "65288": true, "65293": true,
			"65307": true, "65361": true, "65363": true}
		if !allowed[value] {
			return compositionState{}, errors.New("unsupported conversion key")
		}
		argument = value
	case "select":
		id, err := strconv.Atoi(value)
		found := false
		for _, candidate := range session.state.Candidates {
			found = found || candidate.ID == id
		}
		if err != nil || !found {
			return compositionState{}, errors.New("conversion candidate is no longer current")
		}
		argument = strconv.Itoa(id)
	case "cursor":
		position, err := strconv.Atoi(value)
		length := utf8.RuneCountInString(session.state.Preedit)
		if session.state.Input != "" {
			length = utf8.RuneCountInString(session.state.Input)
		}
		if err != nil || position < 0 || position > length {
			return compositionState{}, errors.New("invalid reading cursor")
		}
		argument = strconv.Itoa(position)
	case "more":
		if !session.state.HasMore || value != strconv.Itoa(len(session.state.Candidates)) || len(session.state.Candidates) >= 2048 {
			return compositionState{}, errors.New("invalid candidate page")
		}
		argument = value
	case "reset", "commit", "state", "stop-toggle":
	default:
		return compositionState{}, errors.New("unsupported conversion command")
	}
	if _, err := fmt.Fprintf(session.input, "%s\t%s\n", operation, argument); err != nil {
		session.failed = true
		session.closeLocked()
		return compositionState{}, errors.New("conversion input failed")
	}
	state, err := session.readLocked(false)
	if err != nil {
		session.failed = true
		session.closeLocked()
		return compositionState{}, err
	}
	state.Session, state.Revision = token, revision+1
	if state.AppendCandidates {
		state.Candidates = append(session.state.Candidates, state.Candidates...)
	}
	state.AppendCandidates = false
	session.state = state
	return state, nil
}
