part of 'emergency_map_bloc.dart';

abstract class EmergencyMapState {}

class EmergencyMapInitial extends EmergencyMapState {}

class EmergencyMapSearching extends EmergencyMapState {
  final double radiusKm;
  EmergencyMapSearching(this.radiusKm);
}

class EmergencyMapProvidersFound extends EmergencyMapState {
  /// Only the NEW providers from this radius search.
  /// The view layer accumulates them into _allProviders.
  final List<Map<String, dynamic>> notifiedProviders;
  final double radiusKm;
  final double latitude;
  final double longitude;
  final int bookingId;

  /// From API: data.waiting_window_seconds (e.g. 7200)
  final int? waitingWindowSeconds;

  EmergencyMapProvidersFound(
      this.notifiedProviders,
      this.radiusKm,
      this.latitude,
      this.longitude,
      this.bookingId, {
        this.waitingWindowSeconds,
      });
}

class EmergencyMapNoProviders extends EmergencyMapState {
  final double radiusKm;
  final double latitude;
  final double longitude;

  EmergencyMapNoProviders(this.radiusKm, this.latitude, this.longitude);
}

/// Emitted when a provider accepts the emergency booking.
/// Carries everything needed to open the tracking page directly.
class EmergencyMapBookingAccepted extends EmergencyMapState {
  final int bookingId;
  final double userLat;
  final double userLng;
  final String providerName;
  final String? providerPhone;
  final double? providerRating;

  EmergencyMapBookingAccepted({
    required this.bookingId,
    required this.userLat,
    required this.userLng,
    required this.providerName,
    this.providerPhone,
    this.providerRating,
  });
}

class EmergencyMapAllProvidersDeclined extends EmergencyMapState {}

class EmergencyMapBookingExpired extends EmergencyMapState {}

// Cancelling States
class EmergencyMapCancelling extends EmergencyMapState {}

class EmergencyMapCancelled extends EmergencyMapState {}

class EmergencyMapError extends EmergencyMapState {
  final String message;
  EmergencyMapError(this.message);
}