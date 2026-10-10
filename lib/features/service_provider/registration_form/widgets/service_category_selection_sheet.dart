import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/data/models/dropdown_response_model.dart';
import 'package:adhisaat_health_care/shared/widgets/buttons/custom_button.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_cached_image.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ServiceCategorySelectionSheet extends StatefulWidget {
  final List<ServiceCategory> allCategories;
  final List<String> selectedIds;

  const ServiceCategorySelectionSheet({super.key, required this.allCategories, required this.selectedIds});

  static Future<List<String>?> showCategoryPicker(
    BuildContext context, {
    required List<ServiceCategory> allCategories,
    required List<String> selectedIds,
  }) async {
    return await showModalBottomSheet<List<String>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ServiceCategorySelectionSheet(allCategories: allCategories, selectedIds: selectedIds),
    );
  }

  @override
  State<ServiceCategorySelectionSheet> createState() => _ServiceCategorySelectionSheetState();
}

class _ServiceCategorySelectionSheetState extends State<ServiceCategorySelectionSheet> {
  late List<String> selectedIds;
  late TextEditingController _searchController;
  List<ServiceCategory> filteredCategories = [];
  final Set<String> expandedParents = {};

  @override
  void initState() {
    super.initState();
    selectedIds = List<String>.from(widget.selectedIds);
    _searchController = TextEditingController();
    filteredCategories = widget.allCategories;
  }

