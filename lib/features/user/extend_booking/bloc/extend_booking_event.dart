part of 'extend_booking_bloc.dart';

abstract class ExtendBookingEvent extends Equatable {
  const ExtendBookingEvent();
  @override
  List<Object?> get props => [];
}

// ── Date / duration inputs ───────────────────────────────────────────────────

class ExtendDateChanged extends ExtendBookingEvent {
  final DateTime extendEndDate;
  const ExtendDateChanged(this.extendEndDate);
  @override
  List<Object?> get props => [extendEndDate];
}

/// Used for hourly bookings — user picks a number of extra hours directly.
class ExtendHoursChanged extends ExtendBookingEvent {
  final int hours;
  const ExtendHoursChanged(this.hours);
  @override
  List<Object?> get props => [hours];
}

// ── Step 1: Get price quotation ──────────────────────────────────────────────

class ExtendCalculatePrice extends ExtendBookingEvent {
  const ExtendCalculatePrice();
}

// ── Step 2: Submit extend → get Razorpay order ───────────────────────────────

class ExtendSubmitOrder extends ExtendBookingEvent {
  const ExtendSubmitOrder();
}

// ── Step 3: Razorpay callbacks ───────────────────────────────────────────────

class ExtendRazorpaySuccess extends ExtendBookingEvent {
  final String paymentId;
  final String orderId;
  final String signature;

  const ExtendRazorpaySuccess({
    required this.paymentId,
    required this.orderId,
    required this.signature,
  });

  @override
  List<Object?> get props => [paymentId, orderId, signature];
}

class ExtendRazorpayFailure extends ExtendBookingEvent {
  final String? message;
  const ExtendRazorpayFailure(this.message);
  @override
  List<Object?> get props => [message];
}