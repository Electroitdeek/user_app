import 'dart:ui' as ui;

import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/data/models/push_notification_model.dart';
import 'package:adhisaat_health_care/data/repositories/notification_repository.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/service_provider/notification/bloc/provider_notification_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../shared/widgets/common/custom_refresh_indicator.dart';

// ─────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────
class ProviderNotificationPage extends StatefulWidget {
  const ProviderNotificationPage({super.key});

  @override
  State<ProviderNotificationPage> createState() => _ProviderNotificationPageState();
}

class _ProviderNotificationPageState extends State<ProviderNotificationPage> {
  @override
  void initState() {
    super.initState();
    // Clear the iOS app-icon badge as soon as the user opens the notification page
    ProviderNotificationBloc.syncBadge(0);
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ProviderNotificationBloc(locator<NotificationRepository>())..add(FetchProviderNotifications()),
    child: const _NotificationView(),
  );
}

// ─────────────────────────────────────────────────────────────────
// Main view
// ─────────────────────────────────────────────────────────────────
class _NotificationView extends StatelessWidget {
  const _NotificationView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProviderNotificationBloc, ProviderNotificationState>(
      builder: (context, state) {
        final bloc = context.read<ProviderNotificationBloc>();
        final isSelecting = state is ProviderNotificationLoaded && state.hasSelection;

        return Scaffold(
          backgroundColor: kWhiteColor,
          appBar: _buildAppBar(context, state, bloc),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: switch (state) {
              ProviderNotificationLoading() => const _ShimmerList(),
              ProviderNotificationError(:final message) => _ErrorView(
                message: message,
                onRetry: () => bloc.add(FetchProviderNotifications()),
              ),
              ProviderNotificationLoaded(:final notifications) when notifications.isEmpty => const _EmptyView(),
              ProviderNotificationLoaded() => _LoadedView(state: state),
              _ => const SizedBox.shrink(),
            },
          ),
          // Bottom action bar appears when items are selected
          bottomNavigationBar: isSelecting ? _SelectionActionBar(state: state) : null,
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ProviderNotificationState state,
    ProviderNotificationBloc bloc,
  ) {
    final isLoaded = state is ProviderNotificationLoaded;
    final isSelecting = isLoaded && (state).hasSelection;

    if (isSelecting) {
      final s = state;
      return AppBar(
        backgroundColor: kPrimaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => bloc.add(ClearSelectionEvent()),
        ),
        title: Text('${s.selectedIds.length} selected', style: kTextSemiBold2(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              final allIds = s.notifications.where((n) => n.id != null).map((n) => n.id!).toList();
              final allSelected = s.selectedIds.length == allIds.length;
              if (allSelected) {
                bloc.add(ClearSelectionEvent());
              } else {
                for (final id in allIds) {
                  if (!s.selectedIds.contains(id)) {
                    bloc.add(ToggleSelectNotificationEvent(id));
                  }
                }
              }
            },
            child: Text('Select all', style: kTextSemiBold(color: Colors.white70)),
          ),
        ],
        systemOverlayStyle: SystemUiOverlayStyle.light,
      );
    }

