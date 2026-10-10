import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/api/api_endpoints.dart';

import '../model/nearby_provider_model.dart';

class NearbyProviderRepository {
  final ApiClient _apiClient;

  NearbyProviderRepository(this._apiClient);

  /// Finds providers near [latitude]/[longitude] within [radiusKm] km for the
  /// given [serviceCategoryId].
  Future<List<NearbyProviderModel>> findNearbyProviders({
    required double latitude,
    required double longitude,
    int radiusKm = 50,
    required String serviceCategoryId,
    String? startDate,
    String? endDate,
    String? serviceType,
    String? shiftType,
  }) async {
    try {
      final response = await _apiClient.post(ApiEndpoints.findNearbyProviders, {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius_km': radiusKm.toString(),
        'service_category_id': serviceCategoryId.toString(),
        'start_date': ?startDate,
        'end_date': ?endDate,
        'service_type': ?serviceType,
        'shift_type': ?shiftType,
      });
      final parsed = NearbyProvidersResponse.fromJson(response as Map<String, dynamic>);
      if (!parsed.success) throw "Failed to find nearby providers";
      return parsed.providers;
    } catch (e) {
      kPrintError('NearbyProviderRepository.findNearbyProviders: $e');
      rethrow;
    }
  }
}
