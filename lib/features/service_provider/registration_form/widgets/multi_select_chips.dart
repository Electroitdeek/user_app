import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../data/models/dropdown_response_model.dart';

import '../../../../core/theme/screen_dimensions.dart';

class MultiSelectChips extends StatefulWidget {
  final dynamic options;
  final Function(List<String>) onSelectionChanged;
  final List<String> selectedChoices;

  const MultiSelectChips({
    super.key,
    required this.options,
    required this.onSelectionChanged,
    required this.selectedChoices,
  });

  @override
  State<MultiSelectChips> createState() => _MultiSelectChipsState();
}

class _MultiSelectChipsState extends State<MultiSelectChips> {
  late List<String> selectedChoices;

  @override
  void initState() {
    super.initState();
    selectedChoices = List<String>.from(widget.selectedChoices);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 10.w, runSpacing: 10.h, children: _buildChips());
  }

  List<Widget> _buildChips() {
    final options = widget.options;
    if (options is Map<String, String>) {
      return options.entries.map((data) => _buildSingleChip(data.key, data.value)).toList();
    } else if (options is List<String>) {
      return options.map((option) => _buildSingleChip(option, option)).toList();
    }
    return [];
  }

  Widget _buildSingleChip(String value, String label) {
    final isSelected = selectedChoices.contains(value);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            selectedChoices.remove(value);
          } else {
            selectedChoices.add(value);
          }
          widget.onSelectionChanged(selectedChoices);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: AppPadding.symmetric(h: 18, v: 12),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor : kWhiteColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? kPrimaryColor : kBorderColor, width: 1.5),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: kPrimaryColor.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                key: ValueKey(isSelected),
                size: 20.sp,
                color: isSelected ? kWhiteColor : kGreyColor6,
              ),
            ),
            SizedBox(width: 8.w),
            Text(label, style: kTextSemiBold1(color: isSelected ? kWhiteColor : kTextPrimaryColor)),
          ],
        ),
      ),
    );
  }
}

class CategorySelectionTile extends StatelessWidget {
  final List<String> selectedCategories;
  final List<ServiceCategory> allCategories;
  final VoidCallback onTap;

  const CategorySelectionTile({
    super.key,
    required this.selectedCategories,
    required this.allCategories,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Group ALL categories by parent to calculate true selection count
    final totalGrouped = <String, List<ServiceCategory>>{};
    for (var cat in allCategories) {
      final parent = cat.parentCategoryName ?? 'Other';
      totalGrouped.putIfAbsent(parent, () => []).add(cat);
    }

    final selectedParentNames = <String>[];
    totalGrouped.forEach((parent, items) {
      final serviceIds = items.expand((e) => e.services.map((s) => s.id.toString())).toList();
      if (serviceIds.isNotEmpty && serviceIds.any((id) => selectedCategories.contains(id))) {
        selectedParentNames.add(parent);
      }
    });

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: AppPadding.all(16),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorderColor, width: 1.2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: AppPadding.all(10),
                  decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.medical_services_rounded, color: kPrimaryColor, size: 24.sp),
                ),
                AppSpacing.mHorizontal,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Service Category", style: kTextMedium2()),
                      AppSpacing.xsVertical,
                      Text(
                        selectedCategories.isEmpty
                            ? "Select your services"
                            : "${selectedParentNames.length} categories selected",
                        style: kTextNormal(color: selectedCategories.isEmpty ? kGreyColor6 : kPrimaryColor),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: kGreyColor6, size: 28.sp),
              ],
            ),
            if (selectedParentNames.isNotEmpty) ...[
              AppSpacing.mVertical,
              const Divider(color: kBorderColor, height: 1),
              AppSpacing.mVertical,
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: selectedParentNames.map((name) {
                  return Container(
                    padding: AppPadding.symmetric(h: 12, v: 6),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: kPrimaryColor.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: kPrimaryColor, size: 14.sp),
                        SizedBox(width: 6.w),
                        Text(
                          name,
                          style: kTextMedium(color: kPrimaryColor).copyWith(fontSize: 12.sp),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MultiSelectDropdown extends StatefulWidget {
  final Map<String, String> options;
  final List<String> selectedChoices;
  final Function(List<String>) onSelectionChanged;
  final String hint;

  const MultiSelectDropdown({
    super.key,
    required this.options,
    required this.selectedChoices,
    required this.onSelectionChanged,
    this.hint = "Select duty types",
  });

  @override
  State<MultiSelectDropdown> createState() => _MultiSelectDropdownState();
}

class _MultiSelectDropdownState extends State<MultiSelectDropdown> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            constraints: BoxConstraints(minHeight: 60.h, maxHeight: 60.h),
            decoration: BoxDecoration(
              color: kScaffoldColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _isExpanded ? kPrimaryColor : kBorderColor, width: 1.5),
              boxShadow: _isExpanded
                  ? [
                      BoxShadow(
                        color: kPrimaryColor.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: widget.selectedChoices.isEmpty
                        ? Text(widget.hint, style: kTextNormal(color: kGreyColor6))
                        : Row(
                            children: widget.selectedChoices.map((choiceId) {
                              final label = widget.options[choiceId] ?? choiceId;
                              return Padding(
                                padding: EdgeInsets.only(right: 8.w),
                                child: SelectionChip(
                                  label: label,
                                  onRemove: () {
                                    final newList = List<String>.from(widget.selectedChoices)..remove(choiceId);
                                    widget.onSelectionChanged(newList);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: _isExpanded ? kPrimaryColor : kGreyColor6,
                  size: 24.sp,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded) ...[
          AppSpacing.sVertical,
          Material(
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            color: kWhiteColor,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 250.h),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(vertical: 8.h),
                itemCount: widget.options.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = widget.options.entries.elementAt(index);
                  final isSelected = widget.selectedChoices.contains(entry.key);
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: isSelected ? kPrimaryColor : kGreyColor3,
                      size: 22.sp,
                    ),
                    title: Text(
                      entry.value,
                      style: kTextMedium(color: isSelected ? kPrimaryColor : kTextPrimaryColor),
                    ),
                    onTap: () {
                      final newList = List<String>.from(widget.selectedChoices);
                      if (isSelected) {
                        newList.remove(entry.key);
                      } else {
                        newList.add(entry.key);
                      }
                      widget.onSelectionChanged(newList);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class SelectionChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const SelectionChip({super.key, required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: kTextMedium(color: kTextPrimaryColor)),
          SizedBox(width: 6.w),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 14.sp, color: kGreyColor6),
          ),
        ],
      ),
    );
  }
}

class GenericSelectionTile extends StatelessWidget {
  final String title;
  final String hint;
  final IconData icon;
  final int selectedCount;
  final VoidCallback onTap;

  const GenericSelectionTile({
    super.key,
    required this.hint,
    required this.icon,
    required this.selectedCount,
    required this.onTap,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: AppPadding.all(16),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorderColor, width: 1.2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: AppPadding.all(10),
              decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: kPrimaryColor, size: 24.sp),
            ),
            AppSpacing.mHorizontal,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: kTextMedium2()),
                  AppSpacing.xsVertical,
                  Text(
                    selectedCount == 0 ? hint : "$selectedCount selected",
                    style: kTextNormal(color: selectedCount == 0 ? kGreyColor6 : kPrimaryColor),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: kGreyColor6, size: 28.sp),
          ],
        ),
      ),
    );
  }
}
