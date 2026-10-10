import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/core/utils/message_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/shared_blocs/dropdown/dropdown_bloc.dart';
import '../../../../data/shared_blocs/dropdown/dropdown_state.dart';
import '../../../../shared/widgets/inputs/common_inputs.dart';
import '../../../../shared/widgets/inputs/custom_drop_down.dart' show CustomDropDown, mapToDropdownItems;
import '../bloc/family_bloc.dart';
import '../bloc/family_event.dart';
import '../bloc/family_state.dart';
import '../model/family_member_model.dart';

class FamilyAddEditBottomSheet extends StatelessWidget {
  final FamilyMemberModel? existing;

  const FamilyAddEditBottomSheet({super.key, this.existing});

  static Future<bool?> show(BuildContext context, {FamilyMemberModel? existing}) {
    final familyBloc = context.read<FamilyBloc>();
    final dropdownBloc = context.read<DropdownBloc>();

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: familyBloc),
          BlocProvider.value(value: dropdownBloc),
        ],
        child: FamilyAddEditBottomSheet(existing: existing),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _FamilyAddEditBottomSheetView(existing: existing);
  }
}

class _FamilyAddEditBottomSheetView extends StatefulWidget {
  final FamilyMemberModel? existing;

  const _FamilyAddEditBottomSheetView({this.existing});

  @override
  State<_FamilyAddEditBottomSheetView> createState() => _FamilyAddEditBottomSheetViewState();
}

