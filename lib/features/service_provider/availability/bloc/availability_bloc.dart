import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repositories/availability_repository.dart';
import 'availability_event.dart';
import 'availability_state.dart';
import '../data/models/weekly_availability_model.dart';

class AvailabilityBloc extends Bloc<AvailabilityEvent, AvailabilityState> {
  final AvailabilityRepository repository;

  AvailabilityBloc(this.repository) : super(AvailabilityInitial()) {
    on<LoadAvailability>(_onLoadAvailability);
    on<ToggleDayStatus>(_onToggleDayStatus);
    on<ChangeTime>(_onChangeTime);
    on<AddSlot>(_onAddSlot);
    on<DeleteSlot>(_onDeleteSlot);
    on<ToggleSlotStatus>(_onToggleSlotStatus);
    on<SetBulkAvailability>(_onSetBulkAvailability);
    on<UpdateAvailability>(_onUpdateAvailability);
  }

  Future<void> _onLoadAvailability(
    LoadAvailability event,
    Emitter<AvailabilityState> emit,
  ) async {
    emit(AvailabilityLoading());
    try {
      final availability = await repository.getWeeklyAvailability();
      emit(AvailabilityLoaded(availability: availability));
    } catch (e) {
      emit(AvailabilityError(e.toString()));
    }
  }

  void _onToggleDayStatus(
    ToggleDayStatus event,
    Emitter<AvailabilityState> emit,
  ) {
    if (state is AvailabilityLoaded) {
      final loadedState = state as AvailabilityLoaded;
      final Map<String, List<DayAvailability>> newMap = {};
      loadedState.availability.availability.forEach((key, value) {
        newMap[key] = List<DayAvailability>.from(value);
      });
      
      final daySlots = newMap[event.dayName] ?? [];
      if (event.isActive) {
        if (daySlots.isEmpty) {
          daySlots.add(DayAvailability(
            dayOfWeek: event.dayName,
            startTime: '09:00:00',
            endTime: '21:00:00',
            isActive: true,
          ));
        } else {
          final hasActive = daySlots.any((s) => s.isActive);
          if (!hasActive) {
            daySlots[0] = daySlots[0].copyWith(isActive: true);
          }
        }
      } else {
        if (daySlots.isEmpty) {
          daySlots.add(DayAvailability(
            dayOfWeek: event.dayName,
            startTime: '09:00:00',
            endTime: '21:00:00',
            isActive: false,
          ));
        } else {
          for (int i = 0; i < daySlots.length; i++) {
            daySlots[i] = daySlots[i].copyWith(isActive: false);
          }
        }
      }
      
      newMap[event.dayName] = daySlots;
      emit(loadedState.copyWith(availability: WeeklyAvailability(availability: newMap)));
    }
  }

  void _onChangeTime(
    ChangeTime event,
    Emitter<AvailabilityState> emit,
  ) {
    if (state is AvailabilityLoaded) {
      final loadedState = state as AvailabilityLoaded;
      final Map<String, List<DayAvailability>> newMap = {};
      loadedState.availability.availability.forEach((key, value) {
        newMap[key] = List<DayAvailability>.from(value);
      });
      
      final daySlots = newMap[event.dayName] ?? [];
      if (event.slotIndex >= 0 && event.slotIndex < daySlots.length) {
        daySlots[event.slotIndex] = daySlots[event.slotIndex].copyWith(
          startTime: event.startTime,
          endTime: event.endTime,
        );
        newMap[event.dayName] = daySlots;
        emit(loadedState.copyWith(availability: WeeklyAvailability(availability: newMap)));
      }
    }
  }

