import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/shared/widgets/buttons/custom_button.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SkillsSelectionSheet extends StatefulWidget {
  final List<String> suggestions;
  final List<String> initialSelected;

  const SkillsSelectionSheet({super.key, required this.suggestions, required this.initialSelected});

  static Future<List<String>?> show({
    required BuildContext context,
    required List<String> suggestions,
    required List<String> initialSelected,
  }) {
    return showModalBottomSheet<List<String>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SkillsSelectionSheet(suggestions: suggestions, initialSelected: initialSelected),
    );
  }

  @override
  State<SkillsSelectionSheet> createState() => _SkillsSelectionSheetState();
}

class _SkillsSelectionSheetState extends State<SkillsSelectionSheet> {
  late List<String> _selected;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.initialSelected);
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle(String skill) {
    setState(() {
      if (_selected.contains(skill)) {
        _selected.remove(skill);
      } else {
        _selected.add(skill);
      }
    });
  }

  void _addCustom() {
    final skill = _query;
    if (skill.isEmpty) return;
    setState(() {
      if (!_selected.contains(skill)) _selected.add(skill);
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.suggestions
        .where((s) => _query.isEmpty || s.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    final showAddCustom =
        _query.isNotEmpty &&
        !widget.suggestions.any((s) => s.toLowerCase() == _query.toLowerCase()) &&
        !_selected.any((s) => s.toLowerCase() == _query.toLowerCase());

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: kWhiteColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: EdgeInsets.symmetric(vertical: 12.h),
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(color: kGreyColor3, borderRadius: BorderRadius.circular(2)),
                ),

                // Title row
                Padding(
                  padding: AppPadding.symmetric(h: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Select Skills',
                          style: kTextSemiBold3(),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (_selected.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() => _selected.clear()),
                          child: Text('Clear All', style: kTextMedium(color: kPrimaryColor)),
                        ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                Padding(
                  padding: AppPadding.symmetric(h: 16, v: 12),
                  child: AppSearchField(
                    controller: _searchController,
                    hintText: 'Search or type a custom skill...',
                    suffixIcon: showAddCustom
                        ? GestureDetector(
                            onTap: _addCustom,
                            child: Container(
                              margin: EdgeInsets.all(8.r),
                              padding: EdgeInsets.symmetric(horizontal: 10.w),
                              decoration: BoxDecoration(
                                color: kPrimaryColor,
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Center(
                                widthFactor: 1,
                                child: Text('Add', style: kTextSemiBold0(color: kWhiteColor)),
                              ),
                            ),
                          )
                        : null,
                  ),
                ),

                // Selected chips strip (if any)
                if (_selected.isNotEmpty) ...[
                  SizedBox(
                    height: 38.h,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      itemCount: _selected.length,
                      separatorBuilder: (_, _) => SizedBox(width: 8.w),
                      itemBuilder: (_, i) {
                        final skill = _selected[i];
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: kPrimaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(color: kPrimaryColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(skill, style: kTextNormal0(color: kPrimaryColor)),
                              SizedBox(width: 4.w),
                              GestureDetector(
                                onTap: () => _toggle(skill),
                                child: Icon(Icons.close, size: 14.sp, color: kPrimaryColor),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 8.h),
                  const Divider(height: 1),
                ],

                // Skills grid
                Expanded(
                  child: filtered.isEmpty && !showAddCustom
                      ? Center(
                          child: Text('No skills found', style: kTextNormal(color: kGreyColor6)),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: AppPadding.symmetric(h: 16, v: 12),
                          itemCount: filtered.length + (showAddCustom ? 1 : 0),
                          separatorBuilder: (context, index) => SizedBox(height: 10.h),
                          itemBuilder: (context, index) {
                            if (showAddCustom && index == 0) {
                              return _SkillTile(
                                label: '+ Add "$_query"',
                                isSelected: false,
                                isCustom: true,
                                onTap: _addCustom,
                              );
                            }
                            final skill = filtered[showAddCustom ? index - 1 : index];
                            return _SkillTile(
                              label: skill,
                              isSelected: _selected.contains(skill),
                              onTap: () => _toggle(skill),
                            );
                          },
                        ),
                ),

                // Confirm button
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h + MediaQuery.of(context).viewInsets.bottom),
                  child: CustomButton(
                    width: double.infinity,
                    title: _selected.isEmpty ? 'Confirm' : 'Confirm (${_selected.length})',
                    onPressed: () => Navigator.pop(context, _selected),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SkillTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isCustom;
  final VoidCallback onTap;

  const _SkillTile({required this.label, required this.isSelected, required this.onTap, this.isCustom = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor.withValues(alpha: 0.04) : kWhiteColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? kPrimaryColor.withValues(alpha: 0.4) : kBorderColor,
            width: 1.2,
          ),
          boxShadow: [
            if (!isSelected && !isCustom)
              BoxShadow(
                color: kGreyColor2.withValues(alpha: 0.5),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: isSelected
                    ? kPrimaryColor
                    : isCustom
                        ? kAccentColor.withValues(alpha: 0.1)
                        : kGreyColor1,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCustom
                    ? Icons.add_rounded
                    : isSelected
                        ? Icons.check_rounded
                        : Icons.medical_services_outlined,
                color: isSelected
                    ? kWhiteColor
                    : isCustom
                        ? kAccentColor
                        : kGreyColor6,
                size: 20.sp,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: isSelected
                        ? kTextBold1(color: kPrimaryColor)
                        : kTextSemiBold1(color: kTextPrimaryColor),
                  ),
                  if (isCustom) ...[
                    SizedBox(height: 2.h),
                    Text('Tap to add custom skill', style: kTextNormal(color: kAccentColor).copyWith(fontSize: 12.sp)),
                  ],
                ],
              ),
            ),
            if (!isCustom)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24.w,
                height: 24.w,
                decoration: BoxDecoration(
                  color: isSelected ? kPrimaryColor : kWhiteColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? kPrimaryColor : kGreyColor4,
                    width: isSelected ? 0 : 1.5,
                  ),
                ),
                child: isSelected
                    ? Icon(Icons.check_rounded, size: 16.sp, color: kWhiteColor)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
