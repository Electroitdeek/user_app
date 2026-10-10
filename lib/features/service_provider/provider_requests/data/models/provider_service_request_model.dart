import 'booking_model.dart';
import 'customer_models.dart';
import 'sub_block_model.dart';

class ProviderServiceRequestModel {
  // ─── Identity ────────────────────────────────────────────────────────────
  final int id;
  final String requestNumber;
  final String? bookingNumber;
  final int? bookingId;

  // ─── Status ───────────────────────────────────────────────────────────────
  final String requestStatus;
  final int requestStage;
  final String paymentStatus;
  final bool isPaymentDone;
  final int isEmergency;
  final bool serviceStarted;
  final String? serviceStartedAt;
  final bool isNotReached;

  // ─── Waiting window (for incoming request countdown) ─────────────────────
  final String? waitingStartedAt;
  final int waitingWindowMinutes;

  // ─── Service info ─────────────────────────────────────────────────────────
  final String serviceCategoryName;
  final String? categoryIconUrl;
  final String serviceMode;
  final String serviceModeText;
  final String serviceType;
  final String serviceTypeText;
  final String? genderPreference;

  // ─── Schedule ─────────────────────────────────────────────────────────────
  final String? startDate;
  final String startDateText;
  final String? startTime;
  final String startTimeText;
  final String? endDate;
  final String endDateText;
  final String? endTime;
  final String endTimeText;
  final int? durationDays;
  final int? durationHours;
  final String? shiftType;

  // ─── Pricing ──────────────────────────────────────────────────────────────
  final double? basePrice;
  final double? totalAmount;
  final double? paidAmount;
  final double? remainingAmount;
  final double? companyCommission;
  final double? gstAmount;
  final double? gstPercentage;
  final double? distanceCharge;
  final double? discountAmount;
  final double? surgeCharge;
  final int surgeMultiplier;

  // ─── Location ─────────────────────────────────────────────────────────────
  final double serviceLatitude;
  final double serviceLongitude;
  final double distanceKm;
  final String address;
  final String city;

  // ─── Customer ─────────────────────────────────────────────────────────────
  final int? customerProfileId;
  final int? familyMemberId;
  final String customerName;
  final String? customerPhone;
  final String? customerProfileImageUrl;
  final String? specialInstructions;

  // ─── Nested models ────────────────────────────────────────────────────────
  final CustomerProfileModel? customerProfile;
  final FamilyMemberModel? familyMember;
  final CustomerAddressModel? customerAddress;
  final List<SubBlock> subBlocks;
  final List<BookingModel> bookings;

  // ─── Timestamps ───────────────────────────────────────────────────────────
  final String createdAt;

  ProviderServiceRequestModel({
    required this.id,
    required this.requestNumber,
    this.bookingNumber,
    this.bookingId,
    required this.requestStatus,
    this.requestStage = 1,
    this.paymentStatus = 'pending',
    this.isPaymentDone = false,
    this.isEmergency = 0,
    this.serviceStarted = false,
    this.serviceStartedAt,
    this.isNotReached = false,
    this.waitingStartedAt,
    this.waitingWindowMinutes = 10,
    required this.serviceCategoryName,
    this.categoryIconUrl,
    this.serviceMode = '',
    this.serviceModeText = '',
    this.serviceType = '',
    this.serviceTypeText = '',
    this.genderPreference,
    this.startDate,
    this.startDateText = '',
    this.startTime,
    this.startTimeText = '',
    this.endDate,
    this.endDateText = '',
    this.endTime,
    this.endTimeText = '',
    this.durationDays,
    this.durationHours,
    this.shiftType,
    this.basePrice,
    this.totalAmount,
    this.paidAmount,
    this.remainingAmount,
    this.companyCommission,
    this.gstAmount,
    this.gstPercentage,
    this.distanceCharge,
    this.discountAmount,
    this.surgeCharge,
    this.surgeMultiplier = 1,
    this.serviceLatitude = 0.0,
    this.serviceLongitude = 0.0,
    this.distanceKm = 0.0,
    this.address = '',
    this.city = '',
    this.customerProfileId,
    this.familyMemberId,
    this.customerName = '',
    this.customerPhone,
    this.customerProfileImageUrl,
    this.specialInstructions,
    this.customerProfile,
    this.familyMember,
    this.customerAddress,
    this.subBlocks = const [],
    this.bookings = const [],
    required this.createdAt,
  });

