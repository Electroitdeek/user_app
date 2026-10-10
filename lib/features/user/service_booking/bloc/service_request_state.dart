part of 'service_request_bloc.dart';

abstract class ServiceRequestState extends Equatable {
  const ServiceRequestState();
  @override
  List<Object?> get props => [];
}

class ServiceRequestInitial extends ServiceRequestState {}

class ServiceRequestLoading extends ServiceRequestState {}

class ServiceRequestCreated extends ServiceRequestState {
  final Map<String, dynamic> response;
  const ServiceRequestCreated(this.response);
  @override
  List<Object?> get props => [response];
}

class ServiceRequestListLoaded extends ServiceRequestState {
  final List<ServiceRequestModel> requests;
  final int currentPage;
  final int lastPage;
  final int total;
  final String? activeStatus;
  final String? activeSearch;
  final bool isLoadingMore;

  const ServiceRequestListLoaded({
    required this.requests,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.activeStatus,
    this.activeSearch,
    this.isLoadingMore = false,
  });

  bool get hasMore => currentPage < lastPage;

  ServiceRequestListLoaded copyWith({
    List<ServiceRequestModel>? requests,
    int? currentPage,
    int? lastPage,
    int? total,
    String? activeStatus,
    bool clearStatus = false,
    String? activeSearch,
    bool clearSearch = false,
    bool? isLoadingMore,
  }) {
    return ServiceRequestListLoaded(
      requests: requests ?? this.requests,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      total: total ?? this.total,
      activeStatus: clearStatus ? null : (activeStatus ?? this.activeStatus),
      activeSearch: clearSearch ? null : (activeSearch ?? this.activeSearch),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [requests, currentPage, lastPage, total, activeStatus, activeSearch, isLoadingMore];
}

class ServiceRequestCancelled extends ServiceRequestState {
  const ServiceRequestCancelled();
  @override
  List<Object?> get props => [];
}

class ServiceRequestError extends ServiceRequestState {
  final String message;
  const ServiceRequestError(this.message);
  @override
  List<Object?> get props => [message];
}
