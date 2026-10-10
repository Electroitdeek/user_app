import 'package:equatable/equatable.dart';

abstract class WalletEvent extends Equatable {
  const WalletEvent();

  @override
  List<Object?> get props => [];
}

class InitiateWalletTopUpEvent extends WalletEvent {
  final double amount;
  const InitiateWalletTopUpEvent(this.amount);

  @override
  List<Object?> get props => [amount];
}

class WalletPaymentSuccessEvent extends WalletEvent {
  final String paymentId;
  final String orderId;
  final String signature;

  const WalletPaymentSuccessEvent({required this.paymentId, required this.orderId, required this.signature});

  @override
  List<Object?> get props => [paymentId, orderId, signature];
}

class WalletPaymentErrorEvent extends WalletEvent {
  final String message;
  const WalletPaymentErrorEvent(this.message);

  @override
  List<Object?> get props => [message];
}

class FetchWalletTransactionsEvent extends WalletEvent {
  final int page;
  final int perPage;

  const FetchWalletTransactionsEvent({this.page = 1, this.perPage = 20});

  @override
  List<Object?> get props => [page, perPage];
}

// ─── States ──────────────────────────────────────────────────────────────────

abstract class WalletState extends Equatable {
  const WalletState();

  @override
  List<Object?> get props => [];
}

class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

class WalletTransactionsLoading extends WalletState {}

class WalletInitiateSuccess extends WalletState {
  final Map<String, dynamic> razorpayOptions;
  const WalletInitiateSuccess(this.razorpayOptions);

  @override
  List<Object?> get props => [razorpayOptions];
}

class WalletVerifySuccess extends WalletState {
  final dynamic response;
  const WalletVerifySuccess(this.response);

  @override
  List<Object?> get props => [response];
}

class WalletTransactionsLoaded extends WalletState {
  final List<dynamic> transactions;
  final num walletAmount;
  final num bonusWalletAmount;
  final String bonusPercentage;
  final String bonusAdjustmentPercentage;
  const WalletTransactionsLoaded(
    this.transactions,
    this.walletAmount,
    this.bonusWalletAmount, {
    this.bonusPercentage = '',
    this.bonusAdjustmentPercentage = '',
  });

  @override
  List<Object?> get props => [
    transactions,
    walletAmount,
    bonusWalletAmount,
    bonusPercentage,
    bonusAdjustmentPercentage,
  ];
}

class WalletError extends WalletState {
  final String message;
  const WalletError(this.message);

  @override
  List<Object?> get props => [message];
}

class WalletTransactionsError extends WalletState {
  final String message;
  const WalletTransactionsError(this.message);

  @override
  List<Object?> get props => [message];
}
