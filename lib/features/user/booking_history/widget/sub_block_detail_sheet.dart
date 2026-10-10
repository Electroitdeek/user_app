import 'dart:math' as math;

import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/services/app_clock.dart';
import 'package:adhisaat_health_care/core/services/launch_url_service.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/user/booking_history/helper/sub_block_status_mapper.dart';
import 'package:adhisaat_health_care/features/user/booking_history/model/sub_block_detail_model.dart';
import 'package:adhisaat_health_care/features/user/booking_history/widget/feedback_bottom_sheet.dart';
import 'package:adhisaat_health_care/features/user/service_booking/data/service_request_repository.dart';
import 'package:adhisaat_health_care/shared/widgets/buttons/custom_button.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry Point
// ─────────────────────────────────────────────────────────────────────────────

class SubBlockDetailSheet extends StatefulWidget {
  final int subBlockId;
  final int serviceRequestId;
  final String? requestNumber;
  final String? serviceName;
  final bool hideProviderIfEmergency;
  final bool hideCancelIfEmergency;

  // Hide cancel because this session falls in the payment-locked window
  // (last `durationDays × paidFraction` days of a long-duration booking).
  final bool lockCancel;
  final VoidCallback? onCancelRequest;

  const SubBlockDetailSheet({
    super.key,
    required this.subBlockId,
    required this.serviceRequestId,
    this.requestNumber,
    this.serviceName,
    this.hideProviderIfEmergency = false,
    this.hideCancelIfEmergency = false,
    this.lockCancel = false,
    this.onCancelRequest,
  });

  static void show(
    BuildContext context, {
    required int subBlockId,
    required int serviceRequestId,
    String? requestNumber,
    String? serviceName,
    bool hideProviderIfEmergency = false,
    bool hideCancelIfEmergency = false,
    bool lockCancel = false,
    VoidCallback? onCancelRequest,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => SubBlockDetailSheet(
        subBlockId: subBlockId,
        serviceRequestId: serviceRequestId,
        requestNumber: requestNumber,
        serviceName: serviceName,
        hideProviderIfEmergency: hideProviderIfEmergency,
        hideCancelIfEmergency: hideCancelIfEmergency,
        lockCancel: lockCancel,
        onCancelRequest: onCancelRequest,
      ),
    );
  }

  @override
  State<SubBlockDetailSheet> createState() => _SubBlockDetailSheetState();
}

