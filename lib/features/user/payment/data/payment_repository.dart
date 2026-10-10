import 'dart:io';

import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/api/api_endpoints.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import '../../../../data/models/payment_order_result.dart';
import '../../payment_list/model/payment_model.dart';
import '../../service_booking/data/service_category_repository.dart';

class PaymentRepository {
  final ApiClient _apiClient;

  PaymentRepository(this._apiClient);

  Future<PaymentModel> getPaymentById(int id) async {
    try {
      final response = await _apiClient.get('${ApiEndpoints.userPayments}?payment_id=$id');
      final json = response as Map<String, dynamic>;
      final data = json['data'];

      // Array response: [{...}]
      if (data is List && data.isNotEmpty) {
        return PaymentModel.fromJson(data.first as Map<String, dynamic>);
      }
      // Single-object response: {"data": {...}}
      if (data is Map<String, dynamic>) {
        return PaymentModel.fromJson(data);
      }
      // Nested list: {"data": {"data": [{...}]}}
      if (data is Map) {
        final inner = data['data'];
        if (inner is List && inner.isNotEmpty) {
          return PaymentModel.fromJson(inner.first as Map<String, dynamic>);
        }
      }
      throw Exception('Payment not found');
    } catch (e) {
      kPrintError('PaymentRepository.getPaymentById: $e');
      rethrow;
    }
  }

  Future<PaymentsResponse> getPayments({
    int page = 1,
    String search = '',
    String status = '',
    int perPage = 15,
    String sortField = 'id',
    String sortDirection = 'desc',
  }) async {
    try {
      final params = <String, String>{
        'page': '$page',
        'per_page': '$perPage',
        'sort_field': sortField,
        'sort_direction': sortDirection,
        if (search.isNotEmpty) 'search': search,
        if (status.isNotEmpty) 'payment_type': status,
      };
      final query = params.entries
          .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');
      final response = await _apiClient.get('${ApiEndpoints.userPayments}?$query');
      return PaymentsResponse.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      kPrintError('PaymentRepository.getPayments: $e');
      rethrow;
    }
  }

  /// Confirms a booking when the payable amount is zero (promo/wallet covered).
  Future<Map<String, dynamic>> confirmBookingZeroAmount({
    required int serviceRequestId,
    required int customerProfileId,
    required int cityAdminId,
    required double basePrice,
    required double totalAmount,
    required double discountAmount,
    required double bonusAmountUsed,
    required double walletAmountUsed,
    required double amount, // always 0 in this flow
    String? promocode,
    int? promoCodeId,
    int? bookingId,
    List<int> paymentInstallmentIds = const [],
    String bookingType = 'service_booking',
    String paymentFor = 'booking_confirm',
    // legacy params kept for backward compat
    double distanceCharge = 0,
    double gstAmount = 0,
  }) async {
    try {
      final data = <String, dynamic>{
        if (bookingId != null) 'booking_id': bookingId.toString(),
        'service_request_id': serviceRequestId.toString(),
        'customer_profile_id': customerProfileId.toString(),
        'city_admin_id': cityAdminId.toString(),
        'booking_type': bookingType,
        'base_price': basePrice.toStringAsFixed(2),
        'total_amount': totalAmount.toStringAsFixed(2),
        if (promocode != null && promocode.isNotEmpty) 'promocode': promocode,
        if (promoCodeId != null && promoCodeId > 0) 'promocode_id': promoCodeId.toString(),
        'discount_amount': discountAmount.toStringAsFixed(2),
        'bonus_amount_used': bonusAmountUsed.toStringAsFixed(2),
        'wallet_amount_used': walletAmountUsed.toStringAsFixed(2),
        'amount': amount.toStringAsFixed(2),
        'payment_for': paymentFor,
      };
      for (int i = 0; i < paymentInstallmentIds.length; i++) {
        data['payment_installment_ids[$i]'] = paymentInstallmentIds[i].toString();
      }

      final res =
          await _apiClient.postMultipart(ApiEndpoints.bookingConfirmZeroAmount, data) as Map<String, dynamic>;

      // Surface known business errors (e.g. 409 service_request_cancelled) as a
      // dialog instead of a generic snackbar.
      if (res['status'] != true) {
        final errorType = res['error_type']?.toString();
        final message = switch (errorType) {
          'service_request_cancelled' =>
            'This booking has been cancelled and can no longer be confirmed. Please create a new booking to continue.',
          'service_not_accepted' =>
            'No partner has accepted your request yet. Payment will be available once a partner accepts.',
          _ => res['message']?.toString() ?? 'Booking confirmation failed. Please try again.',
        };
        final asDialog = errorType == 'service_request_cancelled' || errorType == 'service_not_accepted';
        throw PaymentApiException(message: message, showDialog: asDialog);
      }
      return res;
    } catch (e) {
      kPrintError('PaymentRepository.confirmBookingZeroAmount: $e');
      rethrow;
    }
  }

