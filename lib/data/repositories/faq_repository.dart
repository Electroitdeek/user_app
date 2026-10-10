import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/constants/app_constants.dart';
import '../models/faq_model.dart';

class FaqRepository {
  final ApiClient _apiClient;

  FaqRepository(this._apiClient);

  Future<FaqResponse> getFaqs() async {
    try {
      final category = AppConstants.isProviderApp ? 'services' : 'general';
      final response = await _apiClient.get(
        ApiEndpoints.faqs,
        query: {'category': category},
      );
      return FaqResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }
}
