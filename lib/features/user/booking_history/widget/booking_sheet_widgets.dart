import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BookingSheetHandle extends StatelessWidget {
  const BookingSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 12.h, bottom: 4.h),
      child: Center(
        child: Container(
          width: 36.w,
          height: 4.h,
          decoration: BoxDecoration(
            color: kBorderColor,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
      ),
    );
  }
}

class BreakdownSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const BreakdownSection({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Text(title, style: kTextSemiBold(color: kTextSecondaryColor)),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: const Color(0xFFEDF0F7)),
          ),
          child: Column(
            children: children
                .asMap()
                .entries
                .map(
                  (e) => Column(
                    children: [
                      e.value,
                      if (e.key < children.length - 1)
                        Divider(height: 1, color: const Color(0xFFEDF0F7), indent: 14.w),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class BreakdownRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color? color;

  const BreakdownRow({super.key, required this.label, required this.amount, this.color});

  @override
  Widget build(BuildContext context) {
    final isNegative = amount < 0;
    final displayColor = color ?? (isNegative ? kSuccessColor : kTextPrimaryColor);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
      child: Row(
        children: [
          Expanded(child: Text(label, style: kTextNormal(color: kTextPrimaryColor))),
          Text(
            isNegative
                ? '- ${NumberUtils.formatCurrency(amount.abs())}'
                : NumberUtils.formatCurrency(amount),
            style: kTextSemiBold(color: displayColor),
          ),
        ],
      ),
    );
  }
}
