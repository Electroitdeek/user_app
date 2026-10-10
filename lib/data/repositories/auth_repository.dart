import 'dart:io';

import 'package:adhisaat_health_care/core/api/api_endpoints.dart';
import 'package:adhisaat_health_care/core/services/device_service.dart';
import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/app_exception.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/error_constants.dart';
import '../../core/storage/local_storage_service.dart';
import '../models/user_profile_model.dart';
import '../../features/user/service_booking/data/service_category_repository.dart';
import '../models/dropdown_response_model.dart';
import '../models/service_availability_model.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final LocalStorageService _storage;

  AuthRepository(this._apiClient, this._storage);

  Future<void> logout() async {
    try {
      final rawId = await DeviceService.getPersistentDeviceId();
      final deviceType = Platform.isIOS ? 'ios' : 'android';
      final formattedDeviceId = "${deviceType == 'android' ? 'AND' : 'IOS'}-$rawId";

      final response = await _apiClient.post(ApiEndpoints.logout, {'device_id': formattedDeviceId});
      return response;
    } catch (e) {
      kPrintError("Error on logout: $e");
    }
  }

  Future<dynamic> sendOtp({required String mobile, bool isResend = false}) async {
    return _apiClient.post(ApiEndpoints.sendOtp, {'mobile': mobile});
  }

  Future<dynamic> verifyOtp({required String mobile, required String otp}) async {
    try {
      return await _apiClient.post(ApiEndpoints.verifyOtp, {'mobile': mobile, 'code': otp});
    } on AppException catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('401') || errorMessage.toLowerCase().contains('unauthorized')) {
        errorMessage = ErrorConstants.invalidOtp;
      }
      throw AppException(errorMessage);
    }
  }

  /// Email or 10-digit mobile plus password. Same contract as the website and admin panel.
  Future<UserProfileModel> loginWithPassword({required String identifier, required String password}) async {
    final raw = identifier.trim();
    final Map<String, dynamic> body = {'password': password};
    if (raw.contains('@')) {
      body['email'] = raw.toLowerCase();
    } else {
      body['mobile'] = raw.replaceAll(RegExp(r'\D'), '');
    }

    final response = await _apiClient.post(ApiEndpoints.login, body);
    if (response is! Map || response['success'] != true) {
      final message = response is Map ? response['message']?.toString() : null;
      throw AppException(message?.isNotEmpty == true ? message! : 'Could not log in');
    }

    final data = response['data'];
    if (data is! Map) throw AppException('Could not log in');
    final token = data['token']?.toString() ?? '';
    final user = data['user'];
    if (token.isEmpty || user is! Map) throw AppException('Could not log in');

    final profile = legacyProfileFromApiUser(Map<String, dynamic>.from(user));
    final model = UserProfileModel.fromJson(profile);
    final isVendor = (user['userType']?.toString().toUpperCase() == 'VENDOR') || model.hasProviderRole;
    if (AppConstants.isProviderApp && !isVendor) {
      throw AppException('This account is not a partner account.');
    }
    if (!AppConstants.isProviderApp && isVendor && !model.hasCustomerRole) {
      throw AppException('Partner accounts sign in on the partner app.');
    }

    await _storage.saveToken(token);
    await _storage.saveUserProfile(profile);
    return model;
  }

  Future<dynamic> saveDeviceToken({required String fcmToken, required String deviceId, required String deviceType}) async {
    try {
      final userType = AppConstants.isProviderApp ? 'service_provider' : 'customer';
      final response = await _apiClient.post(ApiEndpoints.saveDeviceToken, {
        'device_token': fcmToken,
        'device_id': deviceId,
        'device_type': deviceType,
        'user_type': userType,
      });
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> registerProvider(FormData providerData) async {
    providerData.fields.map((k) {
      kPrint("$k");
    });
    try {
      final response = await _apiClient.postMultipart(ApiEndpoints.registerProvider, {}, formData: providerData);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> registerUser(dynamic data) async {
    if (data is FormData) {
      final fields = <String, dynamic>{};
      for (final field in data.fields) {
        fields[field.key] = field.value;
      }
      fields['role'] = AppConstants.isProviderApp ? 'PROVIDER' : 'CUSTOMER';
      fields['termsAccepted'] = true;
      return _apiClient.post(ApiEndpoints.registerUser, fields);
    }
    final body = Map<String, dynamic>.from(data as Map);
    body.putIfAbsent('role', () => 'CUSTOMER');
    body['termsAccepted'] = true;
    return _apiClient.post(ApiEndpoints.registerUser, body);
  }

  Future<DropdownResponse> fetchDropdowns() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.dropdown);
      return DropdownResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> validateReferralCode(String code, {String? userType}) async {
    try {
      final Map<String, dynamic> data = {'referral_code': code};
      if (userType != null) data['user_type'] = userType;

      final token = await _storage.token;
      final Map<String, dynamic> headers = {};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _apiClient.postMultipart(
        ApiEndpoints.validateReferralCode,
        data,
        options: Options(followRedirects: false, validateStatus: (status) => status != null && status < 500, headers: headers),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<ServiceAvailabilityResponse> checkServiceAvailability(
    String zipcode, {
    bool excludeManMachineServices = false,
  }) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.catalogServices);
      final data = response is Map ? response['data'] : null;
      final rows = data is Map && data['services'] is List ? data['services'] as List : const [];
      final categories = rows.whereType<Map>().toList().asMap().entries.map((entry) {
        final row = Map<String, dynamic>.from(entry.value);
        final mongoId = row['id']?.toString() ?? '';
        final icon = row['hasIcon'] == true ? catalogIconUrl('services', mongoId) : null;
        return ServiceCategory(
          id: rememberCatalogId(mongoId),
          categoryName: row['title']?.toString() ?? '',
          categorySlug: row['slug']?.toString(),
          description: row['description']?.toString(),
          iconUrl: icon,
          iconImageUrl: icon,
          isActive: row['isOn'] != false,
          isEmergency: row['bookingRequestType']?.toString() == 'EMERGENCY',
          displayOrder: entry.key,
          fullCategoryName: row['title']?.toString() ?? '',
        );
      }).toList();

      final emergencyOn = categories.any((item) => item.isEmergency);
      return ServiceAvailabilityResponse(
        status: true,
        message: 'OK',
        data: ServiceAvailabilityData(
          cityAdmin: CityAdmin.fromJson({
            'id': 0,
            'city_id': 0,
            'owner_user_id': 0,
            'is_emergency_service_enabled': emergencyOn ? 1 : 0,
          }),
          serviceCategories: categories,
        ),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> fetchConsents(String type, {int? cityAdminId}) async {
    try {
      final Map<String, dynamic> data = {'consent_type': type};
      if (cityAdminId != null) {
        data['city_admin_id'] = cityAdminId.toString();
      }
      final response = await _apiClient.postMultipart(ApiEndpoints.consents, data);
      return response;
    } catch (e) {
      rethrow;
    }
  }
}

/// Maps the website / admin user payload into the profile shape this app already reads.
Map<String, dynamic> legacyProfileFromApiUser(Map<String, dynamic> user) {
  final first = user['firstName']?.toString() ?? '';
  final last = user['lastName']?.toString() ?? '';
  final name = [first, last].where((part) => part.isNotEmpty).join(' ');
  final userType = user['userType']?.toString().toUpperCase() ?? '';
  final isVendor = userType == 'VENDOR';
  final roleName = isVendor ? 'service_provider' : 'customer';
  final roles = (user['roles'] as List?)?.map((role) {
        final record = role is Map ? role : <String, dynamic>{};
        final slug = record['slug']?.toString() ?? '';
        final name = slug == 'vendor' || slug == 'service_provider' ? 'service_provider' : 'customer';
        return {
          'id': record['id'],
          'name': name,
          'label': record['name'] ?? name,
          'is_active': true,
          'pivot': <String, dynamic>{},
        };
      }).toList() ??
      [
        {'name': roleName, 'label': roleName, 'is_active': true, 'pivot': <String, dynamic>{}},
      ];

  return {
    'id': user['id'],
    'api_user_id': user['id'],
    'name': name,
    'mobile_number': user['mobile'] ?? '',
    'whatsapp_number': user['whatsapp'],
    'email': user['email'] ?? '',
    'user_type': isVendor ? 'service_provider' : 'customer',
    'is_active': user['status'] == 'ACTIVE',
    'is_verified': user['isVerified'] == true,
    'is_blocked': user['status'] == 'BLOCKED',
    'gender': user['gender'],
    'date_of_birth': user['dateOfBirth'],
    'blood_group': user['bloodGroup'],
    'aadhar_no': user['aadhaarNumber'],
    'profile_image': user['profileImage'],
    'primary_role': roleName,
    'code': user['code'],
    'roles': roles,
    'created_at': user['createdAt']?.toString() ?? '',
    'updated_at': user['updatedAt']?.toString() ?? '',
  };
}
