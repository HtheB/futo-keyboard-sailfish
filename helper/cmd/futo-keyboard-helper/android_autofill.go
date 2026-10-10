package main

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/godbus/dbus/v5"
)

const androidAutofillAddress = "127.0.0.1:39767"
const androidAutofillPackage = "org.htheb.futo.autofill"
const androidAutofillSignal = "androidAutofillRequested"

type androidAutofillState struct {
	Enabled bool   `json:"enabled"`
	Token   string `json:"token"`
}

type androidLoginRequest struct {
	ID               string             `json:"id"`
	PackageName      string             `json:"packageName"`
	Origin           string             `json:"origin"`
	Label            string             `json:"-"`
	Mode             string             `json:"mode"`
	Username         string             `json:"username,omitempty"`
	Password         string             `json:"password,omitempty"`
	Approved         bool               `json:"approved"`
	Finished         bool               `json:"finished"`
	Presented        bool               `json:"-"`
	DirectSave       bool               `json:"-"`
	Error            string             `json:"error,omitempty"`
	Cancel           context.CancelFunc `json:"-"`
	Expires          time.Time          `json:"-"`
	Owner            dbus.Sender        `json:"-"`
	KeyboardVisible  bool               `json:"-"`
	KeyboardRevision int                `json:"-"`
}

// The listener exists only while the user enables the companion. One pending
// request is bounded, expires and is consumed once; it never exports the vault.
type androidAutofillBridge struct {
	mu               sync.Mutex
	service          *service
	state            androidAutofillState
	path             string
	active           bool
	server           *http.Server
	pending          *androidLoginRequest
	authenticateSave func(context.Context) error
	commitSave       func(*androidLoginRequest) error
	savingAllowed    func() bool
	toastCancel      context.CancelFunc
}

func newAndroidAutofillBridge(service *service) (*androidAutofillBridge, error) {
	b := &androidAutofillBridge{service: service,
		path:             filepath.Join(service.dataDirectory, "android-autofill.json"),
		authenticateSave: service.authenticateAndroidSave,
		commitSave:       service.saveAuthenticatedAndroidLogin,
		savingAllowed:    service.androidAutofillSavingAllowed}
	data, err := os.ReadFile(b.path)
	if err == nil {
		err = json.Unmarshal(data, &b.state)
		zeroBytes(data)
		if err != nil || (len(b.state.Token) != 64 && (b.state.Enabled || b.state.Token != "")) {
			return nil, errors.New("invalid Android autofill configuration")
		}
	} else if !os.IsNotExist(err) {
		return nil, err
	}
	// The companion reports the actual Android selection on setup, connection
	// and selection changes. Preserve that report across a native helper restart.
	if b.state.Enabled {
		active, _ := dconfRead(keyboardSettingsRoot + "androidAutofillActive")
		b.active = strings.TrimSpace(active) == "true"
	}
	return b, nil
}

func (b *androidAutofillBridge) persistLocked() error {
	if err := os.MkdirAll(filepath.Dir(b.path), 0700); err != nil {
		return err
	}
	data, err := json.Marshal(b.state)
	if err != nil {
		return err
	}
	defer zeroBytes(data)
	file, err := os.CreateTemp(filepath.Dir(b.path), ".android-autofill-")
	if err != nil {
		return err
	}
	name := file.Name()
	defer os.Remove(name)
	if _, err = file.Write(data); err == nil {
		err = file.Sync()
	}
	closeErr := file.Close()
	if err != nil {
		return err
	}
	if closeErr != nil {
		return closeErr
	}
	return os.Rename(name, b.path)
}

func (b *androidAutofillBridge) clearPendingLocked() {
	if b.pending != nil {
		if b.pending.Cancel != nil {
			b.pending.Cancel()
		}
		b.pending.Password = ""
		b.pending.Username = ""
	}
	b.pending = nil
}

func (b *androidAutofillBridge) pendingLocked(id string) *androidLoginRequest {
	if b.pending != nil && time.Now().After(b.pending.Expires) {
		b.clearPendingLocked()
	}
	if b.pending == nil || (id != "" && b.pending.ID != id) {
		return nil
	}
	return b.pending
}

