import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/core/utils/message_service.dart';
import 'package:adhisaat_health_care/data/repositories/provider_repository.dart';
import 'package:adhisaat_health_care/data/models/dropdown_response_model.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/file_downloading_service.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/common/custom_refresh_indicator.dart';
import '../../../../shared/widgets/dialogs/dialog_helpers.dart';
import '../blocs/provider_document_bloc.dart';
import '../data/model/document_model.dart';
import 'add_provider_document_page.dart';

class ProviderDocumentListPage extends StatelessWidget {
  const ProviderDocumentListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProviderDocumentBloc(locator<ProviderRepository>())..add(FetchDocuments()),
      child: Scaffold(
        backgroundColor: kScaffoldColor,
        appBar: CustomAppBar(
          title: 'My Documents',
          backgroundColor: kScaffoldColor,
          actions: [
            BlocBuilder<ProviderDocumentBloc, ProviderDocumentState>(
              builder: (context, state) {
                return IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () {
                    context.read<ProviderDocumentBloc>().add(FetchDocuments());
                  },
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: BlocConsumer<ProviderDocumentBloc, ProviderDocumentState>(
            listener: (context, state) {
              if (state is DocumentDeleted) {
                MessageService.showSuccess('Document deleted successfully');
              } else if (state is DocumentOperationError) {
                MessageService.showError(state.message);
              }
            },
            buildWhen: (previous, current) =>
                current is DocumentLoading ||
                current is DocumentLoaded ||
                current is DocumentError,
            builder: (context, state) {
              if (state is DocumentLoading) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: kPrimaryColor),
                      const SizedBox(height: 16),
                      Text('Loading documents...', style: kTextNormal0().copyWith(color: Colors.grey)),
                    ],
                  ),
                );
              }

              if (state is DocumentError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                        ),
                        const SizedBox(height: 24),
                        Text('Failed to load documents', style: kTextBold1()),
                        const SizedBox(height: 12),
                        Text(
                          state.message,
                          style: kTextNormal0().copyWith(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              context.read<ProviderDocumentBloc>().add(FetchDocuments());
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Retry'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (state is DocumentLoaded) {
                if (state.documents.isEmpty) {
                  return _buildEmptyState(context, state);
                }

                return CustomRefreshIndicator(
                  onRefresh: () async {
                    context.read<ProviderDocumentBloc>().add(FetchDocuments());
                  },
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: state.documents.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return _buildDocumentCard(context, state.documents[index], state);
                    },
                  ),
                );
              }

              return _buildEmptyState(context, null);
            },
          ),
        ),
        floatingActionButton: BlocBuilder<ProviderDocumentBloc, ProviderDocumentState>(
          builder: (context, state) {
            return FloatingActionButton.extended(
              onPressed: () async {
                final dynamicDocumentTypes = state is DocumentLoaded
                    ? state.dynamicDocumentType
                    : <DynamicDocumentType>[];
                final addedKeys = state is DocumentLoaded
                    ? state.documents.map((e) => e.documentType).toSet()
                    : <String>{};
                final filteredTypes = dynamicDocumentTypes.where((type) => !addedKeys.contains(type.key)).toList();

                if (filteredTypes.isEmpty) {
                  MessageService.showInfo('All available document types have already been added.');
                  return;
                }

                final result = await AppNavigator.push(
                  AddProviderDocumentPage(dynamicDocumentTypes: filteredTypes),
                );
                if (result == true && context.mounted) {
                  context.read<ProviderDocumentBloc>().add(FetchDocuments());
                }
              },
              backgroundColor: kPrimaryColor,
              elevation: 4,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text('Add Document', style: kTextBold0().copyWith(color: Colors.white)),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, DocumentLoaded? state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.05), shape: BoxShape.circle),
              child: Icon(Icons.description_outlined, size: 64, color: kPrimaryColor.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 24),
            Text('No documents yet', style: kTextBold1()),
            const SizedBox(height: 12),
            Text(
              'Upload your proofs to complete your profile verification.',
              style: kTextNormal0().copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (state != null)
              OutlinedButton.icon(
                onPressed: () async {
                  final addedKeys = state.documents.map((e) => e.documentType).toSet();
                  final filteredTypes = state.dynamicDocumentType
                      .where((type) => !addedKeys.contains(type.key))
                      .toList();

                  if (filteredTypes.isEmpty) {
                    MessageService.showInfo('All available document types have already been added.');
                    return;
                  }

                  final result = await AppNavigator.push(
                    AddProviderDocumentPage(dynamicDocumentTypes: filteredTypes),
                  );
                  if (result == true && context.mounted) {
                    context.read<ProviderDocumentBloc>().add(FetchDocuments());
                  }
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add First Document'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimaryColor,
                  side: const BorderSide(color: kPrimaryColor),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, DocumentModel document, DocumentLoaded state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Top Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_getDocumentIcon(document.documentType), color: kPrimaryColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(document.documentName, style: kTextSemiBold1().copyWith(fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(
                          _getDocumentTypeName(document, state),
                          style: kTextNormal0().copyWith(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(document.verificationStatus),
                ],
              ),
            ),

            // Middle Section (Optional Info)
            if (document.issueDate != null || document.expiryDate != null || document.adminRemarks != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEEF2F7)),
                ),
                child: Column(
                  children: [
                    if (document.issueDate != null || document.expiryDate != null)
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            if (document.issueDate != null)
                              Expanded(
                                child: _dateInfo(
                                  'Issued On',
                                  AppDateFormatter.dateShort(document.issueDate!),
                                  Icons.event_available_rounded,
                                ),
                              ),
                            if (document.issueDate != null && document.expiryDate != null)
                              Container(
                                width: 1,
                                color: const Color(0xFFE2E8F0),
                                margin: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                            if (document.expiryDate != null)
                              Expanded(
                                child: _dateInfo(
                                  'Expires On',
                                  AppDateFormatter.dateShort(document.expiryDate!),
                                  Icons.event_busy_rounded,
                                  accent: _isExpired(document.expiryDate)
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF0EA5E9),
                                  valueColor: _isExpired(document.expiryDate) ? const Color(0xFFEF4444) : null,
                                ),
                              ),
                          ],
                        ),
                      ),
                    if ((document.issueDate != null || document.expiryDate != null) &&
                        document.adminRemarks != null)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider(height: 1)),
                    if (document.adminRemarks != null)
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              document.adminRemarks!,
                              style: kTextNormal0().copyWith(color: Colors.orange[900], fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

            // Bottom Section (Actions)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (document.verificationStatus.toLowerCase() == 'pending' ||
                      document.verificationStatus.toLowerCase() == 'rejected' ||
                      document.verificationStatus.toLowerCase() == 'hold')
                    _actionButton(
                      icon: Icons.edit_rounded,
                      label: 'Edit',
                      color: kPrimaryColor,
                      onPressed: () async {
                        final addedKeys = state.documents
                            .map((e) => e.documentType)
                            .where((type) => type != document.documentType)
                            .toSet();
                        final filteredTypes = state.dynamicDocumentType
                            .where((type) => !addedKeys.contains(type.key))
                            .toList();

                        final result = await AppNavigator.push(
                          AddProviderDocumentPage(dynamicDocumentTypes: filteredTypes, document: document),
                        );
                        if (result == true && context.mounted) {
                          context.read<ProviderDocumentBloc>().add(FetchDocuments());
                        }
                      },
                    ),
                  _actionButton(
                    icon: Icons.visibility_rounded,
                    label: 'View',
                    color: const Color(0xFF64748B),
                    onPressed: () => _viewDocument(context, document),
                  ),
                  const Spacer(),
                  _deleteButton(context, document),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: kTextSemiBold0().copyWith(fontSize: 12)),
    );
  }

  Widget _deleteButton(BuildContext context, DocumentModel document) {
    return BlocBuilder<ProviderDocumentBloc, ProviderDocumentState>(
      builder: (context, blocState) {
        final isDeleting = blocState is DocumentDeleting && blocState.documentId == document.id.toString();

        if (isDeleting) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
            ),
          );
        }

        return IconButton(
          onPressed: () => _showDeleteDialog(context, document),
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
          tooltip: 'Delete',
          visualDensity: VisualDensity.compact,
        );
      },
    );
  }

  bool _isExpired(String? date) {
    if (date == null) return false;
    final d = DateTime.tryParse(date);
    return d != null && d.isBefore(DateTime.now());
  }

  Widget _dateInfo(String label, String value, IconData icon, {Color accent = kPrimaryColor, Color? valueColor}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 15, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: kTextNormal0().copyWith(color: Colors.grey[500], fontSize: 10.5),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: kTextSemiBold0().copyWith(fontSize: 12.5, color: valueColor),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _viewDocument(BuildContext context, DocumentModel document) async {
    if (document.documentPathUrl == null) {
      MessageService.showInfo('Document not available');
      return;
    }
    await FileDownloadService().downloadAndViewFile(
      url: document.documentPathUrl!,
      originalName: document.documentName,
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    final label = status.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: kTextBold0().copyWith(color: color, fontSize: 10)),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
      case 'approved':
        return const Color(0xFF10B981); // Emerald
      case 'pending':
      case 'in_progress':
        return const Color(0xFFF59E0B); // Amber
      case 'rejected':
        return const Color(0xFFEF4444); // Red
      case 'hold':
        return const Color(0xFF6366F1); // Indigo
      default:
        return Colors.grey;
    }
  }

  IconData _getDocumentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'aadhar':
        return Icons.badge_outlined;
      case 'pan':
        return Icons.credit_card_rounded;
      case 'qualification':
        return Icons.school_outlined;
      case 'registration':
        return Icons.how_to_reg_rounded;
      case 'photo':
        return Icons.portrait_rounded;
      case 'police_verification':
        return Icons.gpp_good_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  String _getDocumentTypeName(DocumentModel document, DocumentLoaded state) {
    for (final type in state.dynamicDocumentType) {
      if (type.key == document.documentType) {
        return type.name;
      }
    }
    return document.documentType.replaceAll('_', ' ').toUpperCase();
  }

  Future<void> _showDeleteDialog(BuildContext context, DocumentModel document) async {
    final result = await DialogHelper.showConfirmation(
      title: 'Delete Document',
      message: 'Are you sure you want to delete "${document.documentName}"?',
      isDangerous: true,
    );
    if (result == true && context.mounted) {
      context.read<ProviderDocumentBloc>().add(DeleteDocument(documentId: document.id.toString()));
    }
  }
}
