import 'dart:async';

import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../api/api_client.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() => _instance;

  LocationService._internal();

  Position? _lastKnownPosition;
  DateTime? _lastUpdateTime;

  // ==================== PERMISSION HANDLING ====================

  /// Check if location permission is granted
  Future<bool> isLocationPermissionGranted() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  /// Get current permission status
  Future<LocationPermission> getPermissionStatus() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission with proper flow
  Future<LocationPermissionResult> requestLocationPermission() async {
    // Check if location service is enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionResult(
        isGranted: false,
        status: LocationPermission.denied,
        message: 'Location services are disabled. Please enable them in settings.',
        shouldOpenSettings: true,
      );
    }

    // Check current permission
    LocationPermission permission = await Geolocator.checkPermission();

    // Already granted
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      return LocationPermissionResult(isGranted: true, status: permission, message: 'Location permission granted');
    }

    // Permission denied forever
    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionResult(
        isGranted: false,
        status: permission,
        message: 'Location permission permanently denied. Please enable in settings.',
        shouldOpenSettings: true,
      );
    }

    // Request permission
    permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied) {
      return LocationPermissionResult(
        isGranted: false,
        status: permission,
        message: 'Location permission denied',
        shouldOpenSettings: false,
      );
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionResult(
        isGranted: false,
        status: permission,
        message: 'Location permission permanently denied. Please enable in settings.',
        shouldOpenSettings: true,
      );
    }

    return LocationPermissionResult(isGranted: true, status: permission, message: 'Location permission granted');
  }

  /// Open app settings for manual permission enable
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    return await ph.openAppSettings();
  }

  // ==================== LOCATION FETCHING ====================

  /// Get current position with error handling
  Future<LocationResult> getCurrentLocation({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 15),
    bool forceRefresh = false,
    bool requestPermission = true,
  }) async {
    try {
      // Check permission first
      if (requestPermission) {
        final permissionResult = await requestLocationPermission();
        if (!permissionResult.isGranted) {
          return LocationResult.error(
            message: permissionResult.message,
            shouldOpenSettings: permissionResult.shouldOpenSettings,
          );
        }
      } else {
        // Only check current status, don't request
        final granted = await isLocationPermissionGranted();
        if (!granted) {
          return LocationResult.error(message: 'Location permission not granted');
        }
      }

      // Return cached location if available and not force refresh
      if (!forceRefresh && _lastKnownPosition != null && _lastUpdateTime != null) {
        final diff = DateTime.now().difference(_lastUpdateTime!);
        if (diff.inMinutes < 5) {
          // Cache for 5 minutes
          return LocationResult.success(_lastKnownPosition!);
        }
      }

      // Get fresh location
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy),
      ).timeout(timeout);

      _lastKnownPosition = position;
      _lastUpdateTime = DateTime.now();

      return LocationResult.success(position);
    } on TimeoutException {
      return LocationResult.error(message: 'Location request timed out. Please try again.');
    } catch (e) {
      return LocationResult.error(message: 'Failed to get location: ${e.toString()}');
    }
  }

  /// Get last known position (from cache)
  Position? getLastKnownPosition() {
    return _lastKnownPosition;
  }

  /// Calculate distance between two coordinates (in meters)
  double calculateDistance({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(startLatitude, startLongitude, endLatitude, endLongitude);
  }

  /// Calculate distance from current location
  Future<DistanceResult> getDistanceFromCurrentLocation({
    required double targetLatitude,
    required double targetLongitude,
  }) async {
    final locationResult = await getCurrentLocation();

    if (!locationResult.isSuccess || locationResult.position == null) {
      return DistanceResult(distance: null, formattedDistance: null, error: locationResult.message);
    }

    final distance = calculateDistance(
      startLatitude: locationResult.position!.latitude,
      startLongitude: locationResult.position!.longitude,
      endLatitude: targetLatitude,
      endLongitude: targetLongitude,
    );

    return DistanceResult(distance: distance, formattedDistance: _formatDistance(distance));
  }

  Future<Position?> getLocationPosition({bool requestPermission = true}) async {
    final result = await getCurrentLocation(requestPermission: requestPermission);

    if (result.isSuccess && result.position != null) {
      kPrint("Location fetched successfully!");
      return result.position;
    } else {
      kPrint(result.message);
    }
    return null;
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
  }

  // ==================== LOCATION STREAMING ====================

  /// Stream location updates (for live tracking)
  Stream<Position> getLocationStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10, // Update every 10 meters
  }) {
    final locationSettings = LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  // ==================== GEOCODING ====================

  /// Get address from coordinates (Reverse Geocoding)
  Future<AddressResult> getAddressFromCoordinates({required double latitude, required double longitude}) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isEmpty) {
        return AddressResult.error('No address found for these coordinates');
      }

      final place = placemarks.first;
      final formattedAddress = _formatAddress(place);

      return AddressResult.success(placemark: place, formattedAddress: formattedAddress);
    } catch (e) {
      return AddressResult.error('Failed to get address: ${e.toString()}');
    }
  }

  String _formatAddress(Placemark place) {
    final parts = <String>[];

    if (place.street?.isNotEmpty ?? false) parts.add(place.street!);
    if (place.subLocality?.isNotEmpty ?? false) parts.add(place.subLocality!);
    if (place.locality?.isNotEmpty ?? false) parts.add(place.locality!);
    if (place.administrativeArea?.isNotEmpty ?? false) {
      parts.add(place.administrativeArea!);
    }
    if (place.postalCode?.isNotEmpty ?? false) parts.add(place.postalCode!);

    return parts.join(', ');
  }

  /// Get coordinates from address (Forward Geocoding)
  Future<CoordinatesResult> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);

      if (locations.isEmpty) {
        return CoordinatesResult.error('No location found for this address');
      }

      final location = locations.first;

      return CoordinatesResult.success(latitude: location.latitude, longitude: location.longitude);
    } catch (e) {
      return CoordinatesResult.error('Failed to get coordinates: ${e.toString()}');
    }
  }

  /// Find providers within radius
  List<T> findWithinRadius<T>({
    required List<T> items,
    required double userLat,
    required double userLon,
    required double radiusKm,
    required double Function(T) getLatitude,
    required double Function(T) getLongitude,
  }) {
    return items.where((item) {
      final distance = calculateDistance(
        startLatitude: userLat,
        startLongitude: userLon,
        endLatitude: getLatitude(item),
        endLongitude: getLongitude(item),
      );
      return distance <= radiusKm;
    }).toList();
  }

  /// Sort items by distance
  List<T> sortByDistance<T>({
    required List<T> items,
    required double userLat,
    required double userLon,
    required double Function(T) getLatitude,
    required double Function(T) getLongitude,
  }) {
    final itemsWithDistance = items.map((item) {
      final distance = calculateDistance(
        startLatitude: userLat,
        startLongitude: userLon,
        endLatitude: getLatitude(item),
        endLongitude: getLongitude(item),
      );
      return MapEntry(item, distance);
    }).toList();

    itemsWithDistance.sort((a, b) => a.value.compareTo(b.value));

    return itemsWithDistance.map((e) => e.key).toList();
  }

  // String _formatAddress(Placemark place) {
  //   final parts = [
  //     place.street,
  //     place.subLocality,
  //     place.locality,
  //     place.administrativeArea,
  //     place.postalCode,
  //   ].where((part) => part != null && part.isNotEmpty);
  //
  //   return parts.join(', ');
  // }

  // ==================== UTILITY METHODS ====================

  /// Check if location service is enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Clear cached location
  void clearCache() {
    _lastKnownPosition = null;
    _lastUpdateTime = null;
  }

  /// Check if coordinates are valid
  bool isValidCoordinates(double latitude, double longitude) {
    return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
  }

  void showSettingsDialog() {
    showDialog(
      context: AppNavigator.context!,
      builder: (context) => AlertDialog(
        title: const Text('Location Required'),
        content: const Text('Please enable location permission in settings.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

/// Location helper class
class LocationHelper {
  /// Format distance for display
  static String formatDistance(double kilometers) {
    if (kilometers < 1) {
      return '${(kilometers * 1000).round()} m';
    }
    return '${kilometers.toStringAsFixed(1)} km';
  }

  /// Check if location is within city limits
  static bool isWithinCity({
    required double lat,
    required double lon,
    required double cityLat,
    required double cityLon,
    double radiusKm = 50,
  }) {
    final distance = LocationService().calculateDistance(
      startLatitude: lat,
      startLongitude: lon,
      endLatitude: cityLat,
      endLongitude: cityLon,
    );
    return distance <= radiusKm;
  }
}
// ==================== RESULT CLASSES ====================

class LocationPermissionResult {
  final bool isGranted;
  final LocationPermission status;
  final String message;
  final bool shouldOpenSettings;

  LocationPermissionResult({
    required this.isGranted,
    required this.status,
    required this.message,
    this.shouldOpenSettings = false,
  });
}

class LocationResult {
  final bool isSuccess;
  final Position? position;
  final String message;
  final bool shouldOpenSettings;

  LocationResult._({
    required this.isSuccess,
    this.position,
    required this.message,
    this.shouldOpenSettings = false,
  });

  factory LocationResult.success(Position position) {
    return LocationResult._(isSuccess: true, position: position, message: 'Location fetched successfully');
  }

  factory LocationResult.error({required String message, bool shouldOpenSettings = false}) {
    return LocationResult._(isSuccess: false, message: message, shouldOpenSettings: shouldOpenSettings);
  }
}

class DistanceResult {
  final double? distance; // in meters
  final String? formattedDistance;
  final String? error;

  DistanceResult({this.distance, this.formattedDistance, this.error});

  bool get isSuccess => error == null && distance != null;
}

class AddressResult {
  final bool isSuccess;
  final Placemark? placemark;
  final String? formattedAddress;
  final String? error;

  AddressResult._({required this.isSuccess, this.placemark, this.formattedAddress, this.error});

  factory AddressResult.success({required Placemark placemark, required String formattedAddress}) {
    return AddressResult._(isSuccess: true, placemark: placemark, formattedAddress: formattedAddress);
  }

  factory AddressResult.error(String error) {
    return AddressResult._(isSuccess: false, error: error);
  }
}

class CoordinatesResult {
  final bool isSuccess;
  final double? latitude;
  final double? longitude;
  final String? error;

  CoordinatesResult._({required this.isSuccess, this.latitude, this.longitude, this.error});

  factory CoordinatesResult.success({required double latitude, required double longitude}) {
    return CoordinatesResult._(isSuccess: true, latitude: latitude, longitude: longitude);
  }

  factory CoordinatesResult.error(String error) {
    return CoordinatesResult._(isSuccess: false, error: error);
  }
}
