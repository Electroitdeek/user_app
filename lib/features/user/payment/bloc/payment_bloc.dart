import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/storage/local_storage_service.dart';
import 'package:adhisaat_health_care/data/models/system_settings_model.dart';
import 'package:adhisaat_health_care/data/providers/system_settings_provider.dart';
import 'package:adhisaat_health_care/data/repositories/system_settings_repository.dart';
import 'package:adhisaat_health_care/features/user/payment/data/payment_repository.dart';
import 'package:adhisaat_health_care/features/user/wallet/data/wallet_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/payment_order_result.dart';

part 'payment_event.dart';
part 'payment_state.dart';

class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  final PaymentRepository _repo;
  final LocalStorageService _storage;
  final SystemSettingsRepository _settingsRepo;
  final WalletRepository _walletRepo;
  final ProviderContainer? _container;

  /// Always reflects the latest PaymentSheetData so action states can reference it.
  PaymentSheetData _data = const PaymentSheetData();

  PaymentBloc(this._repo, this._storage, this._settingsRepo, this._walletRepo, {ProviderContainer? container})
    : _container = container,
      super(const PaymentSheetData()) {
    on<ApplyPromoEvent>(_onApplyPromo);
    on<RemovePromoEvent>(_onRemovePromo);
    on<InitiatePaymentEvent>(_onInitiatePayment);
    on<RazorpaySuccessEvent>(_onRazorpaySuccess);
    on<RazorpayFailureEvent>(_onRazorpayFailure);
    on<CancelBookingEvent>(_onCancelBooking);
    on<FetchAvailablePromosEvent>(_onFetchAvailablePromos);
  }

  /// Convenience: keeps [_data] in sync and emits the updated state.
  void _emitData(PaymentSheetData updated, Emitter<PaymentState> emit) {
    _data = updated;
    emit(_data);
  }

  // ── Apply Promo ────────────────────────────────────────────────────────────

  Future<void> _onApplyPromo(ApplyPromoEvent event, Emitter<PaymentState> emit) async {
    _emitData(_data.copyWith(promoLoading: true, clearPromoError: true), emit);
    try {
      final result = await _repo.applyPromocode(
        serviceRequestId: event.serviceRequestId,
        promocode: event.code,
      );
      _emitData(
        _data.copyWith(
          promoLoading: false,
          appliedCode: event.code,
          discountAmount: result.discountAmount,
          promoCodeId: result.promoCodeId,
        ),
        emit,
      );
      // One-shot: show celebratory dialog, then restore builder to latest data.
      emit(
        PromoAppliedState(
          data: _data,
          code: event.code,
          discountAmount: result.discountAmount,
          message: result.message,
        ),
      );
      emit(_data);
    } catch (e) {
      final error = e.toString().replaceAll('Exception:', '').trim();
      _emitData(_data.copyWith(promoLoading: false, promoError: error), emit);
    }
  }

  // ── Remove Promo ───────────────────────────────────────────────────────────

  void _onRemovePromo(RemovePromoEvent event, Emitter<PaymentState> emit) {
    _emitData(
      _data.copyWith(clearAppliedCode: true, discountAmount: 0.0, clearPromoCodeId: true, clearPromoError: true),
      emit,
    );
  }

  // ── Fetch Available Promos ──────────────────────────────────────────────────
  Future<void> _onFetchAvailablePromos(FetchAvailablePromosEvent event, Emitter<PaymentState> emit) async {
    _emitData(_data.copyWith(promosLoading: true), emit);
    try {
      final results = await Future.wait([
        _repo.getAvailablePromoCodes(serviceRequestId: event.serviceRequestId),
        _container != null ? _container.read(systemSettingsProvider.future) : _settingsRepo.getSystemSettings(),
        _walletRepo.fetchWalletTransactions(),
      ]);

      final promos = results[0] as List<AvailablePromoCode>;
      final settings = results[1] as SystemSettingsResponse;
      final walletRes = results[2] as Map<String, dynamic>;

      double adjustmentPct = 0.0;
      final bonusSetting = settings.companyData?.perBookingBonusAdjustmentPercentage?.toString() ?? '0';

      adjustmentPct = double.tryParse(bonusSetting) ?? 0.0;
      kPrint('✅ Bonus Adjustment Percentage loaded: $adjustmentPct%');

      // Parse fresh wallet and bonus balances
      double walletBal = 0.0;
      double bonusBal = 0.0;
      if (walletRes['wallet'] != null) {
        final w = walletRes['wallet'];
        walletBal = double.tryParse(w['wallet_amount']?.toString() ?? '0') ?? 0.0;
        bonusBal = double.tryParse(w['bonus_wallet_amount']?.toString() ?? '0') ?? 0.0;
        kPrint('✅ Real-time Balances: Wallet: $walletBal, Bonus: $bonusBal');
      }

      _emitData(
        _data.copyWith(
          promosLoading: false,
          availablePromos: promos,
          bonusAdjustmentPercentage: adjustmentPct,
          walletBalance: walletBal,
          bonusBalance: bonusBal,
        ),
        emit,
      );
    } catch (e) {
      kPrintError('❌ Error fetching payment data: $e');
      // On error, still show the page but maybe with default balances/settings
      _emitData(_data.copyWith(promosLoading: false), emit);
    }
  }

  // ── Initiate Payment ───────────────────────────────────────────────────────

  Future<void> _onInitiatePayment(InitiatePaymentEvent event, Emitter<PaymentState> emit) async {
    _emitData(_data.copyWith(paymentLoading: true), emit);
    try {
      // ── Installment payment — uses dedicated endpoint ────────────────────────
      if (event.bookingType == 'installment_payment') {
        final response = await _repo.payPendingInstallments(
          serviceRequestId: event.serviceRequestId,
          customerProfileId: event.customerProfileId,
          cityAdminId: _storage.cityAdminId ?? 0,
          paymentInstallmentIds: event.paymentInstallmentIds,
          basePrice: event.basePrice,
          totalAmount: event.totalAmount,
          amount: event.payableAmount,
          promocode: event.appliedCode,
          promoCodeId: event.promoCodeId,
          discountAmount: event.discountAmount,
          bonusAmountUsed: event.bonusAmountUsed,
          walletAmountUsed: event.walletAmountUsed,
        );

        if (event.payableAmount <= 0) {
          // amount was 0 — API confirmed directly, no Razorpay needed
          final payData = response['data'] ?? response['payment'] ?? response['payment_detail'] ?? response;
          emit(
            PaymentSuccessState(
              transactionId: 'WALLET_PAYMENT_${event.serviceRequestId}',
              amount: event.payableAmount,
              paymentId: (payData['id'] ?? payData['payment_id']) as int?,
              paymentNumber: (payData['payment_number'] ?? payData['number'])?.toString(),
            ),
          );
          return;
        }

        // amount > 0 — open Razorpay
        final d = response['data'] as Map<String, dynamic>?;
        if (d == null) throw Exception('Payment order data missing from response');

        final order = PaymentOrderResult(
          razorpayOrderId: (d['gateway_order_id'] ?? d['razorpay_order_id'] ?? '') as String,
          amount: (d['amount'] as num).toInt(),
          currency: d['currency'] as String? ?? 'INR',
          razorpayKey: d['razorpay_key'] as String,
          tempOrderId: (d['temp_order_id'] as num).toInt(),
        );

        final verifyParams = PaymentVerifyParams(
          serviceRequestId: event.serviceRequestId,
          bookingId: event.bookingId,
          customerProfileId: event.customerProfileId,
          payableAmount: event.payableAmount,
          basePrice: event.basePrice,
          distanceCharge: event.distanceCharge,
          gstAmount: event.gstAmount,
          discountAmount: event.discountAmount,
          promocode: event.appliedCode,
          promoCodeId: _data.promoCodeId,
          bookingType: event.bookingType,
          walletAmountUsed: event.walletAmountUsed,
          bonusAmountUsed: event.bonusAmountUsed,
        );

        _emitData(_data.copyWith(paymentLoading: false, currentOrder: order, verifyParams: verifyParams), emit);

        if (order.razorpayOrderId.isEmpty) {
          throw Exception("Razorpay Order ID was not generated. Please try again.");
        }

        final userDetail = await _storage.getUserProfile();
        final razorpayOptions = <String, dynamic>{
          'key': order.razorpayKey,
          'amount': order.amount.toInt(),
          'currency': order.currency,
          'order_id': order.razorpayOrderId,
          'name': 'Adhisaat Health Care',
          'description': 'Installment #${event.serviceRequestId}',
          'prefill': {
            'contact': userDetail?['mobile_number']?.toString() ?? '',
            'email': (userDetail?['email'] != null && userDetail?['email'].toString().isNotEmpty == true)
                ? userDetail!['email'].toString()
                : '',
          },
          'theme': {'color': '#2D62ED'},
        };
        emit(PaymentOpenRazorpayState(data: _data, razorpayOptions: razorpayOptions));
        emit(_data);
        return;
      }

      // ── Standard booking payment — same record admin stores on the booking ──
      if (event.payableAmount == 0) {
        emit(
          PaymentSuccessState(
            transactionId: 'DIRECT_CONFIRMATION_${event.serviceRequestId}',
            amount: event.payableAmount,
          ),
        );
        return;
      }

      final double roundedAmount = double.parse(event.payableAmount.toStringAsFixed(2));
      final response = await _repo.recordBookingPayment(
        serviceRequestId: event.serviceRequestId,
        amount: roundedAmount,
        method: event.method,
        gatewayRef: event.gatewayRef,
      );
      final data = response['data'] is Map ? Map<String, dynamic>.from(response['data'] as Map) : <String, dynamic>{};
      final payment = data['payment'] is Map ? Map<String, dynamic>.from(data['payment'] as Map) : data;
      emit(
        PaymentSuccessState(
          transactionId: payment['number']?.toString() ?? 'PAYMENT_${event.serviceRequestId}',
          amount: roundedAmount,
          paymentNumber: payment['number']?.toString(),
        ),
      );
      return;
    } catch (e) {
      _emitData(_data.copyWith(paymentLoading: false), emit);
      if (e is PaymentApiException && e.showDialog) {
        emit(PaymentErrorDialogState(data: _data, message: e.message));
      } else {
        final error = e.toString().replaceAll('Exception:', '').trim();
        emit(PaymentSnackBarState(data: _data, message: error, isError: true));
      }
      emit(_data);
    }
  }

  // ── Razorpay Success → Verify ──────────────────────────────────────────────

  Future<void> _onRazorpaySuccess(RazorpaySuccessEvent event, Emitter<PaymentState> emit) async {
    final params = _data.verifyParams;
    if (params == null) return;

    _emitData(_data.copyWith(paymentLoading: true), emit);
    try {
      final response = await _repo.verifyPayment(
        serviceRequestId: params.serviceRequestId,
        bookingId: params.bookingId,
        customerProfileId: params.customerProfileId,
        amount: params.payableAmount,
        basePrice: params.basePrice,
        distanceCharge: params.distanceCharge,
        gstAmount: params.gstAmount,
        discountAmount: params.discountAmount,
        razorpayPaymentId: event.paymentId,
        razorpayOrderId: event.orderId.isEmpty ? (_data.currentOrder?.razorpayOrderId ?? '') : event.orderId,
        razorpaySignature: event.signature,
        promocode: params.promocode,
        promoCodeId: params.promoCodeId,
        bookingType: params.bookingType,
        walletAmountUsed: params.walletAmountUsed,
        bonusAmountUsed: params.bonusAmountUsed,
      );

      if (response['status'] == true) {
        // Look for payment details in various possible structures
        final data = response['data'] is Map ? response['data'] : null;
        final payment =
            (data != null ? data['payment'] ?? data['payment_detail'] : null) ??
            response['payment'] ??
            response['payment_detail'] ??
            data ??
            response;

        final id = payment['id'] ?? payment['payment_id'];
        final number = payment['payment_number'] ?? payment['number'] ?? payment['transaction_id'];

        // One-shot: close the sheet.
        emit(
          PaymentSuccessState(
            transactionId: event.paymentId,
            amount: params.payableAmount,
            paymentId: id is int ? id : int.tryParse(id?.toString() ?? ''),
            paymentNumber: number?.toString(),
          ),
        );
      } else {
        _emitData(_data.copyWith(paymentLoading: false), emit);
        emit(
          PaymentSnackBarState(
            data: _data,
            message: response['message'] ?? 'Payment verification failed. Contact support.',
            isError: true,
          ),
        );
        emit(_data);
      }
    } catch (e) {
      final error = e.toString().replaceAll('Exception:', '').trim();
      _emitData(_data.copyWith(paymentLoading: false), emit);
      emit(PaymentSnackBarState(data: _data, message: 'Verification error: $error', isError: true));
      emit(_data);
    }
  }

  // ── Razorpay Failure ───────────────────────────────────────────────────────

  Future<void> _onRazorpayFailure(RazorpayFailureEvent event, Emitter<PaymentState> emit) async {
    final orderId = _data.currentOrder?.razorpayOrderId;
    if (orderId != null && orderId.isNotEmpty) {
      _repo.reportPaymentFailed(razorpayOrderId: orderId).catchError((_) {});
    }

    // Filter out 'undefined', null, or empty messages from Razorpay
    String failMsg = event.message?.trim() ?? '';
    final failLower = failMsg.toLowerCase();

    if (failLower == 'undefined' || failMsg.isEmpty || failLower.contains('cancel')) {
      failMsg = 'Cancelled by user';
    }

    emit(PaymentSnackBarState(data: _data, message: 'Payment failed', isError: true));

    emit(_data);
  }

  // ── Cancel Booking ─────────────────────────────────────────────────────────

  Future<void> _onCancelBooking(CancelBookingEvent event, Emitter<PaymentState> emit) async {
    _emitData(_data.copyWith(paymentLoading: true), emit);
    try {
      final success = await _repo.cancelBooking(event.requestId);
      if (success) {
        emit(const PaymentCancelledState());
      } else {
        _emitData(_data.copyWith(paymentLoading: false), emit);
        emit(PaymentSnackBarState(data: _data, message: 'Failed to cancel booking', isError: true));
        emit(_data);
      }
    } catch (e) {
      final error = e.toString().replaceAll('Exception:', '').trim();
      _emitData(_data.copyWith(paymentLoading: false), emit);
      emit(PaymentSnackBarState(data: _data, message: error, isError: true));
      emit(_data);
    }
  }
}
