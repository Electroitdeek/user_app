import 'dart:async';


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';


import '../../../../../core/services/location_service.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class ProviderTrackingEvent {}

/// Start broadcasting GPS to Firestore for this booking.
class StartProviderTracking extends ProviderTrackingEvent {
  final int bookingId;
  final int providerId;
  final String providerName;

  StartProviderTracking({required this.bookingId, required this.providerId, required this.providerName});
}

/// Change the service status label (on_the_way → arrived → in_progress → completed).
class UpdateTrackingStatus extends ProviderTrackingEvent {
  final String status; // 'on_the_way' | 'arrived' | 'in_progress' | 'completed'
  UpdateTrackingStatus(this.status);
}

/// Stop broadcasting (service done / cancelled).
class StopProviderTracking extends ProviderTrackingEvent {}

/// Pause broadcasting (app in background).
class PauseProviderTracking extends ProviderTrackingEvent {}

/// Resume broadcasting (app in foreground).
class ResumeProviderTracking extends ProviderTrackingEvent {}

class _GpsTickEvent extends ProviderTrackingEvent {
  final Position position;

  _GpsTickEvent(this.position);
}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class ProviderTrackingState {}

class ProviderTrackingIdle extends ProviderTrackingState {}

class ProviderTrackingActive extends ProviderTrackingState {
  final int bookingId;
  final double lat;
  final double lng;
  final double heading;
  final String status;

  ProviderTrackingActive({
    required this.bookingId,
    required this.lat,
    required this.lng,
    required this.status,
    this.heading = 0,
  });

  ProviderTrackingActive copyWith({
    double? lat,
    double? lng,
    double? heading,
    String? status,
  }) {
    return ProviderTrackingActive(
      bookingId: bookingId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      heading: heading ?? this.heading,
      status: status ?? this.status,
    );
  }
}

class ProviderTrackingError extends ProviderTrackingState {
  final String message;

  ProviderTrackingError(this.message);
}

class ProviderTrackingCompleted extends ProviderTrackingState {}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class ProviderTrackingBloc extends Bloc<ProviderTrackingEvent, ProviderTrackingState> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _collection = 'emergency_tracking';
  static const _intervalSeconds = 4; // status sync interval

  StreamSubscription<Position>? _gpsSub;
  Timer? _pushTimer;

  double? _lastLat;
  double? _lastLng;

  int? _bookingId;
  int? _providerId;
  String? _providerName;

  ProviderTrackingBloc() : super(ProviderTrackingIdle()) {
    on<StartProviderTracking>(_onStart);
    on<UpdateTrackingStatus>(_onUpdateStatus);
    on<StopProviderTracking>(_onStop);
    on<PauseProviderTracking>(_onPause);
    on<ResumeProviderTracking>(_onResume);
    on<_GpsTickEvent>(_onGpsTick);
  }

  // ─── Start ──────────────────────────────────────────────────────────────────

  Future<void> _onStart(StartProviderTracking event, Emitter<ProviderTrackingState> emit) async {
    _bookingId = event.bookingId;
    _providerId = event.providerId;
    _providerName = event.providerName;

    // Get initial position immediately
    final locationService = LocationService();
    final initial = await locationService.getCurrentLocation();

    if (!initial.isSuccess || initial.position == null) {
      emit(ProviderTrackingError('Could not get GPS location. Please enable location.'));
      return;
    }

    _lastLat = initial.position!.latitude;
    _lastLng = initial.position!.longitude;

    // Write initial doc to Firestore right away
    await _pushToFirestore(lat: _lastLat!, lng: _lastLng!, status: 'on_the_way');

    emit(
      ProviderTrackingActive(
        bookingId: event.bookingId,
        lat: _lastLat!,
        lng: _lastLng!,
        status: 'on_the_way',
        heading: initial.position!.heading,
      ),
    );

    await _startSubscriptions('on_the_way');
  }

  // ─── GPS tick ───────────────────────────────────────────────────────────────

  void _onGpsTick(_GpsTickEvent event, Emitter<ProviderTrackingState> emit) {
    if (state is! ProviderTrackingActive) return;

    final current = state as ProviderTrackingActive;
    _lastLat = event.position.latitude;
    _lastLng = event.position.longitude;

    // Update map in UI immediately (Firestore push is handled by timer)
    emit(
      current.copyWith(
        lat: _lastLat,
        lng: _lastLng,
        heading: event.position.heading,
      ),
    );
  }

  // ─── Status update ──────────────────────────────────────────────────────────

  Future<void> _onUpdateStatus(UpdateTrackingStatus event, Emitter<ProviderTrackingState> emit) async {
    if (state is! ProviderTrackingActive) return;

    final current = state as ProviderTrackingActive;
    emit(current.copyWith(status: event.status));

    // Push updated status to Firestore immediately
    if (_lastLat != null && _lastLng != null) {
      await _pushToFirestore(lat: _lastLat!, lng: _lastLng!, status: event.status);
    }

    // If completed → stop tracking
    if (event.status == 'completed') {
      await _cancelSubscriptions();
      emit(ProviderTrackingCompleted());
    }
  }

  // ─── Stop ───────────────────────────────────────────────────────────────────

  Future<void> _onStop(StopProviderTracking event, Emitter<ProviderTrackingState> emit) async {
    await _cancelSubscriptions();
    emit(ProviderTrackingIdle());
  }

  // ─── Pause / Resume ────────────────────────────────────────────────────────

  Future<void> _onPause(PauseProviderTracking event, Emitter<ProviderTrackingState> emit) async {
    await _cancelSubscriptions();
  }

  Future<void> _onResume(ResumeProviderTracking event, Emitter<ProviderTrackingState> emit) async {
    if (state is! ProviderTrackingActive) return;

    final current = state as ProviderTrackingActive;
    await _startSubscriptions(current.status);
  }

  Future<void> _startSubscriptions(String status) async {
    await _cancelSubscriptions();

    final locationService = LocationService();

    // Subscribe to live GPS stream
    _gpsSub = locationService
        .getLocationStream(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        )
        .listen((pos) => add(_GpsTickEvent(pos)));

    // Push on timer
    _pushTimer = Timer.periodic(const Duration(seconds: _intervalSeconds), (_) {
      if (_lastLat != null && _lastLng != null) {
        _pushToFirestore(lat: _lastLat!, lng: _lastLng!, status: status);
      }
    });
  }

  // ─── Firestore write ────────────────────────────────────────────────────────

  Future<void> _pushToFirestore({required double lat, required double lng, required String status}) async {
    if (_bookingId == null) return;

    try {
      await _db.collection(_collection).doc(_bookingId.toString()).set({
        'booking_id': _bookingId,
        'provider_id': _providerId,
        'provider_name': _providerName,
        'provider_lat': lat,
        'provider_lng': lng,
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // ignore
    }
  }

  Future<void> _cancelSubscriptions() async {
    await _gpsSub?.cancel();
    _gpsSub = null;
    _pushTimer?.cancel();
    _pushTimer = null;
  }

  @override
  Future<void> close() async {
    await _cancelSubscriptions();
    return super.close();
  }
}
