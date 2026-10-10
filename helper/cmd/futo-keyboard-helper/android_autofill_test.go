package main

import (
	"encoding/json"
	"errors"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/godbus/dbus/v5"
)

func TestAndroidAutofillProviderSelection(t *testing.T) {
	for _, test := range []struct {
		value    string
		selected bool
	}{
		{androidAutofillPackage + "/" + androidAutofillPackage + ".FutoAutofillService\n", true},
		{"  " + androidAutofillPackage + "/.FutoAutofillService  ", true},
		{"null", false}, {"", false},
		{"org.mozilla.firefox/.AutofillService", false},
		{androidAutofillPackage + "/.OtherService", false},
		{"org.example/" + androidAutofillPackage + ".FutoAutofillService", false},
		{androidAutofillPackage + "/.FutoAutofillService/extra", false},
	} {
		if actual := androidAutofillProviderSelected(test.value); actual != test.selected {
			t.Errorf("provider %q: got %v, expected %v", test.value, actual, test.selected)
		}
	}
}

func TestAndroidAutofillKeyboardHandoffIsOwnedAndContainsNoCredentials(t *testing.T) {
	owner := dbus.Sender(":1.100")
	b := &androidAutofillBridge{service: &service{}, state: androidAutofillState{
		Enabled: true, Token: strings.Repeat("a", 64)}, pending: &androidLoginRequest{
		ID: "fill-request", Mode: "fill", Owner: owner,
		Username: "test-user", Password: "test-secret", Expires: time.Now().Add(time.Minute)}}
	if b.suspendKeyboard(":1.101") != "" || b.pending.KeyboardRevision != 0 {
		t.Fatal("another keyboard suspended a request it does not own")
	}
	id := b.suspendKeyboard(owner)
	if id != "fill-request" || b.pending.KeyboardVisible || b.pending.KeyboardRevision != 1 {
		t.Fatal("owned authentication did not suspend the Android IME")
	}
	b.restoreKeyboard(":1.101", id)
	b.restoreKeyboard(owner, "old-request")
	if b.pending.KeyboardVisible || b.pending.KeyboardRevision != 1 {
		t.Fatal("stale or foreign authentication restored the IME")
	}
	b.restoreKeyboard(owner, id)
	request := httptest.NewRequest("POST", "http://"+androidAutofillAddress+"/v1/result", strings.NewReader(`{"id":"fill-request"}`))
	request.Header.Set("Authorization", "Bearer "+b.state.Token)
	response := httptest.NewRecorder()
	b.handle(response, request)
	var result map[string]interface{}
	if response.Code != 200 || json.Unmarshal(response.Body.Bytes(), &result) != nil ||
		result["pending"] != true || result["keyboardVisible"] != true || result["keyboardRevision"] != float64(2) {
		t.Fatal("authenticated fill did not restore the Android chooser keyboard")
	}
	if len(result) != 3 || b.pending == nil || b.pending.Finished {
		t.Fatal("IME handshake exposed credentials or consumed the unfinished request")
	}
	b.closeRequest(id)
	b.restoreKeyboard(owner, id)
	if b.pending != nil {
		t.Fatal("late authentication revived a canceled request")
	}
}

func TestAndroidAutofillSaveRespectsPrivacy(t *testing.T) {
	for _, test := range []struct {
		saving, incognito string
		failed, allowed   bool
	}{
		{"", "", false, true}, {"true", "false", false, true},
		{"false", "false", false, false}, {"true", "true", false, false},
		{"true", "false", true, false},
	} {
		read := func(key string) (string, error) {
			if test.failed {
				return "", errors.New("unavailable")
			}
			if strings.HasSuffix(key, "passwordSavingEnabled") {
				return test.saving, nil
			}
			return test.incognito, nil
		}
		if got := androidAutofillSavingPreferencesAllowed(read); got != test.allowed {
			t.Errorf("saving %q incognito %q failed %v: got %v", test.saving, test.incognito, test.failed, got)
		}
	}
}

