import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../service_booking/model/service_request_model.dart';

/// Single source of truth for service-request status display labels and colours.
///
/// Every status chip/badge on the user side should go through this class so
/// that label copy and colour tokens stay in sync.
class RequestStatusHelper {
  RequestStatusHelper._();

  // ── Active status group (matches BookingStatusMapper._isActiveStatus) ─────────

  static bool _isActiveStatus(String status) =>
      status == 'searching' ||
      status == 'partially_accepted' ||
      status == 'standby' ||
      status == 'in_progress' ||
      status == 'accepted';

  // Statuses that always show Confirmed regardless of payment
  static bool _isNonPaymentBlocked(String status) =>
      status == 'standby' ||
      status == 'partially_accepted' ||
      status == 'in_progress';

  // ── Public API ───────────────────────────────────────────────────────────────

  static String label(
    String status, {
    String? serviceType,
    bool isEmergency = false,
    String? paymentStatus,
  }) {
    if (!isEmergency && _isActiveStatus(status)) {
      final isPaid = paymentStatus == 'paid' || paymentStatus == 'partially_paid';
      if (isPaid || _isNonPaymentBlocked(status)) return 'Confirmed';
      return 'Payment Pending';
    }
    switch (status) {
      case 'searching':
        return isEmergency ? 'Searching' : 'Awaiting Response';
      case 'standby':
      case 'partially_accepted':
        return 'Confirmed';
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'in_progress':
        return 'In Progress';
      case 'scheduled':
        return 'Scheduled';
      case 'confirmed':
        return 'Confirmed';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'expired':
        return 'Expired';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  /// Context-aware label used on cards that have the full request model
  /// (mirrors the booking history list, e.g. emergency `accepted` → "Confirmed").
  static String smartLabel(ServiceRequestModel r) {
    if (r.isCancelledOrExpired) return r.isExpired ? 'Expired' : 'Cancelled';
    if (r.isCompleted) return 'Completed';

    if (r.status == 'searching') {
      if (r.isEmergency) return 'Searching Partner';
      if (r.needsPayment) return 'Payment Pending';
      return 'Confirmed';
    }

    final now = DateTime.now();
    if (r.status == 'in_progress' || r.subBlocks.any((s) => s.isCurrentlyOngoing(now))) {
      return 'Session Active';
    }
    if (r.needsPayment) return 'Payment Pending';

    if (r.status == 'accepted' || r.status == 'standby') return 'Confirmed';
    if (r.subBlocks.any((s) => s.isFuture(now) && !s.isCancelled)) return 'Upcoming';
    return 'Confirmed';
  }

  static Color color(
    String status, {
    String? serviceType,
    bool isEmergency = false,
    String? paymentStatus,
  }) {
    if (!isEmergency && _isActiveStatus(status)) {
      final isPaid = paymentStatus == 'paid' || paymentStatus == 'partially_paid';
      if (isPaid || _isNonPaymentBlocked(status)) return kSuccessColor;
      return kWarningColor;
    }
    switch (status) {
      case 'searching':
        return isEmergency ? kAccentColor : kWarningColor;
      case 'pending':
        return kWarningColor;
      case 'standby':
      case 'partially_accepted':
        return kSuccessColor;
      case 'accepted':
      case 'confirmed':
      case 'scheduled':
        return kInfoColor;
      case 'in_progress':
        return kPrimaryColor;
      case 'completed':
        return kSuccessColor;
      case 'cancelled':
      case 'expired':
        return kErrorColor;
      default:
        return kTextSecondaryColor;
    }
  }
}
