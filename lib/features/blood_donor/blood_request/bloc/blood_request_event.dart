part of 'blood_request_bloc.dart';

abstract class BloodRequestEvent extends Equatable {
  const BloodRequestEvent();

  @override
  List<Object?> get props => [];
}

class LoadBloodRequests extends BloodRequestEvent {
  final String token;
  final String? bloodGroup;
  final String? city;
  final String? urgency;
  final String? requestStatus;
  final String? sortField;

  const LoadBloodRequests({
    required this.token,
    this.bloodGroup,
    this.city,
    this.urgency,
    this.requestStatus,
    this.sortField,
  });

  @override
  List<Object?> get props => [token, bloodGroup, city, urgency, requestStatus, sortField];
}

class AddBloodRequest extends BloodRequestEvent {
  final String token;
  final BloodRequest request;

  const AddBloodRequest(this.token, this.request);

  @override
  List<Object?> get props => [token, request];
}

class UpdateBloodRequest extends BloodRequestEvent {
  final String token;
  final BloodRequest request;

  const UpdateBloodRequest(this.token, this.request);

  @override
  List<Object?> get props => [token, request];
}

class FilterBloodRequests extends BloodRequestEvent {
  final String? bloodGroup;
  final String? urgency;

  const FilterBloodRequests({this.bloodGroup, this.urgency});

  @override
  List<Object?> get props => [bloodGroup, urgency];
}
