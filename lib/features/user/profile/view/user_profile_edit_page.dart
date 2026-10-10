import 'dart:io';

import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:adhisaat_health_care/core/utils/message_service.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_cached_image.dart';
import 'package:adhisaat_health_care/shared/widgets/dialogs/custom_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../data/models/user_profile_model.dart';
import '../../../../data/shared_blocs/dropdown/dropdown_bloc.dart';
import '../../../../data/shared_blocs/dropdown/dropdown_state.dart';
import '../../../../data/shared_blocs/user_profile_bloc.dart';
import '../../../../di/locator.dart';
import '../../../../shared/widgets/buttons/custom_button.dart';
import '../../../../shared/widgets/common/app_bar_custom.dart';
import '../../../../shared/widgets/inputs/custom_drop_down.dart';
import '../../../../shared/widgets/inputs/custom_text_field.dart';
import '../bloc/update_profile/update_profile_bloc.dart';
import '../bloc/user_profile_bloc.dart' as profile_bloc;
import '../data/user_profile_repository.dart';

class UserProfileEditPage extends StatelessWidget {
  const UserProfileEditPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = UserProfileRepository(locator<ApiClient>(), locator<LocalStorageService>());
    return MultiBlocProvider(
      providers: [
        BlocProvider<profile_bloc.UserProfileBloc>(
          create: (_) => profile_bloc.UserProfileBloc(repository)..add(profile_bloc.LoadUserProfile()),
        ),
        BlocProvider(create: (_) => UpdateProfileBloc(repository)),
      ],
      child: const _UpdateProfileView(),
    );
  }
}

class _UpdateProfileView extends StatefulWidget {
  const _UpdateProfileView();

  @override
  State<_UpdateProfileView> createState() => _UpdateProfileViewState();
}

