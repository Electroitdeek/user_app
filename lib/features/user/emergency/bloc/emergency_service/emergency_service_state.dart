part of 'emergency_service_bloc.dart';

abstract class EmergencyServiceState {}

class EmergencyServiceInitial extends EmergencyServiceState {}

class EmergencyServiceLoading extends EmergencyServiceState {}

class EmergencyServiceLoaded extends EmergencyServiceState {
  final List<ServiceCategoryModel> services;

  EmergencyServiceLoaded(this.services);
}

class EmergencyServiceError extends EmergencyServiceState {
  final String message;

  EmergencyServiceError(this.message);
}
