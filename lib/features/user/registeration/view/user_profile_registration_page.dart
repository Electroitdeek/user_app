import 'dart:io';

import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/services/launch_url_service.dart';
import 'package:adhisaat_health_care/core/services/location_service.dart';
import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/shared/utils/consent_helper.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:adhisaat_health_care/shared/widgets/dialogs/dialog_helpers.dart';
import 'package:adhisaat_health_care/shared/widgets/inputs/custom_drop_down.dart';
import 'package:adhisaat_health_care/shared/widgets/inputs/custom_text_field.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/redirection_url.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/screen_dimensions.dart';
import '../../../../core/utils/message_service.dart';
import '../../../../data/models/user_profile_model.dart' as data_model;
import '../../../../data/repositories/auth_repository.dart';
import '../../../../features/user/address/bloc/selected_address_provider.dart';
import '../../../../shared/widgets/buttons/custom_button.dart';
import '../../../../shared/widgets/dialogs/custom_bottom_sheets.dart';
import '../../../auth/login/bloc/auth_bloc.dart';
import '../bloc/user_profile/user_profile_registration_bloc.dart';
import '../models/user_registration_request.dart';

class UserProfileRegistrationPage extends HookWidget {
  final String mobileNumber;
  final int? userId;

  const UserProfileRegistrationPage({super.key, required this.mobileNumber, this.userId});

