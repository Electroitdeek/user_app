import 'package:adhisaat_health_care/data/models/user_profile_model.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/models/provider_service_request_model.dart';

import '../../data/models/provider_dashboard.dart';
import '../../data/models/service_request.dart';

enum ProviderStatus { offline, available, onDuty }

// BLoC States
abstract class ProviderDashboardState {}

class ProviderDashboardInitial extends ProviderDashboardState {}

class ProviderDashboardLoading extends ProviderDashboardState {
  final UserProfileModel? cachedProfile; // Show cached data while loading

  ProviderDashboardLoading({this.cachedProfile});
}

class ProviderDashboardLoaded extends ProviderDashboardState {
  final UserProfileModel profile;
  final ProviderDashboard dashboard;
  final bool locationUpdated;

  final bool isOnline;
  final int unreadNotifications;
  final String? heatmapAlert;
  final List<ServiceRequest> upcomingServices;
  final ServiceRequest? incomingRequest;
  final List<ServiceRequest>? multipleRequests;
  final List<ProviderServiceRequestModel> recentRequests;

  ProviderDashboardLoaded({
    required this.isOnline,
    required this.unreadNotifications,
    this.heatmapAlert,
    required this.upcomingServices,
    this.incomingRequest,
    this.multipleRequests,
    required this.profile,
    required this.dashboard,
    required this.locationUpdated,
    this.recentRequests = const [],
  });

  ProviderDashboardLoaded copyWith({
    bool? isOnline,
    int? unreadNotifications,
    String? heatmapAlert,
    List<ServiceRequest>? upcomingServices,
    ServiceRequest? incomingRequest,
    List<ServiceRequest>? multipleRequests,
    bool clearIncomingRequest = false,
    bool clearMultipleRequests = false,
    UserProfileModel? profile,
    ProviderDashboard? dashboard,
    bool? locationUpdated = false,
    List<ProviderServiceRequestModel>? recentRequests,
  }) {
    return ProviderDashboardLoaded(
      isOnline: isOnline ?? this.isOnline,
      unreadNotifications: unreadNotifications ?? this.unreadNotifications,
      heatmapAlert: heatmapAlert ?? this.heatmapAlert,
      upcomingServices: upcomingServices ?? this.upcomingServices,
      incomingRequest: clearIncomingRequest ? null : (incomingRequest ?? this.incomingRequest),
      multipleRequests: clearMultipleRequests ? null : (multipleRequests ?? this.multipleRequests),
      profile: profile ?? this.profile,
      dashboard: dashboard ?? this.dashboard,
      locationUpdated: locationUpdated ?? this.locationUpdated,
      recentRequests: recentRequests ?? this.recentRequests,
    );
  }
}

class ProviderDashboardError extends ProviderDashboardState {
  final String message;
  final UserProfileModel? cachedProfile; // Show cached data even on error
  final ProviderDashboardLoaded? dashboardData;

  ProviderDashboardError({required this.message, this.cachedProfile, this.dashboardData});
}


class ShowIncomingRequestState extends ProviderDashboardState {
  final ServiceRequest request;

  ShowIncomingRequestState({required this.request});
}

class ShowMultipleRequestsState extends ProviderDashboardState {
  final List<ServiceRequest> requests;

  ShowMultipleRequestsState({required this.requests});
}

class NewRequestReceived extends ProviderDashboardState {
  final ServiceRequest request;
  final ProviderDashboardLoaded? dashboardData;

  NewRequestReceived({required this.request, this.dashboardData});
}


class RequestExpired extends ProviderDashboardState {
  final String requestId;
  final ProviderDashboardLoaded? dashboardData;

  RequestExpired({required this.requestId, this.dashboardData});
}


class RequestAccepted extends ProviderDashboardState {
  final String requestId;

  /// Full request is passed so the home page can navigate to the
  /// provider-side tracking page with all required data.
  final ServiceRequest request;
  final ProviderDashboardLoaded? dashboardData;

  RequestAccepted({
    required this.requestId,
    required this.request,
    this.dashboardData,
  });
}

class AcceptDateConflict extends ProviderDashboardState {
  final String message;
  final List<String> conflictDates;
  final ProviderDashboardLoaded? dashboardData;

  AcceptDateConflict({
    required this.message,
    required this.conflictDates,
    this.dashboardData,
  });
}