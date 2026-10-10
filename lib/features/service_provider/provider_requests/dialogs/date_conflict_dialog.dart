import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';

class DateConflictDialog {
  static void show(
    BuildContext context, {
    required List<String> conflictDates,
    String? message,
    VoidCallback? onDismissed,
    VoidCallback? onGoToSchedule,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _DateConflictContent(
        conflictDates: conflictDates,
        message: message,
        onDismissed: onDismissed,
        onGoToSchedule: onGoToSchedule,
      ),
    );
  }
}

/// Groups a sorted list of dates into consecutive ranges.
List<(DateTime, DateTime)> _groupIntoRanges(List<DateTime> sorted) {
  if (sorted.isEmpty) return [];
  final ranges = <(DateTime, DateTime)>[];
  var start = sorted.first;
  var prev = sorted.first;
  for (final d in sorted.skip(1)) {
    if (d.difference(prev).inDays == 1) {
      prev = d;
    } else {
      ranges.add((start, prev));
      start = d;
      prev = d;
    }
  }
  ranges.add((start, prev));
  return ranges;
}

class _DateConflictContent extends StatelessWidget {
  final List<String> conflictDates;
  final String? message;
  final VoidCallback? onDismissed;
  final VoidCallback? onGoToSchedule;

  const _DateConflictContent({
    required this.conflictDates,
    this.message,
    this.onDismissed,
    this.onGoToSchedule,
  });

  List<(DateTime, DateTime)> get _ranges {
    final parsed = conflictDates
        .map((d) {
          try {
            return DateTime.parse(d);
          } catch (_) {
            return null;
          }
        })
        .whereType<DateTime>()
        .toList()
      ..sort((a, b) => a.compareTo(b));
    return _groupIntoRanges(parsed);
  }

  String _fmtStart(DateTime start, DateTime end) {
    final sameMonth = start.month == end.month && start.year == end.year;
    if (start == end) return DateFormat('dd MMM yyyy').format(start);
    if (sameMonth) return '${start.day}';
    return DateFormat('dd MMM').format(start);
  }

  String _fmtEnd(DateTime end) => DateFormat('dd MMM yyyy').format(end);

  String _rangeText(DateTime start, DateTime end) {
    if (start == end) return DateFormat('dd MMM yyyy').format(start);
    return '${_fmtStart(start, end)} – ${_fmtEnd(end)}';
  }

  int _dayCount(DateTime start, DateTime end) =>
      end.difference(start).inDays + 1;

  @override
  Widget build(BuildContext context) {
    final ranges = _ranges;
    final totalDays = conflictDates.length;

    return PopScope(
      onPopInvokedWithResult: (_, _) => onDismissed?.call(),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 32,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top header with gradient ───────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 28.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFF7ED),
                      const Color(0xFFFEF3C7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                ),
                child: Column(
                  children: [
                    // Icon container with layered rings
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 80.w,
                          height: 80.w,
                          decoration: BoxDecoration(
                            color: kWarningColor.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 60.w,
                          height: 60.w,
                          decoration: BoxDecoration(
                            color: kWarningColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 44.w,
                          height: 44.w,
                          decoration: BoxDecoration(
                            color: kWarningColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.event_busy_rounded,
                            color: Colors.white,
                            size: 22.sp,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      'Schedule Conflict',
                      style: kTextBold2().copyWith(
                        color: const Color(0xFF1C1917),
                        fontSize: 18.sp,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 28.w),
                      child: Text(
                        message?.isNotEmpty == true
                            ? message!
                            : "You're already booked on $totalDays date${totalDays > 1 ? 's' : ''} that overlap with this request.",
                        style: kTextNormal(color: const Color(0xFF78716C)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Body ───────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section label
                    Row(
                      children: [
                        Container(
                          width: 3.w,
                          height: 14.h,
                          decoration: BoxDecoration(
                            color: kWarningColor,
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Conflicting Period${ranges.length > 1 ? 's' : ''}',
                          style: kTextSemiBold1(color: const Color(0xFF1C1917))
                              .copyWith(fontSize: 13.sp),
                        ),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                                color: kWarningColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '$totalDays day${totalDays > 1 ? 's' : ''} blocked',
                            style: kTextSemiBold0(color: kWarningColor)
                                .copyWith(fontSize: 10.sp),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),

                    // Range cards
                    if (ranges.isNotEmpty)
                      ...ranges.map((r) {
                        final days = _dayCount(r.$1, r.$2);
                        final isSingle = r.$1 == r.$2;
                        return Padding(
                          padding: EdgeInsets.only(bottom: 8.h),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 14.w, vertical: 12.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBF5),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Calendar day-of-month chip
                                Container(
                                  width: 36.w,
                                  height: 36.w,
                                  decoration: BoxDecoration(
                                    color: kWarningColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        DateFormat('dd').format(r.$1),
                                        style: kTextBold1(color: kWarningColor)
                                            .copyWith(
                                                fontSize: 14.sp, height: 1.1),
                                      ),
                                      Text(
                                        DateFormat('MMM').format(r.$1).toUpperCase(),
                                        style: kTextSemiBold0(color: kWarningColor)
                                            .copyWith(fontSize: 8.sp, height: 1.1),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _rangeText(r.$1, r.$2),
                                        style: kTextSemiBold(
                                                color: const Color(0xFF1C1917))
                                            .copyWith(fontSize: 13.sp),
                                      ),
                                      if (!isSingle)
                                        Text(
                                          '$days consecutive days',
                                          style: kTextNormal0(
                                                  color: const Color(0xFF78716C))
                                              .copyWith(fontSize: 11.sp),
                                        ),
                                    ],
                                  ),
                                ),
                                // Day count badge
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: kWarningColor,
                                    borderRadius: BorderRadius.circular(20.r),
                                  ),
                                  child: Text(
                                    isSingle ? '1d' : '${days}d',
                                    style: kTextBold0(color: Colors.white)
                                        .copyWith(fontSize: 10.sp),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                    SizedBox(height: 6.h),

                    // Tip
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline_rounded,
                              size: 14.sp, color: const Color(0xFF16A34A)),
                          SizedBox(width: 7.w),
                          Expanded(
                            child: Text(
                              'To accept this request, please choose those slots which you are free.',
                              style: kTextNormal0(
                                      color: const Color(0xFF15803D))
                                  .copyWith(fontSize: 11.sp),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20.h),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              onDismissed?.call();
                            },
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 13.h),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14.r)),
                              side: BorderSide(
                                  color: const Color(0xFFE5E7EB)),
                            ),
                            child: Text('Close',
                                style: kTextSemiBold1(
                                    color: const Color(0xFF374151))),
                          ),
                        ),
                        if (onGoToSchedule != null) ...[
                          SizedBox(width: 10.w),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                onGoToSchedule?.call();
                              },
                              icon: Icon(Icons.calendar_month_rounded,
                                  size: 16.sp, color: Colors.white),
                              label: Text('Schedule',
                                  style: kTextSemiBold1(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryColor,
                                padding:
                                    EdgeInsets.symmetric(vertical: 13.h),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14.r)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ] else ...[
                          SizedBox(width: 10.w),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                onDismissed?.call();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryColor,
                                padding:
                                    EdgeInsets.symmetric(vertical: 13.h),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14.r)),
                                elevation: 0,
                              ),
                              child: Text('OK, Got It',
                                  style:
                                      kTextSemiBold1(color: Colors.white)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
