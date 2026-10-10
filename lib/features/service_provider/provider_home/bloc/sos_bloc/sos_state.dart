import '../../data/models/sos_alert.dart';

abstract class SOSState {}

class SOSInitial extends SOSState {}

class SOSAlertActive extends SOSState {
  final SOSAlert alert;
  SOSAlertActive({required this.alert});
}

class SOSResponded extends SOSState {
  final String sosId;
  SOSResponded({required this.sosId});
}