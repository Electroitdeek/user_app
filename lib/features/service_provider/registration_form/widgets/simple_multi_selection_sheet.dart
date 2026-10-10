import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/shared/widgets/buttons/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SimpleMultiSelectionSheet extends StatefulWidget {
  final String title;
  final Map<String, String> options;
  final List<String> initialSelected;

  const SimpleMultiSelectionSheet({
    super.key,
    required this.title,
    required this.options,
    required this.initialSelected,
  });

  static Future<List<String>?> show({
    required BuildContext context,
    required String title,
    required Map<String, String> options,
    required List<String> initialSelected,
  }) async {
    return await showModalBottomSheet<List<String>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SimpleMultiSelectionSheet(
        title: title,
        options: options,
        initialSelected: initialSelected,
      ),
    );
  }

  @override
  State<SimpleMultiSelectionSheet> createState() => _SimpleMultiSelectionSheetState();
}

class _SimpleMultiSelectionSheetState extends State<SimpleMultiSelectionSheet> {
  late List<String> selectedValues;

  @override
  void initState() {
    super.initState();
    selectedValues = List<String>.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.symmetric(vertical: 12.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: kGreyColor3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: AppPadding.symmetric(h: 20),
              child: Row(
                children: [
                  Flexible(child: Text(widget.title, style: kTextSemiBold3(), overflow: TextOverflow.ellipsis)),
                  const Spacer(),
                  if (selectedValues.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => selectedValues.clear()),
                      child: Text("Clear All", style: kTextMedium(color: kPrimaryColor)),
                    ),
                ],
              ),
            ),

            const Divider(),

            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: AppPadding.symmetric(h: 12),
                children: widget.options.entries.map((entry) {
                  final isSelected = selectedValues.contains(entry.key);
                  return CheckboxListTile(
                    value: isSelected,
                    title: Text(entry.value, style: kTextMedium2()),
                    activeColor: kPrimaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          selectedValues.add(entry.key);
                        } else {
                          selectedValues.remove(entry.key);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),

            Padding(
              padding: AppPadding.all(16),
              child: CustomButton(
                width: double.infinity,
                title: "Confirm (${selectedValues.length})",
                onPressed: () => Navigator.pop(context, selectedValues),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