  factory ProviderServiceRequestModel.fromJson(Map<String, dynamic> json) {
    // ── distance from provider response ──────────────────────────────────────
    double distKm = 0.0;
    final responses = json['service_request_responses'] as List<dynamic>?;
    if (responses != null && responses.isNotEmpty) {
      distKm = double.tryParse(
              (responses.first as Map<String, dynamic>)['distance_km']?.toString() ?? '0') ??
          0.0;
    }

    // ── service name + icon ───────────────────────────────────────────────────
    final service = json['service'] as Map<String, dynamic>?;
    final serviceCategoryName =
        service?['name'] as String? ?? 'Service';
    final categoryIconUrl = service?['icon_image_url'] as String?;

    // ── customer profile ──────────────────────────────────────────────────────
    CustomerProfileModel? customerProfile;
    String customerName = '';
    String? customerPhone;
    String? customerProfileImageUrl;
    final cpJson = json['customer_profile'] as Map<String, dynamic>?;
    if (cpJson != null) {
      customerProfile = CustomerProfileModel.fromJson(cpJson);
      customerName = customerProfile.fullName;
      customerPhone = customerProfile.user?.mobileNumber;
      customerProfileImageUrl = customerProfile.user?.profileImageUrl;
      if (customerName.isEmpty) customerName = customerProfile.user?.name ?? '';
    }

    // ── family member ─────────────────────────────────────────────────────────
    final fmJson = json['family_member'] as Map<String, dynamic>?;
    final familyMember =
        fmJson != null ? FamilyMemberModel.fromJson(fmJson) : null;

    // ── customer address ──────────────────────────────────────────────────────
    final caJson = json['customer_address'] as Map<String, dynamic>?;
    final customerAddress =
        caJson != null ? CustomerAddressModel.fromJson(caJson) : null;

    // ── address string ────────────────────────────────────────────────────────
    final address = json['full_address'] as String? ??
        customerAddress?.fullAddress ??
        '';

    // ── booking from bookings list ────────────────────────────────────────────
    final bookingsList = json['bookings'] as List<dynamic>?;
    final bookings = bookingsList != null
        ? bookingsList
            .map((e) => BookingModel.fromJson(e as Map<String, dynamic>))
            .toList()
        : <BookingModel>[];

    final firstBooking = bookings.isNotEmpty ? bookings.first : null;

    // ── sub blocks ────────────────────────────────────────────────────────────
    final subBlocks = SubBlock.listFromJson(
        json['sub_blocks'] as List<dynamic>? ?? []);

    // ── payment ───────────────────────────────────────────────────────────────
    final paymentStatus = json['payment_status'] as String? ?? 'pending';
    final isPaymentDone = paymentStatus == 'paid';

    // ── pricing breakdown ─────────────────────────────────────────────────────
    final pricingJson = json['pricing_breakdown'] as Map<String, dynamic>?;
    final remainingAmount = _toDouble(pricingJson?['remaining_amount']);

    return ProviderServiceRequestModel(
      id: json['id'] as int? ?? 0,
      requestNumber: json['request_number'] as String? ?? '',
      bookingNumber: firstBooking?.bookingNumber,
      bookingId: firstBooking?.id,
      requestStatus: json['request_status'] as String? ?? 'pending',
      requestStage: json['request_stage'] as int? ?? 1,
      paymentStatus: paymentStatus,
      isPaymentDone: isPaymentDone,
      isEmergency: json['is_emergency'] as int? ?? 0,
      serviceStarted: json['service_started'] == true || json['service_started'] == 1,
      serviceStartedAt: json['service_started_at']?.toString(),
      isNotReached: json['is_not_reached'] == true || json['is_not_reached'] == 1,
      waitingStartedAt: json['waiting_started_at'] as String?,
      waitingWindowMinutes: (json['waiting_window_minutes'] as num?)?.toInt() ?? 10,
      serviceCategoryName: serviceCategoryName,
      categoryIconUrl: categoryIconUrl,
      serviceMode: json['service_mode'] as String? ?? '',
      serviceModeText: json['service_mode_text'] as String? ?? '',
      serviceType: json['service_type'] as String? ?? '',
      serviceTypeText: json['service_type_text'] as String? ?? '',
      genderPreference: json['gender_preference'] as String?,
      startDate: json['start_date'] as String?,
      startDateText: json['start_date_text'] as String? ?? '',
      startTime: json['start_time'] as String?,
      startTimeText: json['start_time_text'] as String? ?? '',
      endDate: json['end_date'] as String?,
      endDateText: json['end_date_text'] as String? ?? '',
      endTime: json['end_time'] as String?,
      endTimeText: json['end_time_text'] as String? ?? '',
      durationDays: json['duration_days'] as int?,
      durationHours: json['duration_hours'] as int?,
      shiftType: json['shift_type'] as String?,
      basePrice: _toDouble(json['base_price']),
      totalAmount: _toDouble(json['total_amount']),
      paidAmount: _toDouble(json['paid_amount']),
      remainingAmount: remainingAmount,
      companyCommission: (_toDouble(json['company_commission']) ?? 0) > 0
          ? _toDouble(json['company_commission'])
          : _toDouble(pricingJson?['company_commission']),
      gstAmount: _toDouble(json['gst_amount']),
      gstPercentage: _toDouble(json['gst_percentage']),
      distanceCharge: _toDouble(json['distance_charge']),
      discountAmount: _toDouble(json['discount_amount']),
      surgeCharge: _toDouble(json['surge_charge']),
      surgeMultiplier: json['surge_multiplier'] as int? ?? 1,
      serviceLatitude: _toDouble(json['service_latitude']) ?? 0.0,
      serviceLongitude: _toDouble(json['service_longitude']) ?? 0.0,
      distanceKm: distKm,
      address: address,
      city: json['city'] as String? ?? customerAddress?.city ?? '',
      customerProfileId: json['customer_profile_id'] as int?,
      familyMemberId: json['family_member_id'] as int?,
      customerName: customerName,
      customerPhone: customerPhone,
      customerProfileImageUrl: customerProfileImageUrl,
      specialInstructions: json['special_instructions'] as String?,
      customerProfile: customerProfile,
      familyMember: familyMember,
      customerAddress: customerAddress,
      subBlocks: subBlocks,
      bookings: bookings,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  static double? _toDouble(dynamic v) =>
      v == null ? null : double.tryParse(v.toString());

  String get formattedShiftType => switch (shiftType?.toLowerCase()) {
        'day' => 'Day',
        'night' => 'Night',
        '24_hours' => 'Full Day',
        _ => shiftType ?? '—',
      };

  bool get isFullDayShift =>
      shiftType?.toLowerCase() == '24_hours' ||
      (startTime != null && endTime != null && startTime == endTime);

  String get shiftTypeLabel => switch (shiftType?.toLowerCase()) {
        'day' => 'Day Shift',
        'night' => 'Night Shift',
        '24_hours' => 'Full Day Shift',
        _ => shiftType != null ? '$formattedShiftType Shift' : '',
      };
}
