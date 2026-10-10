import 'dart:async';

import 'package:adhisaat_health_care/core/services/app_clock.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/theme/screen_dimensions.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/models/provider_service_request_model.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/models/sub_block_model.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/widgets/session_detail_sheet.dart';
import 'package:adhisaat_health_care/shared/widgets/dialogs/dialog_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../di/locator.dart';
import '../bloc/provider_request_detail_bloc/provider_request_detail_bloc.dart';

// ─── Session state ────────────────────────────────────────────────────────────

enum _SessionState { upcoming, readyToStart, ongoing, completed, cancelled }

// ─── Main widget ──────────────────────────────────────────────────────────────

class SessionDashboard extends StatefulWidget {
  final ProviderServiceRequestModel request;
  final void Function(SubBlock) onStartBooking;
  final void Function(SubBlock) onCompleteBooking;

  const SessionDashboard({
    super.key,
    required this.request,
    required this.onStartBooking,
    required this.onCompleteBooking,
  });

  @override
  State<SessionDashboard> createState() => _SessionDashboardState();
}

class _SessionDashboardState extends State<SessionDashboard> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  bool _ongoingOpen = true;
  bool _readyToStartOpen = true;
  bool _upcomingOpen = true;
  bool _completedOpen = false;
  bool _expiredOpen = false;
  bool _cancelledOpen = false;
  bool _upcomingExpanded = false;

  static const _purple = kSecondaryColor;
  static const _orange = Color(0xFFD97706);

  @override
  void initState() {
    super.initState();
    _now = locator<AppClock>().now;
    // Expand completed section by default when nothing is pending.
    final hasPending = _sessionBlocks.any((b) {
      final s = _stateOf(b);
      return s == _SessionState.ongoing || s == _SessionState.readyToStart || s == _SessionState.upcoming;
    });
    _completedOpen = !hasPending;
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = locator<AppClock>().now);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Data helpers ────────────────────────────────────────────────────────────

  List<SubBlock> get _sessionBlocks {
    final blocks = widget.request.bookings.expand((b) => b.subBlocks).toList();
    blocks.sort((a, b) {
      final ad = _sessionDateTime(a);
      final bd = _sessionDateTime(b);
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
    return blocks;
  }

  DateTime? _sessionDateTime(SubBlock b) {
    try {
      final date = DateTime.parse(b.scheduledDate);
      final parts = b.scheduledStartTime.split(':');
      return DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(parts[0]),
        int.parse(parts.length > 1 ? parts[1] : '0'),
      );
    } catch (_) {
      return null;
    }
  }

  // Session end as DateTime. For overnight/full-day shifts where end <= start,
  // the end falls on the next calendar day.
  DateTime? _sessionEndDateTime(SubBlock b) {
    try {
      final date = DateTime.parse(b.scheduledDate);
      final eParts = b.scheduledEndTime.split(':');
      var end = DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(eParts[0]),
        int.parse(eParts.length > 1 ? eParts[1] : '0'),
      );
      final start = _sessionDateTime(b);
      if (start != null && !end.isAfter(start)) {
        end = end.add(const Duration(days: 1));
      }
      return end;
    } catch (_) {
      return null;
    }
  }

  // True when the scheduled end time has already passed.
  bool _isExpired(SubBlock b) {
    final end = _sessionEndDateTime(b);
    if (end == null) return false;
    return _now.isAfter(end);
  }

  _SessionState _stateOf(SubBlock b) {
    switch (b.status.toLowerCase()) {
      case 'completed':
        return _SessionState.completed;
      case 'cancelled':
        return _SessionState.cancelled;
      case 'in_progress':
        return _SessionState.ongoing;
      case 'assigned':
        final start = _sessionDateTime(b);
        if (start == null) return _SessionState.upcoming;
        final readyAt = start.subtract(const Duration(minutes: 30));
        if (_now.isAfter(readyAt)) return _SessionState.readyToStart;
        return _SessionState.upcoming;
      default:
        return _SessionState.upcoming;
    }
  }

  Color _stateColor(_SessionState s) => switch (s) {
    _SessionState.upcoming => kPrimaryColor,
    _SessionState.readyToStart => _orange,
    _SessionState.ongoing => _purple,
    _SessionState.completed => kSuccessColor,
    _SessionState.cancelled => kErrorColor,
  };

  IconData _stateIcon(_SessionState s) => switch (s) {
    _SessionState.upcoming => Icons.schedule_rounded,
    _SessionState.readyToStart => Icons.play_circle_rounded,
    _SessionState.ongoing => Icons.radio_button_checked_rounded,
    _SessionState.completed => Icons.check_circle_rounded,
    _SessionState.cancelled => Icons.cancel_rounded,
  };

  String _stateLabel(_SessionState s) => switch (s) {
    _SessionState.upcoming => 'Upcoming',
    _SessionState.readyToStart => 'Ready to Start',
    _SessionState.ongoing => 'Ongoing',
    _SessionState.completed => 'Completed',
    _SessionState.cancelled => 'Cancelled',
  };

  // ── Earnings ────────────────────────────────────────────────────────────────

  double get _totalPayout =>
      _sessionBlocks.where((b) => b.status.toLowerCase() != 'cancelled').fold(0.0, (s, b) => s + b.providerPayout);

  double get _earnedSoFar =>
      _sessionBlocks.where((b) => b.status.toLowerCase() == 'completed').fold(0.0, (s, b) => s + b.providerPayout);

  String _countdown(SubBlock b) {
    final start = _sessionDateTime(b);
    if (start == null) return '';
    final diff = start.difference(_now);
    if (diff.isNegative) return '';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h > 0) return 'Starts in ${h}h ${m}m';
    if (m > 0) return 'Starts in ${m}m';
    return 'Starting now';
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final blocks = _sessionBlocks;
    final ongoing = blocks.where((b) => _stateOf(b) == _SessionState.ongoing).toList();
    final readyToStartAll = blocks.where((b) => _stateOf(b) == _SessionState.readyToStart).toList();
    final readyToStart = readyToStartAll.where((b) => !_isExpired(b)).toList();
    final expired = readyToStartAll.where(_isExpired).toList();
    final upcoming = blocks.where((b) => _stateOf(b) == _SessionState.upcoming).toList();
    final completed = blocks.where((b) => _stateOf(b) == _SessionState.completed).toList();
    final cancelled = blocks.where((b) => _stateOf(b) == _SessionState.cancelled).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEarningsProgress(completed.length, blocks.length - cancelled.length),
        SizedBox(height: 16.h),

        // Ongoing — top priority
        if (ongoing.isNotEmpty) ...[
          _collapsibleHeader(
            label: 'Live Session',
            icon: Icons.radio_button_checked_rounded,
            color: _purple,
            count: ongoing.length,
            expanded: _ongoingOpen,
            onTap: () => setState(() => _ongoingOpen = !_ongoingOpen),
          ),
          if (_ongoingOpen) ...[
            SizedBox(height: 8.h),
            ...ongoing.map(
              (b) => _SessionCard(
                block: b,
                state: _SessionState.ongoing,
                stateColor: _stateColor(_SessionState.ongoing),
                stateIcon: _stateIcon(_SessionState.ongoing),
                stateLabel: _stateLabel(_SessionState.ongoing),
                request: widget.request,
                onStartBooking: widget.onStartBooking,
                onCompleteBooking: widget.onCompleteBooking,
                countdown: '',
                isFullDay: widget.request.isFullDayShift,
              ),
            ),
          ],
          SizedBox(height: 16.h),
        ],

        // Ready to start
        if (readyToStart.isNotEmpty) ...[
          _collapsibleHeader(
            label: 'Ready to Start',
            icon: Icons.play_circle_rounded,
            color: _orange,
            count: readyToStart.length,
            expanded: _readyToStartOpen,
            onTap: () => setState(() => _readyToStartOpen = !_readyToStartOpen),
          ),
          if (_readyToStartOpen) ...[
            SizedBox(height: 8.h),
            ...readyToStart.map(
              (b) => _SessionCard(
                block: b,
                state: _SessionState.readyToStart,
                stateColor: _stateColor(_SessionState.readyToStart),
                stateIcon: _stateIcon(_SessionState.readyToStart),
                stateLabel: _stateLabel(_SessionState.readyToStart),
                request: widget.request,
                onStartBooking: widget.onStartBooking,
                onCompleteBooking: widget.onCompleteBooking,
                countdown: _countdown(b),
                isFullDay: widget.request.isFullDayShift,
              ),
            ),
          ],
          SizedBox(height: 16.h),
        ],

        // Upcoming
        if (upcoming.isNotEmpty) ...[
          _collapsibleHeader(
            label: 'Upcoming Sessions',
            icon: Icons.schedule_rounded,
            color: kPrimaryColor,
            count: upcoming.length,
            expanded: _upcomingOpen,
            onTap: () => setState(() => _upcomingOpen = !_upcomingOpen),
          ),
          if (_upcomingOpen) ...[
            SizedBox(height: 8.h),
            ...(_upcomingExpanded ? upcoming : upcoming.take(3)).map(
              (b) => _SessionCard(
                block: b,
                state: _SessionState.upcoming,
                stateColor: _stateColor(_SessionState.upcoming),
                stateIcon: _stateIcon(_SessionState.upcoming),
                stateLabel: _stateLabel(_SessionState.upcoming),
                request: widget.request,
                onStartBooking: widget.onStartBooking,
                onCompleteBooking: widget.onCompleteBooking,
                countdown: '',
                isFullDay: widget.request.isFullDayShift,
              ),
            ),
            if (upcoming.length > 3) ...[
              SizedBox(height: 8.h),
              GestureDetector(
                onTap: () => setState(() => _upcomingExpanded = !_upcomingExpanded),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: kPrimaryColor.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _upcomingExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 16.sp,
                        color: kPrimaryColor,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        _upcomingExpanded ? 'Show Less' : 'View More  (+${upcoming.length - 3} more)',
                        style: kTextSemiBold0(color: kPrimaryColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
          SizedBox(height: 16.h),
        ],

        // Completed — collapsible
        if (completed.isNotEmpty) ...[
          _collapsibleHeader(
            label: 'Completed',
            icon: Icons.check_circle_rounded,
            color: kSuccessColor,
            count: completed.length,
            expanded: _completedOpen,
            onTap: () => setState(() => _completedOpen = !_completedOpen),
          ),
          if (_completedOpen) ...[
            SizedBox(height: 8.h),
            ...completed.map(
              (b) => _SessionCard(
                block: b,
                state: _SessionState.completed,
                stateColor: _stateColor(_SessionState.completed),
                stateIcon: _stateIcon(_SessionState.completed),
                stateLabel: _stateLabel(_SessionState.completed),
                request: widget.request,
                onStartBooking: widget.onStartBooking,
                onCompleteBooking: widget.onCompleteBooking,
                countdown: '',
                isFullDay: widget.request.isFullDayShift,
              ),
            ),
          ],
          SizedBox(height: 16.h),
        ],

        // Expired — missed sessions, separated from genuinely actionable ones
        if (expired.isNotEmpty) ...[
          _collapsibleHeader(
            label: 'Expired',
            icon: Icons.block_rounded,
            color: Colors.grey.shade600,
            count: expired.length,
            expanded: _expiredOpen,
            onTap: () => setState(() => _expiredOpen = !_expiredOpen),
          ),
          if (_expiredOpen) ...[
            SizedBox(height: 8.h),
            ...expired.map(
              (b) => _SessionCard(
                block: b,
                state: _SessionState.readyToStart,
                stateColor: _stateColor(_SessionState.readyToStart),
                stateIcon: _stateIcon(_SessionState.readyToStart),
                stateLabel: _stateLabel(_SessionState.readyToStart),
                request: widget.request,
                onStartBooking: widget.onStartBooking,
                onCompleteBooking: widget.onCompleteBooking,
                countdown: '',
                isFullDay: widget.request.isFullDayShift,
                isExpired: true,
              ),
            ),
          ],
          SizedBox(height: 16.h),
        ],

        // Cancelled
        if (cancelled.isNotEmpty) ...[
          _collapsibleHeader(
            label: 'Cancelled',
            icon: Icons.cancel_rounded,
            color: kErrorColor,
            count: cancelled.length,
            expanded: _cancelledOpen,
            onTap: () => setState(() => _cancelledOpen = !_cancelledOpen),
          ),
          if (_cancelledOpen) ...[
            SizedBox(height: 8.h),
            ...cancelled.map(
              (b) => _SessionCard(
                block: b,
                state: _SessionState.cancelled,
                stateColor: _stateColor(_SessionState.cancelled),
                stateIcon: _stateIcon(_SessionState.cancelled),
                stateLabel: _stateLabel(_SessionState.cancelled),
                request: widget.request,
                onStartBooking: widget.onStartBooking,
                onCompleteBooking: widget.onCompleteBooking,
                countdown: '',
                isFullDay: widget.request.isFullDayShift,
              ),
            ),
          ],
          SizedBox(height: 16.h),
        ],
      ],
    );
  }

  // ── Earnings progress ───────────────────────────────────────────────────────

  Widget _buildEarningsProgress(int completedCount, int total) {
    final progress = total > 0 ? completedCount / total : 0.0;
    final remaining = _totalPayout - _earnedSoFar;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFBBF7D0)),
        boxShadow: [
          BoxShadow(color: kSuccessColor.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total + earned row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      NumberUtils.formatCurrency(_totalPayout),
                      style: kTextBold3(color: const Color(0xFF15803D)).copyWith(fontSize: 28.sp),
                    ),
                    Text(
                      'Total Booking Earnings',
                      style: kTextNormal0(color: const Color(0xFF16A34A)).copyWith(fontSize: 11.sp),
                    ),
                  ],
                ),
              ),
              if (_earnedSoFar > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: kSuccessColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        NumberUtils.formatCurrency(_earnedSoFar),
                        style: kTextBold2(color: const Color(0xFF15803D)),
                      ),
                      Text(
                        'Earned so far',
                        style: kTextNormal0(color: const Color(0xFF16A34A)).copyWith(fontSize: 10.sp),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 14.h),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFDCFCE7),
              valueColor: const AlwaysStoppedAnimation<Color>(kSuccessColor),
              minHeight: 8.h,
            ),
          ),
          SizedBox(height: 8.h),
          // Stats row
          Row(
            children: [
              Expanded(
                child: Text(
                  '$completedCount of $total Completed',
                  style: kTextMedium(color: const Color(0xFF166534)).copyWith(fontSize: 12.sp),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppSpacing.sHorizontal,
              if (remaining > 0)
                Expanded(
                  child: Text(
                    '${NumberUtils.formatCurrency(remaining)} remaining',
                    style: kTextNormal0(color: const Color(0xFF16A34A)).copyWith(fontSize: 11.sp),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _collapsibleHeader({
    required String label,
    required IconData icon,
    required Color color,
    required int count,
    required bool expanded,
    required VoidCallback onTap,
  }) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15.sp, color: color),
          SizedBox(width: 6.w),
          Text(
            '$label ($count)',
            style: kTextSemiBold(color: color).copyWith(fontSize: 13.sp),
          ),
          const Spacer(),
          Text(
            expanded ? 'Hide' : 'View',
            style: kTextMedium(color: color).copyWith(fontSize: 12.sp),
          ),
          SizedBox(width: 6.w),
          AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: EdgeInsets.all(2.r),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(Icons.keyboard_arrow_down_rounded, size: 16.sp, color: color),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Session card ─────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final SubBlock block;
  final _SessionState state;
  final Color stateColor;
  final IconData stateIcon;
  final String stateLabel;
  final ProviderServiceRequestModel request;
  final void Function(SubBlock) onStartBooking;
  final void Function(SubBlock) onCompleteBooking;
  final String countdown;
  final bool isFullDay;
  final bool isExpired;

  static const _purple = kSecondaryColor;
  static const _greyText = Color(0xFF6B7280);

  const _SessionCard({
    required this.block,
    required this.state,
    required this.stateColor,
    required this.stateIcon,
    required this.stateLabel,
    required this.request,
    required this.onStartBooking,
    required this.onCompleteBooking,
    required this.countdown,
    required this.isFullDay,
    this.isExpired = false,
  });

  bool get _isOngoing => state == _SessionState.ongoing;

  bool get _isReadyToStart => state == _SessionState.readyToStart;

  bool get _isCompleted => state == _SessionState.completed;

  bool get _isCancelled => state == _SessionState.cancelled;

  void _openDetail(BuildContext context) {
    SessionDetailSheet.show(
      context: context,
      block: block,
      request: request,
      isReadyToStart: _isReadyToStart,
      isOngoing: _isOngoing,
      isCompleted: _isCompleted,
      isCancelled: _isCancelled,
      isExpired: isExpired,
      onStart: onStartBooking,
      onComplete: onCompleteBooking,
      onCancelled: () => context.read<ProviderRequestDetailBloc>().add(RefreshProviderRequestDetail()),
    );
  }
  static const _orange = Color(0xFFD97706);

  void _showExpiredMessage(BuildContext context) {
    DialogHelper.showError(
      title: 'Session Time Ended',
      message:
          'This session\'s scheduled time has already passed. You can no longer start it. Please contact support if you need help.',
      buttonText: 'OK',
    );
  }

  DateTime? get _sessionStart {
    try {
      final date = DateTime.parse(block.scheduledDate);
      final parts = block.scheduledStartTime.split(':');
      return DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(parts[0]),
        int.parse(parts.length > 1 ? parts[1] : '0'),
      );
    } catch (_) {
      return null;
    }
  }

  void _showUpcomingMessage(BuildContext context) {
    final start = _sessionStart;
    final message = start == null
        ? 'You can start this session 30 minutes before its scheduled shift time.'
        : 'This session is scheduled for ${AppDateFormatter.dayMonthShort(block.scheduledDate)} at '
              '${AppDateFormatter.timeOnly(start)}. You can start it from '
              '${AppDateFormatter.timeOnly(start.subtract(const Duration(minutes: 30)))} — 30 minutes before the shift begins.';
    DialogHelper.showWarning(
      title: 'Too Early to Start',
      message: message,
      buttonText: 'OK',
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openDetail(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: _isOngoing
              ? _purple.withValues(alpha: 0.04)
              : _isReadyToStart
              ? const Color(0xFFFFFBEB)
              : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: _isOngoing
                ? _purple.withValues(alpha: 0.35)
                : _isReadyToStart
                ? const Color(0xFFFDE68A)
                : Colors.grey.shade200,
            width: (_isOngoing || _isReadyToStart) ? 1.5 : 1,
          ),
          boxShadow: [
            if (_isOngoing)
              BoxShadow(color: _purple.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4)),
            if (_isReadyToStart)
              BoxShadow(
                color: const Color(0xFFD97706).withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            if (!_isOngoing && !_isReadyToStart)
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopRow(),
              SizedBox(height: 10.h),
              _buildTimeRow(),
              if (countdown.isNotEmpty) ...[SizedBox(height: 6.h), _buildCountdown()],
              if (_buildCTA(context) != null) ...[SizedBox(height: 12.h), _buildCTA(context)!],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow() {
    final badgeColor = isExpired ? Colors.grey.shade600 : stateColor;
    final badgeIcon = isExpired ? Icons.block_rounded : stateIcon;
    final badgeLabel = isExpired ? 'Expired' : stateLabel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date badge
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: stateColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Column(
            children: [
              Text(
                AppDateFormatter.dayNum(block.scheduledDate),
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: stateColor, height: 1),
              ),
              Text(
                AppDateFormatter.weekdayShort(block.scheduledDate),
                style: TextStyle(fontSize: 9.sp, color: stateColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppDateFormatter.dayMonthShort(block.scheduledDate), style: kTextSemiBold1()),
              SizedBox(height: 2.h),
              Text(
                NumberUtils.formatCurrency(block.providerPayout),
                style: kTextBold1(color: _isCancelled ? Colors.grey.shade500 : kSuccessColor).copyWith(
                  decoration: _isCancelled ? TextDecoration.lineThrough : null,
                ),
              ),
              if (_isCancelled) ...[
                SizedBox(height: 1.h),
                Text(
                  'Not earned — cancelled',
                  style: kTextNormal0(color: Colors.grey.shade500).copyWith(fontSize: 10.sp),
                ),
              ],
            ],
          ),
        ),
        // State badge
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isOngoing) ...[_PulsingDot(color: _purple), SizedBox(width: 5.w)],
              Icon(badgeIcon, size: 11.sp, color: badgeColor),
              SizedBox(width: 4.w),
              Text(
                badgeLabel,
                style: kTextSemiBold0(color: badgeColor).copyWith(fontSize: 10.sp),
              ),
            ],
          ),
        ),
        SizedBox(width: 6.w),
        Icon(Icons.chevron_right_rounded, size: 18.sp, color: _greyText),
      ],
    );
  }

  Widget _buildTimeRow() => Row(
    children: [
      Icon(Icons.schedule_rounded, size: 13.sp, color: _greyText),
      SizedBox(width: 5.w),
      Flexible(
        child: Text(
          AppDateFormatter.shiftTimeRange(
            block.scheduledStartTime,
            block.scheduledEndTime,
            isFullDay: block.isFullDay,
          ),
          style: kTextNormal0(color: _greyText).copyWith(fontSize: 12.sp),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  Widget _buildCountdown() => Row(
    children: [
      Icon(Icons.timer_outlined, size: 12.sp, color: _isReadyToStart ? const Color(0xFFD97706) : kPrimaryColor),
      SizedBox(width: 4.w),
      Text(
        countdown,
        style: kTextMedium(
          color: _isReadyToStart ? const Color(0xFFD97706) : kPrimaryColor,
        ).copyWith(fontSize: 11.sp),
      ),
    ],
  );

  Widget? _buildCTA(BuildContext context) {
    if (_isCompleted || _isCancelled) return null;

    if (_isOngoing) {
      return SizedBox(
        width: double.infinity,
        height: 42.h,
        child: ElevatedButton.icon(
          onPressed: () => onCompleteBooking(block),
          icon: Icon(Icons.verified_rounded, size: 16.sp),
          label: Text(
            'Complete Session',
            style: kTextSemiBold(color: Colors.white).copyWith(fontSize: 13.sp),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _purple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
            elevation: 0,
          ),
        ),
      );
    }

    if (_isReadyToStart) {
      final isWaitingForPayment =
          request.isEmergency == 1 &&
          request.requestStatus.toLowerCase() == 'accepted' &&
          request.paymentStatus.toLowerCase() == 'pending';

      final disabled = isWaitingForPayment || isExpired;

      final String label;
      final IconData icon;
      if (isExpired) {
        label = 'Session time has ended';
        icon = Icons.block_rounded;
      } else if (isWaitingForPayment) {
        label = 'Waiting for customer payment';
        icon = Icons.hourglass_empty_rounded;
      } else {
        label = 'Start Session';
        icon = Icons.play_circle_rounded;
      }

      // Expired: keep tappable so we can explain why it can't start.
      // Waiting for payment: hard-disabled (null).
      final VoidCallback? onPressed = isExpired
          ? () => _showExpiredMessage(context)
          : (isWaitingForPayment ? null : () => onStartBooking(block));

      return SizedBox(
        width: double.infinity,
        height: 42.h,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16.sp),
          label: Text(
            label,
            style: kTextSemiBold(
              color: disabled ? Colors.grey.shade600 : Colors.white,
            ).copyWith(fontSize: 13.sp),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: disabled ? Colors.grey.shade200 : _orange,
            foregroundColor: disabled ? Colors.grey.shade600 : Colors.white,
            disabledBackgroundColor: Colors.grey.shade200,
            disabledForegroundColor: Colors.grey.shade600,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
            elevation: 0,
          ),
        ),
      );
    }

    // Upcoming — not yet ready; tapping explains when it unlocks.
    return SizedBox(
      width: double.infinity,
      height: 42.h,
      child: ElevatedButton.icon(
        onPressed: () => _showUpcomingMessage(context),
        icon: Icon(Icons.play_circle_rounded, size: 16.sp),
        label: Text(
          'Start Session',
          style: kTextSemiBold(color: Colors.grey.shade600).copyWith(fontSize: 13.sp),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.grey.shade600,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        ),
      ),
    );
  }
}

// ─── Pulsing dot for live sessions ───────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
      builder: (_, _) => Container(
        width: 7.w,
        height: 7.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: _anim.value),
        ),
      ),
    );
  }
}
