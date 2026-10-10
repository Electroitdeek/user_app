import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../di/locator.dart';
import '../../data/models/provider_service_request_model.dart';
import '../../data/repositories/provider_request_repository.dart';

part 'provider_request_event.dart';
part 'provider_request_state.dart';

class ProviderRequestBloc extends Bloc<ProviderRequestEvent, ProviderRequestState> {
  final _repository = locator<ProviderRequestRepository>();

  ProviderRequestBloc() : super(ProviderRequestInitial()) {
    on<LoadRequest>(_onLoad);
    on<LoadMoreRequests>(_onLoadMore);
    on<FilterChanged>(_onFilterChanged);
    on<SearchChanged>(_onSearchChanged);
    on<RefreshRequests>(_onRefresh);
    on<RespondToRequest>(_onRespond);
  }

  /// Map UI filter tab to booking_status values
  /// new_request → no booking_status (uses is_new_request=1)
  /// ongoing     → confirmed,in_progress
  /// past        → completed,cancelled
  String? _mapUiFilterToBackendStatus(String? uiStatus) {
    switch (uiStatus) {
      case 'new_request':
        return '';
      case 'ongoing':
        return 'confirmed,in_progress';
      case 'past':
        return 'completed,cancelled';
      default:
        return uiStatus;
    }
  }

  bool _isNewRequest(String status) => status == 'new_request';

  Future<void> _onLoad(LoadRequest event, Emitter<ProviderRequestState> emit) async {
    final status = event.status ?? 'new_request';
    emit(ProviderRequestLoading(currentStatus: status));
    try {
      final mappedStatus = _mapUiFilterToBackendStatus(status);
      final response = await _repository.getProviderServiceRequests(
        requestStatus: mappedStatus,
        search: event.search,
        page: 1,
        isNewRequest: _isNewRequest(status),
      );
      emit(
        ProviderRequestLoaded(
          requests: response.requests,
          pagination: response.pagination,
          currentStatus: status,
          currentSearch: event.search ?? '',
        ),
      );
    } catch (e) {
      kPrint(e);
      emit(ProviderRequestError(message: e.toString(), currentStatus: status));
    }
  }

  Future<void> _onLoadMore(LoadMoreRequests event, Emitter<ProviderRequestState> emit) async {
    if (state is! ProviderRequestLoaded) return;
    final current = state as ProviderRequestLoaded;
    if (!current.pagination.hasMore || current.isLoadingMore) return;

    emit(current.copyWith(isLoadingMore: true));
    try {
      final status = current.currentStatus.isNotEmpty ? current.currentStatus : null;
      final mappedStatus = _mapUiFilterToBackendStatus(
        current.currentStatus.isNotEmpty ? current.currentStatus : null,
      );
      final response = await _repository.getProviderServiceRequests(
        requestStatus: mappedStatus,
        search: current.currentSearch.isNotEmpty ? current.currentSearch : null,
        page: current.pagination.currentPage + 1,
        isNewRequest: _isNewRequest(status ?? ''),
      );
      emit(
        ProviderRequestLoaded(
          requests: [...current.requests, ...response.requests],
          pagination: response.pagination,
          currentStatus: current.currentStatus,
          currentSearch: current.currentSearch,
        ),
      );
    } catch (e) {
      emit(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onFilterChanged(FilterChanged event, Emitter<ProviderRequestState> emit) async {
    final search = state is ProviderRequestLoaded ? (state as ProviderRequestLoaded).currentSearch : '';
    add(LoadRequest(status: event.status ?? 'ongoing', search: search));
  }

  Future<void> _onSearchChanged(SearchChanged event, Emitter<ProviderRequestState> emit) async {
    final status = state.currentStatus;
    add(LoadRequest(status: status.isNotEmpty ? status : null, search: event.query));
  }

  Future<void> _onRefresh(RefreshRequests event, Emitter<ProviderRequestState> emit) async {
    final status = state.currentStatus;
    final search = state is ProviderRequestLoaded ? (state as ProviderRequestLoaded).currentSearch : '';
    add(LoadRequest(status: status.isNotEmpty ? status : 'new_request', search: search));
  }

  Future<void> _onRespond(RespondToRequest event, Emitter<ProviderRequestState> emit) async {
    final currentState = state;
    final status = currentState.currentStatus;
    if (currentState is! ProviderRequestLoaded) return;

    try {
      final result = await _repository.respondToServiceRequest(
          requestId: event.requestId, action: event.action, subBlockIds: event.subBlockIds);

      if (result.success) {
        emit(ProviderRequestActionSuccess(
            requestId: event.requestId, action: event.action, currentStatus: status));
        add(RefreshRequests());
      } else {
        emit(ProviderRequestActionFailure(
          message: result.message,
          errorType: result.errorType,
          conflictDates: result.conflictDates,
          currentStatus: status,
        ));
        add(RefreshRequests());
      }
    } catch (e) {
      emit(ProviderRequestActionFailure(
          message: e.toString().replaceAll('Exception: ', ''), currentStatus: status));
      add(RefreshRequests());
    }
  }
}
