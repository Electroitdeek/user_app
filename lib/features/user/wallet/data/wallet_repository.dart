import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/api/api_endpoints.dart';
import 'package:dio/dio.dart';
import '../../../../data/models/payment_order_result.dart';

class WalletRepository {
  final ApiClient _apiClient;

  WalletRepository(this._apiClient);

  /// Initiates wallet top-up.
  Future<PaymentOrderResult> initiateWalletTopUp({required int userId, required double amount}) async {
    final res = await _apiClient.postMultipart(ApiEndpoints.addMoneyToWalletInitiate, {
      'user_id': userId.toString(),
      'amount': amount.toStringAsFixed(2),
    });
    kPrint(res);
    if (res['status'] == true && res['data'] != null) {
      final data = res['data'] as Map<String, dynamic>;
      
      // Check if the gateway is razorpay
      if (data['gateway'] != 'razorpay') {
        throw Exception('Unsupported gateway: ${data['gateway']}');
      }

      return PaymentOrderResult(
        razorpayOrderId: data['gateway_order_id'] as String,
        amount: (data['amount'] as num).toInt(),
        currency: data['currency'] as String? ?? 'INR',
        razorpayKey: data['razorpay_key'] as String,
        tempOrderId: (data['temp_order_id'] as num).toInt(),
        bookingId: data['booking_id'] != null ? (data['booking_id'] as num).toInt() : null,
        serviceRequestId: data['service_request_id'] != null ? (data['service_request_id'] as num).toInt() : null,
        bookingType: data['booking_type']?.toString(),
        promocode: data['promocode']?.toString(),
      );
    } else {
      throw Exception(res['message'] ?? 'Failed to initiate wallet top-up');
    }
  }

  /// Verifies the wallet top-up payment.
  /// Using the generic verify endpoint as requested by user.
  Future<Map<String, dynamic>> verifyWalletTopUp({
    required int bookingId,
    required int serviceRequestId,
    required int customerProfileId,
    required String bookingType,
    required double basePrice,
    required double distanceCharge,
    required double gstAmount,
    required double discountAmount,
    required double amount,
    required String promocode,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    final res = await _apiClient.postMultipart(
      ApiEndpoints.verifyPayment,
      {},
      formData: FormData.fromMap({
        'booking_id': bookingId.toString(),
        'service_request_id': serviceRequestId.toString(),
        'customer_profile_id': customerProfileId.toString(),
        'booking_type': bookingType,
        'base_price': basePrice.toStringAsFixed(2),
        'distance_charge': distanceCharge.toStringAsFixed(2),
        'gst_amount': gstAmount.toStringAsFixed(2),
        'discount_amount': discountAmount.toStringAsFixed(2),
        'amount': amount.toStringAsFixed(2),
        'promocode': promocode,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_order_id': razorpayOrderId,
        'razorpay_signature': razorpaySignature,
      }),
    );
    return res;
  }

  /// Fetches wallet transaction history.
  Future<Map<String, dynamic>> fetchWalletTransactions({int page = 1, int perPage = 20}) async {
    final res = await _apiClient.postMultipart(
      ApiEndpoints.walletTransactions,
      {},
      formData: FormData.fromMap({'page': page.toString(), 'per_page': perPage.toString()}),
    );
    return res;
  }
}
