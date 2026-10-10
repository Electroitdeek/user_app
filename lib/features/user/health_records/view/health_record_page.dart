import 'package:adhisaat_health_care/core/utils/message_service.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/file_downloading_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_edge_insets.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/screen_dimensions.dart';
import '../../../../core/utils/number_utils.dart';
import '../../../../di/locator.dart';
import '../../../../shared/widgets/buttons/custom_button.dart';
import '../../../../shared/widgets/dialogs/dialog_helpers.dart';
import '../../../../shared/widgets/shimmer/user_shimmers.dart';
import '../../family/data/family_repository.dart';
import '../../family/model/family_member_model.dart';
import '../bloc/health_record_bloc.dart';
import '../data/health_record_repository.dart';
import '../model/health_record_model.dart';
import 'add_health_record_page.dart';

class HealthRecordsListPage extends StatelessWidget {
  const HealthRecordsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HealthRecordBloc>(
      create: (_) =>
          HealthRecordBloc(healthRepo: locator<HealthRecordRepository>(), familyRepo: locator<FamilyRepository>())
            ..add(HealthRecordInitialLoad()),
      child: _HealthRecordListBody(),
    );
  }
}

class _HealthRecordListBody extends StatelessWidget {
  const _HealthRecordListBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScaffoldColor,
      appBar: _buildCustomAppBar(context),
      body: SafeArea(
        child: BlocConsumer<HealthRecordBloc, HealthRecordState>(listener: _onStateChange, builder: _buildBody),
      ),
      floatingActionButton: _AddRecordFab(),
    );
  }

  PreferredSizeWidget _buildCustomAppBar(BuildContext context) {
    return CustomAppBar(
      title: 'Health Records',
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: kPrimaryColor, size: AppIconSize.m),
          onPressed: () => context.read<HealthRecordBloc>().add(HealthRecordInitialLoad()),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: kBorderColor, height: 1),
      ),
    );
  }

  // ── Listener ──────────────────────────────────────────────────────────────

  void _onStateChange(BuildContext context, HealthRecordState state) {
    if (state is HealthRecordSaveSuccess) {
      MessageService.showSuccess('Record saved successfully!');
    } else if (state is HealthRecordSaveFailure) {
      MessageService.showError(state.message);
    } else if (state is HealthRecordDeleteSuccess) {
      MessageService.showSuccess('Record deleted');
    } else if (state is HealthRecordDeleteFailure) {
      MessageService.showError(state.message);
    }
  }

  // ── Builder ───────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, HealthRecordState state) {
    if (state is HealthRecordLoading) {
      return const HealthRecordShimmer();
    }
    if (state is HealthRecordError) {
      return _HealthRecordErrorView(
        message: state.message,
        onRetry: () => context.read<HealthRecordBloc>().add(HealthRecordInitialLoad()),
      );
    }

    final loaded = _resolveLoaded(state);
    if (loaded == null) return const SizedBox.shrink();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Member Selection Bar ──
        SliverToBoxAdapter(
          child: _FamilyMemberSwitcher(members: loaded.familyMembers, selectedId: loaded.selectedFamilyMemberId),
        ),

        // ── Search & Filter Bar ──
        SliverPersistentHeader(
          pinned: true,
          delegate: _FilterHeaderDelegate(
            activeFilter: loaded.activeFilter,
            onChanged: (f) => context.read<HealthRecordBloc>().add(HealthRecordFilterChanged(f)),
          ),
        ),

        // ── Records Timeline ──
        _buildTimelineList(loaded, state),

        // Bottom padding for FAB
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  Widget _buildTimelineList(HealthRecordLoaded loaded, HealthRecordState state) {
    final records = loaded.filteredRecords;
    if (records.isEmpty) {
      return const SliverFillRemaining(child: _EmptyState());
    }

    // Grouping records by Month-Year
    final groups = <String, List<HealthRecordModel>>{};
    for (var r in records) {
      try {
        final date = DateTime.parse(r.recordDate);
        final key = DateFormat('MMMM yyyy').format(date);
        groups.putIfAbsent(key, () => []).add(r);
      } catch (_) {
        groups.putIfAbsent('Other', () => []).add(r);
      }
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final groupKey = groups.keys.elementAt(index);
        final groupRecords = groups[groupKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MonthHeader(title: groupKey),
            ...groupRecords.map(
              (r) => HealthRecordCard(
                record: r,
                isDeleting: state is HealthRecordDeleting && state.deletingId == r.id,
                familyMemberId: loaded.selectedFamilyMemberId,
              ),
            ),
          ],
        );
      }, childCount: groups.length),
    );
  }

  HealthRecordLoaded? _resolveLoaded(HealthRecordState s) => switch (s) {
    HealthRecordLoaded s => s,
    HealthRecordSaving s => s.previousLoaded,
    HealthRecordSaveSuccess s => s.loaded,
    HealthRecordSaveFailure s => s.previousLoaded,
    HealthRecordDeleting s => s.previousLoaded,
    HealthRecordDeleteSuccess s => s.loaded,
    HealthRecordDeleteFailure s => s.previousLoaded,
    _ => null,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// FAB
// ─────────────────────────────────────────────────────────────────────────────

class _AddRecordFab extends StatelessWidget {
  const _AddRecordFab();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        final loaded = _resolveLoaded(context.read<HealthRecordBloc>().state);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<HealthRecordBloc>(),
              child: AddHealthRecordPage(
                familyMembers: loaded?.familyMembers ?? [],
                initialFamilyMemberId: loaded?.selectedFamilyMemberId,
              ),
            ),
          ),
        );
      },
      backgroundColor: kPrimaryColor,
      icon: const Icon(Icons.add_rounded, color: kWhiteColor),
      label: Text('Add Record', style: kTextSemiBold(color: kWhiteColor)),
    );
  }

  HealthRecordLoaded? _resolveLoaded(HealthRecordState s) => switch (s) {
    HealthRecordLoaded s => s,
    HealthRecordSaveSuccess s => s.loaded,
    HealthRecordDeleteSuccess s => s.loaded,
    _ => null,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Family Member Switcher — redesigned with avatar cards
// ─────────────────────────────────────────────────────────────────────────────

class _FamilyMemberSwitcher extends StatelessWidget {
  final List<FamilyMemberModel> members;
  final int? selectedId; // null = "Me"

  const _FamilyMemberSwitcher({required this.members, required this.selectedId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20.h),
      decoration: BoxDecoration(
        color: kWhiteColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Text(
              'Family Members',
              style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 17.sp),
            ),
          ),
          SizedBox(height: 16.h),
          SizedBox(
            height: 96.h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              physics: const BouncingScrollPhysics(),
              children: [
                _MemberCard(
                  initials: 'Me',
                  name: 'Self',
                  subLabel: 'Me',
                  color: kPrimaryColor,
                  isSelected: selectedId == null,
                  onTap: () =>
                      context.read<HealthRecordBloc>().add(HealthRecordMemberSwitched(familyMemberId: null)),
                ),
                ...members.asMap().entries.map((entry) {
                  final m = entry.value;
                  final colors = _memberColors;
                  final color = colors[entry.key % colors.length];
                  return Padding(
                    padding: EdgeInsets.only(left: 12.w),
                    child: _MemberCard(
                      initials: _initials(m.fullName),
                      name: m.fullName.split(' ').first,
                      subLabel: m.relationship,
                      color: color,
                      isSelected: selectedId == m.id,
                      onTap: () =>
                          context.read<HealthRecordBloc>().add(HealthRecordMemberSwitched(familyMemberId: m.id)),
                    ),
                  );
                }),
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

  static const List<Color> _memberColors = [
    Color(0xFF6C63FF),
    Color(0xFF00BFA5),
    Color(0xFFFF6B6B),
    Color(0xFFFF9800),
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
  ];
}

class _MemberCard extends StatelessWidget {
  final String initials;
  final String name;
  final String subLabel;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _MemberCard({
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
        width: 72.w,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 58.w,
                  height: 58.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? color : color.withValues(alpha: 0.08),
                    border: Border.all(color: isSelected ? color : Colors.transparent, width: 2),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: kTextBold(color: isSelected ? kWhiteColor : color).copyWith(fontSize: 15.sp),
                    ),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: kWhiteColor, shape: BoxShape.circle),
                      child: Icon(Icons.check_circle_rounded, color: color, size: 18.sp),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              name,
              style: (isSelected ? kTextBold() : kTextMedium()).copyWith(
                fontSize: 11.sp,
                color: isSelected ? kTextPrimaryColor : kTextSecondaryColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Bar
// ─────────────────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String activeFilter;
  final ValueChanged<String> onChanged;

  const _FilterBar({required this.activeFilter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final filters = [
      {'value': 'all', 'label': 'All', 'icon': '📋'},
      ...kRecordTypes,
    ];
    return Container(
      color: Colors.transparent, // Inherit background from header delegate
      padding: AppPadding.symmetric(h: 16, v: 0),
      child: SizedBox(
        height: 40.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          itemCount: filters.length,
          separatorBuilder: (context, index) => AppSpacing.mHorizontal,
          itemBuilder: (_, i) {
            final f = filters[i];
            final sel = activeFilter == f['value'];
            return GestureDetector(
              onTap: () => onChanged(f['value']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: AppPadding.symmetric(h: 16, v: 8),
                decoration: BoxDecoration(
                  color: sel ? kPrimaryColor : kWhiteColor,
                  borderRadius: BorderRadius.circular(28.r),
                  border: Border.all(color: sel ? kPrimaryColor : const Color(0xFFF3F4F6), width: 1.5),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: kPrimaryColor.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(f['icon']!, style: TextStyle(fontSize: 14.sp)),
                    AppSpacing.sHorizontal,
                    Text(
                      f['label']!,
                      style: kTextSemiBold(color: sel ? kWhiteColor : kTextPrimaryColor).copyWith(fontSize: 13.sp),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DocumentAttachmentBar extends StatelessWidget {
  final VoidCallback onView;

  const _DocumentAttachmentBar({required this.onView});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: kScaffoldColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: kBorderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(Icons.description_rounded, size: 20.sp, color: kPrimaryColor),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attachment',
                  style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
                ),
                Text(
                  'Tap to view document',
                  style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onView,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: kWhiteColor,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              minimumSize: Size(0, 36.h),
            ),
            child: Text(
              'View',
              style: kTextBold(color: kWhiteColor).copyWith(fontSize: 12.sp),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final String title;

  const _MonthHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 12.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: kPrimaryColor,
              borderRadius: BorderRadius.circular(8.r),
              boxShadow: [
                BoxShadow(color: kPrimaryColor.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Text(
              title,
              style: kTextBold(color: kWhiteColor).copyWith(fontSize: 13.sp),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(child: Divider(color: kBorderColor.withValues(alpha: 0.5), thickness: 1)),
        ],
      ),
    );
  }
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String activeFilter;
  final ValueChanged<String> onChanged;

  _FilterHeaderDelegate({required this.activeFilter, required this.onChanged});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: kWhiteColor,
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Column(
        children: [
          _FilterBar(activeFilter: activeFilter, onChanged: onChanged),
          if (overlapsContent) Container(height: 1, color: const Color(0xFFF3F4F6)),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 64.h;

  @override
  double get minExtent => 64.h;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Health Record Card
// ─────────────────────────────────────────────────────────────────────────────

/// Formats a raw ISO date string (e.g. `2026-06-15`) to `15 Jun 2026`.
/// Falls back to the raw value when it cannot be parsed.
String _formatRecordDate(String raw) {
  try {
    return DateFormat('dd MMM yyyy').format(DateTime.parse(raw));
  } catch (_) {
    return raw;
  }
}

class HealthRecordCard extends StatelessWidget {
  final HealthRecordModel record;
  final bool isDeleting;
  final int? familyMemberId;

  const HealthRecordCard({super.key, required this.record, this.isDeleting = false, this.familyMemberId});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isDeleting ? 0.4 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.r),
          child: Column(
            children: [
              _CardHeader(record: record, isDeleting: isDeleting, familyMemberId: familyMemberId),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
                child: Column(
                  children: [
                    Divider(color: kBorderColor.withValues(alpha: 0.5), height: 1),
                    SizedBox(height: 16.h),
                    Row(
                      children: [
                        Expanded(
                          child: _CompactInfo(
                            icon: Icons.calendar_today_rounded,
                            label: 'Date',
                            value: _formatRecordDate(record.recordDate),
                          ),
                        ),
                        if (record.doctorName?.isNotEmpty == true) ...[
                          SizedBox(width: 16.w),
                          Expanded(
                            child: _CompactInfo(
                              icon: Icons.person_rounded,
                              label: 'Doctor',
                              value: record.doctorName!,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (record.hospitalName?.isNotEmpty == true) ...[
                      SizedBox(height: 16.h),
                      _CompactInfo(
                        icon: Icons.location_on_rounded,
                        label: 'Hospital',
                        value: record.hospitalName!,
                      ),
                    ],
                    if (record.documentUrl?.isNotEmpty == true) ...[
                      SizedBox(height: 16.h),
                      _DocumentAttachmentBar(onView: _downloadDocument),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadDocument() async {
    if (!isNotNull(record.documentUrl)) {
      MessageService.showInfo('Attachment not available');
      return;
    }
    String url = record.documentUrl!;
    final downloadService = FileDownloadService();
    downloadService.downloadAndViewFile(url: url);
  }
}

class _CardHeader extends StatelessWidget {
  final HealthRecordModel record;
  final bool isDeleting;
  final int? familyMemberId;

  const _CardHeader({required this.record, required this.isDeleting, this.familyMemberId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(20.w),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Center(
              child: Text(getRecordTypeIcon(record.recordType), style: TextStyle(fontSize: 22.sp)),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.recordTitle,
                  style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 16.sp),
                ),
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    getRecordTypeLabel(record.recordType).toUpperCase(),
                    style: kTextBold(
                      color: kPrimaryColor.withValues(alpha: 0.8),
                    ).copyWith(fontSize: 9.sp, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
          if (isDeleting)
            SizedBox(
              width: 20.w,
              height: 20.w,
              child: const CircularProgressIndicator(strokeWidth: 2, color: kErrorColor),
            )
          else
            GestureDetector(
              onTap: () => _confirmDelete(context),
              child: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.05), shape: BoxShape.circle),
                child: Icon(Icons.delete_outline_rounded, color: kErrorColor.withValues(alpha: 0.6), size: 20.sp),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) async {
    final result = await DialogHelper.showConfirmation(
      title: 'Delete Record',
      message: 'Are you sure you want to delete "${record.recordTitle}"? This cannot be undone.',
      confirmText: 'Delete',
      isDangerous: true,
    );

    if (result == true && context.mounted) {
      context.read<HealthRecordBloc>().add(
        HealthRecordDeleteRequested(id: record.id, familyMemberId: familyMemberId),
      );
    }
  }
}

class _CompactInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CompactInfo({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(color: kScaffoldColor, borderRadius: BorderRadius.circular(8.r)),
          child: Icon(icon, size: 16.sp, color: kPrimaryColor.withValues(alpha: 0.6)),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: kTextMedium(color: kTextSecondaryColor.withValues(alpha: 0.5)).copyWith(fontSize: 10.sp),
              ),
              Text(
                value,
                style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 13.sp),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120.w,
            height: 120.w,
            decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.05), shape: BoxShape.circle),
            child: Icon(Icons.folder_open_rounded, size: 60.sp, color: kPrimaryColor.withValues(alpha: 0.4)),
          ),
          SizedBox(height: 24.h),
          Text(
            'No Health Records',
            style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 18.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            'Your medical history will appear here.\nStart by adding a new record.',
            style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 14.sp, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _HealthRecordErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _HealthRecordErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: AppPadding.xl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.error_outline_rounded, size: 64, color: kErrorColor),
              AppSpacing.lVertical,
              Text('Oops!', style: kTextSemiBold2(), textAlign: TextAlign.center),
              AppSpacing.sVertical,
              Text(
                message,
                style: kTextNormal(color: kTextSecondaryColor),
                textAlign: TextAlign.center,
              ),
              AppSpacing.xxxlVertical,
              CustomButton(onPressed: onRetry, title: 'Try Again', iconData: Icons.refresh_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