  /// Validates a promocode and returns discount info.
  Future<PromoResult> applyPromocode({
    required int serviceRequestId,
    required String promocode,
  }) async {
    try {
      final mongoId = await resolveCatalogMongoId(_apiClient, serviceRequestId);
      if (mongoId == null || mongoId.isEmpty) {
        throw Exception('Open this booking again, then apply the promo code.');
      }
      final res = await _apiClient.post('${ApiEndpoints.bookings}/$mongoId/promo', {
        'promoCode': promocode.trim().toUpperCase(),
      });
      final data = res is Map ? res['data'] : null;
      final booking = data is Map ? data['booking'] : null;
      if (booking is! Map) {
        throw Exception(res is Map ? res['message']?.toString() ?? 'Invalid promo code' : 'Invalid promo code');
      }
      final pricing = booking['pricing'] is Map ? Map<String, dynamic>.from(booking['pricing'] as Map) : const <String, dynamic>{};
      final discount = (pricing['promoDiscount'] as num?)?.toDouble() ?? 0;
      final total = (pricing['total'] as num?)?.toDouble() ?? 0;
      return PromoResult(
        payableAmount: total,
        discountAmount: discount,
        message: res is Map ? res['message']?.toString() ?? 'Promo applied' : 'Promo applied',
        promoCodeId: rememberCatalogId(booking['id']?.toString() ?? ''),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[PaymentRepo] applyPromocode error: $e');
      rethrow;
    }
  }

  /// Records a booking payment the same way admin does: method, amount, status, and reference.
  Future<Map<String, dynamic>> recordBookingPayment({
    required int serviceRequestId,
    required double amount,
    required String method,
    String gatewayRef = '',
  }) async {
    final mongoId = await resolveCatalogMongoId(_apiClient, serviceRequestId);
    if (mongoId == null || mongoId.isEmpty) {
      throw Exception('Open this booking again, then pay.');
    }
    final today = DateTime.now();
    final paidOn = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final online = method != 'CASH';
    final response = await _apiClient.post('${ApiEndpoints.bookings}/$mongoId/payments', {
      'method': method,
      'amount': amount,
      'status': online && gatewayRef.trim().isEmpty ? 'PENDING' : 'PAID',
      'paidOn': paidOn,
      'gatewayRef': gatewayRef.trim(),
      'notes': 'Recorded from the app',
    });
    if (response is! Map || response['success'] != true) {
      throw Exception(response is Map ? response['message']?.toString() ?? 'Could not record payment' : 'Could not record payment');
    }
    return Map<String, dynamic>.from(response);
  }

  /// Creates a Razorpay order via the regular booking payment initiate endpoint.
  Future<PaymentOrderResult> initiateRegularBookingPayment({
    required int serviceRequestId,
    required int customerProfileId,
    required int cityAdminId,
    required double amount,
    required double basePrice,
    required double totalAmount,
    required double discountAmount,
    required double walletAmountUsed,
    required double bonusAmountUsed,
    String? promocode,
    int? promoCodeId,
    int? bookingId,
    List<int> paymentInstallmentIds = const [],
    String bookingType = 'service_booking',
    String paymentFor = 'booking_confirm',
  }) async {
    final data = <String, dynamic>{
      'service_request_id': serviceRequestId.toString(),
      'customer_profile_id': customerProfileId.toString(),
      'city_admin_id': cityAdminId.toString(),
      if (bookingId != null) 'booking_id': bookingId.toString(),
      'base_price': basePrice.toStringAsFixed(2),
      'total_amount': totalAmount.toStringAsFixed(2),
      if (promocode != null && promocode.isNotEmpty) 'promocode': promocode,
      if (promoCodeId != null && promoCodeId > 0) 'promocode_id': promoCodeId.toString(),
      'discount_amount': discountAmount.toStringAsFixed(2),
      'bonus_amount_used': bonusAmountUsed.toStringAsFixed(2),
      'wallet_amount_used': walletAmountUsed.toStringAsFixed(2),
      'amount': amount.toStringAsFixed(2),
      'booking_type': bookingType,
      'payment_for': paymentFor,
    };

    for (int i = 0; i < paymentInstallmentIds.length; i++) {
      data['payment_installment_ids[$i]'] = paymentInstallmentIds[i].toString();
    }

    final res = await _apiClient.postMultipart(ApiEndpoints.regularBookingPaymentInitiate, data);
    kPrint(res);

    if (res['status'] == true && res['data'] != null) {
      final d = res['data'] as Map<String, dynamic>;
      return PaymentOrderResult(
        razorpayOrderId: (d['gateway_order_id'] ?? d['razorpay_order_id'] ?? '').toString(),
        amount: (d['amount'] as num?)?.toInt() ?? 0,
        currency: d['currency']?.toString() ?? 'INR',
        razorpayKey: d['razorpay_key']?.toString() ?? '',
        tempOrderId: (d['temp_order_id'] as num?)?.toInt() ?? 0,
      );
    } else {
      final errorType = res['error_type']?.toString();
      final message = switch (errorType) {
        'service_request_cancelled' => 'Your booking has been cancelled. Please create a new booking to continue.',
        'service_not_accepted' =>
          'No partner has accepted your request yet. Payment will be available once a partner accepts.',
        _ => res['message']?.toString() ?? 'Failed to create payment order',
      };
      final showDialog = errorType == 'service_request_cancelled' || errorType == 'service_not_accepted';
      throw PaymentApiException(message: message, showDialog: showDialog);
    }
  }

  /// Pays a pending installment. Returns a [PaymentOrderResult] when amount > 0
  /// (Razorpay flow), or null when amount == 0 (direct wallet/bonus confirmation).
  Future<Map<String, dynamic>> payPendingInstallments({
    required int serviceRequestId,
    required int customerProfileId,
    required int cityAdminId,
    required List<int> paymentInstallmentIds,
    required double basePrice,
    required double totalAmount,
    required double amount,
    String? promocode,
    int? promoCodeId,
    double discountAmount = 0,
    double bonusAmountUsed = 0,
    double walletAmountUsed = 0,
    String bookingType = 'installment_payment',
    String paymentFor = 'installment_payment',
  }) async {
    try {
      final data = <String, dynamic>{
        'service_request_id': serviceRequestId.toString(),
        'customer_profile_id': customerProfileId.toString(),
        'city_admin_id': cityAdminId.toString(),
        'base_price': basePrice.toStringAsFixed(2),
        'total_amount': totalAmount.toStringAsFixed(2),
        if (promocode != null && promocode.isNotEmpty) 'promocode': promocode,
        if (promoCodeId != null && promoCodeId > 0) 'promocode_id': promoCodeId.toString(),
        'discount_amount': discountAmount.toStringAsFixed(2),
        'bonus_amount_used': bonusAmountUsed.toStringAsFixed(2),
        'wallet_amount_used': walletAmountUsed.toStringAsFixed(2),
        'amount': amount.toStringAsFixed(2),
        'booking_type': bookingType,
        'payment_for': paymentFor,
      };
      for (int i = 0; i < paymentInstallmentIds.length; i++) {
        data['payment_installment_ids[$i]'] = paymentInstallmentIds[i].toString();
      }

      final res = await _apiClient.postMultipart(ApiEndpoints.payPendingInstallments, data);

      if (res['status'] != true) {
        throw Exception(res['message'] ?? 'Failed to process installment payment');
      }

      return res as Map<String, dynamic>;
    } catch (e) {
      kPrintError('PaymentRepository.payPendingInstallments: $e');
      rethrow;
    }
  }

  /// Creates a Razorpay order and returns order details.
  Future<PaymentOrderResult> initiatePayment({
    required int serviceRequestId,
    required int customerProfileId,
    required double amount,
    required double basePrice,
    required double distanceCharge,
    required double gstAmount,
    required double discountAmount,
    String? promocode,
    int? promoCodeId,
    int? bookingId,
    String bookingType = 'service_booking',
    double surgeMultiplier = 1.0,
    double walletAmountUsed = 0.0,
    double bonusAmountUsed = 0.0,
  }) async {
    final res = await _apiClient.postMultipart(ApiEndpoints.initiatePayment, {
      if (bookingId != null) 'booking_id': bookingId.toString(),
      'service_request_id': serviceRequestId.toString(),
      'customer_profile_id': customerProfileId.toString(),
      if (promoCodeId != null) 'promocode_id': promoCodeId.toString(),
      if (promocode != null && promocode.isNotEmpty) 'promocode': promocode,
      'booking_type': bookingType,
      'amount': amount.toStringAsFixed(2),
      'base_price': basePrice.toStringAsFixed(2),
      'distance_charge': distanceCharge.toStringAsFixed(2),
      'surge_multiplier': surgeMultiplier.toStringAsFixed(2),
      'gst_amount': gstAmount.toStringAsFixed(2),
      'discount_amount': discountAmount.toStringAsFixed(2),
      'wallet_amount_used': walletAmountUsed.toStringAsFixed(2),
      'bonus_amount_used': bonusAmountUsed.toStringAsFixed(2),
    });

    if (res['status'] == true && res['data'] != null) {
      final data = res['data'] as Map<String, dynamic>;
      return PaymentOrderResult(
        razorpayOrderId: (data['razorpay_order_id'] ?? data['gateway_order_id'] ?? '').toString(),
        amount: (data['amount'] as num?)?.toInt() ?? 0,
        currency: data['currency']?.toString() ?? 'INR',
        razorpayKey: data['razorpay_key']?.toString() ?? '',
        tempOrderId: (data['temp_order_id'] as num?)?.toInt() ?? 0,
      );
    } else {
      throw Exception(res['message'] ?? 'Failed to create payment order');
    }
  }

  /// Verifies the payment after Razorpay callback.
  Future<Map<String, dynamic>> verifyPayment({
    required int serviceRequestId,
    required int customerProfileId,
    required double amount,
    required double basePrice,
    required double distanceCharge,
    required double gstAmount,
    required double discountAmount,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
    String? promocode,
    int? promoCodeId,
    int? bookingId,
    String bookingType = 'service_booking',
    double walletAmountUsed = 0.0,
    double bonusAmountUsed = 0.0,
  }) async {
    final res = await _apiClient.postMultipart(ApiEndpoints.verifyPayment, {
      if (bookingId != null) 'booking_id': bookingId.toString(),
      'service_request_id': serviceRequestId.toString(),
      'customer_profile_id': customerProfileId.toString(),
      'booking_type': bookingType,
      'base_price': basePrice.toStringAsFixed(2),
      'distance_charge': distanceCharge.toStringAsFixed(2),
      'gst_amount': gstAmount.toStringAsFixed(2),
      'discount_amount': discountAmount.toStringAsFixed(2),
      'amount': amount.toStringAsFixed(2),
      if (promocode != null && promocode.isNotEmpty) 'promocode': promocode,
      if (promoCodeId != null && promoCodeId > 0) 'promo_code_id': promoCodeId.toString(),
      'wallet_amount_used': walletAmountUsed.toStringAsFixed(2),
      'bonus_amount_used': bonusAmountUsed.toStringAsFixed(2),
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_order_id': razorpayOrderId,
      'razorpay_signature': razorpaySignature,
    });
    return res as Map<String, dynamic>;
  }

  /// Notifies the server that a Razorpay payment has failed.
  Future<void> reportPaymentFailed({required String razorpayOrderId}) async {
    await _apiClient.post(ApiEndpoints.failedPayment, {'razorpay_order_id': razorpayOrderId});
  }

  /// Cancels an unpaid booking when user backs out of the payment screen.
  Future<void> cancelUnpaidBooking(int requestId) async {
    try {
      final mongoId = await resolveCatalogMongoId(_apiClient, requestId);
      if (mongoId == null || mongoId.isEmpty) return;
      await _apiClient.post('${ApiEndpoints.bookings}/$mongoId/cancel', {'reason': 'Left before payment'});
    } catch (e) {
      kPrintError('PaymentRepository.cancelUnpaidBooking: $e');
    }
  }

  /// Cancels a service request (booking).
  Future<bool> cancelBooking(int requestId) async {
    try {
      final mongoId = await resolveCatalogMongoId(_apiClient, requestId);
      if (mongoId == null || mongoId.isEmpty) return false;
      final response = await _apiClient.post('${ApiEndpoints.bookings}/$mongoId/cancel', {});
      final resMap = response as Map<String, dynamic>;
      return resMap['success'] == true || resMap['status'] == true;
    } catch (e) {
      kPrintError('PaymentRepository.cancelBooking: $e');
      rethrow;
    }
  }

  /// Downloads the invoice for a payment.
  /// This version handles direct file content in the response.
  /// Returns the local path where the file is saved.
  Future<String?> downloadInvoice(int paymentId, String paymentNumber) async {
    try {
      final res = await _apiClient.get(
        ApiEndpoints.invoiceDownload,
        query: {'payment_id': paymentId.toString()},
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (res is Uint8List) {
        final dir = await getTemporaryDirectory();
        final path = p.join(dir.path, "${paymentNumber}_invoice.pdf");
        final file = File(path);
        await file.writeAsBytes(res);
        return path;
      } else if (res is Map && res['status'] == true) {
        final url =
            res['download_url'] ??
            res['invoice_url'] ??
            res['url'] ??
            res['data']?['download_url'] ??
            res['data']?['invoice_url'] ??
            res['data']?['url'];

        return url?.toString();
      }
      return null;
    } catch (e) {
      kPrintError('PaymentRepository.downloadInvoice: $e');
      return null;
    }
  }

  /// Downloads the invoice for a payment.
  /// Returns the invoice download URL.
  Future<String?> getInvoiceUrl(int paymentId) async {
    try {
      final res = await _apiClient.postMultipart(
        ApiEndpoints.invoiceDownload,
        {},
        formData: FormData.fromMap({'payment_id': paymentId.toString()}),
      );

      if (res['status'] == true) {
        // Try various common keys
        final url =
            res['download_url'] ??
            res['invoice_url'] ??
            res['url'] ??
            res['data']?['download_url'] ??
            res['data']?['invoice_url'] ??
            res['data']?['url'];

        if (url != null) return url.toString();
      }
      return null;
    } catch (e) {
      kPrintError('PaymentRepository.getInvoiceUrl: $e');
      return null;
    }
  }

  Future<List<AvailablePromoCode>> getAvailablePromoCodes({int? serviceRequestId}) async {
    try {
      String path = '${ApiEndpoints.getPromoCodes}/available';
      if (serviceRequestId != null && serviceRequestId != 0) {
        final mongoId = await resolveCatalogMongoId(_apiClient, serviceRequestId);
        if (mongoId != null && mongoId.isNotEmpty) {
          path = '$path?bookingId=$mongoId';
        }
      }
      final res = await _apiClient.get(path);
      final data = res is Map ? res['data'] : null;
      final promoList = data is Map ? data['promoCodes'] : null;
      if (promoList is! List) return [];
      return promoList.whereType<Map>().map((row) {
        final item = Map<String, dynamic>.from(row);
        final type = item['discountType']?.toString() ?? '';
        final value = item['discountValue'];
        final valueText = type == 'PERCENTAGE' ? '$value%' : '₹$value';
        return AvailablePromoCode.fromJson({
          'id': rememberCatalogId(item['id']?.toString() ?? ''),
          'code': item['code'],
          'title': item['title'],
          'description': item['description'],
          'discount_type': type,
          'discount_type_text': type == 'PERCENTAGE' ? 'Percentage' : 'Fixed',
          'discount_value_text': valueText,
          'promo_type': item['promoType'],
          'promo_type_text': item['promoType'],
          'valid_from_formatted': item['validFrom'],
          'valid_until_formatted': (item['validUntil']?.toString().isNotEmpty ?? false) ? item['validUntil'] : 'No expiry',
          'min_order_value': item['minOrderValue'] ?? 0,
          'max_discount': item['maxDiscount'],
          'usage_limit_per_user': item['usageLimitPerUser'],
          'is_active': item['status'] == 'ACTIVE',
        });
      }).toList();
    } catch (e) {
      kPrintError('PaymentRepository.getAvailablePromoCodes error: $e');
      return [];
    }
  }
}

// ─── Result models ─────────────────────────────────────────────────────────

class PromoResult {
  final double payableAmount;
  final double discountAmount;
  final int promoCodeId;
  final String message;

  const PromoResult({
    required this.payableAmount,
    required this.discountAmount,
    required this.message,
    required this.promoCodeId,
  });
}

class AvailablePromoCode {
  final int id;
  final String code;
  final String? title;
  final String? description;
  final String? discountType;
  final String? discountTypeText;
  final String? discountValueText;
  final String? promoType;
  final String? promoTypeText;
  final String? validFromFormatted;
  final String? validUntilFormatted;
  final double minOrderValue;
  final double? maxDiscount;
  final int? usageLimitPerUser;
  final int? currentUsageCount;
  final bool isActive;
  final String? bannerImage;

  AvailablePromoCode({
    required this.id,
    required this.code,
    this.title,
    this.description,
    this.discountType,
    this.discountTypeText,
    this.discountValueText,
    this.promoType,
    this.promoTypeText,
    this.validFromFormatted,
    this.validUntilFormatted,
    this.minOrderValue = 0.0,
    this.maxDiscount,
    this.usageLimitPerUser,
    this.currentUsageCount,
    this.isActive = true,
    this.bannerImage,
  });

  String? get bannerImageUrl {
    if (bannerImage == null || bannerImage!.isEmpty) return null;
    if (!bannerImage!.startsWith('http')) {
      final base = AppConstants.baseUrl;
      final separator = (base.endsWith('/') || bannerImage!.startsWith('/')) ? '' : '/';
      return "$base$separator$bannerImage";
    }
    return bannerImage;
  }

  bool get isExpired {
    if (validUntilFormatted == null) return false;
    final lower = validUntilFormatted!.toLowerCase();
    if (lower.contains('no expiry')) return false;
    if (lower.contains('expired')) return true;

    final date = _parseDate(validUntilFormatted!);
    if (date == null) return false;
    return DateTime.now().isAfter(date);
  }

  bool get isExpiringSoon {
    if (isExpired) return false;
    if (validUntilFormatted == null) return false;
    final lower = validUntilFormatted!.toLowerCase();
    if (lower.contains('no expiry')) return false;

    final date = _parseDate(validUntilFormatted!);
    if (date == null) return false;
    // Expiring within 48 hours is "soon"
    return date.difference(DateTime.now()).inHours <= 48;
  }

  DateTime? _parseDate(String input) {
    try {
      // Handles formats like "24-03-2026 15:36" or "2026-03-24 15:36"
      final parts = input.split(' ');
      final datePart = parts[0];
      final timePart = parts.length > 1 ? parts[1] : "00:00";

      // Try dd-MM-yyyy
      if (datePart.contains('-')) {
        final dateBits = datePart.split('-');
        if (dateBits.length == 3) {
          int day, month, year;
          if (dateBits[0].length == 4) {
            // yyyy-MM-dd
            year = int.parse(dateBits[0]);
            month = int.parse(dateBits[1]);
            day = int.parse(dateBits[2]);
          } else {
            // dd-MM-yyyy
            day = int.parse(dateBits[0]);
            month = int.parse(dateBits[1]);
            year = int.parse(dateBits[2]);
          }
          final timeBits = timePart.split(':');
          int hour = 0, minute = 0;
          if (timeBits.length >= 2) {
            hour = int.parse(timeBits[0]);
            minute = int.parse(timeBits[1]);
          }
          return DateTime(year, month, day, hour, minute);
        }
      }
      return DateTime.tryParse(input);
    } catch (_) {
      return null;
    }
  }

  factory AvailablePromoCode.fromJson(Map<String, dynamic> json) {
    return AvailablePromoCode(
      id: json['id'] as int? ?? 0,
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      discountType: json['discount_type']?.toString(),
      discountTypeText: json['discount_type_text']?.toString(),
      discountValueText: json['discount_value_text']?.toString(),
      promoType: json['promo_type']?.toString(),
      promoTypeText: json['promo_type_text']?.toString(),
      validFromFormatted: json['valid_from_formatted']?.toString(),
      validUntilFormatted: json['valid_until_formatted']?.toString(),
      minOrderValue: double.tryParse(json['min_order_value']?.toString() ?? '0') ?? 0.0,
      maxDiscount: double.tryParse(json['max_discount']?.toString() ?? ''),
      usageLimitPerUser: json['usage_limit_per_user'] as int?,
      currentUsageCount: json['current_usage_count'] as int?,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      bannerImage: json['banner_image']?.toString(),
    );
  }
}

class PaymentApiException implements Exception {
  final String message;
  final bool showDialog;

  const PaymentApiException({required this.message, this.showDialog = false});

  @override
  String toString() => message;
}