func (b *androidAutofillBridge) setEnabled(enabled bool) error {
	b.mu.Lock()
	defer b.mu.Unlock()
	previous := b.state
	if enabled && b.state.Token == "" {
		buf := make([]byte, 32)
		if _, err := rand.Read(buf); err != nil {
			return err
		}
		b.state.Token = hex.EncodeToString(buf)
		zeroBytes(buf)
	}
	if enabled && b.server == nil {
		listener, err := net.Listen("tcp", androidAutofillAddress)
		if err != nil {
			b.state = previous
			return errors.New("Android autofill bridge port is unavailable")
		}
		server := &http.Server{Handler: http.HandlerFunc(b.handle),
			ReadHeaderTimeout: 2 * time.Second, ReadTimeout: 5 * time.Second,
			WriteTimeout: 5 * time.Second, IdleTimeout: 5 * time.Second, MaxHeaderBytes: 4096}
		b.server = server
		go server.Serve(listener)
	}
	b.state.Enabled = enabled
	if err := b.persistLocked(); err != nil {
		if !previous.Enabled && b.server != nil {
			b.server.Close()
			b.server = nil
		}
		b.state = previous
		return err
	}
	if !enabled {
		b.active = false
		b.clearPendingLocked()
		if b.server != nil {
			b.server.Close()
			b.server = nil
		}
	}
	return nil
}

func (b *androidAutofillBridge) close() {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.clearPendingLocked()
	if b.server != nil {
		b.server.Close()
		b.server = nil
	}
}

func androidCompanionOrigin(packageName, origin string) string {
	if !androidPackagePattern.MatchString(packageName) || packageName == androidAutofillPackage {
		return ""
	}
	normalized := normalizeCredentialOrigin(origin)
	if normalized == "" {
		return ""
	}
	if strings.HasPrefix(normalized, "app://") {
		if normalized != "app://"+strings.ToLower(packageName) {
			return ""
		}
		return normalized
	}
	// Website identity is accepted only from known browser packages. Arbitrary
	// apps exposing web-domain attributes cannot obtain another site's login.
	if androidFirefoxPackage(packageName) {
		return normalized
	}
	switch packageName {
	case "org.chromium.chrome", "com.android.chrome", "com.chrome.beta", "com.chrome.dev",
		"com.brave.browser", "com.microsoft.emmx", "com.opera.browser", "com.vivaldi.browser",
		"com.duckduckgo.mobile.android":
		return normalized
	}
	return ""
}

func verifiedAndroidBrowserOrigin(reported, current string) string {
	reported = normalizeCredentialOrigin(reported)
	current = normalizeCredentialOrigin(current)
	if reported == "" || current == "" || strings.HasPrefix(reported, "app://") || strings.HasPrefix(current, "app://") {
		return ""
	}
	a, errA := url.Parse(reported)
	b, errB := url.Parse(current)
	if errA != nil || errB != nil || a.Scheme != b.Scheme || a.Hostname() != b.Hostname() || (a.Port() != "" && a.Port() != b.Port()) {
		return ""
	}
	return current
}

func (service *service) androidCompanionOrigin(packageName, origin string) string {
	origin = androidCompanionOrigin(packageName, origin)
	if origin == "" || strings.HasPrefix(origin, "app://") || !androidFirefoxPackage(packageName) {
		return origin
	}
	// Firefox's AssistStructure omits the port. Cross-check the live normal
	// tab before matching, including its exact port and reported HTTP scheme.
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	output, err := exec.CommandContext(ctx, browserOriginPath, "--android", packageName).Output()
	if err != nil {
		return ""
	}
	return verifiedAndroidBrowserOrigin(origin, strings.TrimSpace(string(output)))
}

