part of 'manage_categories_page.dart';

class _AddCategoryServiceBottomSheet extends StatefulWidget {
  final ManageCategoriesLoaded existing;

  const _AddCategoryServiceBottomSheet({required this.existing});

  @override
  State<_AddCategoryServiceBottomSheet> createState() => _AddCategoryServiceBottomSheetState();
}

class _AddCategoryServiceBottomSheetState extends State<_AddCategoryServiceBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return _AddSheetBody(manageCategoriesBloc: context.read<ManageCategoriesBloc>(), existing: widget.existing);
  }
}

class _AddSheetBody extends StatelessWidget {
  final ManageCategoriesBloc manageCategoriesBloc;
  final ManageCategoriesLoaded existing;

  const _AddSheetBody({required this.manageCategoriesBloc, required this.existing});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: 10.h, bottom: 4.h),
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(2.r)),
                ),
              ),
              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 12.w, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add Services', style: kTextBold2()),
                          BlocBuilder<ManageCategoriesBloc, ManageCategoriesState>(
                            bloc: manageCategoriesBloc,
                            builder: (_, s) {
                              int parentCount = 0;
                              if (s is ManageCategoriesLoaded && s.pendingAddIds.isNotEmpty) {
                                final selected = s.pendingAddIds;
                                final existingIds = s.existingCategoryIds;

                                // Group only available (non-existing) services to count correctly
                                final grouped = <String, List<int>>{};
                                for (final c in s.dropdownCategories) {
                                  if (existingIds.contains(c.id)) continue;
                                  final parent = c.fullCategoryName.isNotEmpty ? c.fullCategoryName : 'Other';
                                  grouped.putIfAbsent(parent, () => []).add(c.id);
                                }

                                // A parent is "selected" if all its available sub-services are selected
                                parentCount = grouped.values
                                    .where((ids) => ids.isNotEmpty && ids.every((id) => selected.contains(id)))
                                    .length;
                              }
                              return Text(
                                parentCount == 0 ? 'Tap services to select' : '$parentCount selected',
                                style: kTextNormal0(color: parentCount > 0 ? kPrimaryColor : kTextSecondaryColor),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        manageCategoriesBloc.add(ClearAddSelection());
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              Divider(color: kDividerColor, height: 16.h),
              // List
              Expanded(
                child: BlocBuilder<ManageCategoriesBloc, ManageCategoriesState>(
                  bloc: manageCategoriesBloc,
                  builder: (_, state) {
                    if (state is! ManageCategoriesLoaded) return const SizedBox.shrink();

                    // Filter out already-added services
                    final existingIds = state.existingCategoryIds;
                    final available = state.dropdownCategories.where((c) => !existingIds.contains(c.id)).toList();

                    if (available.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 48.sp,
                              color: kSuccessColor.withValues(alpha: 0.5),
                            ),
                            SizedBox(height: 12.h),
                            Text('All services added!', style: kTextBold1()),
                            Text(
                              'You have all available services.',
                              style: kTextNormal(color: kTextSecondaryColor),
                            ),
                          ],
                        ),
                      );
                    }

                    // Group available by parent
                    final grouped = <String, List<ServiceCategoryModel>>{};
                    for (final c in available) {
                      final parent = c.fullCategoryName;
                      grouped.putIfAbsent(parent, () => []).add(c);
                    }

                    final selected = state.pendingAddIds;
                    return ListView(
                      controller: scrollCtrl,
                      padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 100.h),
                      children: [
                        for (final entry in grouped.entries) ...[
                          _AddCategoryTile(
                            title: entry.key,
                            services: entry.value
                                .map((e) => SubServiceItem(
                                      name: e.categoryName,
                                      imageUrl: e.iconImageUrl,
                                      description: e.description,
                                    ))
                                .toList(),
                            imageUrl: entry.value.first.iconImageUrl,
                            description: entry.value.first.fullCategoryDescription,
                            isSelected: entry.value.every((c) => selected.contains(c.id)),
                            onTap: () {
                              final allIds = entry.value.map((c) => c.id).toList();
                              final isAlreadyAllSelected = entry.value.every((c) => selected.contains(c.id));
                              manageCategoriesBloc.add(ToggleMultipleAddSelection(allIds, !isAlreadyAllSelected));
                            },
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              // Confirm button
              BlocBuilder<ManageCategoriesBloc, ManageCategoriesState>(
                bloc: manageCategoriesBloc,
                builder: (_, s) {
                  final ids = s is ManageCategoriesLoaded ? s.pendingAddIds : <int>{};
                  final loading = s is ManageCategoriesLoaded && s.isActionLoading;
                  int parentCount = 0;
                  if (s is ManageCategoriesLoaded && s.pendingAddIds.isNotEmpty) {
                    final selected = s.pendingAddIds;
                    final existingIds = s.existingCategoryIds;

                    final grouped = <String, List<int>>{};
                    for (final c in s.dropdownCategories) {
                      if (existingIds.contains(c.id)) continue;
                      final parent = c.fullCategoryName.isNotEmpty ? c.fullCategoryName : 'Other';
                      grouped.putIfAbsent(parent, () => []).add(c.id);
                    }
                    parentCount = grouped.values
                        .where((ids) => ids.isNotEmpty && ids.every((id) => selected.contains(id)))
                        .length;
                  }
                  return Container(
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: kDividerColor)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: parentCount == 0 || loading
                            ? null
                            : () {
                                DialogHelper.showConfirmation(
                                  title: 'Confirm Enrollment',
                                  message:
                                      'Enrolling in new services will require your profile to be re-verified by the administrator to ensure quality standards.',
                                  confirmText: 'Enroll Now',
                                  cancelText: 'Cancel',
                                  onConfirm: () {
                                    manageCategoriesBloc.add(AddProviderCategories(ids.toList()));
                                    // Close dialog and sheet
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                  },
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: kButtonDisabledColor,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                        ),
                        child: loading
                            ? SizedBox(
                                width: 20.w,
                                height: 20.w,
                                child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                parentCount == 0
                                    ? 'Select services'
                                    : 'Add $parentCount service${parentCount == 1 ? '' : 's'}',
                                style: kTextSemiBold1(color: parentCount == 0 ? kTextHintColor : Colors.white),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCategoryTile extends StatelessWidget {
  final String title;
  final List<SubServiceItem> services;
  final String? imageUrl;
  final String? description;
  final bool isSelected;
  final VoidCallback onTap;

  const _AddCategoryTile({
    required this.title,
    required this.services,
    this.imageUrl,
    this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = kAccentColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.symmetric(vertical: 4.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: isSelected ? kPrimaryColor : kBorderColor, width: isSelected ? 1.5 : 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: kPrimaryColor.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Icon
            ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: Container(
                width: 64.w,
                height: 64.w,
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: color.withValues(alpha: 0.15)),
                ),
                child: imageUrl != null && imageUrl!.isNotEmpty
                    ? AppCachedImage(imageUrl: imageUrl!, width: 46.w, height: 46.w, fit: BoxFit.cover)
                    : _PlaceholderIcon(title),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: isSelected ? kTextSemiBold1(color: kPrimaryColor) : kTextSemiBold1(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 7.h),
                  // Service count + view button → opens detail sheet
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => SubServicesListSheet.showServices(
                      context,
                      title: title,
                      services: services,
                      imageUrl: imageUrl,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: kPrimaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.medical_services_outlined, size: 11.sp, color: kPrimaryColor),
                              SizedBox(width: 4.w),
                              Text(
                                '${services.length} service${services.length == 1 ? '' : 's'}',
                                style: kTextMedium(color: kPrimaryColor).copyWith(fontSize: 11.sp),
                              ),
                              SizedBox(width: 2.w),
                              Icon(Icons.keyboard_arrow_down_rounded, size: 15.sp, color: kPrimaryColor),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24.w,
              height: 24.w,
              decoration: BoxDecoration(
                color: isSelected ? kPrimaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(7.r),
                border: Border.all(color: isSelected ? kPrimaryColor : kBorderColor, width: 1.5),
              ),
              child: isSelected ? Icon(Icons.check_rounded, color: Colors.white, size: 15.sp) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  final String title;

  const _PlaceholderIcon(this.title);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44.w,
      height: 44.w,
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Center(
        child: Text(title.isNotEmpty ? title[0].toUpperCase() : 'S', style: kTextBold1(color: kPrimaryColor)),
      ),
    );
  }
}
