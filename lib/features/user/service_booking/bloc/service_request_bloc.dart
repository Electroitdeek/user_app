import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../data/service_request_repository.dart';
import '../model/booking_model.dart';
import '../model/service_request_model.dart';

part 'service_request_event.dart';
part 'service_request_state.dart';

class ServiceRequestBloc extends Bloc<ServiceRequestEvent, ServiceRequestState> {
  final ServiceRequestRepository _repository;

  ServiceRequestBloc(this._repository) : super(ServiceRequestInitial()) {
    on<CreateServiceRequest>(_onCreate);
    on<LoadServiceRequests>(_onLoad);
    on<LoadMoreServiceRequests>(_onLoadMore);
    on<CancelServiceRequest>(_onCancel);
  }

  Future<void> _onCreate(
    CreateServiceRequest event,
    Emitter<ServiceRequestState> emit,
  ) async {
    emit(ServiceRequestLoading());
    try {
      final result = await _repository.createServiceRequest(event.request);
      emit(ServiceRequestCreated(result));
    } catch (e) {
      emit(ServiceRequestError(e.toString()));
    }
  }

  // ── Fresh load / refresh ──────────────────────────────────────────────────

  Future<void> _onLoad(
    LoadServiceRequests event,
    Emitter<ServiceRequestState> emit,
  ) async {
    emit(ServiceRequestLoading());
    try {
      final res = await _repository.getServiceRequests(
        page: 1,
        status: event.status,
        search: event.search,
        perPage: event.perPage,
      );
      emit(ServiceRequestListLoaded(
        requests: res.requests,
        currentPage: res.currentPage,
        lastPage: res.lastPage,
        total: res.total,
        activeStatus: event.status,
        activeSearch: event.search,
      ));
    } catch (e) {
      emit(ServiceRequestError(e.toString()));
    }
  }

  // ── Load more (pagination) ────────────────────────────────────────────────

  Future<void> _onLoadMore(
    LoadMoreServiceRequests event,
    Emitter<ServiceRequestState> emit,
  ) async {
    final current = state;
    if (current is! ServiceRequestListLoaded) return;
    if (!current.hasMore || current.isLoadingMore) return;

    emit(current.copyWith(isLoadingMore: true));
    try {
      final res = await _repository.getServiceRequests(
        page: event.page,
        status: event.status,
        search: event.search,
        perPage: event.perPage,
      );
      emit(current.copyWith(
        requests: [...current.requests, ...res.requests],
        currentPage: res.currentPage,
        lastPage: res.lastPage,
        total: res.total,
        isLoadingMore: false,
      ));
    } catch (e) {
      emit(current.copyWith(isLoadingMore: false));
    }
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  Future<void> _onCancel(
    CancelServiceRequest event,
    Emitter<ServiceRequestState> emit,
  ) async {
    emit(ServiceRequestLoading());
    try {
      await _repository.cancelServiceRequest(event.bookingId);
      emit(const ServiceRequestCancelled());
    } catch (e) {
      emit(ServiceRequestError(e.toString()));
    }
  }
}
