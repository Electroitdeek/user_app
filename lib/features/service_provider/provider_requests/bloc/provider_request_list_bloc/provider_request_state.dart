part of 'provider_request_bloc.dart';

sealed class ProviderRequestState {
  final String currentStatus;
  const ProviderRequestState({this.currentStatus = 'upcoming'});
}

final class ProviderRequestInitial extends ProviderRequestState {
  const ProviderRequestInitial({super.currentStatus});
}

final class ProviderRequestLoading extends ProviderRequestState {
  const ProviderRequestLoading({super.currentStatus});
}

final class ProviderRequestLoaded extends ProviderRequestState {
  final List<ProviderServiceRequestModel> requests;
  final PaginationInfo pagination;
  final String currentSearch;
  final bool isLoadingMore;

  const ProviderRequestLoaded({
    required this.requests,
    required this.pagination,
    String? currentStatus,
    this.currentSearch = '',
    this.isLoadingMore = false,
  }) : super(currentStatus: currentStatus ?? 'upcoming');

  ProviderRequestLoaded copyWith({
    List<ProviderServiceRequestModel>? requests,
    PaginationInfo? pagination,
    String? currentStatus,
    String? currentSearch,
    bool? isLoadingMore,
  }) {
    return ProviderRequestLoaded(
      requests: requests ?? this.requests,
      pagination: pagination ?? this.pagination,
      currentStatus: currentStatus ?? this.currentStatus,
      currentSearch: currentSearch ?? this.currentSearch,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

final class ProviderRequestError extends ProviderRequestState {
  final String message;
  const ProviderRequestError({required this.message, super.currentStatus});
}

final class ProviderRequestActionSuccess extends ProviderRequestState {
  final int requestId;
  final String action;

  const ProviderRequestActionSuccess({
    required this.requestId,
    required this.action,
    super.currentStatus,
  });
}

final class ProviderRequestActionFailure extends ProviderRequestState {
  final String message;
  final String? errorType;
  final List<String> conflictDates;

  const ProviderRequestActionFailure({
    required this.message,
    this.errorType,
    this.conflictDates = const [],
    super.currentStatus,
  });
}