func (b *androidAutofillBridge) handle(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Content-Type", "application/json")
	if r.Method != "POST" || r.Header.Get("Origin") != "" || r.Host != androidAutofillAddress {
		http.Error(w, "invalid request", http.StatusForbidden)
		return
	}
	b.mu.Lock()
	valid := b.state.Enabled && b.state.Token != "" && subtle.ConstantTimeCompare(
		[]byte(r.Header.Get("Authorization")), []byte("Bearer "+b.state.Token)) == 1
	b.mu.Unlock()
	if !valid {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	defer r.Body.Close()
	body, err := io.ReadAll(io.LimitReader(r.Body, 16385))
	if err != nil || len(body) > 16384 {
		http.Error(w, "invalid request", 400)
		return
	}
	defer zeroBytes(body)
	var input struct {
		PackageName string `json:"packageName"`
		Origin      string `json:"origin"`
		ID          string `json:"id"`
		Mode        string `json:"mode"`
		Username    string `json:"username"`
		Password    string `json:"password"`
		Active      *bool  `json:"active"`
	}
	if json.Unmarshal(body, &input) != nil {
		http.Error(w, "invalid request", 400)
		return
	}
	defer func() { input.Password = "" }()
	switch r.URL.Path {
	case "/v1/settings":
		if b.service.bus == nil {
			http.Error(w, "settings unavailable", 503)
			return
		}
		// AppSupport can open its own settings activity. Android's setup
		// trampoline returns immediately when FUTO is already selected, and
		// INPUT_METHOD_SETTINGS opens a different page on Sailfish AppSupport.
		ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
		call := b.service.bus.Object("com.jolla.apkd", "/com/jolla/apkd").CallWithContext(ctx,
			"com.jolla.apkd.launchIntent", 0, "android.intent.action.MAIN",
			"package:"+androidAutofillPackage, "", "com.android.settings",
			"com.android.settings.applications.autofill.AutofillPickerActivity", "",
			map[string]dbus.Variant{})
		cancel()
		if call.Err != nil {
			http.Error(w, "settings unavailable", 503)
			return
		}
		json.NewEncoder(w).Encode(map[string]bool{"opened": true})
	case "/v1/status":
		b.mu.Lock()
		if input.Active != nil {
			b.active = *input.Active
		}
		active := b.active
		b.mu.Unlock()
		if input.Active != nil {
			_ = dconfWrite(keyboardSettingsRoot+"androidAutofillActive", boolDconf(active))
		}
		json.NewEncoder(w).Encode(map[string]bool{"enabled": true, "active": active})
	case "/v1/match":
		origin := b.service.androidCompanionOrigin(input.PackageName, input.Origin)
		if origin == "" {
			http.Error(w, "invalid form", 400)
			return
		}
		count := 0
		if b.service.credentialIndex != nil {
			count = b.service.credentialIndex.count(origin)
		}
		b.mu.Lock()
		wasActive := b.active
		b.active = true
		b.mu.Unlock()
		if !wasActive {
			_ = dconfWrite(keyboardSettingsRoot+"androidAutofillActive", "true")
		}
		json.NewEncoder(w).Encode(map[string]interface{}{"count": count, "origin": origin, "saveEnabled": b.service.androidAutofillSavingAllowed()})
	case "/v1/request":
		origin := b.service.androidCompanionOrigin(input.PackageName, input.Origin)
		if origin == "" || (input.Mode != "fill" && input.Mode != "save") || len(input.Password) > 4096 || len(input.Username) > 512 {
			http.Error(w, "invalid form", 400)
			return
		}
		if input.Mode == "save" {
			if !b.service.androidAutofillSavingAllowed() || input.Password == "" {
				http.Error(w, "saving disabled", 403)
				return
			}
		} else if input.Password != "" {
			http.Error(w, "invalid form", 400)
			return
		}
		id, err := randomID()
		if err != nil {
			http.Error(w, "unavailable", 503)
			return
		}
		pending := &androidLoginRequest{ID: id, PackageName: input.PackageName, Origin: origin,
			Label: b.service.androidAutofillLabel(input.PackageName, origin),
			Mode:  input.Mode, Username: input.Username, Password: input.Password, Expires: time.Now().Add(2 * time.Minute)}
		b.mu.Lock()
		if !b.state.Enabled {
			b.mu.Unlock()
			http.Error(w, "disabled", 403)
			return
		}
		if previous := b.pendingLocked(""); previous != nil {
			if previous.Finished && previous.Mode == "save" {
				b.clearPendingLocked()
			} else {
				b.mu.Unlock()
				http.Error(w, "another request is pending", 409)
				return
			}
		}
		b.pending = pending
		b.mu.Unlock()
		if input.Mode == "save" {
			log.Print("Android autofill: save request queued")
		}
		// No bearer token or password is included in a URL, process argument or signal.
		if b.service.bus == nil {
			b.closeRequest(id)
			http.Error(w, "unavailable", 503)
			return
		}
		if input.Mode == "fill" {
			_ = b.service.bus.Emit(objectPath, interfaceName+"."+androidAutofillSignal)
		}
		json.NewEncoder(w).Encode(map[string]string{"id": id, "origin": origin})
		go func() { time.Sleep(2 * time.Minute); b.closeRequest(id) }()
	case "/v1/present":
		b.mu.Lock()
		pending := b.pendingLocked(input.ID)
		if input.ID == "" || pending == nil || pending.Mode != "save" || pending.Finished {
			b.mu.Unlock()
			http.Error(w, "request unavailable", 404)
			return
		}
		alreadyPresented := pending.Presented
		if !alreadyPresented {
			if b.savingAllowed == nil || !b.savingAllowed() {
				b.clearPendingLocked()
				b.mu.Unlock()
				http.Error(w, "saving unavailable", 403)
				return
			}
			pending.Presented = true
			pending.DirectSave = true
			ctx, cancel := context.WithDeadline(context.Background(), pending.Expires)
			pending.Cancel = cancel
			go b.saveInBackground(ctx, input.ID)
			log.Print("Android autofill: device authentication requested")
		}
		b.mu.Unlock()
		json.NewEncoder(w).Encode(map[string]bool{"presented": true})
	case "/v1/result":
		b.mu.Lock()
		pending := b.pendingLocked(input.ID)
		if input.ID == "" || pending == nil {
			b.mu.Unlock()
			http.Error(w, "request unavailable", 404)
			return
		}
		if !pending.Finished {
			// The explicit fill transaction also carries IME visibility across
			// a native system overlay. AppSupport does not consistently forward
			// native window-focus changes to the transparent Android activity.
			if pending.Mode != "fill" {
				b.mu.Unlock()
				http.Error(w, "request unavailable", 404)
				return
			}
			visible, revision := pending.KeyboardVisible, pending.KeyboardRevision
			b.mu.Unlock()
			json.NewEncoder(w).Encode(map[string]interface{}{"pending": true,
				"keyboardVisible": visible, "keyboardRevision": revision})
			return
		}
		result := *pending
		b.clearPendingLocked()
		b.mu.Unlock()
		json.NewEncoder(w).Encode(result)
		result.Password = ""
		result.Username = ""
	case "/v1/cancel":
		b.closeRequest(input.ID)
		json.NewEncoder(w).Encode(map[string]bool{"canceled": true})
	default:
		http.Error(w, "not found", 404)
	}
}

func androidAutofillSavingPreferencesAllowed(read func(string) (string, error)) bool {
	saving, err := read(keyboardSettingsRoot + "passwordSavingEnabled")
	if err != nil || saving == "false" {
		return false
	}
	incognito, err := read(keyboardSettingsRoot + "incognitoMode")
	return err == nil && incognito != "true"
}

func (service *service) androidAutofillSavingAllowed() bool {
	if !androidAutofillSavingPreferencesAllowed(dconfRead) {
		return false
	}
	follow, err := dconfRead(keyboardSettingsRoot + "incognitoOnPrivacySwitch")
	if err != nil {
		return false
	}
	if follow != "true" || service.bus == nil {
		return true
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	var active bool
	call := service.bus.Object("org.sailfishos.privacyswitch", "/privacyswitch").CallWithContext(ctx,
		"org.sailfishos.privacyswitch.privacyModeActive", 0)
	if call.Err != nil {
		if failure, ok := call.Err.(dbus.Error); ok && (failure.Name == "org.freedesktop.DBus.Error.ServiceUnknown" || failure.Name == "org.freedesktop.DBus.Error.NameHasNoOwner") {
			return true // The optional Privacy Switch application is not installed.
		}
		return false
	}
	return call.Store(&active) == nil && !active
}

func boolDconf(value bool) string {
	if value {
		return "true"
	}
	return "false"
}

func (service *service) androidAutofillLabel(packageName, origin string) string {
	label := credentialDisplayOrigin(origin)
	if !strings.HasPrefix(origin, "app://") || service.bus == nil {
		return label
	}
	// Resolve the localized launcher name through AppSupport, not from an
	// untrusted HTTP label. The stable package identity remains the match key.
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	var apps []struct{ Package, Activity, Label, Icon, APK string }
	err := service.bus.Object("com.jolla.apkd", "/com/jolla/apkd").CallWithContext(ctx,
		"com.jolla.apkd.queryIntent", 0, "android.intent.action.MAIN", "", "", packageName,
		"", "", map[string]dbus.Variant{}).Store(&apps)
	if err == nil {
		for _, app := range apps {
			if app.Package == packageName {
				if name := cleanCredentialText(app.Label, 200); name != "" {
					return name
				}
			}
		}
	}
	return label
}
func (b *androidAutofillBridge) closeRequest(id string) {
	if id == "" {
		return
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.pending != nil && b.pending.ID == id {
		b.clearPendingLocked()
	}
}

// Only the keyboard that claimed this exact request may suspend or restore
// its IME. No account names, secrets or vault tokens cross this UI handshake.
func (b *androidAutofillBridge) suspendKeyboard(owner dbus.Sender) string {
	if b == nil {
		return ""
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	pending := b.pendingLocked("")
	if pending == nil || pending.Owner != owner || pending.Mode != "fill" || pending.Finished {
		return ""
	}
	pending.KeyboardVisible = false
	pending.KeyboardRevision++
	return pending.ID
}

func (b *androidAutofillBridge) restoreKeyboard(owner dbus.Sender, id string) {
	if b == nil || id == "" {
		return
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	pending := b.pendingLocked(id)
	if pending == nil || pending.Owner != owner || pending.Mode != "fill" || pending.Finished {
		return
	}
	pending.KeyboardVisible = true
	pending.KeyboardRevision++
}

func (service *service) GetAndroidAutofillState(sender dbus.Sender) (string, *dbus.Error) {
	if !service.trustedNamedVaultCaller(sender, "com.jolla.settings") || service.androidAutofill == nil {
		return "{}", nil
	}
	b := service.androidAutofill
	b.mu.Lock()
	defer b.mu.Unlock()
	data, _ := json.Marshal(map[string]bool{"enabled": b.state.Enabled, "active": b.active})
	return string(data), nil
}

func (service *service) SetAndroidAutofillEnabled(sender dbus.Sender, enabled bool) (bool, *dbus.Error) {
	if !service.trustedNamedVaultCaller(sender, "com.jolla.settings") || service.androidAutofill == nil {
		return false, dbus.MakeFailedError(errors.New("trusted Settings access required"))
	}
	if err := service.androidAutofill.setEnabled(enabled); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	// Disabling the native bridge does not remove Android's selected provider.
	// Check the real selection once on enable, without opening an activity or
	// polling the Android container in the background.
	selected := false
	if enabled {
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		output, err := exec.CommandContext(ctx, appSupportKeyboardPath, "autofill-status").Output()
		cancel()
		selected = err == nil && androidAutofillProviderSelected(string(output))
	}
	b := service.androidAutofill
	b.mu.Lock()
	b.active = selected
	b.mu.Unlock()
	_ = dconfWrite(keyboardSettingsRoot+"androidAutofillEnabled", boolDconf(enabled))
	_ = dconfWrite(keyboardSettingsRoot+"androidAutofillActive", boolDconf(selected))
	return true, nil
}

func androidAutofillProviderSelected(value string) bool {
	packageName, className, found := strings.Cut(strings.TrimSpace(value), "/")
	return found && packageName == androidAutofillPackage &&
		(className == ".FutoAutofillService" || className == androidAutofillPackage+".FutoAutofillService")
}

func (service *service) AndroidAutofillSetupToken(sender dbus.Sender) (string, *dbus.Error) {
	if !service.trustedNamedVaultCaller(sender, "com.jolla.settings") || service.androidAutofill == nil {
		return "", nil
	}
	b := service.androidAutofill
	b.mu.Lock()
	defer b.mu.Unlock()
	if !b.state.Enabled {
		return "", nil
	}
	return b.state.Token, nil
}

func (service *service) ShowAndroidAutofillSetupToast(sender dbus.Sender) (bool, *dbus.Error) {
	if !service.trustedNamedVaultCaller(sender, "com.jolla.settings") || service.androidAutofill == nil {
		return false, dbus.MakeFailedError(errors.New("trusted Settings access required"))
	}
	b := service.androidAutofill
	b.mu.Lock()
	defer b.mu.Unlock()
	if !b.state.Enabled || b.active {
		return false, nil
	}
	if b.toastCancel != nil {
		b.toastCancel()
	}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	command := exec.CommandContext(ctx, "/usr/libexec/futo-keyboard-setup-toast")
	if err := command.Start(); err != nil {
		cancel()
		return false, dbus.MakeFailedError(errors.New("could not show setup feedback"))
	}
	b.toastCancel = cancel
	go func() { _ = command.Wait(); cancel() }()
	return true, nil
}

func (service *service) PendingAndroidAutofill(sender dbus.Sender) (string, *dbus.Error) {
	if !service.trustedNamedVaultCaller(sender, "com.jolla.settings") || service.androidAutofill == nil {
		return "{}", nil
	}
	b := service.androidAutofill
	b.mu.Lock()
	defer b.mu.Unlock()
	pending := b.pendingLocked("")
	if pending == nil || pending.Finished || pending.DirectSave || pending.Mode != "save" || !pending.Presented {
		return "{}", nil
	}
	if pending.Owner != "" && pending.Owner != sender {
		return "{}", nil
	}
	pending.Owner = sender
	data, _ := json.Marshal(map[string]string{"id": pending.ID, "mode": pending.Mode,
		"origin": pending.Origin, "label": pending.Label, "username": pending.Username, "packageName": pending.PackageName})
	return string(data), nil
}

// The keyboard may claim only a fill request. Settings cannot claim that
// request or display a second account list in another application window.
func (service *service) PendingAndroidKeyboardAutofill(sender dbus.Sender) (string, *dbus.Error) {
	if !service.trustedNamedVaultCaller(sender, "com.jolla.keyboard") || service.androidAutofill == nil {
		return "{}", nil
	}
	b := service.androidAutofill
	b.mu.Lock()
	defer b.mu.Unlock()
	pending := b.pendingLocked("")
	if pending == nil || pending.Finished || pending.Mode != "fill" || (pending.Owner != "" && pending.Owner != sender) {
		return "{}", nil
	}
	pending.Owner = sender
	data, _ := json.Marshal(map[string]string{"id": pending.ID, "origin": pending.Origin,
		"packageName": pending.PackageName})
	return string(data), nil
}

func (service *service) ListAndroidAutofillAccounts(sender dbus.Sender, token, id string) (string, *dbus.Error) {
	if !service.trustedVaultCaller(sender) || service.androidAutofill == nil {
		return "[]", nil
	}
	if err := service.validateVaultSession(sender, token); err != nil {
		return "[]", dbus.MakeFailedError(err)
	}
	b := service.androidAutofill
	b.mu.Lock()
	defer b.mu.Unlock()
	pending := b.pendingLocked(id)
	if pending == nil || pending.Owner != sender || pending.Finished || pending.DirectSave {
		return "[]", nil
	}
	entries, err := service.vault.list()
	if err != nil {
		return "[]", dbus.MakeFailedError(err)
	}
	matched := []credentialMetadata{}
	for _, entry := range entries {
		if credentialAutofillOriginMatches(entry.Origin, pending.Origin) {
			matched = append(matched, entry)
		}
	}
	data, _ := json.Marshal(matched)
	return string(data), nil
}

func (service *service) CompleteAndroidAutofill(sender dbus.Sender, token, id, account string, approved bool) (bool, *dbus.Error) {
	if !service.trustedVaultCaller(sender) || service.androidAutofill == nil {
		return false, nil
	}
	if approved {
		if err := service.validateVaultSession(sender, token); err != nil {
			return false, dbus.MakeFailedError(err)
		}
	}
	b := service.androidAutofill
	b.mu.Lock()
	pending := b.pendingLocked(id)
	if pending == nil || pending.Owner != sender || pending.Finished || pending.DirectSave {
		b.mu.Unlock()
		return false, nil
	}
	if approved && pending.Mode == "fill" {
		entries, err := service.vault.list()
		if err != nil {
			b.mu.Unlock()
			return false, dbus.MakeFailedError(err)
		}
		found := false
		for _, entry := range entries {
			if entry.ID != account || !credentialAutofillOriginMatches(entry.Origin, pending.Origin) {
				continue
			}
			secret, err := service.vault.secret(account, "password")
			if err != nil {
				b.mu.Unlock()
				return false, dbus.MakeFailedError(err)
			}
			pending.Username = entry.Username
			pending.Password = secret
			found = true
			break
		}
		if !found {
			b.mu.Unlock()
			return false, nil
		}
	} else if approved && pending.Mode == "save" {
		if !pending.Presented || !service.androidAutofillSavingAllowed() {
			b.clearPendingLocked()
			b.mu.Unlock()
			return false, dbus.MakeFailedError(errors.New("password saving is disabled"))
		}
		label := pending.Label
		if label == "" {
			label = credentialDisplayOrigin(pending.Origin)
		}
		saved, err := service.vault.upsert(label, pending.Origin, pending.Username, pending.Password)
		if err != nil || !saved {
			b.mu.Unlock()
			return false, dbus.MakeFailedError(errors.New("could not save this login"))
		}
		if entries, err := service.vault.list(); err == nil {
			service.refreshCredentialIndex(entries)
		}
		pending.Password = ""
		log.Print("Android autofill: login saved")
	}
	pending.Finished = true
	pending.Approved = approved
	pending.Expires = time.Now().Add(10 * time.Second)
	b.mu.Unlock()
	// The companion consumes the completed result without opening another
	// activity. The original Android authentication result target stays intact.
	go func() { time.Sleep(10 * time.Second); b.closeRequest(id) }()
	return true, nil
}
