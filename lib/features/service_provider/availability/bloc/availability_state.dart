import 'package:equatable/equatable.dart';
import '../data/models/weekly_availability_model.dart';

abstract class AvailabilityState extends Equatable {
  const AvailabilityState();

  @override
  List<Object?> get props => [];
}

class AvailabilityInitial extends AvailabilityState {}

class AvailabilityLoading extends AvailabilityState {}

class AvailabilityLoaded extends AvailabilityState {
  final WeeklyAvailability availability;
  final bool isUpdating;
  final String? error;

  const AvailabilityLoaded({
    required this.availability,
    this.isUpdating = false,
    this.error,
  });

  AvailabilityLoaded copyWith({
    WeeklyAvailability? availability,
    bool? isUpdating,
    String? error,
  }) {
    return AvailabilityLoaded(
      availability: availability ?? this.availability,
      isUpdating: isUpdating ?? this.isUpdating,
      error: error,
    );
  }

  @override
  List<Object?> get props => [availability, isUpdating, error];
}

class AvailabilityUpdateSuccess extends AvailabilityState {}

class AvailabilityError extends AvailabilityState {
  final String message;

  const AvailabilityError(this.message);

  @override
  List<Object?> get props => [message];
}
