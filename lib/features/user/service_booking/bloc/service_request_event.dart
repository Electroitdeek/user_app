part of 'service_request_bloc.dart';

abstract class ServiceRequestEvent extends Equatable {
  const ServiceRequestEvent();
  @override
  List<Object?> get props => [];
}

class CreateServiceRequest extends ServiceRequestEvent {
  final BookingRequest request;
  const CreateServiceRequest(this.request);
  @override
  List<Object?> get props => [request];
}

/// Initial load or full refresh (resets page to 1, keeps current filters).
class LoadServiceRequests extends ServiceRequestEvent {
  final String? status;
  final String? search;
  final int perPage;
  const LoadServiceRequests({this.status, this.search, this.perPage = 10});
  @override
  List<Object?> get props => [status, search, perPage];
}

/// Appends the next page to the existing list.
class LoadMoreServiceRequests extends ServiceRequestEvent {
  final int page;
  final String? status;
  final String? search;
  final int perPage;
  const LoadMoreServiceRequests({required this.page, this.status, this.search, this.perPage = 10});
  @override
  List<Object?> get props => [page, status, search, perPage];
}

class CancelServiceRequest extends ServiceRequestEvent {
  final int bookingId;
  const CancelServiceRequest(this.bookingId);
  @override
  List<Object?> get props => [bookingId];
}
