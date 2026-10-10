import '../../../../core/constants/app_constants.dart';

class PaymentModel {
  final int id;
  final String paymentNumber;
  final String? requestNumber;
  final int? bookingId;
  final String? transactionId;
  final double subtotal;
  final double distanceCharge;
  final double surgeCharge;
  final double discountAmount;
  final double gstAmount;
  final double totalAmount;
  final String? paymentMethod;
  final String? paymentGateway;
  final String status;
  final double walletAmountUsed;
  final double bonusAmountUsed;
  final String? serviceCategoryName;
  final String? serviceCategoryIconUrl;
  final String? refundId;
  final double? refundAmount;
  final String? refundedAt;
  final String? paidAt;
  final double? basePrice;
  final String createdAt;

  final String? invoiceUrl;
  final String? paymentType;
  final String? refundStatus;
  final String? refundGatewayReference;
  final String? paymentFor;
  final String? paymentMethodOriginal;
  final double? totalPenaltyApplied;
  final double? refundedToOnline;
  final int? cancelledSubBlocksCount;

  /// Child refund transactions linked to this payment (`refund_payments`).
  final List<PaymentModel> refundPayments;

  // Legacy compat
  double get amount => totalAmount;

  int? get serviceRequestId => bookingId;

  bool get hasRefunds => refundPayments.isNotEmpty;

  bool get isRefundTxn => paymentType == 'refund';

  /// Amount to display as the headline value. Some records (e.g. wallet
  /// refunds) carry `total_amount = 0` while the real value sits in `subtotal`.
  double get displayAmount => totalAmount > 0 ? totalAmount : subtotal;

