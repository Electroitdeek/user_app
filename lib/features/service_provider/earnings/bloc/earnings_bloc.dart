import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../model/payout_model.dart';
import '../repository/earnings_repository.dart';

// ════════════════════════════════════════════════════════════════
// Events
// ════════════════════════════════════════════════════════════════
abstract class EarningsEvent extends Equatable {
  @override List<Object?> get props => [];
}

class EarningsLoad extends EarningsEvent {}

class EarningsRefresh extends EarningsEvent {}

class EarningsLoadMore extends EarningsEvent {}

class EarningsSearchChanged extends EarningsEvent {
  final String query;
  EarningsSearchChanged(this.query);
  @override List<Object?> get props => [query];
}

class EarningsStatusFilterChanged extends EarningsEvent {
  final PayoutStatusFilter status;
  EarningsStatusFilterChanged(this.status);
  @override List<Object?> get props => [status];
}

class EarningsSortChanged extends EarningsEvent {
  final EarningSortField field;
  final EarningSortDirection direction;
  EarningsSortChanged(this.field, this.direction);
  @override List<Object?> get props => [field, direction];
}

class EarningsResetFilters extends EarningsEvent {}

// ════════════════════════════════════════════════════════════════
// State
// ════════════════════════════════════════════════════════════════
enum EarningsStatus { initial, loading, loaded, loadingMore, error }

class EarningsState extends Equatable {
  final EarningsStatus status;
  final List<PayoutModel> payouts;
  final PayoutPagination? pagination;
  final EarningFilters filters;
  final String? errorMessage;
  final bool isRefreshing;

  // Summary stats derived from current full list
  final double totalNet;
  final double totalService;
  final double totalCommission;
  final EarningSummary summary;

  const EarningsState({
    this.status = EarningsStatus.initial,
    this.payouts = const [],
    this.pagination,
    this.filters = const EarningFilters(),
    this.errorMessage,
    this.isRefreshing = false,
    this.totalNet = 0,
    this.totalService = 0,
    this.totalCommission = 0,
    this.summary = const EarningSummary.empty(),
  });

  bool get hasMore => pagination?.hasMore ?? false;
  bool get isLoading => status == EarningsStatus.loading;
  bool get isLoadingMore => status == EarningsStatus.loadingMore;

  EarningsState copyWith({
    EarningsStatus? status,
    List<PayoutModel>? payouts,
    PayoutPagination? pagination,
    EarningFilters? filters,
    String? errorMessage,
    bool? isRefreshing,
    double? totalNet,
    double? totalService,
    double? totalCommission,
    EarningSummary? summary,
  }) => EarningsState(
    status:          status          ?? this.status,
    payouts:         payouts         ?? this.payouts,
    pagination:      pagination      ?? this.pagination,
    filters:         filters         ?? this.filters,
    errorMessage:    errorMessage,
    isRefreshing:    isRefreshing    ?? this.isRefreshing,
    totalNet:        totalNet        ?? this.totalNet,
    totalService:    totalService    ?? this.totalService,
    totalCommission: totalCommission ?? this.totalCommission,
    summary:         summary         ?? this.summary,
  );

  @override
  List<Object?> get props => [
    status, payouts.length, pagination?.currentPage,
    filters, errorMessage, isRefreshing,
    totalNet, totalService, totalCommission,
    summary,
  ];
}

// ════════════════════════════════════════════════════════════════
// BLoC
// ════════════════════════════════════════════════════════════════
class EarningsBloc extends Bloc<EarningsEvent, EarningsState> {
  final EarningsRepository _repo;
  Timer? _searchDebounce;