func TestAndroidAutofillPresentCannotOpenFillOrUnknownRequest(t *testing.T) {
	b := &androidAutofillBridge{service: &service{}, state: androidAutofillState{
		Enabled: true, Token: strings.Repeat("a", 64)}, pending: &androidLoginRequest{
		ID: "fill-request", Mode: "fill", Expires: time.Now().Add(time.Minute)}}
	for _, id := range []string{"", "unknown", "fill-request"} {
		request := httptest.NewRequest("POST", "http://"+androidAutofillAddress+"/v1/present", strings.NewReader(`{"id":"`+id+`"}`))
		request.Header.Set("Authorization", "Bearer "+b.state.Token)
		response := httptest.NewRecorder()
		b.handle(response, request)
		if response.Code != 404 || b.pending.Presented {
			t.Fatal("fill request or unknown nonce opened the save UI")
		}
	}
}

func TestAndroidAutofillSignalIsIntrospected(t *testing.T) {
	for _, signal := range helperIntrospectionInterface(&service{}).Signals {
		if signal.Name == androidAutofillSignal && len(signal.Args) == 0 {
			return
		}
	}
	t.Fatal("keyboard cannot subscribe to the companion handoff")
}

func TestAndroidCompanionOriginBoundaries(t *testing.T) {
	for _, test := range []struct{ pkg, origin, expected string }{
		{"org.example.app", "app://org.example.app", "app://org.example.app"},
		{"org.example.app", "app://org.other.app", ""},
		{"org.example.app", "https://bank.example", ""},
		{"com.android.chrome", "https://bank.example/login", "https://bank.example"},
		{"org.mozilla.firefox", "http://localhost:8765/path", "http://localhost:8765"},
		{"org.mozilla.firefox", "https://user@bank.example", ""},
		{"org.mozilla.firefox", "javascript://bank.example", ""},
		{androidAutofillPackage, "app://" + androidAutofillPackage, ""},
		{"none", "app://none", ""},
	} {
		if got := androidCompanionOrigin(test.pkg, test.origin); got != test.expected {
			t.Errorf("%s %s: got %q, expected %q", test.pkg, test.origin, got, test.expected)
		}
	}
}

func TestAndroidBrowserOriginIncludesVerifiedPort(t *testing.T) {
	for _, test := range []struct{ reported, current, expected string }{
		{"http://example.test", "http://example.test:8765/path", "http://example.test:8765"},
		{"https://example.test", "http://example.test", ""},
		{"https://example.test", "https://other.test", ""},
		{"http://example.test:8765", "http://example.test:9876", ""},
		{"https://example.test", "", ""},
		{"app://org.example.app", "https://example.test", ""},
	} {
		if got := verifiedAndroidBrowserOrigin(test.reported, test.current); got != test.expected {
			t.Errorf("reported %q current %q: got %q", test.reported, test.current, got)
		}
	}
}

func TestAndroidAutofillHTTPRejectsUnauthorizedRequests(t *testing.T) {
	b := &androidAutofillBridge{service: &service{}, state: androidAutofillState{
		Enabled: true, Token: strings.Repeat("a", 64)}}
	for _, test := range []struct{ method, token, host, origin string }{
		{"POST", "", androidAutofillAddress, ""},
		{"POST", strings.Repeat("b", 64), androidAutofillAddress, ""},
		{"GET", b.state.Token, androidAutofillAddress, ""},
		{"POST", b.state.Token, "malicious.example", ""},
		{"POST", b.state.Token, androidAutofillAddress, "https://malicious.example"},
	} {
		request := httptest.NewRequest(test.method, "http://"+test.host+"/v1/status", strings.NewReader("{}"))
		request.Header.Set("Authorization", "Bearer "+test.token)
		request.Header.Set("Origin", test.origin)
		response := httptest.NewRecorder()
		b.handle(response, request)
		if response.Code == 200 {
			t.Fatal("unauthorized request accepted")
		}
	}
}

func TestAndroidAutofillSettingsUnavailable(t *testing.T) {
	b := &androidAutofillBridge{service: &service{}, state: androidAutofillState{
		Enabled: true, Token: strings.Repeat("a", 64)}}
	request := httptest.NewRequest("POST", "http://"+androidAutofillAddress+"/v1/settings", strings.NewReader("{}"))
	request.Header.Set("Authorization", "Bearer "+b.state.Token)
	response := httptest.NewRecorder()
	b.handle(response, request)
	if response.Code != 503 {
		t.Fatal("settings launch reported success without AppSupport")
	}
}

