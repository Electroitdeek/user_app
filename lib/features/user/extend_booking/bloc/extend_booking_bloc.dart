import 'package:adhisaat_health_care/core/storage/local_storage_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/extend_booking_repository.dart';

part 'extend_booking_event.dart';
part 'extend_booking_state.dart';

class ExtendBookingBloc extends Bloc<ExtendBookingEvent, ExtendBookingState> {
  final ExtendBookingRepository _repo;
  final LocalStorageService _storage;

  // ── Booking context (set at construction time) ──────────────────────────
  final int serviceRequestId;
  final int bookingId;
  final String serviceType; // 'daily' | 'hourly'
  final String currentEndDate; // current booking end date  "2026-03-17"

  ExtendBookingData _data = const ExtendBookingData();

  ExtendBookingBloc({
    required this.serviceRequestId,
    required this.bookingId,
    required this.serviceType,
    required this.currentEndDate,
    required ExtendBookingRepository repo,
    required LocalStorageService storage,
  }) : _repo = repo,
       _storage = storage,
       super(const ExtendBookingData()) {
    on<ExtendDateChanged>(_onDateChanged);
    on<ExtendHoursChanged>(_onHoursChanged);
    on<ExtendCalculatePrice>(_onCalculatePrice);
    on<ExtendSubmitOrder>(_onSubmitOrder);
    on<ExtendRazorpaySuccess>(_onRazorpaySuccess);
    on<ExtendRazorpayFailure>(_onRazorpayFailure);
  }

  int get _customerId => _storage.customerUserId ?? 0;

  void _emit(ExtendBookingData updated, Emitter<ExtendBookingState> emit) {
    _data = updated;
    emit(_data);
  }

  // ── Date changed (daily bookings) ────────────────────────────────────────

  void _onDateChanged(ExtendDateChanged event, Emitter<ExtendBookingState> emit) {
    _emit(
      _data.copyWith(
        extendEndDate: event.extendEndDate,
        clearSelectedHours: true,
        clearPriceResult: true,
        clearCalculateError: true,
      ),
      emit,
    );
  }

  // ── Hours changed (hourly bookings) ──────────────────────────────────────

  void _onHoursChanged(ExtendHoursChanged event, Emitter<ExtendBookingState> emit) {
    // Compute the synthetic extendEndDate from currentEndDate + hours
    final base = _parseDate(currentEndDate);
    final syntheticEnd = base.add(Duration(hours: event.hours));
    _emit(
      _data.copyWith(
        selectedHours: event.hours,
        extendEndDate: syntheticEnd,
        clearPriceResult: true,
        clearCalculateError: true,
      ),
      emit,
    );
  }

  // ── Step 1: Calculate price ───────────────────────────────────────────────

  Future<void> _onCalculatePrice(ExtendCalculatePrice event, Emitter<ExtendBookingState> emit) async {
    final isHourly = serviceType == 'hourly';
    final hours = _data.selectedHours;
    final endDate = _data.extendEndDate;

    if (isHourly && (hours == null || hours <= 0)) return;
    if (!isHourly && endDate == null) return;

    _emit(_data.copyWith(isCalculating: true, clearCalculateError: true), emit);

    try {
      final extendEndStr = _formatDate(endDate!);
      final diffDays = isHourly ? 0 : endDate.difference(_parseDate(currentEndDate)).inDays;

      final result = await _repo.calculatePrice(
        serviceRequestId: serviceRequestId,
        customerProfileId: _customerId,
        serviceType: serviceType,
        endDate: currentEndDate,
        extendEndDate: extendEndStr,
        durationDays: isHourly ? null : diffDays,
        durationHours: isHourly ? hours : null,
      );

      _emit(_data.copyWith(isCalculating: false, priceResult: result), emit);

      emit(ExtendShowPriceDialog(data: _data));
      emit(_data);
    } catch (e) {
      final error = e.toString().replaceAll('Exception:', '').trim();
      _emit(_data.copyWith(isCalculating: false, calculateError: error), emit);
    }
  }

  // ── Step 2: Submit extend order ───────────────────────────────────────────