  void _onSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredCategories = widget.allCategories;
      });
      return;
    }

    final queryLower = query.toLowerCase();
    // Using Word Boundary regex to match only from the start of words
    final wordBoundaryRegex = RegExp('\\b${RegExp.escape(queryLower)}', caseSensitive: false);

    setState(() {
      filteredCategories = widget.allCategories
          .where(
            (c) =>
                wordBoundaryRegex.hasMatch(c.categoryName.toLowerCase()) ||
                (c.parentCategoryName?.toLowerCase().contains(queryLower) ?? false) ||
                c.services.any((s) => s.name.toLowerCase().contains(queryLower)),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Group all categories by parent name to determine total selected groups
    final totalGrouped = <String, List<ServiceCategory>>{};
    for (var cat in widget.allCategories) {
      final parent = cat.parentCategoryName ?? 'Other';
      totalGrouped.putIfAbsent(parent, () => []).add(cat);
    }

    int selectedParentCount = 0;
    totalGrouped.forEach((parent, items) {
      final serviceIds = items.expand((e) => e.services.map((s) => s.id.toString())).toList();
      if (serviceIds.isNotEmpty && serviceIds.every((id) => selectedIds.contains(id))) {
        selectedParentCount++;
      }
    });

    // Group only filtered categories for display
    final grouped = <String, List<ServiceCategory>>{};
    for (var cat in filteredCategories) {
      final parent = cat.parentCategoryName ?? 'Other';
      grouped.putIfAbsent(parent, () => []).add(cat);
    }

    return SafeArea(
      child: Container(
        height: 0.85.sh,
        decoration: const BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.symmetric(vertical: 12.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(color: kGreyColor3, borderRadius: BorderRadius.circular(2)),
            ),

            Padding(
              padding: AppPadding.symmetric(h: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text("Select Services", style: kTextSemiBold3(), overflow: TextOverflow.ellipsis),
                  ),
                  if (selectedIds.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => selectedIds.clear()),
                      child: Text("Clear All", style: kTextMedium(color: kPrimaryColor)),
                    ),
                ],
              ),
            ),

            // Search Box
            Padding(
              padding: AppPadding.symmetric(h: 20, v: 12),
              child: AppSearchField(
                controller: _searchController,
                onChanged: _onSearch,
                hintText: "Search services...",
              ),
            ),

            Expanded(
              child: widget.allCategories.isEmpty
                  ? Center(
                      child: Padding(
                        padding: AppPadding.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_off_rounded, size: 52.sp, color: kGreyColor3),
                            SizedBox(height: 16.h),
                            Text(
                              'No services available in your selected area',
                              style: kTextSemiBold1(color: kGreyColor6),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'Please go back and select a different location.',
                              style: kTextNormal0(color: kGreyColor6),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: AppPadding.symmetric(h: 20),
                      itemCount: grouped.length,
                      itemBuilder: (context, index) {
                        final parentName = grouped.keys.elementAt(index);
                        final items = grouped[parentName]!;
                        final serviceIds = items.expand((e) => e.services.map((s) => s.id.toString())).toList();
                        final allSelected =
                            serviceIds.isNotEmpty && serviceIds.every((id) => selectedIds.contains(id));
                        final hasSelection = serviceIds.any((id) => selectedIds.contains(id));
                        final firstItem = items.first;

                        // Calculate total sub-services (procedures) in this group
                        int totalSubServices = 0;
                        for (var item in items) {
                          totalSubServices += item.services.length;
                        }

                        final isExpanded = expandedParents.contains(parentName);

                        return Container(
                          margin: EdgeInsets.only(bottom: 12.h),
                          decoration: BoxDecoration(
                            color: hasSelection ? kPrimaryColor.withValues(alpha: 0.02) : kWhiteColor,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: allSelected
                                  ? kPrimaryColor
                                  : (hasSelection ? kPrimaryColor.withValues(alpha: 0.5) : kBorderColor),
                              width: hasSelection ? 1.5 : 1,
                            ),
                            boxShadow: [
                              if (hasSelection)
                                BoxShadow(
                                  color: kPrimaryColor.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Main Header Row - Click to select
                              InkWell(
                                borderRadius: isExpanded
                                    ? BorderRadius.vertical(top: Radius.circular(16.r))
                                    : BorderRadius.circular(16.r),
                                onTap: () {
                                  setState(() {
                                    if (allSelected) {
                                      selectedIds.removeWhere((id) => serviceIds.contains(id));
                                    } else {
                                      for (var id in serviceIds) {
                                        if (!selectedIds.contains(id)) {
                                          selectedIds.add(id);
                                        }
                                      }
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: AppPadding.symmetric(h: 12, v: 12),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10.r),
                                        child: firstItem.iconImageUrl != null
                                            ? AppCachedImage(
                                                imageUrl: firstItem.iconImageUrl!,
                                                width: 48.w,
                                                height: 48.w,
                                                fit: BoxFit.cover,
                                                errorWidgetBuilder: _PlaceholderIcon(parentName),
                                              )
                                            : _PlaceholderIcon(parentName),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(parentName, style: kTextSemiBold2()),
                                            SizedBox(height: 2.h),
                                            // Clickable Subtitle to expand/collapse only
                                            InkWell(
                                              onTap: () {
                                                setState(() {
                                                  if (expandedParents.contains(parentName)) {
                                                    expandedParents.remove(parentName);
                                                  } else {
                                                    expandedParents.add(parentName);
                                                  }
                                                });
                                              },
                                              borderRadius: BorderRadius.circular(4.r),
                                              child: Padding(
                                                padding: EdgeInsets.symmetric(vertical: 4.h),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        "$totalSubServices sub-services included",
                                                        style: kTextNormal0(color: kGreyColor6),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    SizedBox(width: 4.w),
                                                    Icon(
                                                      isExpanded
                                                          ? Icons.keyboard_arrow_up_rounded
                                                          : Icons.keyboard_arrow_down_rounded,
                                                      size: 16.sp,
                                                      color: kGreyColor6,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Checkbox(
                                        value: allSelected ? true : (hasSelection ? null : false),
                                        tristate: true,
                                        activeColor: kPrimaryColor,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.r)),
                                        onChanged: (val) {
                                          setState(() {
                                            if (allSelected) {
                                              selectedIds.removeWhere((id) => serviceIds.contains(id));
                                            } else {
                                              for (var id in serviceIds) {
                                                if (!selectedIds.contains(id)) {
                                                  selectedIds.add(id);
                                                }
                                              }
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Expanded Sub-services list
                              if (isExpanded)
                                Container(
                                  decoration: BoxDecoration(
                                    color: kGreyColor1,
                                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(16.r)),
                                  ),
                                  child: Column(
                                    children: items.expand((cat) => cat.services).map((service) {
                                      return Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
                                        child: Row(
                                          children: [
                                            if (service.iconImageUrl != null)
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(12.r),
                                                child: AppCachedImage(
                                                  imageUrl: service.iconImageUrl!,
                                                  width: 32.w,
                                                  height: 32.w,
                                                  fit: BoxFit.cover,
                                                  errorWidgetBuilder: _PlaceholderIcon(service.name, size: 32.w),
                                                ),
                                              )
                                            else
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(12.r),
                                                child: _PlaceholderIcon(service.name, size: 32.w),
                                              ),
                                            SizedBox(width: 12.w),
                                            Expanded(
                                              child: Text(service.name, style: kTextMedium0(color: kGreyColor8)),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            Padding(
              padding: AppPadding.all(12),
              child: CustomButton(
                width: double.infinity,
                title: "Confirm Selection ($selectedParentCount)",
                onPressed: () => Navigator.pop(context, selectedIds),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  final String name;
  final double? size;

  const _PlaceholderIcon(this.name, {this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size ?? 44.w,
      height: size ?? 44.w,
      color: kPrimaryColor.withValues(alpha: 0.1),
      child: Center(
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S', style: kTextBold1(color: kPrimaryColor)),
      ),
    );
  }
}
