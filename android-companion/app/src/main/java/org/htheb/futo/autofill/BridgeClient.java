package org.htheb.futo.autofill;

import android.content.Context;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import org.json.JSONObject;

/** Local-only transport. The companion never persists credentials. */
final class BridgeClient {
    static final class Failure extends Exception {
        final int status;
        Failure(int status) { super("FUTO bridge request failed"); this.status = status; }
    }
    static String token(Context context) {
        return context.getSharedPreferences("bridge", Context.MODE_PRIVATE).getString("token", "");
    }

    static JSONObject call(Context context, String path, JSONObject request) throws Exception {
        return call(token(context), path, request);
    }

    static JSONObject call(String token, String path, JSONObject request) throws Exception {
        if (!token.matches("[0-9a-f]{64}")) throw new Exception("Companion is not configured");
        HttpURLConnection connection = (HttpURLConnection) new URL(
                "http://127.0.0.1:39767/v1/" + path).openConnection();
        connection.setConnectTimeout(1500);
        connection.setReadTimeout(5000);
        connection.setInstanceFollowRedirects(false);
        connection.setRequestMethod("POST");
        connection.setRequestProperty("Authorization", "Bearer " + token);
        connection.setRequestProperty("Content-Type", "application/json");
        connection.setDoOutput(true);
        byte[] body = request.toString().getBytes(StandardCharsets.UTF_8);
        try {
            connection.setFixedLengthStreamingMode(body.length);
            try (OutputStream output = connection.getOutputStream()) { output.write(body); }
            int status = connection.getResponseCode();
            if (status != 200) throw new Failure(status);
            try (InputStream input = connection.getInputStream();
                 ByteArrayOutputStream output = new ByteArrayOutputStream()) {
                byte[] buffer = new byte[1024];
                int count;
                while ((count = input.read(buffer)) != -1) {
                    if (output.size() + count > 16384) throw new Exception("Invalid bridge response");
                    output.write(buffer, 0, count);
                }
                Arrays.fill(buffer, (byte) 0);
                byte[] response = output.toByteArray();
                try { return new JSONObject(new String(response, StandardCharsets.UTF_8)); }
                finally { Arrays.fill(response, (byte) 0); }
            }
        } finally { Arrays.fill(body, (byte) 0); connection.disconnect(); }
    }
}
