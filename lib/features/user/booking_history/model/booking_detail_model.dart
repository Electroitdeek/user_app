import '../../../../core/services/app_clock.dart';
import '../../../../di/locator.dart';
import '../../family/model/family_member_model.dart';

class BookingDetailModel {
  final ServiceRequestDetail serviceRequest;
  final List<ServiceRequestResponse> responses;

  const BookingDetailModel({required this.serviceRequest, required this.responses});

  factory BookingDetailModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return BookingDetailModel(
      serviceRequest: ServiceRequestDetail.fromJson(
        data['service_request'] as Map<String, dynamic>,
      ),
      responses: (data['service_request_responses'] as List<dynamic>?)
              ?.map((e) => ServiceRequestResponse.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ServiceRequestDetail {
  final int id;
  final String requestNumber;
  final String requestStatus;
  final String serviceType;
  final String serviceMode;
  final String serviceModeText;
  final String serviceTypeText;
  final String startDate;
  final String startDateText;
  final String? startTime;
  final String startTimeText;
  final String endDate;
  final String endDateText;
  final String? endTime;
  final String endTimeText;
  final String? shiftType;
  final int? durationDays;
  final double? durationHours;
  final String fullAddress;
  final String city;
  final String? serviceLatitude;
  final String? serviceLongitude;
  final double basePrice;
  final double totalAmount;
  final double paidAmount;
  final double discountAmount;
  final double walletAmountUsed;
  final double bonusAmountUsed;
  final String paymentStatus;
  final String paymentStatusText;
  final bool isEmergency;
  final bool serviceStarted;
  final String? specialInstructions;
  final String? createdAt;
  final String? cancelledAt;
  final String? completedAt;
  final List<PaymentInstallment> paymentInstallments;
  final List<SubBlock> subBlocks;
  final BookingServiceInfo? service;
  final PricingBreakdown? pricingBreakdown;
  final FamilyMemberModel? familyMember;

  const ServiceRequestDetail({
    required this.id,
    required this.requestNumber,
    required this.requestStatus,
    required this.serviceType,
    required this.serviceMode,
    required this.serviceModeText,
    required this.serviceTypeText,
    required this.startDate,
    required this.startDateText,
    this.startTime,
    required this.startTimeText,
    required this.endDate,
    required this.endDateText,
    this.endTime,
    required this.endTimeText,
    this.shiftType,
    this.durationDays,
    this.durationHours,
    required this.fullAddress,
    required this.city,
    this.serviceLatitude,
    this.serviceLongitude,
    required this.basePrice,
    required this.totalAmount,
    required this.paidAmount,
    required this.discountAmount,
    required this.walletAmountUsed,
    required this.bonusAmountUsed,
    required this.paymentStatus,
    required this.paymentStatusText,
    required this.isEmergency,
    required this.serviceStarted,
    this.specialInstructions,
    this.createdAt,
    this.cancelledAt,
    this.completedAt,
    required this.paymentInstallments,
    required this.subBlocks,
    this.service,
    this.pricingBreakdown,
    this.familyMember,
  });

  double get remainingAmount => totalAmount - paidAmount;

  bool get isCancelled => requestStatus == 'cancelled';
  bool get isExpired => requestStatus == 'expired';
  bool get isCancelledOrExpired => isCancelled || isExpired;
  bool get isCompleted => requestStatus == 'completed';
  bool get isSearching => requestStatus == 'searching';
  bool get isAccepted => requestStatus == 'accepted';
  bool get isInProgress => requestStatus == 'in_progress';

  /// Combined start date + time of the booking. Falls back gracefully when
  /// the time is missing (defaults to start of day).
  DateTime? get startDateTime {
    final d = DateTime.tryParse(startDate);
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

  factory ServiceRequestDetail.fromJson(Map<String, dynamic> json) {
    return ServiceRequestDetail(
      id: json['id'] as int,
      requestNumber: json['request_number'] as String? ?? '',
      requestStatus: json['request_status'] as String? ?? '',
      serviceType: json['service_type'] as String? ?? '',
      serviceMode: json['service_mode'] as String? ?? '',
      serviceModeText: json['service_mode_text'] as String? ?? '',
      serviceTypeText: json['service_type_text'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      startDateText: json['start_date_text'] as String? ?? '',
      startTime: json['start_time'] as String?,
      startTimeText: json['start_time_text'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      endDateText: json['end_date_text'] as String? ?? '',
      endTime: json['end_time'] as String?,
      endTimeText: json['end_time_text'] as String? ?? '',
      shiftType: json['shift_type'] as String?,
      durationDays: json['duration_days'] as int?,
      durationHours: (json['duration_hours'] as num?)?.toDouble(),
      fullAddress: json['full_address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      serviceLatitude: json['service_latitude'] as String?,
      serviceLongitude: json['service_longitude'] as String?,
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      walletAmountUsed: (json['wallet_amount_used'] as num?)?.toDouble() ?? 0,
      bonusAmountUsed: (json['bonus_amount_used'] as num?)?.toDouble() ?? 0,
      paymentStatus: json['payment_status'] as String? ?? '',
      paymentStatusText: json['payment_status_text'] as String? ?? '',
      isEmergency: (json['is_emergency'] as int? ?? 0) == 1,
      serviceStarted: json['service_started'] as bool? ?? false,
      specialInstructions: json['special_instructions'] as String?,
      createdAt: json['created_at'] as String?,
      cancelledAt: json['cancelled_at'] as String?,
      completedAt: json['completed_at'] as String?,
      paymentInstallments: (json['payment_installments'] as List<dynamic>?)
              ?.map((e) => PaymentInstallment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      subBlocks: (json['sub_blocks'] as List<dynamic>?)
              ?.map((e) => SubBlock.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      service: json['service'] != null
          ? BookingServiceInfo.fromJson(json['service'] as Map<String, dynamic>)
          : null,
      pricingBreakdown: json['pricing_breakdown'] != null
          ? PricingBreakdown.fromJson(json['pricing_breakdown'] as Map<String, dynamic>)
          : null,
      familyMember: json['family_member'] != null
          ? FamilyMemberModel.fromJson(json['family_member'] as Map<String, dynamic>)
          : null,
    );
  }
}

class PaymentInstallment {
  final int id;
  final int installmentNumber;
  final double amount;
  final int percentage;
  final String dueDate;
  final String status;
  final String statusText;
  final String? paidAt;
  final bool isOverdue;
  final InstallmentPayment? payment;

  const PaymentInstallment({
    required this.id,
    required this.installmentNumber,
    required this.amount,
    required this.percentage,
    required this.dueDate,
    required this.status,
    required this.statusText,
    this.paidAt,
    required this.isOverdue,
    this.payment,
  });

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';

  factory PaymentInstallment.fromJson(Map<String, dynamic> json) {
    return PaymentInstallment(
      id: json['id'] as int,
      installmentNumber: json['installment_number'] as int,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      percentage: json['percentage'] as int? ?? 0,
      dueDate: json['due_date'] as String? ?? '',
      status: json['status'] as String? ?? '',
      statusText: json['status_text'] as String? ?? '',
      paidAt: json['paid_at'] as String?,
      isOverdue: json['is_overdue'] as bool? ?? false,
      payment: json['payment'] != null
          ? InstallmentPayment.fromJson(json['payment'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'installment_number': installmentNumber,
      'amount': amount,
      'percentage': percentage,
      'due_date': dueDate,
      'status': status,
      'status_text': statusText,
      'paid_at': paidAt,
      'is_overdue': isOverdue,
    };
  }
}

class InstallmentPayment {
  final int id;
  final String paymentNumber;
  final double subtotal;
  final double totalAmount;
  final double discountAmount;
  final double walletAmountUsed;
  final double bonusAmountUsed;
  final String paymentMethod;
  final String paymentStatus;
  final String? transactionId;
  final String? paidAt;
  final String paymentGateway;
  final List<InstallmentRefundPayment> refundPayments;

  const InstallmentPayment({
    required this.id,
    required this.paymentNumber,
    required this.subtotal,
    required this.totalAmount,
    required this.discountAmount,
    required this.walletAmountUsed,
    required this.bonusAmountUsed,
    required this.paymentMethod,
    required this.paymentStatus,
    this.transactionId,
    this.paidAt,
    required this.paymentGateway,
    this.refundPayments = const [],
  });

  factory InstallmentPayment.fromJson(Map<String, dynamic> json) {
    return InstallmentPayment(
      id: json['id'] as int,
      paymentNumber: json['payment_number'] as String? ?? '',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      walletAmountUsed: (json['wallet_amount_used'] as num?)?.toDouble() ?? 0,
      bonusAmountUsed: (json['bonus_amount_used'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['payment_method'] as String? ?? '',
      paymentStatus: json['payment_status'] as String? ?? '',
      transactionId: json['transaction_id'] as String?,
      paidAt: json['paid_at'] as String?,
      paymentGateway: json['payment_gateway'] as String? ?? '',
      refundPayments: (json['refund_payments'] as List<dynamic>?)
              ?.map((e) => InstallmentRefundPayment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class InstallmentRefundPayment {
  final int id;
  final String paymentNumber;
  final double subtotal;
  final double walletAmountUsed;
  final double bonusAmountUsed;
  final String? paymentMethod;
  final String? paidAt;
  final String? refundGatewayReference;

  const InstallmentRefundPayment({
    required this.id,
    required this.paymentNumber,
    required this.subtotal,
    required this.walletAmountUsed,
    required this.bonusAmountUsed,
    this.paymentMethod,
    this.paidAt,
    this.refundGatewayReference,
  });

  double get displayAmount => subtotal;

  factory InstallmentRefundPayment.fromJson(Map<String, dynamic> json) {
    return InstallmentRefundPayment(
      id: json['id'] as int,
      paymentNumber: json['payment_number'] as String? ?? '',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      walletAmountUsed: (json['wallet_amount_used'] as num?)?.toDouble() ?? 0,
      bonusAmountUsed: (json['bonus_amount_used'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['payment_method'] as String?,
      paidAt: json['paid_at'] as String?,
      refundGatewayReference: json['refund_gateway_reference'] as String?,
    );
  }
}

class SubBlock {
  final int id;
  final int? bookingId;
  final String scheduledDate;
  final String scheduledDateText;
  final String scheduledStartTimeText;
  final String scheduledEndTimeText;
  final String scheduledStartTime;
  final String scheduledEndTime;
  final String status;
  final String statusText;
  final double blockAmount;
  final String? actualStartTime;
  final String? actualEndTime;
  final String? actualStartDateText;
  final String? actualEndDateText;
  final String? startOtp;
  final bool hasRating;
  final int? rating;

  const SubBlock({
    required this.id,
    this.bookingId,
    required this.scheduledDate,
    required this.scheduledDateText,
    required this.scheduledStartTimeText,
    required this.scheduledEndTimeText,
    required this.scheduledStartTime,
    required this.scheduledEndTime,
    required this.status,
    required this.statusText,
    required this.blockAmount,
    this.actualStartTime,
    this.actualEndTime,
    this.actualStartDateText,
    this.actualEndDateText,
    this.startOtp,
    this.hasRating = false,
    this.rating,
  });

  bool get isPending => status == 'pending';
  bool get isAssigned => status == 'assigned';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isOngoing => status == 'in_progress';

  // A pending/assigned session whose scheduled window has fully passed
  // without ever being started — distinct from "Confirmed".
  bool get isExpired => (isPending || isAssigned) && endDateTime.isBefore(locator<AppClock>().now);
  bool get isConfirmed => (isPending || isAssigned || isOngoing) && !isExpired;

  DateTime get startDateTime {
    final d = DateTime.tryParse(scheduledDate) ?? DateTime.now();
    final p = scheduledStartTime.split(':');
    return DateTime(d.year, d.month, d.day, int.tryParse(p[0]) ?? 0, int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
  }

  // Scheduled end as DateTime. For overnight shifts where the end time is
  // not after the start time, the end falls on the next calendar day.
  DateTime get endDateTime {
    final d = DateTime.tryParse(scheduledDate) ?? DateTime.now();
    final p = scheduledEndTime.split(':');
    var end = DateTime(d.year, d.month, d.day, int.tryParse(p[0]) ?? 0, int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
    if (!end.isAfter(startDateTime)) end = end.add(const Duration(days: 1));
    return end;
  }

  // Session is "in progress" only when the block status is actually in_progress
  // (provider checked in). A pending block whose scheduled time window contains
  // `now` is NOT ongoing yet.
  bool isCurrentlyOngoing(DateTime now) => isOngoing;

  bool isFuture(DateTime now) => startDateTime.isAfter(now);

  factory SubBlock.fromJson(Map<String, dynamic> json) {
    return SubBlock(
      id: json['id'] as int,
      bookingId: json['booking_id'] as int?,
      scheduledDate: json['scheduled_date'] as String? ?? '',
      scheduledDateText: json['scheduled_date_text'] as String? ?? '',
      scheduledStartTimeText: json['scheduled_start_time_text'] as String? ?? '',
      scheduledEndTimeText: json['scheduled_end_time_text'] as String? ?? '',
      scheduledStartTime: json['scheduled_start_time'] as String? ?? '',
      scheduledEndTime: json['scheduled_end_time'] as String? ?? '',
      status: json['status'] as String? ?? '',
      statusText: json['status_text'] as String? ?? '',
      blockAmount: (json['block_amount'] as num?)?.toDouble() ?? 0,
      actualStartTime: json['actual_start_time'] as String?,
      actualEndTime: json['actual_end_time'] as String?,
      actualStartDateText: json['actual_start_date_text'] as String?,
      actualEndDateText: json['actual_end_date_text'] as String?,
      startOtp: json['start_otp'] as String?,
      hasRating: json['rating_feedback'] != null,
      rating: (json['rating_feedback'] as Map<String, dynamic>?)?['rating'] as int?,
    );
  }
}

class BookingServiceInfo {
  final int id;
  final int serviceCategoryId;
  final String name;
  final String? iconImageUrl;
  final String type;
  final String? description;

  const BookingServiceInfo({
    required this.id,
    required this.serviceCategoryId,
    required this.name,
    this.iconImageUrl,
    required this.type,
    this.description,
  });

  factory BookingServiceInfo.fromJson(Map<String, dynamic> json) {
    return BookingServiceInfo(
      id: json['id'] as int,
      serviceCategoryId: json['service_category_id'] as int,
      name: json['name'] as String? ?? '',
      iconImageUrl: json['icon_image_url'] as String?,
      type: json['type'] as String? ?? '',
      description: json['description'] as String?,
    );
  }
}

class PackageInfo {
  final int id;
  final double price;
  final double actualPrice;
  final int duration;
  final String durationType;
  final String shiftType;
  final String? description;
  final double discountPercentage;

  const PackageInfo({
    required this.id,
    required this.price,
    required this.actualPrice,
    required this.duration,
    required this.durationType,
    required this.shiftType,
    this.description,
    required this.discountPercentage,
  });

  String get displayShift {
    switch (shiftType.toLowerCase()) {
      case 'day_shift':
        return 'Day Shift';
      case 'night_shift':
        return 'Night Shift';
      case 'full_day':
        return 'Full Day';
      default:
        return shiftType.replaceAll('_', ' ');
    }
  }

  factory PackageInfo.fromJson(Map<String, dynamic> json) {
    return PackageInfo(
      id: json['id'] as int,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      actualPrice: (json['actual_price'] as num?)?.toDouble() ?? 0,
      duration: json['duration'] as int? ?? 0,
      durationType: json['duration_type'] as String? ?? 'days',
      shiftType: json['shift_type'] as String? ?? '',
      description: json['description'] as String?,
      discountPercentage: (json['discount_percentage'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PricingBreakdown {
  final PackageInfo? package;
  final double totalAmount;
  final double advanceAmount;
  final double remainingAmount;
  final double serviceCharge;
  final double distanceCharge;
  final double surgeCharge;
  final double gstAmount;
  final double gstPercentage;
  final double companyCommission;
  final String? unitType;

  const PricingBreakdown({
    this.package,
    required this.totalAmount,
    required this.advanceAmount,
    required this.remainingAmount,
    required this.serviceCharge,
    required this.distanceCharge,
    required this.surgeCharge,
    required this.gstAmount,
    required this.gstPercentage,
    required this.companyCommission,
    this.unitType,
  });

  factory PricingBreakdown.fromJson(Map<String, dynamic> json) {
    final rateCard = json['rateCard'] as Map<String, dynamic>?;
    return PricingBreakdown(
      package: json['package'] != null
          ? PackageInfo.fromJson(json['package'] as Map<String, dynamic>)
          : null,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      advanceAmount: (json['advance_amount'] as num?)?.toDouble() ?? 0,
      remainingAmount: (json['remaining_amount'] as num?)?.toDouble() ?? 0,
      serviceCharge: (json['service_charge'] as num?)?.toDouble() ?? 0,
      distanceCharge: (json['distance_charge'] as num?)?.toDouble() ?? 0,
      surgeCharge: (json['surge_charge'] as num?)?.toDouble() ?? 0,
      gstAmount: (json['gst_amount'] as num?)?.toDouble() ?? 0,
      gstPercentage: (json['gst_percentage'] as num?)?.toDouble() ?? 0,
      companyCommission: (json['company_commission'] as num?)?.toDouble() ?? 0,
      unitType: rateCard?['unit_type'] as String?,
    );
  }
}

// ─── Cancellation Preview ─────────────────────────────────────────────────────

class CancellationPreviewModel {
  final bool allowed;
  final String cancellationType;
  final int totalBlocks;
  final double totalPaidValue;
  final double cancellationFee;
  final double providerShare;
  final double adhisaatShare;
  final double refundAmount;
  final List<BlockCancellationDetail> blockDetails;

  const CancellationPreviewModel({
    required this.allowed,
    required this.cancellationType,
    required this.totalBlocks,
    required this.totalPaidValue,
    required this.cancellationFee,
    required this.providerShare,
    required this.adhisaatShare,
    required this.refundAmount,
    required this.blockDetails,
  });

  factory CancellationPreviewModel.fromJson(Map<String, dynamic> json) {
    return CancellationPreviewModel(
      allowed: json['allowed'] as bool? ?? false,
      cancellationType: json['cancellation_type'] as String? ?? '',
      totalBlocks: json['total_blocks'] as int? ?? 0,
      totalPaidValue: (json['total_paid_value_of_blocks'] as num?)?.toDouble() ?? 0,
      cancellationFee: (json['cancellation_fee'] as num?)?.toDouble() ?? 0,
      providerShare: (json['provider_share'] as num?)?.toDouble() ?? 0,
      adhisaatShare: (json['adhisaat_share'] as num?)?.toDouble() ?? 0,
      refundAmount: (json['refund_amount'] as num?)?.toDouble() ?? 0,
      blockDetails: (json['block_details'] as List<dynamic>?)
              ?.map((e) => BlockCancellationDetail.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class BlockCancellationDetail {
  final int blockId;
  final double blockAmount;
  final double blockPaidValue;
  final double cancellationFee;
  final double refundAmount;
  final String tier;
  final double hoursBeforeStart;

  const BlockCancellationDetail({
    required this.blockId,
    required this.blockAmount,
    required this.blockPaidValue,
    required this.cancellationFee,
    required this.refundAmount,
    required this.tier,
    required this.hoursBeforeStart,
  });

  factory BlockCancellationDetail.fromJson(Map<String, dynamic> json) {
    return BlockCancellationDetail(
      blockId: json['block_id'] as int,
      blockAmount: (json['block_amount'] as num?)?.toDouble() ?? 0,
      blockPaidValue: (json['block_paid_value'] as num?)?.toDouble() ?? 0,
      cancellationFee: (json['cancellation_fee'] as num?)?.toDouble() ?? 0,
      refundAmount: (json['refund_amount'] as num?)?.toDouble() ?? 0,
      tier: json['tier'] as String? ?? '',
      hoursBeforeStart: (json['hours_before_start'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ServiceRequestResponse {
  final int id;
  final int serviceProviderId;
  final String responseStatus;
  final String responseStatusText;
  final String distanceKm;
  final int estimatedArrivalTime;
  final String userName;

  const ServiceRequestResponse({
    required this.id,
    required this.serviceProviderId,
    required this.responseStatus,
    required this.responseStatusText,
    required this.distanceKm,
    required this.estimatedArrivalTime,
    required this.userName,
  });

  bool get isPending => responseStatus == 'pending';
  bool get isAccepted => responseStatus == 'accepted';
  bool get isDeclined => responseStatus == 'declined';

  factory ServiceRequestResponse.fromJson(Map<String, dynamic> json) {
    return ServiceRequestResponse(
      id: json['id'] as int,
      serviceProviderId: json['service_provider_id'] as int,
      responseStatus: json['response_status'] as String? ?? '',
      responseStatusText: json['response_status_text'] as String? ?? '',
      distanceKm: json['distance_km'] as String? ?? '0',
      estimatedArrivalTime: json['estimated_arrival_time'] as int? ?? 0,
      userName: json['user_name'] as String? ?? 'Partner',
    );
  }
}
