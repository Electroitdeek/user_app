import 'package:flutter/material.dart';

import '../../../../core/services/app_clock.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../di/locator.dart';
import '../model/sub_block_detail_model.dart';

enum SubBlockStatus { pending, assigned, inProgress, completed, cancelled, expired, unknown }

class SubBlockDisplayConfig {
  final String label;
  final String message;
  final Color primaryColor;
  final Color bgColor;
  final IconData icon;
  final bool isTerminal;
  final bool isLive;

  const SubBlockDisplayConfig({
    required this.label,
    required this.message,
    required this.primaryColor,
    required this.bgColor,
    required this.icon,
    this.isTerminal = false,
    this.isLive = false,
  });
}

class SubBlockStatusMapper {
  SubBlockStatusMapper._();

  /// `isExpired` overrides pending/assigned statuses to `expired` when the
  /// scheduled end time has passed without the session being started.
  static SubBlockStatus fromString(String raw, {bool isExpired = false}) {
    switch (raw.toLowerCase()) {
      case 'pending':
      case 'accepted':
        return isExpired ? SubBlockStatus.expired : SubBlockStatus.pending;
      case 'assigned':
        return isExpired ? SubBlockStatus.expired : SubBlockStatus.assigned;
      case 'in_progress':
        return SubBlockStatus.inProgress;
      case 'completed':
        return SubBlockStatus.completed;
      case 'cancelled':
        return SubBlockStatus.cancelled;
      default:
        return SubBlockStatus.unknown;
    }
  }

  /// True once `scheduledEndTime` (combined with `scheduledDate`, accounting
  /// for overnight shifts) is in the past. Only meaningful for sessions that
  /// never started — a session in progress is never "expired".
  static bool computeExpired({
    required String status,
    required String scheduledDate,
    required String scheduledStartTime,
    required String scheduledEndTime,
  }) {
    final lower = status.toLowerCase();
    if (lower != 'pending' && lower != 'accepted' && lower != 'assigned') return false;

    final date = DateTime.tryParse(scheduledDate);
    if (date == null) return false;

    DateTime? at(String time) {
      final p = time.split(':');
      if (p.isEmpty) return null;
      final h = int.tryParse(p[0]);
      if (h == null) return null;
      final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
      return DateTime(date.year, date.month, date.day, h, m);
    }

    final start = at(scheduledStartTime);
    var end = at(scheduledEndTime);
    if (end == null) return false;
    if (start != null && !end.isAfter(start)) end = end.add(const Duration(days: 1));

    return locator<AppClock>().now.isAfter(end);
  }

  static SubBlockDisplayConfig getConfig(SubBlockStatus status) {
    switch (status) {
      case SubBlockStatus.pending:
        return SubBlockDisplayConfig(
          label: 'Confirmed',
          message: 'Your session is confirmed. A healthcare partner will be assigned shortly.',
          primaryColor: kSecondaryColor,
          bgColor: kSecondaryColor.withValues(alpha: 0.1),
          icon: Icons.verified_rounded,
        );
      case SubBlockStatus.assigned:
        return SubBlockDisplayConfig(
          label: 'Confirmed',
          message: 'Your healthcare partner has been assigned for this session.',
          primaryColor: kSecondaryColor,
          bgColor: kSecondaryColor.withValues(alpha: 0.1),
          icon: Icons.person_pin_circle_rounded,
        );
      case SubBlockStatus.inProgress:
        return SubBlockDisplayConfig(
          label: 'In Progress',
          message: 'Session is currently in progress.',
          primaryColor: kPrimaryColor,
          bgColor: kPrimaryColor.withValues(alpha: 0.1),
          icon: Icons.play_circle_rounded,
          isLive: true,
        );
      case SubBlockStatus.completed:
        return SubBlockDisplayConfig(
          label: 'Completed',
          message: 'Session completed successfully.',
          primaryColor: kSuccessColor,
          bgColor: kSuccessColor.withValues(alpha: 0.1),
          icon: Icons.task_alt_rounded,
          isTerminal: true,
        );
      case SubBlockStatus.cancelled:
        return SubBlockDisplayConfig(
          label: 'Cancelled',
          message: 'This session has been cancelled.',
          primaryColor: kErrorColor,
          bgColor: kErrorColor.withValues(alpha: 0.1),
          icon: Icons.cancel_rounded,
          isTerminal: true,
        );
      case SubBlockStatus.expired:
        return SubBlockDisplayConfig(
          label: 'Expired',
          message: 'This session window has passed without being started.',
          primaryColor: kTextSecondaryColor,
          bgColor: kTextSecondaryColor.withValues(alpha: 0.1),
          icon: Icons.timer_off_rounded,
          isTerminal: true,
        );
      default:
        return SubBlockDisplayConfig(
          label: 'Unknown',
          message: '',
          primaryColor: kTextSecondaryColor,
          bgColor: const Color(0xFFF3F4F6),
          icon: Icons.info_rounded,
        );
    }
  }

