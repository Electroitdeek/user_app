import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/api/api_endpoints.dart';
import 'package:adhisaat_health_care/core/api/app_exception.dart';

import '../../service_booking/data/service_category_repository.dart';
import '../model/user_address_model.dart';

class UserAddressRepository {
  final ApiClient _apiClient;

  UserAddressRepository(this._apiClient);

  // ── List ─────────────────────────────────────────────────────────────────
  Future<List<UserAddressModel>> getAddresses() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.getCustomerAddresses);
      final data = response is Map ? response['data'] : null;
      final rawList = data is Map && data['addresses'] is List
          ? data['addresses'] as List
          : data is List
          ? data
          : const [];
      return rawList.whereType<Map>().map((row) => UserAddressModel.fromJson(Map<String, dynamic>.from(row))).toList();
    } catch (e) {
      kPrintError('UserAddressRepository.getAddresses: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _addressBody(UserAddressModel address) {
    final label = (address.addressType ?? 'home').toLowerCase();
    return {
      'label': label == 'work' ? 'Work' : label == 'other' ? 'Other' : 'Home',
      'fullAddress': address.fullAddress,
      'area': address.area ?? '',
      'city': address.city ?? '',
      'state': address.state ?? '',
      'pincode': address.pinCode ?? '',
      'latitude': double.tryParse(address.latitude ?? '') ?? 0,
      'longitude': double.tryParse(address.longitude ?? '') ?? 0,
      'isDefault': address.isDefault,
    };
  }

  // ── Add / Update ──────────────────────────────────────────────────────────
  Future<bool> addOrUpdateAddress(UserAddressModel address) async {
    try {
      final response = address.mongoId == null || address.mongoId!.isEmpty
          ? await _apiClient.post(ApiEndpoints.getCustomerAddresses, _addressBody(address))
          : await ApiClient.put('${ApiEndpoints.getCustomerAddresses}/${address.mongoId}', _addressBody(address));
      kPrint(response);

      // 422/validation responses come back with status<500, so they land here
      // as a body rather than an exception. Treat non-success as a failure and
      // surface a friendly, user-facing message (not the raw API text).
      final ok = response['status'] == true || response['success'] == true;
      if (!ok) {
        throw Exception(_friendlyError(response));
      }
      return true;
    } catch (e) {
      kPrintError('UserAddressRepository.addOrUpdateAddress: $e');
      rethrow;
    }
  }

  String _friendlyError(Map<String, dynamic> response) {
    final errors = response['errors'];
    if (errors is Map && errors.isNotEmpty) {
      if (errors.containsKey('address_type')) {
        return 'Please choose a valid address label (Home, Work or Other) and try again.';
      }
      // Any other validation issue on a specific field.
      return 'Some details look incorrect. Please review the address and try again.';
    }
    return "We couldn't save this address. Please check the details and try again.";
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<bool> deleteAddress(int id) async {
    try {
      final known = catalogMongoByInt[id];
      if (known == null || known.isEmpty) return false;
      final response = await ApiClient.delete('${ApiEndpoints.getCustomerAddresses}/$known');
      final success = response['success'] == true || response['status'] == true;
      if (!success) {
        throw AppException(response['message']?.toString() ?? "Couldn't delete this address.");
      }
      return true;
    } catch (e) {
      kPrintError('UserAddressRepository.deleteAddress: $e');
      rethrow;
    }
  }
}