  Future<void> _onSubmitOrder(ExtendSubmitOrder event, Emitter<ExtendBookingState> emit) async {
    final isHourly = serviceType == 'hourly';
    final hours = _data.selectedHours;
    final endDate = _data.extendEndDate;
    final price = _data.priceResult;

    if (price == null) return;
    if (isHourly && (hours == null || hours <= 0)) return;
    if (!isHourly && endDate == null) return;

    _emit(_data.copyWith(isSubmitting: true, clearSubmitError: true), emit);

    try {
      final extendEndStr = _formatDate(endDate!);
      final diffDays = isHourly ? 0 : endDate.difference(_parseDate(currentEndDate)).inDays;

      final order = await _repo.initiateExtend(
        serviceRequestId: serviceRequestId,
        serviceType: serviceType,
        endDate: currentEndDate,
        extendEndDate: extendEndStr,
        durationDays: isHourly ? null : diffDays,
        durationHours: isHourly ? hours : null,
        amount: price.totalAmount,
        bookingId: bookingId,
      );

      _emit(_data.copyWith(isSubmitting: false, currentOrder: order), emit);

      final userDetail = await _storage.getUserProfile();
      final options = <String, dynamic>{
        'key': order.razorpayKey,
        'amount': order.amount,
        'currency': order.currency,
        'order_id': order.razorpayOrderId,
        'name': 'Adhisaat Health Care',
        'description': 'Extend Booking #$serviceRequestId',
        'prefill': {'contact': userDetail?['mobile_number'] ?? '', 'email': userDetail?['email'] ?? ''},
        'theme': {'color': '#2D62ED'},
      };

      emit(ExtendOpenRazorpay(data: _data, options: options));
      emit(_data);
    } catch (e) {
      final error = e.toString().replaceAll('Exception:', '').trim();
      _emit(_data.copyWith(isSubmitting: false, submitError: error), emit);
      emit(ExtendSnackBar(data: _data, message: error, isError: true));
      emit(_data);
    }
  }

  // ── Step 3: Razorpay success → verify ────────────────────────────────────

  Future<void> _onRazorpaySuccess(ExtendRazorpaySuccess event, Emitter<ExtendBookingState> emit) async {
    final price = _data.priceResult;
    final order = _data.currentOrder;
    if (price == null || order == null) return;

    _emit(_data.copyWith(isVerifying: true), emit);

    try {
      final verified = await _repo.verifyPayment(
        customerProfileId: _customerId,
        amount: price.totalAmount,
        basePrice: price.basePrice,
        distanceCharge: price.distanceCharge,
        gstAmount: price.gstAmount,
        discountAmount: 0,
        razorpayPaymentId: event.paymentId,
        razorpayOrderId: event.orderId.isEmpty ? order.razorpayOrderId : event.orderId,
        razorpaySignature: event.signature,
      );

      if (verified) {
        emit(const ExtendPaymentSuccess());
      } else {
        _emit(_data.copyWith(isVerifying: false), emit);
        emit(
          ExtendSnackBar(
            data: _data,
            message: 'Payment verification failed. Please contact support.',
            isError: true,
          ),
        );
        emit(_data);
      }
    } catch (e) {
      final error = e.toString().replaceAll('Exception:', '').trim();
      _emit(_data.copyWith(isVerifying: false), emit);
      emit(ExtendSnackBar(data: _data, message: 'Verification error: $error', isError: true));
      emit(_data);
    }
  }

  // ── Razorpay failure ──────────────────────────────────────────────────────

  void _onRazorpayFailure(ExtendRazorpayFailure event, Emitter<ExtendBookingState> emit) {
    // Filter out 'undefined' or null/empty messages from Razorpay
    String failMsg = event.message ?? 'Unknown error';
    if (failMsg.toLowerCase() == 'undefined' || failMsg.trim().isEmpty) {
      failMsg = 'Cancelled by user';
    }

    emit(ExtendSnackBar(data: _data, message: 'Payment failed: $failMsg', isError: true));
    emit(_data);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _parseDate(String s) {
    final parts = s.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }
}