  static bool isTerminal(SubBlockStatus status) =>
      status == SubBlockStatus.completed ||
      status == SubBlockStatus.cancelled ||
      status == SubBlockStatus.expired;
}

// ─── Timeline ────────────────────────────────────────────────────────────────

enum TimelineStepState { completed, active, upcoming, cancelled }

class TimelineStep {
  final String label;
  final String? timestamp;
  final TimelineStepState state;

  const TimelineStep({required this.label, this.timestamp, required this.state});
}

class TimelineStateBuilder {
  TimelineStateBuilder._();

  static const _order = [
    SubBlockStatus.pending,
    SubBlockStatus.assigned,
    SubBlockStatus.inProgress,
    SubBlockStatus.completed,
  ];

  static bool _atLeast(SubBlockStatus current, SubBlockStatus target) =>
      _order.indexOf(current) >= _order.indexOf(target);

  static List<TimelineStep> build(SubBlockDetailModel data, SubBlockStatus status) {
    final scheduledDate = AppDateFormatter.dateFromApi(data.scheduledDateText);
    final startEndTime = AppDateFormatter.shiftTimeRange(data.scheduledStartTime, data.scheduledEndTime);
    final scheduledTs = '$scheduledDate · $startEndTime';

    if (status == SubBlockStatus.cancelled) {
      return [
        TimelineStep(label: 'Scheduled', timestamp: scheduledDate, state: TimelineStepState.completed),
        TimelineStep(label: 'Cancelled', timestamp: data.updatedAt, state: TimelineStepState.cancelled),
      ];
    }

    return [
      TimelineStep(label: 'Scheduled', timestamp: scheduledTs, state: TimelineStepState.completed),
      // TimelineStep(
      //   label: 'Assigned',
      //   timestamp: _atLeast(status, SubBlockStatus.assigned) ? data.updatedAt : null,
      //   state: _atLeast(status, SubBlockStatus.assigned)
      //       ? TimelineStepState.completed
      //       : TimelineStepState.upcoming,
      // ),
      TimelineStep(
        label: 'Started',
        timestamp: data.actualStartTime,
        state: _atLeast(status, SubBlockStatus.inProgress)
            ? TimelineStepState.completed
            : status == SubBlockStatus.assigned
            ? TimelineStepState.active
            : TimelineStepState.upcoming,
      ),
      TimelineStep(
        label: 'Completed',
        timestamp: data.actualEndTime,
        state: status == SubBlockStatus.completed ? TimelineStepState.completed : TimelineStepState.upcoming,
      ),
    ];
  }
}

// ─── Action Resolver ─────────────────────────────────────────────────────────

class SubBlockActionResolver {
  SubBlockActionResolver._();

  static bool showCancel(SubBlockStatus status) =>
      status == SubBlockStatus.pending || status == SubBlockStatus.assigned;

  static bool showCallProvider(SubBlockStatus status, bool hasProvider) =>
      hasProvider &&
      (status == SubBlockStatus.assigned ||
          status == SubBlockStatus.inProgress);

  static bool showRaiseIssue(SubBlockStatus status) => true;
}
