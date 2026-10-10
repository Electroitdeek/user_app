part of 'provider_document_bloc.dart';

sealed class ProviderDocumentEvent {}

class FetchDocuments extends ProviderDocumentEvent {}

class DeleteDocument extends ProviderDocumentEvent {
  final String documentId;

  DeleteDocument({required this.documentId});
}

class AddDocument extends ProviderDocumentEvent {
  final String documentType;
  final String documentName;
  final String documentNumber;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final File? documentFile;

  AddDocument({
    required this.documentType,
    required this.documentName,
    required this.documentNumber,
    required this.issueDate,
    required this.expiryDate,
    required this.documentFile,
  });
}

class UpdateDocument extends ProviderDocumentEvent {
  final String documentType;
  final String documentName;
  final String documentNumber;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final String documentId;
  final File? documentFile;

  UpdateDocument({
    required this.documentType,
    required this.documentName,
    required this.documentNumber,
    required this.issueDate,
    required this.expiryDate,
    required this.documentId,
    this.documentFile,
  });
}
