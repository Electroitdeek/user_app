import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/shared/widgets/inputs/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/screen_dimensions.dart';

class SkillsInputField extends HookWidget {
  final ValueNotifier<List<String>> selectedSkills;
  final List<String> suggestions;

  const SkillsInputField({
    super.key,
    required this.selectedSkills,
    required this.suggestions,
  });

  @override
  Widget build(BuildContext context) {
    final textController = useTextEditingController();
    final focusNode = useFocusNode();
    final hasFocus = useState(false);
    final query = useState('');

    // Create a GlobalKey to track the suggestions container for auto-scrolling
    final suggestionsBoxKey = useMemoized(() => GlobalKey());

    useEffect(() {
      void focusListener() => hasFocus.value = focusNode.hasFocus;
      void textListener() => query.value = textController.text;
      focusNode.addListener(focusListener);
      textController.addListener(textListener);
      return () {
        focusNode.removeListener(focusListener);
        textController.removeListener(textListener);
      };
    }, [focusNode, textController]);

    final filteredSuggestions = useMemoized(() {
      final q = query.value.toLowerCase();
      if (q.isEmpty) return <String>[];
      return suggestions
          .where((s) => s.toLowerCase().contains(q))
          .where((s) => !selectedSkills.value.contains(s))
          .toList();
    }, [query.value, selectedSkills.value, suggestions]);

    // Auto-scroll logic: triggers whenever suggestions appear
    final showSuggestions = filteredSuggestions.isNotEmpty && hasFocus.value;
    useEffect(() {
      if (showSuggestions) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (suggestionsBoxKey.currentContext != null) {
            Scrollable.ensureVisible(
              suggestionsBoxKey.currentContext!,
              alignment: 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
      return null;
    }, [showSuggestions]);

    // Common skills for "Quick Add"
    final quickAddSkillsList = useMemoized(() {
      return suggestions
          .where((s) => !selectedSkills.value.contains(s))
          .take(15)
          .toList();
    }, [selectedSkills.value, suggestions]);

    void addSkill(String skill) {
      final s = skill.trim();
      if (s.isEmpty) return;
      if (!selectedSkills.value.contains(s)) {
        selectedSkills.value = [...selectedSkills.value, s];
      }
      textController.clear();
      query.value = '';
      focusNode.requestFocus();
    }

    return TapRegion(
      onTapOutside: (event) {
        focusNode.unfocus();
        hasFocus.value = false;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Selected Skills Wrap ──
          if (selectedSkills.value.isNotEmpty) ...[
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: selectedSkills.value.map((skill) {
                return _SkillChip(
                  skill: skill,
                  onDeleted: () {
                    selectedSkills.value =
                        selectedSkills.value.where((s) => s != skill).toList();
                  },
                );
              }).toList(),
            ),
            AppSpacing.mVertical,
          ],

          // ── Input Field ──
          CustomTextField(
            controller: textController,
            focusNode: focusNode,
            hintText: 'Search or add skills...',
            prefixIcon: Icon(Icons.psychology_outlined, color: kGreyColor6),
            suffixIcon: query.value.isNotEmpty
                ? IconButton(
                    onPressed: () => addSkill(query.value),
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      color: kPrimaryColor,
                    ),
                  )
                : null,
            onFieldSubmitted: (val) => addSkill(val),
          ),

          // ── Suggestions List (Visual Dropdown) ──
          if (showSuggestions) ...[
            AppSpacing.sVertical,
            Container(
              key: suggestionsBoxKey,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: Border.all(color: kGreyColor2),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 220.h),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) => true,
                  child: ListView.separated(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: filteredSuggestions.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Color(0xFFF8F8F8)),
                    itemBuilder: (context, index) {
                      final option = filteredSuggestions[index];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: Icon(
                          Icons.add_task_rounded,
                          color: kPrimaryColor,
                          size: 18.sp,
                        ),
                        title: Text(
                          option,
                          style: kTextNormal1(color: kTextPrimaryColor),
                        ),
                        onTap: () => addSkill(option),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],

          // ── Quick Add (Top Skills Suggestions) ──
          if (query.value.isEmpty && quickAddSkillsList.isNotEmpty) ...[
            AppSpacing.mVertical,
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 14.sp,
                  color: kPrimaryColor,
                ),
                SizedBox(width: 6.w),
                Text(
                  'Suggested Skills',
                  style: kTextSemiBold0(color: kGreyColor7),
                ),
              ],
            ),
            AppSpacing.sVertical,
            SizedBox(
              height: 40.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: quickAddSkillsList.length,
                separatorBuilder: (_, _) => SizedBox(width: 10.w),
                itemBuilder: (context, index) {
                  final skill = quickAddSkillsList[index];
                  return ActionChip(
                    label: Text(skill),
                    labelStyle: kTextNormal0(color: kGreyColor8),
                    backgroundColor: kGreyColor1,
                    onPressed: () => addSkill(skill),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    side: BorderSide(color: kGreyColor3, width: 0.5),
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String skill;
  final VoidCallback onDeleted;

  const _SkillChip({required this.skill, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kPrimaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(skill, style: kTextNormal0(color: kPrimaryColor)),
          SizedBox(width: 4.w),
          GestureDetector(
            onTap: onDeleted,
            child: Icon(Icons.close, size: 14.sp, color: kPrimaryColor),
          ),
        ],
      ),
    );
  }
}
