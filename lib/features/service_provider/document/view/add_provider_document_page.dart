import 'dart:io';

import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/data/models/dropdown_response_model.dart';
import 'package:adhisaat_health_care/core/services/file_downloading_service.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:adhisaat_health_care/shared/widgets/inputs/custom_drop_down.dart'
    show CustomDropDown, mapToDropdownItems;
import 'package:adhisaat_health_care/shared/widgets/inputs/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../data/repositories/provider_repository.dart';
import '../../../../di/locator.dart';
import '../../../../shared/widgets/dialogs/custom_bottom_sheets.dart';
import '../blocs/provider_document_bloc.dart';
import '../data/model/document_model.dart';

class AddProviderDocumentPage extends HookWidget {
  final List<DynamicDocumentType> dynamicDocumentTypes;
  final DocumentModel? document;
  final String? initialSelectedType;

  const AddProviderDocumentPage({
    super.key,
    required this.dynamicDocumentTypes,
    this.document,
    this.initialSelectedType,
  });

  @override
  Widget build(BuildContext context) {
    final isEdit = document != null;
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final documentNameController = useTextEditingController(text: document?.documentName);
    final documentNumberController = useTextEditingController(text: document?.documentNumber);
    final issueDateController = useTextEditingController(text: document?.issueDateText);
    final expiryDateController = useTextEditingController(text: document?.expiryDateText);

    final selectedDocumentType = useState<String?>(initialSelectedType ?? document?.documentType);
    final selectedFile = useState<File?>(null);
    final issueDate = useState<DateTime?>(
      document?.issueDate != null ? AppDateFormatter.dateFromString(document!.issueDate!) : null,
    );
    final expiryDate = useState<DateTime?>(
      document?.expiryDate != null ? AppDateFormatter.dateFromString(document!.expiryDate!) : null,
    );

    final selectedTypeConfig = useMemoized(() {
      if (selectedDocumentType.value == null) return null;
      return dynamicDocumentTypes.firstWhere(
        (type) => type.key == selectedDocumentType.value,
        orElse: () => DynamicDocumentType(id: 0, key: '', name: '', isRequired: false, isActive: false),
      );
    }, [selectedDocumentType.value, dynamicDocumentTypes]);

    void submitForm(BuildContext context) {
      if (formKey.currentState!.validate()) {
        // 1. Validate Document Type
        if (selectedDocumentType.value == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select document type'), backgroundColor: Colors.red),
          );
          return;
        }

        // 2. Validate File Presence and Size (Only for new documents)
        if (!isEdit && selectedFile.value == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Please upload a document'), backgroundColor: Colors.red));
          return;
        }

        if (selectedFile.value != null && selectedFile.value!.lengthSync() > AppConstants.maxFileSize) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File size must be less than ${AppConstants.maxFileSizeMB} MB'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (isEdit) {
          context.read<ProviderDocumentBloc>().add(
            UpdateDocument(
              documentId: document!.id.toString(),
              documentType: selectedDocumentType.value!,
              documentName: documentNameController.text.trim(),
              documentNumber: documentNumberController.text.trim(),
              issueDate: issueDate.value,
              expiryDate: expiryDate.value,
              documentFile: selectedFile.value,
            ),
          );
        } else {
          context.read<ProviderDocumentBloc>().add(
            AddDocument(
              documentType: selectedDocumentType.value!,
              documentName: documentNameController.text.trim(),
              documentNumber: documentNumberController.text.trim(),
              issueDate: issueDate.value,
              expiryDate: expiryDate.value,
              documentFile: selectedFile.value,
            ),
          );
        }
      }
    }

    return BlocProvider(
      create: (context) => ProviderDocumentBloc(locator<ProviderRepository>()),
      child: Scaffold(
        backgroundColor: kScaffoldColor,
        appBar: CustomAppBar(title: isEdit ? 'Edit Document' : 'Add Document'),
        body: SafeArea(
          child: BlocListener<ProviderDocumentBloc, ProviderDocumentState>(
            listener: (context, state) {
              if (state is DocumentAdded) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.green));
                Navigator.pop(context, true);
              } else if (state is DocumentOperationError) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
              }
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _WarningNotice(),
                    const SizedBox(height: 16),
                    CustomDropDown(
                      labelText: "Document Type",
                      items: mapToDropdownItems({
                        for (var type in dynamicDocumentTypes) type.key: type.name
                      }),
                      value: selectedDocumentType.value,
                      onChanged: (value) {
                        selectedDocumentType.value = value;
                      },
                    ),

                    CustomTextField(
                      controller: documentNameController,
                      labelText: 'Document Name',
                      hintText: 'Enter document name',
                      isRequired: true,
                    ),
                    CustomTextField(
                      controller: documentNumberController,
                      labelText: 'Document Number (Optional)',
                      hintText: 'Enter document number',
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: DatePickerTextField(
                            controller: issueDateController,
                            labelText: 'Issue Date',
                            initialDate: issueDate.value,
                            onDateSelected: (date) {
                              issueDate.value = date;
                              expiryDate.value = null;
                              expiryDateController.clear();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DatePickerTextField(
                            controller: expiryDateController,
                            labelText: 'Expiry Date',
                            initialDate: expiryDate.value,
                            firstDate: issueDate.value ?? DateTime.now(),
                            onDateSelected: (date) => expiryDate.value = date,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('Upload Document'),
                        if (selectedTypeConfig != null &&
                            selectedTypeConfig.sampleFileUrl != null &&
                            selectedTypeConfig.sampleFileUrl!.isNotEmpty)
                          GestureDetector(
                            onTap: () async {
                              await FileDownloadService().downloadAndViewFile(
                                url: selectedTypeConfig.sampleFileUrl!,
                                originalName: '${selectedTypeConfig.name}_sample',
                              );
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: kPrimaryColor, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'View Sample',
                                  style: kTextBold0().copyWith(color: kPrimaryColor, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Max size: ${AppConstants.maxFileSizeMB} MB',
                      style: kTextNormal0().copyWith(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    _buildFileUploadSection(context, selectedFile),
                    const SizedBox(height: 32),
                    BlocBuilder<ProviderDocumentBloc, ProviderDocumentState>(
                      builder: (context, state) {
                        final isLoading = state is DocumentAdding;

                        return ElevatedButton(
                          onPressed: isLoading ? null : () => submitForm(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  isEdit ? 'Update Document' : 'Submit Document',
                                  style: kTextSemiBold1().copyWith(color: Colors.white),
                                ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: kTextSemiBold1().copyWith(color: Colors.grey[800]));
  }

  Widget _buildFileUploadSection(BuildContext context, ValueNotifier<File?> selectedFile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectedFile.value != null ? kPrimaryColor : Colors.grey[300]!,
          width: selectedFile.value != null ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          if (selectedFile.value != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.insert_drive_file, color: kPrimaryColor, size: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedFile.value!.path.split('/').last,
                          style: kTextMedium(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getFileSize(selectedFile.value!),
                          style: kTextNormal0().copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      selectedFile.value = null;
                    },
                  ),
                ],
              ),
            )
          else if (document?.documentPathUrl != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: InkWell(
                onTap: () async {
                  final result = await ChooseFileBottomSheet.show();
                  if (result != null) {
                    if (result.lengthSync() > AppConstants.maxFileSize) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'File is too large! Maximum allowed is ${AppConstants.maxFileSizeMB} MB.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } else {
                      selectedFile.value = result;
                    }
                  }
                },
                child: Row(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                        image: document!.documentPathUrl!.toLowerCase().endsWith('.pdf')
                            ? null
                            : DecorationImage(image: NetworkImage(document!.documentPathUrl!), fit: BoxFit.cover),
                      ),
                      child: document!.documentPathUrl!.toLowerCase().endsWith('.pdf')
                          ? const Icon(Icons.picture_as_pdf, color: Colors.red, size: 48)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current Document', style: kTextMedium()),
                          const SizedBox(height: 4),
                          Text('Tap to change file', style: kTextNormal0().copyWith(color: kPrimaryColor)),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit, color: kPrimaryColor),
                  ],
                ),
              ),
            )
          else
            InkWell(
              onTap: () async {
                final result = await ChooseFileBottomSheet.show();
                if (result != null) {
                  // Instant validation upon picking
                  if (result.lengthSync() > AppConstants.maxFileSize) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('File is too large! Maximum allowed is ${AppConstants.maxFileSizeMB} MB.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } else {
                    selectedFile.value = result;
                  }
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text('Upload Document', style: kTextMedium1()),
                    const SizedBox(height: 4),
                    Text('Tap to select image or PDF', style: kTextNormal0().copyWith(color: Colors.grey)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getFileSize(File file) {
    final bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _WarningNotice extends StatelessWidget {
  const _WarningNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange[800], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Important: Adding or updating documents will require your profile to be re-verified by the administrator.',
              style: kTextNormal0().copyWith(color: Colors.orange[900]),
            ),
          ),
        ],
      ),
    );
  }
}
