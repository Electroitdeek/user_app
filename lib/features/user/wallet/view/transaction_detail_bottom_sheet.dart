import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/utils/number_utils.dart';

class TransactionDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> tx;

  const TransactionDetailsSheet({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    final cr = double.tryParse(tx['cr']?.toString() ?? '0') ?? 0;
    final dr = double.tryParse(tx['dr']?.toString() ?? '0') ?? 0;
    final bool isCredit = cr > 0;
    final amountText = NumberUtils.formatCurrency(isCredit ? cr : dr, decimalDigits: 1);
    final description = tx['description']?.toString() ?? 'Transaction';
    final dateStr = tx['created_at_formatted'] ?? '';
    final isPending = description.toLowerCase().contains('pending');

    final Color statusColor = isPending ? Colors.orange : (isCredit ? Colors.green : kTextPrimaryColor);

    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(color: kGreyColor2, borderRadius: BorderRadius.circular(2.r)),
                ),
              ),
              SizedBox(height: 24.h),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Transaction Detail', style: kTextBold().copyWith(fontSize: 18.sp)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8.r)),
                    child: Text(
                      isPending ? 'Processing' : (isCredit ? 'Credit' : 'Debit'),
                      style: kTextBold(color: statusColor).copyWith(fontSize: 10.sp, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // Icon & Amount
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 64.w,
                      height: 64.w,
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(
                        isPending ? Icons.schedule_rounded : (isCredit ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded),
                        color: statusColor,
                        size: 32.sp,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      '${isCredit ? '+' : '-'} $amountText',
                      style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 32.sp, letterSpacing: -1),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: kTextMedium(color: kTextSecondaryColor).copyWith(fontSize: 14.sp),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32.h),

              // Details Card
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(color: kGreyColor1.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20.r)),
                child: Column(
                  children: [
                    _buildDetailRow('Date & Time', dateStr),
                    if (tx['id'] != null) ...[SizedBox(height: 14.h), _buildDetailRow('Reference ID', '#${tx['id']}')],
                    if (tx['txn_id'] != null) ...[SizedBox(height: 14.h), _buildDetailRow('Transaction ID', tx['txn_id'].toString())],
                    SizedBox(height: 14.h),
                    _buildDetailRow('Status', isPending ? 'Processing' : 'Completed'),
                  ],
                ),
              ),

              SizedBox(height: 32.h),

              // OK Button
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                    elevation: 0,
                  ),
                  child: Text('Close', style: kTextBold1(color: kWhiteColor)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: kTextMedium(color: kTextSecondaryColor).copyWith(fontSize: 13.sp),
        ),
        Flexible(
          child: Text(
            value,
            style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 13.sp),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
