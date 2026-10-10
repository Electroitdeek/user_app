// BLoC Events
import 'package:adhisaat_health_care/data/models/user_profile_model.dart';

import '../../data/models/service_request.dart';

abstract class ProviderDashboardEvent {}

class LoadProviderDashboard extends ProviderDashboardEvent {
  final bool forceRefresh;

  LoadProviderDashboard({this.forceRefresh = false});
}

class UpdateProfileData extends ProviderDashboardEvent {
  final UserProfileModel profile;

  UpdateProfileData(this.profile);
}

class RefreshDashboardEvent extends ProviderDashboardEvent {}

class ToggleAvailabilityEvent extends ProviderDashboardEvent {
  final bool isOnline;

  ToggleAvailabilityEvent({required this.isOnline});
}

class NewRequestReceivedEvent extends ProviderDashboardEvent {
  // final ServiceRequest request;
  final Map<String, dynamic> requestData;

  NewRequestReceivedEvent({required this.requestData});
}

class AcceptRequestEvent extends ProviderDashboardEvent {
  final String requestId;
  /// Full ServiceRequest so the bloc can emit it back in RequestAccepted
  /// and the home page can navigate with all data.
  final ServiceRequest request;

  AcceptRequestEvent({required this.requestId, required this.request});
}

/// Fired when the provider taps ACCEPT on the system notification
/// (background / killed state). The bloc fetches full request details
/// from the API before emitting [RequestAccepted].
class AcceptFromNotificationEvent extends ProviderDashboardEvent {
  final String requestId;
  final bool isEmergency;
  final Map<String, String?> payload;

  AcceptFromNotificationEvent({
    required this.requestId,
    required this.isEmergency,
    required this.payload,
  });
}

class RejectRequestEvent extends ProviderDashboardEvent {
  final String requestId;

  RejectRequestEvent({required this.requestId});
}

class WaitingPeriodEndedEvent extends ProviderDashboardEvent {
  final List<ServiceRequest> acceptedRequests;

  WaitingPeriodEndedEvent({required this.acceptedRequests});
}

class SelectRequestEvent extends ProviderDashboardEvent {
  final String requestId;

  SelectRequestEvent({required this.requestId});
}

class RequestExpiredEvent extends ProviderDashboardEvent {
  final String requestId;

  RequestExpiredEvent({required this.requestId});
}