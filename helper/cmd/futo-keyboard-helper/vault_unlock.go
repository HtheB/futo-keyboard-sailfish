package main

import (
	"context"
	"errors"
	"os/exec"
	"strings"
	"time"

	"github.com/godbus/dbus/v5"
)

type vaultUnlockRequest struct {
	id     string
	cancel context.CancelFunc
}

// Only fixed, non-sensitive action identifiers may reach the privileged bridge.
// Both operations require SecurityCode/Fingerprint, never a consent-only agent.
func vaultDeviceAuthenticationCommand(ctx context.Context, action string) (*exec.Cmd, error) {
	switch action {
	case vaultAuthAction:
		return exec.CommandContext(ctx, deviceAuthenticationPath, "--use-login"), nil
	case vaultSaveAuthAction:
		return exec.CommandContext(ctx, deviceAuthenticationPath), nil
	default:
		return nil, errors.New("unsupported vault authorization action")
	}
}

func validVaultUnlockRequest(id string) bool {
	if len(id) == 0 || len(id) > 64 {
		return false
	}
	return strings.IndexFunc(id, func(r rune) bool {
		return !(r >= '0' && r <= '9' || r >= 'a' && r <= 'z' || r == '-')
	}) == -1
}

// Interactive authorization can take longer than Nemo.DBus's 25-second method
// timeout. Acknowledge immediately, then deliver the result only to the exact
// caller's unique bus name. Vault tokens must never be broadcast as signals.
func vaultUnlockCompletion(sender dbus.Sender, id, token string) *dbus.Message {
	return &dbus.Message{
		Type: dbus.TypeSignal,
		Headers: map[dbus.HeaderField]dbus.Variant{
			dbus.FieldPath:        dbus.MakeVariant(objectPath),
			dbus.FieldInterface:   dbus.MakeVariant(interfaceName),
			dbus.FieldMember:      dbus.MakeVariant("VaultUnlockCompleted"),
			dbus.FieldDestination: dbus.MakeVariant(string(sender)),
			dbus.FieldSignature:   dbus.MakeVariant(dbus.SignatureOf(id, token)),
		},
		Body: []interface{}{id, token},
	}
}

func (service *service) BeginVaultUnlock(sender dbus.Sender, id string) (bool, *dbus.Error) {
	if !service.trustedNamedVaultCaller(sender, "com.jolla.keyboard") || !validVaultUnlockRequest(id) {
		return false, dbus.MakeFailedError(errors.New("trusted keyboard authorization required"))
	}
	pid, err := service.connectionPID(string(sender))
	if err != nil || pid == 0 {
		return false, dbus.MakeFailedError(errors.New("keyboard unavailable"))
	}
	ctx, cancel := context.WithTimeout(context.Background(), 135*time.Second)
	request := &vaultUnlockRequest{id: id, cancel: cancel}
	service.vaultUnlockMu.Lock()
	if service.vaultUnlockRequests == nil {
		service.vaultUnlockRequests = make(map[dbus.Sender]*vaultUnlockRequest)
	}
	if service.vaultUnlockRequests[sender] != nil {
		service.vaultUnlockMu.Unlock()
		cancel()
		return false, dbus.MakeFailedError(errors.New("authorization already in progress"))
	}
	service.vaultUnlockRequests[sender] = request
	service.vaultUnlockMu.Unlock()
	go func() {
		defer cancel()
		var token string
		androidRequest := service.androidAutofill.suspendKeyboard(sender)
		if service.authenticateVaultPIDForActionContext(ctx, pid, vaultAuthAction) == nil && ctx.Err() == nil {
			// The unique sender must still identify the original keyboard process.
			if current, err := service.connectionPID(string(sender)); err == nil && current == pid {
				value, dbusErr := service.unlockVaultSession(sender)
				if dbusErr == nil {
					token = value
				}
			}
		}
		if ctx.Err() != nil && token != "" {
			_, _ = service.LockVault(sender, token)
			token = ""
		}
		service.vaultUnlockMu.Lock()
		current := service.vaultUnlockRequests[sender] == request
		if service.vaultUnlockRequests[sender] == request {
			delete(service.vaultUnlockRequests, sender)
		}
		service.vaultUnlockMu.Unlock()
		if !current {
			if token != "" {
				_, _ = service.LockVault(sender, token)
			}
			return
		}
		if token != "" {
			service.androidAutofill.restoreKeyboard(sender, androidRequest)
		}
		call := service.bus.Send(vaultUnlockCompletion(sender, id, token), nil)
		if call.Err != nil && token != "" {
			_, _ = service.LockVault(sender, token)
		}
	}()
	return true, nil
}

func (service *service) CancelVaultUnlock(sender dbus.Sender, id string) (bool, *dbus.Error) {
	if !service.trustedNamedVaultCaller(sender, "com.jolla.keyboard") {
		return false, dbus.MakeFailedError(errors.New("trusted keyboard authorization required"))
	}
	service.vaultUnlockMu.Lock()
	request := service.vaultUnlockRequests[sender]
	if request == nil || request.id != id {
		service.vaultUnlockMu.Unlock()
		return false, nil
	}
	delete(service.vaultUnlockRequests, sender)
	request.cancel()
	service.vaultUnlockMu.Unlock()
	return true, nil
}
