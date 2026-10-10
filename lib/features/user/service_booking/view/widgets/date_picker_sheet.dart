import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';

/// Shows a bottom-sheet single-date calendar picker.
///
/// Returns the selected [DateTime] (date only) or `null` if dismissed.
Future<DateTime?> showSingleDatePickerSheet(
  BuildContext context, {
  required String title,
  required DateTime firstDay,
  required DateTime lastDay,
  DateTime? initialDate,
}) async {
  final normFirst = DateUtils.dateOnly(firstDay);
  final normLast = DateUtils.dateOnly(lastDay);

  // Ensure initialDate is valid (between normFirst and normLast)
  DateTime? safeInitial;
  if (initialDate != null) {
    final normInitial = DateUtils.dateOnly(initialDate);
    if (!normInitial.isBefore(normFirst) && !normInitial.isAfter(normLast)) {
      safeInitial = normInitial;
    }
  }

  DateTime focused = safeInitial ?? normFirst;
  if (focused.isBefore(normFirst)) {
    focused = normFirst;
  } else if (focused.isAfter(normLast)) {
    focused = normLast;
  }

  DateTime? picked = safeInitial ?? normFirst;

  await showModalBottomSheet(
    context: context,
    useSafeArea: true,
    backgroundColor: kWhiteColor,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.only(topLeft: Radius.circular(24.r), topRight: Radius.circular(24.r)),
    ),
    builder: (_) => StatefulBuilder(
      builder: (ctx, setSheet) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.73,
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(2.r)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: kTextBold1()),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                      color: kTextSecondaryColor,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: TableCalendar(
                  firstDay: normFirst,
                  lastDay: normLast,
                  focusedDay: focused,
                  selectedDayPredicate: (d) => DateUtils.isSameDay(d, picked),
                  onDaySelected: (selected, newFocused) => setSheet(() {
                    picked = selected;
                    focused = newFocused;
                  }),
                  onPageChanged: (f) => focused = f,
                  calendarFormat: CalendarFormat.month,
                  availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: kTextBold(),
                    leftChevronIcon: Icon(Icons.chevron_left_rounded, color: kPrimaryColor, size: 22.sp),
                    rightChevronIcon: Icon(Icons.chevron_right_rounded, color: kPrimaryColor, size: 22.sp),
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: kPrimaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: kTextMedium(color: kPrimaryColor),
                    selectedDecoration: const BoxDecoration(color: kPrimaryColor, shape: BoxShape.circle),
                    selectedTextStyle: kTextMedium(color: kWhiteColor),
                    outsideDaysVisible: false,
                  ),
                  enabledDayPredicate: (d) => !d.isBefore(firstDay),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 28.h),
                child: SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: picked == null ? null : () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      disabledBackgroundColor: kBorderColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    child: Text('Confirm', style: kTextBold(color: kWhiteColor)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  return picked != null ? DateUtils.dateOnly(picked!) : null;
}

