import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../../address/data/user_address_repository.dart';
import '../../../service_booking/data/service_request_repository.dart';
import '../../../service_booking/model/booking_model.dart';
import '../../../service_booking/model/service_category_model.dart';

part 'emergency_map_event.dart';
part 'emergency_map_state.dart';

class EmergencyMapBloc extends Bloc<EmergencyMapEvent, EmergencyMapState> {
  final ServiceRequestRepository _requestRepo;
  final UserAddressRepository _addressRepo;
  int? _currentRequestId;
  double? _userLat;
  double? _userLng;
  bool _isCancelled = false;

  EmergencyMapBloc(this._requestRepo, this._addressRepo)
    : super(EmergencyMapInitial()) {
    on<SearchNearbyProviders>(_onSearch);
    on<BookingAcceptedNotificationReceived>(_onAccepted);
    on<AllProvidersDeclinedNotificationReceived>(_onAllDeclined);
    on<BookingExpiredNotificationReceived>(_onBookingExpired);
    on<CancelEmergencyRequest>(_onCancel);
    on<CheckEmergencyBookingStatus>(_onCheckStatus);
  }

  void _onAllDeclined(
    AllProvidersDeclinedNotificationReceived event,
    Emitter<EmergencyMapState> emit,
  ) {
    if (_isCancelled) return;
    emit(EmergencyMapAllProvidersDeclined());
  }

  void _onBookingExpired(
    BookingExpiredNotificationReceived event,
    Emitter<EmergencyMapState> emit,
  ) {
    if (_isCancelled) return;
    _currentRequestId = null;
    emit(EmergencyMapBookingExpired());
  }

