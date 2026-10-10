import 'package:equatable/equatable.dart';

abstract class AvailabilityEvent extends Equatable {
  const AvailabilityEvent();

  @override
  List<Object?> get props => [];
}

class LoadAvailability extends AvailabilityEvent {}

class UpdateAvailability extends AvailabilityEvent {}

class ToggleDayStatus extends AvailabilityEvent {
  final String dayName;
  final bool isActive;

  const ToggleDayStatus(this.dayName, this.isActive);

  @override
  List<Object?> get props => [dayName, isActive];
}

class ChangeTime extends AvailabilityEvent {
  final String dayName;
  final int slotIndex;
  final String startTime;
  final String endTime;

  const ChangeTime({
    required this.dayName,
    required this.slotIndex,
    required this.startTime,
    required this.endTime,
  });

  @override
  List<Object?> get props => [dayName, slotIndex, startTime, endTime];
}

class AddSlot extends AvailabilityEvent {
  final String dayName;
  final String? startTime;
  final String? endTime;

  const AddSlot(this.dayName, {this.startTime, this.endTime});

  @override
  List<Object?> get props => [dayName, startTime, endTime];
}

class DeleteSlot extends AvailabilityEvent {
  final String dayName;
  final int slotIndex;

  const DeleteSlot(this.dayName, this.slotIndex);

  @override
  List<Object?> get props => [dayName, slotIndex];
}

class ToggleSlotStatus extends AvailabilityEvent {
  final String dayName;
  final int slotIndex;
  final bool isActive;

  const ToggleSlotStatus({
    required this.dayName,
    required this.slotIndex,
    required this.isActive,
  });

  @override
  List<Object?> get props => [dayName, slotIndex, isActive];
}

class SetBulkAvailability extends AvailabilityEvent {
  final String startTime;
  final String endTime;

  const SetBulkAvailability({required this.startTime, required this.endTime});

  @override
  List<Object?> get props => [startTime, endTime];
}
