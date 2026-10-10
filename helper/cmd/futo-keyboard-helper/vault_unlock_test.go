package main

import (
	"context"
	"testing"

	"github.com/godbus/dbus/v5"
)

func TestVaultDeviceAuthenticationRequiresNativeIdentityCheck(t *testing.T) {
	for _, test := range []struct {
		action   string
		useLogin bool
	}{{vaultAuthAction, true}, {vaultSaveAuthAction, false}} {
		command, err := vaultDeviceAuthenticationCommand(context.Background(), test.action)
		if err != nil || command.Path != deviceAuthenticationPath {
			t.Fatal("vault operation must use the device authentication bridge")
		}
		if test.useLogin {
			if len(command.Args) != 2 || command.Args[1] != "--use-login" {
				t.Fatal("saved login needs the fixed use-login challenge")
			}
		} else if len(command.Args) != 1 {
			t.Fatal("save challenge must not accept caller-supplied text")
		}
	}
	if command, err := vaultDeviceAuthenticationCommand(context.Background(), "untrusted"); err == nil || command != nil {
		t.Fatal("arbitrary authentication actions must be rejected")
	}
}

func TestVaultUnlockRequestIdentifiers(t *testing.T) {
	for _, id := range []string{"1-12345", "request-1", "a"} {
		if !validVaultUnlockRequest(id) {
			t.Fatalf("valid request rejected: %q", id)
		}
	}
	for _, id := range []string{"", "with space", ":1.42", "\n", "é", string(make([]byte, 65))} {
		if validVaultUnlockRequest(id) {
			t.Fatalf("invalid request accepted: %q", id)
		}
	}
}

func TestVaultUnlockCompletionIsNotBroadcast(t *testing.T) {
	message := vaultUnlockCompletion(dbus.Sender(":1.42"), "request-1", "dummy-token")
	if err := message.IsValid(); err != nil {
		t.Fatalf("invalid completion signal: %v", err)
	}
	if destination := message.Headers[dbus.FieldDestination].Value(); destination != ":1.42" {
		t.Fatalf("vault token lacks its exact caller destination: %v", destination)
	}
	if len(message.Body) != 2 || message.Body[0] != "request-1" || message.Body[1] != "dummy-token" {
		t.Fatal("unexpected completion payload")
	}
}
