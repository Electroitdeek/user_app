abstract class SOSEvent {}

class SOSAlertReceived extends SOSEvent {
  final Map<String, dynamic> sosData;
  SOSAlertReceived({required this.sosData});
}

class RespondToSOS extends SOSEvent {
  final String sosId;
  RespondToSOS({required this.sosId});
}