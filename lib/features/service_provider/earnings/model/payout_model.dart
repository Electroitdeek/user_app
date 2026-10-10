import 'package:equatable/equatable.dart';

class PayoutModel {
  final int id;
  final String payoutNumber;
  final int serviceProviderId;
  final int bookingId;
  final int paymentId;
  final double serviceAmount;
  final double commissionAmount;
  final double netAmount;
  final double cashCollected;
  final double cashToRemit;
  final String cashSettlementStatus;
  final String? cashSettlementDueDate;
  final String payoutStatus;
  final String payoutMethod;
  final String payoutCycle;
  final String? transactionReference;
  final String? settlementReceipt;
  final String? processedAt;
  final String createdAt;
  final String updatedAt;
  final String payoutStatusText;
  final String? settlementReceiptUrl;
  final String? nextSettlementDate;
  final String? bookingNumber;

  const PayoutModel({
    required this.id,
    required this.payoutNumber,
    required this.serviceProviderId,
    required this.bookingId,
    required this.paymentId,
    required this.serviceAmount,
    required this.commissionAmount,
    required this.netAmount,
    required this.cashCollected,
    required this.cashToRemit,
    required this.cashSettlementStatus,
    this.cashSettlementDueDate,
    required this.payoutStatus,
    required this.payoutMethod,
    required this.payoutCycle,
    this.transactionReference,
    this.settlementReceipt,
    this.processedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.payoutStatusText,
    this.settlementReceiptUrl,
    this.nextSettlementDate,
    this.bookingNumber,
  });

  factory PayoutModel.fromJson(Map<String, dynamic> json) => PayoutModel(
    id: json['id'] ?? 0,
    payoutNumber: json['payout_number'] ?? '',
    serviceProviderId: json['service_provider_id'] ?? 0,
    bookingId: json['service_request_id'] ?? 0,
    paymentId: json['payment_id'] ?? 0,
    serviceAmount: _toDouble(json['service_amount']),
    commissionAmount: _toDouble(json['commission_amount']),
    netAmount: _toDouble(json['net_amount']),
    cashCollected: _toDouble(json['cash_collected']),
    cashToRemit: _toDouble(json['cash_to_remit']),
    cashSettlementStatus: json['cash_settlement_status'] ?? '',
    cashSettlementDueDate: json['cash_settlement_due_date'],
    payoutStatus: json['payout_status'] ?? '',
    payoutMethod: json['payout_method'] ?? '',
    payoutCycle: json['payout_cycle'] ?? '',
    transactionReference: json['transaction_reference'],
    settlementReceipt: json['settlement_receipt'],
    processedAt: json['processed_at'],
    createdAt: json['created_at'] ?? '',
    updatedAt: json['updated_at'] ?? '',
    payoutStatusText: json['payout_status_text'] ?? '',
    settlementReceiptUrl: json['settlement_receipt_url'],
    nextSettlementDate: json['next_settlement_date'],
    bookingNumber: json['booking'] is Map<String, dynamic>
        ? json['booking']['booking_number']
        : null,
  );

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

class PayoutPagination {
  final int total;
  final int currentPage;
  final int perPage;
  final int lastPage;

  const PayoutPagination({required this.total, required this.currentPage, required this.perPage, required this.lastPage});

  factory PayoutPagination.fromJson(Map<String, dynamic> json) => PayoutPagination(
    total: json['total'] ?? 0,
    currentPage: json['current_page'] ?? 1,
    perPage: json['per_page'] ?? 10,
    lastPage: json['last_page'] ?? 1,
  );

  bool get hasMore => currentPage < lastPage;
}

// ─── Filter / sort params ─────────────────────────────────────────
enum PayoutStatusFilter {
  all('', 'All'),
  pending('pending,hold,processing', 'Pending'),
  // processing('processing', 'Processing'),
  completed('completed', 'Completed');
  // failed('failed,cancelled', 'Failed');
  // cancelled('cancelled', 'Cancelled');

  final String value;
  final String label;
  const PayoutStatusFilter(this.value, this.label);
}

enum EarningSortField {
  createdAt('created_at', 'Date'),
  netAmount('net_amount', 'Amount'),
  serviceAmount('service_amount', 'Service Amount');

  final String value;
  final String label;
  const EarningSortField(this.value, this.label);
}

enum EarningSortDirection {
  desc('desc', 'Newest First'),
  asc('asc', 'Oldest First');

  final String value;
  final String label;
  const EarningSortDirection(this.value, this.label);
}

class EarningFilters {
  final String search;
  final PayoutStatusFilter status;
  final EarningSortField sortField;
  final EarningSortDirection sortDirection;
  final int page;
  final int perPage;

  const EarningFilters({
    this.search = '',
    this.status = PayoutStatusFilter.all,
    this.sortField = EarningSortField.createdAt,
    this.sortDirection = EarningSortDirection.desc,
    this.page = 1,
    this.perPage = 15,
  });

  EarningFilters copyWith({
    String? search,
    PayoutStatusFilter? status,
    EarningSortField? sortField,
    EarningSortDirection? sortDirection,
    int? page,
    int? perPage,
  }) => EarningFilters(
    search: search ?? this.search,
    status: status ?? this.status,
    sortField: sortField ?? this.sortField,
    sortDirection: sortDirection ?? this.sortDirection,
    page: page ?? this.page,
    perPage: perPage ?? this.perPage,
  );

  Map<String, dynamic> toQueryParams() => {
    'page': page.toString(),
    'per_page': perPage.toString(),
    'search': search,
    'payout_status': status == PayoutStatusFilter.completed ? 'completed,manual_completed' : status.value,
    'sort_field': sortField.value,
    'sort_direction': sortDirection.value,
  };

  bool get isFiltered => search.isNotEmpty || status != PayoutStatusFilter.all;
}

class EarningSummary extends Equatable {
  final int totalPayouts;
  final int pendingPayouts;
  final int completedPayouts;
  final double totalAmount;
  final double pendingAmount;
  final double completedAmount;

  const EarningSummary({
    required this.totalPayouts,
    required this.pendingPayouts,
    required this.completedPayouts,
    required this.totalAmount,
    required this.pendingAmount,
    required this.completedAmount,
  });

  const EarningSummary.empty()
      : totalPayouts = 0,
        pendingPayouts = 0,
        completedPayouts = 0,
        totalAmount = 0.0,
        pendingAmount = 0.0,
        completedAmount = 0.0;

  factory EarningSummary.fromJson(Map<String, dynamic> json) => EarningSummary(
        totalPayouts: json['total_paouts'] ?? 0,
        pendingPayouts: json['pending_paouts'] ?? 0,
        completedPayouts: json['completed_paouts'] ?? 0,
        totalAmount: _toDouble(json['total_amount']),
        pendingAmount: _toDouble(json['pending_amount']),
        completedAmount: _toDouble(json['completed_amount']),
      );

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  @override
  List<Object?> get props => [
        totalPayouts,
        pendingPayouts,
        completedPayouts,
        totalAmount,
        pendingAmount,
        completedAmount,
      ];
}
