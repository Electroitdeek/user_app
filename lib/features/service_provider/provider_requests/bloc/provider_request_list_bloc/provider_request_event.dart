part of 'provider_request_bloc.dart';

abstract class ProviderRequestEvent {
  const ProviderRequestEvent();
}

class LoadRequest extends ProviderRequestEvent {
  final String? status;
  final String? search;

  const LoadRequest({this.status, this.search});
}

class LoadMoreRequests extends ProviderRequestEvent {
  const LoadMoreRequests();
}

class FilterChanged extends ProviderRequestEvent {
  final String? status;

  const FilterChanged({this.status});
}

class SearchChanged extends ProviderRequestEvent {
  final String query;

  const SearchChanged({required this.query});
}

class RefreshRequests extends ProviderRequestEvent {
  const RefreshRequests();
}

class RespondToRequest extends ProviderRequestEvent {
  final int requestId;
  final String action;
  final List<int> subBlockIds;

  const RespondToRequest({required this.requestId, required this.action, this.subBlockIds = const []});
}
