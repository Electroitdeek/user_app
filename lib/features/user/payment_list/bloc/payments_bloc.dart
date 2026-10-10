import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../payment/data/payment_repository.dart';
import '../model/payment_model.dart';

// ─── Filter model ─────────────────────────────────────────────────────────────

class PaymentFilter {
  final String search;
  final String paymentStatus; // '' = all
  final int perPage;
  final String sortField;
  final String sortDirection;

  const PaymentFilter({
    this.search = '',
    this.paymentStatus = '',
    this.perPage = 15,
    this.sortField = 'id',
    this.sortDirection = 'desc',
  });

  PaymentFilter copyWith({
    String? search,
    String? paymentStatus,
    int? perPage,
    String? sortField,
    String? sortDirection,
  }) =>
      PaymentFilter(
        search: search ?? this.search,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        perPage: perPage ?? this.perPage,
        sortField: sortField ?? this.sortField,
        sortDirection: sortDirection ?? this.sortDirection,
      );

  @override
  bool operator ==(Object other) =>
      other is PaymentFilter &&
      search == other.search &&
      paymentStatus == other.paymentStatus &&
      perPage == other.perPage &&
      sortField == other.sortField &&
      sortDirection == other.sortDirection;

  @override
  int get hashCode =>
      Object.hash(search, paymentStatus, perPage, sortField, sortDirection);
}

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class PaymentsEvent {}

class LoadPayments extends PaymentsEvent {
  final bool isRefresh;
  final PaymentFilter? filter;

  LoadPayments({this.isRefresh = false, this.filter});
}

class LoadMorePayments extends PaymentsEvent {}

class UpdatePaymentFilter extends PaymentsEvent {
  final PaymentFilter filter;
  UpdatePaymentFilter(this.filter);
}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class PaymentsState {}

class PaymentsInitial extends PaymentsState {}

class PaymentsLoading extends PaymentsState {}

class PaymentsLoaded extends PaymentsState {
  final List<PaymentModel> payments;
  final bool hasReachedMax;
  final bool isRefreshing;
  final PaymentFilter filter;

  PaymentsLoaded({
    required this.payments,
    this.hasReachedMax = false,
    this.isRefreshing = false,
    this.filter = const PaymentFilter(),
  });

  PaymentsLoaded copyWith({
    List<PaymentModel>? payments,
    bool? hasReachedMax,
    bool? isRefreshing,
    PaymentFilter? filter,
  }) =>
      PaymentsLoaded(
        payments: payments ?? this.payments,
        hasReachedMax: hasReachedMax ?? this.hasReachedMax,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        filter: filter ?? this.filter,
      );
}

class PaymentsError extends PaymentsState {
  final String message;
  PaymentsError(this.message);
}

// ─── Bloc ─────────────────────────────────────────────────────────────────────

class PaymentsBloc extends Bloc<PaymentsEvent, PaymentsState> {
  final PaymentRepository _repository;
  int _currentPage = 1;
  PaymentFilter _filter = const PaymentFilter();

  Timer? _debounce;

  PaymentsBloc(this._repository) : super(PaymentsInitial()) {
    on<LoadPayments>(_onLoadPayments);
    on<LoadMorePayments>(_onLoadMorePayments);
    on<UpdatePaymentFilter>(_onUpdateFilter);
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }

  Future<void> _onLoadPayments(
    LoadPayments event,
    Emitter<PaymentsState> emit,
  ) async {
    if (event.filter != null) _filter = event.filter!;

    if (event.isRefresh && state is PaymentsLoaded) {
      emit((state as PaymentsLoaded).copyWith(isRefreshing: true));
    } else {
      emit(PaymentsLoading());
    }

    _currentPage = 1;
    await _fetch(emit);
  }

  Future<void> _onUpdateFilter(
    UpdatePaymentFilter event,
    Emitter<PaymentsState> emit,
  ) async {
    _filter = event.filter;
    emit(PaymentsLoading());
    _currentPage = 1;
    await _fetch(emit);
  }

  Future<void> _onLoadMorePayments(
    LoadMorePayments event,
    Emitter<PaymentsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! PaymentsLoaded || currentState.hasReachedMax) return;

    try {
      final nextPage = _currentPage + 1;
      final response = await _repository.getPayments(
        page: nextPage,
        search: _filter.search,
        status: _filter.paymentStatus,
      );
      _currentPage = nextPage;
      emit(currentState.copyWith(
        payments: currentState.payments + response.payments,
        hasReachedMax: response.currentPage >= response.lastPage,
      ));
    } catch (_) {
      // Fail silently for load more
    }
  }

  Future<void> _fetch(Emitter<PaymentsState> emit) async {
    try {
      final response = await _repository.getPayments(
        page: _currentPage,
        search: _filter.search,
        status: _filter.paymentStatus,
      );
      emit(PaymentsLoaded(
        payments: response.payments,
        hasReachedMax: response.currentPage >= response.lastPage,
        filter: _filter,
      ));
    } catch (e) {
      emit(PaymentsError(e.toString()));
    }
  }
}
