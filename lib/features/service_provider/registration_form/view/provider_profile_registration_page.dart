import 'dart:io';

import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/core/theme/screen_dimensions.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/data/repositories/auth_repository.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:adhisaat_health_care/shared/widgets/inputs/custom_drop_down.dart';
import 'package:adhisaat_health_care/shared/widgets/inputs/custom_text_field.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart' show LocationPermission;
import 'package:open_filex/open_filex.dart';
import 'package:place_picker_google/place_picker_google.dart';

import '../../../../core/api/redirection_url.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/services/file_downloading_service.dart' as file_download;
import '../../../../core/services/launch_url_service.dart';
import '../../../../core/services/location_service.dart' hide LocationResult;
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/pdf_generator_service.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/message_service.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/location_permission_dialog.dart';
import '../../../../data/models/dropdown_response_model.dart';
import '../../../../data/models/user_profile_model.dart';
import '../../../../shared/utils/consent_helper.dart';
import '../../../../shared/widgets/buttons/custom_button.dart';
import '../../../../shared/widgets/dialogs/custom_bottom_sheets.dart';
import '../../../../shared/widgets/dialogs/dialog_helpers.dart';
import '../../../auth/login/bloc/auth_bloc.dart';
import '../../../user/address/model/user_address_model.dart';
import '../../../user/home/view/search_address_page.dart';
import '../bloc/provider_profile/provider_profile_registration_bloc.dart';
import '../models/provider_profile_model.dart';
import '../widgets/multi_select_chips.dart';
import '../widgets/service_category_selection_sheet.dart';

class ProviderProfileRegistrationPage extends StatelessWidget {
  final String mobileNumber;
  final int? userId;

  const ProviderProfileRegistrationPage({super.key, required this.mobileNumber, this.userId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProviderProfileRegistrationBloc(locator<AuthRepository>())..add(FetchDropdownData()),
      child: ProviderProfileRegistrationContent(mobileNumber: mobileNumber, userId: userId),
    );
  }
}

class ProviderProfileRegistrationContent extends HookWidget {
  final String mobileNumber;
  final int? userId;

  const ProviderProfileRegistrationContent({super.key, required this.mobileNumber, this.userId});

