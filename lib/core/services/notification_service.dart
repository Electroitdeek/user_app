import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/auth_wrapper/data/role_enums.dart';
import '../../features/auth/login/bloc/auth_bloc.dart';
import '../widgets/provider_blocked_dialog.dart';
import '../../data/repositories/provider_repository.dart';
import '../../di/locator.dart';
import '../../core/storage/local_storage_service.dart';
import '../api/api_client.dart';
import '../navigation/app_routes.dart';
import 'notification_keys.dart';
import 'incoming_request_manager.dart';
import 'package:intl/intl.dart';
import 'pending_notification_action.dart';
import '../constants/app_constants.dart';

typedef NotificationBlocCallback = void Function(String type, Map<String, dynamic> data);

// ─────────────────────────────────────────────────────────────────
// Channel keys
// ─────────────────────────────────────────────────────────────────
const _kBasicChannel = 'basic_channel';
const _kBookingChannel = 'booking_channel';
const _kServiceRequestChannel = 'service_request_channel';
const _kEmergencyChannel = 'emergency_channel'; // emergency_request

// ─────────────────────────────────────────────────────────────────
// Deduplication — prevents iOS double-delivery
// On iOS, Firebase Messaging can deliver the same message to BOTH
// the background handler AND onMessage when the app resumes from
// background. We deduplicate by request_id using SharedPreferences
// (works across Dart isolate boundaries).
// ─────────────────────────────────────────────────────────────────
const _kDedupKey = '_notif_dedup_ids';
const _kDedupWindowMs = 5 * 60 * 1000; // 5 minutes

// In-memory fast-path dedup — catches same-isolate duplicates instantly
// without any async I/O and narrows the race-condition window for
// cross-isolate cases (background isolate vs. main isolate).
final Map<String, int> _inMemoryDedup = {};

/// Returns [true] if [id] was already processed recently (duplicate).
/// If not a duplicate, marks [id] as processed and returns [false].
/// Safe to call from any isolate.
Future<bool> _checkAndMarkProcessed(String id) async {
  if (id.isEmpty) return false;
  final now = DateTime.now().millisecondsSinceEpoch;

  // ── Fast path: in-memory check (same isolate, zero latency) ────
  final cached = _inMemoryDedup[id];
  if (cached != null && now - cached < _kDedupWindowMs) {
    debugPrint('⚠️ [DEDUP-MEM] Duplicate suppressed for id: $id');
    return true;
  }
  // Mark in-memory BEFORE the async SharedPreferences write to minimise
  // the race window with another concurrent call in the same isolate.
  _inMemoryDedup[id] = now;
  // Purge stale entries to keep the map small.
  _inMemoryDedup.removeWhere((_, v) => now - v >= _kDedupWindowMs);

  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kDedupKey) ?? [];

    // Decode: each entry is "id:timestamp"
    final active = <String, int>{};
    for (final e in raw) {
      final sep = e.lastIndexOf(':');
      if (sep == -1) continue;
      final k = e.substring(0, sep);
      final t = int.tryParse(e.substring(sep + 1)) ?? 0;
      if (now - t < _kDedupWindowMs) active[k] = t;
    }

    if (active.containsKey(id)) {
      debugPrint('⚠️ [DEDUP] Duplicate suppressed for id: $id');
      return true;
    }

    // Mark as processed
    active[id] = now;
    await prefs.setStringList(_kDedupKey, active.entries.map((e) => '${e.key}:${e.value}').toList());
    return false;
  } catch (e) {
    debugPrint('⚠️ [DEDUP] SharedPreferences error: $e');
    return false; // Allow processing if we can't check
  }
}

/// Computes the deterministic notification ID used in both the background
/// handler and the foreground handler so we can cancel/replace correctly.
int _notifIdForRequest(String requestId) => requestId.isNotEmpty
    ? requestId.hashCode.abs() % 100000
    : DateTime.now().millisecondsSinceEpoch.remainder(100000);

