package main

import (
	"context"
	"errors"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func TestAndroidDirectSaveRequiresAuthenticationAndRechecksPrivacy(t *testing.T) {
	for _, test := range []struct {
		name                 string
		authError, saveError error
		allowed, saved       bool
	}{
		{"authenticated", nil, nil, true, true},
		{"rejected", errors.New("rejected"), nil, true, false},
		{"privacy changed", nil, nil, false, false},
		{"encrypted write failed", nil, errors.New("write failed"), true, false},
	} {
		t.Run(test.name, func(t *testing.T) {
			var writes int
			b := &androidAutofillBridge{service: &service{}, pending: &androidLoginRequest{
				ID: "save", Mode: "save", Presented: true, DirectSave: true,
				Password: "dummy", Username: "dummy-user", Expires: time.Now().Add(time.Minute)}}
			b.authenticateSave = func(context.Context) error {
				if writes != 0 {
					t.Fatal("saved before authentication")
				}
				return test.authError
			}
			b.commitSave = func(p *androidLoginRequest) error {
				writes++
				if p.Password != "dummy" || p.Username != "dummy-user" {
					t.Fatal("candidate lost")
				}
				return test.saveError
			}
			b.savingAllowed = func() bool { return test.allowed }
			b.saveInBackground(context.Background(), "save")
			if !b.pending.Finished || b.pending.Approved != test.saved {
				t.Fatal("incorrect save result")
			}
			if b.pending.Password != "" || b.pending.Username != "" {
				t.Fatal("save result retained credentials")
			}
			if test.saveError != nil && b.pending.Error == "" {
				t.Fatal("encrypted write failure hidden")
			}
			b.saveInBackground(context.Background(), "save")
			if writes > 1 {
				t.Fatal("same consent wrote twice")
			}
		})
	}
}

func TestAndroidDirectSaveRejectsExpiredAndCanceledRequests(t *testing.T) {
	for _, expired := range []bool{false, true} {
		ctx, cancel := context.WithCancel(context.Background())
		b := &androidAutofillBridge{service: &service{}, pending: &androidLoginRequest{
			ID: "save", DirectSave: true, Password: "dummy", Cancel: cancel,
			Expires: time.Now().Add(time.Minute)}}
		if expired {
			b.pending.Expires = time.Now().Add(-time.Second)
		}
		b.authenticateSave = func(context.Context) error {
			if !expired {
				b.closeRequest("save")
			}
			return nil
		}
		b.savingAllowed = func() bool { return true }
		b.commitSave = func(*androidLoginRequest) error { t.Fatal("expired/canceled login saved"); return nil }
		b.saveInBackground(ctx, "save")
		if b.pending != nil || ctx.Err() == nil {
			t.Fatal("request/authorization not canceled")
		}
		cancel()
	}
}

func TestAndroidDirectSavePresentIsAsyncAndSingleUse(t *testing.T) {
	var prompts, writes atomic.Int32
	started, release, committed := make(chan struct{}), make(chan struct{}), make(chan struct{})
	b := &androidAutofillBridge{service: &service{}, state: androidAutofillState{
		Enabled: true, Token: strings.Repeat("a", 64)}, pending: &androidLoginRequest{
		ID: "save", Mode: "save", Password: "dummy", Expires: time.Now().Add(time.Minute)}}
	b.savingAllowed = func() bool { return true }
	b.authenticateSave = func(context.Context) error { prompts.Add(1); close(started); <-release; return nil }
	b.commitSave = func(*androidLoginRequest) error { writes.Add(1); close(committed); return nil }
	for i := 0; i < 2; i++ {
		request := httptest.NewRequest("POST", "http://"+androidAutofillAddress+"/v1/present", strings.NewReader(`{"id":"save"}`))
		request.Header.Set("Authorization", "Bearer "+b.state.Token)
		response := httptest.NewRecorder()
		b.handle(response, request)
		if response.Code != 200 {
			t.Fatal("handoff did not return immediately")
		}
	}
	<-started
	if writes.Load() != 0 {
		t.Fatal("wrote before user authentication")
	}
	close(release)
	select {
	case <-committed:
	case <-time.After(time.Second):
		t.Fatal("save stalled")
	}
	b.mu.Lock()
	if prompts.Load() != 1 || writes.Load() != 1 || !b.pending.DirectSave {
		t.Error("duplicate handoff")
	}
	b.mu.Unlock()
}
