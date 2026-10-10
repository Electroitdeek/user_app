part of 'extend_booking_bloc.dart';

abstract class ExtendBookingState extends Equatable {
  const ExtendBookingState();
  @override
  List<Object?> get props => [];
}

// ── Primary UI state ─────────────────────────────────────────────────────────

class ExtendBookingData extends ExtendBookingState {
  final DateTime? extendEndDate;
  /// For hourly bookings — number of hours chosen by the user.
  final int? selectedHours;
  final bool isCalculating;
  final ExtendPriceResult? priceResult;
  final String? calculateError;
  final bool isSubmitting;
  final ExtendOrderResult? currentOrder;
  final String? submitError;
  final bool isVerifying;

  const ExtendBookingData({
    this.extendEndDate,
    this.selectedHours,
    this.isCalculating = false,
    this.priceResult,
    this.calculateError,
    this.isSubmitting = false,
    this.currentOrder,
    this.submitError,
    this.isVerifying = false,
  });

  ExtendBookingData copyWith({
    DateTime? extendEndDate,
    bool clearExtendEndDate = false,
    int? selectedHours,
    bool clearSelectedHours = false,
    bool? isCalculating,
    ExtendPriceResult? priceResult,
    bool clearPriceResult = false,
    String? calculateError,
    bool clearCalculateError = false,
    bool? isSubmitting,
    ExtendOrderResult? currentOrder,
    bool clearCurrentOrder = false,
    String? submitError,
    bool clearSubmitError = false,
    bool? isVerifying,
  }) {
    return ExtendBookingData(
      extendEndDate: clearExtendEndDate ? null : (extendEndDate ?? this.extendEndDate),
      selectedHours: clearSelectedHours ? null : (selectedHours ?? this.selectedHours),
      isCalculating: isCalculating ?? this.isCalculating,
      priceResult: clearPriceResult ? null : (priceResult ?? this.priceResult),
      calculateError: clearCalculateError ? null : (calculateError ?? this.calculateError),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      currentOrder: clearCurrentOrder ? null : (currentOrder ?? this.currentOrder),
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
      isVerifying: isVerifying ?? this.isVerifying,
    );
  }

  @override
  List<Object?> get props => [
    extendEndDate, selectedHours, isCalculating, priceResult, calculateError,
    isSubmitting, currentOrder, submitError, isVerifying,
  ];
}

// ── One-shot action states ───────────────────────────────────────────────────

/// Tells the UI to call razorpay.open()
class ExtendOpenRazorpay extends ExtendBookingState {
  final ExtendBookingData data;
  final Map<String, dynamic> options;
  const ExtendOpenRazorpay({required this.data, required this.options});
  @override
  List<Object?> get props => [data, options];
}

/// Payment fully verified — pop back to detail page
class ExtendPaymentSuccess extends ExtendBookingState {
  const ExtendPaymentSuccess();
  @override
  List<Object?> get props => [];
}

/// Show a one-shot snackbar
class ExtendSnackBar extends ExtendBookingState {
  final ExtendBookingData data;
  final String message;
  final bool isError;
  const ExtendSnackBar({required this.data, required this.message, this.isError = false});
  @override
  List<Object?> get props => [data, message, isError];
}

/// Show the price confirmation dialog
class ExtendShowPriceDialog extends ExtendBookingState {
  final ExtendBookingData data;
  const ExtendShowPriceDialog({required this.data});
  @override
  List<Object?> get props => [data];
}