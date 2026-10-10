import 'dart:io';

import 'package:adhisaat_health_care/core/api/app_exception.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../data/models/user_profile_model.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../service_provider/feedback/data/model/feedback_model.dart';

class UserProfileRepository {
  final ApiClient _apiClient;
  final LocalStorageService _storage;

  UserProfileRepository(this._apiClient, this._storage);

  Future<FeedbackResponse> getAppFeedback() async {
    try {
      final response = await _apiClient.postMultipart(
        ApiEndpoints.appFeedback,
        {'customer_profile_id': _storage.customerUserId?.toString() ?? ''},
      );
      return FeedbackResponse.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      kPrintError('getAppFeedback error: $e');
      throw Exception('Failed to fetch feedback: $e');
    }
  }

  Future<bool> saveAppFeedback({
    required int rating,
    required String feedbackType,
    required String feedbackText,
  }) async {
    try {
      final response = await _apiClient
          .postMultipart(ApiEndpoints.saveAppFeedback, {
            'customer_profile_id': _storage.customerUserId?.toString() ?? '',
            'rating': rating.toString(),
            'feedback_type': feedbackType,
            'feedback_text': feedbackText,
          });
      return response['status'] == true;
    } catch (e) {
      kPrintError('saveAppFeedback error: $e');
      throw Exception('Failed to save feedback: $e');
    }
  }

  Future<UserProfileModel> getProfile() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.currentUser);
      final data = response is Map ? response['data'] : null;
      final user = data is Map && data['user'] is Map ? data['user'] as Map : data;
      final profileJson = legacyProfileFromApiUser(Map<String, dynamic>.from(user as Map));
      final profile = UserProfileModel.fromJson(profileJson);
      await _storage.saveUserProfile(profileJson);
      return profile;
    } catch (e) {
      final cached = await _storage.getUserProfile();
      if (cached != null) return UserProfileModel.fromJson(cached);
      rethrow;
    }
  }

  /// Updates the customer profile via multipart/form-data.
  /// Pass [profileImage], [aadharFile], [panFile] as [File] if the user picked new ones.
  Future<UserProfileModel> updateProfile({
    required String name,
    required String mobileNumber,
    String? whatsappNumber,
    String? email,
    String? dateOfBirth, // yyyy-MM-dd
    String? bloodGroup,
    String? gender, // male | female | other
    String? emergencyContactName,
    String? emergencyContactNumber,
    String? aadharNo,
    String? panNumber,
    File? profileImage,
    File? aadharFile,
    File? panFile,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'name': name,
        'mobile': mobileNumber,
        if (whatsappNumber != null && whatsappNumber.isNotEmpty) 'whatsapp': whatsappNumber,
        if (email != null && email.isNotEmpty) 'email': email,
        if (dateOfBirth != null && dateOfBirth.isNotEmpty) 'dateOfBirth': dateOfBirth,
        if (bloodGroup != null && bloodGroup.isNotEmpty) 'bloodGroup': bloodGroup,
        if (gender != null && gender.isNotEmpty) 'gender': gender.toUpperCase(),
        if (emergencyContactName != null && emergencyContactName.isNotEmpty)
          'emergencyContactName': emergencyContactName,
        if (emergencyContactNumber != null && emergencyContactNumber.isNotEmpty)
          'emergencyContactNumber': emergencyContactNumber,
        if (aadharNo != null && aadharNo.isNotEmpty) 'aadhaarNumber': aadharNo,
      };

      final res = await ApiClient.put(ApiEndpoints.currentUser, data);

      if (res is Map && res['success'] == true && res['data'] is Map && (res['data'] as Map)['user'] is Map) {
        final profileJson = legacyProfileFromApiUser(
          Map<String, dynamic>.from((res['data'] as Map)['user'] as Map),
        );
        final profile = UserProfileModel.fromJson(profileJson);
        await _storage.saveUserProfile(profileJson);
        return profile;
      }

      throw AppException(
        res['message'] ?? 'Failed to update profile',
        errors: res['errors'] is Map
            ? (res['errors'] as Map<String, dynamic>)
            : null,
      );
    } catch (e) {
      kPrintError('UpdateProfileRepository.updateProfile: $e');
      rethrow;
    }
  }
}
