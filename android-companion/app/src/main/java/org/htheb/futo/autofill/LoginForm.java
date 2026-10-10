package org.htheb.futo.autofill;

import android.app.assist.AssistStructure;
import android.os.Build;
import android.os.Bundle;
import android.service.autofill.FillContext;
import android.text.InputType;
import android.util.Pair;
import android.view.View;
import android.view.autofill.AutofillId;
import android.view.autofill.AutofillValue;
import java.net.URI;
import java.util.ArrayList;
import java.util.IdentityHashMap;
import java.util.List;
import java.util.Locale;
import org.json.JSONObject;

/** Refuse ambiguous forms instead of guessing where a password belongs. */
final class LoginForm {
    final String packageName;
    final String origin;
    final AssistStructure.ViewNode username;
    final AssistStructure.ViewNode password;

    private LoginForm(String packageName, String origin, AssistStructure.ViewNode username,
                      AssistStructure.ViewNode password) {
        this.packageName = packageName; this.origin = origin;
        this.username = username; this.password = password;
    }

    AutofillId[] ids() {
        return username == null ? new AutofillId[] { password.getAutofillId() }
                : new AutofillId[] { username.getAutofillId(), password.getAutofillId() };
    }

    JSONObject metadata() throws Exception {
        return new JSONObject().put("packageName", packageName).put("origin", origin);
    }

    Bundle saveState() {
        // Only field identities and their verified source are retained. The
        // Android framework supplies the final values in the save request.
        Bundle state = new Bundle();
        state.putString("package", packageName);
        state.putString("origin", origin);
        state.putParcelable("password_id", password.getAutofillId());
        if (username != null) state.putParcelable("username_id", username.getAutofillId());
        return state;
    }

    static LoginForm parseForSave(List<FillContext> contexts, Bundle state) {
        if (contexts == null || contexts.isEmpty()) return null;
        if (state == null) return parse(contexts.get(contexts.size() - 1).getStructure());
        String pkg = state.getString("package", "");
        String expectedOrigin = state.getString("origin", "");
        AutofillId passwordId = state.getParcelable("password_id");
        AutofillId usernameId = state.getParcelable("username_id");
        if (!pkg.matches("[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z0-9_]+)+")
                || pkg.equals("org.htheb.futo.autofill") || passwordId == null
                || passwordId.equals(usernameId) || expectedOrigin.isEmpty()) return null;
        for (int i = contexts.size() - 1; i >= 0; i--) {
            AssistStructure structure = contexts.get(i).getStructure();
            if (structure == null || structure.getActivityComponent() == null
                    || !pkg.equals(structure.getActivityComponent().getPackageName())) continue;
            for (int j = 0; j < structure.getWindowNodeCount(); j++) {
                Collector collector = new Collector();
                collector.savedFields = true;
                collector.visit(structure.getWindowNodeAt(j).getRootViewNode(), "");
                if (collector.excessive) return null;
                AssistStructure.ViewNode pass = null, user = null;
                for (AssistStructure.ViewNode node : collector.origins.keySet()) {
                    if (passwordId.equals(node.getAutofillId())) pass = node;
                    if (usernameId != null && usernameId.equals(node.getAutofillId())) user = node;
                }
                if (pass == null) continue;
                if (usernameId != null && user == null) return null;
                String passOrigin = isBrowser(pkg) ? collector.origins.get(pass)
                        : "app://" + pkg.toLowerCase(Locale.ROOT);
                if (!expectedOrigin.equals(passOrigin)
                        || (isBrowser(pkg) && user != null
                            && !expectedOrigin.equals(collector.origins.get(user)))
                        || (!isBrowser(pkg) && !collector.origins.get(pass).isEmpty())) return null;
                // Submitted forms may now be disabled, hidden or on an earlier
                // screen. Do not reclassify them or guess another password:
                // use exactly the fields approved by the original SaveInfo.
                return new LoginForm(pkg, expectedOrigin, user, pass);
            }
        }
        return null;
    }

    static String value(AssistStructure.ViewNode node) {
        if (node == null) return "";
        AutofillValue value = node.getAutofillValue();
        return value != null && value.isText() ? value.getTextValue().toString() : "";
    }

    static LoginForm parse(AssistStructure structure) {
        if (structure == null || structure.getActivityComponent() == null) return null;
        String pkg = structure.getActivityComponent().getPackageName();
        if (!pkg.matches("[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z0-9_]+)+")
                || pkg.equals("org.htheb.futo.autofill")) return null;
        LoginForm result = null;
        for (int i = 0; i < structure.getWindowNodeCount(); i++) {
            Collector collector = new Collector();
            collector.visit(structure.getWindowNodeAt(i).getRootViewNode(), "");
            if (collector.excessive || collector.passwords.size() != 1) continue;
            AssistStructure.ViewNode pass = collector.passwords.get(0);
            List<AssistStructure.ViewNode> users = collector.usernames;
            if (users.isEmpty()) users = collector.texts;
            if (users.size() > 1) continue;
            AssistStructure.ViewNode user = users.isEmpty() ? null : users.get(0);
            String origin = "app://" + pkg.toLowerCase(Locale.ROOT);
            String webOrigin = collector.origins.get(pass);
            if (isBrowser(pkg)) {
                if (webOrigin == null || webOrigin.isEmpty()) continue;
                origin = webOrigin;
                if (user != null && !origin.equals(collector.origins.get(user))) continue;
            } else if (webOrigin != null && !webOrigin.isEmpty()) {
                // An arbitrary app cannot impersonate a website through HtmlInfo.
                continue;
            }
            if (result != null) return null;
            result = new LoginForm(pkg, origin, user, pass);
        }
        return result;
    }

