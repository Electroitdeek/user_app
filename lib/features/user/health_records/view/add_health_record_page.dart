import 'dart:io';

import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_edge_insets.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/screen_dimensions.dart';
import '../../../../shared/widgets/buttons/custom_button.dart';
import '../../../../shared/widgets/dialogs/custom_bottom_sheets.dart';
import '../../../../shared/widgets/inputs/custom_drop_down.dart' show CustomDropDown;
import '../../../../shared/widgets/inputs/custom_text_field.dart';
import '../../family/model/family_member_model.dart';
import '../bloc/health_record_bloc.dart';
import '../model/health_record_model.dart';

class AddHealthRecordPage extends StatefulWidget {
  final List<FamilyMemberModel> familyMembers;
  final int? initialFamilyMemberId;

  const AddHealthRecordPage({super.key, required this.familyMembers, this.initialFamilyMemberId});

  @override
  State<AddHealthRecordPage> createState() => _AddHealthRecordPageState();
}

class _AddHealthRecordPageState extends State<AddHealthRecordPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _doctorController = TextEditingController();
  final _notesController = TextEditingController();
  final _dateController = TextEditingController();

  String _selectedType = kRecordTypes.first['value']!;
  DateTime _selectedDate = DateTime.now();
  File? _selectedFile;
  String? _fileName;

  /// null = "Me" (self)
  int? _selectedFamilyMemberId;

  @override
  void initState() {
    super.initState();
    _selectedFamilyMemberId = widget.initialFamilyMemberId;
    _dateController.text = DateFormat('dd MMM yyyy').format(_selectedDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _hospitalController.dispose();
    _doctorController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  // ── File Picker ───────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final file = await ChooseFileBottomSheet.show(showFiles: true, showCamera: true, showGallery: true);

    if (file != null) {
      // Validate extensions if needed, but the chooser handles it via the file picker mostly.
      // For camera/gallery it's jpg/png.

      // Enforce 10 MB max upload size.
      const maxBytes = 10 * 1024 * 1024;
      if (await file.length() > maxBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('File too large. Please choose a file under 10MB.'),
            backgroundColor: kErrorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() {
        _selectedFile = file;
        _fileName = file.path.split('/').last.split('\\').last;
      });
    }
  }

  // ── Navigate to FamilyAddEditPage and refresh members on return ───────────

  Future<void> _addFamilyMember() async {
    final result = await Navigator.of(context).pushNamed(AppRoutes.familyAddEdit);
    if (result == true && mounted) {
      // Dispatch event to bloc so the list page AND this page both get fresh members
      context.read<HealthRecordBloc>().add(HealthRecordRefreshFamilyMembers());
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please attach a document (report, prescription, etc.)'),
          backgroundColor: kErrorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    context.read<HealthRecordBloc>().add(
      HealthRecordSaveRequested(
        familyMemberId: _selectedFamilyMemberId,
        recordType: _selectedType,
        recordTitle: _titleController.text.trim(),
        recordDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
        hospitalName: _hospitalController.text.trim(),
        doctorName: _doctorController.text.trim(),
        notes: _notesController.text.trim(),
        documentFile: _selectedFile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HealthRecordBloc, HealthRecordState>(
      listener: (context, state) {
        if (state is HealthRecordSaveSuccess) {
          Navigator.pop(context);
        } else if (state is HealthRecordSaveFailure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: kErrorColor, behavior: SnackBarBehavior.floating));
        }
      },
      builder: (context, state) {
        final isSaving = state is HealthRecordSaving;

        // Get live family members from bloc state (auto-updates after refresh)
        final liveMembers = _resolveFamilyMembers(state) ?? widget.familyMembers;

        return PopScope(
          canPop: !isSaving,
          child: Scaffold(
            backgroundColor: kScaffoldColor,
            appBar: CustomAppBar(title: 'Add Health Record', centerTitle: true, backgroundColor: kScaffoldColor),
            body: SafeArea(
              child: Stack(
                children: [
                  Form(
                    key: _formKey,
                    child: ListView(
                      padding: AppPadding.symmetric(h: 16, v: 20),
                      children: [
                        // ─── 1. For Whom ───────────────────────────────────────────
                        _SectionHeader(icon: Icons.people_alt_rounded, title: 'Add Record For'),
                        AppSpacing.mVertical,
                        _ForWhomSelector(
                          familyMembers: liveMembers,
                          selectedId: _selectedFamilyMemberId,
                          onChanged: (id) => setState(() => _selectedFamilyMemberId = id),
                          onAddMember: _addFamilyMember,
                        ),

                        AppSpacing.xlVertical,

                        // ─── 2. Record Details Group ────────────────────────────────
                        Container(
                          padding: EdgeInsets.all(20.w),
                          decoration: BoxDecoration(
                            color: kWhiteColor,
                            borderRadius: BorderRadius.circular(20.r),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 8))],
                          ),
                          child: Column(
                            children: [
                              _SectionHeader(icon: Icons.assignment_rounded, title: 'Record Details'),
                              AppSpacing.lVertical,
                              CustomDropDown<String>(
                                labelText: 'Select Record Type',
                                hintText: 'Choose type',
                                isRequired: true,
                                value: _selectedType,
                                items: kRecordTypes.map((t) {
                                  return DropdownMenuItem<String>(
                                    value: t['value'],
                                    child: Row(
                                      children: [
                                        Text(t['icon']!, style: TextStyle(fontSize: 16.sp)),
                                        AppSpacing.sHorizontal,
                                        Text(t['label']!, style: kTextNormal1()),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _selectedType = v);
                                },
                              ),
                              AppSpacing.mVertical,
                              CustomTextField(
                                controller: _titleController,
                                labelText: 'Record Title',
                                hintText: 'e.g. Blood Test Report',
                                isRequired: true,
                                prefixIcon: Icon(Icons.title_rounded, size: 20.sp, color: kPrimaryColor),
                                textInputAction: TextInputAction.next,
                              ),
                              AppSpacing.mVertical,
                              DatePickerTextField(
                                controller: _dateController,
                                labelText: 'Record Date',
                                isRequired: true,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                                onDateSelected: (date) => setState(() => _selectedDate = date),
                              ),
                              AppSpacing.mVertical,
                              CustomTextField(
                                controller: _hospitalController,
                                labelText: 'Hospital / Clinic',
                                hintText: 'e.g. Apollo Hospital',
                                prefixIcon: Icon(Icons.local_hospital_rounded, size: 20.sp, color: kPrimaryColor),
                                textInputAction: TextInputAction.next,
                              ),
                              AppSpacing.mVertical,
                              CustomTextField(
                                controller: _doctorController,
                                labelText: 'Doctor Name',
                                hintText: 'e.g. Dr. Sharma',
                                prefixIcon: Icon(Icons.person_rounded, size: 20.sp, color: kPrimaryColor),
                                textInputAction: TextInputAction.next,
                              ),
                              AppSpacing.mVertical,
                              CustomTextField(
                                controller: _notesController,
                                labelText: 'Notes',
                                hintText: 'Any additional details...',
                                maxLines: 2,
                                prefixIcon: Icon(Icons.notes_rounded, size: 20.sp, color: kPrimaryColor),
                                textInputAction: TextInputAction.done,
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.xlVertical,

                        // ─── 4. Document Section ─────────────────────────────────────
                        Container(
                          padding: EdgeInsets.all(20.w),
                          decoration: BoxDecoration(
                            color: kWhiteColor,
                            borderRadius: BorderRadius.circular(20.r),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 8))],
                          ),
                          child: Column(
                            children: [
                              _SectionHeader(icon: Icons.attach_file_rounded, title: 'Attach Document'),
                              AppSpacing.lVertical,
                              _FilePickerCard(
                                fileName: _fileName,
                                onTap: _pickFile,
                                onRemove: () => setState(() {
                                  _selectedFile = null;
                                  _fileName = null;
                                }),
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.xxxlVertical,

                        // ─── Submit ────────────────────────────────────────────────
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          child: CustomButton(
                            onPressed: isSaving ? null : _submit,
                            title: 'Save Health Record',
                            isLoading: isSaving,
                            height: 56.h,
                            borderRadius: BorderRadius.circular(16.r),
                            width: double.infinity,
                          ),
                        ),
                        AppSpacing.lVertical,
                      ],
                    ),
                  ),
                  if (isSaving)
                    Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 24.h),
                          decoration: BoxDecoration(
                            color: kWhiteColor,
                            borderRadius: BorderRadius.circular(24.r),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 3),
                              SizedBox(height: 20.h),
                              Text(
                                'Saving Record',
                                style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 16.sp),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Please wait a moment...',
                                style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Extracts live family members from the current bloc state after a refresh
  List<FamilyMemberModel>? _resolveFamilyMembers(HealthRecordState s) => switch (s) {
    HealthRecordLoaded s => s.familyMembers,
    HealthRecordSaveSuccess s => s.loaded.familyMembers,
    HealthRecordSaving s => s.previousLoaded?.familyMembers,
    HealthRecordSaveFailure s => s.previousLoaded?.familyMembers,
    _ => null,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8.r)),
          child: Icon(icon, size: 16.sp, color: kPrimaryColor),
        ),
        SizedBox(width: 12.w),
        Text(
          title,
          style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 16.sp),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "For Whom" Selector — avatar row with "+ Add Member" at end
// ─────────────────────────────────────────────────────────────────────────────

class _ForWhomSelector extends StatelessWidget {
  final List<FamilyMemberModel> familyMembers;
  final int? selectedId;
  final ValueChanged<int?> onChanged;
  final VoidCallback onAddMember;

  const _ForWhomSelector({required this.familyMembers, required this.selectedId, required this.onChanged, required this.onAddMember});

  @override
  Widget build(BuildContext context) {
    final selected = selectedId == null ? null : familyMembers.where((m) => m.id == selectedId).firstOrNull;

    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SelectedBanner(member: selected),
          Divider(height: 1, color: kBorderColor.withValues(alpha: 0.4)),
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Patient',
                  style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
                ),
                SizedBox(height: 16.h),
                SizedBox(
                  height: 90.h,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _ForWhomChip(
                        initials: 'Me',
                        name: 'Self',
                        subLabel: 'Me',
                        color: kPrimaryColor,
                        isSelected: selectedId == null,
                        onTap: () => onChanged(null),
                      ),
                      ...familyMembers.asMap().entries.map((e) {
                        final m = e.value;
                        final colors = _chipColors;
                        final c = colors[e.key % colors.length];
                        return Padding(
                          padding: EdgeInsets.only(left: 12.w),
                          child: _ForWhomChip(
                            initials: _initials(m.fullName),
                            name: m.fullName.split(' ').first,
                            subLabel: m.relationship,
                            color: c,
                            isSelected: selectedId == m.id,
                            onTap: () => onChanged(m.id),
                          ),
                        );
                      }),
                      Padding(
                        padding: EdgeInsets.only(left: 12.w),
                        child: _AddMemberChip(onTap: onAddMember),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static const List<Color> _chipColors = [
    Color(0xFF6C63FF),
    Color(0xFF00BFA5),
    Color(0xFFFF6B6B),
    Color(0xFFFF9800),
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
  ];
}

class _SelectedBanner extends StatelessWidget {
  final FamilyMemberModel? member;

  const _SelectedBanner({this.member});

  @override
  Widget build(BuildContext context) {
    final name = member?.fullName ?? 'Me';
    final rel = member?.relationship ?? 'Self';
    final color = member == null ? kPrimaryColor : const Color(0xFF6C63FF);
    final initials = member == null ? 'Me' : _initials(name);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: kWhiteColor, width: 2),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Center(
              child: Text(
                initials,
                style: kTextBold(color: kWhiteColor).copyWith(fontSize: 14.sp),
              ),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 16.sp),
                ),
                Text(
                  rel,
                  style: kTextMedium(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(color: kSuccessColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20.r)),
            child: Row(
              children: [
                Icon(Icons.check_rounded, size: 14.sp, color: kSuccessColor),
                SizedBox(width: 6.w),
                Text(
                  'Active',
                  style: kTextBold(color: kSuccessColor).copyWith(fontSize: 10.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _ForWhomChip extends StatelessWidget {
  final String initials;
  final String name;
  final String subLabel;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ForWhomChip({
    required this.initials,
    required this.name,
    required this.subLabel,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastOutSlowIn,
        width: 64.w,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 54.w,
              height: 54.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : color.withValues(alpha: 0.08),
                border: Border.all(color: isSelected ? color : Colors.transparent, width: 2),
                boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
              ),
              child: Center(
                child: Text(
                  initials,
                  style: kTextBold(color: isSelected ? kWhiteColor : color).copyWith(fontSize: 14.sp),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              name,
              style: (isSelected ? kTextBold() : kTextMedium()).copyWith(
                fontSize: 10.sp,
                color: isSelected ? kTextPrimaryColor : kTextSecondaryColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMemberChip extends StatelessWidget {
  final VoidCallback onTap;

  const _AddMemberChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 54.w,
            height: 54.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kScaffoldColor,
              border: Border.all(color: kPrimaryColor.withValues(alpha: 0.3), width: 1.5, style: BorderStyle.solid),
            ),
            child: Icon(Icons.add_rounded, color: kPrimaryColor, size: 24.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            'New',
            style: kTextMedium(color: kPrimaryColor).copyWith(fontSize: 10.sp),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// File Picker Card
// ─────────────────────────────────────────────────────────────────────────────

class _FilePickerCard extends StatelessWidget {
  final String? fileName;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FilePickerCard({required this.fileName, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (fileName != null) {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: kSuccessColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: kSuccessColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(color: kSuccessColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.description_rounded, color: kSuccessColor, size: 20.sp),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Document Attached',
                    style: kTextBold(color: kSuccessColor).copyWith(fontSize: 14.sp),
                  ),
                  Text(
                    fileName!,
                    style: kTextMedium(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.08), shape: BoxShape.circle),
                child: Icon(Icons.close_rounded, color: kErrorColor, size: 18.sp),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 32.h),
        decoration: BoxDecoration(
          color: kScaffoldColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: kPrimaryColor.withValues(alpha: 0.2), width: 1.5, style: BorderStyle.solid),
        ),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 60.w,
                height: 60.w,
                decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(Icons.cloud_upload_rounded, color: kPrimaryColor, size: 28.sp),
              ),
              SizedBox(height: 16.h),
              Text(
                'Upload Medical Report',
                style: kTextBold(color: kPrimaryColor).copyWith(fontSize: 15.sp),
              ),
              SizedBox(height: 4.h),
              Text(
                'Supports PDF, JPG, PNG up to 10MB',
                style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
