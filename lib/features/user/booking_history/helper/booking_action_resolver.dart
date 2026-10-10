import '../model/booking_detail_model.dart';
import 'booking_status_mapper.dart';
import 'payment_status_mapper.dart';

const _activeStatuses = [
  BookingStatus.searching,
  BookingStatus.partiallyAccepted,
  BookingStatus.standby,
  BookingStatus.inProgress,
  BookingStatus.accepted,
];

class BookingActionResolver {
  BookingActionResolver._();

  /// Show "Pay Now" button.
  ///
  /// Emergency: only when accepted AND payment is pending/failed.
  /// Non-emergency: when payment is pending/failed (booking already confirmed).
  static bool showPayNow({
    required BookingType type,
    required BookingStatus status,
    required PaymentStatus paymentStatus,
  }) {
    final needsPayment =
        paymentStatus == PaymentStatus.pending || paymentStatus == PaymentStatus.failed;
    if (!needsPayment) return false;
    if (BookingStatusMapper.isTerminal(status)) return false;

    if (type == BookingType.emergency) {
      return status == BookingStatus.accepted;
    }
    return true;
  }

  /// Show "Cancel" button — hidden for all terminal statuses, and for completed emergency bookings.
  static bool showCancel(
    BookingStatus status, {
    BookingType? type,
    PaymentStatus? paymentStatus,
  }) {
    if (BookingStatusMapper.isTerminal(status)) return false;
    if (type == BookingType.emergency && paymentStatus == PaymentStatus.paid) {
      return false;
    }
    return true;
  }

  /// Show "View Full Schedule" — only for multi-day bookings with sessions.
  static bool showViewSchedule(ServiceRequestDetail sr) =>
      (sr.durationDays ?? 0) > 1 && sr.subBlocks.isNotEmpty;

  /// Show sessions section — any booking with sub-blocks.
  static bool showSessions(ServiceRequestDetail sr) => sr.subBlocks.isNotEmpty;

  /// Show providers notified section — while searching only.
  static bool showProviders(BookingStatus status, List<ServiceRequestResponse> responses) =>
      responses.isNotEmpty &&
      (status == BookingStatus.searching || status == BookingStatus.partiallyAccepted);

  /// Informational banner for confirmed non-emergency bookings.
  static String? confirmedBannerMessage(BookingType type, BookingStatus status) {
    if (type == BookingType.emergency) return null;
    if (!_activeStatuses.contains(status)) return null;
    return 'Your booking is confirmed. A provider will be assigned shortly.';
  }
}
