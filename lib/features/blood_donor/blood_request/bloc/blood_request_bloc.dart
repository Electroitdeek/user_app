import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/repositories/blood_donation_repository.dart';
import '../data/model/blood_request_model.dart';

part 'blood_request_event.dart';
part 'blood_request_state.dart';

class BloodRequestBloc extends Bloc<BloodRequestEvent, BloodRequestState> {
  final BloodDonationRepository repository;

  BloodRequestBloc(this.repository) : super(BloodRequestInitial()) {
    on<LoadBloodRequests>(_onLoadBloodRequests);
    on<AddBloodRequest>(_onAddBloodRequest);
    on<UpdateBloodRequest>(_onUpdateBloodRequest);
    on<FilterBloodRequests>(_onFilterBloodRequests);
  }

  Future<void> _onLoadBloodRequests(LoadBloodRequests event, Emitter<BloodRequestState> emit) async {
    emit(BloodRequestLoading());
    try {
      final requests = await repository.getBloodRequests(
        bloodGroup: event.bloodGroup,
        city: event.city,
        urgency: event.urgency,
        requestStatus: event.requestStatus,
        sortField: event.sortField,
      );
      emit(BloodRequestLoaded(requests));
    } catch (e) {
      emit(BloodRequestError(e.toString()));
    }
  }

  Future<void> _onAddBloodRequest(AddBloodRequest event, Emitter<BloodRequestState> emit) async {
    emit(BloodRequestSubmitting());
    try {
      await repository.addOrUpdateBloodRequest(event.request);
      emit(const BloodRequestSubmitSuccess('Blood request submitted successfully'));
    } catch (e) {
      emit(BloodRequestError(e.toString()));
    }
  }

  Future<void> _onUpdateBloodRequest(UpdateBloodRequest event, Emitter<BloodRequestState> emit) async {
    emit(BloodRequestSubmitting());
    try {
      await repository.addOrUpdateBloodRequest(event.request);
      emit(const BloodRequestSubmitSuccess('Blood request updated successfully'));
    } catch (e) {
      emit(BloodRequestError(e.toString()));
    }
  }

  Future<void> _onFilterBloodRequests(FilterBloodRequests event, Emitter<BloodRequestState> emit) async {
    final currentState = state;
    if (currentState is BloodRequestLoaded) {
      List<BloodRequest> filtered = currentState.requests;

      if (event.bloodGroup != null && event.bloodGroup!.isNotEmpty) {
        filtered = filtered.where((r) => r.bloodGroupRequired == event.bloodGroup).toList();
      }

      if (event.urgency != null && event.urgency!.isNotEmpty) {
        filtered = filtered.where((r) => r.urgencyLevel == event.urgency).toList();
      }

      emit(currentState.copyWith(filteredRequests: filtered));
    }
  }
}
