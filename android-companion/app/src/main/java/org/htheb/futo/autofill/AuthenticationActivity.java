package org.htheb.futo.autofill;

import android.app.Activity;
import android.app.assist.AssistStructure;
import android.content.Intent;
import android.os.Bundle;
import android.service.autofill.Dataset;
import android.view.autofill.AutofillManager;
import android.view.autofill.AutofillValue;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.view.View;
import android.view.WindowManager;
import android.view.inputmethod.InputMethodManager;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.json.JSONObject;

/** Keeps Android's exact field IDs; native FUTO owns authentication and selection. */
public final class AuthenticationActivity extends Activity {
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private LoginForm form;
    private String verifiedOrigin;
    private volatile String requestId = "";
    private volatile boolean closed;
    private boolean keyboardRequestedVisible = true;
    private int keyboardRevision;
    private EditText keyboardAnchor;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
        // A transparent Android result activity retains the framework's exact
        // field IDs. An empty, non-saving editor keeps Sailfish's keyboard
        // attached; the keyboard itself draws the saved-account chooser.
        FrameLayout surface = new FrameLayout(this);
        keyboardAnchor = new EditText(this);
        keyboardAnchor.setAlpha(0);
        keyboardAnchor.setImportantForAutofill(View.IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS);
        keyboardAnchor.setInputType(android.text.InputType.TYPE_CLASS_TEXT
                | android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD);
        keyboardAnchor.setFilters(new android.text.InputFilter[] { (source, start, end, dest, dstart, dend) -> "" });
        surface.addView(keyboardAnchor, new FrameLayout.LayoutParams(1, 1));
        setContentView(surface);
        form = LoginForm.parse(getIntent().getParcelableExtra(AutofillManager.EXTRA_ASSIST_STRUCTURE));
        verifiedOrigin = getIntent().getStringExtra("origin");
        if (form == null || verifiedOrigin == null || verifiedOrigin.isEmpty()
                || !form.origin.equals(getIntent().getStringExtra("reported_origin"))
                || !form.packageName.equals(getIntent().getStringExtra("packageName"))) { finish(); return; }
        worker.execute(() -> {
            try {
                JSONObject reply = BridgeClient.call(this, "request", form.metadata().put("mode", "fill"));
                requestId = reply.getString("id");
                if (!verifiedOrigin.equals(reply.optString("origin"))) {
                    cancelRequest(); runOnUiThread(this::finish); return;
                }
                if (closed) { cancelRequest(); return; }
                runOnUiThread(this::showKeyboard);
                // This bounded wait exists only during an explicit autofill
                // request. There is no polling while the keyboard is idle.
                long deadline = android.os.SystemClock.elapsedRealtime() + 120000;
                while (!closed && android.os.SystemClock.elapsedRealtime() < deadline) {
                    try {
                        JSONObject result = BridgeClient.call(this, "result", new JSONObject().put("id", requestId));
                        if (result.optBoolean("pending")) {
                            int revision = result.optInt("keyboardRevision");
                            boolean visible = result.optBoolean("keyboardVisible");
                            runOnUiThread(() -> updateKeyboardVisibility(revision, visible));
                            Thread.sleep(350);
                            continue;
                        }
                        complete(result); return;
                    } catch (Exception pending) { Thread.sleep(350); }
                }
                runOnUiThread(this::finish);
            } catch (Exception ignored) { runOnUiThread(this::finish); }
        });
    }

    private void showKeyboard() {
        if (closed || !keyboardRequestedVisible || keyboardAnchor == null || !hasWindowFocus()) return;
        keyboardAnchor.requestFocus();
        keyboardAnchor.post(() -> {
            InputMethodManager manager = getSystemService(InputMethodManager.class);
            if (manager != null && !closed && keyboardRequestedVisible && hasWindowFocus())
                manager.showSoftInput(keyboardAnchor, InputMethodManager.SHOW_IMPLICIT);
        });
    }

    private void updateKeyboardVisibility(int revision, boolean visible) {
        if (closed || revision <= keyboardRevision) return;
        keyboardRevision = revision;
        keyboardRequestedVisible = visible;
        if (visible) showKeyboard();
        else {
            InputMethodManager manager = getSystemService(InputMethodManager.class);
            if (manager != null) manager.hideSoftInputFromWindow(keyboardAnchor.getWindowToken(), 0);
        }
    }

    @Override protected void onResume() { super.onResume(); if (!requestId.isEmpty()) showKeyboard(); }

    @Override public void onWindowFocusChanged(boolean focused) {
        super.onWindowFocusChanged(focused);
        if (keyboardAnchor == null || closed) return;
        if (focused) {
            if (!requestId.isEmpty()) showKeyboard();
        } else {
            // The native device-lock overlay needs the whole screen for its
            // pattern grid/keypad. Restore the keyboard chooser on return.
            InputMethodManager manager = getSystemService(InputMethodManager.class);
            if (manager != null) manager.hideSoftInputFromWindow(keyboardAnchor.getWindowToken(), 0);
        }
    }

    private void complete(JSONObject reply) {
        try {
            if (!reply.optBoolean("approved") || !verifiedOrigin.equals(reply.optString("origin"))) {
                runOnUiThread(this::finish); return;
            }
            String username = reply.optString("username");
            String password = reply.getString("password");
            reply.remove("password");
            android.widget.RemoteViews view = new android.widget.RemoteViews(
                    getPackageName(), android.R.layout.simple_list_item_1);
            view.setTextViewText(android.R.id.text1, username.isEmpty() ? "Saved login" : username);
            Dataset.Builder data = new Dataset.Builder(view);
            if (form.username != null) data.setValue(form.username.getAutofillId(), AutofillValue.forText(username));
            data.setValue(form.password.getAutofillId(), AutofillValue.forText(password));
            Dataset selected = data.build();
            runOnUiThread(() -> {
                if (closed) return;
                closed = true;
                setResult(RESULT_OK, new Intent().putExtra(AutofillManager.EXTRA_AUTHENTICATION_RESULT, selected));
                finish();
            });
        } catch (Exception ignored) { runOnUiThread(this::finish); }
    }

    @Override public void onBackPressed() {
        closed = true;
        cancelRequest();
        super.onBackPressed();
    }

    private void cancelRequest() {
        String id = requestId;
        if (id.isEmpty()) return;
        new Thread(() -> {
            try { BridgeClient.call(getApplicationContext(), "cancel", new JSONObject().put("id", id)); }
            catch (Exception ignored) { }
        }, "futo-autofill-cancel").start();
    }

    @Override protected void onDestroy() {
        closed = true;
        cancelRequest();
        worker.shutdownNow();
        super.onDestroy();
    }
}
