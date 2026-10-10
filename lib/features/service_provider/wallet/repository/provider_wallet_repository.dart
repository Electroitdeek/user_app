import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/api/api_endpoints.dart';
import 'package:adhisaat_health_care/core/api/app_exception.dart';

import '../model/provider_wallet_model.dart';

class ProviderWalletRepository {
  final ApiClient _api;

  ProviderWalletRepository(this._api);

  /// The API client treats 4xx as a normal response (validateStatus < 500),
  /// so business failures arrive as `{status:false, message:...}`. Surface them
  /// as an [AppException] instead of silently succeeding.
  void _ensureSuccess(dynamic response) {
    if (response is Map &&
        (response['status'] == false || response['success'] == false)) {
      final message = (response['message'] as String?)?.trim();
      throw AppException(
        _cleanMoney(message?.isNotEmpty == true ? message! : 'Request failed. Please try again.'),
      );
    }
  }

  /// Rounds over-precise floats (e.g. `0.95000000000005`) in API messages to
  /// 2 decimals so amounts read cleanly.
  String _cleanMoney(String message) {
    return message.replaceAllMapped(RegExp(r'\d+\.\d{3,}'), (m) {
      final value = double.tryParse(m[0]!);
      return value != null ? value.toStringAsFixed(2) : m[0]!;
    });
  }

  Future<ProviderWalletData> getWalletBalance() async {
    final response = await _api.get(ApiEndpoints.providerWallet);
    return ProviderWalletData.fromJson(response['data'] ?? {});
  }

  Future<
    ({List<ProviderTransaction> transactions, TransactionPagination pagination})
  >
  getTransactions({int page = 1, int perPage = 10}) async {
    final response = await _api.get(
      ApiEndpoints.providerWalletTransactions,
      query: {'page': page.toString(), 'per_page': perPage.toString()},
    );

    final transactions = (response['data'] as List<dynamic>? ?? [])
        .map((j) => ProviderTransaction.fromJson(j as Map<String, dynamic>))
        .toList();

    final pagination = TransactionPagination.fromJson(
      response['pagination'] ?? {},
    );

    return (transactions: transactions, pagination: pagination);
  }

  Future<
    ({List<ProviderWithdrawal> withdrawals, TransactionPagination pagination})
  >
  getWithdrawals({int page = 1, int perPage = 15}) async {
    final response = await _api.get(
      ApiEndpoints.providerWithdrawals,
      query: {'page': page.toString(), 'per_page': perPage.toString()},
    );

    final withdrawals = (response['data'] as List<dynamic>? ?? [])
        .map((j) => ProviderWithdrawal.fromJson(j as Map<String, dynamic>))
        .toList();

    final pagination = TransactionPagination.fromJson(
      response['pagination'] ?? {},
    );

    return (withdrawals: withdrawals, pagination: pagination);
  }

  Future<void> requestWithdrawal(double amount) async {
    final response = await _api.post(ApiEndpoints.providerWithdrawalRequest, {
      'amount': amount.toString(),
    });
    _ensureSuccess(response);
  }

  Future<void> cancelWithdrawal(int id) async {
    final response = await _api.post(ApiEndpoints.providerWithdrawalCancel(id), {});
    _ensureSuccess(response);
  }
}