  void _onAddSlot(
    AddSlot event,
    Emitter<AvailabilityState> emit,
  ) {
    if (state is AvailabilityLoaded) {
      final loadedState = state as AvailabilityLoaded;
      final Map<String, List<DayAvailability>> newMap = {};
      loadedState.availability.availability.forEach((key, value) {
        newMap[key] = List<DayAvailability>.from(value);
      });
      
      final daySlots = newMap[event.dayName] ?? [];
      
      // Calculate a default non-overlapping slot if possible
      String start = event.startTime ?? "09:00:00";
      String end = event.endTime ?? "17:00:00";
      
      if (event.startTime == null && event.endTime == null && daySlots.isNotEmpty) {
        final lastSlot = daySlots.last;
        final lastEndMin = WeeklyAvailability.timeToMinutes(lastSlot.endTime);
        if (lastEndMin + 60 < 1440) {
          final startH = (lastEndMin + 60) ~/ 60;
          final startM = (lastEndMin + 60) % 60;
          final endH = (startH + 4) > 23 ? 23 : (startH + 4);
          final endM = (startH + 4) > 23 ? 59 : startM;
          start = "${startH.toString().padLeft(2, '0')}:${startM.toString().padLeft(2, '0')}:00";
          end = "${endH.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')}:00";
        }
      }
      
      daySlots.add(DayAvailability(
        dayOfWeek: event.dayName,
        startTime: start,
        endTime: end,
        isActive: true,
      ));
      
      newMap[event.dayName] = daySlots;
      emit(loadedState.copyWith(availability: WeeklyAvailability(availability: newMap)));
    }
  }

  void _onDeleteSlot(
    DeleteSlot event,
    Emitter<AvailabilityState> emit,
  ) {
    if (state is AvailabilityLoaded) {
      final loadedState = state as AvailabilityLoaded;
      final Map<String, List<DayAvailability>> newMap = {};
      loadedState.availability.availability.forEach((key, value) {
        newMap[key] = List<DayAvailability>.from(value);
      });
      
      final daySlots = newMap[event.dayName] ?? [];
        if (event.slotIndex >= 0 && event.slotIndex < daySlots.length) {
        daySlots.removeAt(event.slotIndex);
        
        newMap[event.dayName] = daySlots;
        emit(loadedState.copyWith(availability: WeeklyAvailability(availability: newMap)));
      }
    }
  }

  void _onToggleSlotStatus(
    ToggleSlotStatus event,
    Emitter<AvailabilityState> emit,
  ) {
    if (state is AvailabilityLoaded) {
      final loadedState = state as AvailabilityLoaded;
      final Map<String, List<DayAvailability>> newMap = {};
      loadedState.availability.availability.forEach((key, value) {
        newMap[key] = List<DayAvailability>.from(value);
      });
      
      final daySlots = newMap[event.dayName] ?? [];
      if (event.slotIndex >= 0 && event.slotIndex < daySlots.length) {
        daySlots[event.slotIndex] = daySlots[event.slotIndex].copyWith(
          isActive: event.isActive,
        );
        newMap[event.dayName] = daySlots;
        emit(loadedState.copyWith(availability: WeeklyAvailability(availability: newMap)));
      }
    }
  }

  void _onSetBulkAvailability(
    SetBulkAvailability event,
    Emitter<AvailabilityState> emit,
  ) {
    if (state is AvailabilityLoaded) {
      final loadedState = state as AvailabilityLoaded;
      final Map<String, List<DayAvailability>> newMap = {};
      
      final days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      
      for (var day in days) {
        newMap[day] = [
          DayAvailability(
            dayOfWeek: day,
            startTime: event.startTime,
            endTime: event.endTime,
            isActive: true,
          )
        ];
      }
      
      emit(loadedState.copyWith(availability: WeeklyAvailability(availability: newMap)));
    }
  }

  Future<void> _onUpdateAvailability(
    UpdateAvailability event,
    Emitter<AvailabilityState> emit,
  ) async {
    if (state is AvailabilityLoaded) {
      final loadedState = state as AvailabilityLoaded;
      
      // Check validation before sending
      final validationError = loadedState.availability.validate();
      if (validationError != null) {
        emit(loadedState.copyWith(isUpdating: false, error: validationError));
        return;
      }

      emit(loadedState.copyWith(isUpdating: true));
      try {
        await repository.updateWeeklyAvailability(loadedState.availability);
        emit(AvailabilityUpdateSuccess());
        add(LoadAvailability());
      } catch (e) {
        emit(loadedState.copyWith(isUpdating: false, error: e.toString()));
      }
    }
  }
}