/// Shows a bottom-sheet range calendar picker.
///
/// Returns `(start, end)` record or `null` if dismissed.
// Future<(DateTime, DateTime)?> showDateRangePickerSheet(
//   BuildContext context, {
//   DateTime? initialStart,
//   DateTime? initialEnd,
// }) async {
//   final today = DateUtils.dateOnly(DateTime.now());
//   final firstDay = today.add(const Duration(days: 1));
//   final lastDay = today.add(const Duration(days: 90));
//
//   DateTime? sheetStart = initialStart;
//   DateTime? sheetEnd = initialEnd;
//   (DateTime, DateTime)? result;
//
//   await showModalBottomSheet(
//     context: context,
//     useSafeArea: true,
//     backgroundColor: kWhiteColor,
//     isScrollControlled: true,
//     shape: RoundedRectangleBorder(
//       borderRadius: BorderRadius.only(
//         topLeft: Radius.circular(24.r),
//         topRight: Radius.circular(24.r),
//       ),
//     ),
//     builder: (_) => StatefulBuilder(
//       builder: (ctx, setSheetState) {
//         final dayCount = (sheetStart != null && sheetEnd != null) ? sheetEnd!.difference(sheetStart!).inDays + 1 : 0;
//
//         return DraggableScrollableSheet(
//           initialChildSize: 0.7,
//           minChildSize: 0.5,
//           maxChildSize: 0.85,
//           expand: false,
//           builder: (ctx2, scrollController) => SafeArea(
//             child: Column(
//               children: [
//                 Container(
//                   margin: EdgeInsets.only(top: 12.h, bottom: 4.h),
//                   width: 40.w,
//                   height: 4.h,
//                   decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(2.r)),
//                 ),
//                  Padding(
//                   padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text('Select Date Range', style: kTextBold1()),
//                             SizedBox(height: 2.h),
//                             Text(
//                               dayCount > 0
//                                   ? '${DateFormat('dd MMM').format(sheetStart!)} - ${DateFormat('dd MMM').format(sheetEnd!)}'
//                                   : sheetStart != null
//                                   ? '${DateFormat('dd MMM').format(sheetStart!)} - Select end date'
//                                   : 'Tap start date, then end date',
//                               style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
//                             ),
//                           ],
//                         ),
//                       ),
//                       if (dayCount > 0) ...[
//                         SizedBox(width: 8.w),
//                         Container(
//                           padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
//                           decoration: BoxDecoration(
//                             color: kPrimaryColor.withValues(alpha: 0.1),
//                             borderRadius: BorderRadius.circular(20.r),
//                           ),
//                           child: Text(
//                             '$dayCount days',
//                             style: kTextSemiBold(color: kPrimaryColor).copyWith(fontSize: 12.sp),
//                           ),
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
//                 Divider(color: kBorderColor, height: 1),
//                 Expanded(
//                   child: SingleChildScrollView(
//                     controller: scrollController,
//                     child: TableCalendar(
//                       firstDay: firstDay,
//                       lastDay: lastDay,
//                       focusedDay: sheetStart ?? firstDay,
//                       rangeStartDay: sheetStart,
//                       rangeEndDay: sheetEnd,
//                       rangeSelectionMode: RangeSelectionMode.enforced,
//                       onRangeSelected: (start, end, focused) => setSheetState(() {
//                         sheetStart = start;
//                         sheetEnd = end;
//                       }),
//                       calendarFormat: CalendarFormat.month,
//                       availableCalendarFormats: const {CalendarFormat.month: 'Month'},
//                       headerStyle: HeaderStyle(
//                         formatButtonVisible: false,
//                         titleCentered: true,
//                         titleTextStyle: kTextBold(),
//                         leftChevronIcon: Icon(Icons.chevron_left_rounded, color: kPrimaryColor, size: 22.sp),
//                         rightChevronIcon: Icon(Icons.chevron_right_rounded, color: kPrimaryColor, size: 22.sp),
//                       ),
//                       calendarStyle: CalendarStyle(
//                         todayDecoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.15), shape: BoxShape.circle),
//                         todayTextStyle: kTextMedium(color: kPrimaryColor),
//                         rangeHighlightColor: kPrimaryColor.withValues(alpha: 0.12),
//                         rangeStartDecoration: const BoxDecoration(color: kPrimaryColor, shape: BoxShape.circle),
//                         rangeStartTextStyle: kTextMedium(color: kWhiteColor),
//                         rangeEndDecoration: const BoxDecoration(color: kPrimaryColor, shape: BoxShape.circle),
//                         rangeEndTextStyle: kTextMedium(color: kWhiteColor),
//                         withinRangeTextStyle: kTextMedium(color: kTextPrimaryColor),
//                         outsideDaysVisible: false,
//                         disabledTextStyle: kTextNormal(color: kBorderColor),
//                       ),
//                       enabledDayPredicate: (d) => !d.isBefore(firstDay),
//                     ),
//                   ),
//                 ),
//                 Container(
//                   padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
//                   decoration: BoxDecoration(
//                     color: kWhiteColor,
//                     boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
//                   ),
//                   child: SizedBox(
//                     width: double.infinity,
//                     height: 48.h,
//                     child: ElevatedButton(
//                       onPressed: sheetStart == null || sheetEnd == null
//                           ? null
//                           : () {
//                               result = (DateUtils.dateOnly(sheetStart!), DateUtils.dateOnly(sheetEnd!));
//                               Navigator.pop(ctx);
//                             },
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: kPrimaryColor,
//                         disabledBackgroundColor: kBorderColor,
//                         elevation: 0,
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
//                       ),
//                       child: Text('Confirm Dates', style: kTextBold(color: kWhiteColor)),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     ),
//   );
//
//   return result;
// }
