import 'dart:io';

import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/core/utils/message_service.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/data/models/provider_models/provider_profile_payload_model.dart';
import 'package:adhisaat_health_care/data/shared_blocs/dropdown/dropdown_bloc.dart';
import 'package:adhisaat_health_care/data/shared_blocs/dropdown/dropdown_state.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_profile/blocs/profile_bloc/provider_profile_bloc.dart';
import 'package:adhisaat_health_care/shared/widgets/buttons/custom_button.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:adhisaat_health_care/shared/widgets/dialogs/custom_bottom_sheets.dart';
import 'package:adhisaat_health_care/shared/widgets/inputs/custom_drop_down.dart';
import 'package:adhisaat_health_care/shared/widgets/inputs/custom_text_field.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProviderProfileEditPage extends HookWidget {
  final bool autoScrollToBottom;

  const ProviderProfileEditPage({super.key, this.autoScrollToBottom = false});

  @override
  Widget build(BuildContext context) {
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final bottomAnchorKey = useMemoized(() => GlobalKey());
    final blocState = context.watch<ProviderProfileBloc>().state;
    final dropdownState = context.watch<DropdownBloc>().state;
    final dropdownData = dropdownState is DropdownLoaded ? dropdownState.data : null;

    final nameController = useTextEditingController();
    final mobileController = useTextEditingController();
    final whatsappController = useTextEditingController();
    final emailController = useTextEditingController();
    final dobController = useTextEditingController();
    final eighteenYearsAgo = useMemoized(() {
      final now = DateTime.now();
      return DateTime(now.year - 18, now.month, now.day);
    }, []);
    final selectedDob = useState<DateTime>(eighteenYearsAgo);
    final selectedGender = useState<String?>(null);
    final selectedBloodGroup = useState<String?>(null);
    final qualificationController = useTextEditingController();
    final registrationController = useTextEditingController();
    final councilController = useTextEditingController();
    final selectedExperience = useState<String?>(null);
    final workplaceController = useTextEditingController();
    final areaController = useTextEditingController();
    final aboutController = useTextEditingController();
    final aadharController = useTextEditingController();
    final panController = useTextEditingController();

    final profileImage = useState<File?>(null);
    final profileImageUrl = useState<String?>(null);
    final aadharFile = useState<File?>(null);
    final aadharUrl = useState<String?>(null);
    final panFile = useState<File?>(null);
    final panUrl = useState<String?>(null);

    final selectedDutyTypes = useState<List<String>>([]);
    final selectedSkills = useState<List<String>>([]);
    final isInitialized = useState(false);
    final isAadharVerified = useState(false);
    final isPanVerified = useState(false);
    final isEmailEnable = useState(false);
    final aadharStatus = useState<String?>(null);
    final panStatus = useState<String?>(null);

    // Optimized Scroll tracking using ValueNotifier to prevent full-page rebuilds
    final scrollController = useScrollController();
    final isScrolledNotifier = useValueNotifier(false);
    final hasAutoScrolledToBottom = useState(false);
    final scrollAfterProfileLoad = useState(false);

    useEffect(() {
      void listener() {
        if (scrollController.hasClients) {
          final shouldBeScrolled = scrollController.offset > 40;
          if (isScrolledNotifier.value != shouldBeScrolled) {
            isScrolledNotifier.value = shouldBeScrolled;
          }
        }
      }

      scrollController.addListener(listener);
      return () => scrollController.removeListener(listener);
    }, [scrollController]);

    useEffect(() {
      if (!autoScrollToBottom || !scrollAfterProfileLoad.value || hasAutoScrolledToBottom.value) {
        return null;
      }

      Future<void> scrollToBottom() async {
        // Wait for the first frame to be laid out.
        await Future.delayed(const Duration(milliseconds: 300));

        double lastMaxExtent = -1;
        int stableCount = 0;

        // Keep scrolling until maxScrollExtent stops growing (content fully rendered)
        // and we are confirmed at the bottom.
        for (int i = 0; i < 25; i++) {
          if (!scrollController.hasClients) {
            await Future.delayed(const Duration(milliseconds: 150));
            continue;
          }

          final currentMaxExtent = scrollController.position.maxScrollExtent;

          if (currentMaxExtent == lastMaxExtent) {
            stableCount++;
          } else {
            // Page is still growing – reset stability counter and keep chasing bottom.
            stableCount = 0;
            lastMaxExtent = currentMaxExtent;
          }

          if (currentMaxExtent > 0) {
            try {
              await scrollController.animateTo(
                currentMaxExtent,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
              );
            } catch (_) {
              // Controller detached during transition – stop gracefully.
              break;
            }
          }

          // Only declare success once extent has been stable for 2 consecutive checks
          // AND we are actually at the bottom.
          if (stableCount >= 2 && scrollController.hasClients) {
            final atBottom = (scrollController.position.maxScrollExtent - scrollController.offset).abs() <= 4;
            if (atBottom) {
              hasAutoScrolledToBottom.value = true;
              scrollAfterProfileLoad.value = false;
              return;
            }
          }

          await Future.delayed(const Duration(milliseconds: 180));
        }

        hasAutoScrolledToBottom.value = true;
        scrollAfterProfileLoad.value = false;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToBottom();
      });

      return null;
    }, [autoScrollToBottom, scrollAfterProfileLoad.value, scrollController, hasAutoScrolledToBottom.value]);

    useEffect(() {
      if (blocState is ProviderProfileLoaded && !isInitialized.value) {
        final profile = blocState.userProfileModel;
        final sp = profile.serviceProviderProfile;

        nameController.text = profile.name;
        mobileController.text = profile.mobileNumber;
        whatsappController.text = profile.whatsappNumber ?? '';
        emailController.text = profile.email;
        if (!isNotNull(profile.email)) {
          isEmailEnable.value = true;
        }
        selectedDob.value = AppDateFormatter.dateFromString(profile.dateOfBirth ?? '');
        dobController.text = AppDateFormatter.dateFromApi(profile.dateOfBirth ?? '');
        selectedGender.value = profile.gender;
        selectedBloodGroup.value = profile.bloodGroup;
        qualificationController.text = sp?.highestQualification ?? '';
        registrationController.text = sp?.professionalRegistrationNumber ?? '';
        councilController.text = sp?.councilBoardName ?? '';
        workplaceController.text = sp?.previousWorkplace ?? '';
        areaController.text = sp?.preferredWorkingArea ?? '';
        aboutController.text = sp?.about ?? '';
        aadharController.text = profile.aadharNo ?? '';
        panController.text = profile.panNumber ?? '';
        selectedExperience.value = sp?.totalExperience;

        if (sp?.dutyType != null) {
          selectedDutyTypes.value = sp!.dutyType!.split(',').map((e) => e.trim()).toList();
        }

        profileImageUrl.value = profile.profileImageUrl;

        if (sp?.skills != null) {
          selectedSkills.value = sp!.skills.map((e) => e.skillName).toList();
        }

        aadharUrl.value = profile.aadharFilePathUrl;
        panUrl.value = profile.panFilePathUrl;

        isAadharVerified.value = profile.aadharVerified == 'verified';
        isPanVerified.value = profile.panVerified == 'verified';
        aadharStatus.value = profile.aadharVerified;
        panStatus.value = profile.panVerified;

        isInitialized.value = true;
        scrollAfterProfileLoad.value = autoScrollToBottom;
      }
      return null;
    }, [blocState]);

    void pickProfileImage() async {
      final file = await ChooseFileBottomSheet.show(showFiles: false);
      if (file != null) {
        final size = await file.length();
        if (size > AppConstants.maxFileSize) {
          MessageService.showError('Photo too large. Maximum limit is ${AppConstants.maxFileSizeMB}MB.');
          return;
        }
        profileImage.value = file;
      }
    }

    void pickDocument(ValueNotifier<File?> fileNotifier) async {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final size = await file.length();
        if (size > AppConstants.maxFileSize) {
          MessageService.showError('File size too large. Maximum limit is ${AppConstants.maxFileSizeMB}MB.');
          return;
        }
        fileNotifier.value = file;
      }
    }

    void handleUpdate() {
      if (formKey.currentState!.validate()) {
        final dob = AppDateFormatter.dateForApi(selectedDob.value.toString());

        final profile = ProviderProfileModel(
          name: nameController.text,
          mobileNumber: mobileController.text,
          whatsappNumber: whatsappController.text,
          email: emailController.text,
          dateOfBirth: dob,
          bloodGroup: selectedBloodGroup.value,
          highestQualification: qualificationController.text,
          professionalRegistrationNumber: registrationController.text,
          councilBoardName: councilController.text,
          totalExperience: selectedExperience.value,
          previousWorkplace: workplaceController.text,
          dutyType: selectedDutyTypes.value,
          preferredWorkingArea: areaController.text,
          gender: selectedGender.value,
          about: aboutController.text,
          aadharNo: aadharController.text,
          panNumber: panController.text,
        );

        context.read<ProviderProfileBloc>().add(
          UpdateProviderProfile(
            profile: profile,
            profileImage: profileImage.value,
            aadharFile: aadharFile.value,
            panFile: panFile.value,
            skills: selectedSkills.value,
          ),
        );
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: kScaffoldColor,
      appBar: CustomAppBar(
        title: 'Edit Profile',
        backgroundColor: kScaffoldColor,
        titleColor: kBlackColor,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: kPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: BlocListener<ProviderProfileBloc, ProviderProfileState>(
          listener: (context, state) {
            if (state is ProviderProfileUpdateSuccess) {
              // Pop after showing success, and signal to refresh on the view page
              Navigator.pop(context, true);
              MessageService.showSuccess('Profile updated successfully!');
            } else if (state is ProviderProfileError) {
              MessageService.showError(state.error);
            }
          },
          child: BlocBuilder<ProviderProfileBloc, ProviderProfileState>(
            builder: (context, state) {
              if (state is ProviderProfileLoading && !isInitialized.value) {
                return const Center(child: CircularProgressIndicator.adaptive());
              }

              return Form(
                key: formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                // Header Background with Curve
                                // ClipRRect(
                                //   borderRadius: BorderRadius.vertical(bottom: Radius.circular(36.r)),
                                //   child: Container(
                                //     height: 160.h,
                                //     width: double.infinity,
                                //     decoration: BoxDecoration(
                                //       // gradient: const LinearGradient(
                                //       //   begin: Alignment.topCenter,
                                //       //   end: Alignment.bottomCenter,
                                //       //   colors: [kPrimaryColor, Color(0xFF4277F7), Color(0xFF5B8BF5)],
                                //       // ),
                                //       color: kPrimaryColor,
                                //       boxShadow: [
                                //         BoxShadow(
                                //           color: kPrimaryColor.withValues(alpha: )(0.25),
                                //           blurRadius: 20,
                                //           offset: const Offset(0, 10),
                                //         ),
                                //       ],
                                //     ),
                                //     child: Stack(
                                //       children: [
                                //         Positioned(top: -40.r, right: -40.r, child: _buildDecorativeCircle(140.r)),
                                //         Positioned(
                                //           bottom: -20.r,
                                //           left: -30.r,
                                //           child: _buildDecorativeCircle(100.r),
                                //         ),
                                //       ],
                                //     ),
                                //   ),
                                // ),

                                // Image and Spacing
                                Column(
                                  children: [
                                    SizedBox(height: 100.h),
                                    _buildProfileImageHeader(profileImage, profileImageUrl, pickProfileImage),
                                    SizedBox(height: 16.h),
                                  ],
                                ),
                              ],
                            ),

                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8.w),
                              child: Column(
                                children: [
                                  _buildSectionCard(
                                    title: 'Personal Details',
                                    icon: Icons.person_rounded,
                                    children: [
                                      CustomTextField(
                                        controller: nameController,
                                        labelText: 'Full Name',
                                        isRequired: true,
                                        enabled: false,
                                        prefixIcon: const Icon(Icons.person_outline_rounded),
                                      ),
                                      CustomTextField(
                                        enabled: false,
                                        controller: mobileController,
                                        labelText: 'Mobile Number',
                                        prefixIcon: const Icon(Icons.phone_android_rounded),
                                      ),
                                      PhoneTextField(
                                        controller: whatsappController,
                                        labelText: 'WhatsApp',
                                        hintText: 'Enter whatsapp number',
                                      ),
                                      EmailTextField(
                                        controller: emailController,
                                        enabled: isEmailEnable.value,
                                        labelText: 'Email Address',
                                      ),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: CustomDropDown<String>(
                                              labelText: 'Blood Group',
                                              value: selectedBloodGroup.value,
                                              items: mapToDropdownItems(
                                                dropdownData?.bloodGroups ??
                                                    {
                                                      'A+': 'A+',
                                                      'A-': 'A-',
                                                      'B+': 'B+',
                                                      'B-': 'B-',
                                                      'AB+': 'AB+',
                                                      'AB-': 'AB-',
                                                      'O+': 'O+',
                                                      'O-': 'O-',
                                                    },
                                              ),
                                              onChanged: (val) => selectedBloodGroup.value = val,
                                            ),
                                          ),

                                          SizedBox(width: 12.w),
                                          Expanded(
                                            child: CustomDropDown<String>(
                                              labelText: 'Gender',
                                              isRequired: true,
                                              value: selectedGender.value,
                                              items: mapToDropdownItems(
                                                dropdownData?.genders ??
                                                    {'male': 'Male', 'female': 'Female', 'other': 'Other'},
                                              ),
                                              onChanged: (val) => selectedGender.value = val,
                                            ),
                                          ),
                                        ],
                                      ),
                                      _buildDatePicker(context, dobController, selectedDob, eighteenYearsAgo),
                                    ],
                                  ),

                                  _buildSectionCard(
                                    title: 'Bio',
                                    icon: Icons.info_outline_rounded,
                                    children: [
                                      CustomTextField(
                                        controller: aboutController,
                                        labelText: 'About You',
                                        hintText: 'Describe your expertise...',
                                        maxLines: 4,
                                        minLines: 2,
                                      ),
                                    ],
                                  ),

                                  _buildSectionCard(
                                    title: 'Professional Info',
                                    icon: Icons.work_outline_rounded,
                                    children: [
                                      CustomTextField(
                                        controller: qualificationController,
                                        labelText: 'Highest Qualification',
                                        hintText: 'M.Sc. Nursing / B.Sc. Nursing / GNM or Other',
                                        isRequired: true,
                                        prefixIcon: const Icon(Icons.school_outlined),
                                      ),
                                      CustomTextField(
                                        controller: councilController,
                                        labelText: 'Council / Board Name',
                                        hintText: 'RNC / Other',
                                        prefixIcon: const Icon(Icons.account_balance_outlined),
                                      ),
                                      CustomTextField(
                                        controller: workplaceController,
                                        labelText: 'Previous Workplace',
                                        hintText: 'Previous Hospital / Clinic / Other',
                                        prefixIcon: const Icon(Icons.local_hospital),
                                      ),
                                      CustomTextField(
                                        controller: registrationController,
                                        labelText: 'Registration Number',
                                        maxLength: 10,
                                        prefixIcon: const Icon(Icons.assignment_ind_outlined),
                                      ),

                                      CustomDropDown<String>(
                                        labelText: 'Experience',
                                        isRequired: true,
                                        value: selectedExperience.value,
                                        items: mapToDropdownItems(
                                          dropdownData?.totalExperience ??
                                              {
                                                'fresher': 'Fresher',
                                                '0-1': '0-1 Year',
                                                '1-3': '1-3 Years',
                                                '3-5': '3-5 Years',
                                                '5+': '5+ Years',
                                              },
                                        ),
                                        onChanged: (val) => selectedExperience.value = val,
                                      ),
                                    ],
                                  ),

                                  // _buildWorkPreferencesCard(
                                  //   context,
                                  //   selectedDutyTypes,
                                  //   selectedSkills,
                                  //   areaController,
                                  //   dropdownData,
                                  // ),
                                  _buildSectionCard(
                                    title: 'KYC Documents',
                                    icon: Icons.verified_user_outlined,
                                    children: [
                                      CustomTextField(
                                        enabled: !isAadharVerified.value,
                                        controller: aadharController,
                                        labelText: 'Aadhaar Number',
                                        isRequired: true,
                                        maxLength: 12,
                                        keyboardType: TextInputType.number,
                                        prefixIcon: const Icon(Icons.credit_card),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Aadhaar number is required';
                                          }
                                          if (value.length != 12) {
                                            return 'Aadhaar number must be 12 digits';
                                          }
                                          return null;
                                        },
                                      ),
                                      _buildFileUploadItem(
                                        'Aadhaar Card (Front/Back)',
                                        aadharFile,
                                        aadharUrl,
                                        isAadharVerified.value ? null : () => pickDocument(aadharFile),
                                        aadharStatus.value,
                                      ),
                                      SizedBox(height: 12.h),
                                      CustomTextField(
                                        enabled: !isPanVerified.value,
                                        controller: panController,
                                        labelText: 'PAN Number',
                                        isRequired: true,
                                        maxLength: 10,
                                        textCapitalization: TextCapitalization.characters,
                                        prefixIcon: const Icon(Icons.badge_outlined),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'PAN number is required';
                                          }
                                          final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
                                          if (!panRegex.hasMatch(value.toUpperCase())) {
                                            return 'Enter a valid PAN number';
                                          }
                                          return null;
                                        },
                                      ),
                                      _buildFileUploadItem(
                                        'PAN Card',
                                        panFile,
                                        panUrl,
                                        isPanVerified.value ? null : () => pickDocument(panFile),
                                        panStatus.value,
                                      ),
                                    ],
                                  ),
                                  SizedBox(key: bottomAnchorKey, height: 1),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Pinned Bottom Button
                    Padding(
                      padding: AppPadding.m,
                      child: CustomButton(
                        width: double.infinity,
                        title: 'Update',
                        onPressed: handleUpdate,
                        isLoading: state is ProviderProfileUpdating,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // --- Reusable UI Components ---

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(color: kPrimaryColor.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6)),
        ],
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(icon, size: 18.r, color: kPrimaryColor),
              ),
              SizedBox(width: 10.w),
              Text(title, style: kTextSemiBold2().copyWith(fontSize: 15.sp)),
            ],
          ),
          const Divider(height: 28, thickness: 0.5),
          ...children.expand((w) => [w, SizedBox(height: 12.h)]).toList()..removeLast(),
        ],
      ),
    );
  }

  Widget _buildProfileImageHeader(
    ValueNotifier<File?> localFile,
    ValueNotifier<String?> remoteUrl,
    VoidCallback onTap,
  ) {
    return Center(
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 15, offset: const Offset(0, 8)),
              ],
            ),
            child: CircleAvatar(
              radius: 56.r,
              backgroundColor: Colors.grey[100],
              backgroundImage: localFile.value != null
                  ? FileImage(localFile.value!)
                  : (remoteUrl.value != null ? NetworkImage(remoteUrl.value!) : null) as ImageProvider?,
              child: localFile.value == null && remoteUrl.value == null
                  ? Icon(Icons.person_rounded, size: 55.r, color: Colors.grey[400])
                  : null,
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: InkWell(
              onTap: onTap,
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
    );
  }

  Widget _buildDatePicker(
    BuildContext context,
    TextEditingController controller,
    ValueNotifier<DateTime?> selectedDate,
    DateTime eighteenYearsAgo,
  ) {
    DateTime initial = eighteenYearsAgo;
    try {
      if (selectedDate.value != null) {
        initial = selectedDate.value!;
      }
    } catch (_) {}
    return DatePickerTextField(
      controller: controller,
      isRequired: true,
      initialDate: initial,
      lastDate: eighteenYearsAgo,
      labelText: "Date of Birth",
      onDateSelected: (date) => selectedDate.value = date,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Date of Birth is required';
        final dob = selectedDate.value;
        if (dob == null) return 'Date of Birth is required';
        final today = DateTime.now();
        var age = today.year - dob.year;
        if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
          age--;
        }
        if (age < 18) return 'You must be at least 18 years old to register.';
        return null;
      },
    );
  }

  Widget _buildFileUploadItem(
    String title,
    ValueNotifier<File?> file,
    ValueNotifier<String?> remoteUrl,
    VoidCallback? onTap,
    String? status,
  ) {
    final hasLocalFile = file.value != null;
    final hasRemoteFile = remoteUrl.value != null;
    final hasFile = hasLocalFile || hasRemoteFile;
    final isVerified = onTap == null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: isVerified
              ? kSuccessColor.withValues(alpha: 0.05)
              : (status == 'pending'
                    ? Colors.orange.withValues(alpha: 0.05)
                    : (status == 'rejected'
                          ? Colors.red.withValues(alpha: 0.05)
                          : (hasFile ? Colors.green.withValues(alpha: 0.05) : Colors.grey[50]))),
          border: Border.all(
            color: isVerified
                ? kSuccessColor.withValues(alpha: 0.3)
                : (status == 'pending'
                      ? Colors.orange.withValues(alpha: 0.3)
                      : (status == 'rejected'
                            ? Colors.red.withValues(alpha: 0.3)
                            : (hasFile ? Colors.green.withValues(alpha: 0.3) : Colors.grey[200]!))),
          ),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            if (isVerified)
              Icon(Icons.verified, color: kSuccessColor, size: 24.sp)
            else if (status == 'pending')
              Icon(Icons.hourglass_empty, color: Colors.orange, size: 24.sp)
            else if (status == 'rejected')
              Icon(Icons.error_outline, color: Colors.red, size: 24.sp)
            else if (hasLocalFile)
              Icon(Icons.check_circle, color: Colors.green, size: 24.sp)
            else if (hasRemoteFile)
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6.r),
                  image: remoteUrl.value!.toLowerCase().endsWith('.pdf')
                      ? null
                      : DecorationImage(image: NetworkImage(remoteUrl.value!), fit: BoxFit.cover),
                  color: Colors.grey[200],
                ),
                child: remoteUrl.value!.toLowerCase().endsWith('.pdf')
                    ? Icon(Icons.picture_as_pdf, color: Colors.red, size: 20.sp)
                    : null,
              )
            else
              Icon(Icons.upload_file_rounded, color: kPrimaryColor, size: 24.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: kTextMedium().copyWith(fontSize: 13.sp)),
                  Text(
                    hasLocalFile
                        ? file.value!.path.split('/').last
                        : (isVerified
                              ? 'Verified'
                              : (status != null && status != 'verified' && status != 'not_uploaded'
                                    ? _statusLabel(status)
                                    : (hasRemoteFile ? 'Current File (Tap to change)' : 'Tap to select file'))),
                    style: kTextNormal0(
                      color: isVerified
                          ? kSuccessColor
                          : (status == 'pending'
                                ? Colors.orange
                                : (status == 'rejected'
                                      ? Colors.red
                                      : (hasLocalFile || hasRemoteFile ? kPrimaryColor : Colors.grey))),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (hasRemoteFile && !hasLocalFile && !isVerified) Icon(Icons.edit, color: kPrimaryColor, size: 18.sp),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending for Verification';
      case 'rejected':
        return 'Rejected – Re-upload required';
      case 'in_progress':
        return 'Under Review';
      case 'hold':
        return 'On Hold – Contact Support';
      default:
        return status[0].toUpperCase() + status.substring(1).toLowerCase();
    }
  }
}
