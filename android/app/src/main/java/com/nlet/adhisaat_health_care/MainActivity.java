package com.nlet.adhisaat_health_care;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.android.gms.auth.api.phone.SmsRetriever;
import com.google.android.gms.common.api.CommonStatusCodes;
import com.google.android.gms.common.api.Status;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {

    // Channel name must match the one used in the Flutter OTP page.
    private static final String CHANNEL = "sms_user_consent";
    private static final int SMS_CONSENT_REQUEST = 2;

    private MethodChannel methodChannel;
    private BroadcastReceiver smsConsentReceiver;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        methodChannel = new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);

        methodChannel.setMethodCallHandler((call, result) -> {
            if ("startSmsUserConsent".equals(call.method)) {
                startSmsUserConsent();
                result.success(null); // returns immediately; OTP comes via invokeMethod callback
            } else if ("cancelSmsUserConsent".equals(call.method)) {
                unregisterSmsReceiver();
                result.success(null);
            } else {
                result.notImplemented();
            }
        });
    }

    // ── Step 1: tell Google Play Services to watch for an incoming SMS ──────
    private void startSmsUserConsent() {
        SmsRetriever.getClient(this)
                .startSmsUserConsent(null) // null = accept from any sender
                .addOnSuccessListener(unused -> registerSmsConsentReceiver())
                .addOnFailureListener(e -> {
                    if (methodChannel != null) {
                        methodChannel.invokeMethod("error", "Consent start failed: " + e.getMessage());
                    }
                });
    }

    // ── Step 2: receive the consent Intent and start the system dialog ──────
    private void registerSmsConsentReceiver() {
        smsConsentReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                if (!SmsRetriever.SMS_RETRIEVED_ACTION.equals(intent.getAction())) return;
                Bundle extras = intent.getExtras();
                if (extras == null) return;
                Status status = (Status) extras.get(SmsRetriever.EXTRA_STATUS);
                if (status == null) return;

                if (status.getStatusCode() == CommonStatusCodes.SUCCESS) {
                    // Launch the system consent bottom-sheet to the user.
                    Intent consentIntent = extras.getParcelable(SmsRetriever.EXTRA_CONSENT_INTENT);
                    if (consentIntent != null) {
                        try {
                            startActivityForResult(consentIntent, SMS_CONSENT_REQUEST);
                        } catch (Exception e) {
                            if (methodChannel != null) {
                                methodChannel.invokeMethod("error", e.getMessage());
                            }
                        }
                    }
                }
            }
        };

        IntentFilter filter = new IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION);
        // Android 13+ requires RECEIVER_EXPORTED for system-broadcast receivers.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(smsConsentReceiver, filter,
                    SmsRetriever.SEND_PERMISSION, null, Context.RECEIVER_EXPORTED);
        } else {
            registerReceiver(smsConsentReceiver, filter, SmsRetriever.SEND_PERMISSION, null);
        }
    }

    // ── Step 3: user tapped "Allow" — extract OTP and send to Flutter ───────
    @Override
    protected void onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != SMS_CONSENT_REQUEST) return;

        if (resultCode == RESULT_OK && data != null) {
            String smsMessage = data.getStringExtra(SmsRetriever.EXTRA_SMS_MESSAGE);
            String otp = extractOtp(smsMessage);
            if (methodChannel != null && !otp.isEmpty()) {
                // Invoke Flutter: _smsConsentChannel receives 'smsCode' event.
                methodChannel.invokeMethod("smsCode", otp);
            }
        }
        // Always clean up the receiver regardless of result.
        unregisterSmsReceiver();
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private void unregisterSmsReceiver() {
        if (smsConsentReceiver != null) {
            try { unregisterReceiver(smsConsentReceiver); } catch (Exception ignored) {}
            smsConsentReceiver = null;
        }
    }

    /** Extracts the first 6-digit number from the SMS body. */
    private String extractOtp(String message) {
        if (message == null || message.isEmpty()) return "";
        Matcher matcher = Pattern.compile("\\b(\\d{6})\\b").matcher(message);
        return matcher.find() ? matcher.group(1) : "";
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        unregisterSmsReceiver();
    }
}
