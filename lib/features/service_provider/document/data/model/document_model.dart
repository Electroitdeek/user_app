import '../../../../../data/models/dropdown_response_model.dart';

class DocumentModel {
  final int id;
  final int serviceProviderId;
  final String documentType;
  final String documentName;
  final String? documentPath;
  final String? documentPathUrl;
  final String? documentNumber;
  final String? issueDate;
  final String? expiryDate;
  final String verificationStatus;
  final String? adminRemarks;
  final String createdAt;
  final String updatedAt;
  final String verificationStatusLabel;
  final String? issueDateText;
  final String? expiryDateText;

  DocumentModel({
    required this.id,
    required this.serviceProviderId,
    required this.documentType,
    required this.documentName,
    required this.documentPath,
    required this.documentPathUrl,
    this.documentNumber,
    this.issueDate,
    this.expiryDate,
    required this.verificationStatus,
    this.adminRemarks,
    required this.createdAt,
    required this.updatedAt,
    required this.verificationStatusLabel,
    this.issueDateText,
    this.expiryDateText,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] ?? 0,
      serviceProviderId: json['service_provider_id'] ?? 0,
      documentType: json['document_type'] ?? '',
      documentName: json['document_name'] ?? '',
      documentPath: json['document_path'],
      documentPathUrl: json['document_path_url'],
      documentNumber: json['document_number'],
      issueDate: json['issue_date'],
      expiryDate: json['expiry_date'],
      verificationStatus: json['verification_status'] ?? '',
      adminRemarks: json['admin_remarks'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      verificationStatusLabel: json['verification_status_label'] ?? '',
      issueDateText: json['issue_date_text'],
      expiryDateText: json['expiry_date_text'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service_provider_id': serviceProviderId,
      'document_type': documentType,
      'document_name': documentName,
      'document_path': documentPath,
      'document_path_url': documentPathUrl,
      'document_number': documentNumber,
      'issue_date': issueDate,
      'expiry_date': expiryDate,
      'verification_status': verificationStatus,
      'admin_remarks': adminRemarks,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'verification_status_label': verificationStatusLabel,
      'issue_date_text': issueDateText,
      'expiry_date_text': expiryDateText,
    };
  }
}

class DocumentResponse {
  final bool status;
  final String message;
  final List<DocumentModel> data;
  final List<DynamicDocumentType> dynamicDocumentType;

  DocumentResponse({
    required this.status,
    required this.message,
    required this.data,
    required this.dynamicDocumentType,
  });

  factory DocumentResponse.fromJson(Map<String, dynamic> json) {
    return DocumentResponse(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
      data: (json['data'] as List?)?.map((e) => DocumentModel.fromJson(e)).toList() ?? [],
      dynamicDocumentType: (json['dynamicDocumentType'] as List?)
              ?.map((e) => DynamicDocumentType.fromJson(e))
              .toList() ??
          [],
    );
  }
}
