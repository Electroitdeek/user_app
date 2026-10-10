import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../model/support_ticket_model.dart';

class SupportTicketRepository {
  final ApiClient _apiClient;

  SupportTicketRepository(this._apiClient);

  Future<SupportTicketsResponse> getSupportTickets() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.supportTickets);
      return SupportTicketsResponse.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createSupportTicket({
    required String subject,
    required String description,
    required String priority,
    required String category,
    String status = "open",
    String? serviceRequestId,
    String? cityAdminId,
    String? bookingSubBlockId,
  }) async {
    try {
      final data = {
        'subject': subject,
        'description': description,
        'priority': priority,
        'category': category,
        'status': status,
        if (serviceRequestId != null && serviceRequestId.isNotEmpty)
          'service_request_id': serviceRequestId,
        if (cityAdminId != null && cityAdminId.isNotEmpty)
          'city_admin_id': cityAdminId,
        if (bookingSubBlockId != null && bookingSubBlockId.isNotEmpty)
          'booking_sub_block_id': bookingSubBlockId,
      };

      final response = await _apiClient.postMultipart(
        ApiEndpoints.supportTicketsCreate,
        data,
      );
      
      final responseMap = response as Map<String, dynamic>;
      
      if (responseMap['status'] == false || responseMap.containsKey('errors')) {
        throw Exception('Something went wrong, please try again');
      }
      
      return responseMap;
    } catch (e) {
      debugPrint('Error: $e');
      rethrow;
    }
  }

  Future<SupportTicketModel> getSupportTicketDetails(String ticketId) async {
    try {
      final response = await _apiClient.postMultipart(
        ApiEndpoints.supportTicketsDetails,
        {'ticket_id': ticketId},
      );
      final data = response as Map<String, dynamic>;
      // Expecting `data['data']` to have the ticket or directly.
      if (data.containsKey('data') && data['data'] != null) {
        return SupportTicketModel.fromJson(data['data']);
      }
      return SupportTicketModel.fromJson(data);
    } catch (e) {
      debugPrint('Error: $e');
      rethrow;
    }
  }

  Future<void> updateSupportTicketStatus(String ticketId, String status) async {
    try {
      await _apiClient.postMultipart(
        ApiEndpoints.supportTicketsUpdateStatus,
        {
          'ticket_id': ticketId,
          'status': status,
        },
      );
    } catch (e) {
      debugPrint('Error: $e');
      rethrow;
    }
  }

  Future<List<SupportTicketMessageModel>> getSupportTicketMessages(String ticketId) async {
    try {
      final response = await _apiClient.get(
        '${ApiEndpoints.supportTicketsMessages}?ticket_id=$ticketId',
      );
      final messagesResponse = SupportTicketMessagesResponse.fromJson(response as Map<String, dynamic>);
      return messagesResponse.data;
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendSupportTicketMessage({
    required String ticketId,
    required String message,
    String? attachmentPath,
  }) async {
    try {
      final data = <String, dynamic>{
        'ticket_id': ticketId,
        'message': message,
        if (attachmentPath != null)
          'attachment': await MultipartFile.fromFile(attachmentPath),
      };

      final response = await _apiClient.postMultipart(
        ApiEndpoints.supportTicketsSendMessage,
        data,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }
}
