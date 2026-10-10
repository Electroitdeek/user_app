import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/api/api_endpoints.dart';
import 'package:dio/dio.dart';

class ExtendBookingRepository {
  final ApiClient _apiClient;

  ExtendBookingRepository(this._apiClient);

  // ── Step 1: Calculate quotation ──────────────────────────────────────────
  Future<ExtendPriceResult> calculatePrice({
    required int serviceRequestId,
    required int customerProfileId,
    required String serviceType,
    required String endDate,
    required String extendEndDate,
    int? durationDays,
    int? durationHours,
  }) async {
    try {
      final res = await _apiClient.postMultipart(
        ApiEndpoints.extendPriceCalculate,
        {},
        formData: FormData.fromMap({
          'service_request_id': serviceRequestId.toString(),
          'customer_profile_id': customerProfileId.toString(),
          'service_type': serviceType,
          'end_date': endDate,
          'extend_end_date': extendEndDate,
          'duration_days': durationDays?.toString() ?? '',
          'duration_hours': durationHours?.toString() ?? '',
        }),
      );

      if (res['success'] == true && res['data'] != null) {
        return ExtendPriceResult.fromJson(res['data'] as Map<String, dynamic>);
      }
      throw Exception(res['message'] ?? 'Failed to calculate price');
    } catch (e) {
      kPrintError('ExtendBookingRepository.calculatePrice: $e');
      rethrow;
    }
  }

  // ── Step 2: Initiate extend order → get Razorpay order ──────────────────
  Future<ExtendOrderResult> initiateExtend({
    required int serviceRequestId,
    required int bookingId,
    required String serviceType,
    required String endDate,
    required String extendEndDate,
    int? durationDays,
    int? durationHours,
    required double amount,
    String? promocode,
    String? promocodeId,
    String? discountAmount,
  }) async {
    try {
      final res = await _apiClient.postMultipart(
        ApiEndpoints.initiateExtendPrice,
        {},
        formData: FormData.fromMap({
          'service_request_id': serviceRequestId.toString(),
          'booking_id': bookingId.toString(),
          'service_type': serviceType,
          'end_date': endDate,
          'extend_end_date': extendEndDate,
          'duration_days': durationDays?.toString() ?? '',
          'duration_hours': durationHours?.toString() ?? '',
          'amount': amount.toStringAsFixed(2),
          'promocode': promocode ?? '',
          'promocode_id': promocodeId ?? '',
          'discount_amount': discountAmount ?? '',
        }),
      );

      if (res['status'] == true && res['data'] != null) {
        return ExtendOrderResult.fromJson(res['data'] as Map<String, dynamic>);
      }
      throw Exception(res['message'] ?? 'Failed to initiate extend payment');
    } catch (e) {
      kPrintError('ExtendBookingRepository.initiateExtend: $e');
      rethrow;
    }
  }

  // ── Step 3: Verify payment ───────────────────────────────────────────────
  // NOTE: verify endpoint for extend only requires customer_profile_id,
  // booking_type, price fields and razorpay fields — no booking_id/service_request_id
  Future<bool> verifyPayment({
    required int customerProfileId,
    required double amount,
    required double basePrice,
    required double distanceCharge,
    required double gstAmount,
    required double discountAmount,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
    String bookingType = 'service_booking',
  }) async {
    try {
      final res = await _apiClient.postMultipart(
        ApiEndpoints.verifyPayment,
        {},
        formData: FormData.fromMap({
          'customer_profile_id': customerProfileId.toString(),
          'booking_type': bookingType,
          'base_price': basePrice.toStringAsFixed(2),
          'distance_charge': distanceCharge.toStringAsFixed(2),
          'gst_amount': gstAmount.toStringAsFixed(2),
          'discount_amount': discountAmount.toStringAsFixed(2),
          'amount': amount.toStringAsFixed(2),
          'razorpay_payment_id': razorpayPaymentId,
          'razorpay_order_id': razorpayOrderId,
          'razorpay_signature': razorpaySignature,
        }),
      );
      return res['status'] == true;
    } catch (e) {
      kPrintError('ExtendBookingRepository.verifyPayment: $e');
      rethrow;
    }
  }
}

// ─── Result models ─────────────────────────────────────────────────────────

class ExtendPriceResult {
  final double basePrice;
  final double distanceCharge;
  final double gstAmount;
  final double totalAmount;
  final double gstPercentage;
  final String? serviceType;
  final int? durationDays;
  final int? durationHours;

  const ExtendPriceResult({
    required this.basePrice,
    required this.distanceCharge,
    required this.gstAmount,
    required this.totalAmount,
    required this.gstPercentage,
    this.serviceType,
    this.durationDays,
    this.durationHours,
  });

  factory ExtendPriceResult.fromJson(Map<String, dynamic> json) {
    // Actual response is flat — all fields are directly on `data`
    // gstAmount (camelCase) is the actual key returned by the API
    return ExtendPriceResult(
      basePrice: (json['base_price'] ?? json['service_charge'] ?? 0).toDouble(),
      distanceCharge: (json['distance_charge'] ?? 0).toDouble(),
      gstAmount: (json['gstAmount'] ?? json['gst_amount'] ?? 0).toDouble(),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      gstPercentage: (json['gst_percentage'] ?? 18).toDouble(),
      serviceType: json['service_type'] as String?,
      durationDays: json['duration_days'] as int?,
      durationHours: json['duration_hours'] as int?,
    );
  }
}

class ExtendOrderResult {
  final String razorpayOrderId;
  final int amount; // in paise
  final String currency;
  final String razorpayKey;
  final int? bookingId;
  final int? tempOrderId;

  const ExtendOrderResult({
    required this.razorpayOrderId,
    required this.amount,
    required this.currency,
    required this.razorpayKey,
    this.bookingId,
    this.tempOrderId,
  });

  factory ExtendOrderResult.fromJson(Map<String, dynamic> json) {
    return ExtendOrderResult(
      razorpayOrderId: json['razorpay_order_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      razorpayKey: json['razorpay_key'] as String? ?? '',
      bookingId: json['booking_id'] as int?,
      tempOrderId: (json['temp_order_id'] as num?)?.toInt(),
    );
  }
}