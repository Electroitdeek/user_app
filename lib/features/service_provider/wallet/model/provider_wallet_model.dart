class ProviderWalletResponse {
  final bool status;
  final String message;
  final ProviderWalletData data;

  ProviderWalletResponse({required this.status, required this.message, required this.data});

  factory ProviderWalletResponse.fromJson(Map<String, dynamic> json) {
    return ProviderWalletResponse(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
      data: ProviderWalletData.fromJson(json['data'] ?? {}),
    );
  }
}

class ProviderWalletData {
  final double availableBalance;
  final double lockedBalance;
  final double pendingBalance;
  final double totalBalance;
  final bool isNegative;
  final ProviderWalletDetails wallet;

  ProviderWalletData({
    required this.availableBalance,
    required this.lockedBalance,
    required this.pendingBalance,
    required this.totalBalance,
    required this.isNegative,
    required this.wallet,
  });

  factory ProviderWalletData.fromJson(Map<String, dynamic> json) {
    return ProviderWalletData(
      availableBalance: double.tryParse(json['available_balance']?.toString() ?? '0') ?? 0.0,
      lockedBalance: double.tryParse(json['locked_balance']?.toString() ?? '0') ?? 0.0,
      pendingBalance: double.tryParse(json['pending_balance']?.toString() ?? '0') ?? 0.0,
      totalBalance: double.tryParse(json['total_balance']?.toString() ?? '0') ?? 0.0,
      isNegative: json['is_negative'] ?? false,
      wallet: ProviderWalletDetails.fromJson(json['wallet'] ?? {}),
    );
  }
}

class ProviderWalletDetails {
  final int id;
  final int serviceProviderId;
  final String availableBalance;
  final String lockedBalance;
  final String pendingBalance;
  final String createdAt;
  final String updatedAt;

  ProviderWalletDetails({
    required this.id,
    required this.serviceProviderId,
    required this.availableBalance,
    required this.lockedBalance,
    required this.pendingBalance,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProviderWalletDetails.fromJson(Map<String, dynamic> json) {
    return ProviderWalletDetails(
      id: json['id'] ?? 0,
      serviceProviderId: json['service_provider_id'] ?? 0,
      availableBalance: json['available_balance']?.toString() ?? '0.00',
      lockedBalance: json['locked_balance']?.toString() ?? '0.00',
      pendingBalance: json['pending_balance']?.toString() ?? '0.00',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }
}

class ProviderTransaction {
  final int id;
  final int providerWalletId;
  final String transactionType;
  final double amount;
  final String status;
  final String? referenceType;
  final String? referenceId; // reference_id can be string or int in JSON sometimes, safer as String?
  final String description;
  final double balanceAfter;
  final String createdAt;
  final String updatedAt;
  final int? createdBy;

  ProviderTransaction({
    required this.id,
    required this.providerWalletId,
    required this.transactionType,
    required this.amount,
    required this.status,
    this.referenceType,
    this.referenceId,
    required this.description,
    required this.balanceAfter,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  factory ProviderTransaction.fromJson(Map<String, dynamic> json) {
    return ProviderTransaction(
      id: json['id'] ?? 0,
      providerWalletId: json['provider_wallet_id'] ?? 0,
      transactionType: json['transaction_type'] ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      status: json['status'] ?? '',
      referenceType: json['reference_type']?.toString(),
      referenceId: json['reference_id']?.toString(),
      description: json['description'] ?? '',
      balanceAfter: double.tryParse(json['balance_after']?.toString() ?? '0') ?? 0.0,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      createdBy: json['created_by'],
    );
  }
}

class ProviderWithdrawal {
  final int id;
  final int? userId;
  final int serviceProviderId;
  final double amount;
  final String status;
  final String? receiptFile;
  final String? remark;
  final String? transactionNumber;
  final int? actionBy;
  final String? actionAt;
  final String createdAt;
  final String updatedAt;

  ProviderWithdrawal({
    required this.id,
    this.userId,
    required this.serviceProviderId,
    required this.amount,
    required this.status,
    this.receiptFile,
    this.remark,
    this.transactionNumber,
    this.actionBy,
    this.actionAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProviderWithdrawal.fromJson(Map<String, dynamic> json) {
    return ProviderWithdrawal(
      id: json['id'] ?? 0,
      userId: json['user_id'],
      serviceProviderId: json['service_provider_id'] ?? 0,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      status: json['status']?.toString() ?? '',
      receiptFile: json['receipt_file']?.toString(),
      remark: json['remark']?.toString(),
      transactionNumber: json['transaction_number']?.toString(),
      actionBy: json['action_by'],
      actionAt: json['action_at']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }
}

class TransactionPagination {
  final int total;
  final int currentPage;
  final int perPage;
  final int lastPage;

  TransactionPagination({
    required this.total,
    required this.currentPage,
    required this.perPage,
    required this.lastPage,
  });

  factory TransactionPagination.fromJson(Map<String, dynamic> json) {
    return TransactionPagination(
      total: json['total'] ?? 0,
      currentPage: json['current_page'] ?? 1,
      perPage: json['per_page'] ?? 15,
      lastPage: json['last_page'] ?? 1,
    );
  }
}
