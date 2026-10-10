import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/nearby_provider_repository.dart';
import '../model/nearby_provider_model.dart';

part 'nearby_provider_event.dart';
part 'nearby_provider_state.dart';

class NearbyProviderBloc extends Bloc<NearbyProviderEvent, NearbyProviderState> {
  final NearbyProviderRepository _repository;

  NearbyProviderBloc(this._repository) : super(NearbyProviderInitial()) {
    on<FindNearbyProviders>(_onFind);
    on<ExpandSearchRadius>(_onExpandRadius);
    on<AllProvidersDeclinedReceived>((event, emit) => emit(NearbyProviderAllDeclined()));
  }

  Future<void> _onFind(FindNearbyProviders event, Emitter<NearbyProviderState> emit) async {
    emit(NearbyProviderLoading());
    try {
      final providers = await _repository.findNearbyProviders(
        latitude: event.latitude,
        longitude: event.longitude,
        radiusKm: event.radiusKm,
        serviceCategoryId: event.serviceCategoryId,
        startDate: event.startDate,
        endDate: event.endDate,
        serviceType: event.serviceType,
        shiftType: event.shiftType,
      );
      emit(NearbyProviderLoaded(providers: providers, radiusKm: event.radiusKm));
    } catch (e) {
      emit(NearbyProviderError(e.toString()));
    }
  }

  Future<void> _onExpandRadius(ExpandSearchRadius event, Emitter<NearbyProviderState> emit) async {
    final currentState = state;
    if (currentState is! NearbyProviderLoaded) return;
    final newRadius = currentState.radiusKm + event.additionalKm;
    add(
      FindNearbyProviders(
        latitude: event.latitude,
        longitude: event.longitude,
        radiusKm: newRadius,
        serviceCategoryId: event.serviceCategoryId,
      ),
    );
  }
}
