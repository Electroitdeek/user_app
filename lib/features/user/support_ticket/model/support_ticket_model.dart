import 'package:flutter/material.dart';

import '../../service_booking/model/service_request_model.dart';

class SupportTicketModel {
  final int id;
  final String ticketNo;
  final String subject;
  final String description;
  final String category;
  final String priority;
  final String status;
  final String? serviceRequestId;
  final String? serviceRequestNumber;
  final String createdAt;
  final String? createdAtFormatted;
  final String? statusText;
  final String? adminRemark;
  final String? adminName;
  final String? adminRole;
  final String? bookingStartDate;
  final String? bookingEndDate;
  final String? bookingAddress;
  final String? bookingStatusText;
  final double? bookingAmount;
  final ServiceRequestModel? serviceRequest;

  SupportTicketModel({
    required this.id,
    required this.ticketNo,
    required this.subject,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    this.serviceRequestId,
    this.serviceRequestNumber,
    required this.createdAt,
    this.createdAtFormatted,
    this.statusText,
    this.adminRemark,
    this.adminName,
    this.adminRole,
    this.bookingStartDate,
    this.bookingEndDate,
    this.bookingAddress,
    this.bookingStatusText,
    this.bookingAmount,
    this.serviceRequest,
  });

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    final admin = json['admin_user'] as Map<String, dynamic>?;
    final sr = json['service_request'] as Map<String, dynamic>?;

    return SupportTicketModel(
      id: json['id'] ?? 0,
      ticketNo: json['ticket_number']?.toString() ?? json['ticket_no']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      priority: json['priority']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      serviceRequestId: json['service_request_id']?.toString(),
      serviceRequestNumber: json['request_number']?.toString() ?? json['service_request_number']?.toString() ?? sr?['request_number']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      createdAtFormatted: json['created_at_formatted']?.toString(),
      statusText: json['status_text']?.toString(),
      adminRemark: json['admin_remark']?.toString(),
      adminName: admin?['admin_name']?.toString(),
      adminRole: admin?['admin_role']?.toString(),
      bookingStartDate: sr?['start_date_text']?.toString(),
      bookingEndDate: sr?['end_date_text']?.toString(),
      bookingAddress: sr?['full_address']?.toString(),
      bookingStatusText: sr?['request_status_text']?.toString(),
      bookingAmount: double.tryParse(sr?['total_amount']?.toString() ?? ''),
      serviceRequest: sr != null ? ServiceRequestModel.fromJson(sr) : null,
    );
  }

  String get statusLabel {
    if (statusText != null && statusText!.isNotEmpty) return statusText!;
    switch (status.toLowerCase()) {
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return status.toUpperCase();
    }
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'open':
        return const Color(0xFF2D62ED);
      case 'in_progress':
        return const Color(0xFFF59E0B);
      case 'resolved':
        return const Color(0xFF10B981);
      case 'closed':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String get displayDate => createdAtFormatted ?? createdAt;
}

class SupportTicketMessageModel {
  final int id;
  final int ticketId;
  final String message;
  final String? attachment;
  final bool isAdmin;
  final String createdAt;
  final String? createdAtFormatted;

  SupportTicketMessageModel({
    required this.id,
    required this.ticketId,
    required this.message,
    this.attachment,
    required this.isAdmin,
    required this.createdAt,
    this.createdAtFormatted,
  });

  factory SupportTicketMessageModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketMessageModel(
      id: json['id'] ?? 0,
      ticketId: int.tryParse(json['support_ticket_id']?.toString() ?? '') ?? 0,
      message: json['message']?.toString() ?? '',
      attachment: json['attachment_url']?.toString() ?? json['attachment']?.toString(),
      isAdmin: json['sender_type']?.toString().toLowerCase() == 'admin' || 
               json['is_admin'] == 1 || 
               json['is_admin'] == true,
      createdAt: json['created_at']?.toString() ?? '',
      createdAtFormatted: json['created_at_formatted']?.toString(),
    );
  }
}

class SupportTicketMessagesResponse {
  final bool status;
  final String message;
  final List<SupportTicketMessageModel> data;

  SupportTicketMessagesResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory SupportTicketMessagesResponse.fromJson(Map<String, dynamic> json) {
    final status = json['status'] == true;
    final msg = json['message']?.toString() ?? '';
    final list = json['data'] as List?;
    return SupportTicketMessagesResponse(
      status: status,
      message: msg,
      data: list?.map((e) => SupportTicketMessageModel.fromJson(e)).toList() ?? [],
    );
  }
}

class SupportTicketsResponse {
  final bool status;
  final String message;
  final List<SupportTicketModel> data;

  SupportTicketsResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory SupportTicketsResponse.fromJson(Map<String, dynamic> json) {
    final status = json['status'] == true;
    final msg = json['message']?.toString() ?? '';
    final list = json['data'] as List?;
    return SupportTicketsResponse(
      status: status,
      message: msg,
      data: list?.map((e) => SupportTicketModel.fromJson(e)).toList() ?? [],
    );
  }
}
