import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/api/api_endpoints.dart';

import '../models/system_settings_model.dart';

class SystemSettingsRepository {
  final ApiClient _apiClient;

  SystemSettingsRepository(this._apiClient);

  Future<SystemSettingsResponse> getSystemSettings() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.systemSettings);
      return SystemSettingsResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }
}
