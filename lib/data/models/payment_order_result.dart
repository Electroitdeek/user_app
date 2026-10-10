class PaymentOrderResult {
  final String razorpayOrderId;
  final int amount; // in paise
  final String currency;
  final String razorpayKey;
  final int tempOrderId;
  final int? bookingId;
  final int? serviceRequestId;
  final String? bookingType;
  final String? promocode;

  const PaymentOrderResult({
    required this.razorpayOrderId,
    required this.amount,
    required this.currency,
    required this.razorpayKey,
    required this.tempOrderId,
    this.bookingId,
    this.serviceRequestId,
    this.bookingType,
    this.promocode,
  });
}
