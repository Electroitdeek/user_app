import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/data/repositories/blood_donation_repository.dart';
import 'package:adhisaat_health_care/data/shared_blocs/dropdown/dropdown_bloc.dart';
import 'package:adhisaat_health_care/data/shared_blocs/dropdown/dropdown_state.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/blood_donor/donor_profile/bloc/donor_profile_bloc.dart';
import 'package:adhisaat_health_care/features/blood_donor/donor_profile/data/model/donor_profile_model.dart';
import 'package:adhisaat_health_care/shared/widgets/buttons/custom_button.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:adhisaat_health_care/shared/widgets/progress_bar/transparent_loader.dart';
import 'package:adhisaat_health_care/core/utils/message_service.dart';
import 'package:adhisaat_health_care/shared/widgets/dialogs/dialog_helpers.dart';
import 'package:adhisaat_health_care/shared/widgets/inputs/custom_drop_down.dart';
import 'package:adhisaat_health_care/shared/widgets/inputs/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class DonorProfileEditPage extends StatefulWidget {
  final DonorProfile profile;

  const DonorProfileEditPage({super.key, required this.profile});

  @override
  State<DonorProfileEditPage> createState() => _DonorProfileEditPageState();
}

class _DonorProfileEditPageState extends State<DonorProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _weightController;
  late TextEditingController _dobController;

  String? _selectedGender;
  String? _selectedBloodGroup;
  String? _selectedContactMethod;
  bool _isAvailable = false;
  bool _showContactPublicly = false;
  bool _receiveNotifications = true;
  DateTime? _selectedDate;

  final List<String> _contactMethods = ['call', 'whatsapp', 'both'];

  @override
  void initState() {
    super.initState();
    _initializeValues();
  }

  void _initializeValues() {
    _weightController = TextEditingController(text: widget.profile.weightKg?.toString() ?? '');
    _selectedGender = widget.profile.gender;
    _selectedBloodGroup = widget.profile.bloodGroup;
    _selectedContactMethod = widget.profile.preferredContactMethod;
    _isAvailable = widget.profile.isAvailable ?? false;
    _showContactPublicly = widget.profile.showContactPublicly ?? false;
    _receiveNotifications = widget.profile.receiveNotifications ?? true;

    if (widget.profile.dateOfBirth != null) {
      try {
        _selectedDate = DateTime.parse(widget.profile.dateOfBirth!);
      } catch (e) {
        _selectedDate = null;
      }
    }

    _dobController = TextEditingController(
      text: _selectedDate != null ? AppDateFormatter.dateOnly(_selectedDate!) : '',
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DonorProfileBloc(locator<BloodDonationRepository>()),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: CustomAppBar(title: widget.profile.id == null ? 'Donor Registration' : 'Edit Donor Profile'),
        body: SafeArea(
          child: BlocConsumer<DonorProfileBloc, DonorProfileState>(
            listener: (context, state) {
              if (state is DonorProfileUpdateSuccess) {
                Navigator.pop(context, true);
                MessageService.showSuccess('Donor profile updated successfully');
              }
              if (state is DonorProfileError) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
              }
            },
            builder: (context, state) {
              final isLoading = state is DonorProfileUpdating;

              return Stack(
                children: [
                  Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                  padding: EdgeInsets.all(14.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      SizedBox(height: 14.h),
                      _buildSection('Basic Information', [
                        _buildBloodGroupDropdown(),
                        SizedBox(height: 12.h),
                        _buildGenderDropdown(),
                        SizedBox(height: 12.h),
                        _buildDatePicker(),
                        SizedBox(height: 12.h),
                        _buildWeightField(),
                      ]),
                      SizedBox(height: 12.h),
                      _buildSection('Availability', [
                        _buildSwitchTile(
                          'Available for Donation',
                          _isAvailable,
                          (value) => setState(() => _isAvailable = value),
                          Icons.volunteer_activism_rounded,
                        ),
                      ]),
                      SizedBox(height: 12.h),
                      _buildSection('Contact Preferences', [
                        _buildContactMethodDropdown(),
                        SizedBox(height: 12.h),
                        _buildSwitchTile(
                          'Show Contact Publicly',
                          _showContactPublicly,
                          (value) => setState(() => _showContactPublicly = value),
                          Icons.visibility_rounded,
                        ),
                        SizedBox(height: 8.h),
                        _buildSwitchTile(
                          'Receive Notifications',
                          _receiveNotifications,
                          (value) => setState(() => _receiveNotifications = value),
                          Icons.notifications_rounded,
                        ),
                      ]),
                      SizedBox(height: 20.h),
                      _buildSubmitButton(isLoading, context),
                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
              ),
                  if (isLoading) const TransparentLoader(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.profile.id == null ? 'Become a Donor' : 'Donor Profile Details',
          style: kHeadingMedium().copyWith(color: kErrorColor),
        ),
        SizedBox(height: 8.h),
        Text(
          'Keep your information up to date to help us coordinate life-saving donations effectively.',
          style: kTextNormal().copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: kTextSemiBold1()),
          SizedBox(height: 12.h),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBloodGroupDropdown() {
    return BlocBuilder<DropdownBloc, DropdownState>(
      builder: (context, dropState) {
        final dropdownData = dropState is DropdownLoaded ? dropState.data : null;
        final items =
            dropdownData?.bloodGroups ??
            {'A+': 'A+', 'A-': 'A-', 'B+': 'B+', 'B-': 'B-', 'O+': 'O+', 'O-': 'O-', 'AB+': 'AB+', 'AB-': 'AB-'};
        return CustomDropDown<String>(
          labelText: 'Blood Group',
          hintText: 'Select Blood Group',
          value: _selectedBloodGroup,
          prefixIcon: Icon(Icons.bloodtype_rounded, color: kErrorColor.withValues(alpha: 0.7)),
          items: mapToDropdownItems(items),
          onChanged: (value) => setState(() => _selectedBloodGroup = value),
          isRequired: true,
        );
      },
    );
  }

  Widget _buildGenderDropdown() {
    return BlocBuilder<DropdownBloc, DropdownState>(
      builder: (context, dropState) {
        final dropdownData = dropState is DropdownLoaded ? dropState.data : null;
        final items = dropdownData?.genders ?? {'male': 'Male', 'female': 'Female', 'other': 'Other'};
        return CustomDropDown<String>(
          labelText: 'Gender',
          hintText: 'Select Gender',
          value: _selectedGender,
          prefixIcon: const Icon(Icons.person_outline_rounded, color: kPrimaryColor),
          items: mapToDropdownItems(items),
          onChanged: (value) => setState(() => _selectedGender = value),
          isRequired: true,
        );
      },
    );
  }

  Widget _buildDatePicker() {
    return DatePickerTextField(
      controller: _dobController,
      labelText: 'Date of Birth',
      initialDate: _selectedDate ?? DateTime.now().subtract(const Duration(days: 6570)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      onDateSelected: (date) {
        setState(() {
          _selectedDate = date;
        });
      },
      isRequired: true,
    );
  }

  Widget _buildWeightField() {
    return CustomTextField(
      controller: _weightController,
      labelText: 'Weight (kg)',
      hintText: 'Enter weight',
      isDecimal: true,
      prefixIcon: const Icon(Icons.fitness_center_rounded, color: kTextHintColor),
      isRequired: true,
      inputFormatters: [_MaxWeightFormatter(150)],
    );
  }

  Widget _buildContactMethodDropdown() {
    return CustomDropDown<String>(
      labelText: 'Preferred Contact Method',
      hintText: 'Select contact method',
      value: _selectedContactMethod,
      prefixIcon: const Icon(Icons.contact_phone_rounded, color: kPrimaryColor),
      items: _contactMethods.map((method) {
        return DropdownMenuItem(value: method, child: Text(method[0].toUpperCase() + method.substring(1)));
      }).toList(),
      onChanged: (value) => setState(() => _selectedContactMethod = value),
      isRequired: true,
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(icon, size: 20, color: kPrimaryColor),
          SizedBox(width: 12.w),
          Expanded(child: Text(title, style: kTextNormal())),
          Switch(value: value, onChanged: onChanged, activeThumbColor: kErrorColor),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isLoading, BuildContext context) {
    return CustomButton(
      onPressed: () => _submitForm(context),
      title: 'Save Details',
      backgroundColor: kErrorColor,
      isLoading: isLoading,
      borderRadius: BorderRadius.circular(16),
      width: double.infinity,
      height: 56.h,
    );
  }

  void _submitForm(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      // Age Validation (18–65)
      if (_selectedDate != null) {
        final now = DateTime.now();
        int age = now.year - _selectedDate!.year;
        if (now.month < _selectedDate!.month ||
            (now.month == _selectedDate!.month && now.day < _selectedDate!.day)) {
          age--;
        }

        if (age < 18) {
          DialogHelper.showInfo(
            title: 'Not Eligible for Donation',
            message:
                'You are not eligible to register as a blood donor.\n\nMinimum age required is 18 years. You can register once you meet the eligibility criteria.',
            buttonText: 'Understood',
          );
          return;
        }
        if (age > 65) {
          DialogHelper.showInfo(
            title: 'Not Eligible for Donation',
            message:
                'You are not eligible to register as a blood donor.\n\nBlood donation is only allowed for individuals aged 18 to 65 years.',
            buttonText: 'Understood',
          );
          return;
        }
      }

      // Weight Validation (Min 40kg)
      final minWeight = 45;
      final weight = double.tryParse(_weightController.text) ?? 0;
      if (weight < minWeight) {
        DialogHelper.showInfo(
          title: 'Not Eligible for Donation',
          message:
              'You are not eligible to register as a blood donor.\n\nMinimum weight required is $minWeight kg. You can register once you meet the eligibility criteria.',
          buttonText: 'Understood',
        );
        return;
      }

      final updatedProfile = widget.profile.copyWith(
        bloodGroup: _selectedBloodGroup,
        gender: _selectedGender,
        dateOfBirth: _selectedDate?.toIso8601String().split('T')[0],
        weightKg: weight,
        isAvailable: _isAvailable,
        preferredContactMethod: _selectedContactMethod,
        showContactPublicly: _showContactPublicly,
        receiveNotifications: _receiveNotifications,
      );

      context.read<DonorProfileBloc>().add(UpdateDonorProfile(updatedProfile));
    }
  }
}

class _MaxWeightFormatter extends TextInputFormatter {
  final double max;
  const _MaxWeightFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final parsed = double.tryParse(newValue.text);
    if (parsed == null) return newValue;
    if (parsed > max) return oldValue;
    return newValue;
  }
}
