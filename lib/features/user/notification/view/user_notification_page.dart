import 'dart:ui' as ui;

import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/services/notification_keys.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/features/auth/auth_wrapper/data/role_enums.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/data/models/push_notification_model.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/user/notification/bloc/notification_bloc.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:adhisaat_health_care/shared/widgets/common/custom_error_view.dart';
import 'package:adhisaat_health_care/shared/widgets/common/custom_refresh_indicator.dart';
import 'package:adhisaat_health_care/shared/widgets/shimmer/card_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

class UserNotificationPage extends StatefulWidget {
  const UserNotificationPage({super.key});

  @override
  State<UserNotificationPage> createState() => _UserNotificationPageState();
}

class _UserNotificationPageState extends State<UserNotificationPage> {
  @override
  void initState() {
    super.initState();
    // Clear the iOS app-icon badge as soon as the user opens the notification page
    NotificationBloc.syncBadge(0);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => locator<NotificationBloc>()..add(FetchNotificationsEvent()),
      child: const _NotificationView(),
    );
  }
}

class _NotificationView extends StatelessWidget {
  const _NotificationView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationBloc, NotificationState>(
      builder: (context, state) {
        final bloc = context.read<NotificationBloc>();
        final isLoaded = state is NotificationLoaded;
        final unread = isLoaded ? state.notifications.where((n) => n.isRead == false).length : 0;

        return Scaffold(
          backgroundColor: kWhiteColor,
          appBar: CustomAppBar(
            title: "Notifications",
            // bottom: isLoaded && unread > 0
            //     ? PreferredSize(
            //         preferredSize: Size.fromHeight(24.h),
            //         child: Padding(
            //           padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
            //           child: Row(
            //             children: [
            //               Container(
            //                 padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            //                 decoration: BoxDecoration(
            //                   color: kPrimaryColor.withValues(alpha: 0.1),
            //                   borderRadius: BorderRadius.circular(6.r),
            //                 ),
            //                 child: Text(
            //                   '$unread UNREAD',
            //                   style: kTextBold(color: kPrimaryColor).copyWith(fontSize: 10.sp, letterSpacing: 0.5),
            //                 ),
            //               ),
            //             ],
            //           ),
            //         ),
            //       )
            //     : null,
            actions: [
              if (isLoaded && unread > 0)
                TextButton.icon(
                  onPressed: state.isActionLoading ? null : () => bloc.add(MarkAllAsReadEvent()),
                  icon: Icon(Icons.done_all_rounded, size: 16.sp, color: kPrimaryColor),
                  label: Text('Mark all read', style: kTextSemiBold0(color: kPrimaryColor)),
                ),
              SizedBox(width: 4.w),
            ],
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: switch (state) {
              NotificationLoading() => const ListShimmer(),
              NotificationError(:final message) => CustomErrorView(
                title: 'Failed to load',
                message: message,
                onRetry: () => bloc.add(FetchNotificationsEvent()),
              ),
              NotificationLoaded(:final notifications) when notifications.isEmpty => const _EmptyView(),
              NotificationLoaded() => _LoadedView(state: state),
              _ => const SizedBox.shrink(),
            },
          ),
        );
      },
    );
  }
}

class _LoadedView extends StatelessWidget {
  final NotificationLoaded state;

  const _LoadedView({required this.state});

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDate(state.notifications);

    return CustomRefreshIndicator(
      onRefresh: () async {
        context.read<NotificationBloc>().add(FetchNotificationsEvent());
      },
      child: SafeArea(
        top: false,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: 12.h)),
            for (final entry in groups.entries) ...[
              SliverToBoxAdapter(child: _DateHeader(label: entry.key)),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _NotificationCard(notification: entry.value[i]),
                  childCount: entry.value.length,
                ),
              ),
            ],
            SliverToBoxAdapter(child: SizedBox(height: 32.h)),
          ],
        ),
      ),
    );
  }

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

class _DateHeader extends StatelessWidget {
  final String label;

  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 10.h),
    child: Row(
      children: [
        Expanded(
          child: Divider(color: kBorderColor, thickness: 1, endIndent: 10.w),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Text(
            label,
            style: kTextSemiBold0(color: kPrimaryColor).copyWith(fontSize: 11.sp),
          ),
        ),
        Expanded(
          child: Divider(color: kBorderColor, thickness: 1, indent: 10.w),
        ),
      ],
    ),
  );
}

class _NotificationCard extends StatelessWidget {
  final PushNotificationModel notification;

  const _NotificationCard({required this.notification});

