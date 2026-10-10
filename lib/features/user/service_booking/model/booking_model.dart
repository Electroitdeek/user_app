// ─────────────────────────────────────────────────────────
//  Booking Flow – Shared Data Models
//  Updated: added rateCard to ServiceType, estimatedPrice to BookingRequest
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../model/service_category_model.dart';

// --------------- Service Type (lightweight UI model) ---------------
class ServiceType {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String priceFrom;
  final String? iconUrl;

  /// The active rate card for this service — used for live cost calculation
  final RateCardModel? rateCard;

  /// GST percentage from the service category
  final double gstPercentage;
  final int? cityAdminId;

  const ServiceType({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.priceFrom,
    this.iconUrl,
    this.rateCard,
    this.gstPercentage = 0,
    this.cityAdminId,
  });
}

// --------------- Provider (legacy mock) ---------------
class ProviderModel {
  final String id;
  final String name;
  final String specialty;
  final double rating;
  final int reviewCount;
  final String experience;
  final int distanceMeters;
  final String price;
  final String imagePlaceholder;
  final List<String> badges;
  final bool isVerified;

  const ProviderModel({
    required this.id,
    required this.name,
    required this.specialty,
    required this.rating,
    required this.reviewCount,
    required this.experience,
    required this.distanceMeters,
    required this.price,
    required this.imagePlaceholder,
    required this.badges,
    this.isVerified = true,
  });
}

// --------------- Booking Request (accumulated across steps) ---------------
class BookingRequest {
  // Step 1 – category
  ServiceType? serviceType;

  // Step 2 – care mode
  String? mode; // 'hourly' | 'daily'
  String? careModeName;
  String? bookingType; // 'procedural' | 'long_duration'

  // Step 3 – date & time
  DateTime? startDate;
  DateTime? endDate;
  String? startTime;
  int? durationHours;
  int? durationDays;

  /// Live-calculated estimated price (set in step 3)
  double? estimatedPrice;

  // Step 4 – address & family
  String? address;
  String? landmark;
  int? addressId;
  int? familyMemberId;
  String? familyMemberName;
  String? instructions;
  double? latitude;
  double? longitude;
  String? city;

  // Step 6 – provider(s)
  ProviderModel? selectedProvider;
  List<int>? selectedProviderIds;
  List<String>? selectedProviderNames;

  // Set after creation
  int? serviceRequestId;
  String? requestNumber;
  int? waitingWindowMinutes;
  DateTime? waitingStartedAt;
  List<Map<String, dynamic>>? notifiedProviders;

  // Shift type
  String? shiftType;
  String? serviceStartShift;
  String? endTime;
  String? serviceMode; // e.g. 'live_in' for multi-day bookings
  String? genderPreference; // 'male' | 'female' | 'all'

  // Package & GST
  int? selectedPackageId;
  double? gstPercentage;

  // Scheduling
  bool alternateDays = false;
  List<String>? scheduledDates; // YYYY-MM-DD strings

  // Address extras
  String? pinCode;

  BookingRequest();

  /// Reset all mode-specific scheduling fields when switching care modes.
  void resetModeSpecificFields() {
    startDate = null;
    endDate = null;
    durationDays = null;
    durationHours = null;
    selectedPackageId = null;
    estimatedPrice = null;
    startTime = null;
    endTime = null;
    shiftType = null;
    serviceMode = null;
    alternateDays = false;
    scheduledDates = null;
  }

