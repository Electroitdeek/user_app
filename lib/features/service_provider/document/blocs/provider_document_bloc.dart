import 'dart:io';

import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/api/app_exception.dart';
import 'package:adhisaat_health_care/data/repositories/provider_repository.dart';
import 'package:adhisaat_health_care/data/models/dropdown_response_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/model/document_model.dart';

part 'provider_document_event.dart';
part 'provider_document_state.dart';

class ProviderDocumentBloc extends Bloc<ProviderDocumentEvent, ProviderDocumentState> {
  final ProviderRepository _repository;

  ProviderDocumentBloc(this._repository) : super(ProviderDocumentInitial()) {
    on<FetchDocuments>(_onFetchDocuments);
    on<DeleteDocument>(_onDeleteDocument);
    on<AddDocument>(_onAddDocument);
    on<UpdateDocument>(_onUpdateDocument);
  }

  Future<void> _onFetchDocuments(FetchDocuments event, Emitter<ProviderDocumentState> emit) async {
    emit(DocumentLoading());
    try {
      final response = await _repository.fetchDocuments();
      emit(DocumentLoaded(
        documents: response.data,
        dynamicDocumentType: response.dynamicDocumentType,
      ));
    } catch (e) {
      kPrintError('Failed to fetch documents: $e');
      emit(DocumentError(message: "Failed to fetch documents"));
    }
  }

  Future<void> _onDeleteDocument(DeleteDocument event, Emitter<ProviderDocumentState> emit) async {
    emit(DocumentDeleting(documentId: event.documentId));
    try {
      await _repository.deleteDocument(event.documentId);
      if (isClosed) return;
      emit(DocumentDeleted(documentId: event.documentId));
      // Refresh the list after deletion
      add(FetchDocuments());
    } catch (e) {
      if (isClosed) return;
      emit(DocumentOperationError(message: _errorMessage(e, 'Failed to delete document')));
      add(FetchDocuments());
    }
  }

  Future<void> _onAddDocument(AddDocument event, Emitter<ProviderDocumentState> emit) async {
    emit(DocumentAdding());
    try {
      await _repository.addOrUpdateDocument(
        documentType: event.documentType,
        documentName: event.documentName,
        documentNumber: event.documentNumber,
        issueDate: event.issueDate,
        expiryDate: event.expiryDate,
        documentFile: event.documentFile,
      );
      emit(DocumentAdded(message: 'Document added successfully'));
      // Refresh the list after adding
      add(FetchDocuments());
    } catch (e) {
      kPrintError("Failed to add document: $e");
      emit(DocumentOperationError(message: _errorMessage(e, 'Failed to add document')));
    }
  }

  Future<void> _onUpdateDocument(UpdateDocument event, Emitter<ProviderDocumentState> emit) async {
    emit(DocumentAdding());
    try {
      await _repository.addOrUpdateDocument(
        id: event.documentId,
        documentType: event.documentType,
        documentName: event.documentName,
        documentNumber: event.documentNumber,
        issueDate: event.issueDate,
        expiryDate: event.expiryDate,
        documentFile: event.documentFile,
      );
      emit(DocumentAdded(message: 'Document updated successfully'));
      // Refresh the list after updating
      add(FetchDocuments());
    } catch (e) {
      emit(DocumentOperationError(message: _errorMessage(e, 'Failed to update document')));
    }
  }

  String _errorMessage(Object e, String fallback) {
    if (e is AppException) return e.message;
    return fallback;
  }
}
