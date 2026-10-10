import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/core/utils/message_service.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/shared_blocs/dropdown/dropdown_bloc.dart';
import '../../../../data/shared_blocs/dropdown/dropdown_state.dart';
import '../../../../di/locator.dart';
import '../../../../shared/widgets/inputs/common_inputs.dart';
import '../../../../shared/widgets/inputs/custom_drop_down.dart' show CustomDropDown, mapToDropdownItems;
import '../../../../shared/widgets/inputs/custom_text_field.dart';
import '../bloc/family_bloc.dart';
import '../bloc/family_event.dart';
import '../bloc/family_state.dart';
import '../data/family_repository.dart';
import '../model/family_member_model.dart';

class FamilyAddEditPage extends StatelessWidget {
  final FamilyMemberModel? existing;

  const FamilyAddEditPage({super.key, this.existing});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FamilyBloc>(
      create: (_) => FamilyBloc(locator<FamilyRepository>()),
      child: _FamilyAddEditView(existing: existing),
    );
  }
}

class _FamilyAddEditView extends StatefulWidget {
  final FamilyMemberModel? existing;

  const _FamilyAddEditView({this.existing});

  @override
  State<_FamilyAddEditView> createState() => _FamilyAddEditViewState();
}

class _FamilyAddEditViewState extends State<_FamilyAddEditView> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  DateTime? _selectedDob;

  String _gender = 'male';
  String? _relationship;
  String? _bloodGroup;
  bool _isLoading = false;

  final List<String> _relationships = ['Father', 'Mother', 'Brother', 'Sister', 'Son', 'Daughter', 'Spouse', 'Other'];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _fullNameCtrl.text = e.fullName;
      _mobileCtrl.text = e.mobileNumber ?? '';
      _selectedDob = AppDateFormatter.dateFromString(e.dateOfBirth);
      if (_selectedDob != null) {
        _dobCtrl.text = AppDateFormatter.dateOnly(_selectedDob!);
      }
      _gender = e.gender.isNotEmpty ? e.gender.toLowerCase() : 'male';
      _relationship = e.relationship;
      _bloodGroup = e.bloodGroup;
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _mobileCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_relationship == null) {
      _showError('Please select a relationship');
      return;
    }
    if (_selectedDob == null) {
      _showError('Please choose a date of birth');
      return;
    }

    final member = FamilyMemberModel(
      id: widget.existing?.id,
      fullName: _fullNameCtrl.text.trim(),
      mobileNumber: _mobileCtrl.text.trim(),
      relationship: _relationship!,
      dateOfBirth: AppDateFormatter.dateForApi(_selectedDob!.toString()),
      gender: _gender,
      bloodGroup: _bloodGroup,
    );

    if (widget.existing != null) {
      context.read<FamilyBloc>().add(UpdateFamilyMember(member));
    } else {
      context.read<FamilyBloc>().add(AddFamilyMember(member));
    }
  }

  void _showError(String text) => MessageService.showError(text);

  bool _isDirty() {
    if (widget.existing == null) {
      return _fullNameCtrl.text.isNotEmpty || _mobileCtrl.text.isNotEmpty || _selectedDob != null || _relationship != null || _bloodGroup != null;
    }
    final e = widget.existing!;
    final currentDob = _selectedDob != null ? AppDateFormatter.dateForApi(_selectedDob!.toString()) : '';
    return _fullNameCtrl.text != e.fullName ||
        _mobileCtrl.text != (e.mobileNumber ?? '') ||
        currentDob != e.dateOfBirth ||
        _gender != e.gender.toLowerCase() ||
        _relationship != e.relationship ||
        _bloodGroup != e.bloodGroup;
  }

  Future<bool> _onWillPop() async {
    if (!_isDirty()) return true;

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kWhiteColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text('Unsaved Changes', style: kTextBold(color: kTextPrimaryColor)),
        content: Text('You have unsaved changes. Would you like to save them before leaving?', style: kTextNormal(color: kTextSecondaryColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 0),
            child: Text('Discard', style: kTextSemiBold(color: kErrorColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 1),
            child: Text('Save & Exit', style: kTextSemiBold(color: kPrimaryColor)),
          ),
        ],
      ),
    );

    if (result == 0) return true;
    if (result == 1) {
      _submit();
      return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    bool isEdit = widget.existing != null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: BlocListener<FamilyBloc, FamilyState>(
        listener: (context, state) {
          if (state is FamilyLoading) {
            setState(() => _isLoading = true);
          } else {
            setState(() => _isLoading = false);
          }

          if (state is FamilyActionSuccess) {
            Navigator.of(context).pop(true);
          } else if (state is FamilyError) {
            _showError(state.message);
          }
        },
        child: Scaffold(
          backgroundColor: kScaffoldColor,
          appBar: CustomAppBar(title: isEdit ? 'Edit Member' : 'Add Member', centerTitle: true, backgroundColor: kScaffoldColor),
          body: SafeArea(
            child: Stack(
              children: [
                // ── Top Background Accents ──
                Positioned(
                  top: -30.h,
                  right: -30.w,
                  child: Container(
                    width: 200.w,
                    height: 200.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [kPrimaryColor.withValues(alpha: 0.05), Colors.transparent]),
                    ),
                  ),
                ),

                Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 24.h),

                        Text('Member Details', style: kTextBold1(color: kTextPrimaryColor)),
                        SizedBox(height: 16.h),

                        CommonTextField(
                          controller: _fullNameCtrl,
                          labelText: 'Full Name',
                          isRequired: true,
                          keyboardType: TextInputType.name,
                          hintText: 'Enter full name',
                          prefixIcon: Icon(Icons.person_outline_rounded, color: kPrimaryColor, size: 18.sp),
                          // validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        SizedBox(height: 16.h),

                        CustomDropDown<String>(
                          labelText: 'Relationship',
                          hintText: 'Select Relationship',
                          isRequired: true,
                          borderRadius: 16.r,
                          value: _relationship,
                          items: _relationships.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value, style: kTextMedium(color: kTextPrimaryColor)),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _relationship = val),
                        ),
                        SizedBox(height: 16.h),
                        DatePickerTextField(
                          controller: _dobCtrl,
                          labelText: 'Date of Birth',
                          isRequired: true,
                          initialDate: _selectedDob,
                          lastDate: DateTime.now(),
                          onDateSelected: (date) {
                            setState(() {
                              _selectedDob = date;
                              _dobCtrl.text = AppDateFormatter.dateOnly(date);
                            });
                          },
                        ),
                        SizedBox(height: 16.h),
                        BlocBuilder<DropdownBloc, DropdownState>(
                          builder: (context, dropState) {
                            final dropdownData = dropState is DropdownLoaded ? dropState.data : null;
                            final items =
                                dropdownData?.bloodGroups ??
                                {'A+': 'A+', 'A-': 'A-', 'B+': 'B+', 'B-': 'B-', 'AB+': 'AB+', 'AB-': 'AB-', 'O+': 'O+', 'O-': 'O-'};
                            return CustomDropDown<String>(
                              labelText: 'Blood Group',
                              hintText: 'Select',
                              isRequired: false,
                              borderRadius: 16.r,
                              value: _bloodGroup,
                              items: mapToDropdownItems(items),
                              onChanged: (val) => setState(() => _bloodGroup = val),
                            );
                          },
                        ),

                        SizedBox(height: 24.h),
                        Text('Gender', style: kTextBold1(color: kTextPrimaryColor)),
                        SizedBox(height: 12.h),

                        _GenderSelector(selected: _gender, onSelect: (val) => setState(() => _gender = val)),

                        SizedBox(height: 24.h),
                        Text('Contact Information', style: kTextBold1(color: kTextPrimaryColor)),
                        SizedBox(height: 12.h),

                        CommonTextField(
                          controller: _mobileCtrl,
                          labelText: 'Mobile Number',
                          hintText: '10-digit mobile number',
                          isRequired: false,
                          keyboardType: TextInputType.phone,
                          isNumeric: true,
                          maxLength: 10,
                          prefixIcon: Icon(Icons.phone_iphone_rounded, color: kPrimaryColor, size: 18.sp),
                          validator: (v) {
                            if (v != null && v.isNotEmpty && v.length != 10) {
                              return 'Enter valid 10-digit number';
                            }
                            return null;
                          },
                        ),

                        SizedBox(height: 40.h),

                        ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            minimumSize: Size(double.infinity, 56.h),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 24.w,
                                  height: 24.w,
                                  child: const CircularProgressIndicator(color: kWhiteColor, strokeWidth: 2.5),
                                )
                              : Text(
                                  isEdit ? 'Update Details' : 'Save Details',
                                  style: kTextBold(color: kWhiteColor).copyWith(fontSize: 16.sp),
                                ),
                        ),

                        SizedBox(height: 48.h),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GenderSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _GenderSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const types = [
      {'key': 'male', 'label': 'Male', 'icon': Icons.male_rounded},
      {'key': 'female', 'label': 'Female', 'icon': Icons.female_rounded},
      {'key': 'other', 'label': 'Other', 'icon': Icons.transgender_rounded},
    ];

    return Row(
      children: types.map((t) {
        final sel = selected == t['key'];
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(t['key'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: sel ? kPrimaryColor : kGreyColor1.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: sel ? kPrimaryColor : kGreyColor2, width: 1.5),
                boxShadow: sel ? [BoxShadow(color: kPrimaryColor.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))] : [],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(t['icon'] as IconData, color: sel ? kWhiteColor : kTextSecondaryColor, size: 20.sp),
                  SizedBox(height: 4.h),
                  Text(
                    t['label'] as String,
                    style: kTextBold(color: sel ? kWhiteColor : kTextPrimaryColor).copyWith(fontSize: 12.sp),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