  @override
  Widget build(BuildContext context) {
    // Cache dropdown data so it survives transient submit/error states.
    final genders = useState<Map<String, String>>({});
    final experiences = useState<Map<String, String>>({});
    final dutyTypes = useState<Map<String, String>>({});
    final bloodGroups = useState<Map<String, String>>({});
    final serviceCategories = useState<List<ServiceCategory>>([]);
    final documentTypes = useState<Map<String, String>>({});

    // ── Personal Info controllers ─────────────────────────────────
    final nameController = useTextEditingController();
    final mobileController = useTextEditingController(text: mobileNumber);
    final whatsappController = useTextEditingController();
    final emailController = useTextEditingController();
    final dobController = useTextEditingController();
    final eighteenYearsAgo = useMemoized(() {
      final now = DateTime.now();
      return DateTime(now.year - 18, now.month, now.day);
    }, []);
    final dateOfBirth = useState<DateTime>(eighteenYearsAgo);
    final selectedGender = useState<String?>(null);
    final selectedBloodGroup = useState<String?>(null);
    final aadharNoController = useTextEditingController();
    final panNoController = useTextEditingController();
    final referralCodeController = useTextEditingController();
    final referredById = useState<String?>(null);
    final referralError = useState<String?>(null);

    // ── Professional Details controllers ─────────────────────────
    final qualificationController = useTextEditingController();
    final selectedExperience = useState<String?>(null);
    final registrationNumberController = useTextEditingController();
    final councilController = useTextEditingController();
    final previousWorkplaceController = useTextEditingController();

    // ── Availability & Skills ────────────────────────────────────
    final selectedCategories = useState<List<String>>([]);
    // final selectedDutyTypes = useState<List<String>>([]);
    final selectedSkills = useState<List<String>>([]);
    final preferredAreaController = useTextEditingController();

    // ── Address controllers ──────────────────────────────────────
    final addressController = useTextEditingController();
    final areaController = useTextEditingController();
    final cityController = useTextEditingController();
    final stateController = useTextEditingController();
    final pinCodeController = useTextEditingController();
    final isLocating = useState(false);
    final latitude = useState<String>('');
    final longitude = useState<String>('');
    final cityAdminId = useState<int?>(null);
    final profileImagePath = useState<String?>(null);

    // ── Required Documents (file picks) ──────────────────────────
    // aadharFilePath = the FINAL single PDF sent to backend (either an uploaded
    // UIDAI PDF, or one generated by merging front+back images).
    final aadharFilePath = useState<String?>(null);
    final aadhaarFrontPath = useState<String?>(null);
    final aadhaarBackPath = useState<String?>(null);
    final isGeneratingAadhaar = useState(false);
    final aadhaarMethod = useState<String>('photo'); // 'photo' | 'pdf'
    final panFilePath = useState<String?>(null);
    final dynamicDocumentTypes = useState<List<DynamicDocumentType>>([]);

    // ── Bank Details controllers ─────────────────────────────────
    final accountHolderNameController = useTextEditingController();
    final accountNumberController = useTextEditingController();
    final ifscController = useTextEditingController();
    final bankNameController = useTextEditingController();
    final branchNameController = useTextEditingController();
    final accountType = useState<String>('Savings');

    // ── Professional Documents ────────────────────────────────────
    final professionalDocs = useState<List<ProfessionalDocument>>([
      ProfessionalDocument(
        documentType: 'registration',
      ), // Explicitly set first doc to 'registration' to match API
    ]);

    // ── Declaration ──────────────────────────────────────────────
    final isDeclared = useState(false);

    final formKey = useMemoized(() => GlobalKey<FormState>());
    final currentStep = useState(0);
    final maxStepReached = useState(0);
    final scrollController = useScrollController();

    final hasAttemptedAddressNext = useState(false);

    // Make the builder reactive to pin code typing
    useListenable(pinCodeController);
    useListenable(accountHolderNameController);
    useListenable(accountNumberController);
    useListenable(ifscController);
    useListenable(bankNameController);
    useListenable(branchNameController);

    final isBankOptional =
        accountHolderNameController.text.trim().isEmpty &&
        accountNumberController.text.trim().isEmpty &&
        ifscController.text.trim().isEmpty &&
        bankNameController.text.trim().isEmpty &&
        branchNameController.text.trim().isEmpty;

    // Fetch GPS once on mount
    useEffect(() {
      _autofillAddress(
        context,
        latitude,
        longitude,
        addressController,
        areaController,
        cityController,
        stateController,
        pinCodeController,
      );
      return null;
    }, []);

    useEffect(() {
      if (currentStep.value != 1) {
        hasAttemptedAddressNext.value = false;
      }
      return null;
    }, [currentStep.value]);

    useEffect(() {
      void onPinChanged() {
        if (pinCodeController.text.length == 6) {
          context.read<ProviderProfileRegistrationBloc>().add(CheckServiceAvailability(pinCodeController.text));
        }
      }

      pinCodeController.addListener(onPinChanged);
      return () => pinCodeController.removeListener(onPinChanged);
    }, [pinCodeController]);

    void pickProfileImage() async {
      final path = await _pickFile(showFiles: false);
      if (path != null) {
        profileImagePath.value = path;
      }
    }

    // ── Aadhaar KYC handlers ──────────────────────────────────────
    Future<void> generateAadhaarPdf() async {
      // Front is mandatory; back is optional (single-page PDF if back absent).
      if (aadhaarFrontPath.value == null) return;
      final paths = [aadhaarFrontPath.value!, if (aadhaarBackPath.value != null) aadhaarBackPath.value!];
      isGeneratingAadhaar.value = true;
      try {
        final pdf = await PdfGeneratorService.imagesToPdf(paths.map((p) => File(p)).toList(), fileName: 'aadhaar');
        aadharFilePath.value = pdf.path;
      } catch (_) {
        MessageService.showError('Failed to generate Aadhaar PDF. Please try again.');
      } finally {
        isGeneratingAadhaar.value = false;
      }
    }

    // Option 1: upload UIDAI PDF directly — opens the system file chooser (PDF only).
    Future<void> pickAadhaarPdf() async {
      final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      final path = result?.files.single.path;
      if (path == null) return;
      if (!path.toLowerCase().endsWith('.pdf')) {
        MessageService.showError('Please select a PDF file downloaded from the UIDAI portal.');
        return;
      }
      final size = await File(path).length();
      if (size > AppConstants.maxFileSize) {
        MessageService.showError('File size too large. Maximum limit is ${AppConstants.maxFileSizeMB}MB.');
        return;
      }
      // Switch to PDF mode — clear any image-flow state.
      aadhaarFrontPath.value = null;
      aadhaarBackPath.value = null;
      aadharFilePath.value = path;
    }

    // Option 2: upload front / back card image.
    Future<void> pickAadhaarImage({required bool isFront}) async {
      final path = await _pickFile(showFiles: false, showCamera: true, showGallery: true);
      if (path == null) return;
      final isImage = ['.jpg', '.jpeg', '.png'].any((e) => path.toLowerCase().endsWith(e));
      if (!isImage) {
        MessageService.showError('Please select a JPG or PNG image.');
        return;
      }
      if (isFront) {
        aadhaarFrontPath.value = path;
      } else {
        aadhaarBackPath.value = path;
      }
      // Regenerate the PDF whenever the front side is present (back optional).
      aadharFilePath.value = null;
      if (aadhaarFrontPath.value != null) {
        await generateAadhaarPdf();
      }
    }

    void deleteAadhaar() {
      aadhaarFrontPath.value = null;
      aadhaarBackPath.value = null;
      aadharFilePath.value = null;
    }

    Future<void> previewAadhaar() async {
      if (aadharFilePath.value != null) {
        await OpenFilex.open(aadharFilePath.value!);
      }
    }

    void selectAadhaarMethod(String method) {
      if (aadhaarMethod.value == method) return;
      deleteAadhaar(); // reset so each method starts fresh
      aadhaarMethod.value = method;
    }

    void showAadhaarInstructions() {
      showModalBottomSheet(
        context: context,
        backgroundColor: kWhiteColor,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
        builder: (_) => _AadhaarInstructionsSheet(method: aadhaarMethod.value),
      );
    }

    // ── Submit handler ────────────────────────────────────────────
    void handleSubmit(BuildContext context) {
      // Aadhaar must resolve to a single PDF (uploaded directly or generated from images).
      if (aadharFilePath.value == null) {
        if (aadhaarFrontPath.value != null) {
          DialogHelper.showError(
            title: 'Required Document',
            message: 'Aadhaar PDF is still generating. Please wait a moment.',
          );
        } else {
          DialogHelper.showError(
            title: 'Required Document',
            message: 'Please upload your Aadhaar document (PDF or front side image).',
            buttonText: 'Upload',
            onConfirm: () async {
              Navigator.pop(context);
              if (aadhaarMethod.value == 'pdf') {
                await pickAadhaarPdf();
              } else {
                await pickAadhaarImage(isFront: true);
              }
            },
          );
        }
        return;
      }
      if (panFilePath.value == null) {
        DialogHelper.showError(
          title: 'Required Document',
          message: 'Please upload your PAN card.',
          buttonText: 'Upload',
          onConfirm: () async {
            Navigator.pop(context);
            final path = await _pickFile(showFiles: true, showCamera: true, showGallery: true);
            if (path != null) panFilePath.value = path;
          },
        );
        return;
      }

      final dob = AppDateFormatter.dateForApi(dateOfBirth.value.toString());

      // Validate professional documents
      for (int i = 0; i < professionalDocs.value.length; i++) {
        final doc = professionalDocs.value[i];
        final typeConfig = dynamicDocumentTypes.value.firstWhere(
          (element) => element.key == doc.documentType,
          orElse: () => DynamicDocumentType(
            id: 0,
            key: doc.documentType ?? '',
            name: documentTypes.value[doc.documentType] ?? 'Professional Document',
            isRequired: false,
            isActive: true,
          ),
        );

        final hasName = (doc.documentName ?? '').trim().isNotEmpty;
        final hasNumber = (doc.documentNumber ?? '').trim().isNotEmpty;
        final hasFile = (doc.filePath ?? '').isNotEmpty;
        final hasAny = hasName || hasNumber || hasFile;

        if (hasAny) {
          if (!hasName) {
            MessageService.showError('Please enter Document Name for ${typeConfig.name}');
            return;
          }
          if (!hasFile) {
            DialogHelper.showWarning(
              title: typeConfig.name,
              message: 'Please upload the document file for ${typeConfig.name}.',
              buttonText: 'Upload',
              // barrierDismissible: true,
              onConfirm: () async {
                Navigator.pop(context);
                final path = await _pickFile(showFiles: true, showCamera: true, showGallery: true);
                if (path != null) {
                  final list = List<ProfessionalDocument>.from(professionalDocs.value);
                  list[i] = doc.copyWith(filePath: path);
                  professionalDocs.value = list;
                }
              },
            );
            return;
          }
        }
      }
      if (!isDeclared.value) {
        MessageService.showWarning('Please accept the declaration to proceed.');
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
        return;
      }

      final docs = professionalDocs.value;

      final request = ProviderProfileRequest(
        userId: userId,
        cityAdminId: cityAdminId.value,
        name: nameController.text,
        mobile: mobileNumber,
        whatsapp: whatsappController.text,
        email: emailController.text,
        dob: dob,
        gender: selectedGender.value,
        bloodGroup: selectedBloodGroup.value,
        aadharNo: aadharNoController.text,
        panNo: panNoController.text.toUpperCase(),
        qualification: qualificationController.text,
        experience: selectedExperience.value,
        registrationNumber: registrationNumberController.text,
        councilName: councilController.text,
        previousWorkplace: previousWorkplaceController.text,
        serviceCategoryIds: selectedCategories.value,
        // dutyTypes: selectedDutyTypes.value,
        skills: selectedSkills.value,
        preferredArea: preferredAreaController.text,
        addressType: 'home',
        // Default for registration
        address: addressController.text,
        area: areaController.text,
        city: cityController.text,
        state: stateController.text,
        pinCode: pinCodeController.text,
        lat: latitude.value,
        long: longitude.value,
        aadharCardPath: aadharFilePath.value,
        panCardPath: panFilePath.value,
        profileImagePath: profileImagePath.value,
        professionalDocuments: docs.isEmpty ? null : docs,
        referralCode: referralCodeController.text.trim(),
        referredBy: referredById.value,
        accountHolderName:
            (accountHolderNameController.text.trim().isNotEmpty ||
                accountNumberController.text.trim().isNotEmpty ||
                ifscController.text.trim().isNotEmpty ||
                bankNameController.text.trim().isNotEmpty ||
                branchNameController.text.trim().isNotEmpty)
            ? accountHolderNameController.text.trim()
            : null,
        accountNumber:
            (accountHolderNameController.text.trim().isNotEmpty ||
                accountNumberController.text.trim().isNotEmpty ||
                ifscController.text.trim().isNotEmpty ||
                bankNameController.text.trim().isNotEmpty ||
                branchNameController.text.trim().isNotEmpty)
            ? accountNumberController.text.trim()
            : null,
        ifscCode:
            (accountHolderNameController.text.trim().isNotEmpty ||
                accountNumberController.text.trim().isNotEmpty ||
                ifscController.text.trim().isNotEmpty ||
                bankNameController.text.trim().isNotEmpty ||
                branchNameController.text.trim().isNotEmpty)
            ? ifscController.text.trim().toUpperCase()
            : null,
        bankName:
            (accountHolderNameController.text.trim().isNotEmpty ||
                accountNumberController.text.trim().isNotEmpty ||
                ifscController.text.trim().isNotEmpty ||
                bankNameController.text.trim().isNotEmpty ||
                branchNameController.text.trim().isNotEmpty)
            ? bankNameController.text.trim()
            : null,
        branchName:
            (accountHolderNameController.text.trim().isNotEmpty ||
                accountNumberController.text.trim().isNotEmpty ||
                ifscController.text.trim().isNotEmpty ||
                bankNameController.text.trim().isNotEmpty ||
                branchNameController.text.trim().isNotEmpty)
            ? branchNameController.text.trim()
            : null,
        accountType:
            (accountHolderNameController.text.trim().isNotEmpty ||
                accountNumberController.text.trim().isNotEmpty ||
                ifscController.text.trim().isNotEmpty ||
                bankNameController.text.trim().isNotEmpty ||
                branchNameController.text.trim().isNotEmpty)
            ? accountType.value.toLowerCase()
            : null,
      );

      context.read<ProviderProfileRegistrationBloc>().add(SubmitProviderProfile(request));
    }

    void proceedToNextStep(BuildContext context) {
      kPrint(selectedCategories.value);

      if (currentStep.value == 5) {
        // First check: If Aadhaar file is not uploaded, show dialog popup instead of form validation.
        if (aadharFilePath.value == null) {
          if (aadhaarFrontPath.value != null) {
            DialogHelper.showInfo(
              title: 'Required Document',
              message: 'Aadhaar PDF is still generating. Please wait a moment.',
            );
          } else {
            DialogHelper.showWarning(
              title: 'Required Document',
              message: 'Please upload your Aadhaar document (PDF or front side image).',
              buttonText: 'Upload',
              onConfirm: () async {
                Navigator.pop(context);
                if (aadhaarMethod.value == 'pdf') {
                  await pickAadhaarPdf();
                } else {
                  await pickAadhaarImage(isFront: true);
                }
              },
            );
          }
          return;
        }

        // Second check: If PAN card file is not uploaded, show dialog popup instead of form validation.
        if (panFilePath.value == null) {
          DialogHelper.showWarning(
            title: 'Required Document',
            message: 'Please upload your PAN card.',
            buttonText: 'Upload',
            onConfirm: () async {
              Navigator.pop(context);
              final path = await _pickFile(showFiles: true, showCamera: true, showGallery: true);
              if (path != null) panFilePath.value = path;
            },
          );
          return;
        }
      }

      if (!formKey.currentState!.validate()) {
        // Find the first FormFieldState with an error and scroll to it
        void scrollToFirstError(BuildContext ctx) {
          FormFieldState? firstErrorField;

          void visitor(Element element) {
            if (firstErrorField != null) return; // already found

            if (element is StatefulElement && element.state is FormFieldState) {
              final formFieldState = element.state as FormFieldState;
              if (formFieldState.hasError) {
                firstErrorField = formFieldState;
                return;
              }
            }
            element.visitChildren(visitor);
          }

          ctx.visitChildElements(visitor);

          if (firstErrorField != null) {
            Scrollable.ensureVisible(
              firstErrorField!.context,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: 0.1, // Scroll so it is near the top
            );
          }
        }

        scrollToFirstError(context);
        return;
      }

      if (currentStep.value == 1) {
        if (pinCodeController.text.length != 6 || cityAdminId.value == null) {
          hasAttemptedAddressNext.value = true;
          return;
        }
      }

      if (currentStep.value == 3) {
        if (selectedCategories.value.isEmpty) {
          MessageService.showWarning('Please select at least one service category.');
          return;
        }
        // if (selectedDutyTypes.value.isEmpty) {
        //   MessageService.showError('Please select at least one duty type.');
        //   return;
        // }
      }

      if (currentStep.value < 5) {
        currentStep.value++;
        if (currentStep.value > maxStepReached.value) {
          maxStepReached.value = currentStep.value;
        }
      } else {
        handleSubmit(context);
      }
    }

    Future<void> handleBackPress() async {
      final shouldPop = await DialogHelper.showConfirmation(
        title: 'Discard Changes?',
        message: 'Are you sure you want to exit? Your registration progress will be lost.',
        confirmText: 'Exit',
        cancelText: 'Stay',
        isDangerous: true,
      );

      if (shouldPop == true && context.mounted) {
        Navigator.pop(context);
      }
    }

    void goBackStep() {
      if (currentStep.value > 0) {
        currentStep.value--;
      } else {
        handleBackPress();
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await handleBackPress();
      },
      child: Scaffold(
        appBar: CustomAppBar(title: 'Partner Registration', onBack: handleBackPress),
        body: SafeArea(
          child: BlocConsumer<ProviderProfileRegistrationBloc, ProviderProfileRegistrationState>(
            listener: (context, state) async {
              // ── Populate dropdowns safely in listener (never in builder) ──
              if (state is DropdownLoaded) {
                genders.value = state.genders;
                experiences.value = state.experiences;
                dutyTypes.value = state.dutyTypes;
                bloodGroups.value = state.bloodGroups;
                documentTypes.value = state.documentType;

                // Sort dynamicDocumentTypes: mandatory (isRequired: true) first
                final sortedTypes = List<DynamicDocumentType>.from(state.dynamicDocumentTypes);
                sortedTypes.sort((a, b) {
                  if (a.isRequired && !b.isRequired) return -1;
                  if (!a.isRequired && b.isRequired) return 1;
                  return 0;
                });
                dynamicDocumentTypes.value = sortedTypes;

                // Pre-populate professionalDocs based on sorted dynamicDocumentTypes
                if (sortedTypes.isNotEmpty &&
                    (professionalDocs.value.isEmpty ||
                        (professionalDocs.value.length == 1 &&
                            professionalDocs.value[0].documentName == null &&
                            professionalDocs.value[0].filePath == null))) {
                  professionalDocs.value = sortedTypes
                      .map((type) => ProfessionalDocument(documentType: type.key))
                      .toList();
                }
              }
              if (state is ServiceAvailabilityLoaded) {
                serviceCategories.value = state.serviceCategories;
                cityAdminId.value = state.cityAdminId;
              }
              if (state is ServiceAvailabilityUnavailable) {
                serviceCategories.value = [];
                cityAdminId.value = null;
                DialogHelper.showError(title: 'Service Not Available', message: state.message);
              }
              // Consent states are now handled by ConsentHelper directly in the UI
              if (state is ProfileSuccess) {
                MessageService.showSuccess('Registration Successful!');
                final String token = state.data['access_token'].toString();
                await locator<LocalStorageService>().saveToken(token);
                final userData = state.data['user'] ?? {};
                await locator<LocalStorageService>().saveUser(userData);
                final String? fcmToken = await locator<NotificationService>().getFCMToken();
                if (fcmToken != null && context.mounted) {
                  context.read<AuthBloc>().add(UpdateFcmTokenEvent(fcmToken));
                }

                // IMPORTANT: Notify AuthBloc about the successful login
                if (context.mounted) {
                  final userModel = UserProfileModel.fromJson(userData);
                  context.read<AuthBloc>().add(LoginSuccess(user: userModel, token: token));
                  // Note: SelectedAddressCubit is customer-only; providers don't use it.
                }

                AppNavigator.removeAndGo(AppRoutes.providerDashboard);
              }
              if (state is ProfileError) {
                String errorMessage = state.message;
                if (state.errors != null && state.errors!.isNotEmpty) {
                  final firstErrorKey = state.errors!.keys.first;
                  // Personal Info step (0)
                  if (const [
                    'name',
                    'mobile_number',
                    'whatsapp_number',
                    'email',
                    'date_of_birth',
                    'gender',
                    'blood_group',
                    'aadhar_no',
                    'pan_number',
                  ].contains(firstErrorKey)) {
                    currentStep.value = 0;
                  }
                  // Address details step (1)
                  else if (const [
                    'full_address',
                    'area',
                    'city',
                    'state',
                    'pin_code',
                    'latitude',
                    'longitude',
                  ].contains(firstErrorKey)) {
                    currentStep.value = 1;
                  }
                  // Professional Details step (2)
                  else if (const [
                    'highest_qualification',
                    'total_experience',
                    'professional_registration_number',
                    'council_board_name',
                    'previous_workplace',
                  ].contains(firstErrorKey)) {
                    currentStep.value = 2;
                  }
                  // Services & Skills step (3)
                  else if (firstErrorKey.contains('service_category_ids') ||
                      firstErrorKey.contains('duty_type') ||
                      firstErrorKey.contains('skills') ||
                      firstErrorKey == 'preferred_working_area') {
                    currentStep.value = 3;
                  }
                  // Bank Details step (4)
                  else if (const [
                    'account_holder_name',
                    'account_number',
                    'ifsc_code',
                    'bank_name',
                    'branch_name',
                    'account_type',
                  ].contains(firstErrorKey)) {
                    currentStep.value = 4;
                  }
                  // Documents step (5)
                  else if (firstErrorKey.contains('aadhar_file_path') ||
                      firstErrorKey.contains('pan_file_path') ||
                      firstErrorKey.contains('profile_image') ||
                      firstErrorKey.contains('documents')) {
                    currentStep.value = 5;
                  }

                  // Scroll to top of the content so user can see it
                  if (scrollController.hasClients) {
                    scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }

                  final firstError = state.errors!.values.first;
                  if (firstError is List && firstError.isNotEmpty) {
                    errorMessage = firstError.first.toString();
                  } else {
                    errorMessage = firstError.toString();
                  }
                }
                MessageService.showError(errorMessage);
              }
              if (state is ReferralCodeValidated) {
                MessageService.showSuccess(state.message);
                referredById.value = state.referredById.toString();
                referralError.value = null;
              }
              if (state is ReferralCodeInvalid) {
                // MessageService.showError(state.message); // Disable toast to avoid redundancy
                referredById.value = null;
                referralError.value = state.message;
              }
            },
            builder: (context, state) {
              if (state is DropdownLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is ProfileLoading) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Submitting your profile…'),
                    ],
                  ),
                );
              }
              // DropdownLoaded: useState values already set in listener — just render the form.

              return Column(
                children: [
                  _StepProgressIndicator(
                    currentStep: currentStep.value,
                    onStepTapped: (index) {
                      // Allow switching only between completed / filled steps
                      // Users can jump to any previously reached step
                      if (index <= maxStepReached.value) {
                        currentStep.value = index;
                      }
                      // Or move to the immediate next step if current step is valid
                      else if (index == currentStep.value + 1) {
                        proceedToNextStep(context);
                      }
                    },
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: AppPadding.m,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (currentStep.value == 0) ...[
                              // Profile Image Upload
                              Center(
                                child: Stack(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.12),
                                            blurRadius: 15,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 56.r,
                                        backgroundColor: Colors.grey[100],
                                        backgroundImage: profileImagePath.value != null
                                            ? FileImage(File(profileImagePath.value!))
                                            : null,
                                        child: profileImagePath.value == null
                                            ? Icon(Icons.person_rounded, size: 55.r, color: Colors.grey[400])
                                            : null,
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: InkWell(
                                        onTap: pickProfileImage,
                                        child: Container(
                                          padding: EdgeInsets.all(10.r),
                                          decoration: BoxDecoration(
                                            color: kPrimaryColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2.5),
                                            boxShadow: [
                                              BoxShadow(
                                                color: kPrimaryColor.withValues(alpha: 0.3),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18.r),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AppSpacing.mVertical,

                              // 1. PERSONAL INFORMATION
                              _SectionHeader(title: 'Personal Information', icon: Icons.person_outline, index: 1),
                              AppSpacing.mVertical,

                              CustomTextField(
                                controller: nameController,
                                labelText: 'Full Name (As per your Aadhaar)',
                                hintText: 'Enter your full name',
                                isRequired: true,
                                keyboardType: TextInputType.name,
                              ),
                              CustomTextField(
                                controller: mobileController,
                                labelText: 'Mobile Number',
                                isRequired: true,
                                enabled: false,
                                keyboardType: TextInputType.phone,
                              ),
                              AppSpacing.sHorizontal,
                              CustomTextField(
                                controller: whatsappController,
                                labelText: 'WhatsApp Number',
                                isRequired: false,
                                isNumeric: true,
                                maxLength: 10,
                                keyboardType: TextInputType.phone,
                                prefixIcon: const Icon(Icons.chat_outlined),
                                suffixIcon: whatsappController.text.isEmpty
                                    ? TextButton(
                                        onPressed: () => whatsappController.text = mobileController.text,
                                        child: Text('Same', style: kTextSemiBold(color: kPrimaryColor)),
                                      )
                                    : null,
                                validator: (value) {
                                  if (value == null || value.isEmpty) return null;
                                  if (value.length != 10) return 'Enter valid 10-digit number';
                                  return null;
                                },
                              ),
                              EmailTextField(controller: emailController),
                              DatePickerTextField(
                                controller: dobController,
                                labelText: 'Date of Birth',
                                isRequired: true,
                                initialDate: dateOfBirth.value,
                                lastDate: eighteenYearsAgo,
                                onDateSelected: (date) => dateOfBirth.value = date,
                                validator: (value) {
                                  if (value == null || value.isEmpty) return "Date of Birth is required";
                                  final today = DateTime.now();
                                  var age = today.year - dateOfBirth.value.year;
                                  if (today.month < dateOfBirth.value.month ||
                                      (today.month == dateOfBirth.value.month &&
                                          today.day < dateOfBirth.value.day)) {
                                    age--;
                                  }
                                  if (age < 18) return "You must be at least 18 years old to register.";
                                  return null;
                                },
                              ),
                              CustomDropDown(
                                labelText: 'Gender',
                                isRequired: true,
                                items: mapToDropdownItems(genders.value),
                                onChanged: (val) => selectedGender.value = val,
                                value: selectedGender.value,
                              ),
                              CustomTextField(
                                enabled: state is! ReferralCodeValidated,
                                controller: referralCodeController,
                                labelText: 'Referral Code',
                                hintText: 'Enter referral code (optional)',
                                capitalizeSentences: true,
                                maxLength: 6,
                                onChanged: (val) {
                                  if (referralError.value != null) referralError.value = null;
                                  final upperVal = val.toUpperCase();
                                  if (upperVal.length >= 6) {
                                    context.read<ProviderProfileRegistrationBloc>().add(
                                      ValidateReferralCode(upperVal),
                                    );
                                  }
                                },
                                errorText: referralError.value,
                                suffixIcon: state is ReferralCodeValidationLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      )
                                    : state is ReferralCodeValidated
                                    ? const Icon(Icons.check_circle, color: kSuccessColor)
                                    : state is ReferralCodeInvalid
                                    ? const Icon(Icons.error, color: kErrorColor)
                                    : null,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                                  UpperCaseTextFormatter(),
                                ],
                                textCapitalization: TextCapitalization.characters,
                              ),
                              CustomDropDown(
                                labelText: 'Blood Group',
                                items: mapToDropdownItems(bloodGroups.value),
                                onChanged: (val) => selectedBloodGroup.value = val,
                                value: selectedBloodGroup.value,
                              ),

                              AppSpacing.xlVertical,

                              AppSpacing.xxxlVertical,
                            ],
                            if (currentStep.value == 1) ...[
                              // 2. ADDRESS DETAILS
                              _SectionHeader(title: 'Address Details', icon: Icons.location_on_outlined, index: 2),
                              AppSpacing.mVertical,

                              // Use My Location button
                              _UseMyLocationButton(
                                isLocating: isLocating.value,
                                onTap: () async {
                                  isLocating.value = true;
                                  await _autofillAddress(
                                    context,
                                    latitude,
                                    longitude,
                                    addressController,
                                    areaController,
                                    cityController,
                                    stateController,
                                    pinCodeController,
                                  );
                                  isLocating.value = false;
                                },
                              ),

                              // Change Location button
                              Padding(
                                padding: AppPadding.only(bottom: 16),
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final dynamic result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const SearchAddressPage(hideSavedAddresses: true, returnResult: true),
                                      ),
                                    );

                                    if (result != null) {
                                      // Result can be LocationResult (from LocationPicker) or UserAddressModel (from Search results)
                                      if (result is LocationResult) {
                                        latitude.value = result.latLng?.latitude.toString() ?? '';
                                        longitude.value = result.latLng?.longitude.toString() ?? '';
                                        addressController.text = result.formattedAddress ?? '';
                                        cityController.text = result.locality?.longName?.toString() ?? '';
                                        stateController.text =
                                            result.administrativeAreaLevel1?.longName?.toString() ?? '';
                                        pinCodeController.text = result.postalCode?.longName.toString() ?? '';
                                        areaController.text = result.subLocalityLevel1?.longName?.toString() ?? '';
                                      } else if (result is UserAddressModel) {
                                        latitude.value = result.latitude ?? '';
                                        longitude.value = result.longitude ?? '';
                                        addressController.text = result.fullAddress;
                                        cityController.text = result.city ?? '';
                                        stateController.text = result.state ?? '';
                                        pinCodeController.text = result.pinCode ?? '';
                                        areaController.text = result.area ?? '';
                                      }
                                    }
                                  },
                                  icon: Icon(Icons.map_outlined, size: 16.sp, color: kPrimaryColor),
                                  label: Text(
                                    'Local Home Location',
                                    style: kTextMedium(color: kPrimaryColor),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: kPrimaryColor,
                                    side: const BorderSide(color: kPrimaryColor),
                                    shape: RoundedRectangleBorder(borderRadius: AppRadius.s),
                                    padding: AppPadding.symmetric(h: 12, v: 8),
                                  ),
                                ),
                              ),

                              CustomTextField(
                                controller: addressController,
                                labelText: 'Full Address',
                                hintText: 'House/Flat No., Street, Locality…',
                                maxLines: 4,
                                minLines: 2,
                                isRequired: true,
                              ),
                              CustomTextField(
                                controller: areaController,
                                labelText: 'Preferred working area',
                                hintText: 'Preferred working area',
                              ),
                              // City, State, PIN Code TextFields removed from UI as requested
                              AppSpacing.xlVertical,
                            ],
                            if (currentStep.value == 2) ...[
                              // 3. PROFESSIONAL DETAILS
                              _SectionHeader(
                                title: 'Professional Details',
                                icon: Icons.medical_services_outlined,
                                index: 3,
                              ),
                              AppSpacing.mVertical,

                              CustomTextField(
                                controller: qualificationController,
                                labelText: 'Highest Qualification',
                                hintText: 'M.Sc. Nursing / B.Sc. Nursing / GNM or Other',
                                isRequired: true,
                              ),
                              CustomDropDown(
                                labelText: 'Total Experience',
                                isRequired: true,
                                items: mapToDropdownItems(experiences.value),
                                onChanged: (val) => selectedExperience.value = val,
                                value: selectedExperience.value,
                              ),
                              CustomTextField(
                                controller: registrationNumberController,
                                labelText: 'Registration Number',
                                hintText: 'Professional reg. no.',
                              ),
                              CustomTextField(
                                controller: councilController,
                                labelText: 'Council / Board Name',
                                hintText: 'RNC / Other',
                              ),
                              CustomTextField(
                                controller: previousWorkplaceController,
                                labelText: 'Previous Workplace',
                                hintText: 'Previous Hospital / Clinic / Other',
                              ),
                              AppSpacing.xlVertical,
                            ],
                            if (currentStep.value == 3) ...[
                              // 4. AVAILABILITY & SKILLS
                              _SectionHeader(title: 'Services', icon: Icons.schedule_outlined, index: 4),
                              AppSpacing.mVertical,

                              CustomLabelForTextField(title: 'Services', isRequired: true),
                              CategorySelectionTile(
                                selectedCategories: selectedCategories.value,
                                allCategories: serviceCategories.value,
                                onTap: () async {
                                  final result = await ServiceCategorySelectionSheet.showCategoryPicker(
                                    context,
                                    allCategories: serviceCategories.value,
                                    selectedIds: selectedCategories.value,
                                  );
                                  if (result is List<String>) {
                                    selectedCategories.value = result;
                                  }
                                },
                              ),

                              // CustomLabelForTextField(title: 'Duty Type', isRequired: true),
                              // GenericSelectionTile(
                              //   title: 'Duty Type',
                              //   hint: 'Select your shift availability',
                              //   icon: Icons.access_time_filled_rounded,
                              //   selectedCount: selectedDutyTypes.value.length,
                              //   onTap: () async {
                              //     final result = await SimpleMultiSelectionSheet.show(
                              //       context: context,
                              //       title: 'Select Duty Type',
                              //       options: dutyTypes.value,
                              //       initialSelected: selectedDutyTypes.value,
                              //     );
                              //     if (result != null) {
                              //       selectedDutyTypes.value = result;
                              //     }
                              //   },
                              // ),
                              // CustomLabelForTextField(title: 'Skills', isRequired: false),
                              // GenericSelectionTile(
                              //   title: 'Skills',
                              //   hint: 'Select your skills & specializations',
                              //   icon: Icons.psychology_outlined,
                              //   selectedCount: selectedSkills.value.length,
                              //   onTap: () async {
                              //     final result = await SkillsSelectionSheet.show(
                              //       context: context,
                              //       suggestions: SkillSuggestions.healthcareSkills,
                              //       initialSelected: selectedSkills.value,
                              //     );
                              //     if (result != null) {
                              //       selectedSkills.value = result;
                              //     }
                              //   },
                              // ),

                              // CustomTextField(
                              //   controller: preferredAreaController,
                              //   labelText: 'Preferred Working Area',
                              //   hintText: 'Preferred city/area for work',
                              // ),
                              AppSpacing.xlVertical,
                              kSizedBox(height: 160.h),
                            ],
                            if (currentStep.value == 4) ...[
                              _SectionHeader(
                                title: 'Bank Details',
                                icon: Icons.account_balance_outlined,
                                index: 5,
                              ),
                              AppSpacing.mVertical,
                              Container(
                                padding: AppPadding.l,
                                decoration: BoxDecoration(
                                  color: kWhiteColor,
                                  borderRadius: AppRadius.l,
                                  border: Border.all(color: kBorderColor),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CustomTextField(
                                      controller: accountHolderNameController,
                                      labelText: 'Account Holder Name',
                                      hintText: 'Enter account holder name',
                                      keyboardType: TextInputType.name,
                                      isRequired: !isBankOptional,
                                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
                                      validator: (v) {
                                        if (isBankOptional) return null;
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Please enter account holder name';
                                        }
                                        if (v.trim().length < 3) return 'Name must be at least 3 characters';
                                        return null;
                                      },
                                    ),
                                    AppSpacing.mVertical,
                                    CustomTextField(
                                      controller: accountNumberController,
                                      labelText: 'Account Number',
                                      hintText: 'Enter account number',
                                      keyboardType: TextInputType.number,
                                      isNumeric: true,
                                      maxLength: 18,
                                      isRequired: !isBankOptional,
                                      validator: (v) {
                                        if (isBankOptional) return null;
                                        if (v == null || v.trim().isEmpty) return 'Please enter account number';
                                        if (v.trim().length < 9) return 'Account number must be at least 9 digits';
                                        if (v.trim().length > 18) return 'Account number cannot exceed 18 digits';
                                        return null;
                                      },
                                    ),
                                    AppSpacing.mVertical,
                                    CustomTextField(
                                      controller: ifscController,
                                      labelText: 'IFSC Code',
                                      hintText: 'E.g. SBIN0001234',
                                      capitalizeAll: true,
                                      maxLength: 11,
                                      isRequired: !isBankOptional,
                                      validator: (v) {
                                        if (isBankOptional) return null;
                                        if (v == null || v.trim().isEmpty) return 'Please enter IFSC code';
                                        final ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
                                        if (!ifscRegex.hasMatch(v.trim().toUpperCase())) {
                                          return 'Enter a valid IFSC code (e.g. SBIN0001234)';
                                        }
                                        return null;
                                      },
                                    ),
                                    AppSpacing.mVertical,
                                    CustomTextField(
                                      controller: bankNameController,
                                      labelText: 'Bank Name',
                                      hintText: 'Enter bank name',
                                      keyboardType: TextInputType.name,
                                      isRequired: !isBankOptional,
                                      validator: (v) {
                                        if (isBankOptional) return null;
                                        if (v == null || v.trim().isEmpty) return 'Please enter bank name';
                                        if (v.trim().length < 2) return 'Bank name must be at least 2 characters';
                                        return null;
                                      },
                                    ),
                                    // AppSpacing.mVertical,
                                    // CustomTextField(
                                    //   controller: branchNameController,
                                    //   labelText: 'Branch Name',
                                    //   hintText: 'Enter branch name',
                                    //   keyboardType: TextInputType.name,
                                    //   isRequired: !isBankOptional,
                                    //   validator: (v) {
                                    //     if (isBankOptional) return null;
                                    //     if (v == null || v.trim().isEmpty) return 'Please enter branch name';
                                    //     if (v.trim().length < 2) return 'Branch name must be at least 2 characters';
                                    //     return null;
                                    //   },
                                    // ),
                                    AppSpacing.mVertical,
                                    CustomDropDown<String>(
                                      labelText: 'Account Type',
                                      value: accountType.value,
                                      items: stringToDropdownItems(['Savings', 'Current']),
                                      onChanged: (v) => accountType.value = v!,
                                    ),
                                  ],
                                ),
                              ),
                              AppSpacing.xlVertical,
                            ],
                            if (currentStep.value == 5) ...[
                              _SectionHeader(title: 'Required Documents', icon: Icons.badge_outlined, index: 6),
                              AppSpacing.mVertical,
                              Container(
                                padding: AppPadding.l,
                                decoration: BoxDecoration(
                                  color: kWhiteColor,
                                  borderRadius: AppRadius.l,
                                  border: Border.all(color: kBorderColor),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CustomTextField(
                                      controller: aadharNoController,
                                      labelText: 'Aadhaar Number',
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      keyboardType: TextInputType.number,
                                      isRequired: true,
                                      isNumeric: true,
                                      maxLength: 12,
                                      validator: Validators.validateAadhaar,
                                    ),
                                    AppSpacing.mVertical,
                                    _AadhaarVerificationSection(
                                      method: aadhaarMethod.value,
                                      pdfPath: aadharFilePath.value,
                                      frontPath: aadhaarFrontPath.value,
                                      backPath: aadhaarBackPath.value,
                                      isGenerating: isGeneratingAadhaar.value,
                                      onSelectMethod: selectAadhaarMethod,
                                      onShowInstructions: showAadhaarInstructions,
                                      onPickPdf: pickAadhaarPdf,
                                      onPickFront: () => pickAadhaarImage(isFront: true),
                                      onPickBack: () => pickAadhaarImage(isFront: false),
                                      onPreview: previewAadhaar,
                                      onDelete: deleteAadhaar,
                                    ),
                                    AppSpacing.lVertical,
                                    Divider(color: kBorderColor, height: 1),
                                    AppSpacing.lVertical,
                                    CustomTextField(
                                      controller: panNoController,
                                      labelText: 'PAN Number',
                                      isRequired: true,
                                      maxLength: 10,
                                      validator: Validators.validatePAN,
                                      capitalizeAll: true,
                                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]'))],
                                    ),
                                    AppSpacing.mVertical,
                                    _DocumentUploadTile(
                                      label: 'PAN Card',
                                      isRequired: true,
                                      filePath: panFilePath.value,
                                      onPick: () async {
                                        final path = await _pickFile(
                                          showFiles: true,
                                          showCamera: true,
                                          showGallery: true,
                                        );
                                        if (path != null) panFilePath.value = path;
                                      },
                                      onRemove: () => panFilePath.value = null,
                                    ),
                                  ],
                                ),
                              ),
                              AppSpacing.xlVertical,
                              _SectionHeader(
                                title: 'Professional Documents',
                                icon: Icons.folder_outlined,
                                index: 7,
                              ),
                              AppSpacing.mVertical,
                              ...professionalDocs.value.asMap().entries.map((entry) {
                                final i = entry.key;
                                final doc = entry.value;
                                final typeConfig = dynamicDocumentTypes.value.firstWhere(
                                  (element) => element.key == doc.documentType,
                                  orElse: () => DynamicDocumentType(
                                    id: 0,
                                    key: doc.documentType ?? '',
                                    name: documentTypes.value[doc.documentType] ?? 'Professional Document',
                                    isRequired: false,
                                    isActive: true,
                                  ),
                                );
                                return _ProfessionalDocumentCard(
                                  index: i,
                                  doc: doc,
                                  canRemove: false,
                                  typeConfig: typeConfig,
                                  onChanged: (updated) {
                                    final list = List<ProfessionalDocument>.from(professionalDocs.value);
                                    list[i] = updated;
                                    professionalDocs.value = list;
                                  },
                                  onRemove: () {},
                                );
                              }),
                              AppSpacing.xlVertical,
                              _DeclarationCheckbox(isDeclared: isDeclared),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Note banner over bottom bar for Address step
                      if (currentStep.value == 1 &&
                          hasAttemptedAddressNext.value &&
                          (pinCodeController.text.length != 6 || cityAdminId.value == null))
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 20.w),
                          decoration: BoxDecoration(
                            color: kAccentColor.withValues(alpha: 0.08),
                            border: Border(top: BorderSide(color: kAccentColor.withValues(alpha: 0.15))),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 18.sp, color: kAccentColor),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  pinCodeController.text.length != 6
                                      ? 'Please pick local home location from the map.'
                                      : 'Service is currently unavailable in this area.',
                                  style: kTextMedium(color: kAccentColor).copyWith(fontSize: 12.sp),
                                ),
                              ),
                            ],
                          ),
                        ),
                      _BottomActionButtons(
                        currentStep: currentStep.value,
                        onBack: goBackStep,
                        onNext: () => proceedToNextStep(context),
                        isNextEnabled:
                            currentStep.value != 1 ||
                            !hasAttemptedAddressNext.value ||
                            (pinCodeController.text.length == 6 && cityAdminId.value != null),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _autofillAddress(
    BuildContext? context,
    ValueNotifier<String> lat,
    ValueNotifier<String> long,
    TextEditingController address,
    TextEditingController area,
    TextEditingController city,
    TextEditingController state,
    TextEditingController pin,
  ) async {
    try {
      final pos = await LocationService().getLocationPosition();
      if (pos != null) {
        lat.value = pos.latitude.toString();
        long.value = pos.longitude.toString();
        try {
          final result = await LocationService().getAddressFromCoordinates(
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
          if (result.isSuccess && result.placemark != null) {
            Placemark place = result.placemark!;
            address.text = result.formattedAddress ?? '';
            area.text = place.subLocality ?? '';
            city.text = place.locality ?? '';
            state.text = place.administrativeArea ?? '';
            pin.text = place.postalCode ?? '';
          }
        } catch (e) {
          kPrintError('Reverse geocoding error: $e');
        }
      } else if (context != null && context.mounted) {
        final permStatus = await LocationService().getPermissionStatus();
        if (permStatus == LocationPermission.denied || permStatus == LocationPermission.deniedForever) {
          if (!context.mounted) return;
          LocationPermissionDialog.show(
            context,
            isPermanentlyDenied:
                permStatus == LocationPermission.denied || permStatus == LocationPermission.deniedForever,
          );
        }
      }
    } catch (e) {
      kPrintError('Autofill location error: $e');
    }
  }

  Future<String?> _pickFile({bool showFiles = false, bool showCamera = true, bool showGallery = true}) async {
    final file = await ChooseFileBottomSheet.show(
      showFiles: showFiles,
      showCamera: showCamera,
      showGallery: showGallery,
    );
    if (file != null) {
      final size = await file.length();
      if (size > AppConstants.maxFileSize) {
        MessageService.showError('File size too large. Maximum limit is ${AppConstants.maxFileSizeMB}MB.');
        return null;
      }
      return file.path;
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step Progress Indicator
// ─────────────────────────────────────────────────────────────────────────────
class _StepProgressIndicator extends StatelessWidget {
  final int currentStep;
  final Function(int) onStepTapped;

  const _StepProgressIndicator({required this.currentStep, required this.onStepTapped});

  @override
  Widget build(BuildContext context) {
    final steps = ['Personal', 'Address', 'Professional', 'Services', 'Bank Details', 'Documents'];
    return Container(
      width: double.infinity,
      color: kWhiteColor,
      padding: AppPadding.symmetric(v: 16, h: 12),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(steps.length, (index) {
              final isActive = index == currentStep;
              final isCompleted = index < currentStep;
              return Row(
                children: [
                  InkWell(
                    onTap: () => onStepTapped(index),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: AppPadding.symmetric(h: 4, v: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28.w,
                            height: 28.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive || isCompleted ? kPrimaryColor : kGreyColor3,
                              border: isActive
                                  ? Border.all(color: kPrimaryColor.withValues(alpha: 0.2), width: 4)
                                  : null,
                            ),
                            child: Center(
                              child: isCompleted
                                  ? Icon(Icons.check, size: 14.sp, color: kWhiteColor)
                                  : Text('${index + 1}', style: kTextNormal0(color: kWhiteColor)),
                            ),
                          ),
                          AppSpacing.xsVertical,
                          Text(
                            steps[index],
                            style: kTextNormal0(
                              color: isActive ? kPrimaryColor : kGreyColor6,
                            ).copyWith(fontWeight: isActive ? FontWeight.bold : FontWeight.normal),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (index < steps.length - 1)
                    Container(
                      width: 40.w,
                      height: 2,
                      margin: EdgeInsets.only(bottom: 20.h, left: 4, right: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            isCompleted ? kPrimaryColor : kGreyColor3,
                            (index + 1) <= currentStep ? kPrimaryColor : kGreyColor3,
                          ],
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fixed Bottom Buttons
// ─────────────────────────────────────────────────────────────────────────────
class _BottomActionButtons extends StatelessWidget {
  final int currentStep;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final bool isNextEnabled;

  const _BottomActionButtons({
    required this.currentStep,
    required this.onBack,
    required this.onNext,
    this.isNextEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppPadding.all(16),
      decoration: BoxDecoration(
        color: kWhiteColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (currentStep > 0)
              Expanded(
                child: CustomButton(
                  onPressed: onBack,
                  borderSide: BorderSide(color: kPrimaryColor, width: 1),
                  backgroundColor: kWhiteColor,
                  title: Text('Back', style: kTextMedium(color: kPrimaryColor)),
                ),
              ),
            if (currentStep > 0) AppSpacing.mHorizontal,
            Expanded(
              child: CustomButton(
                title: currentStep == 5 ? 'Submit' : 'Next',
                onPressed: isNextEnabled ? onNext : null,
                isEnable: isNextEnabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header Widget
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final int index;

  const _SectionHeader({required this.title, required this.icon, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32.w,
          height: 32.w,
          decoration: BoxDecoration(color: kPrimaryColor, borderRadius: AppRadius.s),
          child: Center(
            child: Icon(icon, color: kWhiteColor, size: 18.sp),
          ),
        ),
        AppSpacing.mHorizontal,
        Flexible(
          child: Text(title, style: kTextSemiBold2(), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Use My Location Button
// ─────────────────────────────────────────────────────────────────────────────
class _UseMyLocationButton extends StatelessWidget {
  final bool isLocating;
  final VoidCallback onTap;

  const _UseMyLocationButton({required this.isLocating, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppPadding.only(bottom: 8),
      child: OutlinedButton.icon(
        onPressed: isLocating ? null : onTap,
        icon: isLocating
            ? SizedBox(
                width: 14.w,
                height: 14.w,
                child: const CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor),
              )
            : Icon(Icons.my_location_rounded, size: 16.sp, color: kPrimaryColor),
        label: Text(isLocating ? 'Locating…' : 'Use My Location', style: kTextMedium(color: kPrimaryColor)),
        style: OutlinedButton.styleFrom(
          foregroundColor: kPrimaryColor,
          side: const BorderSide(color: kPrimaryColor),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.s),
          padding: AppPadding.symmetric(h: 12, v: 8),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Document Upload Tile  (Aadhaar / PAN)
// ─────────────────────────────────────────────────────────────────────────────
class _DocumentUploadTile extends StatelessWidget {
  final String label;
  final bool isRequired;
  final String? filePath;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _DocumentUploadTile({
    required this.label,
    required this.onPick,
    required this.onRemove,
    this.filePath,
    this.isRequired = false,
  });

  String get _fileName => filePath?.split('/').last ?? '';

  @override
  Widget build(BuildContext context) {
    final hasFile = filePath != null && filePath!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: kTextMedium1()),
            if (isRequired) Text(' *', style: kTextMedium(color: kErrorColor)),
          ],
        ),
        AppSpacing.xsVertical,
        GestureDetector(
          onTap: hasFile ? null : onPick,
          child: Container(
            width: double.infinity,
            padding: AppPadding.m,
            decoration: BoxDecoration(
              color: hasFile ? kSuccessColor.withValues(alpha: 0.06) : kScaffoldColor,
              borderRadius: AppRadius.s,
              border: Border.all(
                color: hasFile ? kSuccessColor.withValues(alpha: 0.4) : kBorderColor,
                style: hasFile ? BorderStyle.solid : BorderStyle.solid,
              ),
            ),
            child: hasFile
                ? Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: kSuccessColor, size: 16.sp),
                      AppSpacing.sHorizontal,
                      Expanded(
                        child: Text(
                          _fileName,
                          style: kTextNormal0(color: kSuccessColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: onRemove,
                        child: Icon(Icons.close_rounded, size: 16.sp, color: kTextSecondaryColor),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_file_rounded, color: kTextSecondaryColor, size: 16.sp),
                      AppSpacing.sHorizontal,
                      Text('Upload $label', style: kTextMedium(color: kTextSecondaryColor)),
                    ],
                  ),
          ),
        ),
        AppSpacing.xsVertical,
        Text('PDF, JPG, PNG (Max ${AppConstants.maxFileSizeMB}MB)', style: kTextNormal0(color: kTextHintColor)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Aadhaar Instructions Bottom Sheet  (method-aware)
// ─────────────────────────────────────────────────────────────────────────────
class _AadhaarInstructionsSheet extends StatelessWidget {
  final String method; // 'photo' | 'pdf'

  const _AadhaarInstructionsSheet({required this.method});

  @override
  Widget build(BuildContext context) {
    final isPdf = method == 'pdf';
    final title = isPdf ? 'Aadhaar PDF Instructions' : 'Aadhaar Photo Instructions';
    final bullets = isPdf
        ? const [
            'Upload Aadhaar PDF downloaded from the UIDAI portal',
            'PDF should not be password protected',
            'Ensure the document is readable',
            'Maximum size: 10 MB',
          ]
        : const [
            'Upload clear photos of both front and back sides',
            'Ensure all four corners are visible',
            'Aadhaar number should be readable',
            'QR code should be clearly visible',
            'JPG and PNG supported',
            'Maximum size: 10 MB per image',
          ];

    return SafeArea(
      child: Padding(
        padding: AppPadding.l,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(4.r)),
              ),
            ),
            AppSpacing.mVertical,
            Row(
              children: [
                Icon(
                  isPdf ? Icons.picture_as_pdf_rounded : Icons.photo_library_outlined,
                  color: kPrimaryColor,
                  size: 20.sp,
                ),
                AppSpacing.sHorizontal,
                Expanded(
                  child: Text(title, style: kTextSemiBold1(color: kPrimaryColor)),
                ),
              ],
            ),
            AppSpacing.mVertical,
            ...bullets.map(
              (t) => Padding(
                padding: AppPadding.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 6.h, right: 8.w),
                      child: Container(
                        width: 5.w,
                        height: 5.w,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: kTextSecondaryColor),
                      ),
                    ),
                    Expanded(
                      child: Text(t, style: kTextNormal0(color: kTextSecondaryColor).copyWith(height: 1.4)),
                    ),
                  ],
                ),
              ),
            ),
            AppSpacing.sVertical,
            SizedBox(
              width: double.infinity,
              child: CustomButton(title: 'Got it', onPressed: () => Navigator.pop(context)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Aadhaar Verification Section  (compact toggle: Photo | PDF → single PDF)
// ─────────────────────────────────────────────────────────────────────────────
class _AadhaarVerificationSection extends StatelessWidget {
  final String method; // 'photo' | 'pdf'
  final String? pdfPath; // final PDF to submit (uploaded or generated)
  final String? frontPath;
  final String? backPath;
  final bool isGenerating;
  final ValueChanged<String> onSelectMethod;
  final VoidCallback onShowInstructions;
  final VoidCallback onPickPdf;
  final VoidCallback onPickFront;
  final VoidCallback onPickBack;
  final VoidCallback onPreview;
  final VoidCallback onDelete;

  const _AadhaarVerificationSection({
    required this.method,
    required this.pdfPath,
    required this.frontPath,
    required this.backPath,
    required this.isGenerating,
    required this.onSelectMethod,
    required this.onShowInstructions,
    required this.onPickPdf,
    required this.onPickFront,
    required this.onPickBack,
    required this.onPreview,
    required this.onDelete,
  });

  bool get _imageMode => frontPath != null || backPath != null;

  bool get _pdfDirect => pdfPath != null && !_imageMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title + ⓘ
        Row(
          children: [
            Text('Upload Aadhaar Card', style: kTextMedium1()),
            Text(' *', style: kTextSemiBold1(color: kErrorColor)),
            const Spacer(),
            GestureDetector(
              onTap: onShowInstructions,
              child: Padding(
                padding: AppPadding.all(4),
                child: Icon(Icons.info_outline_rounded, size: 18.sp, color: kPrimaryColor),
              ),
            ),
          ],
        ),
        AppSpacing.mVertical,
        if (_pdfDirect)
          _buildPdfUploadedCard()
        else ...[
          _segmentToggle(),
          AppSpacing.mVertical,
          method == 'pdf' ? _buildPdfPicker() : _buildPhotoPicker(),
        ],
      ],
    );
  }

  // ── Segmented toggle: Photo | PDF ──
  Widget _segmentToggle() {
    Widget seg(String label, IconData icon, String value) {
      final selected = method == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onSelectMethod(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: AppPadding.symmetric(v: 10),
            decoration: BoxDecoration(
              color: selected ? kPrimaryColor : Colors.transparent,
              borderRadius: AppRadius.s,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16.sp, color: selected ? kWhiteColor : kTextSecondaryColor),
                AppSpacing.sHorizontal,
                Text(label, style: kTextMedium(color: selected ? kWhiteColor : kTextSecondaryColor)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: AppPadding.all(4),
      decoration: BoxDecoration(
        color: kScaffoldColor,
        borderRadius: AppRadius.s,
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        children: [
          seg('Photo', Icons.photo_library_outlined, 'photo'),
          seg('PDF', Icons.picture_as_pdf_rounded, 'pdf'),
        ],
      ),
    );
  }

  // ── PDF picker (empty) ──
  Widget _buildPdfPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose PDF', style: kTextMedium()),
        AppSpacing.xsVertical,
        Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 13.sp, color: kPrimaryColor),
            AppSpacing.xsHorizontal,
            Expanded(
              child: Text(
                'Upload the Aadhaar PDF downloaded from the UIDAI portal.',
                style: kTextNormal0(color: kTextSecondaryColor).copyWith(height: 1.3),
              ),
            ),
          ],
        ),
        AppSpacing.sVertical,
        GestureDetector(
          onTap: onPickPdf,
          child: Container(
            width: double.infinity,
            padding: AppPadding.m,
            decoration: BoxDecoration(
              color: kScaffoldColor,
              borderRadius: AppRadius.s,
              border: Border.all(color: kBorderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_file_rounded, color: kTextSecondaryColor, size: 18.sp),
                AppSpacing.sHorizontal,
                Text('Upload Aadhaar PDF', style: kTextMedium(color: kTextSecondaryColor)),
              ],
            ),
          ),
        ),
        AppSpacing.xsVertical,
        Text('PDF (Max ${AppConstants.maxFileSizeMB} MB)', style: kTextNormal0(color: kTextHintColor)),
      ],
    );
  }

  // ── Photo picker (empty / front-only / generating) ──
  Widget _buildPhotoPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _squareImageTile(label: 'Front Side', path: frontPath, onTap: onPickFront),
            AppSpacing.mHorizontal,
            _squareImageTile(label: 'Back Side', isMandatory: false, path: backPath, onTap: onPickBack),
          ],
        ),
        AppSpacing.sVertical,
        Text(
          'JPG, PNG (Max ${AppConstants.maxFileSizeMB} MB each) · Back side optional',
          style: kTextNormal0(color: kTextHintColor),
        ),
      ],
    );
  }

  // ── PDF uploaded card ──
  Widget _buildPdfUploadedCard() {
    return Container(
      width: double.infinity,
      padding: AppPadding.l,
      decoration: BoxDecoration(
        color: kSuccessColor.withValues(alpha: 0.05),
        borderRadius: AppRadius.l,
        border: Border.all(color: kSuccessColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.picture_as_pdf_rounded, color: kSuccessColor, size: 20.sp),
              AppSpacing.sHorizontal,
              Expanded(child: _successRow('Aadhaar PDF Uploaded', bold: true)),
            ],
          ),
          AppSpacing.xsVertical,
          Text(
            pdfPath!.split('/').last,
            style: kTextNormal0(color: kTextSecondaryColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          AppSpacing.mVertical,
          _actionsRow(preview: true, replaceLabel: 'Replace', isReplacePdf: true),
        ],
      ),
    );
  }

  // ── Shared sub-widgets ──
  // Square upload tile (Front/Back side-by-side).
  Widget _squareImageTile({
    required String label,
    required String? path,
    required VoidCallback onTap,
    bool isMandatory = true,
  }) {
    final hasFile = path != null;
    final accent = hasFile ? kSuccessColor : kTextSecondaryColor;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  style: kTextNormal0(color: kGreyColor7),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isMandatory) Text(' *', style: kTextNormal0(color: kErrorColor)),
            ],
          ),
          AppSpacing.xsVertical,
          GestureDetector(
            onTap: onTap,
            child: AspectRatio(
              aspectRatio: 1.4,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: hasFile ? null : kScaffoldColor,
                  borderRadius: AppRadius.s,
                  border: Border.all(color: hasFile ? kSuccessColor.withValues(alpha: 0.5) : kBorderColor),
                ),
                child: hasFile
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(File(path), fit: BoxFit.cover),
                          Positioned(
                            top: 4.h,
                            right: 4.w,
                            child: Container(
                              decoration: const BoxDecoration(color: kWhiteColor, shape: BoxShape.circle),
                              child: Icon(Icons.check_circle, color: kSuccessColor, size: 18.sp),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.4),
                              padding: EdgeInsets.symmetric(vertical: 4.h),
                              child: Text(
                                'Tap to change',
                                textAlign: TextAlign.center,
                                style: kTextNormal0(color: kWhiteColor).copyWith(fontSize: 10.sp),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, color: accent, size: 28.sp),
                          AppSpacing.sVertical,
                          Text(
                            'Upload',
                            style: kTextMedium(color: accent).copyWith(fontSize: 12.sp),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _successRow(String text, {bool bold = false}) {
    return Row(
      children: [
        Icon(Icons.check_circle_rounded, color: kSuccessColor, size: 16.sp),
        AppSpacing.sHorizontal,
        Flexible(
          child: Text(
            text,
            style: bold ? kTextSemiBold(color: kSuccessColor) : kTextMedium(color: kSuccessColor),
          ),
        ),
      ],
    );
  }

  Widget _actionsRow({required bool preview, required String replaceLabel, bool isReplacePdf = false}) {
    Widget action(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: AppPadding.symmetric(v: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: AppRadius.s,
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15.sp, color: color),
              AppSpacing.xsHorizontal,
              Flexible(
                child: Text(
                  label,
                  style: kTextMedium(color: color).copyWith(fontSize: 12.sp),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Row(
      children: [
        if (preview) ...[
          action(Icons.visibility_outlined, 'Preview', kPrimaryColor, onPreview),
          AppSpacing.sHorizontal,
        ],
        // Replace = reset selection; for PDF, immediately re-pick.
        action(Icons.swap_horiz_rounded, replaceLabel, kSecondaryColor, () {
          onDelete();
          if (isReplacePdf) onPickPdf();
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Professional Document Card (Registration Certificate etc.)
// ─────────────────────────────────────────────────────────────────────────────
class _ProfessionalDocumentCard extends StatefulWidget {
  final int index;
  final ProfessionalDocument doc;
  final bool canRemove;
  final ValueChanged<ProfessionalDocument> onChanged;
  final VoidCallback onRemove;
  final DynamicDocumentType typeConfig;

  const _ProfessionalDocumentCard({
    required this.index,
    required this.doc,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
    required this.typeConfig,
  });

  @override
  State<_ProfessionalDocumentCard> createState() => _ProfessionalDocumentCardState();
}

class _ProfessionalDocumentCardState extends State<_ProfessionalDocumentCard> {
  late TextEditingController _nameCtrl;
  late TextEditingController _numberCtrl;
  late TextEditingController _issueDateCtrl;
  late TextEditingController _expiryDateCtrl;
  DateTime? _issueDate;
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.doc.documentName ?? '');
    _numberCtrl = TextEditingController(text: widget.doc.documentNumber ?? '');
    _issueDateCtrl = TextEditingController(text: widget.doc.issueDate ?? '');
    _expiryDateCtrl = TextEditingController(text: widget.doc.expiryDate ?? '');

    _nameCtrl.addListener(_onCtrlChanged);
    _numberCtrl.addListener(_onCtrlChanged);
    _issueDateCtrl.addListener(_onCtrlChanged);
    _expiryDateCtrl.addListener(_onCtrlChanged);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onCtrlChanged);
    _numberCtrl.removeListener(_onCtrlChanged);
    _issueDateCtrl.removeListener(_onCtrlChanged);
    _expiryDateCtrl.removeListener(_onCtrlChanged);
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _issueDateCtrl.dispose();
    _expiryDateCtrl.dispose();
    super.dispose();
  }

  void _onCtrlChanged() {
    setState(() {});
  }

  bool get _isDocCardFilledAny {
    return _nameCtrl.text.trim().isNotEmpty ||
        _numberCtrl.text.trim().isNotEmpty ||
        _issueDateCtrl.text.trim().isNotEmpty ||
        _expiryDateCtrl.text.trim().isNotEmpty ||
        (widget.doc.filePath ?? '').isNotEmpty;
  }

  void _notify({String? filePath, String? documentType}) {
    widget.onChanged(
      widget.doc.copyWith(
        documentType: documentType ?? widget.doc.documentType,
        documentName: _nameCtrl.text,
        documentNumber: _numberCtrl.text,
        // Display shows friendly 'dd MMM yyyy'; API stores ISO 'yyyy-MM-dd'.
        issueDate: _issueDate != null ? _formatDate(_issueDate!) : (widget.doc.issueDate ?? ''),
        expiryDate: _expiryDate != null ? _formatDate(_expiryDate!) : (widget.doc.expiryDate ?? ''),
        filePath: filePath ?? widget.doc.filePath,
      ),
    );
  }

  Future<void> _pickFile() async {
    final file = await ChooseFileBottomSheet.show(showFiles: true);
    if (file != null) {
      final size = await file.length();
      if (size > AppConstants.maxFileSize) {
        MessageService.showError('File size too large. Maximum limit is ${AppConstants.maxFileSizeMB}MB.');
        return;
      }
      _notify(filePath: file.path);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: AppPadding.only(bottom: 16),
      padding: AppPadding.symmetric(h: 12, v: 16),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: AppRadius.l,
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Row(
            children: [
              Expanded(
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    text: widget.typeConfig.name,
                    style: kTextSemiBold(color: kPrimaryColor),
                    children: [
                      if (_isDocCardFilledAny)
                        TextSpan(
                          text: ' *',
                          style: kTextSemiBold(color: kErrorColor),
                        ),
                    ],
                  ),
                ),
              ),
              AppSpacing.sHorizontal,
              if (widget.canRemove)
                GestureDetector(
                  onTap: widget.onRemove,
                  child: Icon(Icons.delete_outline_rounded, color: kErrorColor, size: 20.sp),
                ),
            ],
          ),
          AppSpacing.mVertical,
          CustomTextField(
            controller: _nameCtrl,
            labelText: 'Document Name',
            isRequired: _isDocCardFilledAny,
            hintText: 'e.g. Degree Certificate',
            onChanged: (_) => _notify(),
          ),
          CustomTextField(
            controller: _numberCtrl,
            labelText: 'Document Number',
            isRequired: _isDocCardFilledAny,
            hintText: 'e.g. ID or Reg no.',
            onChanged: (_) => _notify(),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DatePickerTextField(
                  controller: _issueDateCtrl,
                  labelText: 'Issue Date',
                  isRequired: false,
                  initialDate: _issueDate ?? DateTime.now(),
                  lastDate: DateTime.now(),
                  onDateSelected: (d) {
                    _issueDate = d;
                    _notify();
                  },
                ),
              ),
              AppSpacing.sHorizontal,
              Expanded(
                child: DatePickerTextField(
                  controller: _expiryDateCtrl,
                  labelText: 'Expiry Date',
                  isRequired: false,
                  initialDate: _expiryDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2050),
                  onDateSelected: (d) {
                    _expiryDate = d;
                    _notify();
                  },
                ),
              ),
            ],
          ),

          // File upload
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: CustomLabelForTextField(title: 'Upload Document', isRequired: _isDocCardFilledAny),
              ),
              if (widget.typeConfig.sampleFileUrl != null && widget.typeConfig.sampleFileUrl!.isNotEmpty) ...[
                SizedBox(width: 8.w),
                GestureDetector(
                  onTap: () async {
                    final docUrl = widget.typeConfig.sampleFileUrl!;
                    await file_download.FileDownloadService().downloadAndViewFile(url: docUrl);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_rounded, size: 14.sp, color: kSecondaryColor),
                      AppSpacing.xsHorizontal,
                      Flexible(
                        child: Text(
                          'Download Sample',
                          style: kTextMedium(
                            color: kSecondaryColor,
                          ).copyWith(decoration: TextDecoration.underline),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          AppSpacing.xsVertical,
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: double.infinity,
              padding: AppPadding.m,
              decoration: BoxDecoration(
                color: widget.doc.filePath != null && widget.doc.filePath!.isNotEmpty
                    ? kSuccessColor.withValues(alpha: 0.06)
                    : kScaffoldColor,
                borderRadius: AppRadius.s,
                border: Border.all(
                  color: widget.doc.filePath != null && widget.doc.filePath!.isNotEmpty
                      ? kSuccessColor.withValues(alpha: 0.4)
                      : kBorderColor,
                ),
              ),
              child: widget.doc.filePath != null && widget.doc.filePath!.isNotEmpty
                  ? Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: kSuccessColor, size: 16.sp),
                        AppSpacing.sHorizontal,
                        Expanded(
                          child: Text(
                            widget.doc.filePath!.split('/').last,
                            style: kTextNormal0(color: kSuccessColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _notify(filePath: ''),
                          child: Icon(Icons.close_rounded, size: 16.sp, color: kTextSecondaryColor),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file_rounded, color: kTextSecondaryColor, size: 18.sp),
                        AppSpacing.sHorizontal,
                        Text('Choose File', style: kTextMedium(color: kTextSecondaryColor)),
                      ],
                    ),
            ),
          ),
          AppSpacing.xsVertical,
          Text('PDF, JPG, PNG (Max ${AppConstants.maxFileSizeMB}MB)', style: kTextNormal0(color: kTextHintColor)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Declaration Checkbox
// ─────────────────────────────────────────────────────────────────────────────
class _DeclarationCheckbox extends StatelessWidget {
  final ValueNotifier<bool> isDeclared;

  const _DeclarationCheckbox({required this.isDeclared});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: isDeclared.value,
            activeColor: kPrimaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (val) {
              if (val == true) {
                ConsentHelper.show(
                  context: context,
                  consentType: 'provider_registration',
                  onAgree: () => isDeclared.value = true,
                  silentFailure: true,
                );
              } else {
                isDeclared.value = false;
              }
            },
          ),
        ),
        AppSpacing.mHorizontal,
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (!isDeclared.value) {
                ConsentHelper.show(
                  context: context,
                  consentType: 'provider_registration',
                  onAgree: () => isDeclared.value = true,
                  silentFailure: true,
                );
              } else {
                isDeclared.value = false;
              }
            },
            child: RichText(
              text: TextSpan(
                style: kTextNormal(color: kTextSecondaryColor),
                children: [
                  const TextSpan(
                    text:
                        'I hereby confirm that all information and documents provided by me are true, accurate, and complete. I have read, understood, and agree to abide by the Home Health Care rules, professional code of ethics, the ',
                  ),
                  TextSpan(
                    text: 'Terms & Conditions',
                    style: TextStyle(color: kPrimaryColor, decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => LaunchUrlService.launchInAppWebUrl(RedirectionUrl.partnerTermsConditions),
                  ),
                  const TextSpan(text: ', and the '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(color: kPrimaryColor, decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => LaunchUrlService.launchInAppWebUrl(RedirectionUrl.privacyPolicy),
                  ),
                  const TextSpan(
                    text:
                        ' of Adhisaat Health Care. I authorize Adhisaat to verify the information and documents submitted by me and understand that any false information or violation of these terms may result in suspension or termination of my registration/account.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AadhaarFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // If user is deleting (backspace), allow it
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    String text = newValue.text.replaceAll(' ', '');
    if (text.length > 12) text = text.substring(0, 12);

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && (i + 1) != 12) {
        buffer.write(' ');
      }
    }

    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
