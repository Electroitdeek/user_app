import 'package:adhisaat_health_care/shared/widgets/dialogs/dialog_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';

class BookingScheduleSheet extends StatefulWidget {
  final List<String> scheduledDates;
  final bool isMultiDayMode;
  final String? selectedTimeSlot;
  final String Function(String slot) formatSlot;
  final void Function(List<String> updated) onDatesChanged;

  const BookingScheduleSheet({
    super.key,
    required this.scheduledDates,
    required this.isMultiDayMode,
    required this.selectedTimeSlot,
    required this.formatSlot,
    required this.onDatesChanged,
  });

  static Future<void> show({
    required BuildContext context,
    required List<String> scheduledDates,
    required bool isMultiDayMode,
    required String? selectedTimeSlot,
    required String Function(String) formatSlot,
    required void Function(List<String>) onDatesChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: kWhiteColor,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24.r), topRight: Radius.circular(24.r)),
      ),
      builder: (_) => BookingScheduleSheet(
        scheduledDates: scheduledDates,
        isMultiDayMode: isMultiDayMode,
        selectedTimeSlot: selectedTimeSlot,
        formatSlot: formatSlot,
        onDatesChanged: onDatesChanged,
      ),
    );
  }

  @override
  State<BookingScheduleSheet> createState() => _BookingScheduleSheetState();
}

class _BookingScheduleSheetState extends State<BookingScheduleSheet> {
  late List<String> _dates;

  @override
  void initState() {
    super.initState();
    _dates = List.from(widget.scheduledDates);
  }

  void _removeDate(BuildContext context, int index) {
    if (_dates.length <= 1) {
      DialogHelper.showWarning(
        title: 'Minimum Days Required',
        message: 'A minimum of 1 days is required for booking.',
      );
      return;
    }
    setState(() => _dates.removeAt(index));
    widget.onDatesChanged(List.from(_dates));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: 12.h, bottom: 4.h),
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(2.r)),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Whole Schedule', style: kTextBold1()),
                      Text(
                        'You can remove specific dates below',
                        style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: kTextSecondaryColor, size: 22.sp),
                ),
              ],
            ),
          ),
          Divider(color: kBorderColor, height: 1),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              itemCount: _dates.length,
              itemBuilder: (_, index) {
                final date = DateTime.parse(_dates[index]);
                return Container(
                  margin: EdgeInsets.only(bottom: 8.h),
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: kBorderColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(DateFormat('EEEE, dd MMMM').format(date), style: kTextSemiBold()),
                          if (widget.isMultiDayMode && widget.selectedTimeSlot != null)
                            Text(
                              widget.formatSlot(widget.selectedTimeSlot!),
                              style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
                            ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => _removeDate(context, index),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: _dates.length <= 1 ? kErrorColor.withValues(alpha: 0.3) : kErrorColor,
                          size: 20.sp,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h + MediaQuery.of(context).padding.bottom),
            child: SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                child: Text('Done', style: kTextBold(color: kWhiteColor)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
