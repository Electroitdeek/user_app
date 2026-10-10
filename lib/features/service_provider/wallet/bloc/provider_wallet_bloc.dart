import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../model/provider_wallet_model.dart';
import '../repository/provider_wallet_repository.dart';

// ════════════════════════════════════════════════════════════════
// Events
// ════════════════════════════════════════════════════════════════
abstract class ProviderWalletEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class ProviderWalletFetch extends ProviderWalletEvent {}

class ProviderWalletRefresh extends ProviderWalletEvent {}

class ProviderWalletLoadMoreTransactions extends ProviderWalletEvent {}

class ProviderWalletLoadMoreWithdrawals extends ProviderWalletEvent {}

class ProviderWalletRequestWithdrawal extends ProviderWalletEvent {
  final double amount;
  ProviderWalletRequestWithdrawal(this.amount);
}

class ProviderWalletCancelWithdrawal extends ProviderWalletEvent {
  final int withdrawalId;
  ProviderWalletCancelWithdrawal(this.withdrawalId);
}

// ════════════════════════════════════════════════════════════════
// State
// ════════════════════════════════════════════════════════════════
enum ProviderWalletStatus { initial, loading, loaded, loadingMore, error }

enum WithdrawalRequestStatus { initial, loading, success, error }

class ProviderWalletState extends Equatable {
  final ProviderWalletStatus status;
  final WithdrawalRequestStatus requestStatus;
  final WithdrawalRequestStatus cancelStatus;
  final ProviderWalletData? walletData;
  final List<ProviderTransaction> transactions;
  final TransactionPagination? pagination;
  final List<ProviderWithdrawal> withdrawals;
  final TransactionPagination? withdrawalPagination;
  final String? errorMessage;
  final String? requestMessage;
  final String? cancelMessage;
  final bool isRefreshing;

  const ProviderWalletState({
    this.status = ProviderWalletStatus.initial,
    this.requestStatus = WithdrawalRequestStatus.initial,
    this.cancelStatus = WithdrawalRequestStatus.initial,
    this.walletData,
    this.transactions = const [],
    this.pagination,
    this.withdrawals = const [],
    this.withdrawalPagination,
    this.errorMessage,
    this.requestMessage,
    this.cancelMessage,
    this.isRefreshing = false,
  });

  bool get hasMoreTransactions =>
      pagination != null && pagination!.currentPage < pagination!.lastPage;
  bool get hasMoreWithdrawals =>
      withdrawalPagination != null &&
      withdrawalPagination!.currentPage < withdrawalPagination!.lastPage;
  bool get isLoading => status == ProviderWalletStatus.loading;
  bool get isLoadingMore => status == ProviderWalletStatus.loadingMore;
  bool get isRequesting => requestStatus == WithdrawalRequestStatus.loading;
  bool get isCanceling => cancelStatus == WithdrawalRequestStatus.loading;

  ProviderWalletState copyWith({
    ProviderWalletStatus? status,
    WithdrawalRequestStatus? requestStatus,
    WithdrawalRequestStatus? cancelStatus,
    ProviderWalletData? walletData,
    List<ProviderTransaction>? transactions,
    TransactionPagination? pagination,
    List<ProviderWithdrawal>? withdrawals,
    TransactionPagination? withdrawalPagination,
    String? errorMessage,
    String? requestMessage,
    String? cancelMessage,
    bool? isRefreshing,
  }) {
    return ProviderWalletState(
      status: status ?? this.status,
      requestStatus: requestStatus ?? this.requestStatus,
      cancelStatus: cancelStatus ?? this.cancelStatus,
      walletData: walletData ?? this.walletData,
      transactions: transactions ?? this.transactions,
      pagination: pagination ?? this.pagination,
      withdrawals: withdrawals ?? this.withdrawals,
      withdrawalPagination: withdrawalPagination ?? this.withdrawalPagination,
      errorMessage: errorMessage,
      requestMessage: requestMessage,
      cancelMessage: cancelMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [
    status,
    requestStatus,
    cancelStatus,
    walletData,
    transactions.length,
    pagination?.currentPage,
    withdrawals.length,
    withdrawalPagination?.currentPage,
    errorMessage,
    requestMessage,
    cancelMessage,
    isRefreshing,
  ];
}

// ════════════════════════════════════════════════════════════════
// BLoC
// ════════════════════════════════════════════════════════════════
class ProviderWalletBloc
    extends Bloc<ProviderWalletEvent, ProviderWalletState> {
  final ProviderWalletRepository _repo;

  ProviderWalletBloc(this._repo) : super(const ProviderWalletState()) {
    on<ProviderWalletFetch>(_onFetch);
    on<ProviderWalletRefresh>(_onRefresh);
    on<ProviderWalletLoadMoreTransactions>(_onLoadMoreTransactions);
    on<ProviderWalletLoadMoreWithdrawals>(_onLoadMoreWithdrawals);
    on<ProviderWalletRequestWithdrawal>(_onRequestWithdrawal);
    on<ProviderWalletCancelWithdrawal>(_onCancelWithdrawal);
  }

  Future<void> _onFetch(
    ProviderWalletFetch event,
    Emitter<ProviderWalletState> emit,
  ) async {
    emit(state.copyWith(status: ProviderWalletStatus.loading));
    await _fetchData(emit);
  }

  Future<void> _onRefresh(
    ProviderWalletRefresh event,
    Emitter<ProviderWalletState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true));
    await _fetchData(emit);
  }

