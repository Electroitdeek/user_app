import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';

/// Shows a scroll-wheel AM/PM time picker bottom sheet.
///
/// [initialSlot] — 24-hour string like "08:00"; defaults to 08:00.
/// [isToday]    — when true, times before [minHour] are blocked.
/// [minHour]    — earliest allowed 24-h hour (inclusive) when [isToday].
///
/// Returns a 24-hour time string like "14:30", or null if dismissed.
Future<String?> showCustomTimePickerSheet(
  BuildContext context, {
  String? initialSlot,
  required bool isToday,
  required int minHour,
}) {
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: kWhiteColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.only(topLeft: Radius.circular(24.r), topRight: Radius.circular(24.r)),
    ),
    builder: (_) => _CustomTimePickerSheet(initialSlot: initialSlot, isToday: isToday, minHour: minHour),
  );
}

class _CustomTimePickerSheet extends StatefulWidget {
  const _CustomTimePickerSheet({required this.isToday, required this.minHour, this.initialSlot});

  final String? initialSlot;
  final bool isToday;
  final int minHour;

  @override
  State<_CustomTimePickerSheet> createState() => _CustomTimePickerSheetState();
}

class _CustomTimePickerSheetState extends State<_CustomTimePickerSheet> {
  late int _hour12;
  late int _minute;
  late bool _isAm;

  @override
  void initState() {
    super.initState();
    final rawHour = int.tryParse(widget.initialSlot?.split(':').first ?? '8') ?? 8;
    final rawMinute = int.tryParse(widget.initialSlot?.split(':').last ?? '0') ?? 0;
    _isAm = rawHour < 12;
    _hour12 = rawHour == 0 ? 12 : (rawHour > 12 ? rawHour - 12 : rawHour);
    _minute = rawMinute;
  }

  int get _hour24 {
    int h = _hour12;
    if (_isAm && h == 12) h = 0;
    if (!_isAm && h != 12) h += 12;
    return h;
  }

  bool get _isInvalid => widget.isToday && _hour24 < widget.minHour;

  void _confirm() {
    if (_isInvalid) return;
    final timeStr = '${_hour24.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';
    Navigator.pop(context, timeStr);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: EdgeInsets.only(top: 12.h, bottom: 4.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(2.r)),
            ),
            // Title row
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Select Time', style: kTextBold1()),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: kTextSecondaryColor, size: 22.sp),
                  ),
                ],
              ),
            ),
            Divider(color: kBorderColor, height: 1),
            SizedBox(height: 16.h),
            // Scroll wheels
            SizedBox(
              height: 180.h,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _WheelColumn(
                    itemCount: 12,
                    initialIndex: _hour12 - 1,
                    onChanged: (i) => setState(() => _hour12 = i + 1),
                    labelFor: (i) => (i + 1).toString().padLeft(2, '0'),
                    isSelected: (i) => (i + 1) == _hour12,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Text(
                      ':',
                      style: kTextBold2(color: kTextPrimaryColor).copyWith(fontSize: 22.sp),
                    ),
                  ),
                  _WheelColumn(
                    itemCount: 4,
                    initialIndex: (_minute / 15).round(),
                    onChanged: (i) => setState(() => _minute = i * 15),
                    labelFor: (i) => (i * 15).toString().padLeft(2, '0'),
                    isSelected: (i) => (i * 15) == _minute,
                  ),
                  SizedBox(width: 16.w),
                  // AM/PM toggle
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _AmPmButton(label: 'AM', isActive: _isAm, onTap: () => setState(() => _isAm = true)),
                      SizedBox(height: 8.h),
                      _AmPmButton(label: 'PM', isActive: !_isAm, onTap: () => setState(() => _isAm = false)),
                    ],
                  ),
                ],
              ),
            ),
            // Selection preview + validation
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.w),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
                    decoration: BoxDecoration(
                      color: _isInvalid
                          ? kErrorColor.withValues(alpha: 0.06)
                          : kPrimaryColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isInvalid ? Icons.warning_amber_rounded : Icons.access_time_rounded,
                          size: 16.sp,
                          color: _isInvalid ? kErrorColor : kPrimaryColor,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '${_hour12.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')} ${_isAm ? 'AM' : 'PM'}',
                          style: kTextBold(
                            color: _isInvalid ? kErrorColor : kPrimaryColor,
                          ).copyWith(fontSize: 16.sp),
                        ),
                      ],
                    ),
                  ),
                  if (_isInvalid) ...[
                    SizedBox(height: 4.h),
                    Text(
                      'Please select a future time (after ${_formatSlot24To12('${widget.minHour}:00')})',
                      style: kTextMedium(color: kErrorColor).copyWith(fontSize: 10.sp),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 16.h),
            // Confirm button
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
              child: SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: Text('Confirm Time', style: kTextBold(color: kWhiteColor)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WheelColumn extends StatelessWidget {
  const _WheelColumn({
    required this.itemCount,
    required this.initialIndex,
    required this.onChanged,
    required this.labelFor,
    required this.isSelected,
  });

  final int itemCount;
  final int initialIndex;
  final ValueChanged<int> onChanged;
  final String Function(int index) labelFor;
  final bool Function(int index) isSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70.w,
      child: ListWheelScrollView.useDelegate(
        itemExtent: 44.h,
        diameterRatio: 1.5,
        physics: const FixedExtentScrollPhysics(),
        controller: FixedExtentScrollController(initialItem: initialIndex),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: itemCount,
          builder: (_, i) {
            final sel = isSelected(i);
            return Center(
              child: Text(
                labelFor(i),
                style: sel
                    ? kTextBold2(color: kPrimaryColor).copyWith(fontSize: 22.sp)
                    : kTextNormal(color: kTextHintColor).copyWith(fontSize: 18.sp),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AmPmButton extends StatelessWidget {
  const _AmPmButton({required this.label, required this.isActive, required this.onTap});

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isActive ? kPrimaryColor : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          label,
          style: kTextSemiBold(color: isActive ? kWhiteColor : kTextSecondaryColor).copyWith(fontSize: 13.sp),
        ),
      ),
    );
  }
}

String _formatSlot24To12(String slot) {
  try {
    final parts = slot.split(':');
    final h = int.parse(parts[0]);
    final m = parts[1];
    final period = h < 12 ? 'AM' : 'PM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${displayH.toString().padLeft(2, '0')}:$m $period';
  } catch (_) {
    return slot;
  }
}