  PaymentModel({
    required this.id,
    required this.paymentNumber,
    this.requestNumber,
    this.bookingId,
    this.transactionId,
    required this.subtotal,
    required this.distanceCharge,
    required this.surgeCharge,
    required this.discountAmount,
    required this.gstAmount,
    required this.totalAmount,
    this.paymentMethod,
    this.paymentGateway,
    required this.status,
    this.walletAmountUsed = 0.0,
    this.bonusAmountUsed = 0.0,
    this.serviceCategoryName,
    this.serviceCategoryIconUrl,
    this.refundId,
    this.refundAmount,
    this.refundedAt,
    this.paidAt,
    required this.createdAt,
    this.basePrice,
    this.invoiceUrl,
    this.paymentType,
    this.refundStatus,
    this.refundGatewayReference,
    this.paymentFor,
    this.paymentMethodOriginal,
    this.totalPenaltyApplied,
    this.refundedToOnline,
    this.cancelledSubBlocksCount,
    this.refundPayments = const [],
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    double d(String key) {
      final val = json[key];
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    double? nd(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    int? toInt(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val);
      return null;
    }

    // Failed/expired payments carry amounts inside `booking_payload` rather
    // than as top-level columns.
    double payloadD(String key) {
      final p = json['booking_payload'];
      if (p is Map) {
        final v = p[key];
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v) ?? 0.0;
      }
      return 0.0;
    }

    double firstPositive(List<double> values) => values.firstWhere((v) => v > 0, orElse: () => 0.0);

    return PaymentModel(
      id: toInt(json['id']) ?? 0,
      paymentNumber: json['payment_number']?.toString() ?? '',
      requestNumber:
          json['request_number']?.toString() ??
          json['service_request']?['request_number']?.toString() ??
          json['booking']?['request_number']?.toString(),
      bookingId: toInt(json['service_request_id']) ?? toInt(json['service_request']?['id']),
      transactionId: json['transaction_id']?.toString(),
      subtotal: firstPositive([d('subtotal'), payloadD('total_amount'), d('amount'), payloadD('amount')]),
      distanceCharge: d('distance_charge'),
      surgeCharge: d('surge_charge'),
      discountAmount: d('discount_amount'),
      gstAmount: d('gst_amount'),
      totalAmount: firstPositive([
        d('total_amount'),
        payloadD('total_amount'),
        d('amount'),
        payloadD('amount'),
        d('subtotal'),
      ]),
      paymentMethod: json['payment_method']?.toString(),
      paymentGateway: json['payment_gateway']?.toString(),
      status: json['payment_status']?.toString() ?? json['status']?.toString() ?? 'pending',
      walletAmountUsed: d('wallet_amount_used') + d('wallet_amount'),
      bonusAmountUsed: d('bonus_amount_used') + d('bonus_wallet_amount'),
      serviceCategoryName:
          (json['booking']?['service_category'] as Map<String, dynamic>?)?['category_name']?.toString() ??
          json['service_request']?['service']?['name']?.toString() ??
          json['service_category_name']?.toString(),
      serviceCategoryIconUrl:
          (json['booking']?['service_category'] as Map<String, dynamic>?)?['icon_image_url']?.toString() ??
          json['service_request']?['service']?['icon_image_url']?.toString(),
      refundId: json['refund_id']?.toString(),
      refundAmount: nd(json['refund_amount']),
      refundedAt: json['refunded_at']?.toString(),
      paidAt: json['paid_at']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      basePrice:
          nd(json['booking']?['service_request']?['base_price']) ?? nd(json['service_request']?['base_price']),
      invoiceUrl: _parseInvoiceUrl(json),
      paymentType: json['payment_type']?.toString(),
      refundStatus: json['refund_status']?.toString(),
      refundGatewayReference: json['refund_gateway_reference']?.toString(),
      paymentFor: json['payment_for']?.toString(),
      paymentMethodOriginal: json['payment_method']?.toString(),
      totalPenaltyApplied: nd(json['service_request']?['total_penalty_applied']),
      refundedToOnline: nd(json['service_request']?['refunded_to_online']),
      cancelledSubBlocksCount: toInt(json['cancelled_sub_blocks_count']),
      refundPayments:
          (json['refund_payments'] as List<dynamic>?)
              ?.map((e) => PaymentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  static String? _parseInvoiceUrl(Map<String, dynamic> json) {
    String? url =
        json['invoice_url']?.toString() ??
        json['invoice']?.toString() ??
        json['invoice_pdf']?.toString() ??
        json['invoice_path']?.toString() ??
        json['booking']?['invoice_url']?.toString() ??
        json['booking']?['invoice']?.toString();

    if (url == null || url.isEmpty) return null;

    if (!url.startsWith('http')) {
      final base = AppConstants.baseUrl;
      final separator = (base.endsWith('/') || url.startsWith('/')) ? '' : '/';
      return "$base$separator$url";
    }
    return url;
  }

  bool get isSuccess => status == 'completed' || status == 'success' || status == 'paid';

  bool get isFailed => status == 'failed' || status == 'cancelled' || status == 'expired';

  bool get isPending => !isSuccess && !isFailed;

  bool get isRefunded => refundId != null && refundId!.isNotEmpty;

  bool get hasInvoice => invoiceUrl != null && invoiceUrl!.isNotEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────

class PaymentsResponse {
  final bool success;
  final List<PaymentModel> payments;
  final int total;
  final int currentPage;
  final int lastPage;

  PaymentsResponse({
    required this.success,
    required this.payments,
    required this.total,
    required this.currentPage,
    required this.lastPage,
  });

  factory PaymentsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    List<dynamic> list = [];
    int total = 0;
    int currentPage = 1;
    int lastPage = 1;

    if (data is List) {
      // New API: data is a plain list + separate pagination object
      list = data;
      final pagination = json['pagination'] as Map<String, dynamic>?;
      total = pagination?['total'] as int? ?? list.length;
      currentPage = pagination?['current_page'] as int? ?? 1;
      lastPage = pagination?['last_page'] as int? ?? 1;
    } else if (data is Map) {
      // Legacy: data.data nested list
      list = data['data'] as List<dynamic>? ?? [];
      total = data['total'] as int? ?? 0;
      currentPage = data['current_page'] as int? ?? 1;
      lastPage = data['last_page'] as int? ?? 1;
    }

    return PaymentsResponse(
      success: json['success'] == true || json['status'] == true,
      payments: list.map((e) => PaymentModel.fromJson(e as Map<String, dynamic>)).toList(),
      total: total,
      currentPage: currentPage,
      lastPage: lastPage,
    );
  }
}
