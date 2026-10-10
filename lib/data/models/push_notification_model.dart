class PushNotificationResponse {
  final bool? success;
  final String? message;
  final List<PushNotificationModel>? data;

  PushNotificationResponse({this.success, this.message, this.data});

  factory PushNotificationResponse.fromJson(Map<String, dynamic> json) {
    return PushNotificationResponse(
      success: json['success'],
      message: json['message'],
      data: json['data'] != null
          ? (json['data'] as List).map((i) => PushNotificationModel.fromJson(i)).toList()
          : null,
    );
  }
}

class PushNotificationModel {
  final int? id;
  final int? userId;
  final String? notificationType;
  final String? title;
  final String? message;
  final PushNotificationData? data;
  final bool? isRead;
  final String? readAt;
  final String? sentVia;
  final String? createdAt;

  PushNotificationModel({
    this.id,
    this.userId,
    this.notificationType,
    this.title,
    this.message,
    this.data,
    this.isRead,
    this.readAt,
    this.sentVia,
    this.createdAt,
  });

  factory PushNotificationModel.fromJson(Map<String, dynamic> json) {
    return PushNotificationModel(
      id: json['id'],
      userId: json['user_id'],
      notificationType: json['notification_type'],
      title: json['title'],
      message: json['message'],
      data: json['data'] != null ? PushNotificationData.fromJson(json['data']) : null,
      isRead: json['is_read'],
      readAt: json['read_at'],
      sentVia: json['sent_via'],
      createdAt: json['created_at'],
    );
  }
}

class PushNotificationData {
  final String? type;
  final String? requestId;
  final String? serviceRequestId;
  final String? bookingId;
  final String? bookingSubBlockId;
  final String? bookingNumber;
  final String? customerId;
  final String? providerId;
  final String? providerName;
  final String? providerMobile;
  final String? amount;
  final String? validUntil;
  final String? couponCode;
  final String? notificationId;
  final String? priority;
  final String? body;
  final String? referredToId;

  PushNotificationData({
    this.type,
    this.requestId,
    this.serviceRequestId,
    this.bookingId,
    this.bookingSubBlockId,
    this.bookingNumber,
    this.customerId,
    this.providerId,
    this.providerName,
    this.providerMobile,
    this.amount,
    this.validUntil,
    this.couponCode,
    this.notificationId,
    this.priority,
    this.body,
    this.referredToId,
  });

  factory PushNotificationData.fromJson(Map<String, dynamic> json) {
    return PushNotificationData(
      type: json['type']?.toString(),
      requestId: json['request_id']?.toString(),
      serviceRequestId: json['service_request_id']?.toString(),
      bookingId: json['booking_id']?.toString(),
      bookingSubBlockId: json['booking_sub_block_id']?.toString() ?? json['sub_block_id']?.toString(),
      bookingNumber: json['booking_number']?.toString(),
      customerId: json['customer_id']?.toString(),
      providerId: json['provider_id']?.toString(),
      providerName: json['provider_name'],
      providerMobile: json['provider_mobile'],
      amount: json['amount']?.toString(),
      validUntil: json['valid_until']?.toString(),
      couponCode: json['coupon_code']?.toString(),
      notificationId: json['notification_id']?.toString(),
      priority: json['priority']?.toString(),
      body: json['body']?.toString(),
      referredToId: json['referred_to_id']?.toString(),
    );
  }
}
