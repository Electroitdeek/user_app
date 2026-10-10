import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/features/user/service_booking/data/service_request_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'service_request_detail_event.dart';
part 'service_request_detail_state.dart';

class ServiceRequestDetailBloc extends Bloc<ServiceRequestDetailEvent, ServiceRequestDetailState> {
  final ServiceRequestRepository _repository;
  int? _bookingId;
  int? _requestId;

  ServiceRequestDetailBloc(this._repository) : super(ServiceRequestDetailInitial()) {
    on<LoadServiceRequestDetail>(_onLoad);
    on<RefreshServiceRequestDetail>(_onRefresh);
    on<CancelDetailServiceRequest>(_onCancel);
    on<CancelSubBlock>(_onCancelSubBlock);
  }

  Future<void> _onLoad(LoadServiceRequestDetail event, Emitter<ServiceRequestDetailState> emit) async {
    _bookingId = event.bookingId;
    _requestId = event.requestId;
    emit(ServiceRequestDetailLoading());
    await _fetch(emit);
  }

  Future<void> _onRefresh(RefreshServiceRequestDetail event, Emitter<ServiceRequestDetailState> emit) async {
    if (_bookingId == null && _requestId == null) return;
    // Keep last loaded state visible while refreshing
    emit(
      ServiceRequestDetailRefreshing(
        serviceRequest: state is ServiceRequestDetailLoaded
            ? (state as ServiceRequestDetailLoaded).serviceRequest
            : {},
        responses: state is ServiceRequestDetailLoaded ? (state as ServiceRequestDetailLoaded).responses : [],
      ),
    );
    await _fetch(emit);
  }

  Future<void> _onCancel(CancelDetailServiceRequest event, Emitter<ServiceRequestDetailState> emit) async {
    emit(ServiceRequestDetailLoading());
    try {
      final success = await _repository.cancelServiceRequest(event.requestId, reason: event.reason);
      if (success) {
        emit(ServiceRequestDetailCancelled());
        await _fetch(emit);
      } else {
        emit(ServiceRequestDetailError('Failed to cancel service request.'));
      }
    } catch (e) {
      emit(ServiceRequestDetailError(e.toString().replaceAll('Exception:', '').trim()));
    }
  }

  Future<void> _onCancelSubBlock(CancelSubBlock event, Emitter<ServiceRequestDetailState> emit) async {
    final current = state;
    if (current is ServiceRequestDetailLoaded) {
      emit(ServiceRequestDetailRefreshing(serviceRequest: current.serviceRequest, responses: current.responses));
    }
    try {
      if (_requestId == null) throw Exception('Request ID not available');
      await _repository.cancelSubBlock(_requestId!, event.subBlockId, reason: event.reason);
      emit(ServiceRequestSubBlockCancelled());
    } catch (e) {
      kPrintError('CancelSubBlock error: $e');
    }
    await _fetch(emit);
  }

  Future<void> _fetch(Emitter<ServiceRequestDetailState> emit) async {
    try {
      final res = await _repository.getServiceRequestDetails(requestId: _requestId, bookingId: _bookingId);
      if (res['status'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        final serviceRequest = data['service_request'] as Map<String, dynamic>?;
        final responses =
            (data['service_request_responses'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];

        if (serviceRequest != null) {
          emit(ServiceRequestDetailLoaded(serviceRequest: serviceRequest, responses: responses));
        } else {
          emit(ServiceRequestDetailError(res['message'] ?? 'Failed to load details.'));
        }
      } else {
        emit(ServiceRequestDetailError(res['message'] ?? 'Failed to load details.'));
      }
    } catch (e) {
      emit(ServiceRequestDetailError(e.toString().replaceAll('Exception:', '').trim()));
    }
  }
}
