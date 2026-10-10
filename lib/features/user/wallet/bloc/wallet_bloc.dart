import 'package:adhisaat_health_care/core/storage/local_storage_service.dart';
import 'package:adhisaat_health_care/data/models/payment_order_result.dart';
import 'package:adhisaat_health_care/data/repositories/system_settings_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/wallet_repository.dart';
import 'wallet_state.dart';

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  final WalletRepository _repo;
  final LocalStorageService _storage;
  final SystemSettingsRepository _settingsRepo;

  // We need to keep track of some data between initiation and verification
  double _lastAmount = 0.0;
  String? _bonusPercentage;
  PaymentOrderResult? _lastInitiationResult;

  String? get bonusPercentage => _bonusPercentage;

  WalletBloc(this._repo, this._storage, this._settingsRepo) : super(WalletInitial()) {
    on<InitiateWalletTopUpEvent>(_onInitiate);
    on<WalletPaymentSuccessEvent>(_onSuccess);
    on<WalletPaymentErrorEvent>(_onFailure);
    on<FetchWalletTransactionsEvent>(_onFetchTransactions);
  }

  Future<void> _onFetchTransactions(FetchWalletTransactionsEvent event, Emitter<WalletState> emit) async {
    emit(WalletTransactionsLoading());
    try {
      // Fetch settings
      final settingResponse = await _settingsRepo.getSystemSettings();

      // Top-up bonus setting - now fetched from companyData
      _bonusPercentage = settingResponse.companyData?.walletAddMoneyBonusPercentage?.toString();

      // Per-booking adjustment setting - now fetched from companyData
      final adjustmentPercentage =
          settingResponse.companyData?.perBookingBonusAdjustmentPercentage?.toString() ?? '0';

      final res = await _repo.fetchWalletTransactions(page: event.page, perPage: event.perPage);
      if (res['status'] == true) {
        final List<dynamic> list = res['data'] is List ? res['data'] : (res['data']?['data'] ?? []);
        final walletAmount = res['wallet']?['wallet_amount'] ?? 0;
        final bonusWalletAmount = res['wallet']?['bonus_wallet_amount'] ?? 0;
        emit(
          WalletTransactionsLoaded(
            list,
            walletAmount,
            bonusWalletAmount,
            bonusPercentage: _bonusPercentage ?? '0',
            bonusAdjustmentPercentage: adjustmentPercentage,
          ),
        );
      } else {
        emit(WalletTransactionsError(res['message'] ?? 'Failed to fetch transactions'));
      }
    } catch (e) {
      emit(WalletTransactionsError(e.toString()));
    }
  }

  Future<void> _onInitiate(InitiateWalletTopUpEvent event, Emitter<WalletState> emit) async {
    emit(WalletLoading());
    try {
      _lastAmount = event.amount;
      final userId = _storage.userId ?? 0;
      final result = await _repo.initiateWalletTopUp(userId: userId, amount: event.amount);
      _lastInitiationResult = result;

      final userDetail = await _storage.getUserProfile();

      final options = {
        'key': result.razorpayKey,
        'amount': result.amount,
        'name': 'Adhisaat Health Care',
        'order_id': result.razorpayOrderId,
        'description': 'Wallet Top Up',
        'timeout': 180, // in seconds
        'prefill': {
          'contact': userDetail?['mobile_number']?.toString() ?? '',
          'email': (userDetail?['email'] != null && userDetail?['email'].toString().isNotEmpty == true)
              ? userDetail!['email'].toString()
              : _storage.email ?? '',
        },
        'theme': {'color': '#1565C0'}, // kPrimaryColor hex
      };

      emit(WalletInitiateSuccess(options));
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onSuccess(WalletPaymentSuccessEvent event, Emitter<WalletState> emit) async {
    emit(WalletLoading());
    try {
      final customerProfileId = _storage.customerUserId ?? 0;

      final res = await _repo.verifyWalletTopUp(
        bookingId: _lastInitiationResult?.bookingId ?? 0,
        serviceRequestId: _lastInitiationResult?.serviceRequestId ?? 0,
        customerProfileId: customerProfileId,
        bookingType: _lastInitiationResult?.bookingType ?? "wallet_topup",
        basePrice: _lastAmount,
        distanceCharge: 0.0,
        gstAmount: 0.0,
        discountAmount: 0.0,
        amount: _lastAmount,
        promocode: _lastInitiationResult?.promocode ?? "",
        razorpayPaymentId: event.paymentId,
        razorpayOrderId: event.orderId,
        razorpaySignature: event.signature,
      );

      emit(WalletVerifySuccess(res));
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onFailure(WalletPaymentErrorEvent event, Emitter<WalletState> emit) async {
    emit(WalletError(state is WalletLoading ? event.message : "Payment failed: ${event.message}"));
  }
}
