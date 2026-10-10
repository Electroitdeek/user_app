import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/features/user/booking_history/model/booking_detail_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SessionScheduleSheet extends StatelessWidget {
  final ScrollController controller;
  final ServiceRequestDetail sr;

  const SessionScheduleSheet({super.key, required this.controller, required this.sr});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          const _SheetHandle(),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 8.w, 14.h),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Full Schedule', style: kTextBold2(color: kTextPrimaryColor)),
                      SizedBox(height: 4.h),
                      Text(
                        '${AppDateFormatter.dateFromApi(sr.startDate)} → ${AppDateFormatter.dateFromApi(sr.endDateText)}  ·  ${sr.subBlocks.length} sessions',
                        style: kTextNormal0(color: kTextSecondaryColor),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, size: 20.sp, color: kTextSecondaryColor),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: kBorderColor),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView.separated(
                controller: controller,
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
                itemCount: sr.subBlocks.length,
                separatorBuilder: (_, _) => SizedBox(height: 8.h),
                itemBuilder: (_, i) => _ScheduleSessionRow(block: sr.subBlocks[i], index: i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleSessionRow extends StatelessWidget {
  final SubBlock block;
  final int index;

  const _ScheduleSessionRow({required this.block, required this.index});

  @override
  Widget build(BuildContext context) {
    final color = block.isCompleted
        ? kSuccessColor
        : block.isCancelled
        ? kErrorColor
        : block.isExpired
        ? kTextSecondaryColor
        : block.isConfirmed
        ? kPrimaryColor
        : kAccentColor;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32.r,
            height: 32.r,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Center(
              child: Text('${index + 1}', style: kTextSemiBold0(color: color)),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppDateFormatter.dateWithWeekday(block.scheduledDate),
                        style: kTextSemiBold(color: kTextPrimaryColor),
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        block.isExpired
                            ? 'Expired'
                            : block.isConfirmed
                            ? 'Confirmed'
                            : block.statusText,
                        style: kTextBold0(color: color),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 11.sp, color: kTextSecondaryColor),
                    SizedBox(width: 3.w),
                    Flexible(
                      child: Text(
                        AppDateFormatter.shiftTimeRange(block.scheduledStartTime, block.scheduledEndTime),
                        style: kTextNormal0(color: kTextSecondaryColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 12.h, bottom: 4.h),
      child: Center(
        child: Container(
          width: 36.w,
          height: 4.h,
          decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(2.r)),
        ),
      ),
    );
  }
}
