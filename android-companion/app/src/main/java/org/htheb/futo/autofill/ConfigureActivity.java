package org.htheb.futo.autofill;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.provider.Settings;
import android.view.autofill.AutofillManager;
import android.widget.TextView;
import org.json.JSONObject;

public final class ConfigureActivity extends Activity {
    private static final String ACTION_ENABLE = "org.htheb.futo.autofill.ENABLE";
    private String token;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        TextView text = new TextView(this);
        text.setPadding(32, 64, 32, 32);
        text.setText("Preparing FUTO Autofill…");
        setContentView(text);
        token = getIntent().getStringExtra("bridge_token");
        if (token == null) token = BridgeClient.token(this);
        new Thread(() -> {
            try {
                BridgeClient.call(token, "status", new JSONObject());
                getSharedPreferences("bridge", MODE_PRIVATE).edit().putString("token", token).commit();
                runOnUiThread(() -> {
                    AutofillManager manager = getSystemService(AutofillManager.class);
                    // The setup action immediately returns when this service is
                    // already selected. AppSupport owns the real settings picker.
                    boolean selected = manager != null && manager.hasEnabledAutofillServices();
                    if (selected) {
                        new Thread(() -> {
                            try {
                                BridgeClient.call(token, "status", new JSONObject().put("active", true));
                                if (!ACTION_ENABLE.equals(getIntent().getAction()))
                                    BridgeClient.call(token, "settings", new JSONObject());
                                runOnUiThread(this::finish);
                            } catch (Exception unavailable) {
                                runOnUiThread(() -> text.setText("Could not open Android autofill settings."));
                            }
                        }, "futo-open-settings").start();
                        return;
                    }
                    Intent request = new Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE);
                    request.setData(Uri.parse("package:" + getPackageName()));
                    try {
                        startActivityForResult(request, 1);
                    }
                    catch (Exception exception) { text.setText("Android autofill is not available on this device."); }
                });
            } catch (Exception exception) {
                runOnUiThread(() -> text.setText("Open FUTO Keyboard settings to set up Android autofill."));
            }
        }, "futo-setup").start();
    }

    @Override protected void onActivityResult(int request, int result, Intent data) {
        super.onActivityResult(request, result, data);
        new Thread(() -> {
            try {
                AutofillManager manager = getSystemService(AutofillManager.class);
                BridgeClient.call(token, "status", new JSONObject().put("active",
                        manager != null && manager.hasEnabledAutofillServices()));
            } catch (Exception ignored) { }
            runOnUiThread(this::finish);
        }, "futo-setup-result").start();
    }
}