  Future<void> _onSearch(
    SearchNearbyProviders event,
    Emitter<EmergencyMapState> emit,
  ) async {
    _isCancelled = false;
    emit(EmergencyMapSearching(event.radiusKm));
    try {
      double lat = 0.0;
      double lng = 0.0;
      Position? position;

      // 1. Get Location (Prefer address coordinates, fallback to live GPS)
      if (event.latitude != null && event.longitude != null) {
        lat = double.tryParse(event.latitude!) ?? 0.0;
        lng = double.tryParse(event.longitude!) ?? 0.0;
      } else {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever ||
            permission == LocationPermission.denied) {
          emit(EmergencyMapError('Location permissions are denied'));
          return;
        }

        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        lat = position.latitude;
        lng = position.longitude;
      }

      if (_isCancelled) return;

      // Get city and fallback address from geocoding
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      String city = 'jaipur';
      String? fallbackFullAddress;

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        city = p.locality ?? 'jaipur';

        // Construct full address: [name, street, subLocality, locality, administrativeArea, postalCode]
        final parts = <String>[
          if (p.name != null && p.name!.isNotEmpty) p.name!,
          if (p.street != null && p.street!.isNotEmpty && p.street != p.name)
            p.street!,
          if (p.subLocality != null && p.subLocality!.isNotEmpty)
            p.subLocality!,
          if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
          if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty)
            p.administrativeArea!,
          if (p.postalCode != null && p.postalCode!.isNotEmpty) p.postalCode!,
        ];
        fallbackFullAddress = parts.join(', ');
      }

      int addressId = event.selectedAddressId ?? 1;
      if (event.selectedAddressId == null) {
        try {
          final addresses = await _addressRepo.getAddresses();
          if (addresses.isNotEmpty && addresses.first.id != null) {
            addressId = addresses.first.id!;
          }
        } catch (_) {}
      }

      if (_isCancelled) return;

      // 2. Create Emergency Request
      final request = BookingRequest()
        ..serviceType = ServiceType(
          id: event.serviceCategory.id.toString(),
          name: event.serviceCategory.categoryName,
          description: event.serviceCategory.description ?? '',
          icon: Icons.local_hospital,
          color: Colors.red,
          priceFrom: '0',
          cityAdminId: event.serviceCategory.cityAdminId,
        )
        ..mode = 'daily'
        ..durationDays = 1
        ..startDate = DateTime.now()
        ..startTime =
            "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}"
        ..latitude = lat
        ..longitude = lng
        ..city = city
        ..address = event.fullAddress ?? fallbackFullAddress
        ..addressId = addressId
        ..familyMemberId = event.familyMemberId
        ..familyMemberName = event.familyMemberName
        ..genderPreference =
            'all' // Default for emergency to match CURL
        ..serviceMode =
            'home_visit' // Default for emergency to match CURL
        ..instructions = event.instructions;

      final response = await _requestRepo.createEmergencyServiceRequest(
        request,
        radiusKm: event.radiusKm.toInt(),
        serviceRequestId: _currentRequestId,
      );

      if (_isCancelled) {
        // If we got an ID but user already cancelled, try to cancel it silently
        final data = response['data'];
        int? idToCleanup;
        if (data != null && data is Map) {
          idToCleanup = int.tryParse(
            data['id']?.toString() ??
                data['service_request']?['id']?.toString() ??
                '0',
          );
        }
        if (idToCleanup != null && idToCleanup > 0) {
          _requestRepo
              .cancelUnpaidBooking(idToCleanup)
              .catchError((_) => false);
        }
        return;
      }

      final data = response['data'];
      int newBookingId = 0;
      List<Map<String, dynamic>> notifiedProviders = [];

      if (data != null && data is Map) {
        final serviceRequest = data['service_request'];
        if (serviceRequest != null && serviceRequest is Map) {
          newBookingId =
              int.tryParse(serviceRequest['id']?.toString() ?? '0') ?? 0;
        } else if (data['id'] != null) {
          newBookingId = int.tryParse(data['id']?.toString() ?? '0') ?? 0;
        } else if (data['service_request_id'] != null) {
          newBookingId =
              int.tryParse(data['service_request_id']?.toString() ?? '0') ?? 0;
        }

        if (data['notifiedProviders'] != null &&
            data['notifiedProviders'] is List) {
          notifiedProviders = List<Map<String, dynamic>>.from(
            data['notifiedProviders'],
          );
        }
      } else if (response['id'] != null) {
        newBookingId = int.tryParse(response['id']?.toString() ?? '0') ?? 0;
      }

      _currentRequestId = newBookingId;
      _userLat = lat;
      _userLng = lng;

      if (notifiedProviders.isEmpty) {
        emit(EmergencyMapNoProviders(event.radiusKm, lat, lng));
        return;
      }

      int? waitingWindowSeconds;
      if (data != null &&
          data is Map &&
          data['waiting_window_seconds'] != null) {
        waitingWindowSeconds = (data['waiting_window_seconds'] as num).toInt();
      }

      emit(
        EmergencyMapProvidersFound(
          notifiedProviders,
          event.radiusKm,
          lat,
          lng,
          newBookingId,
          waitingWindowSeconds: waitingWindowSeconds,
        ),
      );
    } catch (e) {
      if (!_isCancelled) {
        emit(EmergencyMapError(e.toString()));
      }
    }
  }

  void _onAccepted(
    BookingAcceptedNotificationReceived event,
    Emitter<EmergencyMapState> emit,
  ) {
    if (_isCancelled) return;
    emit(
      EmergencyMapBookingAccepted(
        bookingId: _currentRequestId ?? 0,
        userLat: _userLat ?? 0,
        userLng: _userLng ?? 0,
        providerName: event.providerName ?? 'Partner',
        providerPhone: event.providerPhone,
        providerRating: event.providerRating,
      ),
    );
  }

  Future<void> _onCancel(
    CancelEmergencyRequest event,
    Emitter<EmergencyMapState> emit,
  ) async {
    _isCancelled = true;
    if (_currentRequestId == null || _currentRequestId == 0) {
      emit(EmergencyMapCancelled());
      return;
    }
    emit(EmergencyMapCancelling());
    try {
      // Use cancelUnpaidBooking for emergency requests before payment
      await _requestRepo.cancelUnpaidBooking(_currentRequestId!);
      _currentRequestId = null;
      emit(EmergencyMapCancelled());
    } catch (e) {
      // Even if server call fails, we let user go back
      emit(EmergencyMapCancelled());
    }
  }

  Future<void> _onCheckStatus(
    CheckEmergencyBookingStatus event,
    Emitter<EmergencyMapState> emit,
  ) async {
    if (_isCancelled || _currentRequestId == null || _currentRequestId == 0) {
      return;
    }
    try {
      final response = await _requestRepo.getServiceRequestDetails(
        requestId: _currentRequestId!,
      );
      final data =
          response['data']?['service_request'] ??
          response['service_request'] ??
          response['data'];
      final String? status = data?['request_status'] ?? data?['status'];
      if (status == 'accepted' ||
          status == 'in_progress' ||
          status == 'scheduled' ||
          status == 'confirmed') {
        final providerData = data?['provider'] ?? data?['service_provider'];
        emit(
          EmergencyMapBookingAccepted(
            bookingId: _currentRequestId ?? 0,
            userLat: _userLat ?? 0,
            userLng: _userLng ?? 0,
            providerName:
                providerData?['name']?.toString() ??
                providerData?['full_name']?.toString() ??
                'Partner',
            providerPhone:
                providerData?['mobile']?.toString() ??
                providerData?['phone']?.toString(),
            providerRating: (providerData?['rating'] as num?)?.toDouble(),
          ),
        );
      }
    } catch (_) {}
  }
}
