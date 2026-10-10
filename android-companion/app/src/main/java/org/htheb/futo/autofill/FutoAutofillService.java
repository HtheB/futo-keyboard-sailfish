package org.htheb.futo.autofill;

import android.app.PendingIntent;
import android.content.Intent;
import android.content.Context;
import android.database.ContentObserver;
import android.os.Build;
import android.os.CancellationSignal;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.service.autofill.AutofillService;
import android.service.autofill.Dataset;
import android.service.autofill.FillCallback;
import android.service.autofill.FillRequest;
import android.service.autofill.FillResponse;
import android.service.autofill.SaveCallback;
import android.service.autofill.SaveInfo;
import android.service.autofill.SaveRequest;
import android.view.autofill.AutofillId;
import android.view.autofill.AutofillManager;
import android.widget.RemoteViews;
import android.widget.Toast;
import android.util.Log;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;
import org.json.JSONObject;

public final class FutoAutofillService extends AutofillService {
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private static final AtomicInteger serial = new AtomicInteger();
    private final ContentObserver selectionObserver = new ContentObserver(new Handler(Looper.getMainLooper())) {
        @Override public void onChange(boolean selfChange) { reportSelection(); }
    };

    @Override public void onCreate() {
        super.onCreate();
        getContentResolver().registerContentObserver(
                Settings.Secure.getUriFor("autofill_service"), false, selectionObserver);
    }

    private void reportSelection() {
        // Android can deliver onDisconnected after onDestroy. An idle service
        // unbind must never crash an in-progress authentication activity.
        if (worker.isShutdown()) return;
        AutofillManager manager = getSystemService(AutofillManager.class);
        boolean selected = manager != null && manager.hasEnabledAutofillServices();
        worker.execute(() -> {
            try { BridgeClient.call(this, "status", new JSONObject().put("active", selected)); }
            catch (Exception ignored) { }
        });
    }

    @Override public void onConnected() {
        super.onConnected();
        reportSelection();
    }

    @Override public void onDisconnected() {
        reportSelection();
        super.onDisconnected();
    }

    @Override public void onFillRequest(FillRequest request, CancellationSignal cancellation,
                                       FillCallback callback) {
        LoginForm form = LoginForm.parse(request.getFillContexts().get(
                request.getFillContexts().size() - 1).getStructure());
        if (form == null || BridgeClient.token(this).isEmpty()) { callback.onSuccess(null); return; }
        worker.execute(() -> {
            try {
                JSONObject status = BridgeClient.call(this, "match", form.metadata());
                if (cancellation.isCanceled()) return;
                FillResponse.Builder response = new FillResponse.Builder();
                boolean any = false;
                if (status.optInt("count") > 0) {
                    RemoteViews presentation = new RemoteViews(getPackageName(), android.R.layout.simple_list_item_1);
                    presentation.setTextViewText(android.R.id.text1, "Use a saved FUTO login");
                    Intent intent = new Intent(this, AuthenticationActivity.class);
                    intent.putExtra("origin", status.getString("origin"));
                    intent.putExtra("reported_origin", form.origin);
                    intent.putExtra("packageName", form.packageName);
                    int flags = PendingIntent.FLAG_CANCEL_CURRENT;
                    if (Build.VERSION.SDK_INT >= 31) flags |= PendingIntent.FLAG_MUTABLE;
                    // Authenticate a dataset, not the whole response. Returning
                    // that dataset fills both fields immediately after the
                    // keyboard selection instead of showing a second chooser.
                    Dataset.Builder protectedLogin = new Dataset.Builder(presentation);
                    if (form.username != null) protectedLogin.setValue(form.username.getAutofillId(), null);
                    protectedLogin.setValue(form.password.getAutofillId(), null);
                    protectedLogin.setAuthentication(PendingIntent.getActivity(this,
                            serial.incrementAndGet(), intent, flags).getIntentSender());
                    response.addDataset(protectedLogin.build());
                    any = true;
                }
                if (Build.VERSION.SDK_INT >= 28 && status.optBoolean("saveEnabled")) {
                    SaveInfo.Builder save = new SaveInfo.Builder(SaveInfo.SAVE_DATA_TYPE_PASSWORD,
                            new AutofillId[] { form.password.getAutofillId() });
                    if (form.username != null) save.setOptionalIds(new AutofillId[] { form.username.getAutofillId() });
                    response.setSaveInfo(save.build());
                    response.setClientState(form.saveState()); any = true;
                }
                callback.onSuccess(any ? response.build() : null);
            } catch (Exception ignored) {
                if (!cancellation.isCanceled()) callback.onSuccess(null);
            }
        });
    }