func TestAndroidAutofillCompletedSaveDoesNotBlockFill(t *testing.T) {
	for _, test := range []struct {
		mode     string
		finished bool
		status   int
	}{{"save", true, 503}, {"save", false, 409}, {"fill", true, 409}} {
		b := &androidAutofillBridge{service: &service{}, state: androidAutofillState{
			Enabled: true, Token: strings.Repeat("a", 64)}, pending: &androidLoginRequest{
			ID: "previous", Mode: test.mode, Finished: test.finished, Expires: time.Now().Add(time.Minute)}}
		request := httptest.NewRequest("POST", "http://"+androidAutofillAddress+"/v1/request",
			strings.NewReader(`{"packageName":"org.example.app","origin":"app://org.example.app","mode":"fill"}`))
		request.Header.Set("Authorization", "Bearer "+b.state.Token)
		response := httptest.NewRecorder()
		b.handle(response, request)
		// Without a D-Bus connection a newly accepted request ends in 503,
		// not 409. An unfinished request or unconsumed fill must stay intact.
		if response.Code != test.status {
			t.Fatalf("%s finished=%v: got %d, expected %d", test.mode, test.finished, response.Code, test.status)
		}
	}
}

func TestAndroidAutofillResultConsumedOnce(t *testing.T) {
	b := &androidAutofillBridge{service: &service{}, state: androidAutofillState{
		Enabled: true, Token: strings.Repeat("a", 64)}, pending: &androidLoginRequest{
		ID: "only-this-request", Origin: "https://login.example", Mode: "fill", Approved: true,
		Finished: true, Username: "test-account", Password: "dummy-secret", Expires: time.Now().Add(time.Minute)}}
	call := func(id string) *httptest.ResponseRecorder {
		request := httptest.NewRequest("POST", "http://"+androidAutofillAddress+"/v1/result",
			strings.NewReader(`{"id":"`+id+`"}`))
		request.Header.Set("Authorization", "Bearer "+b.state.Token)
		response := httptest.NewRecorder()
		b.handle(response, request)
		return response
	}
	if call("wrong-request").Code != 404 {
		t.Fatal("wrong request consumed result")
	}
	response := call("only-this-request")
	if response.Code != 200 || !strings.Contains(response.Body.String(), "dummy-secret") {
		t.Fatal("valid result missing")
	}
	if b.pending != nil || call("only-this-request").Code != 404 {
		t.Fatal("result was reusable")
	}
}

func TestAndroidAutofillExpiryClearsSecrets(t *testing.T) {
	pending := &androidLoginRequest{ID: "expired", Password: "dummy", Username: "dummy",
		Expires: time.Now().Add(-time.Second)}
	b := &androidAutofillBridge{pending: pending}
	if b.pendingLocked("expired") != nil || b.pending != nil || pending.Password != "" || pending.Username != "" {
		t.Fatal("expired request retained secret data")
	}
}

func TestAndroidAutofillConfigIsPrivateAndOptional(t *testing.T) {
	dir := t.TempDir()
	service := &service{dataDirectory: dir}
	b, err := newAndroidAutofillBridge(service)
	if err != nil || b.state.Enabled || b.server != nil || b.state.Token != "" {
		t.Fatal("fresh install must be inert")
	}
	if _, err := os.Stat(filepath.Join(dir, "android-autofill.json")); !os.IsNotExist(err) {
		t.Fatal("unused feature wrote a token")
	}
	b.state.Token = strings.Repeat("a", 64)
	if err := b.persistLocked(); err != nil {
		t.Fatal(err)
	}
	info, _ := os.Stat(b.path)
	if info.Mode().Perm() != 0600 {
		t.Fatal("bridge token must not be public")
	}
	data, _ := os.ReadFile(b.path)
	var state androidAutofillState
	if json.Unmarshal(data, &state) != nil || state.Token != b.state.Token || state.Enabled {
		t.Fatal("invalid persisted state")
	}
	if b, err := newAndroidAutofillBridge(service); err != nil || b.server != nil {
		t.Fatal("disabled bridge starts a listener")
	}
}
