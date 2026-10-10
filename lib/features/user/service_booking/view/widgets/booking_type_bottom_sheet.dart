import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_edge_insets.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/theme/screen_dimensions.dart';

class BookingTypeBottomSheet extends StatelessWidget {
  final VoidCallback onOneDay;
  final VoidCallback onLongBooking;

  const BookingTypeBottomSheet({super.key, required this.onOneDay, required this.onLongBooking});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kScaffoldColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: 10.h, bottom: 6.h),
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(2.r)),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
              decoration: BoxDecoration(
                color: kWhiteColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: AppPadding.s,
                        decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.10), borderRadius: AppRadius.m),
                        child: Icon(Icons.calendar_month_rounded, color: kPrimaryColor, size: 20.sp),
                      ),
                      AppSpacing.mHorizontal,
                      Expanded(child: Text('Select Booking Type', style: kTextBold2())),
                    ],
                  ),
                  AppSpacing.xsVertical,
                  Padding(
                    padding: EdgeInsets.only(left: 40.w),
                    child: Text('Choose how you\'d like to book this service', style: kTextNormal0(color: kTextSecondaryColor)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
              child: Column(
                children: [
                  _BookingTypeOption(
                    icon: Icons.calendar_today_outlined,
                    accentColor: kPrimaryColor,
                    tag: 'Hourly / Single Visit',
                    title: 'Procedural',
                    subtitle: 'Book service for specific hours or a one-time visit',
                    onTap: onOneDay,
                  ),
                  AppSpacing.mVertical,
                  _BookingTypeOption(
                    icon: Icons.event_repeat_outlined,
                    accentColor: kAccentColor,
                    tag: 'Multi-Day Package',
                    title: 'Long Duration / Package',
                    subtitle: 'Book service for multiple days with special packages',
                    onTap: onLongBooking,
                  ),
                ],
              ),
            ),
            AppSpacing.xlVertical,
          ],
          ),
        ),
      ),
    );
  }
}

class _BookingTypeOption extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String tag;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BookingTypeOption({
    required this.icon,
    required this.accentColor,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.xl,
        child: Ink(
          decoration: BoxDecoration(
            color: kWhiteColor,
            borderRadius: AppRadius.xl,
            border: Border.all(color: accentColor.withValues(alpha: 0.25)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Padding(
            padding: AppPadding.l,
            child: Row(
              children: [
                Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.10), borderRadius: AppRadius.l),
                  child: Icon(icon, color: accentColor, size: 26.sp),
                ),
                AppSpacing.mHorizontal,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(4.r)),
                        child: Text(tag, style: kTextNormal0(color: accentColor)),
                      ),
                      AppSpacing.xsVertical,
                      Text(title, style: kTextBold1()),
                      AppSpacing.xsVertical,
                      Text(
                        subtitle,
                        style: kTextNormal0(color: kTextSecondaryColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                AppSpacing.mHorizontal,
                Container(
                  padding: AppPadding.xs,
                  decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.10), shape: BoxShape.circle),
                  child: Icon(Icons.arrow_forward_ios_rounded, color: accentColor, size: 14.sp),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
