import '../../features/auth/auth_wrapper/data/role_enums.dart';
import '../navigation/app_routes.dart';

/// Central registry of push-notification payload keys, type values, and the
/// role-aware routing that decides which screen a tapped notification opens.
///
/// Keep all FCM `data` contract strings here so backend changes are a one-file
/// edit, and so user (customer) vs partner (provider) routing stays explicit
/// and side by side.

// ─────────────────────────────────────────────────────────────────────────────
// Payload data keys (the keys inside RemoteMessage.data)
// ─────────────────────────────────────────────────────────────────────────────
class NotificationDataKeys {
  NotificationDataKeys._();

  static const String type = 'type';
  static const String notificationType = 'notification_type';
  static const String sendTo = 'send_to';
  static const String title = 'title';
  static const String body = 'body';
  static const String priority = 'priority';
  static const String notificationId = 'notification_id';

  // Identifiers — different events send the id under different keys.
  static const String requestId = 'request_id';
  static const String serviceRequestId = 'service_request_id';
  static const String bookingId = 'booking_id';
  static const String bookingSubBlockId = 'booking_sub_block_id';
  static const String subBlockId = 'sub_block_id';
  static const String isEmergency = 'is_emergency';

  /// Resolves the booking/request id from whichever key the payload used.
  static String? resolveRequestId(Map<String, dynamic> data) {
    final raw = data[serviceRequestId]?.toString() ??
        data[requestId]?.toString() ??
        data[bookingId]?.toString();
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  /// Resolves the session/sub-block id — backend sends it under either key.
  static String? resolveSubBlockId(Map<String, dynamic> data) {
    final raw = data[bookingSubBlockId]?.toString() ?? data[subBlockId]?.toString();
    return (raw == null || raw.isEmpty) ? null : raw;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// `type` values
// ─────────────────────────────────────────────────────────────────────────────
class NotificationType {
  NotificationType._();

  // Incoming-request (provider-facing live cards)
  static const String serviceRequest = 'service_request';
  static const String emergencyRequest = 'emergency_request';

  // Request lifecycle
  static const String requestAccepted = 'request_accepted';
  static const String providerAccepted = 'provider_accepted';
  static const String allProvidersDeclined = 'all_providers_declined';

  // Booking lifecycle
  static const String bookingConfirmed = 'booking_confirmed';
  static const String bookingPaymentConfirmed = 'booking_payment_confirmed';
  static const String providerWaitingForPayment = 'provider_waiting_for_payment';
  static const String bookingCancelled = 'booking_cancelled';
  static const String bookingCancelledRefund = 'booking_cancelled_refund';
  static const String bookingExpired = 'booking_expired';
  static const String bookingCompleted = 'booking_completed';
  static const String serviceCompleted = 'service_completed';
  static const String serviceStatusChanged = 'service_status_changed';
  static const String bookingStartReminder = 'booking_start_reminder';
  static const String bookingStarted = 'booking_started';

  // Provider account / earnings
  static const String providerPayoutCompleted = 'provider_payout_completed';
  static const String providerBlocked = 'provider_blocked';
  static const String broadcast = 'broadcast';
}

// ─────────────────────────────────────────────────────────────────────────────
// Routing result
// ─────────────────────────────────────────────────────────────────────────────
class NotificationRoute {
  /// Route to open. Null when the notification has no navigation target.
  final String? route;

  /// Arguments passed to the route (usually a request id `int`).
  final Object? arguments;

  /// Route the back stack should return to (e.g. the relevant dashboard).
  final String? backRoute;

  const NotificationRoute({this.route, this.arguments, this.backRoute});

  bool get hasTarget => route != null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Role-aware router
// ─────────────────────────────────────────────────────────────────────────────
class NotificationRouter {
  NotificationRouter._();

  /// Resolve the destination for a tapped notification.
  ///
  /// [reqId] is the parsed booking/request id (see
  /// [NotificationDataKeys.resolveRequestId]); pass null when absent.
  static NotificationRoute resolve(String type, UserRole role, {int? reqId, int? subBlockId}) {
    return role == UserRole.provider
        ? _forProvider(type, reqId)
        : _forUser(type, reqId, subBlockId);
  }

  // ── USER (customer) ────────────────────────────────────────────────────────
  static NotificationRoute _forUser(String type, int? reqId, int? subBlockId) {
    switch (type) {
      // Opens the booking detail page and then the specific session
      // (sub-block) detail sheet.
      case NotificationType.bookingStartReminder:
      case NotificationType.bookingStarted:
        return reqId != null
            ? NotificationRoute(
                route: AppRoutes.serviceRequestDetail,
                arguments: {
                  'requestId': reqId,
                  'subBlockId': ?subBlockId,
                },
                backRoute: AppRoutes.userDashboard,
              )
            : const NotificationRoute(route: AppRoutes.bookingHistory);

      case NotificationType.bookingConfirmed:
      case NotificationType.bookingPaymentConfirmed:
      case NotificationType.providerWaitingForPayment:
      case NotificationType.bookingCancelled:
      case NotificationType.bookingCompleted:
      case NotificationType.requestAccepted:
        return reqId != null
            ? NotificationRoute(
                route: AppRoutes.serviceRequestDetail,
                arguments: reqId,
                backRoute: AppRoutes.userDashboard,
              )
            : const NotificationRoute(route: AppRoutes.bookingHistory);

      case NotificationType.bookingExpired:
        return const NotificationRoute(route: AppRoutes.bookingHistory);

      case NotificationType.bookingCancelledRefund:
        return const NotificationRoute(route: AppRoutes.userPayments);

      default:
        return const NotificationRoute();
    }
  }

  // ── PARTNER (provider) ───────────────────────────────────────────────────────
  static NotificationRoute _forProvider(String type, int? reqId) {
    switch (type) {
      case NotificationType.bookingConfirmed:
      case NotificationType.bookingPaymentConfirmed:
      case NotificationType.providerWaitingForPayment:
      case NotificationType.bookingCancelled:
      case NotificationType.providerAccepted:
      case NotificationType.requestAccepted:
        return reqId != null
            ? NotificationRoute(
                route: AppRoutes.providerRequestDetail,
                arguments: reqId,
                backRoute: AppRoutes.providerDashboard,
              )
            : const NotificationRoute(route: AppRoutes.providerDashboard);

      case NotificationType.providerPayoutCompleted:
        return const NotificationRoute(route: AppRoutes.providerEarningsList);

      case NotificationType.serviceStatusChanged:
      case NotificationType.broadcast:
        return const NotificationRoute(route: AppRoutes.providerProfilePage);

      default:
        return const NotificationRoute();
    }
  }
}
