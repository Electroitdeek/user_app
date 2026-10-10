import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../service_booking/model/service_category_model.dart';
import '../../data/emergency_service_repository.dart';

part 'emergency_service_event.dart';
part 'emergency_service_state.dart';

class EmergencyServiceBloc extends Bloc<EmergencyServiceEvent, EmergencyServiceState> {
  final EmergencyServiceRepository _repository;

  EmergencyServiceBloc(this._repository) : super(EmergencyServiceInitial()) {
    on<LoadEmergencyServices>(_onLoadEmergencyServices);
  }

  Future<void> _onLoadEmergencyServices(
    LoadEmergencyServices event,
    Emitter<EmergencyServiceState> emit,
  ) async {
    emit(EmergencyServiceLoading());
    try {
      final services = await _repository.getEmergencyServices(city: event.city);
      emit(EmergencyServiceLoaded(services));
    } catch (e) {
      emit(EmergencyServiceError(e.toString()));
    }
  }
}