  @override
  Widget build(BuildContext context) {
    final genders = useState<Map<String, String>>({});
    // final bloodGroups = useState<Map<String, String>>({});

    // Controllers for text fields
    final nameController = useTextEditingController();
    final mobileController = useTextEditingController(text: mobileNumber);
    // final emailController = useTextEditingController();
    final whatsappController = useTextEditingController();
    // final eighteenYearsAgo = useMemoized(() {
    //   final now = DateTime.now();
    //   return DateTime(now.year - 18, now.month, now.day);
    // }, []);

    // final dobController = useTextEditingController(text: AppDateFormatter.dateOnly(eighteenYearsAgo));
    // final emergencyNameController = useTextEditingController();
    // final emergencyNumberController = useTextEditingController();
    // final aadharNoController = useTextEditingController();
    // final panNoController = useTextEditingController();
    final referralCodeController = useTextEditingController();
    final passwordController = useTextEditingController();
    final confirmPasswordController = useTextEditingController();
    final emailController = useTextEditingController();
    final aadharNoController = useTextEditingController();
    final emergencyNameController = useTextEditingController();
    final emergencyNumberController = useTextEditingController();
    final dobController = useTextEditingController();
    final selectedGender = useState<String?>(null);
    final selectedBloodGroup = useState<String?>(null);
    final dobIso = useState<String>('');
    final addressController = useTextEditingController();
    final areaController = useTextEditingController();
    final cityController = useTextEditingController();
    final stateController = useTextEditingController();
    final pinController = useTextEditingController();

    // Selection States
    // final selectedGender = useState<String?>(null);
    // final selectedBloodGroup = useState<String?>(null);
    final isAgreed = useState(false);
    // final dateOfBirth = useState<DateTime>(eighteenYearsAgo);
    final referredById = useState<String?>(null);
    final profileImagePath = useState<String?>(null);

    final formKey = useMemoized(() => GlobalKey<FormState>());

    // 1. Define states for coordinates and address details
    final latitude = useState<String>("");
    final longitude = useState<String>("");
    final city = useState<String>("");
    final selectedState = useState<String>("");
    final pinCode = useState<String>("");
    // final isLocating = useState(false);
    final fieldErrors = useState<Map<String, String>>({});

    // 2. This hook replaces initState to trigger location fetch once
    useEffect(() {
      _getCurrentLocation(
        context,
        latitude,
        longitude,
        addressController,
        areaController,
        city,
        selectedState,
        pinCode,
        fieldErrors,
        cityController: cityController,
        stateController: stateController,
        pinController: pinController,
      );
      return null;
    }, []);

    void pickProfileImage() async {
      final file = await ChooseFileBottomSheet.show(showFiles: false);
      if (file != null) {
        final size = await file.length();
        if (size > AppConstants.maxFileSize) {
          MessageService.showError('File size too large. Maximum limit is ${AppConstants.maxFileSizeMB}MB.');
          return;
        }
        profileImagePath.value = file.path;
      }
    }

    void handleSubmit(BuildContext context) {
      if (formKey.currentState!.validate()) {
        if (!isAgreed.value) {
          MessageService.showError("Please accept the declaration to proceed.");
          return;
        }
        // final dob = AppDateFormatter.dateForApi(dateOfBirth.value.toString());
        if (passwordController.text.trim().length < 8) {
          MessageService.showError('Password must be at least 8 characters.');
          return;
        }
        if (passwordController.text != confirmPasswordController.text) {
          MessageService.showError('Password and confirm password do not match.');
          return;
        }
        if (aadharNoController.text.trim().length != 12) {
          MessageService.showError('Enter a valid 12-digit Aadhaar number.');
          return;
        }
        if (addressController.text.trim().isEmpty ||
            cityController.text.trim().isEmpty ||
            stateController.text.trim().isEmpty ||
            pinController.text.trim().length != 6) {
          MessageService.showError('Full address, city, state, and a 6-digit PIN code are required.');
          return;
        }
        final request = UserRegistrationRequest(
          userId: userId,
          name: nameController.text,
          mobileNumber: mobileNumber,
          whatsapp: whatsappController.text.trim(),
          email: emailController.text.trim(),
          password: passwordController.text,
          dob: dobIso.value,
          gender: selectedGender.value,
          bloodGroup: selectedBloodGroup.value,
          emergencyName: emergencyNameController.text.trim(),
          emergencyNumber: emergencyNumberController.text.trim(),
          aadharNo: aadharNoController.text.trim(),
          address: addressController.text.trim(),
          area: areaController.text.trim(),
          city: cityController.text.trim(),
          state: stateController.text.trim(),
          pinCode: pinController.text.trim(),
          // email: emailController.text.trim(),
          // dob: dob,
          // gender: selectedGender.value,
          // bloodGroup: selectedBloodGroup.value,
          // emergencyName: emergencyNameController.text,
          // emergencyNumber: emergencyNumberController.text,
          lat: latitude.value,
          long: longitude.value,
          addressType: "home",
          // area: areaController.text,
          // aadharNo: aadharNoController.text,
          // panNo: panNoController.text,
          referralCode: referralCodeController.text.trim(),
          referredBy: referredById.value,
          profileImagePath: profileImagePath.value,
        );
        // kPrint(request.toJson());
        context.read<UserProfileRegistrationBloc>().add(SubmitUserProfile(request));
      }
    }

    return BlocProvider(
      create: (context) => UserProfileRegistrationBloc(locator<AuthRepository>()),
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Create Your Profile'),
        body: SafeArea(
          child: BlocConsumer<UserProfileRegistrationBloc, UserProfileRegistrationState>(
            listener: (context, state) async {
              if (state is DropdownLoaded) {
                genders.value = state.genders;
                // bloodGroups.value = state.bloodGroups;
              }
              if (state is ProfileSuccess) {
                MessageService.showSuccess("Registration Successful!");
                final storage = locator<LocalStorageService>();
                final String token = state.data['access_token'].toString();
                await storage.saveToken(token);

                final userData = state.data['user'] ?? {};
                await storage.saveUser(userData);

                //  Get FCM Token from the registered Service
                final String? fcmToken = await locator<NotificationService>().getFCMToken();

                if (fcmToken != null && context.mounted) {
                  //  Dispatch to AuthBloc to update the server
                  context.read<AuthBloc>().add(UpdateFcmTokenEvent(fcmToken));
                }

                // IMPORTANT: Notify AuthBloc about the successful login
                if (context.mounted) {
                  final userModel = data_model.UserProfileModel.fromJson(userData);
                  context.read<AuthBloc>().add(LoginSuccess(user: userModel, token: token));

                  // Bootstrap selected address after registration login.
                  // If user never selected manually, notifier auto-picks default/primary and persists it.
                  if (userModel.userType != 'service_provider') {
                    ProviderScope.containerOf(
                      context,
                    ).read(selectedAddressProvider.notifier).loadForLoggedInUser();
                  }

                  // Use popToRoot to go back to AuthWrapper which will now show the dashboard
                  AppNavigator.removeAndGo(AppRoutes.userDashboard);
                }
              }
              if (state is ProfileError) {
                if (state.errors != null) {
                  final errors = <String, String>{};
                  state.errors!.forEach((key, value) {
                    String message = '';
                    if (value is List && value.isNotEmpty) {
                      message = value.first.toString();
                    } else {
                      message = value.toString();
                    }

                    // Map API keys to internal UI keys
                    if (key == 'date_of_birth') {
                      errors['dob'] = message;
                    } else if (key == 'full_address') {
                      errors['address'] = message;
                    } else if (key == 'whatsapp_number') {
                      errors['whatsapp'] = message;
                    } else if (key == 'pan_number') {
                      errors['panNo'] = message;
                    } else if (key == 'emergency_contact_name') {
                      errors['emergencyName'] = message;
                    } else if (key == 'emergency_contact_number') {
                      errors['emergencyNumber'] = message;
                    } else if (key == 'aadhar_no') {
                      errors['aadharNo'] = message;
                    } else {
                      errors[key] = message;
                    }
                  });
                  fieldErrors.value = errors;
                }
                MessageService.showError(state.message);
              }
              if (state is ReferralCodeValidated) {
                MessageService.showSuccess(state.message);
                referredById.value = state.referredById.toString();
                if (fieldErrors.value.containsKey('referral_code')) {
                  fieldErrors.value = Map.from(fieldErrors.value)..remove('referral_code');
                }
              }
              if (state is ReferralCodeInvalid) {
                // MessageService.showError(state.message); // Disable toast to avoid redundancy
                referredById.value = null;
                fieldErrors.value = Map.from(fieldErrors.value)..['referral_code'] = state.message;
              }
            },
            builder: (context, state) {
              if (state is DropdownLoading || state is ProfileLoading || state is UpdateFcmTokenLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              return SingleChildScrollView(
                padding: AppPadding.screenAll,
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Profile Image Upload
                      Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: kPrimaryColor.withValues(alpha: 0.12),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: profileImagePath.value != null
                                  ? CircleAvatar(
                                      radius: 56.r,
                                      backgroundImage: FileImage(File(profileImagePath.value!)),
                                    )
                                  : Container(
                                      width: 112.r,
                                      height: 112.r,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            kPrimaryColor.withValues(alpha: 0.08),
                                            kPrimaryColor.withValues(alpha: 0.18),
                                          ],
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.person_outline_rounded,
                                            size: 44.r,
                                            color: kPrimaryColor.withValues(alpha: 0.5),
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            'Add Photo',
                                            style: kTextNormal0(color: kPrimaryColor.withValues(alpha: 0.6)),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: pickProfileImage,
                                child: Container(
                                  padding: EdgeInsets.all(9.r),
                                  decoration: BoxDecoration(
                                    color: kPrimaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: kPrimaryColor.withValues(alpha: 0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16.r),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 28.h),

                      _buildSectionHeader("Personal Information", Icons.person_pin_rounded),
                      CustomTextField(
                        controller: nameController,
                        labelText: 'Full Name (As per your Aadhaar)',
                        hintText: 'Enter your full name',
                        isRequired: true,
                        keyboardType: TextInputType.name,
                        textInputAction: TextInputAction.next,
                        errorText: fieldErrors.value['name'],
                        onChanged: (v) {
                          if (fieldErrors.value.containsKey('name')) {
                            fieldErrors.value = Map.from(fieldErrors.value)..remove('name');
                          }
                        },
                      ),
                      // Mobile is disabled as it is verified
                      CustomTextField(
                        controller: mobileController,
                        labelText: 'Mobile Number',
                        isRequired: true,
                        enabled: false,
                        errorText: fieldErrors.value['mobile_number'],
                        // prefixIconData: Icons.phone_android,
                      ),
                      CustomTextField(
                        controller: whatsappController,
                        labelText: 'WhatsApp Number',
                        hintText: 'Enter WhatsApp number',
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        prefixIcon: Icon(Icons.chat_rounded, size: 20.sp),
                        maxLength: 10,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        errorText: fieldErrors.value['whatsapp'],
                        onChanged: (v) {
                          if (fieldErrors.value.containsKey('whatsapp')) {
                            fieldErrors.value = Map.from(fieldErrors.value)..remove('whatsapp');
                          }
                        },
                        validator: (v) {
                          if (v != null && v.isNotEmpty && v.length != 10) {
                            return 'WhatsApp number must be 10 digits';
                          }
                          return null;
                        },
                        suffixIcon: whatsappController.text.isEmpty
                            ? TextButton(
                                onPressed: () => whatsappController.text = mobileController.text,
                                child: Text('Same', style: kTextSemiBold(color: kPrimaryColor)),
                              )
                            : null,
                      ),
                      PasswordTextField(
                        controller: passwordController,
                        labelText: 'Password',
                        isRequired: true,
                        validator: (value) {
                          if (value == null || value.length < 8) return 'Password must be at least 8 characters';
                          return null;
                        },
                      ),
                      PasswordTextField(
                        controller: confirmPasswordController,
                        labelText: 'Confirm password',
                        isRequired: true,
                        validator: (value) {
                          if (value != passwordController.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                      CustomTextField(
                        controller: emailController,
                        labelText: 'Email',
                        hintText: 'Optional',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      DatePickerTextField(
                        controller: dobController,
                        labelText: 'Date of Birth',
                        lastDate: DateTime.now(),
                        onDateSelected: (date) {
                          dobIso.value =
                              '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                        },
                      ),
                      CustomDropDown<String>(
                        labelText: 'Gender',
                        hintText: 'Select gender',
                        value: selectedGender.value,
                        items: const [
                          DropdownMenuItem(value: 'MALE', child: Text('Male')),
                          DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                          DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                        ],
                        onChanged: (value) => selectedGender.value = value,
                      ),
                      CustomDropDown<String>(
                        labelText: 'Blood Group',
                        hintText: 'Select blood group',
                        value: selectedBloodGroup.value,
                        items: const [
                          DropdownMenuItem(value: 'A+', child: Text('A+')),
                          DropdownMenuItem(value: 'A-', child: Text('A-')),
                          DropdownMenuItem(value: 'B+', child: Text('B+')),
                          DropdownMenuItem(value: 'B-', child: Text('B-')),
                          DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                          DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                          DropdownMenuItem(value: 'O+', child: Text('O+')),
                          DropdownMenuItem(value: 'O-', child: Text('O-')),
                        ],
                        onChanged: (value) => selectedBloodGroup.value = value,
                      ),
                      CustomTextField(
                        controller: emergencyNameController,
                        labelText: 'Emergency contact name',
                        hintText: 'Optional',
                      ),
                      CustomTextField(
                        controller: emergencyNumberController,
                        labelText: 'Emergency contact number',
                        hintText: '10-digit number',
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (value) {
                          if (value != null && value.isNotEmpty && value.length != 10) {
                            return 'Emergency number must be 10 digits';
                          }
                          return null;
                        },
                      ),
                      CustomTextField(
                        controller: aadharNoController,
                        labelText: 'Aadhaar Number',
                        hintText: '12-digit Aadhaar number',
                        isRequired: true,
                        isNumeric: true,
                        maxLength: 12,
                        errorText: fieldErrors.value['aadharNo'],
                      ),
                      // EmailTextField(
                      //   controller: emailController,
                      //   errorText: fieldErrors.value['email'],
                      //   onChanged: (v) {
                      //     if (fieldErrors.value.containsKey('email')) {
                      //       fieldErrors.value = Map.from(fieldErrors.value)..remove('email');
                      //     }
                      //   },
                      // ),
                      // DatePickerTextField(
                      //   controller: dobController,
                      //   labelText: 'Date of Birth',
                      //   initialDate: dateOfBirth.value,
                      //   isRequired: true,
                      //   lastDate: eighteenYearsAgo,
                      //   errorText: fieldErrors.value['dob'],
                      //   onDateSelected: (date) {
                      //     dateOfBirth.value = date;
                      //     if (fieldErrors.value.containsKey('dob')) {
                      //       fieldErrors.value = Map.from(fieldErrors.value)..remove('dob');
                      //     }
                      //   },
                      // ),
                      // Row(
                      //   crossAxisAlignment: CrossAxisAlignment.start,
                      //   children: [
                      //     Expanded(
                      //       child: CustomDropDown(
                      //         labelText: 'Gender',
                      //         isRequired: true,
                      //         items: mapToDropdownItems(genders.value),
                      //         errorText: fieldErrors.value['gender'],
                      //         onChanged: (val) {
                      //           selectedGender.value = val;
                      //           if (fieldErrors.value.containsKey('gender')) {
                      //             fieldErrors.value = Map.from(fieldErrors.value)..remove('gender');
                      //           }
                      //         },
                      //         value: selectedGender.value,
                      //       ),
                      //     ),
                      //     AppSpacing.sHorizontal,
                      //     Expanded(
                      //       child: CustomDropDown(
                      //         labelText: 'Blood Group',
                      //         items: mapToDropdownItems(bloodGroups.value),
                      //         onChanged: (val) => selectedBloodGroup.value = val,
                      //         value: selectedBloodGroup.value,
                      //       ),
                      //     ),
                      //   ],
                      // ),
                      // CustomTextField(
                      //   controller: aadharNoController,
                      //   labelText: 'Aadhaar Number',
                      //   isRequired: false,
                      //   isNumeric: true,
                      //   maxLength: 12,
                      //   errorText: fieldErrors.value['aadharNo'],
                      //   onChanged: (v) {
                      //     if (fieldErrors.value.containsKey('aadharNo')) {
                      //       fieldErrors.value = Map.from(fieldErrors.value)..remove('aadharNo');
                      //     }
                      //   },
                      //   validator: (value) {
                      //     if (value == null || value.trim().isEmpty) {
                      //       return null;
                      //     } else {
                      //       return Validators.validateAadhaar(value);
                      //     }
                      //   },
                      // ),
                      // CustomTextField(
                      //   controller: panNoController,
                      //   labelText: 'PAN Number',
                      //   isRequired: false,
                      //   maxLength: 10,
                      //   capitalizeAll: true,
                      //   errorText: fieldErrors.value['panNo'],
                      //   onChanged: (v) {
                      //     if (fieldErrors.value.containsKey('panNo')) {
                      //       fieldErrors.value = Map.from(fieldErrors.value)..remove('panNo');
                      //     }
                      //   },
                      //   validator: (value) {
                      //     if (value == null || value.trim().isEmpty) {
                      //       return null;
                      //     } else {
                      //       return Validators.validatePAN(value);
                      //     }
                      //   },
                      //   inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]'))],
                      // ),
                      CustomTextField(
                        enabled: state is! ReferralCodeValidated,
                        controller: referralCodeController,
                        labelText: 'Referral Code',
                        hintText: 'Enter referral code (optional)',
                        capitalizeSentences: true,
                        maxLength: 6,
                        errorText: fieldErrors.value['referral_code'],
                        onChanged: (val) {
                          if (fieldErrors.value.containsKey('referral_code')) {
                            fieldErrors.value = Map.from(fieldErrors.value)..remove('referral_code');
                          }
                        },
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

                      SizedBox(height: 24.h),
                      _buildSectionHeader("Address Details", Icons.location_on_rounded),
                      CustomTextField(
                        controller: addressController,
                        labelText: 'Full Address',
                        hintText: 'Enter your full address',
                        isRequired: true,
                        minLines: 2,
                        maxLines: 4,
                      ),
                      CustomTextField(
                        controller: areaController,
                        labelText: 'Area / Locality',
                        hintText: 'Enter your area or locality',
                      ),
                      CustomTextField(
                        controller: cityController,
                        labelText: 'City',
                        isRequired: true,
                      ),
                      CustomTextField(
                        controller: stateController,
                        labelText: 'State',
                        isRequired: true,
                      ),
                      CustomTextField(
                        controller: pinController,
                        labelText: 'PIN code',
                        isRequired: true,
                        isNumeric: true,
                        maxLength: 6,
                      ),

                      // --- SECTION: LOCATION ---
                      // kSizedBox(height: 24),
                      // _buildSectionHeader("Address Details", Icons.location_on_rounded),
                      // SizedBox(height: 16.h),
                      //
                      // // Use My Location button
                      // _UseMyLocationButton(
                      //   isLocating: isLocating.value,
                      //   onTap: () async {
                      //     isLocating.value = true;
                      //     await _getCurrentLocation(
                      //       context,
                      //       latitude,
                      //       longitude,
                      //       addressController,
                      //       areaController,
                      //       city,
                      //       selectedState,
                      //       pinCode,
                      //       fieldErrors,
                      //     );
                      //     isLocating.value = false;
                      //   },
                      // ),

                      // Change Location button
                      // Padding(
                      //   padding: AppPadding.only(bottom: 4),
                      //   child: OutlinedButton.icon(
                      //     onPressed: () => _openLocationSearch(
                      //       context,
                      //       latitude,
                      //       longitude,
                      //       addressController,
                      //       areaController,
                      //       city,
                      //       selectedState,
                      //       pinCode,
                      //       fieldErrors,
                      //     ),
                      //     icon: Icon(Icons.map_outlined, size: 16.sp, color: kPrimaryColor),
                      //     label: Text('Pick Location', style: kTextMedium(color: kPrimaryColor)),
                      //     style: OutlinedButton.styleFrom(
                      //       foregroundColor: kPrimaryColor,
                      //       side: const BorderSide(color: kPrimaryColor),
                      //       shape: RoundedRectangleBorder(borderRadius: AppRadius.s),
                      //       padding: AppPadding.symmetric(h: 12, v: 8),
                      //     ),
                      //   ),
                      // ),

                      // if (fieldErrors.value.containsKey('location'))
                      //   Padding(
                      //     padding: AppPadding.only(bottom: 16, left: 4),
                      //     child: Text(
                      //       fieldErrors.value['location']!,
                      //       style: kTextNormal(color: kErrorColor).copyWith(fontSize: 12.sp),
                      //     ),
                      //   )
                      // else
                      //   SizedBox(height: 12.h),

                      // CustomTextField(
                      //   controller: addressController,
                      //   labelText: 'Full Address',
                      //   hintText: 'Enter your full address',
                      //   isRequired: true,
                      //   minLines: 3,
                      //   maxLines: 5,
                      //   readOnly: false,
                      //   errorText: fieldErrors.value['address'],
                      //   onChanged: (v) {
                      //     if (fieldErrors.value.containsKey('address')) {
                      //       fieldErrors.value = Map.from(fieldErrors.value)..remove('address');
                      //     }
                      //   },
                      // ),
                      // CustomTextField(
                      //   controller: areaController,
                      //   labelText: 'Area / Locality',
                      //   hintText: 'Enter your area or locality',
                      //   isRequired: false,
                      //   errorText: fieldErrors.value['area'],
                      //   onChanged: (v) {
                      //     if (fieldErrors.value.containsKey('area')) {
                      //       fieldErrors.value = Map.from(fieldErrors.value)..remove('area');
                      //     }
                      //   },
                      // ),

                      // --- SECTION: EMERGENCY CONTACT ---
                      // kSizedBox(height: 24),
                      // _buildSectionHeader("Emergency Contact", Icons.emergency_outlined),
                      // CustomTextField(
                      //   controller: emergencyNameController,
                      //   labelText: 'Contact Name',
                      //   hintText: 'Enter emergency contact name',
                      //   keyboardType: TextInputType.name,
                      //   textInputAction: TextInputAction.next,
                      //   errorText: fieldErrors.value['emergencyName'],
                      //   onChanged: (v) {
                      //     if (fieldErrors.value.containsKey('emergencyName')) {
                      //       fieldErrors.value = Map.from(fieldErrors.value)..remove('emergencyName');
                      //     }
                      //   },
                      // ),
                      // CustomTextField(
                      //   controller: emergencyNumberController,
                      //   labelText: 'Contact Number',
                      //   hintText: 'Enter 10-digit number',
                      //   keyboardType: TextInputType.phone,
                      //   textInputAction: TextInputAction.done,
                      //   maxLength: 10,
                      //   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      //   errorText: fieldErrors.value['emergencyNumber'],
                      //   onChanged: (v) {
                      //     if (fieldErrors.value.containsKey('emergencyNumber')) {
                      //       fieldErrors.value = Map.from(fieldErrors.value)..remove('emergencyNumber');
                      //     }
                      //   },
                      //   validator: (v) {
                      //     if (v != null && v.isNotEmpty && v.length != 10) {
                      //       return 'Emergency number must be 10 digits';
                      //     }
                      //     return null;
                      //   },
                      // ),
                      SizedBox(height: 24.h),
                      // Terms and Conditions Declaration
                      _buildDeclaration(
                        isAgreed: isAgreed,
                        context: context,
                        pinCode: pinCode,
                        fieldErrors: fieldErrors,
                      ),
                      SizedBox(height: 24.h),
                      CustomButton(
                        title: "Complete Registration",
                        width: double.infinity,
                        onPressed: () => handleSubmit(context),
                      ),
                      AppSpacing.xlVertical,
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDeclaration({
    required ValueNotifier<bool> isAgreed,
    required BuildContext context,
    required ValueNotifier<String> pinCode,
    required ValueNotifier<Map<String, String>> fieldErrors,
  }) {
    void handleTap() async {
      String defaultPinCode = '302033'; //sending default pincode to get cityadmin id
      if (pinCode.value.isNotEmpty) {
        defaultPinCode = pinCode.value;
        // fieldErrors.value = Map.from(fieldErrors.value)..['location'] = "Please pick your location to proceed.";
        // return;
      }

      if (!isAgreed.value) {
        try {
          DialogHelper.showLoading(message: 'Checking availability...');
          final authRepo = locator<AuthRepository>();
          final availability = await authRepo.checkServiceAvailability(defaultPinCode);

          if (context.mounted) {
            Navigator.pop(context); // close loading

            final cityId = availability.data?.cityAdmin?.id;

            ConsentHelper.show(
              context: context,
              consentType: 'user_registration',
              cityAdminId: cityId,
              onAgree: () => isAgreed.value = true,
              silentFailure: true,
            );
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.pop(context); // close loading
            isAgreed.value = true;
          }
        }
      } else {
        isAgreed.value = false;
      }
    }

    return GestureDetector(
      onTap: handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: isAgreed.value ? kPrimaryColor.withValues(alpha: 0.04) : kWhiteColor,
          borderRadius: AppRadius.m,
          border: Border.all(color: isAgreed.value ? kPrimaryColor.withValues(alpha: 0.4) : kBorderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 22,
              width: 22,
              child: Checkbox(
                value: isAgreed.value,
                activeColor: kPrimaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (_) => handleTap(),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: "I agree to the "),
                    TextSpan(
                      text: "Terms & Conditions",
                      style: kTextSemiBold0(color: kPrimaryColor).copyWith(decoration: TextDecoration.underline),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => LaunchUrlService.launchInAppWebUrl(RedirectionUrl.userTermsConditions),
                    ),
                    TextSpan(text: " and "),
                    TextSpan(
                      text: "Privacy Policy",
                      style: kTextSemiBold0(color: kPrimaryColor).copyWith(decoration: TextDecoration.underline),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => LaunchUrlService.launchInAppWebUrl(RedirectionUrl.privacyPolicy),
                    ),
                    TextSpan(text: " of Adhisaat."),
                  ],
                  style: kTextNormal(color: kTextSecondaryColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation(
    BuildContext context,
    ValueNotifier<String> lat,
    ValueNotifier<String> long,
    TextEditingController addressController,
    TextEditingController areaController,
    ValueNotifier<String> city,
    ValueNotifier<String> state,
    ValueNotifier<String> pinCode,
    ValueNotifier<Map<String, String>> fieldErrors, {
    TextEditingController? cityController,
    TextEditingController? stateController,
    TextEditingController? pinController,
  }) async {
    try {
      LocationService locationService = LocationService();
      final position = await locationService.getLocationPosition();
      if (position != null && context.mounted) {
        lat.value = position.latitude.toString();
        long.value = position.longitude.toString();
        kPrint("Current Location: ${lat.value}, ${long.value}");

        final addressRes = await locationService.getAddressFromCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        if (context.mounted && addressRes.isSuccess && addressRes.formattedAddress != null) {
          addressController.text = addressRes.formattedAddress!;
          if (addressRes.placemark != null) {
            city.value = addressRes.placemark!.locality ?? "";
            state.value = addressRes.placemark!.administrativeArea ?? "";
            pinCode.value = addressRes.placemark!.postalCode ?? "";
            cityController?.text = city.value;
            stateController?.text = state.value;
            pinController?.text = pinCode.value;
            areaController.text = addressRes.placemark!.subLocality ?? "";
            if (pinCode.value.isNotEmpty) {
              fieldErrors.value = Map.from(fieldErrors.value)..remove('location');
            }
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        MessageService.showError("Something went wrong");
      }
      kPrintError("Error fetching location: $e");
    }
  }

  // void _openLocationSearch(
  //   BuildContext context,
  //   ValueNotifier<String> lat,
  //   ValueNotifier<String> long,
  //   TextEditingController addressController,
  //   TextEditingController areaController,
  //   ValueNotifier<String> city,
  //   ValueNotifier<String> state,
  //   ValueNotifier<String> pinCode,
  //   ValueNotifier<Map<String, String>> fieldErrors,
  // ) async {
  //   final result = await Navigator.push(
  //     context,
  //     MaterialPageRoute(builder: (context) => const SearchAddressPage(returnResult: true)),
  //   );
  //
  //   kPrint("UserProfileRegistrationPage: Received result: $result (Type: ${result?.runtimeType})");
  //   if (context.mounted && result != null && result is UserAddressModel) {
  //     kPrint("UserProfileRegistrationPage: Populating fields with: ${result.fullAddress}");
  //     lat.value = result.latitude ?? "";
  //     long.value = result.longitude ?? "";
  //     addressController.text = result.fullAddress;
  //     city.value = result.city ?? "";
  //     state.value = result.state ?? "";
  //     pinCode.value = result.pinCode ?? "";
  //     areaController.text = result.area ?? "";
  //     if (pinCode.value.isNotEmpty) {
  //       fieldErrors.value = Map.from(fieldErrors.value)..remove('location');
  //     }
  //   }
  // }

  Widget _buildSectionHeader(String title, IconData icon) {
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
        Text(title, style: kTextSemiBold2()),
      ],
    );
  }
}

// class _UseMyLocationButton extends StatelessWidget {
//   final bool isLocating;
//   final VoidCallback onTap;
//
//   const _UseMyLocationButton({required this.isLocating, required this.onTap});
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: AppPadding.only(bottom: 8),
//       child: OutlinedButton.icon(
//         onPressed: isLocating ? null : onTap,
//         icon: isLocating
//             ? SizedBox(
//                 width: 14.w,
//                 height: 14.w,
//                 child: const CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor),
//               )
//             : Icon(Icons.my_location_rounded, size: 16.sp, color: kPrimaryColor),
//         label: Text(isLocating ? 'Locating…' : 'Use My Location', style: kTextMedium(color: kPrimaryColor)),
//         style: OutlinedButton.styleFrom(
//           foregroundColor: kPrimaryColor,
//           side: const BorderSide(color: kPrimaryColor),
//           shape: RoundedRectangleBorder(borderRadius: AppRadius.s),
//           padding: AppPadding.symmetric(h: 12, v: 8),
//         ),
//       ),
//     );
//   }
// }

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
