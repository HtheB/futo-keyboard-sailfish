package main

import "testing"

func TestCredentialAutofillOriginMatches(t *testing.T) {
	for _, test := range []struct {
		saved, current string
		matches        bool
	}{
		{"https://example.test/path", "https://EXAMPLE.test/login", true},
		{"http://example.test", "https://example.test", true},
		{"https://example.test", "http://example.test", false},
		{"https://example.test", "https://example.test.evil", false},
		{"https://example.test", "https://example.test:8443", false},
		{"app://example.test", "https://example.test", false},
		{"", "https://example.test", false},
	} {
		if got := credentialAutofillOriginMatches(test.saved, test.current); got != test.matches {
			t.Errorf("origin match for %q, %q: got %v, want %v",
				test.saved, test.current, got, test.matches)
		}
	}
}
