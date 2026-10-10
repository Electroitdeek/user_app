part of 'payment_bloc.dart';

/// Params persisted from [InitiatePaymentEvent] and used during [RazorpaySuccessEvent] verification.
class PaymentVerifyParams extends Equatable {
  final int serviceRequestId;
  final int? bookingId;
  final int customerProfileId;
  final double payableAmount;
  final double basePrice;
  final double distanceCharge;
  final double gstAmount;
  final double discountAmount;
  final String? promocode;
  final int? promoCodeId;
  final String bookingType;
  final double walletAmountUsed;
  final double bonusAmountUsed;

  const PaymentVerifyParams({
    required this.serviceRequestId,
    this.bookingId,
    required this.customerProfileId,
    required this.payableAmount,
    required this.basePrice,
    required this.distanceCharge,
    required this.gstAmount,
    required this.discountAmount,
    this.promocode,
    this.promoCodeId,
    required this.bookingType,
    this.walletAmountUsed = 0.0,
    this.bonusAmountUsed = 0.0,
  });

  @override
  List<Object?> get props => [
    serviceRequestId, bookingId, customerProfileId,
    payableAmount, basePrice, distanceCharge, gstAmount,
    discountAmount, promocode, promoCodeId, bookingType,
    walletAmountUsed, bonusAmountUsed,
  ];
}

// ── States ─────────────────────────────────────────────────────────────────

abstract class PaymentState extends Equatable {
  const PaymentState();
}

/// Primary UI-driving state — always available to the BlocBuilder.
class PaymentSheetData extends PaymentState {
  final bool promoLoading;
  final String? appliedCode;
  final double discountAmount;
  final int? promoCodeId;
  final String? promoError;
  final bool paymentLoading;
  final List<AvailablePromoCode> availablePromos;
  final bool promosLoading;
  final double bonusAdjustmentPercentage;
  final PaymentOrderResult? currentOrder;
  final PaymentVerifyParams? verifyParams;
  final double walletBalance;
  final double bonusBalance;

  const PaymentSheetData({
    this.promoLoading = false,
    this.appliedCode,
    this.discountAmount = 0.0,
    this.promoCodeId,
    this.promoError,
    this.paymentLoading = false,
    this.availablePromos = const [],
    this.promosLoading = false,
    this.bonusAdjustmentPercentage = 0.0,
    this.currentOrder,
    this.verifyParams,
    this.walletBalance = 0.0,
    this.bonusBalance = 0.0,
  });

  PaymentSheetData copyWith({
    bool? promoLoading,
    String? appliedCode,
    bool clearAppliedCode = false,
    double? discountAmount,
    int? promoCodeId,
    bool clearPromoCodeId = false,
    String? promoError,
    bool clearPromoError = false,
    bool? paymentLoading,
    List<AvailablePromoCode>? availablePromos,
    bool? promosLoading,
    double? bonusAdjustmentPercentage,
    PaymentOrderResult? currentOrder,
    bool clearCurrentOrder = false,
    PaymentVerifyParams? verifyParams,
    bool clearVerifyParams = false,
    double? walletBalance,
    double? bonusBalance,
  }) {
    return PaymentSheetData(
      promoLoading: promoLoading ?? this.promoLoading,
      appliedCode: clearAppliedCode ? null : (appliedCode ?? this.appliedCode),
      discountAmount: discountAmount ?? this.discountAmount,
      promoCodeId: clearPromoCodeId ? null : (promoCodeId ?? this.promoCodeId),
      promoError: clearPromoError ? null : (promoError ?? this.promoError),
      paymentLoading: paymentLoading ?? this.paymentLoading,
      availablePromos: availablePromos ?? this.availablePromos,
      promosLoading: promosLoading ?? this.promosLoading,
      bonusAdjustmentPercentage: bonusAdjustmentPercentage ?? this.bonusAdjustmentPercentage,
      currentOrder: clearCurrentOrder ? null : (currentOrder ?? this.currentOrder),
      verifyParams: clearVerifyParams ? null : (verifyParams ?? this.verifyParams),
      walletBalance: walletBalance ?? this.walletBalance,
      bonusBalance: bonusBalance ?? this.bonusBalance,
    );
  }

  @override
  List<Object?> get props => [
    promoLoading, appliedCode, discountAmount, promoCodeId, promoError,
    paymentLoading, availablePromos, promosLoading, bonusAdjustmentPercentage,
    currentOrder, verifyParams, walletBalance, bonusBalance,
  ];
}

// ── One-shot action states (handled by BlocListener) ──────────────────────

/// Tells the UI to call razorpay.open() with these options.
class PaymentOpenRazorpayState extends PaymentState {
  final PaymentSheetData data;
  final Map<String, dynamic> razorpayOptions;

  const PaymentOpenRazorpayState({required this.data, required this.razorpayOptions});

  @override
  List<Object?> get props => [data];
}

/// Payment fully verified — close the sheet.
class PaymentSuccessState extends PaymentState {
  final String? transactionId; // Razorpay ID
  final double? amount;
  final int? paymentId; // Internal ID
  final String? paymentNumber; // Internal Number

  const PaymentSuccessState({
    this.transactionId,
    this.amount,
    this.paymentId,
    this.paymentNumber,
  });

  @override
  List<Object?> get props => [transactionId, amount, paymentId, paymentNumber];
}

/// Show a snackbar message. `isError` controls the colour.
class PaymentSnackBarState extends PaymentState {
  final PaymentSheetData data;
  final String message;
  final bool isError;

  const PaymentSnackBarState({
    required this.data,
    required this.message,
    this.isError = false,
  });

  @override
  List<Object?> get props => [data, message, isError];
}

/// Show an error dialog (for API errors that need prominent display).
class PaymentErrorDialogState extends PaymentState {
  final PaymentSheetData data;
  final String message;

  const PaymentErrorDialogState({required this.data, required this.message});

  @override
  List<Object?> get props => [data, message];
}

/// One-shot: promo applied successfully — show a celebratory dialog.
class PromoAppliedState extends PaymentState {
  final PaymentSheetData data;
  final String code;
  final double discountAmount;
  final String message;

  const PromoAppliedState({
    required this.data,
    required this.code,
    required this.discountAmount,
    required this.message,
  });

  @override
  List<Object?> get props => [data, code, discountAmount, message];
}

/// Booking cancelled — close the sheet.
class PaymentCancelledState extends PaymentState {
  const PaymentCancelledState();

  @override
  List<Object?> get props => [];
}




