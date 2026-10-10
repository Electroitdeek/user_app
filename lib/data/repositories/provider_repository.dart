import 'dart:io';

import 'package:adhisaat_health_care/core/api/api_endpoints.dart';
import 'package:adhisaat_health_care/core/storage/local_storage_service.dart';
import 'package:adhisaat_health_care/data/models/user_profile_model.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/app_exception.dart';
import '../../features/service_provider/document/data/model/document_model.dart';
import '../../features/service_provider/feedback/data/model/feedback_model.dart';
import '../../features/service_provider/provider_home/data/models/provider_dashboard.dart';
import '../../features/service_provider/provider_home/data/models/service_request.dart';
import '../models/payment_order_result.dart';
import '../models/provider_models/bank_detail_model.dart';
import '../models/provider_models/provider_profile_payload_model.dart';
import 'auth_repository.dart';

class ProviderRepository {
  final ApiClient _apiClient;
  final LocalStorageService _storageService;

  ProviderRepository(this._apiClient, this._storageService);

  Future<void> updateCurrentLocation({required double latitude, required double longitude}) async {
    try {
      await _apiClient.post(ApiEndpoints.updateProviderCurrentLocation, {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      });
      // return response;
    } catch (e) {
      // rethrow;
    }
  }

  Future<ProviderDashboard> getProviderDashboard() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.providerDashboardData);
      return ProviderDashboard.fromJson(response['data'] ?? {});
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> updateIsAvailable(bool isEnable) async {
    try {
      final payload = {"is_available": isEnable ? "1" : "0"};
      final response = await _apiClient.post(ApiEndpoints.updateIsAvailableProvider, payload);
      return response['status'] ?? true;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserProfileModel> getProfile() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.currentUser);
      final data = response is Map ? response['data'] : null;
      final user = data is Map && data['user'] is Map ? data['user'] as Map : data;
      return UserProfileModel.fromJson(legacyProfileFromApiUser(Map<String, dynamic>.from(user as Map)));
    } catch (e) {
      kPrintError("Getting error on loading profile: $e");
      rethrow;
    }
  }

  Future<DocumentResponse> fetchDocuments() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.documentList);
      return DocumentResponse.fromJson(response);
    } catch (e) {
      kPrintError('Failed to fetch documents: $e');
      throw Exception('Failed to fetch documents');
    }
  }

  Future<bool> deleteDocument(String documentId) async {
    try {
      final response = await _apiClient.post('${ApiEndpoints.deleteDocument}/$documentId', {});
      return response['status'] == true;
    } catch (e) {
      kPrintError('Failed to delete document: $e');
      throw Exception('Failed to delete document: $e');
    }
  }

  Future<bool> addOrUpdateDocument({
    String? id,
    required String documentType,
    required String documentName,
    String? documentNumber,
    DateTime? issueDate,
    DateTime? expiryDate,
    File? documentFile,
  }) async {
    try {
      final issue = issueDate != null ? DateFormat('yyyy-MM-dd').format(issueDate) : null;
      final expiry = expiryDate != null ? DateFormat('yyyy-MM-dd').format(expiryDate) : null;
      final payload = {
        if (id != null) 'id': id.toString(),
        'service_provider_id': _storageService.serviceProvideUserId?.toString() ?? '',
        'document_type': documentType,
        'document_name': documentName,
        'document_number': documentNumber ?? '',
        'issue_date': issue ?? '',
        'expiry_date': expiry ?? '',
        if (documentFile != null)
          'document_file': await MultipartFile.fromFile(
            documentFile.path,
            filename: documentFile.path.split('/').last,
          ),
      };
      kPrint("Document Payload: $payload");
      final response = await _apiClient.postMultipart(ApiEndpoints.addUpdateDocument, payload);
      kPrint("Document Response: $response");
      kPrintError(response);
      if (response is Map && response['status'] == true) {
        return true;
      }
      // 422 / validation failures return a body (validateStatus < 500) instead
      // of throwing, so surface the server-provided message to the caller.
      throw AppException(_extractErrorMessage(response));
    } on AppException {
      rethrow;
    } catch (e) {
      kPrintError('Failed to add/update document: $e');
      throw AppException('Failed to add/update document');
    }
  }

  /// Pull a human-readable message out of a Laravel-style error body:
  /// `{ message, errors: { field: [msg, ...] } }`.
  String _extractErrorMessage(dynamic response) {
    if (response is Map) {
      final errors = response['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
        return first.toString();
      }
      if (response['message'] != null) return response['message'].toString();
    }
    return 'Failed to add/update document';
  }

  Future<dynamic> updateProfile({
    required ProviderProfileModel profile,
    File? profileImage,
    File? aadharFile,
    File? panFile,
    List<String>? skills,
  }) async {
    try {
      FormData formData = FormData.fromMap({
        if (profile.name != null) 'name': profile.name,
        if (profile.mobileNumber != null) 'mobile_number': profile.mobileNumber,
        if (profile.whatsappNumber != null) 'whatsapp_number': profile.whatsappNumber,
        if (profile.email != null) 'email': profile.email,
        if (profile.dateOfBirth != null) 'date_of_birth': profile.dateOfBirth,
        if (profile.bloodGroup != null) 'blood_group': profile.bloodGroup,
        if (profile.highestQualification != null) 'highest_qualification': profile.highestQualification,
        if (profile.professionalRegistrationNumber != null)
          'professional_registration_number': profile.professionalRegistrationNumber,
        if (profile.councilBoardName != null) 'council_board_name': profile.councilBoardName,
        if (profile.totalExperience != null) 'total_experience': profile.totalExperience,
        if (profile.previousWorkplace != null) 'previous_workplace': profile.previousWorkplace,
        if (profile.preferredWorkingArea != null) 'preferred_working_area': profile.preferredWorkingArea,
        if (profile.gender != null) 'gender': profile.gender,
        if (profile.about != null) 'about': profile.about,
        if (profile.aadharNo != null) 'aadhar_no': profile.aadharNo,
        if (profile.panNumber != null) 'pan_number': profile.panNumber,
      });

      // Add duty types as array
      if (profile.dutyType != null) {
        for (int i = 0; i < profile.dutyType!.length; i++) {
          formData.fields.add(MapEntry('duty_type[$i]', profile.dutyType![i]));
        }
      }

      // Add skills as array
      if (skills != null) {
        for (int i = 0; i < skills.length; i++) {
          formData.fields.add(MapEntry('skills[$i]', skills[i]));
        }
      }

      // Add files
      if (profileImage != null) {
        formData.files.add(
          MapEntry(
            'profile_image',
            await MultipartFile.fromFile(profileImage.path, filename: profileImage.path.split('/').last),
          ),
        );
      }

      if (aadharFile != null) {
        formData.files.add(
          MapEntry(
            'aadhar_file_path',
            await MultipartFile.fromFile(aadharFile.path, filename: aadharFile.path.split('/').last),
          ),
        );
      }

      if (panFile != null) {
        formData.files.add(
          MapEntry(
            'pan_file_path',
            await MultipartFile.fromFile(panFile.path, filename: panFile.path.split('/').last),
          ),
        );
      }
      return await _apiClient.postMultipart(ApiEndpoints.updateProviderProfile, {}, formData: formData);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // Future<void> saveCategories({required int serviceProviderId, required List<int> categoryIds}) async {
  //   try {
  //     await _apiClient.post(ApiEndpoints.saveCategory, {
  //       'service_provider_id': serviceProviderId,
  //       'categories': categoryIds.map((id) => {'service_category_id': id}).toList(),
  //     });
  //   } catch (e) {
  //     throw Exception('Failed to save categories: $e');
  //   }
  // }

  // Future<void> deleteCategory(int categoryId) async {
  //   try {
  //     await _apiClient.post("${ApiEndpoints.deleteCategory}/$categoryId", {});
  //   } catch (e) {
  //     throw Exception('Failed to delete category: $e');
  //   }
  // }

  /// Fetches full service request details by ID.
  /// Used when the provider accepts from a notification (background/killed)
  /// and needs to reconstruct the [ServiceRequest] object from the API.
  Future<ServiceRequest> getServiceRequestById(int requestId) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.getProviderServiceRequestDetails,
        query: {'service_request_id': requestId},
      );
      final data = response['data'] ?? response;
      return ServiceRequest.fromJson(data);
    } catch (e) {
      throw Exception('Failed to fetch service request details: $e');
    }
  }

  /// Sends accept or reject response to the backend.
  /// Returns [RespondResult] — never throws on a known API error response.
  Future<RespondResult> respondToRequest({
    required int requestId,
    required bool accepted,
    List<int> subBlockIds = const [],
  }) async {
    try {
      final formMap = <String, dynamic>{
        'service_request_id': requestId.toString(),
        'action': accepted ? 'accepted' : 'rejected',
      };
      if (accepted) {
        for (var i = 0; i < subBlockIds.length; i++) {
          formMap['booking_unit_ids[$i]'] = subBlockIds[i].toString();
        }
      }
      final response = await _apiClient.postMultipart(ApiEndpoints.respondToServiceRequest, formMap);
      kPrint(response);
      return RespondResult.fromJson(response);
    } catch (e) {
      kPrintError('respondToRequest error: $e');
      rethrow;
    }
  }

  Future<BankDetail?> getBankDetail() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.providerBankDetail);
      if (response['status'] == true && response['data'] != null) {
        return BankDetail.fromJson(response['data']);
      }
      return null;
    } catch (e) {
      kPrintError('getBankDetail error: $e');
      rethrow;
    }
  }

  Future<bool> saveBankDetail({
    String? bankDetailId,
    required String accountHolderName,
    required String accountNumber,
    required String ifscCode,
    required String bankName,
    required String branchName,
    required String accountType,
    bool isPrimary = true,
  }) async {
    try {
      final payload = {
        'bank_detail_id': bankDetailId ?? '',
        'account_holder_name': accountHolderName,
        'account_number': accountNumber,
        'ifsc_code': ifscCode,
        'bank_name': bankName,
        'branch_name': branchName,
        'account_type': accountType,
        'is_primary': isPrimary ? '1' : '0',
      };
      final response = await _apiClient.postMultipart(ApiEndpoints.providerSaveBankDetail, payload);
      return response['status'] == true;
    } catch (e) {
      kPrintError('saveBankDetail error: $e');
      throw Exception('Failed to save bank details: $e');
    }
  }

  Future<PaymentOrderResult> initiateRegistrationFeePayment({required double amount}) async {
    final res = await _apiClient.postMultipart(
      ApiEndpoints.initiateRegistrationFeePayment,
      {},
      formData: FormData.fromMap({
        'registration_fee': amount.toStringAsFixed(2),
        'amount': amount.toStringAsFixed(2),
      }),
    );

    if (res['status'] == true && res['data'] != null) {
      final data = res['data'] as Map<String, dynamic>;
      return PaymentOrderResult(
        razorpayOrderId: (data['razorpay_order_id'] ??
                data['gateway_order_id'] ??
                '')
            .toString(),
        amount: (data['amount'] as num?)?.toInt() ?? 0,
        currency: data['currency']?.toString() ?? 'INR',
        razorpayKey: data['razorpay_key']?.toString() ?? '',
        tempOrderId: (data['temp_order_id'] as num?)?.toInt() ?? 0,
      );
    } else {
      throw Exception(res['message'] ?? 'Failed to initiate registration fee payment');
    }
  }

  Future<bool> verifyRegistrationFeePayment({
    required double amount,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    final res = await _apiClient.postMultipart(ApiEndpoints.verifyPayment, {
      'amount': amount.toStringAsFixed(2),
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_order_id': razorpayOrderId,
      'razorpay_signature': razorpaySignature,
    });
    return res['status'] == true;
  }

  Future<FeedbackResponse> getAppFeedback() async {
    try {
      final response = await _apiClient.postMultipart(ApiEndpoints.appFeedback, {
        'service_provider_id': _storageService.serviceProvideUserId?.toString() ?? '',
      });
      return FeedbackResponse.fromJson(response);
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
      final response = await _apiClient.postMultipart(ApiEndpoints.saveAppFeedback, {
        'service_provider_id': _storageService.serviceProvideUserId?.toString() ?? '',
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
}

// ─── RespondResult ────────────────────────────────────────────────────────────
// Parsed result from POST /provider/service-requests/respond.

class RespondResult {
  final bool success;
  final String message;
  final List<int> invalidIds;
  final String? errorType;
  final List<String> conflictDates;

  const RespondResult({
    required this.success,
    required this.message,
    this.invalidIds = const [],
    this.errorType,
    this.conflictDates = const [],
  });

  bool get hasPartialConflict => !success && invalidIds.isNotEmpty;

  bool get isDateConflict => !success && errorType == 'date_conflict';

  bool get isNotFound =>
      !success &&
      (message.toLowerCase().contains('not found') ||
          message.toLowerCase().contains('already responded'));

  factory RespondResult.fromJson(Map<String, dynamic> json) {
    final rawIds = json['invalid_ids'] as List<dynamic>? ?? [];
    final rawDates = json['conflict_dates'] as List<dynamic>? ?? [];
    return RespondResult(
      success: json['status'] == true,
      message: json['message']?.toString() ?? '',
      invalidIds: rawIds
          .map((e) => (e is num) ? e.toInt() : int.tryParse(e.toString()) ?? 0)
          .where((id) => id > 0)
          .toList(),
      errorType: json['error_type']?.toString(),
      conflictDates: rawDates.map((e) => e.toString()).toList(),
    );
  }
}