    static boolean isBrowser(String pkg) {
        switch (pkg) {
            case "org.mozilla.firefox": case "org.mozilla.firefox_beta":
            case "org.mozilla.fenix": case "org.mozilla.fenix.nightly":
            case "org.mozilla.fennec_fdroid": case "org.mozilla.focus":
            case "org.mozilla.focus.beta": case "org.mozilla.klar": case "org.mozilla.klar.beta":
            case "us.spotco.fennec_dos": case "io.github.forkmaintainers.iceraven":
            case "net.waterfox.android.release": case "org.torproject.torbrowser":
            case "org.torproject.torbrowser_alpha": case "org.chromium.chrome":
            case "com.android.chrome": case "com.chrome.beta": case "com.chrome.dev":
            case "com.brave.browser": case "com.microsoft.emmx":
            case "com.opera.browser": case "com.vivaldi.browser":
            case "com.duckduckgo.mobile.android": return true;
            default: return false;
        }
    }

    static String webOrigin(String scheme, String domain) {
        // Never assume HTTPS when the browser did not report the scheme:
        // doing so could send an HTTPS credential to an HTTP document.
        if (domain == null || domain.isEmpty() || !("http".equals(scheme) || "https".equals(scheme))) return "";
        try {
            URI uri = new URI(scheme + "://" + domain);
            if (uri.getHost() == null || uri.getUserInfo() != null || uri.getQuery() != null
                    || uri.getFragment() != null || uri.getPort() > 65535
                    || (uri.getPath() != null && !uri.getPath().isEmpty())) return "";
            return uri.toString().toLowerCase(Locale.ROOT);
        } catch (Exception ignored) { return ""; }
    }

    static boolean passwordInputType(int inputType) {
        int inputClass = inputType & InputType.TYPE_MASK_CLASS;
        int variation = inputType & InputType.TYPE_MASK_VARIATION;
        return (inputClass == InputType.TYPE_CLASS_TEXT
                && (variation == InputType.TYPE_TEXT_VARIATION_PASSWORD
                    || variation == InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD
                    || variation == InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD))
                || (inputClass == InputType.TYPE_CLASS_NUMBER
                    && variation == InputType.TYPE_NUMBER_VARIATION_PASSWORD);
    }

    private static final class Collector {
        int visited;
        boolean excessive;
        boolean savedFields;
        final List<AssistStructure.ViewNode> passwords = new ArrayList<>();
        final List<AssistStructure.ViewNode> usernames = new ArrayList<>();
        final List<AssistStructure.ViewNode> texts = new ArrayList<>();
        final IdentityHashMap<AssistStructure.ViewNode, String> origins = new IdentityHashMap<>();

        void visit(AssistStructure.ViewNode node, String inheritedOrigin) {
            if (node == null || excessive) return;
            if (++visited > 2000) { excessive = true; return; }
            String origin = inheritedOrigin;
            String domain = node.getWebDomain();
            if (domain != null && !domain.isEmpty()) {
                origin = webOrigin(Build.VERSION.SDK_INT >= 28 ? node.getWebScheme() : "", domain);
                // Invalid document metadata blocks this subtree; do not fall
                // back to the parent website across an iframe boundary.
                if (origin.isEmpty()) return;
            }
            if (node.getAutofillId() != null && node.getAutofillType() == View.AUTOFILL_TYPE_TEXT
                    && (savedFields || (node.getVisibility() == View.VISIBLE && node.isEnabled()))) {
                String hints = String.join(" ", node.getAutofillHints() == null
                        ? new String[0] : node.getAutofillHints()).toLowerCase(Locale.ROOT);
                String htmlType = "";
                if (node.getHtmlInfo() != null && node.getHtmlInfo().getAttributes() != null) {
                    for (Pair<String, String> attribute : node.getHtmlInfo().getAttributes()) {
                        if (attribute.first.equalsIgnoreCase("autocomplete")) hints += " " + attribute.second;
                        if (attribute.first.equalsIgnoreCase("type")) htmlType = attribute.second;
                    }
                    hints = hints.toLowerCase(Locale.ROOT);
                }
                String identity = ((node.getIdEntry() == null ? "" : node.getIdEntry()) + " "
                        + (node.getHint() == null ? "" : node.getHint())).toLowerCase(Locale.ROOT);
                boolean pass = hints.contains("password") || htmlType.equalsIgnoreCase("password")
                        || passwordInputType(node.getInputType());
                boolean excluded = hints.contains("new-password") || hints.contains("newpassword")
                        || hints.contains("one-time-code") || identity.matches(".*(otp|verification|search).*");
                if (!excluded) {
                    origins.put(node, origin);
                    if (pass) passwords.add(node);
                    else if (hints.contains("username") || hints.contains("email")
                            || htmlType.equalsIgnoreCase("email")
                            || identity.matches(".*(username|user_name|email|e-mail|login).*")) usernames.add(node);
                    else texts.add(node);
                }
            }
            for (int i = 0; i < node.getChildCount(); i++) visit(node.getChildAt(i), origin);
        }
    }
}
