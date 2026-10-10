class SubBlockDetailModel {
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
  final String? startOtp;
  final String status;
  final String statusText;
  final int requestStage;
  final String? actualStartTime;
  final String? actualEndTime;
  final String actualStartDateText;
  final String actualEndDateText;
  final double blockAmount;
  final double providerPayout;
  final String paymentStatus;
  final String? paidAt;
  final String? updatedAt;
  final SubBlockProvider? provider;
  final SubBlockBooking? booking;
  final List<CancellationRecord> cancellationRecords;
  final SubBlockRatingFeedback? ratingFeedback;

  const SubBlockDetailModel({
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
    this.startOtp,
    required this.status,
    required this.statusText,
    required this.requestStage,
    this.actualStartTime,
    this.actualEndTime,
    required this.actualStartDateText,
    required this.actualEndDateText,
    required this.blockAmount,
    required this.providerPayout,
    required this.paymentStatus,
    this.paidAt,
    this.updatedAt,
    this.provider,
    this.booking,
    required this.cancellationRecords,
    this.ratingFeedback,
  });

  bool get hasProvider => provider != null;

  factory SubBlockDetailModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return SubBlockDetailModel(
      id: data['id'] as int,
      serviceRequestId: data['service_request_id'] as int,
      bookingId: data['booking_id'] as int?,
      serviceProviderId: data['service_provider_id'] as int?,
      scheduledDate: data['scheduled_date'] as String? ?? '',
      scheduledDateText: data['scheduled_date_text'] as String? ?? '',
      scheduledStartTime: data['scheduled_start_time'] as String? ?? '',
      scheduledEndTime: data['scheduled_end_time'] as String? ?? '',
      scheduledStartTimeText: data['scheduled_start_time_text'] as String? ?? '',
      scheduledEndTimeText: data['scheduled_end_time_text'] as String? ?? '',
      startOtp: data['start_otp'] as String?,
      status: data['status'] as String? ?? '',
      statusText: data['status_text'] as String? ?? '',
      requestStage: data['request_stage'] as int? ?? 0,
      actualStartTime: data['actual_start_time'] as String?,
      actualEndTime: data['actual_end_time'] as String?,
      actualStartDateText: data['actual_start_date_text'] as String? ?? '-',
      actualEndDateText: data['actual_end_date_text'] as String? ?? '-',
      blockAmount: (data['block_amount'] as num?)?.toDouble() ?? 0,
      providerPayout: (data['provider_payout'] as num?)?.toDouble() ?? 0,
      paymentStatus: data['payment_status'] as String? ?? '',
      paidAt: data['paid_at'] as String?,
      updatedAt: data['updated_at'] as String?,
      provider: data['provider'] != null
          ? SubBlockProvider.fromJson(data['provider'] as Map<String, dynamic>)
          : null,
      booking: data['booking'] != null
          ? SubBlockBooking.fromJson(data['booking'] as Map<String, dynamic>)
          : null,
      cancellationRecords: (data['cancellation_records'] as List<dynamic>?)
              ?.map((e) => CancellationRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      ratingFeedback: data['rating_feedback'] != null
          ? SubBlockRatingFeedback.fromJson(data['rating_feedback'] as Map<String, dynamic>)
          : null,
    );
  }
}

class SubBlockProvider {
  final int id;
  final String fullName;
  final String? about;
  final String? highestQualification;
  final String totalExperience;
  final String totalExperienceText;
  final String dutyTypeText;
  final String verificationStatus;
  final String verificationStatusLabel;
  final double rating;
  final int totalRatings;
  final int totalJobsCompleted;
  final ProviderUser? user;

  const SubBlockProvider({
    required this.id,
    required this.fullName,
    this.about,
    this.highestQualification,
    required this.totalExperience,
    required this.totalExperienceText,
    required this.dutyTypeText,
    required this.verificationStatus,
    required this.verificationStatusLabel,
    required this.rating,
    required this.totalRatings,
    required this.totalJobsCompleted,
    this.user,
  });

  bool get isVerified => verificationStatus.toLowerCase() == 'approved';

  String get initials => fullName
      .trim()
      .split(' ')
      .take(2)
      .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
      .join();

  factory SubBlockProvider.fromJson(Map<String, dynamic> json) {
    return SubBlockProvider(
      id: json['id'] as int,
      fullName: json['full_name'] as String? ?? '',
      about: json['about'] as String?,
      highestQualification: json['highest_qualification'] as String?,
      totalExperience: json['total_experience'] as String? ?? '',
      totalExperienceText: json['total_experience_text'] as String? ?? '',
      dutyTypeText: json['duty_type_text'] as String? ?? '',
      verificationStatus: json['verification_status'] as String? ?? '',
      verificationStatusLabel: json['verification_status_label'] as String? ?? '',
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      totalRatings: json['total_ratings'] as int? ?? 0,
      totalJobsCompleted: json['total_jobs_completed'] as int? ?? 0,
      user: json['user'] != null
          ? ProviderUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ProviderUser {
  final int id;
  final String name;
  final String? mobileNumber;
  final String? profileImageUrl;

  const ProviderUser({
    required this.id,
    required this.name,
    this.mobileNumber,
    this.profileImageUrl,
  });

  factory ProviderUser.fromJson(Map<String, dynamic> json) {
    return ProviderUser(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      mobileNumber: json['mobile_number'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
    );
  }
}

class SubBlockBooking {
  final int id;
  final String bookingNumber;
  final String bookingStatus;
  final String bookingStatusText;

  const SubBlockBooking({
    required this.id,
    required this.bookingNumber,
    required this.bookingStatus,
    required this.bookingStatusText,
  });

  factory SubBlockBooking.fromJson(Map<String, dynamic> json) {
    return SubBlockBooking(
      id: json['id'] as int,
      bookingNumber: json['booking_number'] as String? ?? '',
      bookingStatus: json['booking_status'] as String? ?? '',
      bookingStatusText: json['booking_status_text'] as String? ?? '',
    );
  }
}

class CancellationRecord {
  final String? reason;
  final String? cancelledBy;
  final String? cancelledAt;
  final String? cancelledByType;

  const CancellationRecord({
    this.reason,
    this.cancelledBy,
    this.cancelledAt,
    this.cancelledByType,
  });

  factory CancellationRecord.fromJson(Map<String, dynamic> json) {
    return CancellationRecord(
      reason: json['reason'] as String?,
      cancelledBy: json['cancelled_by'] as String?,
      cancelledAt: json['cancelled_at'] as String?,
      cancelledByType: json['cancelled_by_type'] as String?,
    );
  }
}

class SubBlockRatingFeedback {
  final int id;
  final int bookingId;
  final int? bookingSubBlockId;
  final int rating;
  final String? feedbackComment;
  final int? punctualityRating;
  final int? behaviorRating;
  final int? skillRating;
  final bool isComplaint;
  final String? createdAt;

  const SubBlockRatingFeedback({
    required this.id,
    required this.bookingId,
    this.bookingSubBlockId,
    required this.rating,
    this.feedbackComment,
    this.punctualityRating,
    this.behaviorRating,
    this.skillRating,
    this.isComplaint = false,
    this.createdAt,
  });

  factory SubBlockRatingFeedback.fromJson(Map<String, dynamic> json) {
    return SubBlockRatingFeedback(
      id: json['id'] as int? ?? 0,
      bookingId: json['booking_id'] as int? ?? 0,
      bookingSubBlockId: json['booking_sub_block_id'] as int?,
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