class _FamilyAddEditBottomSheetViewState extends State<_FamilyAddEditBottomSheetView> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  DateTime? _selectedDob;
  int? _selectedDay;
  int? _selectedMonth;
  int? _selectedYear;
  bool _showDobError = false;

  String _gender = 'male';
  String? _relationship = 'Other';
  String? _bloodGroup;
  bool _isLoading = false;

  final List<String> _relationships = [
    'Father',
    'Mother',
    'Brother',
    'Sister',
    'Son',
    'Daughter',
    'Spouse',
    'Other',
  ];

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
        _selectedDay = _selectedDob!.day;
        _selectedMonth = _selectedDob!.month;
        _selectedYear = _selectedDob!.year;
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

  int _maxDaysInMonth(int month, int year) {
    if (month == 2) {
      final isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeapYear ? 29 : 28;
    }
    if (month == 4 || month == 6 || month == 9 || month == 11) {
      return 30;
    }
    return 31;
  }

  void _updateDob() {
    if (_selectedDay != null && _selectedMonth != null && _selectedYear != null) {
      int maxDays = _maxDaysInMonth(_selectedMonth!, _selectedYear!);
      if (_selectedDay! > maxDays) {
        _selectedDay = maxDays;
      }
      _selectedDob = DateTime(_selectedYear!, _selectedMonth!, _selectedDay!);
      _dobCtrl.text = AppDateFormatter.dateOnly(_selectedDob!);
      setState(() {
        _showDobError = false;
      });
    } else {
      _selectedDob = null;
      _dobCtrl.text = '';
    }
  }

  void _submit() {
    FocusScope.of(context).unfocus();

    setState(() {
      _showDobError = _selectedDob == null;
    });

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

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.existing != null;

    return BlocListener<FamilyBloc, FamilyState>(
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
      child: Container(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 60.h,
          maxHeight: MediaQuery.of(context).size.height,
        ),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -5)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: 12.h),
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(10)),
                ),
              ),

              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 12.w, 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isEdit ? 'Edit Member Details' : 'Add Member Details',
                        style: kTextBold2(color: kTextPrimaryColor),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: kTextPrimaryColor, size: 24.sp),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Scrollable Form Fields
              Expanded(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CommonTextField(
                                controller: _fullNameCtrl,
                                labelText: 'Full Name',
                                isRequired: true,
                                keyboardType: TextInputType.name,
                                hintText: 'Enter full name',
                                prefixIcon: Icon(Icons.person_outline_rounded, color: kPrimaryColor, size: 18.sp),
                              ),

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

                              SizedBox(height: 12.h),
                              Row(
                                children: [
                                  Text(
                                    'Date of Birth',
                                    style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
                                  ),
                                  Text(
                                    " *",
                                    style: kTextBold(color: Colors.red).copyWith(fontSize: 14.sp),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8.h),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: CustomDropDown<int>(
                                      hintText: 'DD',
                                      value: _selectedDay,
                                      borderRadius: 16.r,
                                      items:
                                          List.generate(
                                            _selectedMonth != null && _selectedYear != null
                                                ? _maxDaysInMonth(_selectedMonth!, _selectedYear!)
                                                : 31,
                                            (index) => index + 1,
                                          ).map((day) {
                                            return DropdownMenuItem<int>(
                                              value: day,
                                              child: Text(
                                                day.toString().padLeft(2, '0'),
                                                style: kTextMedium(
                                                  color: kTextPrimaryColor,
                                                ).copyWith(fontSize: 13.sp),
                                              ),
                                            );
                                          }).toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedDay = val;
                                          _updateDob();
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    flex: 1,
                                    child: CustomDropDown<int>(
                                      hintText: 'MMM  ',
                                      value: _selectedMonth,
                                      borderRadius: 16.r,
                                      items: List.generate(12, (index) => index + 1).map((month) {
                                        final monthNames = [
                                          'Jan',
                                          'Feb',
                                          'Mar',
                                          'Apr',
                                          'May',
                                          'Jun',
                                          'Jul',
                                          'Aug',
                                          'Sep',
                                          'Oct',
                                          'Nov',
                                          'Dec',
                                        ];
                                        return DropdownMenuItem<int>(
                                          value: month,
                                          child: Text(
                                            monthNames[month - 1],
                                            style: kTextMedium(color: kTextPrimaryColor).copyWith(fontSize: 13.sp),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedMonth = val;
                                          _updateDob();
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    flex: 1,
                                    child: CustomDropDown<int>(
                                      hintText: 'YYYY',
                                      value: _selectedYear,
                                      borderRadius: 16.r,
                                      items:
                                          List.generate(
                                            DateTime.now().year - 1900 + 1,
                                            (index) => DateTime.now().year - index,
                                          ).map((year) {
                                            return DropdownMenuItem<int>(
                                              value: year,
                                              child: Text(
                                                year.toString(),
                                                style: kTextMedium(
                                                  color: kTextPrimaryColor,
                                                ).copyWith(fontSize: 13.sp),
                                              ),
                                            );
                                          }).toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedYear = val;
                                          _updateDob();
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              if (_showDobError) ...[
                                SizedBox(height: 6.h),
                                Padding(
                                  padding: EdgeInsets.only(left: 4.w),
                                  child: Text(
                                    'Required',
                                    style: kTextNormal(color: Colors.red).copyWith(fontSize: 12.sp),
                                  ),
                                ),
                              ],

                              CustomDropDown<String>(
                                labelText: 'Gender',
                                hintText: 'Select Gender',
                                isRequired: true,
                                borderRadius: 16.r,
                                value: _gender == 'male' ? 'Male' : (_gender == 'female' ? 'Female' : 'Other'),
                                items: ['Male', 'Female', 'Other'].map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value, style: kTextMedium(color: kTextPrimaryColor)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _gender = val.toLowerCase();
                                    });
                                  }
                                },
                              ),

                              CommonTextField(
                                controller: _mobileCtrl,
                                labelText: 'Mobile Number (Optional)',
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

                              BlocBuilder<DropdownBloc, DropdownState>(
                                builder: (context, dropState) {
                                  final dropdownData = dropState is DropdownLoaded ? dropState.data : null;
                                  final items =
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
                                      };
                                  return CustomDropDown<String>(
                                    labelText: 'Blood Group (Optional)',
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
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          12.w,
                          12.h,
                          12.w,
                          12.h + MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: ElevatedButton(
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
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
