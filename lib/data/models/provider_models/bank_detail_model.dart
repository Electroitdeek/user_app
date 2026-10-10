class BankDetail {
  final int id;
  final int serviceProviderId;
  final String accountHolderName;
  final String accountNumber;
  final String ifscCode;
  final String bankName;
  final String branchName;
  final String accountType;
  final bool isVerified;
  final bool isPrimary;
  final String? createdAt;
  final String? updatedAt;

  BankDetail({
    required this.id,
    required this.serviceProviderId,
    required this.accountHolderName,
    required this.accountNumber,
    required this.ifscCode,
    required this.bankName,
    required this.branchName,
    required this.accountType,
    required this.isVerified,
    required this.isPrimary,
    this.createdAt,
    this.updatedAt,
  });

  factory BankDetail.fromJson(Map<String, dynamic> json) {
    return BankDetail(
      id: json['id'] ?? 0,
      serviceProviderId: json['service_provider_id'] ?? 0,
      accountHolderName: json['account_holder_name'] ?? '',
      accountNumber: json['account_number'] ?? '',
      ifscCode: json['ifsc_code'] ?? '',
      bankName: json['bank_name'] ?? '',
      branchName: json['branch_name'] ?? '',
      accountType: json['account_type'] ?? '',
      isVerified: _toBool(json['is_verified']),
      isPrimary: _toBool(json['is_primary']),
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  static bool _toBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }
}