class _SubBlockDetailSheetState extends State<SubBlockDetailSheet> {
  SubBlockDetailModel? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await locator<ServiceRequestRepository>().getSubBlockDetail(widget.subBlockId);
      if (!mounted) return;
      if (res['status'] == true && res['data'] != null) {
        setState(() {
          _data = SubBlockDetailModel.fromJson(res);
          _loading = false;
        });
      } else {
        setState(() {
          _error = res['message'] as String? ?? 'Failed to load session details.';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception:', '').trim();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      snap: true,
      snapSizes: const [0.62, 0.95],
      builder: (_, ctrl) {
        if (_loading) return _LoadingContent(controller: ctrl);
        if (_error != null) return _ErrorContent(controller: ctrl, error: _error!, onRetry: _load);
        return _SheetContent(
          controller: ctrl,
          data: _data!,
          serviceRequestId: widget.serviceRequestId,
          requestNumber: widget.requestNumber,
          serviceName: widget.serviceName,
          hideProvider: widget.hideProviderIfEmergency,
          hideCancel: widget.hideCancelIfEmergency || widget.lockCancel,
          lockCancel: widget.lockCancel,
          onCancel: () => Navigator.pop(context),
          onCancelRequest: widget.onCancelRequest,
          onRefresh: _load,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet Container
// ─────────────────────────────────────────────────────────────────────────────

class _SheetContainer extends StatelessWidget {
  final ScrollController controller;
  final Widget child;

  const _SheetContainer({required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

// Standalone drag handle for loading/error states (no header content)
Widget _dragHandle() {
  return Container(
    color: Colors.white,
    child: Padding(
      padding: EdgeInsets.only(top: 10.h, bottom: 6.h),
      child: Center(
        child: Container(
          width: 36.w,
          height: 4.h,
          decoration: BoxDecoration(color: const Color(0xFFDDE2EC), borderRadius: BorderRadius.circular(2.r)),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading State
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingContent extends StatelessWidget {
  final ScrollController controller;

  const _LoadingContent({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _SheetContainer(
      controller: controller,
      child: Column(
        children: [
          _dragHandle(),
          Expanded(
            child: Shimmer.fromColors(
              baseColor: const Color(0xFFE8ECF2),
              highlightColor: const Color(0xFFF6F8FC),
              child: ListView(
                controller: controller,
                padding: EdgeInsets.all(16.w),
                children: [
                  _ShimCard(height: 90.h),
                  SizedBox(height: 10.h),
                  _ShimCard(height: 140.h),
                  SizedBox(height: 10.h),
                  _ShimCard(height: 180.h),
                  SizedBox(height: 10.h),
                  _ShimCard(height: 100.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimCard extends StatelessWidget {
  final double height;

  const _ShimCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error State
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorContent extends StatelessWidget {
  final ScrollController controller;
  final String error;
  final VoidCallback onRetry;

  const _ErrorContent({required this.controller, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _SheetContainer(
      controller: controller,
      child: Column(
        children: [
          _dragHandle(),
          Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(Icons.error_outline_rounded, color: kErrorColor, size: 28.sp),
                    ),
                    SizedBox(height: 14.h),
                    Text('Failed to load', style: kTextBold1(color: kTextPrimaryColor)),
                    SizedBox(height: 6.h),
                    Text(
                      error,
                      style: kTextNormal0(color: kTextSecondaryColor),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20.h),
                    CustomButton(
                      onPressed: onRetry,
                      title: 'Retry',
                      iconData: Icons.refresh_rounded,
                      backgroundColor: kPrimaryColor,
                      borderRadius: BorderRadius.circular(12.r),
                      height: 44.h,
                      width: 140.w,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Content
// ─────────────────────────────────────────────────────────────────────────────

class _SheetContent extends StatelessWidget {
  final ScrollController controller;
  final SubBlockDetailModel data;
  final int serviceRequestId;
  final String? requestNumber;
  final String? serviceName;
  final bool hideProvider;
  final bool hideCancel;
  final bool lockCancel;
  final VoidCallback onCancel;
  final VoidCallback? onCancelRequest;
  final VoidCallback onRefresh;

  const _SheetContent({
    required this.controller,
    required this.data,
    required this.serviceRequestId,
    this.requestNumber,
    this.serviceName,
    this.hideProvider = false,
    this.hideCancel = false,
    this.lockCancel = false,
    required this.onCancel,
    this.onCancelRequest,
    required this.onRefresh,
  });

  DateTime? _scheduledStartDateTime(SubBlockDetailModel data) {
    try {
      String dateStr = data.scheduledDate.trim();
      String timeStr = data.scheduledStartTime.trim();
      if (dateStr.isEmpty || timeStr.isEmpty) return null;

      if (dateStr.contains('-')) {
        final bits = dateStr.split('-');
        if (bits.length == 3 && bits[0].length == 2) {
          dateStr = '${bits[2]}-${bits[1]}-${bits[0]}';
        }
      }

      return DateTime.tryParse('${dateStr}T$timeStr');
    } catch (_) {
      return null;
    }
  }

  bool _isTimeLocked(SubBlockDetailModel data) {
    final sched = _scheduledStartDateTime(data);
    if (sched == null) return false;
    return sched.difference(locator<AppClock>().now).inMinutes > 180;
  }

  bool _hasSessionTimePassed(SubBlockDetailModel data) {
    final sched = _scheduledStartDateTime(data);
    if (sched == null) return false;
    return locator<AppClock>().now.isAfter(sched);
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = SubBlockStatusMapper.computeExpired(
      status: data.status,
      scheduledDate: data.scheduledDate,
      scheduledStartTime: data.scheduledStartTime,
      scheduledEndTime: data.scheduledEndTime,
    );
    final status = SubBlockStatusMapper.fromString(data.status, isExpired: isExpired);
    final config = SubBlockStatusMapper.getConfig(status);
    final steps = TimelineStateBuilder.build(data, status);
    final canCancel = SubBlockActionResolver.showCancel(status);
    final canCall = SubBlockActionResolver.showCallProvider(status, data.hasProvider);
    final timeLocked = _isTimeLocked(data);
    final sessionTimePassed = _hasSessionTimePassed(data);
    final showProviderArea = status != SubBlockStatus.cancelled && status != SubBlockStatus.expired;

    return _SheetContainer(
      controller: controller,
      child: Column(
        children: [
          // ─── Sticky Header (includes drag handle) ──────────────────────
          _StickyHeader(data: data, config: config),
          Divider(height: 1, color: const Color(0xFFEDF0F7)),

          // ─── Scrollable Content ────────────────────────────────────────
          Expanded(
            child: ListView(
              controller: controller,
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 32.h),
              children: [
                // Status Banner
                _StatusBanner(config: config, status: status),
                SizedBox(height: 12.h),

                // Cancellation — prominent at top for cancelled sessions
                if (status == SubBlockStatus.cancelled || data.cancellationRecords.isNotEmpty) ...[
                  _CancellationSection(data: data),
                  SizedBox(height: 12.h),
                ],

                // Booking Info — at top before timeline
                if (data.booking != null) ...[
                  _BookingInfoSection(booking: data.booking!, requestNumber: requestNumber),
                  SizedBox(height: 12.h),
                ],

                // Provider card — hidden when cancelled, expired, or emergency with pending payment or time-locked
                if (data.hasProvider && !hideProvider && !timeLocked && showProviderArea) ...[
                  _ProviderSection(data: data, status: status, onRefresh: onRefresh),
                  SizedBox(height: 12.h),
                ],
                if (hideProvider && showProviderArea) ...[_PendingPaymentProviderBanner(), SizedBox(height: 12.h)],
                if (!hideProvider && timeLocked && showProviderArea) ...[
                  const _TimeLockedProviderBanner(),
                  SizedBox(height: 12.h),
                ],

                // Timeline
                _TimelineSection(steps: steps, config: config),
                SizedBox(height: 12.h),

                // Payment-locked cancel notice
                if (canCancel && lockCancel && status != SubBlockStatus.cancelled) ...[
                  const _CancelLockedBanner(),
                  SizedBox(height: 12.h),
                ],

                // Actions
                _ActionsSection(
                  data: data,
                  status: status,
                  canCancel: canCancel && !hideCancel && !sessionTimePassed,
                  canCall: canCall,
                  serviceRequestId: serviceRequestId,
                  requestNumber: requestNumber,
                  serviceName: serviceName,
                  onCancelRequest: onCancelRequest,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky Header
// ─────────────────────────────────────────────────────────────────────────────

class _StickyHeader extends StatelessWidget {
  final SubBlockDetailModel data;
  final SubBlockDisplayConfig config;

  const _StickyHeader({required this.data, required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle — same white bg, no seam
          Padding(
            padding: EdgeInsets.only(top: 10.h, bottom: 6.h),
            child: Center(
              child: Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE2EC),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
          ),
          // Header content
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 2.h, 16.w, 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Session', style: kTextBold2(color: kTextPrimaryColor)),
                          SizedBox(width: 8.w),
                          _StatusPill(config: config),
                        ],
                      ),
                      SizedBox(height: 5.h),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 12.sp, color: kTextSecondaryColor),
                          SizedBox(width: 4.w),
                          Text(
                            AppDateFormatter.dateFromApi(data.scheduledDateText),
                            style: kTextSemiBold0(color: kTextSecondaryColor),
                          ),
                          SizedBox(width: 10.w),
                          Icon(Icons.access_time_rounded, size: 12.sp, color: kTextSecondaryColor),
                          SizedBox(width: 4.w),
                          Flexible(
                            child: Text(
                              AppDateFormatter.shiftTimeRange(data.scheduledStartTime, data.scheduledEndTime),
                              style: kTextSemiBold0(color: kTextSecondaryColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(color: const Color(0xFFF1F4F9), shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, size: 16.sp, color: kTextSecondaryColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final SubBlockDisplayConfig config;

  const _StatusPill({required this.config});

  @override
  Widget build(BuildContext context) {
    if (config.isLive) return _LivePill(config: config);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(color: config.bgColor, borderRadius: BorderRadius.circular(20.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, color: config.primaryColor, size: 11.sp),
          SizedBox(width: 4.w),
          Text(config.label, style: kTextSemiBold0(color: config.primaryColor)),
        ],
      ),
    );
  }
}

class _LivePill extends StatefulWidget {
  final SubBlockDisplayConfig config;

  const _LivePill({required this.config});

  @override
  State<_LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<_LivePill> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: widget.config.primaryColor.withValues(alpha: 0.08 + _anim.value * 0.08),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: widget.config.primaryColor.withValues(alpha: 0.3 + _anim.value * 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6.r,
              height: 6.r,
              decoration: BoxDecoration(color: widget.config.primaryColor, shape: BoxShape.circle),
            ),
            SizedBox(width: 5.w),
            Text('Live', style: kTextSemiBold0(color: widget.config.primaryColor)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Banner
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final SubBlockDisplayConfig config;
  final SubBlockStatus status;

  const _StatusBanner({required this.config, required this.status});

  @override
  Widget build(BuildContext context) {
    if (config.message.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: config.primaryColor.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: config.primaryColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(color: config.bgColor, shape: BoxShape.circle),
            child: Icon(config.icon, color: config.primaryColor, size: 18.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(config.label, style: kTextSemiBold(color: config.primaryColor)),
                SizedBox(height: 3.h),
                Text(config.message, style: kTextNormal0(color: kTextSecondaryColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Card Base
// ─────────────────────────────────────────────────────────────────────────────

class _SCard extends StatelessWidget {
  final Widget child;

  const _SCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2B4A).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SCardHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;

  const _SCardHeader({required this.icon, required this.iconColor, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 10.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: iconColor, size: 13.sp),
          ),
          SizedBox(width: 8.w),
          Text(title, style: kTextSemiBold(color: kTextPrimaryColor)),
        ],
      ),
    );
  }
}

Divider get _sCardDivider => Divider(height: 1, color: const Color(0xFFF0F3F8));

// ─────────────────────────────────────────────────────────────────────────────
// Timeline Section
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineSection extends StatelessWidget {
  final List<TimelineStep> steps;
  final SubBlockDisplayConfig config;

  const _TimelineSection({required this.steps, required this.config});

  @override
  Widget build(BuildContext context) {
    return _SCard(
      child: Column(
        children: [
          _SCardHeader(icon: Icons.timeline_rounded, iconColor: kSecondaryColor, title: 'Timeline'),
          _sCardDivider,
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              children: steps
                  .asMap()
                  .entries
                  .map((e) => _TimelineRow(step: e.value, isLast: e.key == steps.length - 1))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final TimelineStep step;
  final bool isLast;

  const _TimelineRow({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final (dotColor, dotFilled, lineColor) = _dotConfig(step.state);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot + line column
          SizedBox(
            width: 24.w,
            child: Column(
              children: [
                SizedBox(height: 2.h),
                Container(
                  width: 16.r,
                  height: 16.r,
                  decoration: BoxDecoration(
                    color: dotFilled ? dotColor : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: dotColor, width: 2),
                  ),
                  child: dotFilled
                      ? Icon(
                          step.state == TimelineStepState.cancelled ? Icons.close_rounded : Icons.check_rounded,
                          color: Colors.white,
                          size: 9.sp,
                        )
                      : null,
                ),
                if (!isLast) ...[
                  SizedBox(height: 3.h),
                  Expanded(child: Container(width: 2, color: lineColor)),
                  SizedBox(height: 3.h),
                ],
              ],
            ),
          ),
          SizedBox(width: 10.w),
          // Label + timestamp
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.label, style: kTextSemiBold(color: _labelColor(step.state))),
                  if (step.timestamp != null && step.timestamp!.isNotEmpty && step.timestamp != '-') ...[
                    SizedBox(height: 2.h),
                    Text(_fmtTimestamp(step.timestamp!), style: kTextNormal0(color: kTextSecondaryColor)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, bool, Color) _dotConfig(TimelineStepState state) {
    switch (state) {
      case TimelineStepState.completed:
        return (kSuccessColor, true, kSuccessColor.withValues(alpha: 0.3));
      case TimelineStepState.active:
        return (kSecondaryColor, false, kBorderColor);
      case TimelineStepState.cancelled:
        return (kErrorColor, true, kErrorColor.withValues(alpha: 0.3));
      case TimelineStepState.upcoming:
        return (kBorderColor, false, kBorderColor);
    }
  }

  Color _labelColor(TimelineStepState state) {
    switch (state) {
      case TimelineStepState.completed:
        return kTextPrimaryColor;
      case TimelineStepState.active:
        return kSecondaryColor;
      case TimelineStepState.cancelled:
        return kErrorColor;
      case TimelineStepState.upcoming:
        return kTextSecondaryColor;
    }
  }

  String _fmtTimestamp(String raw) {
    // Pre-formatted composite strings (contain '·') pass through as-is
    if (raw.contains('·')) return raw;
    // Pure datetime strings get formatted
    return AppDateFormatter.timelineDateTime(raw);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider Section
// ─────────────────────────────────────────────────────────────────────────────

class _ProviderSection extends StatelessWidget {
  final SubBlockDetailModel data;
  final SubBlockStatus status;
  final VoidCallback onRefresh;

  const _ProviderSection({required this.data, required this.status, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final p = data.provider!;
    final isCompleted =
        status == SubBlockStatus.completed || data.booking?.bookingStatus.toLowerCase() == 'completed';
    final canCall = data.provider?.user?.mobileNumber != null && !isCompleted;

    const palette = [
      Color(0xFF6366F1),
      Color(0xFF0EA5E9),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6),
    ];
    final avatarColor = palette[math.Random(p.id).nextInt(palette.length)];

    return _SCard(
      child: Column(
        children: [
          _SCardHeader(
            icon: Icons.person_pin_circle_rounded,
            iconColor: kSecondaryColor,
            title: 'Healthcare Partner',
          ),
          _sCardDivider,
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [kSecondaryColor.withValues(alpha: 0.05), kPrimaryColor.withValues(alpha: 0.03)],
                    ),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: kSecondaryColor.withValues(alpha: 0.10)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      _ProviderAvatar(imageUrl: p.user?.profileImageUrl, initials: p.initials, color: avatarColor),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p.fullName,
                                    style: kTextBold1(color: kTextPrimaryColor),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (p.isVerified)
                                  Padding(
                                    padding: EdgeInsets.only(left: 4.w),
                                    child: Icon(Icons.verified_rounded, color: kSecondaryColor, size: 16.sp),
                                  ),
                              ],
                            ),
                            SizedBox(height: 5.h),
                            Wrap(
                              spacing: 6.w,
                              runSpacing: 4.h,
                              children: [
                                if (p.highestQualification != null && p.highestQualification!.isNotEmpty)
                                  _ProviderTag(icon: Icons.work_outline_rounded, label: p.highestQualification!)
                                else
                                  _ProviderTag(icon: Icons.verified_user_outlined, label: "Verified Partner"),
                                // if (p.dutyTypeText.isNotEmpty)
                                //   _ProviderTag(
                                //     icon: Icons.schedule_rounded,
                                //     label: p.dutyTypeText,
                                //   ),
                              ],
                            ),
                            if (p.totalRatings > 5) ...[
                              SizedBox(height: 6.h),
                              Row(
                                children: [
                                  Icon(Icons.star_rounded, color: kWarningColor, size: 14.sp),
                                  SizedBox(width: 3.w),
                                  Text(
                                    p.rating.toStringAsFixed(1),
                                    style: kTextSemiBold0(color: kTextPrimaryColor),
                                  ),
                                ],
                              ),
                            ],
                            if (p.totalJobsCompleted > 5) ...[
                              SizedBox(height: 4.h),
                              _ProviderTag(
                                icon: Icons.check_circle_outline_rounded,
                                label: '${p.totalJobsCompleted} jobs completed',
                                color: kSuccessColor,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCompleted) ...[
                  SizedBox(height: 12.h),
                  if (data.ratingFeedback != null)
                    _SessionFeedbackCard(feedback: data.ratingFeedback!, data: data, onRefresh: onRefresh)
                  else
                    _RateProviderBtn(data: data, onRefresh: onRefresh),
                ] else if (canCall) ...[
                  SizedBox(height: 12.h),
                  _CallProviderBtn(mobileNumber: p.user!.mobileNumber!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderAvatar extends StatelessWidget {
  final String? imageUrl;
  final String initials;
  final Color color;

  const _ProviderAvatar({this.imageUrl, required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60.r,
      height: 60.r,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: kWhiteColor, width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: imageUrl != null
          ? ClipOval(
              child: AppCachedImage(imageUrl: imageUrl!, fit: BoxFit.cover),
            )
          : Center(
              child: Text(initials, style: kTextBold1(color: kWhiteColor)),
            ),
    );
  }
}

class _ProviderTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _ProviderTag({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? kTextSecondaryColor;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10.sp, color: c),
          SizedBox(width: 3.w),
          Text(
            label,
            style: kTextNormal0(color: c),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _CallProviderBtn extends StatelessWidget {
  final String mobileNumber;

  const _CallProviderBtn({required this.mobileNumber});

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      onPressed: () async => LaunchUrlService.makePhoneCall(AppConstants.customerPartnerPhone),
      title: 'Call Partner',
      iconData: Icons.call_rounded,
      backgroundColor: kSuccessColor,
      borderRadius: BorderRadius.circular(12.r),
      height: 44.h,
      width: double.infinity,
    );
  }
}

class _RateProviderBtn extends StatelessWidget {
  final SubBlockDetailModel data;
  final VoidCallback onRefresh;

  const _RateProviderBtn({required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final bId = data.booking?.id ?? data.bookingId;
        if (bId != null) {
          await showFeedbackBottomSheet(
            context: context,
            bookingId: bId,
            bookingSubBlockId: data.id,
            providerName: data.provider?.fullName,
            serviceName: data.booking?.bookingNumber,
            onSuccess: onRefresh,
          );
        }
      },
      child: Container(
        width: double.infinity,
        height: 48.h,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
          ),
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(color: kWarningColor.withValues(alpha: 0.32), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_rounded, color: kWhiteColor, size: 20.sp),
            SizedBox(width: 8.w),
            Text('Rate Now', style: kTextBold1(color: kWhiteColor)),
          ],
        ),
      ),
    );
  }
}

class _SessionFeedbackCard extends StatelessWidget {
  final SubBlockRatingFeedback feedback;
  final SubBlockDetailModel data;
  final VoidCallback onRefresh;

  const _SessionFeedbackCard({required this.feedback, required this.data, required this.onRefresh});

  void _openEdit(BuildContext context) {
    final bId = data.booking?.id ?? data.bookingId;
    if (bId == null) return;
    showFeedbackBottomSheet(
      context: context,
      bookingId: bId,
      bookingSubBlockId: data.id,
      providerName: data.provider?.fullName,
      serviceName: data.booking?.bookingNumber,
      onSuccess: onRefresh,
      isEditing: true,
      initialRating: feedback.rating,
      initialPunctuality: feedback.punctualityRating,
      initialBehavior: feedback.behaviorRating,
      initialSkill: feedback.skillRating,
      initialComment: feedback.feedbackComment,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: kWarningColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: kWarningColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          // Rating value
          Text(
            '${feedback.rating}.0',
            style: kTextBold2(color: kWarningColor).copyWith(fontSize: 24.sp, height: 1),
          ),
          SizedBox(width: 12.w),
          // Stars + label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: List.generate(5, (index) {
                    return Padding(
                      padding: EdgeInsets.only(right: 2.w),
                      child: Icon(
                        index < feedback.rating ? Icons.star_rounded : Icons.star_border_rounded,
                        color: kWarningColor,
                        size: 16.sp,
                      ),
                    );
                  }),
                ),
                SizedBox(height: 3.h),
                Text('You rated this session', style: kTextNormal0(color: kTextSecondaryColor)),
              ],
            ),
          ),
          // Update link
          GestureDetector(
            onTap: () => _openEdit(context),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded, color: kWarningColor, size: 14.sp),
                  SizedBox(width: 4.w),
                  Text('Update', style: kTextSemiBold0(color: kWarningColor)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Booking Info Section
// ─────────────────────────────────────────────────────────────────────────────

class _BookingInfoSection extends StatelessWidget {
  final SubBlockBooking booking;
  final String? requestNumber;

  const _BookingInfoSection({required this.booking, this.requestNumber});

  @override
  Widget build(BuildContext context) {
    final hasRequest = requestNumber != null && requestNumber!.trim().isNotEmpty;
    final idLabel = hasRequest ? 'Request' : 'Booking';
    final idValue = hasRequest ? requestNumber! : booking.bookingNumber;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kPrimaryColor.withValues(alpha: 0.04), kSecondaryColor.withValues(alpha: 0.07)],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: kPrimaryColor.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(color: kPrimaryColor.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(Icons.receipt_long_rounded, color: kPrimaryColor, size: 18.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(idLabel, style: kTextNormal0(color: kTextSecondaryColor)),
                  SizedBox(height: 2.h),
                  Text(idValue, style: kTextSemiBold0(color: kTextPrimaryColor), maxLines: 2, softWrap: true),
                ],
              ),
            ),
            // Container(
            //   padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
            //   decoration: BoxDecoration(
            //     color: statusColor.withValues(alpha: 0.1),
            //     borderRadius: BorderRadius.circular(20.r),
            //     border: Border.all(color: statusColor.withValues(alpha: 0.25)),
            //   ),
            //   child: Text(booking.bookingStatusText, style: kTextSemiBold0(color: statusColor)),
            // ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cancellation Section
// ─────────────────────────────────────────────────────────────────────────────

class _CancellationSection extends StatelessWidget {
  final SubBlockDetailModel data;

  const _CancellationSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final records = data.cancellationRecords;
    // If no records but status is cancelled, show a generic cancelled card
    final hasRecords = records.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: kErrorColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: kErrorColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: kErrorColor.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 10.h),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: kErrorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(Icons.cancel_rounded, color: kErrorColor, size: 14.sp),
                ),
                SizedBox(width: 8.w),
                Text('Session Cancelled', style: kTextSemiBold(color: kErrorColor)),
              ],
            ),
          ),
          Divider(height: 1, color: kErrorColor.withValues(alpha: 0.12)),

          if (!hasRecords)
            Padding(
              padding: EdgeInsets.all(14.w),
              child: Text('This session has been cancelled.', style: kTextNormal0(color: kTextSecondaryColor)),
            ),

          if (hasRecords)
            ...records.map((r) {
              return Padding(
                padding: EdgeInsets.all(14.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (r.cancelledBy != null) ...[
                      _CancelInfoRow(
                        icon: Icons.person_off_rounded,
                        label: 'Cancelled By',
                        value: _formatCancelledBy(r.cancelledBy!),
                      ),
                    ],
                    if (r.cancelledAt != null) ...[
                      SizedBox(height: 8.h),
                      _CancelInfoRow(
                        icon: Icons.access_time_rounded,
                        label: 'Cancelled At',
                        value: AppDateFormatter.timelineDateTime(r.cancelledAt!),
                      ),
                    ],
                    if (r.reason != null && r.reason!.isNotEmpty) ...[
                      SizedBox(height: 10.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: kErrorColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Reason', style: kTextNormal0(color: kTextSecondaryColor)),
                            SizedBox(height: 3.h),
                            Text(r.reason!, style: kTextSemiBold(color: kTextPrimaryColor)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _formatCancelledBy(String who) {
    switch (who.toLowerCase()) {
      case 'customer':
        return 'You';
      case 'provider':
        return 'Partner';
      case 'admin':
        return 'Support Team';
      case 'system':
        return 'System (Auto)';
      default:
        return who;
    }
  }
}

class _CancelInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CancelInfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13.sp, color: kErrorColor.withValues(alpha: 0.6)),
        SizedBox(width: 6.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: kTextNormal0(color: kTextSecondaryColor)),
              SizedBox(height: 1.h),
              Text(value, style: kTextSemiBold(color: kTextPrimaryColor)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Actions Section
// ─────────────────────────────────────────────────────────────────────────────

class _ActionsSection extends StatelessWidget {
  final SubBlockDetailModel data;
  final SubBlockStatus status;
  final bool canCancel;
  final bool canCall;
  final int serviceRequestId;
  final String? requestNumber;
  final String? serviceName;
  final VoidCallback? onCancelRequest;

  const _ActionsSection({
    required this.data,
    required this.status,
    required this.canCancel,
    required this.canCall,
    required this.serviceRequestId,
    this.requestNumber,
    this.serviceName,
    this.onCancelRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action row — Cancel (if allowed) + Raise Issue
        Row(
          children: [
            if (canCancel) ...[
              Expanded(
                child: CustomButton(
                  onPressed: () => _confirmCancel(context),
                  title: 'Cancel Session',
                  backgroundColor: Colors.transparent,
                  textColor: kErrorColor,
                  borderSide: BorderSide(color: kErrorColor.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(12.r),
                  height: 46.h,
                ),
              ),
              SizedBox(width: 10.w),
            ],
            Expanded(
              child: CustomButton(
                onPressed: () {
                  Navigator.pop(context);
                  final dateStr = AppDateFormatter.dateFromApi(data.scheduledDateText);
                  final timeStr = AppDateFormatter.formatTimeString(data.scheduledStartTimeText);
                  final bookingId = data.booking?.bookingNumber ?? requestNumber ?? '';
                  final subject = bookingId.isNotEmpty
                      ? '$bookingId – Issue on $dateStr at $timeStr'
                      : 'Issue with session on $dateStr at $timeStr';
                  AppNavigator.to(
                    AppRoutes.createSupportTicket,
                    arguments: {
                      'requestId': serviceRequestId.toString(),
                      'requestNumber': requestNumber ?? data.booking?.bookingNumber,
                      'serviceName': serviceName,
                      'subject': subject,
                    },
                  );
                },
                title: 'Raise Issue',
                iconData: Icons.headset_mic_rounded,
                backgroundColor: Colors.transparent,
                textColor: kPrimaryColor,
                iconColor: kPrimaryColor,
                borderSide: BorderSide(color: kPrimaryColor.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(12.r),
                height: 46.h,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _confirmCancel(BuildContext context) {
    Navigator.pop(context); // close sheet
    onCancelRequest?.call(); // fetch preview in parent context
  }
}

class _CancelLockedBanner extends StatelessWidget {
  const _CancelLockedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: kSecondaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: kSecondaryColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(color: kSecondaryColor.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(Icons.event_busy_rounded, color: kSecondaryColor, size: 18.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cancellation Not Available', style: kTextSemiBold(color: kSecondaryColor)),
                SizedBox(height: 3.h),
                Text(
                  'This session is within the non-cancellable period of your booking. Please contact support for any changes.',
                  style: kTextNormal0(color: kTextSecondaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingPaymentProviderBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: kAccentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: kAccentColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(color: kAccentColor.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(Icons.lock_clock_rounded, color: kAccentColor, size: 18.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Partner Details Locked', style: kTextSemiBold(color: kAccentColor)),
                SizedBox(height: 3.h),
                Text(
                  'Your partner details will be visible once the payment is successful.',
                  style: kTextNormal0(color: kTextSecondaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeLockedProviderBanner extends StatelessWidget {
  const _TimeLockedProviderBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: kSecondaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: kSecondaryColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(color: kSecondaryColor.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(Icons.lock_outline_rounded, color: kSecondaryColor, size: 18.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Partner Details Locked', style: kTextSemiBold(color: kSecondaryColor)),
                SizedBox(height: 3.h),
                Text(
                  'Healthcare partner details will be visible 3 hours before the session start time.',
                  style: kTextNormal0(color: kTextSecondaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
