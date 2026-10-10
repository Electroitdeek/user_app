part of 'nearby_provider_bloc.dart';

abstract class NearbyProviderState extends Equatable {
  const NearbyProviderState();
  @override
  List<Object?> get props => [];
}

class NearbyProviderInitial extends NearbyProviderState {}

class NearbyProviderLoading extends NearbyProviderState {}

class NearbyProviderLoaded extends NearbyProviderState {
  final List<NearbyProviderModel> providers;
  final int radiusKm;

  const NearbyProviderLoaded({required this.providers, required this.radiusKm});

  @override
  List<Object?> get props => [providers, radiusKm];
}

class NearbyProviderError extends NearbyProviderState {
  final String message;
  const NearbyProviderError(this.message);
  @override
  List<Object?> get props => [message];
}

class NearbyProviderAllDeclined extends NearbyProviderState {}
