import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Manages live location updates for emergency tracking via Firestore.
///
/// Firestore document path:
///   emergency_tracking/{bookingId}
///     → provider_lat, provider_lng, status, updated_at, provider_name, provider_id
///
/// Provider app writes to this path every ~4 seconds.
/// User app listens to real-time snapshots.
class EmergencyTrackingService {
  static final EmergencyTrackingService _instance =
  EmergencyTrackingService._internal();
  factory EmergencyTrackingService() => _instance;
  EmergencyTrackingService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _collection = 'emergency_tracking';

  // ─── User side: listen to provider location ───────────────────────────────

  /// Stream of [ProviderLocation] for a given booking.
  /// User app subscribes to this to move the map marker.
  Stream<ProviderLocation?> trackProvider(int bookingId) {
    return _db
        .collection(_collection)
        .doc(bookingId.toString())
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return ProviderLocation.fromMap(snap.data()!);
    });
  }

  // ─── Provider side: push location ─────────────────────────────────────────

  /// Called by Provider app every ~4 seconds with fresh GPS coordinates.
  Future<void> updateProviderLocation({
    required int bookingId,
    required double latitude,
    required double longitude,
    required int providerId,
    required String providerName,
    String status = 'on_the_way',
  }) async {
    await _db.collection(_collection).doc(bookingId.toString()).set({
      'provider_lat': latitude,
      'provider_lng': longitude,
      'provider_id': providerId,
      'provider_name': providerName,
      'status': status,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Mark service status: on_the_way | arrived | in_progress | completed
  Future<void> updateStatus({
    required int bookingId,
    required String status,
  }) async {
    await _db.collection(_collection).doc(bookingId.toString()).update({
      'status': status,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Clean up tracking doc when service is done (optional; keep for audit trail)
  Future<void> endTracking(int bookingId) async {
    await _db.collection(_collection).doc(bookingId.toString()).update({
      'status': 'completed',
      'ended_at': FieldValue.serverTimestamp(),
    });
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

class ProviderLocation {
  final double latitude;
  final double longitude;
  final int? providerId;
  final String providerName;
  final TrackingStatus status;
  final DateTime? updatedAt;

  const ProviderLocation({
    required this.latitude,
    required this.longitude,
    this.providerId,
    required this.providerName,
    required this.status,
    this.updatedAt,
  });

  factory ProviderLocation.fromMap(Map<String, dynamic> map) {
    return ProviderLocation(
      latitude: (map['provider_lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['provider_lng'] as num?)?.toDouble() ?? 0.0,
      providerId: map['provider_id'] as int?,
      providerName: map['provider_name']?.toString() ?? 'Partner',
      status: _parseStatus(map['status']?.toString()),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate(),
    );
  }

  static TrackingStatus _parseStatus(String? s) {
    switch (s) {
      case 'on_the_way':
        return TrackingStatus.onTheWay;
      case 'arrived':
        return TrackingStatus.arrived;
      case 'in_progress':
        return TrackingStatus.inProgress;
      case 'completed':
        return TrackingStatus.completed;
      default:
        return TrackingStatus.onTheWay;
    }
  }
}

enum TrackingStatus { onTheWay, arrived, inProgress, completed }

extension TrackingStatusX on TrackingStatus {
  String get label {
    switch (this) {
      case TrackingStatus.onTheWay:
        return 'Provider On the Way';
      case TrackingStatus.arrived:
        return 'Provider Arrived';
      case TrackingStatus.inProgress:
        return 'Service In Progress';
      case TrackingStatus.completed:
        return 'Service Completed';
    }
  }

  String get sublabel {
    switch (this) {
      case TrackingStatus.onTheWay:
        return 'Heading to your location';
      case TrackingStatus.arrived:
        return 'Service about to begin';
      case TrackingStatus.inProgress:
        return 'Your care is underway';
      case TrackingStatus.completed:
        return 'Rate your experience';
    }
  }

  int get stepIndex {
    switch (this) {
      case TrackingStatus.onTheWay:
        return 0;
      case TrackingStatus.arrived:
        return 1;
      case TrackingStatus.inProgress:
        return 2;
      case TrackingStatus.completed:
        return 3;
    }
  }
}