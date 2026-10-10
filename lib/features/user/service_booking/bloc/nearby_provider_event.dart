part of 'nearby_provider_bloc.dart';

abstract class NearbyProviderEvent extends Equatable {
  const NearbyProviderEvent();
  @override
  List<Object?> get props => [];
}

class FindNearbyProviders extends NearbyProviderEvent {
  final double latitude;
  final double longitude;
  final int radiusKm;
  final String serviceCategoryId;
  final String? startDate;
  final String? endDate;
  final String? serviceType;
  final String? shiftType;

  const FindNearbyProviders({
    required this.latitude,
    required this.longitude,
    this.radiusKm = 50,
    required this.serviceCategoryId,
    this.startDate,
    this.endDate,
    this.serviceType,
    this.shiftType,
  });

  @override
  List<Object?> get props => [
    latitude,
    longitude,
    radiusKm,
    serviceCategoryId,
    startDate,
    endDate,
    serviceType,
    shiftType,
  ];
}

class ExpandSearchRadius extends NearbyProviderEvent {
  final double latitude;
  final double longitude;
  final String serviceCategoryId;
  final int additionalKm;

  const ExpandSearchRadius({
    required this.latitude,
    required this.longitude,
    required this.serviceCategoryId,
    required this.additionalKm,
  });

  @override
  List<Object?> get props => [latitude, longitude, serviceCategoryId, additionalKm];
}

class AllProvidersDeclinedReceived extends NearbyProviderEvent {
  const AllProvidersDeclinedReceived();
}