  EarningsBloc(this._repo) : super(const EarningsState()) {
    on<EarningsLoad>(_onLoad);
    on<EarningsRefresh>(_onRefresh);
    on<EarningsLoadMore>(_onLoadMore);
    on<EarningsSearchChanged>(_onSearchChanged);
    on<EarningsStatusFilterChanged>(_onStatusFilter);
    on<EarningsSortChanged>(_onSortChanged);
    on<EarningsResetFilters>(_onResetFilters);
  }

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    return super.close();
  }

  // ── Initial load ─────────────────────────────────────────────
  Future<void> _onLoad(EarningsLoad _, Emitter<EarningsState> emit) async {
    emit(state.copyWith(status: EarningsStatus.loading));
    await _fetch(emit, state.filters.copyWith(page: 1), replace: true);
  }

  // ── Pull-to-refresh ───────────────────────────────────────────
  Future<void> _onRefresh(EarningsRefresh _, Emitter<EarningsState> emit) async {
    emit(state.copyWith(isRefreshing: true));
    await _fetch(emit, state.filters.copyWith(page: 1), replace: true);
  }

  // ── Infinite scroll ───────────────────────────────────────────
  Future<void> _onLoadMore(EarningsLoadMore _, Emitter<EarningsState> emit) async {
    if (!state.hasMore || state.isLoadingMore) return;
    emit(state.copyWith(status: EarningsStatus.loadingMore));
    await _fetch(
      emit,
      state.filters.copyWith(page: (state.pagination?.currentPage ?? 1) + 1),
      replace: false,
    );
  }

  // ── Search (debounced 400ms) ──────────────────────────────────
  Future<void> _onSearchChanged(EarningsSearchChanged e, Emitter<EarningsState> emit) async {
    _searchDebounce?.cancel();
    final newFilters = state.filters.copyWith(search: e.query, page: 1);
    emit(state.copyWith(filters: newFilters, status: EarningsStatus.loading));
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!isClosed) add(EarningsLoad());
    });
  }

  // ── Status filter ─────────────────────────────────────────────
  Future<void> _onStatusFilter(EarningsStatusFilterChanged e, Emitter<EarningsState> emit) async {
    final newFilters = state.filters.copyWith(status: e.status, page: 1);
    emit(state.copyWith(filters: newFilters, status: EarningsStatus.loading));
    await _fetch(emit, newFilters, replace: true);
  }

  // ── Sort ──────────────────────────────────────────────────────
  Future<void> _onSortChanged(EarningsSortChanged e, Emitter<EarningsState> emit) async {
    final newFilters = state.filters.copyWith(
        sortField: e.field, sortDirection: e.direction, page: 1);
    emit(state.copyWith(filters: newFilters, status: EarningsStatus.loading));
    await _fetch(emit, newFilters, replace: true);
  }

  // ── Reset ─────────────────────────────────────────────────────
  Future<void> _onResetFilters(EarningsResetFilters _, Emitter<EarningsState> emit) async {
    const fresh = EarningFilters();
    emit(state.copyWith(filters: fresh, status: EarningsStatus.loading));
    await _fetch(emit, fresh, replace: true);
  }

  // ── Core fetch ────────────────────────────────────────────────
  Future<void> _fetch(
      Emitter<EarningsState> emit,
      EarningFilters filters, {
        required bool replace,
      }) async {
    try {
      final result = await _repo.getEarnings(filters);
      final merged = replace
          ? result.payouts
          : [...state.payouts, ...result.payouts];

      // Compute summary totals from merged list
      double net = 0, svc = 0, commission = 0;
      for (final p in merged) {
        net        += p.netAmount;
        svc        += p.serviceAmount;
        commission += p.commissionAmount;
      }

      emit(state.copyWith(
        status:          EarningsStatus.loaded,
        payouts:         merged,
        pagination:      result.pagination,
        filters:         filters,
        isRefreshing:    false,
        totalNet:        net,
        totalService:    svc,
        totalCommission: commission,
        summary:         result.summary,
      ));
    } catch (e) {
      emit(state.copyWith(
        status:       EarningsStatus.error,
        errorMessage: e.toString(),
        isRefreshing: false,
      ));
    }
  }
}