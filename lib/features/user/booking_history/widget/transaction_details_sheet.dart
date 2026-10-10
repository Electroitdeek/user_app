import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/features/user/booking_history/model/booking_detail_model.dart';
import 'package:adhisaat_health_care/features/user/booking_history/widget/booking_sheet_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class TransactionDetailsSheet extends StatelessWidget {
  final ScrollController controller;
  final InstallmentPayment payment;
  final int installmentNumber;
  final double installmentAmount;

  const TransactionDetailsSheet({
    super.key,
    required this.controller,
    required this.payment,
    required this.installmentNumber,
    required this.installmentAmount,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = payment.paymentStatus == 'completed';
    final statusColor = isSuccess ? kSuccessColor : kErrorColor;

    final paymentSubtotal = payment.subtotal > 0 ? payment.subtotal : installmentAmount;
    // When one payment covers several installments, its deduction breakdown
    // (promo / wallet / bonus) applies to the whole payment — not to a single
    // installment. Detect that case and show an installment-focused receipt.
    final isSplitPayment = paymentSubtotal > 0 &&
        (installmentAmount - paymentSubtotal).abs() > 0.01;

    final subtotal = installmentAmount;
    final walletUsed = payment.walletAmountUsed;
    final bonusUsed = payment.bonusAmountUsed;
    final discountUsed = payment.discountAmount;
    final totalCharged = payment.totalAmount;

    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          const BookingSheetHandle(),

          // ── Header ─────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 14.h),
            child: Row(
              children: [
                // Status icon
                Container(
                  width: 42.w,
                  height: 42.w,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: statusColor,
                    size: 22.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Payment Receipt', style: kTextBold1(color: kTextPrimaryColor)),
                      SizedBox(height: 2.h),
                      Text(
                        'Installment $installmentNumber · ${payment.paymentNumber}',
                        style: kTextNormal0(color: kTextSecondaryColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Status pill
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    isSuccess ? 'Paid' : payment.paymentStatus.replaceAll('_', ' '),
                    style: kTextSemiBold0(color: statusColor),
                  ),
                ),
                SizedBox(width: 8.w),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                        color: kBorderColor.withValues(alpha: 0.5), shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, size: 16.sp, color: kTextSecondaryColor),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: kBorderColor),

          // ── Body ───────────────────────────────────────────────────
          Expanded(
            child: ListView(
              controller: controller,
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
              children: [
                // ── Amount charged hero card ────────────────────────
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        statusColor.withValues(alpha: 0.08),
                        statusColor.withValues(alpha: 0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isSplitPayment ? 'Installment $installmentNumber Amount' : 'Total Amount',
                              style: kTextNormal0(color: kTextSecondaryColor)
                                  .copyWith(fontSize: 11.sp)),
                          SizedBox(height: 4.h),
                          Text(NumberUtils.formatCurrency(subtotal),
                              style: kTextBold2(color: statusColor).copyWith(fontSize: 22.sp)),
                        ],
                      ),
                      const Spacer(),
                      Icon(
                        isSuccess ? Icons.verified_rounded : Icons.error_outline_rounded,
                        color: statusColor,
                        size: 32.sp,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16.h),

                // ── Amount breakdown ────────────────────────────────
                if (isSplitPayment)
                  BreakdownSection(
                    title: 'Amount Breakdown',
                    children: [
                      BreakdownRow(
                        label: 'Installment $installmentNumber Amount',
                        amount: installmentAmount,
                      ),
                      _TxnInfoRow(
                        label: 'Booking Total',
                        value: NumberUtils.formatCurrency(paymentSubtotal),
                        icon: Icons.receipt_long_rounded,
                      ),
                    ],
                  )
                else
                  BreakdownSection(
                    title: 'Amount Breakdown',
                    children: [
                      BreakdownRow(
                        label: 'Amount to be paid',
                        amount: subtotal,
                      ),
                      if (discountUsed > 0)
                        BreakdownRow(label: 'Promo Discount', amount: -discountUsed, color: kSuccessColor),
                      if (walletUsed > 0)
                        _DeductionRow(
                          label: 'Wallet Used',
                          amount: walletUsed,
                          icon: Icons.account_balance_wallet_rounded,
                          color: const Color(0xFF6366F1),
                        ),
                      if (bonusUsed > 0)
                        _DeductionRow(
                          label: 'Bonus Used',
                          amount: bonusUsed,
                          icon: Icons.redeem_rounded,
                          color: const Color(0xFFF59E0B),
                        ),
                      if (totalCharged > 0)
                        BreakdownRow(
                          label: 'Paid Online',
                          amount: totalCharged,
                          color: kPrimaryColor,
                        ),
                    ],
                  ),

                SizedBox(height: 16.h),

                // ── Payment info ────────────────────────────────────
                BreakdownSection(
                  title: 'Payment Info',
                  children: [
                    _TxnInfoRow(
                      label: 'Method',
                      value: _formatMethod(payment.paymentMethod),
                      icon: _methodIcon(payment.paymentMethod),
                    ),
                    if (payment.transactionId != null)
                      _TxnInfoRow(
                        label: 'Transaction ID',
                        value: payment.transactionId!,
                        copyable: true,
                        icon: Icons.tag_rounded,
                      ),
                    if (payment.paidAt != null)
                      _TxnInfoRow(
                        label: 'Paid At',
                        value: AppDateFormatter.fromApiDateTime(payment.paidAt!),
                        icon: Icons.schedule_rounded,
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

  String _formatMethod(String method) {
    switch (method.toLowerCase()) {
      case 'netbanking':
        return 'Net Banking';
      case 'upi':
        return 'UPI';
      case 'card':
        return 'Card';
      case 'wallet':
        return 'Wallet';
      default:
        return method.replaceAll('_', ' ');
    }
  }

  IconData _methodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'netbanking':
        return Icons.account_balance_rounded;
      case 'upi':
        return Icons.qr_code_rounded;
      case 'card':
        return Icons.credit_card_rounded;
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.payment_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Deduction row (wallet / bonus) — coloured with icon
// ─────────────────────────────────────────────────────────────────────────────
class _DeductionRow extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  const _DeductionRow({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(5.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7.r),
            ),
            child: Icon(icon, color: color, size: 12.sp),
          ),
          SizedBox(width: 8.w),
          Expanded(child: Text(label, style: kTextNormal(color: kTextPrimaryColor))),
          Text(
            '- ${NumberUtils.formatCurrency(amount)}',
            style: kTextSemiBold(color: color),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Transaction info row with icon
// ─────────────────────────────────────────────────────────────────────────────
class _TxnInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final bool copyable;

  const _TxnInfoRow({
    required this.label,
    required this.value,
    this.icon,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: EdgeInsets.only(top: 1.h),
              child: Icon(icon, size: 12.sp, color: kTextSecondaryColor),
            ),
            SizedBox(width: 7.w),
          ],
          Text(label, style: kTextNormal(color: kTextSecondaryColor)),
          SizedBox(width: 12.w),
          Expanded(
            child: GestureDetector(
              onTap: copyable
                  ? () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$label copied'),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                          margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r)),
                        ),
                      );
                    }
                  : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: kTextSemiBold(color: kTextPrimaryColor),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (copyable) ...[
                    SizedBox(width: 6.w),
                    Padding(
                      padding: EdgeInsets.only(top: 2.h),
                      child: Icon(Icons.copy_rounded, color: kPrimaryColor, size: 13.sp),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
