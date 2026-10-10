import 'package:adhisaat_health_care/features/service_provider/provider_home/bloc/sos_bloc/sos_event.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_home/bloc/sos_bloc/sos_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/sos_alert.dart';

class SOSBloc extends Bloc<SOSEvent, SOSState> {
  SOSBloc() : super(SOSInitial()) {
    on<SOSAlertReceived>(_onSOSAlertReceived);
    on<RespondToSOS>(_onRespondToSOS);
  }

  Future<void> _onSOSAlertReceived(SOSAlertReceived event, Emitter<SOSState> emit) async {
    final alert = SOSAlert.fromJson(event.sosData);
    emit(SOSAlertActive(alert: alert));
  }

  Future<void> _onRespondToSOS(RespondToSOS event, Emitter<SOSState> emit) async {
    // Call API to respond
    // await _apiService.respondToSOS(event.sosId);

    emit(SOSResponded(sosId: event.sosId));
  }
}
