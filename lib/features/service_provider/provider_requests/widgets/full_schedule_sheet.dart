import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/models/request_status.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/models/sub_block_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class FullScheduleSheet extends StatelessWidget {
  final List<SubBlock> blocks;
  final ScrollController? scrollController;

  const FullScheduleSheet({super.key, required this.blocks, this.scrollController});

  static const _blue = Color(0xFF2D62ED);
  static const _greyBorder = Color(0xFFE5E7EB);
  static const _greyText = Color(0xFF6B7280);

  Map<String, List<SubBlock>> _groupByMonth() {
    final Map<String, List<SubBlock>> grouped = {};
    for (final b in blocks) {
      final key = b.monthLabel;
      if (key != '—') grouped.putIfAbsent(key, () => []).add(b);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByMonth();
    final months = grouped.keys.toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: 12.h, bottom: 4.h),
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(color: _greyBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_outlined, color: _blue, size: 22.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Full Schedule', style: kTextBold2()),
                        Text(
                          '${blocks.length} sessions total',
                          style: kTextNormal(color: _greyText).copyWith(fontSize: 12.sp),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, size: 22.sp, color: _greyText),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: _greyBorder),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
                itemCount: months.length,
                itemBuilder: (_, mi) {
                  final month = months[mi];
                  final mBlocks = grouped[month]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 16.h, bottom: 10.h),
                        child: Container(
                          padding: AppPadding.symmetric(h: 12, v: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            month,
                            style: kTextBold(color: _blue).copyWith(fontSize: 12.sp, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                      ...mBlocks.asMap().entries.map((e) {
                        final i = e.key;
                        final b = e.value;

                        final rs = RequestStatus.fromString(b.status);
                        final sc = rs.color;

                        return Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  Container(
                                    width: 38.w,
                                    height: 38.w,
                                    decoration: BoxDecoration(
                                      color: rs.bgColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: sc.withValues(alpha: 0.3)),
                                    ),
                                    child: Center(
                                      child: Text(
                                        AppDateFormatter.dayNum(b.scheduledDate),
                                        style: kTextBold(color: sc).copyWith(fontSize: 13.sp),
                                      ),
                                    ),
                                  ),
                                  if (i < mBlocks.length - 1)
                                    Container(width: 1.w, height: 18.h, color: _greyBorder),
                                ],
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Container(
                                  margin: EdgeInsets.only(top: 4.h),
                                  padding: AppPadding.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(10.r),
                                    border: Border.all(color: _greyBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              AppDateFormatter.weekdayFull(b.scheduledDate),
                                              style: kTextSemiBold().copyWith(fontSize: 12.sp),
                                            ),
                                            SizedBox(height: 3.h),
                                            Text(
                                              b.timeRange,
                                              style: kTextNormal(color: _greyText).copyWith(fontSize: 11.sp),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            NumberUtils.formatCurrency(b.providerPayout),
                                            style: kTextSemiBold(
                                              color: const Color(0xFF22C55E),
                                            ).copyWith(fontSize: 12.sp),
                                          ),
                                          // SizedBox(height: 4.h),
                                          // Container(
                                          //   padding: AppPadding.symmetric(h: 6, v: 2),
                                          //   decoration: BoxDecoration(
                                          //     color: sc.withValues(alpha: 0.1),
                                          //     borderRadius: BorderRadius.circular(4.r),
                                          //   ),
                                          //   child: Text(
                                          //     sl,
                                          //     style: kTextMedium(color: sc).copyWith(fontSize: 9.sp),
                                          //   ),
                                          // ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
