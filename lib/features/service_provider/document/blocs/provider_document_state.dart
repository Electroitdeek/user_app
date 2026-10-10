part of 'provider_document_bloc.dart';

sealed class ProviderDocumentState {}

final class ProviderDocumentInitial extends ProviderDocumentState {}

final class DocumentLoading extends ProviderDocumentState {}

final class DocumentAdding extends ProviderDocumentState {}

final class DocumentAdded extends ProviderDocumentState {
  final String message;

  DocumentAdded({required this.message});
}

final class DocumentLoaded extends ProviderDocumentState {
  final List<DocumentModel> documents;
  final List<DynamicDocumentType> dynamicDocumentType;

  DocumentLoaded({
    required this.documents,
    required this.dynamicDocumentType,
  });
}

final class DocumentDeleted extends ProviderDocumentState {
  final String documentId;

  DocumentDeleted({required this.documentId});
}

final class DocumentDeleting extends ProviderDocumentState {
  final String documentId;

  DocumentDeleting({required this.documentId});
}

final class DocumentOperationError extends ProviderDocumentState {
  final String message;

  DocumentOperationError({required this.message});
}

final class DocumentError extends ProviderDocumentState {
  final String message;

  DocumentError({required this.message});
}
