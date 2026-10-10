package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"github.com/godbus/dbus/v5"
)

type nativeCredentialContext struct {
	Reason    string `json:"reason,omitempty"`
	Available bool   `json:"available"`
	Origin    string `json:"origin,omitempty"`
	Field     string `json:"field,omitempty"`
	Username  string `json:"username,omitempty"`
	Password  bool   `json:"password"`
	Revealed  bool   `json:"revealed"`
	ProcessID int32  `json:"processId,omitempty"`
	Filled    bool   `json:"filled"`
	Restored  bool   `json:"restored"`
}

func (service *service) foregroundCredentialPID() (int32, error) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	var pid int32
	err := service.bus.Object("org.nemomobile.lipstick", "/").CallWithContext(ctx,
		"org.nemomobile.compositor.privateTopmostWindowProcessId", 0).Store(&pid)
	if err != nil || pid <= 0 {
		return 0, errors.New("no focused application")
	}
	return pid, nil
}

func nativeEditorRequest(pid int32, request map[string]interface{}) (nativeCredentialContext, error) {
	var result nativeCredentialContext
	if pid <= 0 {
		return result, errors.New("invalid editor process")
	}
	payload, err := json.Marshal(request)
	if err != nil || len(payload) > 32760 {
		return result, errors.New("invalid editor request")
	}
	payload = append(payload, '\n')
	defer zeroBytes(payload)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	command := exec.CommandContext(ctx, "/usr/libexec/futo-keyboard-editor", strconv.Itoa(int(pid)))
	command.Stdin = bytes.NewReader(payload)
	response, err := command.Output()
	if err != nil {
		return result, err
	}
	defer zeroBytes(response)
	if err := json.Unmarshal(response, &result); err != nil {
		return nativeCredentialContext{}, errors.New("invalid editor response")
	}
	result.ProcessID = pid
	return result, nil
}

func (service *service) NativeBrowserCredentialContext(sender dbus.Sender) (string, *dbus.Error) {
	if !service.trustedNamedVaultCaller(sender, "com.jolla.keyboard") {
		return "{}", dbus.MakeFailedError(errors.New("trusted keyboard access required"))
	}
	pid, err := service.foregroundCredentialPID()
	if err != nil {
		return "{}", nil
	}
	application, applicationErr := service.CredentialProcessApplication(sender, pid)
	if applicationErr != nil || application != "sailfish-browser" {
		return "{}", nil
	}
	result, err := nativeEditorRequest(pid, map[string]interface{}{"operation": "context"})
	if err != nil || !result.Available || normalizeCredentialOrigin(result.Origin) == "" {
		return "{}", nil
	}
	result.Origin = normalizeCredentialOrigin(result.Origin)
	data, _ := json.Marshal(result)
	return string(data), nil
}

func credentialAutofillOriginMatches(saved, current string) bool {
	saved = normalizeCredentialOrigin(saved)
	current = normalizeCredentialOrigin(current)
	if saved == "" || current == "" {
		return false
	}
	if saved == current {
		return true
	}
	// An HTTP account can follow an HTTPS upgrade; never downgrade a saved
	// HTTPS credential into an unencrypted HTTP form.
	return strings.HasPrefix(saved, "http://") && strings.HasPrefix(current, "https://") &&
		strings.TrimPrefix(saved, "http://") == strings.TrimPrefix(current, "https://")
}

func (service *service) RestoreNativeCredentialField(sender dbus.Sender, token string,
	pid int32, origin, field string) (bool, *dbus.Error) {
	if err := service.validateVaultSession(sender, token); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	return service.RestoreNativeCredentialFocus(sender, pid, origin, field)
}

// Restoring an already captured foreground field exposes no vault data. It
// must also work after the user cancels authorization, without a vault token.
func (service *service) RestoreNativeCredentialFocus(sender dbus.Sender,
	pid int32, origin, field string) (bool, *dbus.Error) {
	if !service.trustedNamedVaultCaller(sender, "com.jolla.keyboard") {
		return false, dbus.MakeFailedError(errors.New("trusted keyboard access required"))
	}
	foreground, err := service.foregroundCredentialPID()
	if err != nil || foreground != pid {
		return false, nil
	}
	result, err := nativeEditorRequest(pid, map[string]interface{}{
		"operation": "restore", "origin": origin, "field": field,
	})
	return err == nil && result.Restored, nil
}

func (service *service) AutofillNativeCredential(sender dbus.Sender, token, id string,
	pid int32, origin, field string) (bool, *dbus.Error) {
	if err := service.validateVaultSession(sender, token); err != nil {
		return false, dbus.MakeFailedError(err)
	}
	foreground, err := service.foregroundCredentialPID()
	if err != nil || foreground != pid {
		return false, nil
	}
	entries, err := service.vault.list()
	if err != nil {
		return false, dbus.MakeFailedError(err)
	}
	for _, entry := range entries {
		if entry.ID != id || !credentialAutofillOriginMatches(entry.Origin, origin) {
			continue
		}
		secret, err := service.vault.secret(id, "password")
		if err != nil {
			return false, dbus.MakeFailedError(err)
		}
		result, err := nativeEditorRequest(pid, map[string]interface{}{
			"operation": "fill", "origin": origin, "field": field,
			"username": entry.Username, "secret": secret,
		})
		return err == nil && result.Filled, nil
	}
	return false, nil
}
