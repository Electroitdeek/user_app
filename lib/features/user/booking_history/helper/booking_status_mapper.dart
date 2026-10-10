import 'package:flutter/material.dart';

import 'request_status_helper.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum BookingStatus {
  searching,
  partiallyAccepted,
  standby,
  inProgress,
  accepted,
  completed,
  cancelled,
  expired,
  unknown,
}

enum BookingType { procedural, emergency, longDuration, unknown }

// ─── Display Config ───────────────────────────────────────────────────────────

class BookingDisplayConfig {
  final String label;
  final Color primaryColor;
  final Color bgColor;
  final IconData icon;
  final bool isConfirmed;
  final bool isTerminal;
  final bool isPulsing;

  const BookingDisplayConfig({
    required this.label,
    required this.primaryColor,
    required this.bgColor,
    required this.icon,
    this.isConfirmed = false,
    this.isTerminal = false,
    this.isPulsing = false,
  });
}

// ─── Mapper ───────────────────────────────────────────────────────────────────

class BookingStatusMapper {
  BookingStatusMapper._();

  static BookingStatus fromString(String raw) {
    switch (raw.toLowerCase()) {
      case 'searching':
        return BookingStatus.searching;
      case 'partially_accepted':
        return BookingStatus.partiallyAccepted;
      case 'standby':
        return BookingStatus.standby;
      case 'in_progress':
        return BookingStatus.inProgress;
      case 'accepted':
        return BookingStatus.accepted;
      case 'completed':
        return BookingStatus.completed;
      case 'cancelled':
        return BookingStatus.cancelled;
      case 'expired':
        return BookingStatus.expired;
      default:
        return BookingStatus.unknown;
    }
  }

  static BookingType typeFromString(String raw) {
    switch (raw.toLowerCase()) {
      case 'procedural':
        return BookingType.procedural;
      case 'emergency':
        return BookingType.emergency;
      case 'long_duration':
        return BookingType.longDuration;
      default:
        return BookingType.unknown;
    }
  }

  /// Business rule: non-emergency active statuses show as "Confirmed"
  /// because payment was already collected at booking creation.
  static String _statusString(BookingStatus s) {
    switch (s) {
      case BookingStatus.searching:
        return 'searching';
      case BookingStatus.partiallyAccepted:
        return 'partially_accepted';
      case BookingStatus.standby:
        return 'standby';
      case BookingStatus.inProgress:
        return 'in_progress';
      case BookingStatus.accepted:
        return 'accepted';
      case BookingStatus.completed:
        return 'completed';
      case BookingStatus.cancelled:
        return 'cancelled';
      case BookingStatus.expired:
        return 'expired';
      case BookingStatus.unknown:
        return 'unknown';
    }
  }

  static BookingDisplayConfig getConfig(BookingStatus status, BookingType type, String paymentStatus) {
    final isEmergency = type == BookingType.emergency;
    final isPaid = paymentStatus == 'paid' || paymentStatus == 'partially_paid';

    // Single colour source — identical to list & home (RequestStatusHelper),
    // so the same status renders the same colour on every screen.
    final color = RequestStatusHelper.color(
      _statusString(status),
      isEmergency: isEmergency,
      paymentStatus: paymentStatus,
    );
    Color bg() => color.withValues(alpha: 0.1);

    // Emergency: accepted but unpaid → must complete payment to confirm.
    if (isEmergency && !isPaid && status == BookingStatus.accepted) {
      return BookingDisplayConfig(
        label: 'Payment Pending',
        primaryColor: color,
        bgColor: bg(),
        icon: Icons.payment_rounded,
      );
    }

    if (!isEmergency && _isActiveStatus(status)) {
      if (isPaid || _isNonPaymentBlocked(status)) {
        return BookingDisplayConfig(
          label: 'Confirmed',
          primaryColor: color,
          bgColor: bg(),
          icon: Icons.verified_rounded,
          isConfirmed: true,
        );
      }
      return BookingDisplayConfig(
        label: 'Payment Pending',
        primaryColor: color,
        bgColor: bg(),
        icon: Icons.payment_rounded,
      );
    }

    switch (status) {
      case BookingStatus.searching:
        return BookingDisplayConfig(
          label: isEmergency ? 'Searching Partner' : 'Confirmed',
          primaryColor: color,
          bgColor: bg(),
          icon: isEmergency ? Icons.radar_rounded : Icons.verified_rounded,
          isConfirmed: !isEmergency,
          isPulsing: isEmergency,
        );
      case BookingStatus.accepted:
        return BookingDisplayConfig(
          label: 'Accepted',
          primaryColor: color,
          bgColor: bg(),
          icon: Icons.check_circle_rounded,
          isConfirmed: true,
        );
      case BookingStatus.inProgress:
        return BookingDisplayConfig(
          label: 'Session Active',
          primaryColor: color,
          bgColor: bg(),
          icon: Icons.radio_button_checked_rounded,
          isConfirmed: true,
          isPulsing: true,
        );
      case BookingStatus.completed:
        return BookingDisplayConfig(
          label: 'Completed',
          primaryColor: color,
          bgColor: bg(),
          icon: Icons.task_alt_rounded,
          isConfirmed: true,
          isTerminal: true,
        );
      case BookingStatus.cancelled:
        return BookingDisplayConfig(
          label: 'Cancelled',
          primaryColor: color,
          bgColor: bg(),
          icon: Icons.cancel_rounded,
          isTerminal: true,
        );
      case BookingStatus.expired:
        return BookingDisplayConfig(
          label: 'Expired',
          primaryColor: color,
          bgColor: bg(),
          icon: Icons.timer_off_rounded,
          isTerminal: true,
        );
      default:
        return BookingDisplayConfig(
          label: status.name.trim(),
          primaryColor: color,
          bgColor: bg(),
          icon: Icons.info_rounded,
        );
    }
  }

  static bool _isActiveStatus(BookingStatus status) =>
      status == BookingStatus.searching ||
      status == BookingStatus.partiallyAccepted ||
      status == BookingStatus.standby ||
      status == BookingStatus.inProgress ||
      status == BookingStatus.accepted;

  static bool _isNonPaymentBlocked(BookingStatus status) =>
      status == BookingStatus.standby ||
      status == BookingStatus.partiallyAccepted ||
      status == BookingStatus.inProgress;

  static bool isTerminal(BookingStatus status) =>
      status == BookingStatus.completed || status == BookingStatus.cancelled || status == BookingStatus.expired;
}
