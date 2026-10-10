import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/api/api_endpoints.dart';
import 'package:adhisaat_health_care/data/models/dropdown_response_model.dart';

class DropdownRepository {
  final ApiClient _apiClient;

  DropdownRepository(this._apiClient);

  Future<DropdownData> getDropdownData() async {
    final response = await _apiClient.get(ApiEndpoints.dropdown);
    final dropdownResponse = DropdownResponse.fromJson(response);
    return dropdownResponse.data;
  }
}
