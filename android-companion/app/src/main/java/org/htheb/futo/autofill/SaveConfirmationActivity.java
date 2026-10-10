package org.htheb.futo.autofill;

import android.app.Activity;
import android.app.AlertDialog;
import android.os.Bundle;
import android.view.WindowManager;
import android.widget.FrameLayout;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.json.JSONObject;

/** Android's private save continuation; native FUTO shows the confirmation. */
public final class SaveConfirmationActivity extends Activity {
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private volatile boolean closed;
    private String requestId = "";

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
        setContentView(new FrameLayout(this));
        String error = getIntent().getStringExtra("save_error");
        if (error != null) {
            new AlertDialog.Builder(this).setTitle("Login not saved").setMessage(error)
                    .setPositiveButton("Close", (dialog, which) -> finish())
                    .setOnCancelListener(dialog -> finish()).show();
            return;
        }
        requestId = getIntent().getStringExtra("request_id");
        if (requestId == null || !requestId.matches("[0-9a-f]+")) { finish(); return; }
        worker.execute(() -> {
            try {
                BridgeClient.call(this, "present", new JSONObject().put("id", requestId));
                long deadline = android.os.SystemClock.elapsedRealtime() + 120000;
                while (!closed && android.os.SystemClock.elapsedRealtime() < deadline) {
                    try {
                        JSONObject result = BridgeClient.call(this, "result", new JSONObject().put("id", requestId));
                        runOnUiThread(() -> { setResult(result.optBoolean("approved") ? RESULT_OK : RESULT_CANCELED); finish(); });
                        return;
                    } catch (Exception pending) { Thread.sleep(350); }
                }
            } catch (Exception ignored) { }
            runOnUiThread(this::finish);
        });
    }

    @Override protected void onDestroy() {
        closed = true;
        worker.shutdownNow();
        final String id = requestId;
        if (id != null && !id.isEmpty()) new Thread(() -> {
            try { BridgeClient.call(getApplicationContext(), "cancel", new JSONObject().put("id", id)); }
            catch (Exception ignored) { }
        }, "futo-save-cancel").start();
        super.onDestroy();
    }
}
