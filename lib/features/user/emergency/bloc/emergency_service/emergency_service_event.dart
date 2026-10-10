part of 'emergency_service_bloc.dart';

abstract class EmergencyServiceEvent {}

class LoadEmergencyServices extends EmergencyServiceEvent {
  final String city;

  LoadEmergencyServices({required this.city});
}
