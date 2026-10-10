part of 'provider_request_detail_bloc.dart';

abstract class ProviderRequestDetailState {}

class ProviderRequestDetailInitial extends ProviderRequestDetailState {}

class ProviderRequestDetailLoading extends ProviderRequestDetailState {}

class ProviderRequestDetailLoaded extends ProviderRequestDetailState {
  final ProviderServiceRequestModel request;

  ProviderRequestDetailLoaded({required this.request});
}

class ProviderRequestDetailError extends ProviderRequestDetailState {
  final String message;

  ProviderRequestDetailError({required this.message});
}

/// Emitted when the accept API returns status=true.
class ProviderRequestDetailAccepted extends ProviderRequestDetailState {
  final int requestId;
  final String message;

  ProviderRequestDetailAccepted({required this.requestId, required this.message});
}

/// Emitted when the accept API returns status=false with invalid_ids
/// (some slots already taken by another provider).
class ProviderRequestDetailConflict extends ProviderRequestDetailState {
  final String message;
  final List<int> invalidIds;

  ProviderRequestDetailConflict({required this.message, required this.invalidIds});
}

/// Emitted when accept API returns status=false — request gone or taken.
class ProviderRequestDetailUnavailable extends ProviderRequestDetailState {
  final String message;
  ProviderRequestDetailUnavailable({required this.message});
}

/// Emitted when accept API returns date_conflict error_type.
class ProviderRequestDetailDateConflict extends ProviderRequestDetailState {
  final String message;
  final List<String> conflictDates;
  ProviderRequestDetailDateConflict({required this.message, required this.conflictDates});
}

