import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../di/locator.dart';
import '../../../service_booking/data/service_request_repository.dart';
import '../../services/emergency_tracking_service.dart';

// ─── Events ───────────────────────────────────────────────────────────────────
abstract class EmergencyTrackingEvent {}

class StartTracking extends EmergencyTrackingEvent {
  final int requestId;

  StartTracking({required this.requestId});
}

class _LocationUpdated extends EmergencyTrackingEvent {
  final ProviderLocation? location;

  _LocationUpdated(this.location);
}

class StopTracking extends EmergencyTrackingEvent {}

// ─── States ───────────────────────────────────────────────────────────────────
abstract class EmergencyTrackingState {}

class EmergencyTrackingInitial extends EmergencyTrackingState {}

class EmergencyTrackingActive extends EmergencyTrackingState {
  final Map<String, dynamic> data;
  final ProviderLocation? providerLocation;

  EmergencyTrackingActive({required this.data, this.providerLocation});

  EmergencyTrackingActive copyWith({
    Map<String, dynamic>? data,
    ProviderLocation? providerLocation,
  }) {
    return EmergencyTrackingActive(
      data: data ?? this.data,
      providerLocation: providerLocation ?? this.providerLocation,
    );
  }
}

class EmergencyTrackingCompleted extends EmergencyTrackingState {}

class EmergencyTrackingError extends EmergencyTrackingState {
  final String message;

  EmergencyTrackingError(this.message);
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────
class EmergencyTrackingBloc
    extends Bloc<EmergencyTrackingEvent, EmergencyTrackingState> {
  final EmergencyTrackingService _service;
  StreamSubscription<ProviderLocation?>? _locationSub;

  EmergencyTrackingBloc(this._service) : super(EmergencyTrackingInitial()) {
    on<StartTracking>(_onStart);
    on<_LocationUpdated>(_onLocationUpdated);
    on<StopTracking>(_onStop);
  }

  Future<void> _onStart(
    StartTracking event,
    Emitter<EmergencyTrackingState> emit,
  ) async {
    try {
      // Fetch details first
      final repo = locator<ServiceRequestRepository>();
      final response = await repo.getServiceRequestDetails(
        requestId: event.requestId,
      );
      // Safe data extraction
      final dynamic responseData = response['data'];
      Map<String, dynamic> rawData = {};

      if (responseData is Map<String, dynamic>) {
        rawData = responseData;
      } else if (responseData is List && responseData.isNotEmpty) {
        rawData = responseData.first is Map<String, dynamic>
            ? responseData.first as Map<String, dynamic>
            : {};
      }

      // In some responses, the request details are inside a 'service_request' map
      final dynamic serviceRequest = rawData['service_request'];
      Map<String, dynamic> data = {};
      if (serviceRequest is Map<String, dynamic>) {
        data = serviceRequest;
      } else {
        data = rawData;
      }

      final dynamic bookingsData = data['bookings'];
      Map<String, dynamic>? booking;
      if (bookingsData is Map<String, dynamic>) {
        booking = bookingsData;
      } else if (bookingsData is List && bookingsData.isNotEmpty) {
        booking = bookingsData.first is Map<String, dynamic>
            ? bookingsData.first as Map<String, dynamic>
            : null;
      }

      final int bookingId = booking != null
          ? (int.tryParse(booking['service_request_id']?.toString() ?? '0') ??
              0)
          : 0;

      emit(EmergencyTrackingActive(data: data));

      // Cancel any existing subscription
      await _locationSub?.cancel();

      // Listen to Firestore real-time updates
      if (bookingId != 0) {
        _locationSub = _service
            .trackProvider(bookingId)
            .listen(
              (location) {
                add(_LocationUpdated(location));
              },
              onError: (e) {
                // Silently handle
              },
            );
      }
    } catch (e) {
      emit(EmergencyTrackingError('Failed to load tracking details: $e'));
    }
  }

  void _onLocationUpdated(
    _LocationUpdated event,
    Emitter<EmergencyTrackingState> emit,
  ) {
    final current = state;
    if (current is EmergencyTrackingActive) {
      emit(current.copyWith(providerLocation: event.location));

      // Auto-transition when completed
      if (event.location?.status == TrackingStatus.completed) {
        emit(EmergencyTrackingCompleted());
      }
    }
  }

  Future<void> _onStop(
    StopTracking event,
    Emitter<EmergencyTrackingState> emit,
  ) async {
    await _locationSub?.cancel();
    _locationSub = null;
  }

  @override
  Future<void> close() async {
    await _locationSub?.cancel();
    return super.close();
  }
}