class _UpdateProfileViewState extends State<_UpdateProfileView> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _whatsappCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _dobCtrl;
  late final TextEditingController _emergencyNameCtrl;
  late final TextEditingController _emergencyPhoneCtrl;
  late final TextEditingController _aadharCtrl;
  late final TextEditingController _panCtrl;

  String? _gender;
  String? _bloodGroup;
  DateTime? _selectedDob;
  File? _profileImage;
  String? _profileImageUrl;

  Map<String, String> _fieldErrors = {};
  bool _isHydratedFromProfile = false;
  UserProfileModel? _baseProfile;

  static const _genders = ['male', 'female', 'other'];
  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _mobileCtrl = TextEditingController();
    _whatsappCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _dobCtrl = TextEditingController();
    _emergencyNameCtrl = TextEditingController();
    _emergencyPhoneCtrl = TextEditingController();
    _aadharCtrl = TextEditingController();
    _panCtrl = TextEditingController();
  }

  void _hydrateFromProfile(UserProfileModel p) {
    _baseProfile = p;
    _nameCtrl.text = p.name;
    _mobileCtrl.text = p.mobileNumber;
    _whatsappCtrl.text = p.whatsappNumber ?? '';
    _emailCtrl.text = p.email;

    if (p.dateOfBirth != null && p.dateOfBirth!.isNotEmpty) {
      try {
        _selectedDob = DateTime.tryParse(p.dateOfBirth!);
        if (_selectedDob != null) {
          _dobCtrl.text = DateFormat('dd MMM yyyy').format(_selectedDob!);
        } else {
          // Try other common formats if ISO fails
          _selectedDob = DateFormat('yyyy-MM-dd').parse(p.dateOfBirth!);
          _dobCtrl.text = DateFormat('dd MMM yyyy').format(_selectedDob!);
        }
      } catch (_) {
        _dobCtrl.text = p.dateOfBirth!;
      }
    } else {
      _dobCtrl.text = '';
      _selectedDob = null;
    }

    _emergencyNameCtrl.text = p.emergencyContactName ?? '';
    _emergencyPhoneCtrl.text = p.emergencyContactNumber ?? '';
    _aadharCtrl.text = p.aadharNo ?? '';
    _panCtrl.text = p.panNumber ?? '';

    _gender = _normalise(p.gender, _genders);
    _bloodGroup = _normalise(p.bloodGroup, _bloodGroups);
    _profileImageUrl = p.profilePhoto;
  }

  bool _isDirty() {
    if (_baseProfile == null) return false;
    final p = _baseProfile!;
    return _nameCtrl.text != p.name ||
        _mobileCtrl.text != p.mobileNumber ||
        (_whatsappCtrl.text != (p.whatsappNumber ?? '')) ||
        _emailCtrl.text != p.email ||
        (_dobCtrl.text != (p.dateOfBirth ?? '')) ||
        (_emergencyNameCtrl.text != (p.emergencyContactName ?? '')) ||
        (_emergencyPhoneCtrl.text != (p.emergencyContactNumber ?? '')) ||
        (_aadharCtrl.text != (p.aadharNo ?? '')) ||
        (_panCtrl.text != (p.panNumber ?? '')) ||
        _gender != _normalise(p.gender, _genders) ||
        _bloodGroup != _normalise(p.bloodGroup, _bloodGroups) ||
        _profileImage != null;
  }

  String? _normalise(String? value, List<String> options) {
    if (value == null || value.isEmpty) return null;
    try {
      return options.firstWhere((o) => o.toLowerCase() == value.toLowerCase(), orElse: () => value);
    } catch (_) {
      return value;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _aadharCtrl.dispose();
    _panCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final file = await ChooseFileBottomSheet.show(showFiles: false);
    if (file != null) {
      final size = await file.length();
      if (size > AppConstants.maxFileSize) {
        MessageService.showError('Photo too large. Maximum limit is ${AppConstants.maxFileSizeMB}MB.');
        return;
      }
      setState(() => _profileImage = file);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);

    DateTime initialDate = eighteenYearsAgo;
    if (_selectedDob != null) {
      if (_selectedDob!.isBefore(eighteenYearsAgo) || _selectedDob!.isAtSameMomentAs(eighteenYearsAgo)) {
        initialDate = _selectedDob!;
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1920),
      lastDate: eighteenYearsAgo,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: kPrimaryColor)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobCtrl.text = DateFormat('dd MMM yyyy').format(picked);
        if (_fieldErrors.containsKey('dob')) {
          _fieldErrors = Map.from(_fieldErrors)..remove('dob');
        }
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    context.read<UpdateProfileBloc>().add(
      SubmitUpdateProfile(
        name: _nameCtrl.text.trim(),
        mobileNumber: _mobileCtrl.text.trim(),
        whatsappNumber: _whatsappCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        dateOfBirth: _selectedDob != null ? DateFormat('yyyy-MM-dd').format(_selectedDob!) : null,
        bloodGroup: _bloodGroup?.toLowerCase(),
        gender: _gender?.toLowerCase(),
        emergencyContactName: _emergencyNameCtrl.text.trim(),
        emergencyContactNumber: _emergencyPhoneCtrl.text.trim(),
        aadharNo: _aadharCtrl.text.trim(),
        panNumber: _panCtrl.text.trim(),
        profileImage: _profileImage,
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_isDirty()) return true;

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kWhiteColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text('Unsaved Changes', style: kTextBold(color: kTextPrimaryColor)),
        content: Text(
          'You have unsaved changes. Would you like to save them before leaving?',
          style: kTextNormal(color: kTextSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 0), // Back without save
            child: Text('Discard', style: kTextSemiBold(color: kErrorColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 1), // Save & back
            child: Text('Save & Exit', style: kTextSemiBold(color: kPrimaryColor)),
          ),
        ],
      ),
    );

    if (result == 0) return true;
    if (result == 1) {
      _submit();
      return false; // Submission will handle navigation
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: MultiBlocListener(
        listeners: [
          BlocListener<profile_bloc.UserProfileBloc, profile_bloc.UserProfileState>(
            listener: (ctx, state) {
              if (state is profile_bloc.UserProfileLoaded && !_isHydratedFromProfile) {
                setState(() {
                  _hydrateFromProfile(state.profile);
                  _isHydratedFromProfile = true;
                });
              }
            },
          ),
          BlocListener<UpdateProfileBloc, UpdateProfileState>(
            listener: (ctx, state) {
              if (state is UpdateProfileSuccess) {
                try {
                  ctx.read<UserBloc>().add(UpdateUserProfile(state.profile));
                } catch (_) {}
                MessageService.showSuccess(state.message);
                Navigator.of(ctx).pop(state.profile);
              }
              if (state is UpdateProfileError) {
                if (state.errors != null) {
                  final errors = <String, String>{};
                  state.errors!.forEach((key, value) {
                    String message = '';
                    if (value is List && value.isNotEmpty) {
                      message = value.first.toString();
                    } else {
                      message = value.toString();
                    }

                    // Map API keys to internal UI keys if necessary
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
                  setState(() => _fieldErrors = errors);
                }
                MessageService.showError(state.message);
              }
            },
          ),
        ],
        child: Scaffold(
          backgroundColor: kWhiteColor,
          appBar: CustomAppBar(title: 'Edit Profile'),
          body: SafeArea(
            child: _Body(
              isHydrated: _isHydratedFromProfile,
              formKey: _formKey,
              onRefresh: () => context.read<profile_bloc.UserProfileBloc>().add(profile_bloc.LoadUserProfile()),
              children: [
                SizedBox(height: 16.h),

                // ── Avatar ──────────────
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 90.w,
                        height: 90.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kGreyColor,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _profileImage != null
                              ? Image.file(_profileImage!, fit: BoxFit.cover)
                              : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                              ? AppCachedImage(imageUrl: _profileImageUrl!, isOval: true)
                              : _buildInitials(_nameCtrl.text),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 2,
                        child: GestureDetector(
                          onTap: _pickProfileImage,
                          child: Container(
                            padding: EdgeInsets.all(6.w),
                            decoration: BoxDecoration(
                              color: kPrimaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6)],
                            ),
                            child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16.sp),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20.h),

                // ── Form Cards ──────────────
                _FormCard(
                  title: 'Personal Details',
                  children: [
                    CustomTextField(
                      controller: _nameCtrl,
                      labelText: 'Full Name (As per your Aadhaar)',
                      hintText: 'Enter your name',
                      isRequired: true,
                      prefixIcon: Icon(Icons.person_outline, color: kPrimaryColor, size: 18.sp),
                      errorText: _fieldErrors['name'],
                      onChanged: (v) {
                        if (_fieldErrors.containsKey('name')) {
                          setState(() => _fieldErrors = Map.from(_fieldErrors)..remove('name'));
                        }
                      },
                      validator: Validators.validateIsNoEmpty,
                    ),
                    SizedBox(height: 16.h),
                    EmailTextField(
                      controller: _emailCtrl,
                      labelText: 'Email Address',
                      errorText: _fieldErrors['email'],
                      onChanged: (v) {
                        if (_fieldErrors.containsKey('email')) {
                          setState(() => _fieldErrors = Map.from(_fieldErrors)..remove('email'));
                        }
                      },
                    ),
                    SizedBox(height: 16.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: BlocBuilder<DropdownBloc, DropdownState>(
                            builder: (context, dropState) {
                              final items = (dropState is DropdownLoaded)
                                  ? dropState.data.genders
                                  : {'male': 'Male', 'female': 'Female', 'other': 'Other'};
                              return CustomDropDown<String>(
                                labelText: 'Gender',
                                hintText: 'Select',
                                value: _gender,
                                isRequired: true,
                                items: mapToDropdownItems(items),
                                errorText: _fieldErrors['gender'],
                                onChanged: (v) {
                                  setState(() {
                                    _gender = v;
                                    if (_fieldErrors.containsKey('gender')) {
                                      _fieldErrors = Map.from(_fieldErrors)..remove('gender');
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: BlocBuilder<DropdownBloc, DropdownState>(
                            builder: (context, dropState) {
                              final items = (dropState is DropdownLoaded)
                                  ? dropState.data.bloodGroups
                                  : {'A+': 'A+', 'B+': 'B+'};
                              return CustomDropDown<String>(
                                labelText: 'Blood Group',
                                hintText: 'Select',
                                value: _bloodGroup,
                                items: mapToDropdownItems(items),
                                onChanged: (v) => setState(() => _bloodGroup = v),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    GestureDetector(
                      onTap: _pickDate,
                      child: AbsorbPointer(
                        child: CustomTextField(
                          controller: _dobCtrl,
                          labelText: 'Date of Birth',
                          hintText: 'Select Date',
                          isRequired: true,
                          prefixIcon: Icon(Icons.calendar_today_outlined, color: kPrimaryColor, size: 18.sp),
                          errorText: _fieldErrors['dob'],
                          onChanged: (v) {
                            if (_fieldErrors.containsKey('dob')) {
                              setState(() => _fieldErrors = Map.from(_fieldErrors)..remove('dob'));
                            }
                          },
                          validator: Validators.validateMinimumAge,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12.h),

                _FormCard(
                  title: 'Contact Information',
                  children: [
                    CustomTextField(
                      controller: _mobileCtrl,
                      labelText: 'Mobile Number',
                      enabled: false,
                      isRequired: true,
                      prefixIcon: Icon(Icons.phone_android_rounded, color: kPrimaryColor, size: 18.sp),
                    ),
                    SizedBox(height: 16.h),
                    CustomTextField(
                      controller: _whatsappCtrl,
                      labelText: 'WhatsApp Number',
                      hintText: '10-digit number',
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      prefixIcon: Icon(Icons.chat_outlined, color: kPrimaryColor, size: 18.sp),
                      errorText: _fieldErrors['whatsapp'],
                      onChanged: (v) {
                        if (_fieldErrors.containsKey('whatsapp')) {
                          setState(() => _fieldErrors = Map.from(_fieldErrors)..remove('whatsapp'));
                        }
                      },
                      validator: (v) => (v != null && v.isNotEmpty)
                          ? Validators.validatePhone(v, label: 'WhatsApp number')
                          : null,
                    ),
                  ],
                ),

                SizedBox(height: 12.h),

                _FormCard(
                  title: 'Identity & Safety',
                  children: [
                    CustomTextField(
                      controller: _aadharCtrl,
                      labelText: 'Aadhaar Number',
                      hintText: '12-digit number',
                      keyboardType: TextInputType.number,
                      maxLength: 12,
                      prefixIcon: Icon(Icons.badge_outlined, color: kPrimaryColor, size: 18.sp),
                      errorText: _fieldErrors['aadharNo'],
                      onChanged: (v) {
                        if (_fieldErrors.containsKey('aadharNo')) {
                          setState(() => _fieldErrors = Map.from(_fieldErrors)..remove('aadharNo'));
                        }
                      },
                      validator: (v) => (v != null && v.isNotEmpty) ? Validators.validateAadhaar(v) : null,
                    ),
                    SizedBox(height: 16.h),
                    CustomTextField(
                      controller: _panCtrl,
                      labelText: 'PAN Number',
                      hintText: 'ABCDE1234F',
                      maxLength: 10,
                      inputFormatters: [UpperCaseTextFormatter()],
                      prefixIcon: Icon(Icons.credit_card_outlined, color: kPrimaryColor, size: 18.sp),
                      errorText: _fieldErrors['panNo'],
                      onChanged: (v) {
                        if (_fieldErrors.containsKey('panNo')) {
                          setState(() => _fieldErrors = Map.from(_fieldErrors)..remove('panNo'));
                        }
                      },
                      validator: (v) => (v != null && v.isNotEmpty) ? Validators.validatePAN(v) : null,
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      'Emergency Contact',
                      style: kTextSemiBold(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
                    ),
                    SizedBox(height: 12.h),
                    CustomTextField(
                      controller: _emergencyNameCtrl,
                      labelText: 'Contact Person',
                      hintText: 'Name of guardian/relative',
                      prefixIcon: Icon(Icons.person_pin_outlined, color: kPrimaryColor, size: 18.sp),
                    ),
                    SizedBox(height: 16.h),
                    CustomTextField(
                      controller: _emergencyPhoneCtrl,
                      labelText: 'Contact Phone',
                      hintText: '10-digit number',
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      prefixIcon: Icon(Icons.phone_outlined, color: kPrimaryColor, size: 18.sp),
                      errorText: _fieldErrors['emergencyNumber'],
                      onChanged: (v) {
                        if (_fieldErrors.containsKey('emergencyNumber')) {
                          setState(() => _fieldErrors = Map.from(_fieldErrors)..remove('emergencyNumber'));
                        }
                      },
                      validator: (v) => (v != null && v.isNotEmpty)
                          ? Validators.validatePhone(v, label: 'Emergency contact')
                          : null,
                    ),
                  ],
                ),

                SizedBox(height: 16.h),
                BlocBuilder<UpdateProfileBloc, UpdateProfileState>(
                  builder: (context, state) {
                    final isLoading = state is UpdateProfileLoading;
                    return Padding(
                      padding: EdgeInsets.all(16.r),
                      child: CustomButton(
                        width: double.infinity,
                        title: 'Update',
                        onPressed: isLoading ? null : _submit,
                        isLoading: isLoading,
                      ),
                    );
                  },
                ),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitials(String name) {
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (name.isNotEmpty ? name[0].toUpperCase() : 'U');
    return Container(
      color: kGreyColor,
      child: Center(
        child: Text(initials, style: kTextBold1(color: kPrimaryColor)),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final bool isHydrated;
  final GlobalKey<FormState> formKey;
  final VoidCallback onRefresh;
  final List<Widget> children;

  const _Body({required this.isHydrated, required this.formKey, required this.onRefresh, required this.children});

  @override
  Widget build(BuildContext context) {
    if (!isHydrated) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            SizedBox(height: 16.h),
            Text('Loading profile...', style: kTextNormal(color: kTextSecondaryColor)),
          ],
        ),
      );
    }
    return Form(
      key: formKey,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(children: children),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _FormCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
          ),
          SizedBox(height: 16.h),
          ...children,
        ],
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}