  Future<void> _onLoadMoreTransactions(
    ProviderWalletLoadMoreTransactions event,
    Emitter<ProviderWalletState> emit,
  ) async {
    if (!state.hasMoreTransactions || state.isLoadingMore) return;
    emit(state.copyWith(status: ProviderWalletStatus.loadingMore));

    try {
      final nextPage = (state.pagination?.currentPage ?? 1) + 1;
      final result = await _repo.getTransactions(page: nextPage);

      emit(
        state.copyWith(
          status: ProviderWalletStatus.loaded,
          transactions: [...state.transactions, ...result.transactions],
          pagination: result.pagination,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ProviderWalletStatus.loaded,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onLoadMoreWithdrawals(
    ProviderWalletLoadMoreWithdrawals event,
    Emitter<ProviderWalletState> emit,
  ) async {
    if (!state.hasMoreWithdrawals || state.isLoadingMore) return;
    emit(state.copyWith(status: ProviderWalletStatus.loadingMore));

    try {
      final nextPage = (state.withdrawalPagination?.currentPage ?? 1) + 1;
      final result = await _repo.getWithdrawals(page: nextPage);

      emit(
        state.copyWith(
          status: ProviderWalletStatus.loaded,
          withdrawals: [...state.withdrawals, ...result.withdrawals],
          withdrawalPagination: result.pagination,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ProviderWalletStatus.loaded,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onRequestWithdrawal(
    ProviderWalletRequestWithdrawal event,
    Emitter<ProviderWalletState> emit,
  ) async {
    emit(state.copyWith(requestStatus: WithdrawalRequestStatus.loading));

    try {
      await _repo.requestWithdrawal(event.amount);
      emit(
        state.copyWith(
          requestStatus: WithdrawalRequestStatus.success,
          requestMessage: 'Withdrawal request submitted successfully',
        ),
      );
      // Refresh data after success
      add(ProviderWalletFetch());
    } catch (e) {
      emit(
        state.copyWith(
          requestStatus: WithdrawalRequestStatus.error,
          requestMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onCancelWithdrawal(
    ProviderWalletCancelWithdrawal event,
    Emitter<ProviderWalletState> emit,
  ) async {
    emit(state.copyWith(cancelStatus: WithdrawalRequestStatus.loading));

    try {
      await _repo.cancelWithdrawal(event.withdrawalId);
      emit(
        state.copyWith(
          cancelStatus: WithdrawalRequestStatus.success,
          cancelMessage: 'Withdrawal request cancelled successfully',
        ),
      );
      // Refresh data after success
      add(ProviderWalletFetch());
    } catch (e) {
      emit(
        state.copyWith(
          cancelStatus: WithdrawalRequestStatus.error,
          cancelMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _fetchData(Emitter<ProviderWalletState> emit) async {
    try {
      // Fetch balance, transactions, and withdrawals in parallel
      final results = await Future.wait([
        _repo.getWalletBalance(),
        _repo.getTransactions(page: 1),
        _repo.getWithdrawals(page: 1),
      ]);

      final walletData = results[0] as ProviderWalletData;
      final transactionResult =
          results[1]
              as ({
                List<ProviderTransaction> transactions,
                TransactionPagination pagination,
              });
      final withdrawalResult =
          results[2]
              as ({
                List<ProviderWithdrawal> withdrawals,
                TransactionPagination pagination,
              });

      emit(
        state.copyWith(
          status: ProviderWalletStatus.loaded,
          walletData: walletData,
          transactions: transactionResult.transactions,
          pagination: transactionResult.pagination,
          withdrawals: withdrawalResult.withdrawals,
          withdrawalPagination: withdrawalResult.pagination,
          isRefreshing: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ProviderWalletStatus.error,
          errorMessage: e.toString(),
          isRefreshing: false,
        ),
      );
    }
  }
}