// ─────────────────────────────────────────────────────────────────
// Safe navigation helper for notification-driven deep links.
//
// Problem: pushNamedAndRemoveUntil(..., route.isFirst) keeps only
// the very first route in the stack (often a blank splash/bootstrap
// screen). When the user presses Back from serviceRequestDetail they
// land on a black screen and the app appears to exit.
//
// Fix: always ensure userDashboard is the backstop beneath the
// target page. We do this by:
//   1. Popping everything until userDashboard is on top, OR
//   2. If userDashboard is not in the stack, clear the stack,
//      push userDashboard, then push the target on top.
//
// Result: Back from any notification-launched page always returns
// the user to the main dashboard — never a blank screen.
// ─────────────────────────────────────────────────────────────────
void _navigateToDetailSafely(String targetRoute, Object? arguments, {String? backRoute}) {
  final navState = AppNavigator.navigatorKey.currentState;
  if (navState == null) return;

  final String actualBackRoute = backRoute ?? AppRoutes.userDashboard;

  // Check whether backRoute is already somewhere in the stack.
  bool dashboardInStack = false;
  navState.popUntil((route) {
    if (route.settings.name == actualBackRoute || route.isFirst) {
      dashboardInStack = route.settings.name == actualBackRoute;
      return true; // stop popping
    }
    return false; // keep popping
  });

  if (dashboardInStack) {
    // Dashboard is now on top — push the target over it.
    navState.pushNamed(targetRoute, arguments: arguments);
  } else {
    // Dashboard is not a named route in the stack — this app's home is the
    // AuthWrapper (which itself renders the dashboard with all its BlocProviders).
    // Pushing a bare named dashboard route here would lack those providers and
    // hang/crash. Instead push the target over the existing root (we already
    // popped to first), so Back returns to the AuthWrapper-hosted dashboard.
    navState.pushNamed(targetRoute, arguments: arguments);
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // ── Stream-based notification delivery ──────────────────────────
  // Multiple pages (e.g. Dashboard + RequestDetail) can listen
  // simultaneously. This prevents the "overwriting listener" bug.
  final StreamController<Map<String, dynamic>> _notificationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get notificationsStream => _notificationStreamController.stream;

  Future<void> requestNotificationPermission() async {
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );
  }

  // Backward compatibility for existing registerBlocCallback pattern
  final Map<NotificationBlocCallback, StreamSubscription> _subscriptions = {};

  void registerBlocCallback(NotificationBlocCallback callback) {
    if (_subscriptions.containsKey(callback)) return;

    final subscription = notificationsStream.listen((event) {
      final type = event['type']?.toString() ?? '';
      final data = event['data'] as Map<String, dynamic>? ?? {};
      callback(type, data);
    });

    _subscriptions[callback] = subscription;
  }

  /// Call this in the registering page's dispose() so a stale callback
  /// never fires on a dead widget.
  void unregisterBlocCallback(NotificationBlocCallback callback) {
    final subscription = _subscriptions.remove(callback);
    subscription?.cancel();
  }

  void _triggerBlocEvent(String type, Map<String, dynamic> data) {
    // 1. Dispatch to all active stream listeners
    _notificationStreamController.add({'type': type, 'data': data});

    // 2. FALLBACK: if no active listeners for critical types, show banner
    // (Wait a tick to see if any listener was active - simplified logic below)
    if (_subscriptions.isEmpty) {
      debugPrint('⚠️ No active listeners for notification type: $type');
    }
  }

  // ───────────────────────────────────────────────────────────────
  // Initialization
  // ───────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    await AwesomeNotifications().initialize('resource://drawable/res_notification_icon', [
      NotificationChannel(
        channelKey: _kBasicChannel,
        channelName: 'General',
        channelDescription: 'General app notifications',
        defaultColor: const Color(0xFF2D62ED),
        ledColor: Colors.white,
        importance: NotificationImportance.High,
        channelShowBadge: true,
        playSound: true,
        enableVibration: true,
      ),
      NotificationChannel(
        channelKey: _kBookingChannel,
        channelName: 'Bookings',
        channelDescription: 'Service booking updates',
        defaultColor: const Color(0xFF4CAF50),
        ledColor: Colors.white,
        importance: NotificationImportance.Max,
        channelShowBadge: true,
        playSound: true,
        enableVibration: true,
      ),
      if (AppConstants.isProviderApp) ...[
        // Service request — max priority, locked channel, vibration + sound alert for providers
        NotificationChannel(
          channelKey: _kServiceRequestChannel,
          channelName: 'Service Requests',
          channelDescription: 'New service requests assigned to you — accept or reject within the response window',
          defaultColor: const Color(0xFFFF6B00),
          ledColor: Colors.orange,
          importance: NotificationImportance.Max,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
          // criticalAlerts: true,
          // defaultRingtoneType: DefaultRingtoneType.Notification,
          locked: true,
        ),
        // Emergency request — custom sound, emergency vibration, wakes device even in DND
        NotificationChannel(
          channelKey: _kEmergencyChannel,
          channelName: 'Emergency Requests',
          channelDescription: 'Incoming emergency requests — respond immediately',
          defaultColor: const Color(0xFFDC2626),
          ledColor: Colors.red,
          importance: NotificationImportance.Max,
          channelShowBadge: true,
          playSound: true,
          soundSource: 'resource://raw/uber_dispatch_alert',
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500, 200, 1000]),
          // criticalAlerts: true,
          locked: true,
        ),
      ],
    ], debug: true);

    _setupListeners();
    await _initializeFCM();
  }

  void _setupListeners() {
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
      onNotificationCreatedMethod: onNotificationCreatedMethod,
      onNotificationDisplayedMethod: onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: onDismissActionReceivedMethod,
    );
  }

  // ───────────────────────────────────────────────────────────────
  // FCM setup
  // ───────────────────────────────────────────────────────────────
  Future<void> _initializeFCM() async {
    // Permission request moved to PermissionGate for better UX
    
    String? token;
    try {
      token = await _fcm.getToken();
      debugPrint('🔑 FCM Token: $token');
    } catch (e) {
      kPrintError('❌ Error during FCM initialization (getToken): $e');
    }

    _fcm.onTokenRefresh.listen((t) {
      debugPrint('🔄 FCM Token refreshed: $t');
      _triggerBlocEvent('fcm_token_refresh', {'token': t});
    });

    // Enable foreground presentation options for iOS native notification support
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // ── STATE 1: FOREGROUND ──────────────────────────────────────
    // App is open and visible. FCM delivers to onMessage.
    FirebaseMessaging.onMessage.listen(_handleForeground);

    // ── STATE 2: BACKGROUND ─────────────────────────────────────
    // App is running but not visible. FCM delivers to the background
    // handler which posts an AwesomeNotification. When provider taps
    // ACCEPT/REJECT the onActionReceivedMethod fires — bloc IS alive.
    // NOTE: FirebaseMessaging.onBackgroundMessage() is registered in main.dart
    // BEFORE Firebase.initializeApp() — that is the only place it is valid.
    // Registering it here (after init) would have no effect and was the source
    // of the "No top-level getter" crash in the background isolate.

    // App brought to foreground by tapping notification BODY (background state).
    // onMessageOpenedApp fires AFTER the app resumes — bloc is alive.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedFromBackground);

    // ── STATE 3: KILLED ──────────────────────────────────────────
    // App was not running. Background handler posts notification.
    // Provider taps notification → app launches cold.
    // getInitialMessage gives us the FCM message that launched the app.
    // But for ACCEPT/REJECT button taps: onActionReceivedMethod fires
    // before the bloc exists → we use SharedPreferences queue.
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🚀 App launched from killed state via notification tap');
      _handleLaunchedFromKilled(initialMessage);
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final data = message.data;
    final notification = message.notification;
    final type = data['type'] ?? '';
    final requestId = data['request_id']?.toString() ?? '';

    // Ignore request types that have custom in-app overlays
    if (type == 'service_request' || type == 'emergency_request') {
      return;
    }

    final bool isAcceptance = type == 'request_accepted';
    final bool isCancellation = type == 'booking_cancelled';
    final bool isRefund = type == 'booking_cancelled_refund';

    final String channelKey = (isAcceptance || isCancellation || isRefund)
        ? _kBookingChannel
        : (type.contains('booking') ? _kBookingChannel : _kBasicChannel);

    final String? title = data['title']?.toString() ?? notification?.title;
    final String? body = data['body']?.toString() ?? notification?.body;

    if (title == null && body == null && !isAcceptance && !isCancellation && !isRefund) {
      debugPrint('📨 [FOREGROUND] Empty title/body and not a known transaction type — skipping local notification');
      return;
    }

    final notificationId = _notifIdForRequest(requestId);

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: notificationId,
        channelKey: channelKey,
        title: title ?? (isCancellation ? '❌ Booking Cancelled' : 'Notification'),
        body: body ?? 'You have a new update',
        payload: {
          'type': type,
          ...data.map((k, v) => MapEntry(k, v.toString())),
        },
        notificationLayout: NotificationLayout.Default,
        largeIcon: 'resource://mipmap/ic_launcher',
      ),
      actionButtons: (isAcceptance || isCancellation || isRefund)
          ? [NotificationActionButton(key: 'VIEW', label: 'View Details', actionType: ActionType.Default)]
          : null,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STATE 1 — FOREGROUND
  // FCM message arrives while app is open and visible.
  // ● Show in-app overlay directly (no system notification).
  // ● For emergency: show full-screen overlay like Uber/Ola driver
  // ═══════════════════════════════════════════════════════════════
  void _handleForeground(RemoteMessage message) {
    kPrint('📨 [FOREGROUND] Raw message: ${jsonEncode(message.toMap())}');
    final data = message.data;
    final type = data['type'] ?? '';
    debugPrint('📨 [FOREGROUND] type: $type');

    // Role filter: ignore notifications not meant for this app flavor
    final sendTo = data['send_to']?.toString();
    if (sendTo != null && sendTo.isNotEmpty) {
      final forProvider = sendTo == 'provider' || sendTo == 'service_provider';
      if (forProvider != AppConstants.isProviderApp) {
        debugPrint('🚫 [FOREGROUND] Ignored — send_to=$sendTo but this is ${AppConstants.isProviderApp ? 'provider' : 'user'} app');
        return;
      }
    }

    // Show a standard system notification banner in the foreground for non-request notifications
    _showLocalNotification(message);

    switch (type) {
      case 'service_request':
      case 'emergency_request':
        final isEmergency = type == 'emergency_request';
        final requestId = data['request_id']?.toString() ?? '';
        debugPrint('📨 [FOREGROUND] Emergency: $isEmergency, requestId: $requestId showing overlay...');

        // ── Deduplication ─────────────────────────────────────────
        // iOS delivers the same message to onMessage even when the
        // background handler already handled it. Suppress the duplicate.
        _checkAndMarkProcessed('notif_$requestId').then((isDuplicate) {
          if (isDuplicate) {
            debugPrint('⚠️ [FOREGROUND] Duplicate suppressed for request $requestId');
            return;
          }

          // Cancel any system notification already created by the background
          // handler for this request (same deterministic ID). This prevents
          // the user from seeing both the system banner AND the in-app overlay.
          if (requestId.isNotEmpty) {
            AwesomeNotifications().cancel(_notifIdForRequest(requestId));
          }

          final notificationBody = data['body']?.toString() ?? message.notification?.body ?? '';
          final extractedData = _extractFromNotificationBody(notificationBody);
          final requestData = {...data, ...extractedData, 'is_emergency': isEmergency.toString(), 'type': type};

          // Show in-app floating card (foreground experience)
          IncomingRequestManager().addRequest(requestData);
          // Also notify dashboard bloc to refresh badge / card count
          _triggerBlocEvent(type, requestData);
        });
        break;

      case 'request_accepted':
        // Provider accepted the user's service/emergency request
        debugPrint('📨 [FOREGROUND] Provider accepted request: ${data['request_id']}');
        final acceptedRequestId = data['request_id']?.toString() ?? '';
        _checkAndMarkProcessed('notif_$acceptedRequestId').then((isDuplicate) {
          if (isDuplicate) {
            debugPrint('⚠️ [FOREGROUND] Duplicate request_accepted suppressed for $acceptedRequestId');
            return;
          }
          _triggerBlocEvent(type, data);
        });
        break;

      case 'booking_confirmed':
      case 'booking_payment_confirmed':
      case 'provider_waiting_for_payment':
      case 'provider_accepted':
      case 'booking_cancelled':
      case 'booking_expired':
      case 'booking_completed':
      case 'service_completed':
        {
          _triggerBlocEvent(type, data);
        }
        break;

      case 'booking_cancelled_refund':
        {
          _triggerBlocEvent(type, data);
        }
        break;

      case 'provider_payout_completed':
        {
          debugPrint('📨 [FOREGROUND] provider_payout_completed: amount=${data['formatted_amount']}');
          _triggerBlocEvent(type, data);
        }
        break;

      case 'service_status_changed':
        {
          _triggerBlocEvent(type, data);
        }
        break;

      case 'provider_blocked':
        {
          _handleProviderBlocked(data);
        }
        break;

      case 'all_providers_declined':
        {
          _triggerBlocEvent(type, data);
        }
        break;

      default:
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // STATE 2 — BACKGROUND (notification body tapped)
  // App was backgrounded. Provider tapped the notification body
  // (not an action button). App resumes, onMessageOpenedApp fires.
  // Show overlay directly - no bloc dependency!
  // ═══════════════════════════════════════════════════════════════
  void _handleOpenedFromBackground(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? '';
    debugPrint('📨 [BACKGROUND → FOREGROUND] type: $type, data: $data');

    if (type == 'service_request' || type == 'emergency_request') {
      final isEmergency = type == 'emergency_request';
      final requestData = {...data, 'is_emergency': isEmergency.toString(), 'type': type};
      // Show in-app floating card + refresh dashboard badge
      IncomingRequestManager().addRequest(requestData);
      _triggerBlocEvent(type, requestData);
    } else if (type == 'request_accepted') {
      // App was backgrounded — user tapped the notification itself to open it.
      // Navigate directly (they explicitly asked to open this request).
      final requestId = int.tryParse(data['request_id']?.toString() ?? '');
      if (requestId != null) {
        _navigateToDetailSafely(AppRoutes.serviceRequestDetail, requestId);
      }
    } else if (type == 'booking_expired') {
      // Notify the user their request expired — send them to booking history to retry.
      _navigateToDetailSafely(AppRoutes.bookingHistory, null);
    } else if (type == 'booking_completed') {
      // Booking was completed — navigate to its detail page.
      final serviceReqId = int.tryParse(
        data['service_request_id']?.toString() ?? data['request_id']?.toString() ?? '',
      );
      if (serviceReqId != null) {
        _navigateToDetailSafely(AppRoutes.serviceRequestDetail, serviceReqId);
      } else {
        _navigateToDetailSafely(AppRoutes.bookingHistory, null);
      }
    } else if (type == NotificationType.bookingStartReminder ||
        type == NotificationType.bookingStarted) {
      final role = locator<LocalStorageService>().getUserRole;
      final reqId = int.tryParse(NotificationDataKeys.resolveRequestId(data) ?? '');
      final subBlockId = int.tryParse(NotificationDataKeys.resolveSubBlockId(data) ?? '');
      final target = NotificationRouter.resolve(type, role, reqId: reqId, subBlockId: subBlockId);
      if (target.hasTarget) {
        _navigateToDetailSafely(target.route!, target.arguments, backRoute: target.backRoute);
      }
    } else if (type == NotificationType.bookingPaymentConfirmed ||
        type == NotificationType.providerWaitingForPayment ||
        type == NotificationType.bookingConfirmed ||
        type == NotificationType.bookingCancelled) {
      final role = locator<LocalStorageService>().getUserRole;
      final reqId = int.tryParse(NotificationDataKeys.resolveRequestId(data) ?? '');
      final target = NotificationRouter.resolve(type, role, reqId: reqId);
      if (target.hasTarget) {
        _navigateToDetailSafely(target.route!, target.arguments, backRoute: target.backRoute);
      }
    } else if (type == 'booking_cancelled_refund') {
      _navigateToDetailSafely(AppRoutes.userPayments, null);
    } else if (type == 'provider_payout_completed') {
      // Provider tapped the payout notification — open earnings page.
      AppNavigator.navigatorKey.currentState?.pushNamed(AppRoutes.providerEarningsList);
    } else if (type == 'service_status_changed') {
      // Service status changed — open profile page.
      AppNavigator.to(AppRoutes.providerProfilePage);
    } else if (type == 'broadcast') {
      // Provider broadcast (e.g. profile approved) — open provider profile page.
      if (locator<LocalStorageService>().getUserRole == UserRole.provider) {
        AppNavigator.to(AppRoutes.providerProfilePage);
      }
    } else if (type == 'provider_blocked') {
      _handleProviderBlocked(data);
    } else if (type == 'all_providers_declined') {
      // For emergency/searching page refresh
      _triggerBlocEvent(type, data);
    } else {
      _triggerBlocEvent('notification_opened', data);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // STATE 3 — KILLED (notification body tapped, cold launch)
  // App was not running. Provider tapped notification body.
  // App launches → bloc mounts → drain pending.
  // Note: ACCEPT/REJECT button taps go through onActionReceivedMethod
  // and are stored in SharedPreferences by that handler.
  // ═══════════════════════════════════════════════════════════════
  void _handleLaunchedFromKilled(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? '';
    debugPrint('📨 [KILLED → LAUNCHED] type: $type');

    if (type == 'service_request' || type == 'emergency_request') {
      // Store as a pending action so the bloc can drain it once mounted
      unawaited(
        PendingNotificationAction.store(
          type: type,
          requestId: data['request_id'] ?? '',
          isEmergency: type == 'emergency_request',
          payload: data.map((k, v) => MapEntry(k, v.toString())),
        ),
      );
    } else if (type == 'request_accepted') {
      // Provider accepted — store pending navigation to request detail
      unawaited(
        PendingNotificationAction.store(
          type: type,
          requestId: data['request_id'] ?? '',
          isEmergency: false,
          payload: data.map((k, v) => MapEntry(k, v.toString())),
        ),
      );
    } else if (type == 'booking_expired') {
      // App was killed when the expiry arrived — on cold boot, navigate to booking history.
      unawaited(
        PendingNotificationAction.store(
          type: type,
          requestId: data['request_id'] ?? '',
          isEmergency: false,
          payload: data.map((k, v) => MapEntry(k, v.toString())),
        ),
      );
    } else if (type == 'booking_completed') {
      // App was killed when booking completed — store service_request_id for cold-boot navigation.
      unawaited(
        PendingNotificationAction.store(
          type: type,
          requestId: data['service_request_id'] ?? data['request_id'] ?? '',
          isEmergency: false,
          payload: data.map((k, v) => MapEntry(k, v.toString())),
        ),
      );
    } else if (type == 'booking_payment_confirmed' ||
        type == 'provider_waiting_for_payment' ||
        type == 'booking_confirmed') {
      unawaited(
        PendingNotificationAction.store(
          type: type,
          requestId: data['service_request_id'] ?? data['request_id'] ?? data['booking_id'] ?? '',
          isEmergency: false,
          payload: data.map((k, v) => MapEntry(k, v.toString())),
        ),
      );
    } else if (type == 'booking_cancelled') {
      unawaited(
        PendingNotificationAction.store(
          type: type,
          requestId: data['service_request_id'] ?? data['request_id'] ?? data['booking_id'] ?? '',
          isEmergency: false,
          payload: data.map((k, v) => MapEntry(k, v.toString())),
        ),
      );
    } else if (type == NotificationType.bookingStartReminder ||
        type == NotificationType.bookingStarted) {
      // Cold-boot: store so the booking detail + sub-block sheet opens on launch.
      unawaited(
        PendingNotificationAction.store(
          type: type,
          requestId: data['service_request_id'] ?? data['request_id'] ?? data['booking_id'] ?? '',
          isEmergency: false,
          payload: data.map((k, v) => MapEntry(k, v.toString())),
        ),
      );
    } else if (type == 'booking_cancelled_refund') {
      unawaited(
        PendingNotificationAction.store(
          type: type,
          requestId: data['service_request_id'] ?? data['request_id'] ?? data['booking_id'] ?? '',
          isEmergency: false,
          payload: data.map((k, v) => MapEntry(k, v.toString())),
        ),
      );
    } else if (type == 'provider_payout_completed') {
      // App was killed when payout arrived — store so provider lands on earnings on cold boot.
      unawaited(
        PendingNotificationAction.store(
          type: type,
          requestId: '',
          isEmergency: false,
          payload: data.map((k, v) => MapEntry(k, v.toString())),
        ),
      );
    } else if (type == 'service_status_changed' || type == 'broadcast') {
      // App was killed — store so provider lands on profile on cold boot.
      unawaited(
        PendingNotificationAction.store(
          type: type,
          requestId: '',
          isEmergency: false,
          payload: data.map((k, v) => MapEntry(k, v.toString())),
        ),
      );
    } else if (type == 'provider_blocked') {
      _handleProviderBlocked(data);
    } else if (type == 'all_providers_declined') {
      unawaited(
        PendingNotificationAction.store(
          type: type,
          requestId: data['request_id'] ?? '',
          isEmergency: true,
          payload: data.map((k, v) => MapEntry(k, v.toString())),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // AwesomeNotifications action callback
  // Fires when provider taps ACCEPT / REJECT / notification body
  // from a SYSTEM notification (posted by background handler).
  // Makes direct API calls - no bloc dependency!
  // ═══════════════════════════════════════════════════════════════
  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    final payload = receivedAction.payload ?? {};
    final type = payload['type'] ?? '';
    final action = receivedAction.buttonKeyPressed;
    final requestId = payload['request_id'] ?? '';
    final isEmergency = type == 'emergency_request' || payload['is_emergency'] == 'true';

    debugPrint('🔔 [ACTION] type: $type  action: "$action"  requestId: $requestId  isEmergency: $isEmergency');
    debugPrint('🔔 [ACTION] Full payload: $payload');

    switch (type) {
      case 'service_request':
      case 'emergency_request':
        if (action == 'ACCEPT') {
          debugPrint('🔔 [ACTION] Processing ACCEPT via direct API...');
          // Call API directly - no bloc needed
          try {
            final repository = locator<ProviderRepository>();
            final reqId = int.tryParse(requestId) ?? 0;
            final requestDetails = await repository.getServiceRequestById(reqId);
            final result = await repository.respondToRequest(
              requestId: reqId,
              accepted: true,
              subBlockIds: requestDetails.subBlockIds,
            );
            debugPrint('✅ Accept API response: ${result.message}');

            // Navigate to request detail page if accepted
            if (result.success) {
              final ctx = AppNavigator.navigatorKey.currentContext;
              if (ctx != null) {
                if (!ctx.mounted) return;
                final reqId = int.tryParse(requestId) ?? 0;
                Navigator.of(ctx).pushNamed(AppRoutes.providerRequestDetail, arguments: reqId);
              }
            }
          } catch (e) {
            debugPrint('❌ Accept API error: $e');
          } finally {
            unawaited(AwesomeNotifications().dismiss(receivedAction.id ?? 0));
          }
        } else if (action == 'REJECT') {
          debugPrint('🔔 [ACTION] Processing REJECT via direct API...');
          try {
            final repository = locator<ProviderRepository>();
            final reqId = int.tryParse(requestId) ?? 0;
            await repository.respondToRequest(requestId: reqId, accepted: false);
            debugPrint('✅ Reject API called');
          } catch (e) {
            debugPrint('❌ Reject API error: $e');
          } finally {
            unawaited(AwesomeNotifications().dismiss(receivedAction.id ?? 0));
          }
        } else {
          // Notification BODY tapped — navigate to request detail page
          debugPrint('🔔 [ACTION] Body tapped, navigating to request detail...');
          final reqId = int.tryParse(requestId) ?? 0;
          if (reqId > 0 && AppNavigator.navigatorKey.currentState != null) {
            _navigateToDetailSafely(
              AppRoutes.providerRequestDetail,
              {'requestId': reqId, 'isIncomingAlert': true},
              backRoute: AppRoutes.providerDashboard,
            );
            debugPrint('✅ Navigated to providerRequestDetail (isIncomingAlert: true)');
          } else {
            debugPrint('📥 [KILLED] No context - storing for later');
            unawaited(
              PendingNotificationAction.store(
                type: type,
                requestId: requestId,
                isEmergency: isEmergency,
                payload: payload,
              ),
            );
          }
        }
        break;

      case 'booking_confirmed':
      case 'provider_accepted':
        AppNavigator.to('/service_tracking', arguments: int.tryParse(payload['request_id'] ?? ''));
        break;

      case 'request_accepted':
        // User tapped the "Request Accepted" notification — open request detail.
        // Use safe navigation so Back always returns to userDashboard.
        final reqId = int.tryParse(payload['request_id'] ?? '');
        if (reqId != null) {
          _navigateToDetailSafely(AppRoutes.serviceRequestDetail, reqId);
        }
        break;

      case 'booking_cancelled':
        {
          final role = locator<LocalStorageService>().getUserRole;
          final reqId = int.tryParse(
            payload['service_request_id'] ?? payload['request_id'] ?? payload['booking_id'] ?? '',
          );

          if (role == UserRole.provider) {
            if (reqId != null) {
              _navigateToDetailSafely(
                AppRoutes.providerRequestDetail,
                reqId,
                backRoute: AppRoutes.providerDashboard,
              );
            } else {
              AppNavigator.to(AppRoutes.providerDashboard);
            }
          } else {
            if (reqId != null) {
              _navigateToDetailSafely(AppRoutes.serviceRequestDetail, reqId, backRoute: AppRoutes.userDashboard);
            } else {
              AppNavigator.to(AppRoutes.bookingHistory);
            }
          }
        }
        break;

      case 'booking_cancelled_refund':
        _navigateToDetailSafely(AppRoutes.userPayments, null);
        break;

      case 'booking_expired':
        // User tapped the "Request Expired" system notification — go to booking
        // history so they can view the expired request and try again.
        AppNavigator.to(AppRoutes.bookingHistory);
        break;

      case 'booking_completed':
        {
          // User tapped the "Booking Completed" system notification.
          // Navigate to the service request detail using service_request_id.
          final serviceReqIdStr = payload['service_request_id'] ?? payload['request_id'] ?? '';
          final serviceReqId = int.tryParse(serviceReqIdStr);

          if (AppNavigator.navigatorKey.currentState != null) {
            if (serviceReqId != null) {
              _navigateToDetailSafely(AppRoutes.serviceRequestDetail, serviceReqId);
            } else {
              AppNavigator.to(AppRoutes.bookingHistory);
            }
          } else {
            // Cold start — store for later
            unawaited(
              PendingNotificationAction.store(
                type: type,
                requestId: serviceReqIdStr,
                isEmergency: false,
                payload: payload.map((k, v) => MapEntry(k, v.toString())),
              ),
            );
          }
        }
        break;

      case 'provider_payout_completed':
        // Provider tapped the payout notification — open earnings page.
        if (AppNavigator.navigatorKey.currentState != null) {
          AppNavigator.to(AppRoutes.providerEarningsList);
        } else {
          unawaited(
            PendingNotificationAction.store(
              type: type,
              requestId: '',
              isEmergency: false,
              payload: payload.map((k, v) => MapEntry(k, v.toString())),
            ),
          );
        }
        break;

      case 'service_status_changed':
        // Service status changed — open profile page.
        if (AppNavigator.navigatorKey.currentState != null) {
          AppNavigator.to(AppRoutes.providerProfilePage);
        } else {
          unawaited(
            PendingNotificationAction.store(
              type: type,
              requestId: '',
              isEmergency: false,
              payload: payload.map((k, v) => MapEntry(k, v.toString())),
            ),
          );
        }
        break;

      case 'provider_blocked':
        _handleProviderBlocked(payload);
        break;

      default:
        debugPrint('🔔 [ACTION] Unknown type: $type');
    }
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(ReceivedNotification n) async =>
      debugPrint('✅ Notification created: ${n.id}');

  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(ReceivedNotification n) async =>
      debugPrint('📱 Notification displayed: ${n.id}');

  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(ReceivedAction a) async =>
      debugPrint('❌ Notification dismissed: ${a.id}');

  // ───────────────────────────────────────────────────────────────
  // Notification builders (used by bookings / public API)
  // ───────────────────────────────────────────────────────────────

  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, String?>? payload,
    String channelKey = _kBasicChannel,
    List<NotificationActionButton>? actionButtons,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: channelKey,
        title: title,
        body: body,
        payload: payload,
        notificationLayout: NotificationLayout.Default,
        wakeUpScreen: true,
        category: channelKey == 'sos_channel' ? NotificationCategory.Alarm : null,
      ),
      actionButtons: actionButtons,
    );
  }

  Future<void> showBookingNotification({
    required String title,
    required String body,
    required String bookingId,
    String type = 'booking_confirmed',
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: _kBookingChannel,
        title: title,
        body: body,
        payload: {'type': type, 'request_id': bookingId},
        notificationLayout: NotificationLayout.BigText,
        wakeUpScreen: true,
      ),
      actionButtons: [
        NotificationActionButton(key: 'VIEW', label: 'View Details', actionType: ActionType.Default),
      ],
    );
  }

  Future<void> cancelNotification(int id) async => AwesomeNotifications().cancel(id);

  Future<void> cancelAllNotifications() async => AwesomeNotifications().cancelAll();

  Future<String?> getFCMToken() async {
    try {
      final settings = await _fcm.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        return await _fcm.getToken();
      }
      return null;
    } catch (e) {
      kPrintError('Error getting FCM token: $e');
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────────
  // Account status handlers
  // ───────────────────────────────────────────────────────────────

  static void _handleProviderBlocked(Map<String, dynamic> data) {
    debugPrint('🚫 Handling provider_blocked: $data');
    final title = data['title']?.toString() ?? 'Account Blocked ❌';

    // Check for nested 'data' or top-level keys
    final Map<String, dynamic> messageData = data['data'] is Map ? data['data'] : data;

    final reason =
        messageData['blocked_reason']?.toString() ??
        data['body']?.toString() ??
        'Your account has been temporarily blocked.';

    String? formattedDate;
    final tillDateStr = messageData['blocked_till_date']?.toString();
    if (tillDateStr != null) {
      try {
        final date = DateTime.parse(tillDateStr);
        formattedDate = DateFormat('dd-MMM-yyyy').format(date);
      } catch (e) {
        formattedDate = tillDateStr;
      }
    }

    final message = formattedDate != null ? '$reason\n\nBlocked till: $formattedDate' : reason;

    _waitForContextAndShowDialog(title, message);
  }

  static void _waitForContextAndShowDialog(String title, String message) {
    final ctx = AppNavigator.navigatorKey.currentContext;
    if (ctx != null) {
      ProviderBlockedDialog.show(
        ctx,
        title: title,
        message: message,
        onOkPressed: () {
          Navigator.pop(ctx);
          // Add logout event to AuthBloc
          try {
            BlocProvider.of<AuthBloc>(ctx).add(LogoutRequested());
          } catch (e) {
            debugPrint('❌ Error getting AuthBloc: $e');
            // Fallback logout if bloc not found
            AppNavigator.removeAndGo(AppRoutes.login);
          }
        },
      );
    } else {
      // Retry
      Future.delayed(const Duration(milliseconds: 500), () => _waitForContextAndShowDialog(title, message));
    }
  }

  Future<bool> checkAndRequestPermission() async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      isAllowed = await AwesomeNotifications().requestPermissionToSendNotifications();
    }

    if (isAllowed) {
      await _fcm.requestPermission(alert: true, badge: true, sound: true, criticalAlert: true);
    }
    return isAllowed;
  }
}

// ─────────────────────────────────────────────────────────────────
// STATE 2 + 3 background handler (top-level, must not be in a class)
//
// Called by FCM when the app is in background OR killed.
// Responsibility: post a visible AwesomeNotification with
// ACCEPT / REJECT buttons so the provider can respond.
//
// What happens next depends on state:
//   Background: provider taps button → onActionReceivedMethod →
//               bloc alive → dispatch directly ✅
//   Killed:     provider taps button → onActionReceivedMethod →
//               bloc not alive → store in SharedPrefs →
//               app cold-boots → bloc mounts → drain queue ✅
// ─────────────────────────────────────────────────────────────────
// Must be a PUBLIC top-level function (no _ prefix) so the separate
// FCM background isolate can locate it by handle via PluginUtilities.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📨 [BACKGROUND/KILLED handler] Received message');

  final data = message.data;
  final notification = message.notification;
  final type = data['type'] ?? '';
  final requestId = data['request_id']?.toString() ?? '';

  debugPrint(
    '📨 [BACKGROUND/KILLED handler] type: $type, requestId: $requestId, hasNotification: ${notification != null}',
  );

  // Role filter — background isolate cannot use AppConstants (FlavorConfig not initialized),
  // so we read the persisted role from SharedPreferences written at app startup.
  final sendTo = data['send_to']?.toString();
  if (sendTo != null && sendTo.isNotEmpty) {
    final prefs = await SharedPreferences.getInstance();
    final appRole = prefs.getString('_app_role') ?? 'user';
    final forProvider = sendTo == 'provider' || sendTo == 'service_provider';
    final appIsProvider = appRole == 'provider';
    if (forProvider != appIsProvider) {
      debugPrint('🚫 [BACKGROUND] Ignored — send_to=$sendTo but this is $appRole app');
      return;
    }
  }

  final bool isEmergency = type == 'emergency_request';
  final bool isRequest = isEmergency || type == 'service_request';
  final bool isAcceptance = type == 'request_accepted';
  final bool isCancellation = type == 'booking_cancelled';
  final bool isRefund = type == 'booking_cancelled_refund';

  // Only handle request, acceptance, cancellation and refund types; let FCM handle the rest
  if (!isRequest && !isAcceptance && !isCancellation && !isRefund && notification != null) {
    debugPrint('📨 [BACKGROUND] Non-request with notification payload - letting FCM handle it');
    return;
  }

  // ── Deduplication ───────────────────────────────────────────────
  // Guard against iOS re-delivering the same message to both the
  // background handler AND onMessage (foreground). Use the request_id
  // as the dedup key because it's stable across retries/re-deliveries.
  if ((isRequest || isAcceptance) && requestId.isNotEmpty) {
    final isDuplicate = await _checkAndMarkProcessed('notif_$requestId');
    if (isDuplicate) {
      debugPrint('⚠️ [BACKGROUND] Duplicate suppressed for request $requestId');
      return;
    }
  }

  // Initialize AwesomeNotifications in this isolate
  // This is required because background handler runs in separate isolate
  await AwesomeNotifications().initialize('resource://mipmap/ic_launcher', [
    NotificationChannel(
      channelKey: _kBasicChannel,
      channelName: 'General',
      channelDescription: 'General app notifications',
      defaultColor: const Color(0xFF2D62ED),
      importance: NotificationImportance.High,
    ),
    NotificationChannel(
      channelKey: _kBookingChannel,
      channelName: 'Bookings',
      channelDescription: 'Service booking updates',
      defaultColor: const Color(0xFF4CAF50),
      importance: NotificationImportance.Max,
    ),
    if (AppConstants.isProviderApp) ...[
      NotificationChannel(
        channelKey: _kServiceRequestChannel,
        channelName: 'Service Requests',
        channelDescription: 'New service requests assigned to you — accept or reject within the response window',
        defaultColor: const Color(0xFFFF6B00),
        importance: NotificationImportance.Max,
        // criticalAlerts: true,
        // defaultRingtoneType: DefaultRingtoneType.Notification,
        locked: true,
      ),
      NotificationChannel(
        channelKey: _kEmergencyChannel,
        channelName: 'Emergency Requests',
        channelDescription: 'Incoming emergency requests — respond immediately',
        defaultColor: const Color(0xFFDC2626),
        importance: NotificationImportance.Max,
        playSound: true,
        soundSource: 'resource://raw/uber_dispatch_alert',
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500, 200, 1000]),
        // criticalAlerts: true,
        locked: true,
      ),
    ],
  ]);

  debugPrint('📨 [BACKGROUND/KILLED handler] type: $type, data: $data');

  final String channelKey = isEmergency
      ? _kEmergencyChannel
      : isRequest
      ? _kServiceRequestChannel
      : (isAcceptance || isCancellation || isRefund)
      ? _kBookingChannel
      : (type.contains('booking') ? _kBookingChannel : _kBasicChannel);

  // For data-only messages, read title/body from data payload
  // Fall back to notification payload if present, then to defaults
  final String title =
      data['title']?.toString() ??
      notification?.title ??
      (isEmergency
          ? '🚨 EMERGENCY Request!'
          : isRequest
          ? '🔔 New Service Request'
          : isCancellation
          ? '❌ Booking Cancelled'
          : 'Notification');
  final String body = data['body']?.toString() ?? notification?.body ?? 'You have a new request';

  // Use deterministic notification ID based on request_id so we can
  // cancel/replace any FCM auto-displayed notification.
  final notificationId = _notifIdForRequest(requestId);

  debugPrint(
    '📨 Creating notification: id=$notificationId, title=$title, channel=$channelKey, isEmergency=$isEmergency',
  );

  // Cancel any existing notification with same ID first (FCM auto-notification)
  await AwesomeNotifications().cancel(notificationId);

  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: notificationId,
      channelKey: channelKey,
      title: title,
      body: body,
      payload: {
        'type': type,
        ...data.map((k, v) => MapEntry(k, v.toString())),
        if (isEmergency) 'is_emergency': 'true',
      },
      notificationLayout: isRequest ? NotificationLayout.BigText : NotificationLayout.Default,
      wakeUpScreen: true,
      criticalAlert: isEmergency,
      category: isEmergency
          ? NotificationCategory.Alarm
          : isRequest
          ? NotificationCategory.Call
          : null,
      autoDismissible: !isRequest,
      fullScreenIntent: isEmergency,
    ),
    actionButtons: isRequest
        ? [
            NotificationActionButton(
              key: 'REJECT',
              label: '✗  Reject',
              actionType: ActionType.SilentAction,
              color: Colors.red,
              isDangerousOption: true,
            ),
            NotificationActionButton(
              key: 'ACCEPT',
              label: '✓  Accept',
              actionType: ActionType.Default,
              color: const Color(0xFF10B981),
            ),
          ]
        : (isAcceptance || isCancellation || isRefund)
        ? [NotificationActionButton(key: 'VIEW', label: 'View Details', actionType: ActionType.Default)]
        : null,
  );

  debugPrint('✅ [BACKGROUND/KILLED handler] Notification created successfully');
}

