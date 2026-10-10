import 'package:adhisaat_health_care/core/services/app_clock.dart';
import 'package:adhisaat_health_care/di/locator.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Service Request Model — list API
//  Response: { status, message, data: [...], pagination: {...} }
// ─────────────────────────────────────────────────────────────────────────────

class ServiceRequestModel {
  final int id;
  final String? requestNumber;
  final String status; // request_status
  final String? serviceType; // procedural / long_duration / emergency
  final String? serviceTypeText;
  final String? serviceMode; // home_visit / live_in
  final String? serviceModeText;
  final String? shiftType;
  final String? startDate;
  final String? startDateText;
  final String? startTime;
  final String? startTimeText;
  final String? endDate;
  final String? endDateText;
  final String? endTime;
  final int? durationHours;
  final int? durationDays;
  final String? fullAddress;
  final String? city;
  final String? specialInstructions;
  final bool isEmergency;
  final bool serviceStarted;
  final double? basePrice;
  final double? totalAmount;
  final double? paidAmount;
  final double discountAmount;
  final double distanceCharge;
  final double walletAmountUsed;
  final double bonusAmountUsed;
  final double? gstAmount;
  final String? paymentStatus;
  final String createdAt;
  final String? cancelledAt;
  final String? completedAt;
  final ServiceListItem? service;
  final List<SubBlockSummary> subBlocks;
  final List<ServiceRequestBookingSummary> bookings;
  final List<Map<String, dynamic>> paymentInstallments;

  const ServiceRequestModel({
    required this.id,
    this.requestNumber,
    required this.status,
    this.serviceType,
    this.serviceTypeText,
    this.serviceMode,
    this.serviceModeText,
    this.shiftType,
    this.startDate,
    this.startDateText,
    this.startTime,
    this.startTimeText,
    this.endDate,
    this.endDateText,
    this.endTime,
    this.durationHours,
    this.durationDays,
    this.fullAddress,
    this.city,
    this.specialInstructions,
    this.isEmergency = false,
    this.serviceStarted = false,
    this.basePrice,
    this.totalAmount,
    this.paidAmount,
    this.discountAmount = 0,
    this.distanceCharge = 0,
    this.walletAmountUsed = 0,
    this.bonusAmountUsed = 0,
    this.gstAmount,
    this.paymentStatus,
    required this.createdAt,
    this.cancelledAt,
    this.completedAt,
    this.service,
    this.subBlocks = const [],
    this.bookings = const [],
    this.paymentInstallments = const [],
  });

  // ── Backward-compat accessors ─────────────────────────────────────────────

  String get serviceCategoryName => service?.name ?? serviceTypeText ?? 'Service';
  String? get serviceName => service?.name;
  String? get serviceIconUrl => service?.iconImageUrl;
  String? get categoryIconUrl => null;

  // Provider name not available from list API
  String? get providerName => null;

  // Booking IDs from first booking entry
  int? get bookingId => bookings.isNotEmpty ? bookings.first.id : null;
  String? get bookingNumber => bookings.isNotEmpty ? bookings.first.bookingNumber : null;

  // Not available from list API
  String? get actualEnd => null;
  RatingFeedback? get ratingFeedback => null;

  // ── Computed status helpers ───────────────────────────────────────────────

  /// Combined start date + time of the booking (null when unparseable).
  DateTime? get startDateTime {
    final raw = startDate;
    if (raw == null) return null;
    final d = DateTime.tryParse(raw);
    if (d == null) return null;
    final p = (startTime ?? '').split(':');
    final hour = p.isNotEmpty ? int.tryParse(p[0]) ?? 0 : 0;
    final minute = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
    return DateTime(d.year, d.month, d.day, hour, minute);
  }

  /// True when the scheduled start has already passed.
  bool get isStartInPast {
    final start = startDateTime;
    if (start == null) return false;
    return start.isBefore(DateTime.now());
  }

  bool get needsPayment => paymentStatus == 'pending' || paymentStatus == null;
  bool get isPending => status == 'searching';
  bool get isActive => status == 'accepted' || status == 'in_progress';
  bool get isUpcoming => status == 'scheduled' || status == 'confirmed';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isExpired => status == 'expired';
  bool get isCancelledOrExpired => isCancelled || isExpired;
  bool get hasRating => isCompleted && ratingFeedback != null;
  bool get isAnyActive => isPending || isActive || isUpcoming;

