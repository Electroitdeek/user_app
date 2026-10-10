part of 'emergency_map_bloc.dart';

abstract class EmergencyMapEvent {}

class SearchNearbyProviders extends EmergencyMapEvent {
  final ServiceCategoryModel serviceCategory;
  final double radiusKm;
  final bool isExpand;
  final int? selectedAddressId;
  final String? latitude;
  final String? longitude;
  final String? fullAddress;
  final int? familyMemberId;
  final String? familyMemberName;
  final String? instructions;

  SearchNearbyProviders({
    required this.serviceCategory,
    required this.radiusKm,
    this.isExpand = false,
    this.selectedAddressId,
    this.latitude,
    this.longitude,
    this.fullAddress,
    this.familyMemberId,
    this.familyMemberName,
    this.instructions,
  });
}

/// Fired when FCM push notification arrives saying a provider accepted.
/// Optionally carries provider info from the notification payload.
class BookingAcceptedNotificationReceived extends EmergencyMapEvent {
  final String? providerName;
  final String? providerPhone;
  final double? providerRating;

  BookingAcceptedNotificationReceived({
    this.providerName,
    this.providerPhone,
    this.providerRating,
  });
}

class AllProvidersDeclinedNotificationReceived extends EmergencyMapEvent {}

class CancelEmergencyRequest extends EmergencyMapEvent {}
class CheckEmergencyBookingStatus extends EmergencyMapEvent {}

class BookingExpiredNotificationReceived extends EmergencyMapEvent {}