    return AppBar(
      backgroundColor: kWhiteColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text('Notifications', style: kTextBold1().copyWith(fontSize: 18.sp)),
      actions: [
        if (isLoaded && (state).hasUnread)
          IconButton(
            onPressed: () => bloc.add(MarkAllAsReadEvent()),
            icon: Icon(Icons.done_all_rounded, size: 24.sp, color: kPrimaryColor),
            tooltip: 'Mark all read',
          ),
        SizedBox(width: 8.w),
      ],
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Loaded list grouped by Today / Yesterday / Earlier
// ─────────────────────────────────────────────────────────────────
class _LoadedView extends StatelessWidget {
  final ProviderNotificationLoaded state;

  const _LoadedView({required this.state});

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDate(state.notifications);

    return CustomRefreshIndicator(
      onRefresh: () async {
        context.read<ProviderNotificationBloc>().add(FetchProviderNotifications());
      },
      child: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (state.unreadCount > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6.r,
                              height: 6.r,
                              decoration: const BoxDecoration(color: kPrimaryColor, shape: BoxShape.circle),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              '${state.unreadCount} Unread',
                              style: kTextBold(color: kPrimaryColor).copyWith(fontSize: 12.sp),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverToBoxAdapter(child: SizedBox(height: 12.h)),
            for (final entry in groups.entries) ...[
              SliverToBoxAdapter(child: _DateHeader(label: entry.key)),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _NotificationCard(
                    notification: entry.value[i],
                    isSelected: state.selectedIds.contains(entry.value[i].id),
                    isSelecting: state.hasSelection,
                  ),
                  childCount: entry.value.length,
                ),
              ),
            ],
            SliverToBoxAdapter(child: SizedBox(height: 24.h)),
          ],
        ),
      ),
    );
  }

  // Group notifications into Today / Yesterday / Earlier / date labels
  Map<String, List<PushNotificationModel>> _groupByDate(List<PushNotificationModel> list) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<PushNotificationModel>> groups = {};

    for (final n in list) {
      final dt = _parseDate(n.createdAt);
      final day = DateTime(dt.year, dt.month, dt.day);
      String label;
      if (day == today) {
        label = 'Today';
      } else if (day == yesterday) {
        label = 'Yesterday';
      } else {
        label = DateFormat('MMMM d, yyyy').format(dt);
      }
      groups.putIfAbsent(label, () => []).add(n);
    }
    return groups;
  }

  DateTime _parseDate(String? s) {
    if (s == null) return DateTime.now();
    try {
      return DateTime.parse(s);
    } catch (_) {
      return DateTime.now();
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// Date section header
// ─────────────────────────────────────────────────────────────────
class _DateHeader extends StatelessWidget {
  final String label;

  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 10.h),
    child: Row(
      children: [
        Expanded(
          child: Divider(color: kBorderColor.withValues(alpha: 0.5), thickness: 1, endIndent: 10.w),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: kScaffoldColor,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: kBorderColor.withValues(alpha: 0.5)),
          ),
          child: Text(
            label,
            style: kTextSemiBold0(color: kTextSecondaryColor).copyWith(fontSize: 11.sp, letterSpacing: 0.5),
          ),
        ),
        Expanded(
          child: Divider(color: kBorderColor.withValues(alpha: 0.5), thickness: 1, indent: 10.w),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
// Single notification card — Practo style
// ─────────────────────────────────────────────────────────────────
class _NotificationCard extends StatelessWidget {
  final PushNotificationModel notification;
  final bool isSelected;
  final bool isSelecting;

  const _NotificationCard({required this.notification, required this.isSelected, required this.isSelecting});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ProviderNotificationBloc>();
    final isUnread = notification.isRead == false;
    final id = notification.id;

    final cfg = _iconConfig();
    final typeColor = cfg.$2;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 3.h),
      child: GestureDetector(
        onLongPress: id == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                bloc.add(ToggleSelectNotificationEvent(id));
              },
        onTap: () {
          if (isSelecting && id != null) {
            bloc.add(ToggleSelectNotificationEvent(id));
          } else {
            if (isUnread && id != null) {
              bloc.add(MarkAsReadEvent([id]));
            }

            final type = notification.notificationType?.toLowerCase() ?? '';
            final dataType = notification.data?.type?.toLowerCase() ?? '';
            final requestId = notification.data?.requestId ?? notification.data?.serviceRequestId;

            if ((type == 'booking' || dataType == 'emergency_request' || dataType == 'booking_cancelled') &&
                requestId != null) {
              final rid = int.tryParse(requestId);
              if (rid != null) {
                AppNavigator.to(AppRoutes.providerRequestDetail, arguments: rid);
              }
            } else if (dataType == 'provider_payout_completed' || type == 'provider_payout_completed') {
              AppNavigator.to(AppRoutes.providerEarningsList);
            } else if (dataType == 'service_status_changed' || type == 'service_status_changed') {
              AppNavigator.to(AppRoutes.providerProfilePage);
            }
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? kPrimaryColor.withValues(alpha: 0.06)
                : (isUnread ? typeColor.withValues(alpha: 0.03) : Colors.white),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: isSelected
                  ? kPrimaryColor.withValues(alpha: 0.4)
                  : (isUnread ? typeColor.withValues(alpha: 0.15) : Colors.transparent),
              width: 1.5,
            ),
            boxShadow: [
              if (!isUnread) ...[
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4)),
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1)),
              ],
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19.r),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLeading(),
                      SizedBox(width: 10.w),
                      Expanded(child: _buildContent()),
                    ],
                  ),
                ),
                if (isUnread && !isSelecting)
                  Positioned(
                    left: 0,
                    top: 16.h,
                    child: Container(
                      width: 4.w,
                      height: 32.h,
                      decoration: BoxDecoration(
                        color: typeColor,
                        borderRadius: BorderRadius.horizontal(right: Radius.circular(4.r)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeading() {
    if (isSelecting) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38.w,
        height: 38.w,
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? kPrimaryColor : kBorderColor, width: 2),
        ),
        child: isSelected ? Icon(Icons.check, color: Colors.white, size: 16.sp) : null,
      );
    }

    final cfg = _iconConfig();
    final typeColor = cfg.$2;
    final isUnread = notification.isRead == false;
    return Container(
      width: 38.w,
      height: 38.w,
      decoration: BoxDecoration(
        color: isUnread ? typeColor.withValues(alpha: 0.1) : kScaffoldColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(cfg.$1, color: isUnread ? typeColor : kTextSecondaryColor, size: 18.sp),
      ),
    );
  }

  (IconData, Color) _iconConfig() {
    final type = notification.notificationType ?? notification.data?.type ?? '';
    return switch (type) {
      'emergency_request' => (Icons.warning_amber_rounded, kErrorColor),
      'service_request' => (Icons.medical_services_rounded, kPrimaryColor),
      'booking_confirmed' => (Icons.verified_rounded, kSuccessColor),
      'booking_cancelled' => (Icons.cancel_rounded, kErrorColor),
      'service_completed' => (Icons.task_alt_rounded, kSuccessColor),
      'provider_accepted' => (Icons.handshake_rounded, kInfoColor),
      'payment' => (Icons.payments_rounded, kWarningColor),
      'provider_payout_completed' => (Icons.savings_rounded, kSuccessColor),
      _ => (Icons.notifications_active_rounded, kPrimaryColor),
    };
  }

  Widget _buildContent() {
    final isUnread = notification.isRead == false;
    final typeColor = _iconConfig().$2;
    final timeStr = _formatTime(notification.createdAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                notification.title ?? 'Notification',
                style: isUnread ? kTextBold() : kTextSemiBold(color: kTextPrimaryColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 8.w),
            Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: Text(
                timeStr,
                style: kTextNormal0(color: isUnread ? typeColor : kTextHintColor).copyWith(fontSize: 11.sp),
              ),
            ),
            if (isUnread) ...[
              SizedBox(width: 6.w),
              Padding(
                padding: EdgeInsets.only(top: 5.h),
                child: Container(
                  width: 8.w,
                  height: 8.w,
                  decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 4.h),
        _ExpandableText(
          text: notification.message ?? '',
          style: kTextNormal0(color: kTextSecondaryColor),
          expandColor: typeColor,
        ),
      ],
    );
  }

  String _formatTime(String? s) {
    if (s == null) return '';
    try {
      final dt = DateTime.parse(s).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return DateFormat('h:mm a').format(dt);
      return DateFormat('d MMM').format(dt);
    } catch (_) {
      return '';
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// Bottom bar shown during multi-select
// ─────────────────────────────────────────────────────────────────
class _SelectionActionBar extends StatelessWidget {
  final ProviderNotificationLoaded state;

  const _SelectionActionBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ProviderNotificationBloc>();
    final selectedIds = state.selectedIds.toList();

    final selectedNotifs = state.notifications
        .where((n) => n.id != null && state.selectedIds.contains(n.id))
        .toList();
    final hasUnreadInSelection = selectedNotifs.any((n) => n.isRead == false);

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4)),
          ],
        ),
        child: Row(
          children: [
            if (hasUnreadInSelection)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.isActionLoading ? null : () => bloc.add(MarkAsReadEvent(selectedIds)),
                  icon: Icon(Icons.done_all_rounded, size: 16.sp),
                  label: const Text('Mark read', maxLines: 1, overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimaryColor,
                    side: BorderSide(color: kPrimaryColor.withValues(alpha: 0.5)),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                ),
              ),
            if (hasUnreadInSelection) SizedBox(width: 12.w),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: state.isActionLoading ? null : () => _confirmClear(context, bloc, selectedIds),
                icon: state.isActionLoading
                    ? SizedBox(
                        width: 14.w,
                        height: 14.w,
                        child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Icon(Icons.delete_outline_rounded, size: 16.sp),
                label: Text(state.isActionLoading ? 'Clearing…' : 'Delete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kErrorColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, ProviderNotificationBloc bloc, List<int> ids) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Delete notifications?', style: kTextBold1()),
        content: Text(
          'Remove ${ids.length} notification${ids.length == 1 ? '' : 's'}? This cannot be undone.',
          style: kTextNormal(color: kTextSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: kTextSemiBold(color: kTextSecondaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kErrorColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) bloc.add(ClearNotificationsEvent(ids));
  }
}

// ─────────────────────────────────────────────────────────────────
// Shimmer skeleton while loading
// ─────────────────────────────────────────────────────────────────
class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
    itemCount: 6,
    itemBuilder: (_, i) => Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFECECEC),
        highlightColor: const Color(0xFFF4F4F4),
        child: const _ShimmerCard(),
      ),
    ),
  );
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 2.h),
                Container(
                  height: 14.h,
                  width: 140.w,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6.r)),
                ),
                SizedBox(height: 8.h),
                Container(
                  height: 11.h,
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6.r)),
                ),
                SizedBox(height: 5.h),
                Container(
                  height: 11.h,
                  width: 150.w,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6.r)),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                height: 10.h,
                width: 38.w,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Expandable body text with Read more / Show less
// ─────────────────────────────────────────────────────────────────
class _ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Color expandColor;
  final int maxLines;

  const _ExpandableText({required this.text, required this.style, required this.expandColor}) : maxLines = 3;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tp = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: widget.maxLines,
          textDirection: ui.TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final overflows = tp.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: widget.style,
              maxLines: _expanded ? null : widget.maxLines,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (overflows || _expanded) ...[
              SizedBox(height: 4.h),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? 'Show less' : 'Read more',
                  style: kTextSemiBold0(color: widget.expandColor).copyWith(fontSize: 11.sp),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(40.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120.w,
            height: 120.w,
            decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.06), shape: BoxShape.circle),
            child: Center(
              child: Icon(
                Icons.notifications_none_rounded,
                size: 48.sp,
                color: kPrimaryColor.withValues(alpha: 0.4),
              ),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'Your inbox is quiet',
            style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 18.sp),
          ),
          SizedBox(height: 12.h),
          Text(
            "You don't have any notifications at the moment. We'll let you know when something important happens.",
            style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 13.sp),
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
    child: SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 52.sp, color: kErrorColor.withValues(alpha: 0.6)),
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
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