    @Override public void onSaveRequest(SaveRequest request, SaveCallback callback) {
        Log.i("FutoAutofill", "Save requested");
        if (Build.VERSION.SDK_INT < 28) {
            callback.onFailure("This Android version does not support native save confirmation."); return;
        }
        LoginForm form = LoginForm.parseForSave(request.getFillContexts(), request.getClientState());
        if (form == null || LoginForm.value(form.password).isEmpty()) {
            Log.w("FutoAutofill", form == null ? "Save rejected: form_unrecognized"
                    : "Save rejected: password_empty");
            saveFailure(callback, "The login form could not be verified. No password was saved."); return;
        }
        worker.execute(() -> {
            String requestId = "";
            JSONObject candidate = null;
            try {
                candidate = form.metadata().put("mode", "save")
                        .put("username", LoginForm.value(form.username))
                        .put("password", LoginForm.value(form.password));
                JSONObject reply = BridgeClient.call(this, "request", candidate);
                candidate.remove("password");
                if (reply.optString("id").isEmpty()) throw new Exception();
                requestId = reply.getString("id");
                // Login activities commonly finish on success. Android's save
                // continuation would then ask that dead activity to open us.
                // The helper opens Sailfish's device-authentication overlay,
                // not a FUTO activity or Settings window. Android Save is
                // consent; device authentication protects the encrypted write.
                BridgeClient.call(this, "present", new JSONObject().put("id", requestId));
                Log.i("FutoAutofill", "Save handed to device authentication");
                callback.onSuccess();
                watchSaveResult(getApplicationContext(), requestId);
            } catch (Exception failure) {
                // Never log credentials, tokens, request bodies or exception
                // messages. Android hides service errors on newer versions.
                Log.w("FutoAutofill", "Save rejected: " + (failure instanceof BridgeClient.Failure
                        ? "bridge_http_" + ((BridgeClient.Failure) failure).status
                        : failure.getClass().getSimpleName()));
                if (!requestId.isEmpty()) {
                    try { BridgeClient.call(this, "cancel", new JSONObject().put("id", requestId)); }
                    catch (Exception unavailable) { }
                }
                saveFailure(callback, "FUTO could not save this login. Please try again.");
            } finally {
                if (candidate != null) candidate.remove("password");
            }
        });
    }

    private static void watchSaveResult(Context context, String requestId) {
        // Active-request-only, bounded polling. It survives the login activity
        // and service callback closing; no credentials are sent in the result.
        Thread watcher = new Thread(() -> {
            long deadline = android.os.SystemClock.elapsedRealtime() + 120000;
            while (android.os.SystemClock.elapsedRealtime() < deadline) {
                try {
                    JSONObject result = BridgeClient.call(context, "result",
                            new JSONObject().put("id", requestId));
                    String error = result.optString("error");
                    if (!error.isEmpty()) new Handler(Looper.getMainLooper()).post(() ->
                            Toast.makeText(context, error, Toast.LENGTH_LONG).show());
                    return;
                } catch (BridgeClient.Failure failure) {
                    if (failure.status != 404) return;
                } catch (Exception unavailable) { return; }
                try { Thread.sleep(350); }
                catch (InterruptedException canceled) { return; }
            }
        }, "FutoSaveResult");
        watcher.setDaemon(true);
        watcher.start();
    }

    private void saveFailure(SaveCallback callback, String message) {
        // Recent Android versions suppress onFailure messages. A continuation
        // makes failure visible instead of making Save appear successful.
        Intent failure = new Intent(this, SaveConfirmationActivity.class);
        failure.putExtra("save_error", message);
        callback.onSuccess(PendingIntent.getActivity(this, serial.incrementAndGet(), failure,
                PendingIntent.FLAG_CANCEL_CURRENT | PendingIntent.FLAG_IMMUTABLE).getIntentSender());
    }

    @Override public void onDestroy() {
        getContentResolver().unregisterContentObserver(selectionObserver);
        // Let a final selection update finish without keeping an idle worker.
        worker.shutdown();
        super.onDestroy();
    }
}
