import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../di/locator.dart';
import '../model/health_record_model.dart';

class HealthRecordRepository {
  final ApiClient _apiClient;

  HealthRecordRepository(this._apiClient);

  Future<List<HealthRecordModel>> getHealthRecords({int? familyMemberId}) async {
    final customerId = locator<LocalStorageService>().customerUserId?.toString();
    final response = await _apiClient.get(
      ApiEndpoints.healthRecords,
      query: {'customer_profile_id': customerId, 'family_member_id': ?familyMemberId},
    );
    final List data = response['data'] ?? response['records'] ?? [];
    return data.map((e) => HealthRecordModel.fromJson(e)).toList();
  }

  Future<void> saveHealthRecord({
    int? familyMemberId,
    required String recordType,
    required String recordTitle,
    required String recordDate,
    String? hospitalName,
    String? doctorName,
    String? notes,
    File? documentFile,
  }) async {
    final customerId = locator<LocalStorageService>().customerUserId?.toString();
    final formData = FormData.fromMap({
      'customer_profile_id': customerId,
      'family_member_id': familyMemberId?.toString() ?? '',
      'record_type': recordType,
      'record_title': recordTitle,
      'record_date': recordDate,
      'hospital_name': hospitalName ?? '',
      'doctor_name': doctorName ?? '',
      'notes': notes ?? '',
      if (documentFile != null)
        'document_url': await MultipartFile.fromFile(
          documentFile.path,
          filename: documentFile.path.split('/').last,
        ),
    });

    final response = await _apiClient.postMultipart(ApiEndpoints.saveHealthRecord, {}, formData: formData);

    final isSuccess = response['status'] == true || response['success'] == true;
    if (!isSuccess) {
      throw Exception(response['message'] ?? 'Failed to save record');
    }
  }

  Future<void> deleteHealthRecord({required int id}) async {
    final customerId = locator<LocalStorageService>().customerUserId?.toString();

    final formData = FormData.fromMap({'id': id.toString(), 'customer_profile_id': customerId});

    final response = await _apiClient.postMultipart(ApiEndpoints.deleteHealthRecord, {}, formData: formData);

    final isSuccess = response['status'] == true || response['success'] == true;
    if (!isSuccess) {
      throw Exception(response['message'] ?? 'Failed to delete record');
    }
  }
}
