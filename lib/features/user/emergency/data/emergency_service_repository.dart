import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../service_booking/model/service_category_model.dart';

class EmergencyServiceRepository {
  final ApiClient _apiClient;

  EmergencyServiceRepository(this._apiClient);

  Future<List<ServiceCategoryModel>> getEmergencyServices({required String city}) async {
    final response = await _apiClient.get(
      ApiEndpoints.get_service_categories_with_price,
      query: {'is_emergency': '1', 'city': city},
    );

    if (response['status'] == true && response['data'] != null) {
      final res = ServiceCategoriesResponse.fromJson(response);
      return res.data;
    } else {
      throw Exception(response['message'] ?? 'Failed to fetch emergency services');
    }
  }
}
