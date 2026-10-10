import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists a pending notification action across Dart isolate boundaries
/// using SharedPreferences.
///
/// Problem: When the provider taps ACCEPT on a system notification while
/// the app is killed, AwesomeNotifications fires [onActionReceivedMethod]
/// in a background isolate. At that point ProviderDashboardBloc doesn't
/// exist yet. An in-memory singleton won't work because the background
/// isolate and the main app isolate have separate heaps.
///
/// Solution: Write the pending action to SharedPreferences (disk) in the
/// background isolate. When ProviderDashboardBloc mounts in the main
/// isolate, it calls [consume()] which reads + deletes the stored action.
class PendingNotificationAction {
  // SharedPreferences key
  static const _kKey = 'pending_notification_action';

  PendingNotificationAction._();
  static final PendingNotificationAction instance = PendingNotificationAction._();

  /// Stores the action to disk. Safe to call from any isolate.
  static Future<void> store({
    required String type,
    required String requestId,
    required bool isEmergency,
    required Map<String, String?> payload,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode({
        'type': type,
        'request_id': requestId,
        'is_emergency': isEmergency,
        'payload': payload,
      });
      await prefs.setString(_kKey, json);
    } catch (e) {
      // Non-fatal — log and continue
      debugPrint('⚠️ PendingNotificationAction.store failed: $e');
    }
  }

  /// Reads and **deletes** the stored action. Returns null if none.
  /// Call this from the main isolate only (inside the bloc).
  static Future<PendingAction?> consume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw == null) return null;

      await prefs.remove(_kKey); // consume = read + clear
      final map = jsonDecode(raw) as Map<String, dynamic>;

      return PendingAction(
        type:        map['type'] as String,
        requestId:   map['request_id'] as String,
        isEmergency: map['is_emergency'] as bool,
        payload: (map['payload'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v?.toString())),
      );
    } catch (e) {
      debugPrint('⚠️ PendingNotificationAction.consume failed: $e');
      return null;
    }
  }

  /// Checks if there is a pending action without consuming it.
  static Future<bool> hasPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_kKey);
    } catch (_) {
      return false;
    }
  }
}

class PendingAction {
  final String type;
  final String requestId;
  final bool isEmergency;
  final Map<String, String?> payload;

  const PendingAction({
    required this.type,
    required this.requestId,
    required this.isEmergency,
    required this.payload,
  });
}