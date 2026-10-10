import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/data/repositories/blood_donation_repository.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/blood_donor/donor_profile/data/model/donor_profile_model.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class DonorOnboardingPage extends StatefulWidget {
  const DonorOnboardingPage({super.key});

  @override
  State<DonorOnboardingPage> createState() => _DonorOnboardingPageState();
}

class _DonorOnboardingPageState extends State<DonorOnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  
  String? _selectedGender;
  String? _selectedBloodGroup;
  String? _selectedContactMethod = 'whatsapp';
  bool _isAvailable = true;
  bool _showContactPublicly = true;
  final bool _receiveNotifications = true;
  DateTime? _selectedDate;
  bool _isLoading = false;

  final List<String> _contactMethods = ['whatsapp', 'phone', 'email'];
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
  final List<String> _genders = ['male', 'female', 'other'];

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Age Validation (Min 18)
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your date of birth')),
      );
      return;
    }

    final age = DateTime.now().year - _selectedDate!.year;
    final monthDiff = DateTime.now().month - _selectedDate!.month;
    final dayDiff = DateTime.now().day - _selectedDate!.day;

    bool isUnder18 = age < 18 || (age == 18 && (monthDiff < 0 || (monthDiff == 0 && dayDiff < 0)));

    if (isUnder18) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum age for donation is 18 years')),
      );
      return;
    }

    // Weight Validation (Min 40kg)
    final weight = double.tryParse(_weightController.text) ?? 0;
    if (weight < 40) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum weight for donation is 40 kg')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profile = DonorProfile(
        bloodGroup: _selectedBloodGroup,
        gender: _selectedGender,
        dateOfBirth: _selectedDate?.toIso8601String().split('T')[0],
        weightKg: weight,
        isAvailable: _isAvailable,
        preferredContactMethod: _selectedContactMethod,
        showContactPublicly: _showContactPublicly,
        receiveNotifications: _receiveNotifications,
      );

      await locator<BloodDonationRepository>().updateDonorProfile(profile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you! You are now registered as a donor.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to register: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: CustomAppBar(title: 'Become a Donor'),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                SizedBox(height: 24.h),
                _buildSection('Health Details', [
                  _buildBloodGroupDropdown(),
                  SizedBox(height: 16.h),
                  _buildWeightField(),
                ]),
                SizedBox(height: 24.h),
                _buildSection('Personal Details', [
                  _buildGenderDropdown(),
                  SizedBox(height: 16.h),
                  _buildDatePicker(),
                ]),
                SizedBox(height: 24.h),
                _buildSection('Preferences', [
                  _buildContactMethodDropdown(),
                  SizedBox(height: 12.h),
                  _buildSwitchTile(
                    'Available for urgent requests',
                    _isAvailable,
                    (v) => setState(() => _isAvailable = v),
                    Icons.volunteer_activism,
                  ),
                  _buildSwitchTile(
                    'Show my contact to hospitals',
                    _showContactPublicly,
                    (v) => setState(() => _showContactPublicly = v),
                    Icons.visibility,
                  ),
                ]),
                SizedBox(height: 40.h),
                _buildSubmitButton(),
                SizedBox(height: 24.h),
              ],
            ),
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
          'Join Our Life-Saving Community',
          style: kHeadingMedium().copyWith(color: kErrorColor),
        ),
        SizedBox(height: 8.h),
        Text(
          'Your contribution can save lives. Please provide your details to register as a blood donor.',
          style: kTextNormal().copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: EdgeInsets.all(20.w),
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
          SizedBox(height: 20.h),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBloodGroupDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedBloodGroup,
      decoration: _inputDecoration('Blood Group', Icons.bloodtype_rounded),
      items: _bloodGroups.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (v) => setState(() => _selectedBloodGroup = v),
      validator: (v) => v == null ? 'Required' : null,
    );
  }

  Widget _buildWeightField() {
    return TextFormField(
      controller: _weightController,
      keyboardType: TextInputType.number,
      decoration: _inputDecoration('Weight (kg)', Icons.fitness_center_rounded),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (double.tryParse(v) == null) return 'Invalid number';
        return null;
      },
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedGender,
      decoration: _inputDecoration('Gender', Icons.person_outline_rounded),
      items: _genders.map((e) => DropdownMenuItem(value: e, child: Text(e.capitalize()))).toList(),
      onChanged: (v) => setState(() => _selectedGender = v),
      validator: (v) => v == null ? 'Required' : null,
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now().subtract(const Duration(days: 6570)),
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
        );
        if (date != null) setState(() => _selectedDate = date);
      },
      child: InputDecorator(
        decoration: _inputDecoration('Date of Birth', Icons.calendar_today_rounded),
        child: Text(
          _selectedDate != null
              ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
              : 'Select Date',
          style: kTextNormal(),
        ),
      ),
    );
  }

  Widget _buildContactMethodDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedContactMethod,
      decoration: _inputDecoration('Preferred Contact', Icons.chat_bubble_outline_rounded),
      items: _contactMethods.map((e) => DropdownMenuItem(value: e, child: Text(e.capitalize()))).toList(),
      onChanged: (v) => setState(() => _selectedContactMethod = v),
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: kErrorColor,
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey[400]),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor)),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56.h,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: kErrorColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text('Submit Details', style: kTextBold1()),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() => "${this[0].toUpperCase()}${substring(1)}";
}
