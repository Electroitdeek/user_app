import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/provider_service_request_model.dart';
import '../../data/repositories/provider_request_repository.dart';

part 'provider_request_detail_event.dart';
part 'provider_request_detail_state.dart';

class ProviderRequestDetailBloc extends Bloc<ProviderRequestDetailEvent, ProviderRequestDetailState> {
  final ProviderRequestRepository repository;
  int? _lastRequestId;
  int? _lastBookingId;

  ProviderRequestDetailBloc({required this.repository}) : super(ProviderRequestDetailInitial()) {
    on<LoadProviderRequestDetail>(_onLoad);
    on<RefreshProviderRequestDetail>(_onRefresh);
    on<AcceptProviderRequest>(_onAccept);
    on<RejectProviderRequest>(_onReject);
    on<StartServiceRequest>(_onStartService);
  }

  Future<void> _onStartService(
    StartServiceRequest event,
    Emitter<ProviderRequestDetailState> emit,
  ) async {
    try {
      await repository.startServiceRequest(
        requestId: event.requestId,
        checkinLatitude: event.checkinLatitude,
        checkinLongitude: event.checkinLongitude,
      );
      add(RefreshProviderRequestDetail());
    } catch (e) {
      kPrint(e);
      emit(ProviderRequestDetailError(message: e.toString()));
    }
  }

  Future<void> _onAccept(
    AcceptProviderRequest event,
    Emitter<ProviderRequestDetailState> emit,
  ) async {
    try {
      final result = await repository.respondToServiceRequest(
        requestId: event.requestId,
        action: 'accepted',
        subBlockIds: event.subBlockIds,
      );
      if (result.success) {
        emit(ProviderRequestDetailAccepted(
          requestId: event.requestId,
          message: result.message,
        ));
      } else if (result.isDateConflict) {
        emit(ProviderRequestDetailDateConflict(
          message: result.message,
          conflictDates: result.conflictDates,
        ));
      } else if (result.hasPartialConflict) {
        emit(ProviderRequestDetailConflict(
          message: result.message,
          invalidIds: result.invalidIds,
        ));
      } else {
        emit(ProviderRequestDetailUnavailable(message: result.message));
      }
    } catch (e) {
      kPrint(e);
      emit(ProviderRequestDetailError(message: e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onReject(
    RejectProviderRequest event,
    Emitter<ProviderRequestDetailState> emit,
  ) async {
    try {
      await repository.respondToServiceRequest(requestId: event.requestId, action: 'rejected');
      add(RefreshProviderRequestDetail());
    } catch (e) {
      kPrint(e);
      emit(ProviderRequestDetailError(message: e.toString()));
    }
  }

  Future<void> _onLoad(
    LoadProviderRequestDetail event,
    Emitter<ProviderRequestDetailState> emit,
  ) async {
    _lastRequestId = event.requestId;
    _lastBookingId = event.bookingId;
    
    emit(ProviderRequestDetailLoading());
    try {
      final request = await repository.getRequestDetails(requestId: event.requestId, bookingId: event.bookingId);
      if (request != null) {
        emit(ProviderRequestDetailLoaded(request: request));
      } else {
        emit(ProviderRequestDetailError(message: "Request not found"));
      }
    } catch (e) {
      kPrint(e);
      emit(ProviderRequestDetailError(message: e.toString()));
    }
  }

  Future<void> _onRefresh(
    RefreshProviderRequestDetail event,
    Emitter<ProviderRequestDetailState> emit,
  ) async {
    if (_lastRequestId == null && _lastBookingId == null) return;
    
    try {
      final request = await repository.getRequestDetails(requestId: _lastRequestId, bookingId: _lastBookingId);
      if (request != null) {
        emit(ProviderRequestDetailLoaded(request: request));
      }
    } catch (e) {
      kPrint(e);
      // Don't emit error on refresh if we already have data? 
      // Actually standard is usually fine.
    }
  }
}
