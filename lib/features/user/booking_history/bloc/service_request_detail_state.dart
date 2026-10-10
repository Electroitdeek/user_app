part of 'service_request_detail_bloc.dart';

abstract class ServiceRequestDetailState {}

class ServiceRequestDetailInitial extends ServiceRequestDetailState {}

class ServiceRequestDetailLoading extends ServiceRequestDetailState {}

/// Emitted during pull-to-refresh — carries old data so the UI stays visible.
class ServiceRequestDetailRefreshing extends ServiceRequestDetailState {
  final Map<String, dynamic> serviceRequest;
  final List<Map<String, dynamic>> responses;

  ServiceRequestDetailRefreshing({
    required this.serviceRequest,
    required this.responses,
  });
}

class ServiceRequestDetailLoaded extends ServiceRequestDetailState {
  final Map<String, dynamic> serviceRequest;
  final List<Map<String, dynamic>> responses;

  ServiceRequestDetailLoaded({
    required this.serviceRequest,
    required this.responses,
  });
}

class ServiceRequestDetailCancelled extends ServiceRequestDetailState {}

class ServiceRequestSubBlockCancelled extends ServiceRequestDetailState {}

class ServiceRequestDetailError extends ServiceRequestDetailState {
  final String message;
  ServiceRequestDetailError(this.message);
}
