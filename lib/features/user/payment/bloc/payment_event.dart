part of 'payment_bloc.dart';

abstract class PaymentEvent extends Equatable {
  const PaymentEvent();

  @override
  List<Object?> get props => [];
}

// ── Promo ──────────────────────────────────────────────────────────────────

class ApplyPromoEvent extends PaymentEvent {
  final String code;
  final double totalAmount;
  final int customerProfileId;
  final int serviceRequestId;

  const ApplyPromoEvent({
    required this.code,
    required this.totalAmount,
    required this.customerProfileId,
    required this.serviceRequestId,
  });

  @override
  List<Object?> get props => [code, totalAmount, customerProfileId, serviceRequestId];
}

class RemovePromoEvent extends PaymentEvent {
  const RemovePromoEvent();
}

class FetchAvailablePromosEvent extends PaymentEvent {
  final String category;
  final int? serviceRequestId;

  const FetchAvailablePromosEvent({this.category = 'payments', this.serviceRequestId});

  @override
  List<Object?> get props => [category, serviceRequestId];
}

// ── Payment Initiation ─────────────────────────────────────────────────────

class InitiatePaymentEvent extends PaymentEvent {
  final int serviceRequestId;
  final int? bookingId;
  final int customerProfileId;
  final double payableAmount;
  final double totalAmount;
  final double basePrice;
  final double distanceCharge;
  final double gstAmount;
  final double discountAmount;
  final String? appliedCode;
  final int? promoCodeId;
  final String bookingType;
  final double walletAmountUsed;
  final double bonusAmountUsed;
  final List<int> paymentInstallmentIds;
  final String method;
  final String gatewayRef;

  const InitiatePaymentEvent({
    required this.serviceRequestId,
    this.bookingId,
    required this.customerProfileId,
    required this.payableAmount,
    required this.totalAmount,
    required this.basePrice,
    required this.distanceCharge,
    required this.gstAmount,
    required this.discountAmount,
    this.appliedCode,
    this.promoCodeId,
    this.bookingType = 'service_booking',
    this.walletAmountUsed = 0.0,
    this.bonusAmountUsed = 0.0,
    this.paymentInstallmentIds = const [],
    this.method = 'UPI',
    this.gatewayRef = '',
  });

  @override
  List<Object?> get props => [
    serviceRequestId, bookingId, customerProfileId, payableAmount, totalAmount,
    promoCodeId, walletAmountUsed, bonusAmountUsed, paymentInstallmentIds,
  ];
}

// ── Razorpay Callbacks ─────────────────────────────────────────────────────

class RazorpaySuccessEvent extends PaymentEvent {
  final String paymentId;
  final String orderId;
  final String signature;

  const RazorpaySuccessEvent({
    required this.paymentId,
    required this.orderId,
    required this.signature,
  });

  @override
  List<Object?> get props => [paymentId, orderId, signature];
}

class RazorpayFailureEvent extends PaymentEvent {
  final String? message;

  const RazorpayFailureEvent(this.message);

  @override
  List<Object?> get props => [message];
}

// ── Cancel Booking ─────────────────────────────────────────────────────────

class CancelBookingEvent extends PaymentEvent {
  final int requestId;

  const CancelBookingEvent(this.requestId);

  @override
  List<Object?> get props => [requestId];
}

