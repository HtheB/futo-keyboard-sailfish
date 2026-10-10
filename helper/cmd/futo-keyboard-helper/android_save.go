package main

import (
	"context"
	"errors"
	"log"
	"os/exec"
	"time"
)

const deviceAuthenticationPath = "/usr/libexec/futo-keyboard-device-auth"

func (service *service) authenticateAndroidSave(ctx context.Context) error {
	// A narrowly privileged client presents Sailfish's normal unlock component
	// as a system overlay. It creates no Settings window or Android activity.
	return exec.CommandContext(ctx, deviceAuthenticationPath).Run()
}

func (service *service) saveAuthenticatedAndroidLogin(pending *androidLoginRequest) error {
	defer service.lockVaultWhenNoSessions()
	if err := service.ensureVaultOpen(true); err != nil {
		return err
	}
	label := pending.Label
	if label == "" {
		label = credentialDisplayOrigin(pending.Origin)
	}
	saved, err := service.vault.upsert(label, pending.Origin, pending.Username, pending.Password)
	if err != nil || !saved {
		return errors.New("could not save this login")
	}
	if entries, err := service.vault.list(); err == nil {
		service.refreshCredentialIndex(entries)
	}
	return nil
}

func (b *androidAutofillBridge) saveInBackground(ctx context.Context, id string) {
	// Serialize with other vault prompts. Cancellation/expiry still applies
	// while waiting, so a stale request cannot open a later surprise prompt.
	b.service.vaultAuthRunMu.Lock()
	defer b.service.vaultAuthRunMu.Unlock()
	if ctx.Err() != nil {
		return
	}
	b.mu.Lock()
	current := b.pendingLocked(id)
	valid := current != nil && !current.Finished && current.DirectSave
	b.mu.Unlock()
	if !valid {
		return
	}
	err := b.authenticateSave(ctx)
	b.mu.Lock()
	defer b.mu.Unlock()
	pending := b.pendingLocked(id)
	if pending == nil || pending.Finished || !pending.DirectSave || ctx.Err() != nil {
		return
	}
	if err == nil && b.savingAllowed() {
		err = b.commitSave(pending)
		if err == nil {
			pending.Approved = true
			log.Print("Android autofill: login saved")
		} else {
			pending.Error = "FUTO could not save this login. Please try again."
			log.Print("Android autofill: encrypted save failed")
		}
	} else if err != nil {
		var exit *exec.ExitError
		if !errors.As(err, &exit) || exit.ExitCode() != 1 {
			pending.Error = "Device authentication is unavailable. The login was not saved."
			log.Print("Android autofill: device authentication unavailable")
		}
	} // Reject/cancel/disabled saving never writes and never repeats consent.
	pending.Password = ""
	pending.Username = ""
	pending.Finished = true
	pending.Expires = time.Now().Add(10 * time.Second)
	go func() { time.Sleep(10 * time.Second); b.closeRequest(id) }()
}
