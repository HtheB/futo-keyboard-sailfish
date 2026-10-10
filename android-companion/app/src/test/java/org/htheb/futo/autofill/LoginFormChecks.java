package org.htheb.futo.autofill;

/** Dependency-free host checks; no credential values are collected. */
public final class LoginFormChecks {
    public static void main(String[] args) {
        check("http://192.168.1.63:8765", LoginForm.webOrigin("http", "192.168.1.63:8765"));
        check("https://example.test", LoginForm.webOrigin("https", "EXAMPLE.test"));
        check("", LoginForm.webOrigin("", "example.test"));
        check("", LoginForm.webOrigin("javascript", "example.test"));
        check("", LoginForm.webOrigin("https", "user@example.test"));
        check("", LoginForm.webOrigin("https", "example.test/path"));
        check("", LoginForm.webOrigin("https", "example.test?query"));
        check("", LoginForm.webOrigin("https", "example.test#fragment"));
        check("", LoginForm.webOrigin("https", "example.test:65536"));
        check("", LoginForm.webOrigin("https", null));
        if (!LoginForm.isBrowser("org.mozilla.firefox") || LoginForm.isBrowser("org.example.app")) {
            throw new AssertionError("Unverified app was treated as a browser");
        }
        for (int type : new int[] { 0x81, 0x91, 0xe1, 0x12, 0x80081 }) {
            if (!LoginForm.passwordInputType(type)) throw new AssertionError("Password type not recognized");
        }
        for (int type : new int[] { 1, 2, 0x21, 0x82, 0x83, 0x90 }) {
            if (LoginForm.passwordInputType(type)) throw new AssertionError("Non-password type misclassified");
        }
        System.out.println("Android credential origin checks passed");
    }

    private static void check(String expected, String actual) {
        if (!expected.equals(actual)) throw new AssertionError("Invalid document origin handling");
    }
}
