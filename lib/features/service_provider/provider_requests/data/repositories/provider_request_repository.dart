import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/api/api_endpoints.dart';
import 'package:adhisaat_health_care/di/locator.dart';

import '../../../../../data/repositories/provider_repository.dart';
import '../../../../../features/user/health_records/model/health_record_model.dart';
import '../models/cancellation_preview_model.dart';
import '../models/provider_service_request_model.dart';

class ProviderRequestRepository {
  final ApiClient _apiClient = locator<ApiClient>();

  Future<ProviderRequestListResponse> getProviderServiceRequests({
    String? search,
    String? requestStatus,
    int? serviceCategoryId,
    bool isNewRequest = false,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'per_page': perPage};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (requestStatus != null && requestStatus.isNotEmpty) queryParams['booking_status'] = requestStatus;
      if (serviceCategoryId != null) queryParams['service_category_id'] = serviceCategoryId;
      //to get only new request
      queryParams['is_new_request'] = isNewRequest ? "1" : "0";

      final response = await _apiClient.get(ApiEndpoints.getProviderServiceRequests, query: queryParams);

      if (response['status'] == true) {
        final List<dynamic> data = response['data'] ?? [];
        final requests = data.map((json) => ProviderServiceRequestModel.fromJson(json)).toList();

        final paginationJson = response['pagination'] as Map<String, dynamic>? ?? {};
        final pagination = PaginationInfo(
          total: paginationJson['total'] ?? 0,
          currentPage: paginationJson['current_page'] ?? 1,
          lastPage: paginationJson['last_page'] ?? 1,
          perPage: paginationJson['per_page'] ?? perPage,
        );

        return ProviderRequestListResponse(requests: requests, pagination: pagination);
      } else {
        return ProviderRequestListResponse(
          requests: [],
          pagination: PaginationInfo(total: 0, currentPage: 1, lastPage: 1, perPage: perPage),
        );
      }
    } catch (e) {
      kPrint("Error fetching provider service requests: $e");
      throw Exception("Failed to fetch service requests");
    }
  }

  Future<ProviderServiceRequestModel?> getRequestDetails({int? requestId, int? bookingId}) async {
    try {
      final response = await _apiClient.post(ApiEndpoints.getProviderServiceRequestDetails, {
        'service_request_id': ?requestId,
        'booking_id': ?bookingId,
      });
      if (response['status'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        final serviceRequest = Map<String, dynamic>.from(
          (data['service_request'] ?? data) as Map<String, dynamic>,
        );
        // Merge top-level pricing_breakdown (emergency requests have it separate)
        final pricingBreakdown = data['pricing_breakdown'] as Map<String, dynamic>?;
        if (pricingBreakdown != null) {
          serviceRequest['total_amount'] ??= pricingBreakdown['total_amount'];
          serviceRequest['base_price'] ??= pricingBreakdown['base_price'];
          serviceRequest['pricing_breakdown'] ??= pricingBreakdown;
        }
        return ProviderServiceRequestModel.fromJson(serviceRequest);
      } else {
        // status: false - request already accepted by another provider or expired
        final message = response['message'] ?? 'Service Request not found. Or already responded.';
        throw Exception(message);
      }
    } catch (e) {
      kPrint("Error fetching request details: $e");
      rethrow;
    }
  }

  Future<RespondResult> respondToServiceRequest({
    required int requestId,
    required String action,
    List<int> subBlockIds = const [],
  }) async {
    try {
      final formMap = <String, dynamic>{'service_request_id': requestId.toString(), 'action': action};
      if (action == 'accepted') {
        for (var i = 0; i < subBlockIds.length; i++) {
          formMap['booking_unit_ids[$i]'] = subBlockIds[i].toString();
        }
      }
      final response = await _apiClient.postMultipart(ApiEndpoints.respondToServiceRequest, formMap);
      kPrint(response);
      return RespondResult.fromJson(response);
    } catch (e) {
      kPrint("Error responding to service request: $e");
      rethrow;
    }
  }

  Future<void> sendStartOtp({
    required int serviceRequestId,
    required int subBlockId,
    required String mobileNumber,
    bool resend = false,
  }) async {
    try {
      final response = await _apiClient.postMultipart(ApiEndpoints.sendBookingCompletionOtp, {
        'service_request_id': serviceRequestId.toString(),
        'sub_block_id': subBlockId.toString(),
        'mobile_number': mobileNumber,
        if (resend) 'resend': '1',
      });
      if (response['status'] != true && response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      kPrint('Error sending start OTP: $e');
      rethrow;
    }
  }

  Future<void> startServiceRequest({
    required int requestId,
    int? subBlockId,
    String? otp,
    double? checkinLatitude,
    double? checkinLongitude,
  }) async {
    try {
      final response = await _apiClient.postMultipart(ApiEndpoints.startBooking, {
        'service_request_id': requestId.toString(),
        if (subBlockId != null) 'sub_block_id': subBlockId.toString(),
        if (otp != null && otp.isNotEmpty) 'otp': otp,
        if (checkinLatitude != null) 'checkin_latitude': checkinLatitude.toString(),
        if (checkinLongitude != null) 'checkin_longitude': checkinLongitude.toString(),
      });
      if (response['status'] != true) {
        throw Exception(response['message'] ?? "Failed to start service");
      }
    } catch (e) {
      kPrint("Error starting service request: $e");
      rethrow;
    }
  }

  Future<void> completeSession({
    required int serviceRequestId,
    required int subBlockId,
    double? checkoutLatitude,
    double? checkoutLongitude,
  }) async {
    try {
      final response = await _apiClient.postMultipart(ApiEndpoints.completeBooking, {
        'service_request_id': serviceRequestId.toString(),
        'sub_block_id': subBlockId.toString(),
        if (checkoutLatitude != null) 'checkout_latitude': checkoutLatitude.toString(),
        if (checkoutLongitude != null) 'checkout_longitude': checkoutLongitude.toString(),
      });
      if (response['status'] != true && response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to complete session');
      }
    } catch (e) {
      kPrint('Error completing session: $e');
      rethrow;
    }
  }

  Future<void> sendCompletionOtp({
    required int bookingId,
    required String mobileNumber,
    bool resend = false,
  }) async {
    try {
      final response = await _apiClient.postMultipart(ApiEndpoints.sendBookingCompletionOtp, {
        'booking_id': bookingId.toString(),
        'mobile_number': mobileNumber,
        if (resend) 'resend': '1',
      });

      if (response['success'] != true) {
        throw Exception(response['message'] ?? "Failed to send OTP");
      }
    } catch (e) {
      kPrint("Error sending completion OTP: $e");
      rethrow;
    }
  }

  Future<void> completeBooking({
    required int bookingId,
    required String otp,
    double? checkoutLatitude,
    double? checkoutLongitude,
  }) async {
    try {
      final response = await _apiClient.postMultipart(ApiEndpoints.completeBooking, {
        'booking_id': bookingId.toString(),
        'otp': otp,
        if (checkoutLatitude != null) 'checkout_latitude': checkoutLatitude.toString(),
        if (checkoutLongitude != null) 'checkout_longitude': checkoutLongitude.toString(),
      });

      if (response['success'] != true) {
        throw Exception(response['message'] ?? "Failed to complete booking");
      }
    } catch (e) {
      kPrint("Error completing booking: $e");
      rethrow;
    }
  }

  Future<CancellationPreviewModel> getCancellationPreview({
    required int serviceRequestId,
    required int bookingId,
    required List<int> subBlockIds,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.providerCancellationPreview,
        {
          'service_request_id': serviceRequestId,
          'booking_id': bookingId,
          'sub_block_ids': subBlockIds,
        },
      );
      final data = response['data'] as Map<String, dynamic>? ?? response;
      return CancellationPreviewModel.fromJson(data);
    } catch (e) {
      kPrint("Error fetching cancellation preview: $e");
      rethrow;
    }
  }

  Future<void> cancelSession({
    required int serviceRequestId,
    required int bookingId,
    required List<int> subBlockIds,
    String? reason,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.providerCancelSession,
        {
          'service_request_id': serviceRequestId,
          'booking_id': bookingId,
          'sub_block_ids': subBlockIds,
          'reason': ?reason,
        },
      );
      if (response['status'] != true && response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to cancel session');
      }
    } catch (e) {
      kPrint("Error cancelling session: $e");
      rethrow;
    }
  }

  Future<List<HealthRecordModel>> getHealthRecords({int? customerProfileId, int? familyMemberId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (customerProfileId != null) {
        queryParams['customer_profile_id'] = customerProfileId;
      }
      if (familyMemberId != null) {
        queryParams['family_member_id'] = familyMemberId;
      }

      final response = await _apiClient.get(ApiEndpoints.healthRecords, query: queryParams);

      if (response['status'] == true) {
        final List<dynamic> data = response['data'] ?? [];
        return data.map((json) => HealthRecordModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      kPrint("Error fetching health records: $e");
      rethrow;
    }
  }
}

class ProviderRequestListResponse {
  final List<ProviderServiceRequestModel> requests;
  final PaginationInfo pagination;

  ProviderRequestListResponse({required this.requests, required this.pagination});
}

class PaginationInfo {
  final int total;
  final int currentPage;
  final int lastPage;
  final int perPage;

  PaginationInfo({required this.total, required this.currentPage, required this.lastPage, required this.perPage});

  bool get hasMore => currentPage < lastPage;
}
