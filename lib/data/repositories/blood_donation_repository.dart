import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/api/api_endpoints.dart';

import '../../features/blood_donor/blood_request/data/model/blood_request_model.dart';
import '../../features/blood_donor/donor_profile/data/model/donor_profile_model.dart';

class BloodDonationRepository {
  final ApiClient _apiClient;

  BloodDonationRepository(this._apiClient);

  Future<DonorProfile> getDonorProfile() async {
    try {
      // Adding a timestamp to bust potential cache on some network layers
      final response = await _apiClient.get(
        '${ApiEndpoints.getDonorProfile}?t=${DateTime.now().millisecondsSinceEpoch}',
      );
      return DonorProfile.fromJson(response['data']);
    } catch (e) {
      throw Exception('Failed to load donor profile: $e');
    }
  }

  Future<void> updateDonorProfile(DonorProfile profile) async {
    try {
      final formData = profile.toJson();

      final response = await _apiClient.post(ApiEndpoints.addUpdateDonorProfile, formData);
      if (response['status'] == false) {
        throw Exception(response['message'] ?? 'Failed to update donor profile');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Blood Request APIs
  Future<List<BloodRequest>> getBloodRequests({
    required String? bloodGroup,
    String? city,
    String? urgency,
    String? requestStatus,
    String? sortField,
    String? userId,
  }) async {
    try {
      final queryParams = {
        'blood_group': bloodGroup ?? 'null',
        'city': city ?? 'null',
        'urgency': urgency ?? 'null',
        'request_status': requestStatus ?? 'null',
        'sort_field': sortField ?? 'null',
        'user_id': userId ?? 'null',
      };

      final response = await _apiClient.get(ApiEndpoints.getBloodRequest, query: queryParams);

      final List<dynamic> data = response['data'] ?? [];
      return data.map((json) => BloodRequest.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load blood requests: $e');
    }
  }

  Future<void> addOrUpdateBloodRequest(BloodRequest request) async {
    try {
      final formData = request.toFormData();

      final response = await _apiClient.post(ApiEndpoints.addUpdateBloodRequest, formData);
      if (response['status'] == false) {
        throw Exception(response['message'] ?? 'Failed to submit blood request');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