  Color _typeColor() {
    final type = notification.notificationType ?? notification.data?.type ?? '';
    final isReferral = type == 'referral_reward_alert' || notification.data?.couponCode != null;
    if (isReferral) return const Color(0xFFF59E0B);
    return switch (type) {
      'booking' || 'booking_confirmed' => kSuccessColor,
      'booking_cancelled' => kErrorColor,
      'booking_cancelled_refund' => const Color(0xFF8B5CF6),
      'booking_expired' => kErrorColor,
      'booking_completed' => kPrimaryColor,
      'emergency' || 'emergency_request' => kErrorColor,
      'payment' => const Color(0xFF059669),
      _ => kPrimaryColor,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<NotificationBloc>();
    final isUnread = notification.isRead == false;
    final type = notification.notificationType ?? notification.data?.type ?? '';
    final isReferral = type == 'referral_reward_alert' || notification.data?.couponCode != null;
    final typeColor = _typeColor();

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 8.h),
      child: InkWell(
        borderRadius: BorderRadius.circular(20.r),
        onTap: () {
          if (isUnread && notification.id != null) {
            bloc.add(MarkAsReadEvent([notification.id!]));
          }

          // Route the same way a tapped push notification would (user role).
          final d = notification.data;
          final realType = d?.type ?? notification.notificationType ?? '';
          final reqId = int.tryParse(d?.serviceRequestId ?? d?.requestId ?? d?.bookingId ?? '');
          final subBlockId = int.tryParse(d?.bookingSubBlockId ?? '');
          final target = NotificationRouter.resolve(
            realType,
            UserRole.patient,
            reqId: reqId,
            subBlockId: subBlockId,
          );
          if (target.hasTarget) {
            AppNavigator.to(target.route!, arguments: target.arguments);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: kWhiteColor,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: isUnread || isReferral ? typeColor.withValues(alpha: 0.18) : kBorderColor,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isUnread ? typeColor.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19.r),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(isUnread ? 18.w : 14.w, 13.h, 14.w, 13.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLeading(typeColor),
                      SizedBox(width: 12.w),
                      Expanded(child: _buildContent(isUnread)),
                      SizedBox(width: 8.w),
                      _buildTrailing(isUnread),
                    ],
                  ),
                ),
                if (isUnread)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 4.w, color: typeColor),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(Color typeColor) {
    final type = notification.notificationType ?? notification.data?.type ?? '';
    final isUnread = notification.isRead == false;
    final icon = switch (type) {
      'booking' => Icons.medical_services_rounded,
      'booking_confirmed' => Icons.verified_rounded,
      'booking_cancelled' => Icons.cancel_rounded,
      'booking_cancelled_refund' => Icons.account_balance_wallet_rounded,
      'booking_expired' => Icons.hourglass_empty_rounded,
      'booking_completed' => Icons.task_alt_rounded,
      'emergency' || 'emergency_request' => Icons.warning_amber_rounded,
      'payment' => Icons.payments_rounded,
      'referral_reward_alert' => Icons.card_giftcard_rounded,
      _ => Icons.notifications_rounded,
    };

    return Container(
      width: 42.w,
      height: 42.w,
      decoration: BoxDecoration(
        color: typeColor.withValues(alpha: isUnread ? 0.12 : 0.07),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          icon,
          color: typeColor.withValues(alpha: isUnread ? 1.0 : 0.65),
          size: 21.sp,
        ),
      ),
    );
  }

  Widget _buildContent(bool isUnread) {
    final type = notification.notificationType ?? notification.data?.type ?? '';
    final isReferral = type == 'referral_reward_alert' || notification.data?.couponCode != null;

    if (isReferral) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  notification.title ?? 'Referral Reward Earned!',
                  style: kTextBold(color: const Color(0xFFB45309)).copyWith(fontSize: 14.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (notification.data?.amount != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFB300), Color(0xFFFF8F00)]),
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF8F00).withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stars_rounded, color: Colors.white, size: 14.sp),
                      SizedBox(width: 4.w),
                      Text("₹${notification.data!.amount}", style: kTextBold1(color: Colors.white)),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            notification.message ?? notification.data?.body ?? '',
            style: kTextNormal(color: const Color(0xFF795548)).copyWith(fontSize: 11.sp),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          if (notification.data?.couponCode != null) ...[
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.5), width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "CODE",
                          style: kTextBold0(color: kGreyColor6).copyWith(fontSize: 8.sp, letterSpacing: 0.5),
                        ),
                        Text(
                          notification.data!.couponCode!,
                          style: kTextBold1(color: kBlackColor1).copyWith(letterSpacing: 1.5, fontSize: 14.sp),
                        ),
                      ],
                    ),
                  ),
                  _CopyButton(code: notification.data!.couponCode!),
                ],
              ),
            ),
          ],
          if (notification.data?.validUntil != null)
            Padding(
              padding: EdgeInsets.only(top: 6.h, left: 2.w),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 10.sp, color: kGreyColor6),
                  SizedBox(width: 4.w),
                  Text(
                    "Use by: ${notification.data!.validUntil}",
                    style: kTextMedium(color: kGreyColor6).copyWith(fontSize: 10.sp),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    final typeColor = _typeColor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          notification.title ?? 'Notification',
          style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 2.h),
        _ExpandableText(
          text: notification.message ?? '',
          style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
          expandColor: typeColor,
        ),
      ],
    );
  }

  Widget _buildTrailing(bool isUnread) {
    final timeStr = _formatTime(notification.createdAt);
    final typeColor = _typeColor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          timeStr,
          style: kTextNormal0(color: isUnread ? typeColor : kGreyColor4).copyWith(fontSize: 10.sp),
        ),
        if (isUnread) ...[
          SizedBox(height: 6.h),
          Container(
            width: 7.w,
            height: 7.w,
            decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle),
          ),
        ],
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

class _CopyButton extends StatefulWidget {
  final String code;

  const _CopyButton({required this.code});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: widget.code));
        setState(() => _copied = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _copied = false);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: _copied ? kSuccessColor : kPrimaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(color: _copied ? kSuccessColor : kPrimaryColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _copied ? Icons.check_circle_rounded : Icons.content_copy_rounded,
              color: _copied ? Colors.white : kPrimaryColor,
              size: 13.sp,
            ),
            SizedBox(width: 4.w),
            Text(
              _copied ? "COPIED" : "COPY",
              style: kTextBold0(color: _copied ? Colors.white : kPrimaryColor).copyWith(fontSize: 11.sp),
            ),
          ],
        ),
      ),
    );
  }
}

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
