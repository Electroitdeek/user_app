part of 'blood_request_bloc.dart';

abstract class BloodRequestState extends Equatable {
  const BloodRequestState();

  @override
  List<Object?> get props => [];
}

class BloodRequestInitial extends BloodRequestState {}

class BloodRequestLoading extends BloodRequestState {}

class BloodRequestLoaded extends BloodRequestState {
  final List<BloodRequest> requests;
  final List<BloodRequest> filteredRequests;

  const BloodRequestLoaded(this.requests, {List<BloodRequest>? filteredRequests})
      : filteredRequests = filteredRequests ?? requests;

  @override
  List<Object?> get props => [requests, filteredRequests];

  BloodRequestLoaded copyWith({
    List<BloodRequest>? requests,
    List<BloodRequest>? filteredRequests,
  }) {
    return BloodRequestLoaded(
      requests ?? this.requests,
      filteredRequests: filteredRequests ?? this.filteredRequests,
    );
  }
}

class BloodRequestSubmitting extends BloodRequestState {}

class BloodRequestSubmitSuccess extends BloodRequestState {
  final String message;

  const BloodRequestSubmitSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class BloodRequestError extends BloodRequestState {
  final String message;

  const BloodRequestError(this.message);

  @override
  List<Object?> get props => [message];
}