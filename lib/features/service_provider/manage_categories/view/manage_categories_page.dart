import 'dart:math' as math;

import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/message_service.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/service_provider/manage_categories/bloc/manage_categories_bloc.dart';
import 'package:adhisaat_health_care/features/service_provider/manage_categories/model/provider_category_model.dart';
import 'package:adhisaat_health_care/features/service_provider/manage_categories/view/sub_services_list_sheet.dart';
import 'package:adhisaat_health_care/features/user/service_booking/model/service_category_model.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_cached_image.dart';
import 'package:adhisaat_health_care/shared/widgets/common/custom_refresh_indicator.dart';
import 'package:adhisaat_health_care/shared/widgets/dialogs/dialog_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

part 'add_category_service_bottom_sheet.dart';

class ManageCategoriesPage extends StatelessWidget {
  const ManageCategoriesPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ManageCategoriesBloc(locator<ApiClient>())..add(LoadProviderCategories()),
    child: const _ManageCategoriesView(),
  );
}

// ─────────────────────────────────────────────────────────────────
// Main view
// ─────────────────────────────────────────────────────────────────
class _ManageCategoriesView extends StatelessWidget {
  const _ManageCategoriesView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScaffoldColor,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: BlocConsumer<ManageCategoriesBloc, ManageCategoriesState>(
          buildWhen: (p, c) {
            // Only rebuild on loading and loaded states to preserve error/success messages
            if (c is ManageCategoriesLoading || c is ManageCategoriesLoaded) {
              return true;
            }
            return false;
          },
          listener: (context, state) {
            if (state is ManageCategoriesLoaded && state.successMessage != null) {
              MessageService.showSuccess(state.successMessage!);
            }
            if (state is ManageCategoriesError) {
              MessageService.showError(state.message);
            }
            if (state is DeleteCategoriesError) {
              MessageService.showError(state.message);
            }
          },
          builder: (context, state) => switch (state) {
            ManageCategoriesLoading() || ManageCategoriesInitial() => const _ShimmerList(),
            ManageCategoriesLoaded() => _LoadedBody(state: state),
            ManageCategoriesError(:final message) => _ErrorView(
              message: message,
              onRetry: () => context.read<ManageCategoriesBloc>().add(LoadProviderCategories()),
            ),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
      floatingActionButton: BlocBuilder<ManageCategoriesBloc, ManageCategoriesState>(
        builder: (context, state) {
          if (state is! ManageCategoriesLoaded) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: () => _showAddSheet(context, state),
            backgroundColor: kPrimaryColor,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Text('Add Service', style: kTextSemiBold(color: Colors.white)),
            elevation: 3,
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) => AppBar(
    backgroundColor: kScaffoldColor,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    leading: IconButton(
      icon: Icon(Icons.arrow_back_ios_new, size: 18.sp),
      onPressed: () => Navigator.pop(context),
    ),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Services', style: kTextBold2()),
        BlocBuilder<ManageCategoriesBloc, ManageCategoriesState>(
          builder: (_, state) {
            final count = state is ManageCategoriesLoaded ? state.grouped.length : 0;
            return Text(
              '$count service${count == 1 ? '' : 's'} enrolled',
              style: kTextNormal0(color: kTextSecondaryColor),
            );
          },
        ),
      ],
    ),
    actions: [
      IconButton(
        icon: Icon(Icons.refresh_rounded, color: kPrimaryColor, size: 22.sp),
        onPressed: () => context.read<ManageCategoriesBloc>().add(LoadProviderCategories()),
        tooltip: 'Refresh',
      ),
      SizedBox(width: 4.w),
    ],
    // bottom: PreferredSize(
    //   preferredSize: const Size.fromHeight(1),
    //   child: Container(color: kDividerColor, height: 1),
    // ),
    systemOverlayStyle: SystemUiOverlayStyle.dark,
  );

  void _showAddSheet(BuildContext context, ManageCategoriesLoaded state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<ManageCategoriesBloc>(),
        child: _AddCategoryServiceBottomSheet(existing: state),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Loaded body — grouped list
// ─────────────────────────────────────────────────────────────────
class _LoadedBody extends StatelessWidget {
  final ManageCategoriesLoaded state;

  const _LoadedBody({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.categories.isEmpty) return const _EmptyView();

    final grouped = state.grouped;
    final groups = grouped.entries.toList();

    return CustomRefreshIndicator(
      onRefresh: () async => context.read<ManageCategoriesBloc>().add(LoadProviderCategories()),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: 12.h)),
          // Warning Notice
          const SliverToBoxAdapter(child: _WarningNotice()),
          // Summary chips
          // SliverToBoxAdapter(child: _SummaryRow(state: state)),
          SliverToBoxAdapter(child: SizedBox(height: 16.h)),
          // Grouped parent categories
          for (final group in groups) ...[
            SliverToBoxAdapter(
              child: _CategoryCard(title: group.key, items: group.value, isLoading: state.isActionLoading),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 8.h)),
          ],
          // FAB clearance
          SliverToBoxAdapter(child: SizedBox(height: 80.h)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Warning Notice
// ─────────────────────────────────────────────────────────────────
class _WarningNotice extends StatelessWidget {
  const _WarningNotice();

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFF59E0B);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(7.w),
            decoration: BoxDecoration(color: amber.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(Icons.priority_high_rounded, color: const Color(0xFFB45309), size: 16.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Re-verification required', style: kTextSemiBold1(color: const Color(0xFFB45309))),
                SizedBox(height: 3.h),
                Text(
                  'Any change to your enrolled services will send your profile for admin re-verification.',
                  style: kTextNormal0(color: const Color(0xFF92700E)).copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Summary row
// ─────────────────────────────────────────────────────────────────
// class _SummaryRow extends StatelessWidget {
//   final ManageCategoriesLoaded state;
//
//   const _SummaryRow({required this.state});
//
//   @override
//   Widget build(BuildContext context) {
//     final emergency = state.categories.where((c) => c.serviceCategory.isEmergency).length;
//     final regular = state.categories.length - emergency;
//
//     return Padding(
//       padding: EdgeInsets.symmetric(horizontal: 16.w),
//       child: Row(
//         children: [
//           _SummaryChip(label: '$regular Regular', icon: Icons.medical_services_outlined, color: kPrimaryColor),
//           SizedBox(width: 10.w),
//           _SummaryChip(label: '$emergency Emergency', icon: Icons.emergency_rounded, color: kErrorColor),
//         ],
//       ),
//     );
//   }
// }

// class _SummaryChip extends StatelessWidget {
//   final String label;
//   final IconData icon;
//   final Color color;
//
//   const _SummaryChip({required this.label, required this.icon, required this.color});
//
//   @override
//   Widget build(BuildContext context) => Container(
//     padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
//     decoration: BoxDecoration(
//       color: color.withValues(alpha: 0.08),
//       borderRadius: BorderRadius.circular(20.r),
//       border: Border.all(color: color.withValues(alpha: 0.2)),
//     ),
//     child: Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Icon(icon, size: 13.sp, color: color),
//         SizedBox(width: 5.w),
//         Text(label, style: kTextSemiBold0(color: color)),
//       ],
//     ),
//   );
// }

// ─────────────────────────────────────────────────────────────────
// Category card with swipe-to-delete
// ─────────────────────────────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  final String title;
  final List<ProviderCategoryItem> items;
  final bool isLoading;

  const _CategoryCard({required this.title, required this.items, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final firstItem = items.first.serviceCategory;
    final isEmergency = firstItem.isEmergency;
    final categoryIds = items.map((e) => e.serviceCategoryId).toList();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      child: Dismissible(
        key: Key('group_$title'),
        direction: DismissDirection.endToStart,
        background: _SwipeBackground(),
        confirmDismiss: (_) => _confirmDelete(context),
        onDismissed: (_) =>
            context.read<ManageCategoriesBloc>().add(DeleteProviderCategory(serviceCategoryIds: categoryIds)),
        child: Container(
          decoration: BoxDecoration(
            color: isEmergency ? const Color(0xFFFFF5F5) : Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: isEmergency ? kErrorColor.withValues(alpha: 0.25) : kBorderColor),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showServices(context),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon / image — larger, framed
                  _CategoryIcon(iconUrl: firstItem.iconImageUrl, isEmergency: isEmergency),
                  SizedBox(width: 14.w),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(title, style: kTextBold1(), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        // Sub-service count box → opens service list sheet
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                            decoration: BoxDecoration(
                              color: kPrimaryColor.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: kPrimaryColor.withValues(alpha: 0.20)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.list_alt_rounded, size: 15.sp, color: kPrimaryColor),
                                SizedBox(width: 6.w),
                                Flexible(
                                  child: Text(
                                    '${items.length} service${items.length == 1 ? '' : 's'}',
                                    style: kTextSemiBold0(color: kPrimaryColor).copyWith(fontSize: 12.sp),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 2.w),
                                Icon(Icons.keyboard_arrow_down_rounded, size: 17.sp, color: kPrimaryColor),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Delete button
                  IconButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final ok = await _confirmDelete(context);
                            if (ok == true && context.mounted) {
                              context.read<ManageCategoriesBloc>().add(
                                DeleteProviderCategory(serviceCategoryIds: categoryIds),
                              );
                            }
                          },
                    icon: Icon(Icons.delete_outline_rounded, color: kErrorColor.withValues(alpha: 0.8), size: 22.sp),
                    style: IconButton.styleFrom(
                      backgroundColor: kErrorColor.withValues(alpha: 0.07),
                      padding: EdgeInsets.all(8.w),
                    ),
                    constraints: const BoxConstraints(),
                    tooltip: 'Remove all',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showServices(BuildContext context) {
    final cat = items.first.serviceCategory;
    SubServicesListSheet.showServices(
      context,
      title: title,
      services: items
          .map((e) => SubServiceItem(
                name: e.service.name,
                imageUrl: e.service.iconImageUrl ?? e.service.image,
                description: _stripHtml(e.service.description),
              ))
          .toList(),
      imageUrl: cat.iconImageUrl,
      description: _stripHtml(cat.description),
    );
  }

  String? _stripHtml(String? html) {
    if (html == null || html.trim().isEmpty) return null;
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  Future<bool?> _confirmDelete(BuildContext context) => DialogHelper.showConfirmation(
    title: 'Unenroll from Service?',
    message:
        'Important: Changing your enrolled services will require your profile to be re-verified by the administrator.\n\nAre you sure you want to unenroll from "$title" and all its associated sub-services?',
    confirmText: 'Unenroll',
    cancelText: 'Cancel',
    isDangerous: true,
  );
}

class _CategoryIcon extends StatelessWidget {
  final String? iconUrl;
  final bool isEmergency;

  const _CategoryIcon({this.iconUrl, required this.isEmergency});

  @override
  Widget build(BuildContext context) {
    final color = isEmergency ? kErrorColor : kAccentColor;
    return Container(
      width: 64.w,
      height: 64.w,
      padding: EdgeInsets.all(2.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: iconUrl != null && iconUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(11.r),
              child: AppCachedImage(imageUrl: iconUrl!, width: 52.w, height: 52.w, fit: BoxFit.cover),
            )
          : Icon(
              isEmergency ? Icons.emergency_rounded : Icons.medical_services_rounded,
              color: color,
              size: 30.sp,
            ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.centerRight,
    padding: EdgeInsets.only(right: 20.w),
    decoration: BoxDecoration(
      color: kErrorColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14.r),
      border: Border.all(color: kErrorColor.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.delete_outline_rounded, color: kErrorColor, size: 22.sp),
        SizedBox(width: 6.w),
        Text('Remove', style: kTextSemiBold(color: kErrorColor)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(32.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90.w,
            height: 90.w,
            decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(Icons.add_business_rounded, size: 40.sp, color: kPrimaryColor.withValues(alpha: 0.5)),
          ),
          SizedBox(height: 20.h),
          Text('No Services Yet', style: kTextBold2()),
          SizedBox(height: 8.h),
          Text(
            'Add the services you offer so patients can find you and book appointments.',
            style: kTextNormal(color: kTextSecondaryColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48.sp, color: kErrorColor.withValues(alpha: 0.5)),
          SizedBox(height: 16.h),
          Text('Failed to load', style: kTextBold1()),
          SizedBox(height: 8.h),
          Text(
            message,
            style: kTextNormal(color: kTextSecondaryColor),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
// Shimmer skeleton
// ─────────────────────────────────────────────────────────────────
class _ShimmerList extends StatefulWidget {
  const _ShimmerList();

  @override
  State<_ShimmerList> createState() => _ShimmerListState();
}

class _ShimmerListState extends State<_ShimmerList> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _anim = Tween<double>(begin: -1, end: 2).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box(double w, double h, {double? radius, bool circle = false}) => AnimatedBuilder(
    animation: _anim,
    builder: (_, _) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius ?? 8.r),
        gradient: LinearGradient(
          stops: [
            math.max(0, _anim.value - 0.3).clamp(0.0, 1.0).toDouble(),
            _anim.value.clamp(0.0, 1.0),
            math.min(1, _anim.value + 0.3).clamp(0.0, 1.0).toDouble(),
          ],
          colors: const [Color(0xFFEEEEEE), Color(0xFFF8F8F8), Color(0xFFEEEEEE)],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: EdgeInsets.all(12.w),
    itemCount: 6,
    itemBuilder: (_, i) => Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: kBorderColor),
        ),
        child: Row(
          children: [
            _box(44.w, 44.w, radius: 10.r),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(140.w, 14.h),
                  SizedBox(height: 8.h),
                  _box(100.w, 12.h),
                ],
              ),
            ),
            _box(28.w, 28.w, circle: true),
          ],
        ),
      ),
    ),
  );
}
