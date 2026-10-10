import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/api/api_endpoints.dart';

import '../model/payout_model.dart';

class EarningsRepository {
  final ApiClient _api;
  EarningsRepository(this._api);

  Future<({List<PayoutModel> payouts, PayoutPagination pagination, EarningSummary summary})> getEarnings(
      EarningFilters filters,
      ) async {
    final response = await _api.get(
      ApiEndpoints.providerEarnings,
      query: filters.toQueryParams(),
    );
    final list = (response['data'] as List<dynamic>? ?? [])
        .map((j) => PayoutModel.fromJson(j as Map<String, dynamic>))
        .toList();
    final pagination = PayoutPagination.fromJson(
      response['pagination'] as Map<String, dynamic>? ?? {},
    );
    final summary = EarningSummary.fromJson(
      response['summary'] as Map<String, dynamic>? ?? {},
    );
    return (payouts: list, pagination: pagination, summary: summary);
  }
}