  // Not applicable from list API — actual_end not included
  bool get isServiceEnded => false;

  // ── Session helpers ───────────────────────────────────────────────────────

  SubBlockSummary? get currentOrNextSession {
    final now = DateTime.now();
    for (final b in subBlocks) {
      if (b.isOngoing) return b;
    }
    for (final b in subBlocks) {
      if (b.isCurrentlyOngoing(now)) return b;
    }
    final upcoming = subBlocks.where((b) => b.isPending && b.isFuture(now)).toList();
    if (upcoming.isEmpty) return null;
    upcoming.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    return upcoming.first;
  }

  /// Earliest future session that is neither completed nor cancelled
  /// (includes `assigned` sessions). Used to show the real next session date.
  SubBlockSummary? get nextUpcomingSession {
    final now = DateTime.now();
    final upcoming = subBlocks.where((b) => !b.isCompleted && !b.isCancelled && b.isFuture(now)).toList()
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  // ── Display helpers ───────────────────────────────────────────────────────

  String get durationText {
    if (durationDays != null) return durationDays == 1 ? '1 day' : '$durationDays days';
    if (durationHours != null) return durationHours == 1 ? '1 hour' : '$durationHours hours';
    return '—';
  }

  String get statusLabel {
    switch (status) {
      case 'searching':
        return 'Searching';
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'in_progress':
        return 'In Progress';
      case 'scheduled':
        return 'Scheduled';
      case 'confirmed':
      case 'standby':
      case 'partially_accepted':
        return 'Confirmed';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'expired':
        return 'Expired';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  factory ServiceRequestModel.fromJson(Map<String, dynamic> json) {
    return ServiceRequestModel(
      id: json['id'] as int? ?? 0,
      requestNumber: json['request_number'] as String?,
      status: json['request_status'] as String? ?? json['status'] as String? ?? 'searching',
      serviceType: json['service_type'] as String?,
      serviceTypeText: json['service_type_text'] as String?,
      serviceMode: json['service_mode'] as String?,
      serviceModeText: json['service_mode_text'] as String?,
      shiftType: json['shift_type'] as String?,
      startDate: json['start_date'] as String?,
      startDateText: json['start_date_text'] as String?,
      startTime: json['start_time'] as String?,
      startTimeText: json['start_time_text'] as String?,
      endDate: json['end_date'] as String?,
      endDateText: json['end_date_text'] as String?,
      endTime: json['end_time'] as String?,
      durationHours: json['duration_hours'] as int?,
      durationDays: json['duration_days'] as int?,
      fullAddress: json['full_address'] as String?,
      city: json['city'] as String?,
      specialInstructions: json['special_instructions'] as String?,
      isEmergency: json['is_emergency'] == 1 || json['is_emergency'] == true,
      serviceStarted: json['service_started'] == 1 || json['service_started'] == true,
      basePrice: (json['base_price'] as num?)?.toDouble(),
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      paidAmount: (json['paid_amount'] as num?)?.toDouble(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      distanceCharge: (json['distance_charge'] as num?)?.toDouble() ?? 0,
      walletAmountUsed: (json['wallet_amount_used'] as num?)?.toDouble() ?? 0,
      bonusAmountUsed: (json['bonus_amount_used'] as num?)?.toDouble() ?? 0,
      gstAmount: (json['gst_amount'] as num?)?.toDouble(),
      paymentStatus: json['payment_status'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      cancelledAt: json['cancelled_at'] as String?,
      completedAt: json['completed_at'] as String?,
      service: json['service'] != null
          ? ServiceListItem.fromJson(json['service'] as Map<String, dynamic>)
          : null,
      subBlocks: (json['sub_blocks'] as List<dynamic>?)
              ?.map((e) => SubBlockSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      bookings: (json['bookings'] as List<dynamic>?)
              ?.map((e) => ServiceRequestBookingSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      paymentInstallments: (json['payment_installments'] as List<dynamic>?)
              ?.map((e) {
                final m = e as Map<String, dynamic>;
                return {
                  'id': m['id'],
                  'installment_number': m['installment_number'],
                  'amount': m['amount'],
                  'percentage': m['percentage'],
                  'due_date': m['due_date'],
                  'status': m['status'],
                  'status_text': m['status_text'],
                };
              })
              .toList() ??
          [],
    );
  }
}

// ─── Response Wrapper ─────────────────────────────────────────────────────────

class ServiceRequestsResponse {
  final bool success;
  final List<ServiceRequestModel> requests;
  final int total;
  final int currentPage;
  final int perPage;
  final int lastPage;

  const ServiceRequestsResponse({
    required this.success,
    required this.requests,
    this.total = 0,
    this.currentPage = 1,
    this.perPage = 10,
    this.lastPage = 1,
  });

  bool get hasMore => currentPage < lastPage;

  factory ServiceRequestsResponse.fromJson(Map<String, dynamic> json) {
    List<dynamic> rawList = [];
    if (json['data'] is List) {
      rawList = json['data'] as List<dynamic>;
    } else if (json['data'] is Map && (json['data'] as Map)['data'] is List) {
      rawList = (json['data'] as Map)['data'] as List<dynamic>;
    }

    final pagination = json['pagination'] as Map<String, dynamic>?;

    return ServiceRequestsResponse(
      success: json['success'] == true || json['status'] == true,
      requests: rawList.map((e) => ServiceRequestModel.fromJson(e as Map<String, dynamic>)).toList(),
      total: (pagination?['total'] as num?)?.toInt() ?? rawList.length,
      currentPage: (pagination?['current_page'] as num?)?.toInt() ?? 1,
      perPage: (pagination?['per_page'] as num?)?.toInt() ?? 10,
      lastPage: (pagination?['last_page'] as num?)?.toInt() ?? 1,
    );
  }
}

// ─── Service Info (nested in each request) ───────────────────────────────────

class ServiceListItem {
  final int id;
  final String name;
  final String? iconImageUrl;
  final String? imageUrl;
  final bool isEmergency;
  final int serviceCategoryId;
  final int? serviceSubcategoryId;
  final double gstPercentage;

  const ServiceListItem({
    required this.id,
    required this.name,
    this.iconImageUrl,
    this.imageUrl,
    this.isEmergency = false,
    required this.serviceCategoryId,
    this.serviceSubcategoryId,
    this.gstPercentage = 0,
  });

  factory ServiceListItem.fromJson(Map<String, dynamic> json) {
    return ServiceListItem(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      iconImageUrl: json['icon_image_url'] as String?,
      imageUrl: json['image'] as String?,
      isEmergency: json['is_emergency'] == 1 || json['is_emergency'] == true,
      serviceCategoryId: json['service_category_id'] as int? ?? 0,
      serviceSubcategoryId: json['service_subcategory_id'] as int?,
      gstPercentage: (json['gst_percentage'] as num?)?.toDouble() ?? 0,
    );
  }
}

// ─── Booking Summary (from bookings[] in list response) ──────────────────────

class ServiceRequestBookingSummary {
  final int id;
  final String bookingNumber;
  final int? serviceProviderId;
  final String bookingStatus;
  final String bookingStatusText;

  const ServiceRequestBookingSummary({
    required this.id,
    required this.bookingNumber,
    this.serviceProviderId,
    required this.bookingStatus,
    required this.bookingStatusText,
  });

  bool get isCancelled => bookingStatus == 'cancelled';
  bool get isCompleted => bookingStatus == 'completed';
  bool get isActive => bookingStatus == 'accepted' || bookingStatus == 'in_progress';

  factory ServiceRequestBookingSummary.fromJson(Map<String, dynamic> json) {
    return ServiceRequestBookingSummary(
      id: json['id'] as int? ?? 0,
      bookingNumber: json['booking_number'] as String? ?? '',
      serviceProviderId: json['service_provider_id'] as int?,
      bookingStatus: json['booking_status'] as String? ?? '',
      bookingStatusText: json['booking_status_text'] as String? ?? '',
    );
  }
}

// ─── Sub-Block Summary (from sub_blocks[] in list response) ──────────────────

class SubBlockSummary {
  final int id;
  final int serviceRequestId;
  final int? bookingId;
  final int? serviceProviderId;
  final String scheduledDate;
  final String scheduledDateText;
  final String scheduledStartTime;
  final String scheduledEndTime;
  final String scheduledStartTimeText;
  final String scheduledEndTimeText;
  final String status;
  final String statusText;
  final double blockAmount;
  final String? startOtp;

  final String? actualStartTime;
  final String? actualEndTime;

  const SubBlockSummary({
    required this.id,
    required this.serviceRequestId,
    this.bookingId,
    this.serviceProviderId,
    required this.scheduledDate,
    required this.scheduledDateText,
    required this.scheduledStartTime,
    required this.scheduledEndTime,
    required this.scheduledStartTimeText,
    required this.scheduledEndTimeText,
    required this.status,
    required this.statusText,
    required this.blockAmount,
    this.startOtp,
    this.actualStartTime,
    this.actualEndTime,
  });

  bool get isOngoing => status == 'in_progress';
  bool get isPending => status == 'pending';
  bool get isAssigned => status == 'assigned';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';

  DateTime get startDateTime {
    final d = DateTime.tryParse(scheduledDate) ?? DateTime.now();
    final p = scheduledStartTime.split(':');
    return DateTime(d.year, d.month, d.day, int.tryParse(p[0]) ?? 0, int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
  }

  DateTime get endDateTime {
    final d = DateTime.tryParse(scheduledDate) ?? DateTime.now();
    final p = scheduledEndTime.split(':');
    var end = DateTime(d.year, d.month, d.day, int.tryParse(p[0]) ?? 0, int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
    if (!end.isAfter(startDateTime)) end = end.add(const Duration(days: 1));
    return end;
  }

  bool get isExpired {
    final lower = status.toLowerCase();
    if (lower == 'expired') return true;
    if (lower != 'pending' && lower != 'accepted' && lower != 'assigned') return false;
    final now = locator.isRegistered<AppClock>() ? locator<AppClock>().now : DateTime.now();
    return now.isAfter(endDateTime);
  }

  bool get isConfirmed => (isPending || isAssigned || isOngoing) && !isExpired;

  // Session is "in progress" only when the block status is actually in_progress
  // (provider checked in). A pending block whose scheduled time window contains
  // `now` is NOT ongoing yet.
  bool isCurrentlyOngoing(DateTime now) => isOngoing;

  bool isFuture(DateTime now) => startDateTime.isAfter(now);

  factory SubBlockSummary.fromJson(Map<String, dynamic> json) {
    return SubBlockSummary(
      id: json['id'] as int? ?? 0,
      serviceRequestId: json['service_request_id'] as int? ?? 0,
      bookingId: json['booking_id'] as int?,
      serviceProviderId: json['service_provider_id'] as int?,
      scheduledDate: json['scheduled_date'] as String? ?? '',
      scheduledDateText: json['scheduled_date_text'] as String? ?? '',
      scheduledStartTime: json['scheduled_start_time'] as String? ?? '',
      scheduledEndTime: json['scheduled_end_time'] as String? ?? '',
      scheduledStartTimeText: json['scheduled_start_time_text'] as String? ?? '',
      scheduledEndTimeText: json['scheduled_end_time_text'] as String? ?? '',
      status: json['status'] as String? ?? '',
      statusText: json['status_text'] as String? ?? '',
      blockAmount: (json['block_amount'] as num?)?.toDouble() ?? 0,
      startOtp: json['start_otp'] as String?,
      actualStartTime: json['actual_start_time'] as String?,
      actualEndTime: json['actual_end_time'] as String?,
    );
  }
}

// ─── Rating Feedback (kept for backward compat — populated in detail API) ────

class RatingFeedback {
  final int id;
  final int bookingId;
  final int rating;
  final String? feedbackComment;
  final int? punctualityRating;
  final int? behaviorRating;
  final int? skillRating;
  final bool isComplaint;
  final String? createdAt;

  const RatingFeedback({
    required this.id,
    required this.bookingId,
    required this.rating,
    this.feedbackComment,
    this.punctualityRating,
    this.behaviorRating,
    this.skillRating,
    this.isComplaint = false,
    this.createdAt,
  });

  factory RatingFeedback.fromJson(Map<String, dynamic> json) {
    return RatingFeedback(
      id: json['id'] as int? ?? 0,
      bookingId: json['booking_id'] as int? ?? 0,
      rating: json['rating'] as int? ?? 0,
      feedbackComment: json['feedback_comment'] as String?,
      punctualityRating: json['punctuality_rating'] as int?,
      behaviorRating: json['behavior_rating'] as int?,
      skillRating: json['skill_rating'] as int?,
      isComplaint: json['is_complaint'] == true || json['is_complaint'] == 1,
      createdAt: json['created_at'] as String?,
    );
  }
}