  BookingRequest copyWith({
    ServiceType? serviceType,
    String? mode,
    String? careModeName,
    String? bookingType,
    DateTime? startDate,
    DateTime? endDate,
    String? startTime,
    int? durationHours,
    int? durationDays,
    double? estimatedPrice,
    String? address,
    String? landmark,
    int? addressId,
    int? familyMemberId,
    String? familyMemberName,
    String? instructions,
    double? latitude,
    double? longitude,
    String? city,
    ProviderModel? selectedProvider,
    List<int>? selectedProviderIds,
    List<String>? selectedProviderNames,
    int? serviceRequestId,
    String? requestNumber,
    int? waitingWindowMinutes,
    DateTime? waitingStartedAt,
    List<Map<String, dynamic>>? notifiedProviders,
    String? shiftType,
    String? serviceStartShift,
    String? endTime,
    String? serviceMode,
    int? selectedPackageId,
    double? gstPercentage,
    bool? alternateDays,
    List<String>? scheduledDates,
    String? pinCode,
  }) {
    return BookingRequest()
      ..serviceType = serviceType ?? this.serviceType
      ..mode = mode ?? this.mode
      ..careModeName = careModeName ?? this.careModeName
      ..bookingType = bookingType ?? this.bookingType
      ..startDate = startDate ?? this.startDate
      ..endDate = endDate ?? this.endDate
      ..startTime = startTime ?? this.startTime
      ..durationHours = durationHours ?? this.durationHours
      ..durationDays = durationDays ?? this.durationDays
      ..estimatedPrice = estimatedPrice ?? this.estimatedPrice
      ..address = address ?? this.address
      ..landmark = landmark ?? this.landmark
      ..addressId = addressId ?? this.addressId
      ..familyMemberId = familyMemberId ?? this.familyMemberId
      ..familyMemberName = familyMemberName ?? this.familyMemberName
      ..instructions = instructions ?? this.instructions
      ..latitude = latitude ?? this.latitude
      ..longitude = longitude ?? this.longitude
      ..city = city ?? this.city
      ..selectedProvider = selectedProvider ?? this.selectedProvider
      ..selectedProviderIds = selectedProviderIds ?? this.selectedProviderIds
      ..selectedProviderNames =
          selectedProviderNames ?? this.selectedProviderNames
      ..serviceRequestId = serviceRequestId ?? this.serviceRequestId
      ..requestNumber = requestNumber ?? this.requestNumber
      ..waitingWindowMinutes =
          waitingWindowMinutes ?? this.waitingWindowMinutes
      ..waitingStartedAt = waitingStartedAt ?? this.waitingStartedAt
      ..notifiedProviders = notifiedProviders ?? this.notifiedProviders
      ..shiftType = shiftType ?? this.shiftType
      ..serviceStartShift = serviceStartShift ?? this.serviceStartShift
      ..endTime = endTime ?? this.endTime
      ..serviceMode = serviceMode ?? this.serviceMode
      ..genderPreference = genderPreference ?? genderPreference
      ..selectedPackageId = selectedPackageId ?? this.selectedPackageId
      ..gstPercentage = gstPercentage ?? this.gstPercentage
      ..alternateDays = alternateDays ?? this.alternateDays
      ..scheduledDates = scheduledDates ?? this.scheduledDates
      ..pinCode = pinCode ?? this.pinCode;
  }

  Map<String, dynamic> toJson() {
    return {
      // Step 1 – category
      'service_type_id': serviceType?.id,
      'service_type_name': serviceType?.name,
      'city_admin_id': serviceType?.cityAdminId,

      // Step 2 – care mode
      'mode': mode,
      'care_mode_name': careModeName,
      'booking_type': bookingType,

      // Step 3 – date & time
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'start_time': startTime,
      'end_time': endTime,
      'duration_hours': durationHours,
      'duration_days': durationDays,
      'shift_type': shiftType,
      'service_start_shift': serviceStartShift,
      'estimated_price': estimatedPrice,
      'service_mode': serviceMode,
      'gender_preference': genderPreference,

      // Package & GST
      'package_id': selectedPackageId,
      'gst_percentage': gstPercentage,

      // Scheduling
      'alternate_days': alternateDays,
      'scheduled_dates': scheduledDates,

      // Step 4 – address & family
      'address': address,
      'landmark': landmark,
      'address_id': addressId,
      'pin_code': pinCode,
      'family_member_id': familyMemberId,
      'family_member_name': familyMemberName,
      'instructions': instructions,
      'latitude': latitude,
      'longitude': longitude,
      'city': city,

      // Step 6 – provider(s)
      'selected_provider_ids': selectedProviderIds,
      'selected_provider_names': selectedProviderNames,

      // Post-creation
      'service_request_id': serviceRequestId,
      'request_number': requestNumber,
      'waiting_window_minutes': waitingWindowMinutes,
      'waiting_started_at': waitingStartedAt?.toIso8601String(),
      'notified_providers': notifiedProviders,
    };
  }
}
