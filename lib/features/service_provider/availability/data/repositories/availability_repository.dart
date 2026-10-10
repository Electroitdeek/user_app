import '../../../../../core/api/api_client.dart';
import '../../../../../core/api/api_endpoints.dart';
import '../../../../../di/locator.dart';
import '../models/weekly_availability_model.dart';

class AvailabilityRepository {
  final ApiClient _apiClient = locator<ApiClient>();

  Future<WeeklyAvailability> getWeeklyAvailability() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.getWeeklyAvailability);
      if (response['status'] == true) {
        final data = response['data'];
        if (data == null || (data is List && data.isEmpty)) {
          return WeeklyAvailability(availability: WeeklyAvailability.defaultWeek());
        }
        
        if (data is List) {
          return WeeklyAvailability.fromJson({'availability': data});
        }
        
        if (data is Map<String, dynamic>) {
          if (data.containsKey('availability')) {
            return WeeklyAvailability.fromJson(data);
          } else {
            return WeeklyAvailability.fromJson({'availability': data});
          }
        }

        return WeeklyAvailability(availability: WeeklyAvailability.defaultWeek());
      } else {
        throw Exception(response['message'] ?? "Failed to fetch availability");
      }
    } catch (e) {
      kPrint("Error fetching availability: $e");
      rethrow;
    }
  }

  Future<void> updateWeeklyAvailability(WeeklyAvailability availability) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.updateWeeklyAvailability,
        availability.toJson(),
      );
      if (response['status'] != true) {
        throw Exception(response['message'] ?? "Failed to update availability");
      }
    } catch (e) {
      kPrint("Error updating availability: $e");
      rethrow;
    }
  }
}
