import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/utils/message_service.dart';
import '../../../../../core/utils/number_utils.dart';
import '../../model/service_category_model.dart';

void showPackagePickerSheet(
  BuildContext context, {
  required int scheduledDays,
  required List<RateCardPackageModel> packages,
  required int? selectedPackageId,
  required ValueChanged<int?> onChanged,
  DateTime? startDate,
  ValueChanged<RateCardPackageModel>? onApplyPackage,
}) {
  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    backgroundColor: kWhiteColor,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.only(topLeft: Radius.circular(24.r), topRight: Radius.circular(24.r)),
    ),
    builder: (_) {
      int? currentId = selectedPackageId;
      int currentScheduledDays = scheduledDays;
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          void select(int? id) {
            setSheetState(() => currentId = id);
            onChanged(id);
          }

          void confirmAndApplyPackage(RateCardPackageModel pkg) {
            final start = startDate ?? DateTime.now();
            final end = start.add(Duration(days: pkg.duration - 1));
            final startStr = DateFormat('MMM dd, yyyy').format(start);
            final endStr = DateFormat('MMM dd, yyyy').format(end);
            final hasDiscount = pkg.discountPercentage > 0;
            final discountStr = cleanDecimal(pkg.discountPercentage);
            final savings = pkg.actualPrice - pkg.price;

            showDialog(
              context: ctx,
              builder: (dialogCtx) => Dialog(
                backgroundColor: kWhiteColor,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
                child: Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Icon Badge
                      Container(
                        width: 54.w,
                        height: 54.h,
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.local_offer_rounded,
                          color: kPrimaryColor,
                          size: 26.sp,
                        ),
                      ),
                      SizedBox(height: 14.h),

                      // Title
                      Text(
                        'Apply ${pkg.duration} Days Package',
                        textAlign: TextAlign.center,
                        style: kTextBold1(color: kTextPrimaryColor).copyWith(fontSize: 17.sp),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'This package will update your booking duration and end date.',
                        textAlign: TextAlign.center,
                        style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.5.sp, height: 1.3),
                      ),
                      SizedBox(height: 16.h),

                      // Summary Card
                      Container(
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: kBorderColor.withValues(alpha: 0.6)),
                        ),
                        child: Column(
                          children: [
                            // Duration & Discount row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Package Duration', style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 12.sp)),
                                SizedBox(width: 8.w),
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '${pkg.duration} Days',
                                          style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 13.sp),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (hasDiscount) ...[
                                        SizedBox(width: 6.w),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                          decoration: BoxDecoration(
                                            color: kSuccessColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4.r),
                                          ),
                                          child: Text(
                                            '$discountStr% OFF',
                                            style: kTextSemiBold0(color: kSuccessColor).copyWith(fontSize: 10.sp),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.h),
                              child: Divider(color: kBorderColor.withValues(alpha: 0.5), height: 1),
                            ),
                            // Date Range row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('New Schedule', style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 12.sp)),
                                SizedBox(width: 8.w),
                                Flexible(
                                  child: Text(
                                    '$startStr – $endStr',
                                    textAlign: TextAlign.right,
                                    style: kTextSemiBold(color: kPrimaryColor).copyWith(fontSize: 12.sp),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (hasDiscount && savings > 0) ...[
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                child: Divider(color: kBorderColor.withValues(alpha: 0.5), height: 1),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total Savings', style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 12.sp)),
                                  SizedBox(width: 8.w),
                                  Flexible(
                                    child: Text(
                                      'Save ${NumberUtils.formatCurrency(savings, decimalDigits: 0)}',
                                      textAlign: TextAlign.right,
                                      style: kTextBold(color: kSuccessColor).copyWith(fontSize: 12.5.sp),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: 20.h),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: kBorderColor),
                                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 4.w),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                              ),
                              child: Text(
                                'Cancel',
                                textAlign: TextAlign.center,
                                style: kTextSemiBold(color: kTextSecondaryColor).copyWith(fontSize: 13.sp),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(dialogCtx);
                                Navigator.pop(ctx);
                                onApplyPackage?.call(pkg);
                                onChanged(pkg.id);
                                MessageService.showSuccess('${pkg.duration}-Day Package applied successfully!');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryColor,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 4.w),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                              ),
                              child: Text(
                                'Apply Package',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: kTextBold(color: kWhiteColor).copyWith(fontSize: 13.sp),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Size the sheet to the content: header/footer chrome + one row per
          // package (+1 for the "No Package" option), clamped to [0.4, 0.95].
          final screenH = MediaQuery.of(ctx).size.height;
          const chromeEstimate = 220.0; // handle + header + divider + Done bar
          const cardEstimate = 130.0; // avg card height (with description)
          final itemCount = packages.length + 1;
          final contentH = chromeEstimate + itemCount * cardEstimate;
          final initialSize = (contentH / screenH).clamp(0.4, 0.95);

          // Packages sorted from lowest days to highest days. Selected package stays in natural order.
          final sortedPackages = [...packages]..sort((a, b) => a.duration.compareTo(b.duration));

          return DraggableScrollableSheet(
            initialChildSize: initialSize,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (ctx2, scrollController) => Column(
              children: [
                // Handle
                Container(
                  margin: EdgeInsets.only(top: 12.h, bottom: 4.h),
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(2.r)),
                ),
                // Header
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Select Package', style: kTextBold1()),
                            SizedBox(height: 2.h),
                            Text(
                              '$currentScheduledDays days scheduled',
                              style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Icon(Icons.close, color: kTextSecondaryColor, size: 22.sp),
                      ),
                    ],
                  ),
                ),
                Divider(color: kBorderColor, height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    children: [
                      // No package option
                      GestureDetector(
                        onTap: () => select(null),
                        child: StatefulBuilder(
                          builder: (context, _) => AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            margin: EdgeInsets.only(bottom: 10.h),
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                            decoration: BoxDecoration(
                              color: currentId == null ? kPrimaryColor.withValues(alpha: 0.05) : kWhiteColor,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: currentId == null ? kPrimaryColor : kBorderColor,
                                width: currentId == null ? 1.8 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('No Package', style: kTextSemiBold()),
                                      SizedBox(height: 2.h),
                                      Text(
                                        'Pay daily rate × $currentScheduledDays days',
                                        style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                                      ),
                                    ],
                                  ),
                                ),
                                if (currentId == null)
                                  Container(
                                    padding: EdgeInsets.all(4.w),
                                    decoration: const BoxDecoration(color: kPrimaryColor, shape: BoxShape.circle),
                                    child: Icon(Icons.check_rounded, color: kWhiteColor, size: 13.sp),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Package cards — sorted by lowest days to highest days
                      ...sortedPackages.map((pkg) {
                        final isSelected = currentId == pkg.id;
                        final hasDiscount = pkg.discountPercentage > 0;
                        final perDay = pkg.price / pkg.duration;
                        final discountStr = cleanDecimal(pkg.discountPercentage);
                        final savings = pkg.actualPrice - pkg.price;
                        final priceColor = isSelected ? kPrimaryColor : kTextPrimaryColor;

                        return GestureDetector(
                          onTap: isSelected ? null : () => confirmAndApplyPackage(pkg),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            margin: EdgeInsets.only(bottom: 10.h),
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              color: isSelected ? kPrimaryColor.withValues(alpha: 0.04) : kWhiteColor,
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(
                                color: isSelected ? kPrimaryColor : kBorderColor,
                                width: isSelected ? 1.8 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: kPrimaryColor.withValues(alpha: 0.08),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Title + discount badge
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  '${pkg.duration} Days',
                                                  style: kTextBold1(color: kTextPrimaryColor),
                                                ),
                                              ),
                                              if (hasDiscount) ...[
                                                SizedBox(width: 8.w),
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 8.w,
                                                    vertical: 3.h,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: kSuccessColor.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(6.r),
                                                  ),
                                                  child: Text(
                                                    '$discountStr% OFF',
                                                    style: kTextSemiBold0(color: kSuccessColor).copyWith(fontSize: 10.sp),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          SizedBox(height: 6.h),
                                          // Price + strikethrough
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                NumberUtils.formatCurrency(pkg.price, decimalDigits: 0),
                                                style: kTextBold2(color: priceColor),
                                              ),
                                              if (hasDiscount) ...[
                                                SizedBox(width: 8.w),
                                                Padding(
                                                  padding: EdgeInsets.only(bottom: 2.h),
                                                  child: Text(
                                                    NumberUtils.formatCurrency(
                                                      pkg.actualPrice,
                                                      decimalDigits: 0,
                                                    ),
                                                    style: kTextNormal0(color: kTextHintColor).copyWith(
                                                      decoration: TextDecoration.lineThrough,
                                                      decorationColor: kTextHintColor,
                                                      fontSize: 12.sp,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          SizedBox(height: 6.h),
                                          // Per-day chip + savings
                                          Row(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                                decoration: BoxDecoration(
                                                  color: kPrimaryColor.withValues(alpha: 0.06),
                                                  borderRadius: BorderRadius.circular(6.r),
                                                ),
                                                child: Text(
                                                  '${NumberUtils.formatCurrency(perDay, decimalDigits: 0)}/day',
                                                  style: kTextSemiBold0(color: kPrimaryColor).copyWith(fontSize: 11.sp),
                                                ),
                                              ),
                                              if (hasDiscount && savings > 0) ...[
                                                SizedBox(width: 8.w),
                                                Text(
                                                  'Save ${NumberUtils.formatCurrency(savings, decimalDigits: 0)}',
                                                  style: kTextSemiBold0(color: kSuccessColor).copyWith(fontSize: 11.sp),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    if (isSelected)
                                      Container(
                                        padding: EdgeInsets.all(5.w),
                                        decoration: const BoxDecoration(
                                          color: kPrimaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.check_rounded, color: kWhiteColor, size: 14.sp),
                                      )
                                    else
                                      GestureDetector(
                                        onTap: () => confirmAndApplyPackage(pkg),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                                          decoration: BoxDecoration(
                                            color: kPrimaryColor.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(10.r),
                                          ),
                                          child: Text(
                                            'Apply',
                                            style: kTextSemiBold(color: kPrimaryColor).copyWith(fontSize: 12.sp),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                // Description with read more / less — highlighted box
                                if (pkg.description != null && pkg.description!.trim().isNotEmpty) ...[
                                  SizedBox(height: 10.h),
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                                    decoration: BoxDecoration(
                                      color: kPrimaryColor.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(8.r),
                                      border: Border.all(
                                        color: kPrimaryColor.withValues(alpha: 0.12),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.info_outline_rounded,
                                          size: 13.sp,
                                          color: kPrimaryColor,
                                        ),
                                        SizedBox(width: 6.w),
                                        Expanded(
                                          child: _ExpandableText(
                                            text: pkg.description!.trim(),
                                            color: kGreyColor9,
                                            linkColor: kPrimaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                // Done button
                Container(
                  padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h + MediaQuery.of(ctx).padding.bottom),
                  decoration: BoxDecoration(
                    color: kWhiteColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
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
        },
      );
    },
  );
}

/// Description text clamped to 2 lines with a "Read more" / "Read less" toggle.
/// The toggle only appears when the text actually overflows.
class _ExpandableText extends StatefulWidget {
  final String text;
  final Color color;
  final Color linkColor;

  const _ExpandableText({required this.text, required this.color, required this.linkColor});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = kTextNormal0(color: widget.color).copyWith(fontSize: 11.5.sp, height: 1.4);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tp = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 2,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        final isOverflowing = tp.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: style,
              maxLines: _expanded ? null : 2,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (isOverflowing) ...[
              SizedBox(height: 4.h),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? 'Read less' : 'Read more',
                  style: kTextSemiBold0(color: widget.linkColor).copyWith(fontSize: 11.5.sp),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