// ═══════════════════════════════════════════════════════════════
// HELPER: Extract address and patient name from notification body
// Example body: "Emergency Ambulance Service requested at 42, Shanti Nagar,
//               Near Civil Lines, Jaipur, Rajasthan 302006, India from Priya Sharma."
// ═══════════════════════════════════════════════════════════════
Map<String, String> _extractFromNotificationBody(String body) {
  final result = <String, String>{};

  if (body.isEmpty) return result;

  // Extract address: text between "at " and " from "
  final addressMatch = RegExp(
    r'(?:requested at |at )(.+?)(?:\s+from\s+|\.$)',
    caseSensitive: false,
  ).firstMatch(body);
  if (addressMatch != null && addressMatch.group(1) != null) {
    result['address'] = addressMatch.group(1)!.trim();
  }

  // Extract patient name: text after "from " until end or period
  final nameMatch = RegExp(r'\bfrom\s+([^.]+)', caseSensitive: false).firstMatch(body);
  if (nameMatch != null && nameMatch.group(1) != null) {
    result['patient_name'] = nameMatch.group(1)!.trim().replaceAll('.', '');
  }

  // Extract service type from the beginning of the body
  final serviceMatch = RegExp(r'^(.+?)\s+requested', caseSensitive: false).firstMatch(body);
  if (serviceMatch != null && serviceMatch.group(1) != null) {
    result['service_type'] = serviceMatch.group(1)!.trim();
  }

  return result;
}
