import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/features/user/booking_history/bloc/booking_detail_bloc.dart';
import 'package:adhisaat_health_care/features/user/booking_history/helper/payment_status_mapper.dart';
import 'package:adhisaat_health_care/features/user/booking_history/model/booking_detail_model.dart';
import 'package:adhisaat_health_care/features/user/booking_history/widget/booking_sheet_widgets.dart';
import 'package:adhisaat_health_care/features/user/payment/view/booking_payment_page.dart';
import 'package:adhisaat_health_care/features/user/payment_list/view/transaction_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

String _fmtDate(String d) => AppDateFormatter.dateShort(d);

class PaymentBreakdownSheet extends StatelessWidget {
  final ScrollController controller;
  final ServiceRequestDetail sr;

  const PaymentBreakdownSheet({super.key, required this.controller, required this.sr});

  @override
  Widget build(BuildContext context) {
    final bd = sr.pricingBreakdown;
    final payStatus = PaymentStatusMapper.fromString(sr.paymentStatus);
    final sortedInstallments = [...sr.paymentInstallments]
      ..sort((a, b) => a.installmentNumber.compareTo(b.installmentNumber));

    final allRefunds = sortedInstallments
        .expand((inst) => inst.payment?.refundPayments ?? <InstallmentRefundPayment>[])
        .toList()
      ..sort((a, b) => (a.paidAt ?? '').compareTo(b.paidAt ?? ''));

    final paidAmount = sr.paidAmount;
    final totalAmount = sr.totalAmount;
    final paidFraction = totalAmount > 0 ? (paidAmount / totalAmount).clamp(0.0, 1.0) : 0.0;
    final onlinePaid =
        totalAmount - sr.discountAmount - sr.walletAmountUsed - sr.bonusAmountUsed;

    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const BookingSheetHandle(),
            // ── Header ─────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 14.h),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payment Breakdown', style: kTextBold2(color: kTextPrimaryColor)),
                        SizedBox(height: 3.h),
                        Text(sr.requestNumber, style: kTextNormal0(color: kTextSecondaryColor)),
                      ],
                    ),
                  ),
                  _PayStatusChip(config: PaymentStatusMapper.getConfig(payStatus)),
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
                  // Package card
                  if (bd?.package != null) ...[
                    _PackageCard(pkg: bd!.package!, serviceName: sr.service?.name ?? sr.serviceTypeText),
                    SizedBox(height: 16.h),
                  ],

                  // Charges + Total amount
                  BreakdownSection(
                    title: 'Charges',
                    children: [
                      if ((bd?.serviceCharge ?? 0) > 0)
                        BreakdownRow(label: 'Service Charge', amount: bd!.serviceCharge),
                      if ((bd?.distanceCharge ?? 0) > 0)
                        BreakdownRow(label: 'Distance Charge', amount: bd!.distanceCharge),
                      if ((bd?.gstAmount ?? 0) > 0)
                        BreakdownRow(label: 'GST (${bd!.gstPercentage.toStringAsFixed(0)}%)', amount: bd.gstAmount),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // Total amount card
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kPrimaryColor.withValues(alpha: 0.06), kPrimaryColor.withValues(alpha: 0.02)],
                      ),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: kPrimaryColor.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            color: kPrimaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(Icons.receipt_long_rounded, color: kPrimaryColor, size: 14.sp),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(child: Text('Total Amount', style: kTextBold1(color: kTextPrimaryColor))),
                        Text(NumberUtils.formatCurrency(totalAmount),
                            style: kTextBold2(color: kPrimaryColor)),
                      ],
                    ),
                  ),

                  // Discounts & wallet / bonus usage (booking-level)
                  if (sr.discountAmount > 0 || sr.walletAmountUsed > 0 || sr.bonusAmountUsed > 0) ...[
                    SizedBox(height: 12.h),
                    BreakdownSection(
                      title: 'Discounts & Payments',
                      children: [
                        if (sr.discountAmount > 0)
                          BreakdownRow(label: 'Promo Discount', amount: -sr.discountAmount),
                        if (sr.walletAmountUsed > 0)
                          BreakdownRow(
                            label: 'Wallet Used',
                            amount: -sr.walletAmountUsed,
                            color: const Color(0xFF6366F1),
                          ),
                        if (sr.bonusAmountUsed > 0)
                          BreakdownRow(
                            label: 'Bonus Used',
                            amount: -sr.bonusAmountUsed,
                            color: const Color(0xFFF59E0B),
                          ),
                        if (onlinePaid > 0)
                          BreakdownRow(
                            label: 'Paid Online',
                            amount: onlinePaid,
                            color: kPrimaryColor,
                          ),
                      ],
                    ),
                  ],

                  // Progress bar (only for partial payments)
                  if (sortedInstallments.length > 1 && paidAmount > 0 && paidAmount < totalAmount) ...[
                    SizedBox(height: 16.h),
                    _PaymentProgressBar(paidAmount: paidAmount, totalAmount: totalAmount, fraction: paidFraction),
                  ],

                  SizedBox(height: 16.h),

                  // Installments
                  if (sortedInstallments.isNotEmpty) ...[
                    _InstallmentsSection(
                      installments: sortedInstallments,
                      sr: sr,
                      context: context,
                    ),
                  ],

                  // Refunds
                  if (allRefunds.isNotEmpty) ...[
                    SizedBox(height: 20.h),
                    _RefundsSection(refunds: allRefunds),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment progress bar
// ─────────────────────────────────────────────────────────────────────────────
class _PaymentProgressBar extends StatelessWidget {
  final double paidAmount;
  final double totalAmount;
  final double fraction;

  const _PaymentProgressBar({
    required this.paidAmount,
    required this.totalAmount,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = totalAmount - paidAmount;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFEDF0F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Paid', style: kTextNormal0(color: kTextSecondaryColor)),
                    SizedBox(height: 2.h),
                    Text(NumberUtils.formatCurrency(paidAmount),
                        style: kTextBold1(color: kSuccessColor)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Remaining', style: kTextNormal0(color: kTextSecondaryColor)),
                  SizedBox(height: 2.h),
                  Text(NumberUtils.formatCurrency(remaining),
                      style: kTextBold1(color: kAccentColor)),
                ],
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8.h,
              backgroundColor: kAccentColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(kSuccessColor),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            '${(fraction * 100).toStringAsFixed(0)}% paid',
            style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 10.sp),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Installments section — timeline style
// ─────────────────────────────────────────────────────────────────────────────
class _InstallmentsSection extends StatelessWidget {
  final List<PaymentInstallment> installments;
  final ServiceRequestDetail sr;
  final BuildContext context;

  const _InstallmentsSection({
    required this.installments,
    required this.sr,
    required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Text('Payments', style: kTextSemiBold(color: kTextSecondaryColor)),
        ),
        ...List.generate(installments.length, (i) {
          final inst = installments[i];
          final isLast = i == installments.length - 1;
          return _InstallmentTimelineRow(
            inst: inst,
            sr: sr,
            context: context,
            isLast: isLast,
            index: i,
          );
        }),
      ],
    );
  }
}

class _InstallmentTimelineRow extends StatelessWidget {
  final PaymentInstallment inst;
  final ServiceRequestDetail sr;
  final BuildContext context;
  final bool isLast;
  final int index;

  const _InstallmentTimelineRow({
    required this.inst,
    required this.sr,
    required this.context,
    required this.isLast,
    required this.index,
  });

  Color get _color => inst.isPaid
      ? kSuccessColor
      : inst.isOverdue
          ? kErrorColor
          : kAccentColor;

  IconData get _icon => inst.isPaid
      ? Icons.check_circle_rounded
      : inst.isOverdue
          ? Icons.error_rounded
          : Icons.radio_button_unchecked_rounded;

  String get _title => inst.isPaid
      ? 'Payment Completed'
      : inst.percentage == 100
          ? 'Full Payment Due'
          : 'Payment ${inst.installmentNumber} of ${inst.percentage}%';

  String get _subtitle => inst.isPaid && inst.paidAt != null
      ? 'Paid on ${_fmtDate(inst.paidAt!)}'
      : inst.isOverdue
          ? 'Overdue since ${_fmtDate(inst.dueDate)}'
          : 'Due: ${_fmtDate(inst.dueDate)}';

  @override
  Widget build(BuildContext ctx) {
    final canTap = inst.isPaid && inst.payment != null;
    final canPay = !inst.isPaid && !sr.isCancelledOrExpired;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline column: dot + line
          SizedBox(
            width: 28.w,
            child: Column(
              children: [
                Container(
                  width: 26.w,
                  height: 26.w,
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(_icon, color: _color, size: 14.sp),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5.w,
                      margin: EdgeInsets.symmetric(vertical: 2.h),
                      decoration: BoxDecoration(
                        color: kBorderColor,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 12.w),

          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14.h),
              child: GestureDetector(
                onTap: canTap ? () => _showTransactionSheet(ctx, inst.payment!) : null,
                child: Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: inst.isPaid
                        ? kSuccessColor.withValues(alpha: 0.04)
                        : inst.isOverdue
                            ? kErrorColor.withValues(alpha: 0.04)
                            : const Color(0xFFF8FAFD),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: inst.isPaid
                          ? kSuccessColor.withValues(alpha: 0.15)
                          : inst.isOverdue
                              ? kErrorColor.withValues(alpha: 0.2)
                              : const Color(0xFFEDF0F7),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_title,
                                style: kTextSemiBold(color: kTextPrimaryColor)
                                    .copyWith(fontSize: 13.sp)),
                            SizedBox(height: 3.h),
                            Text(_subtitle,
                                style: kTextNormal0(color: kTextSecondaryColor)
                                    .copyWith(fontSize: 11.sp)),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      if (canPay)
                        _PayNowButton(
                          onTap: () => _handleInstallmentPayment(ctx, sr, inst),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(NumberUtils.formatCurrency(inst.amount),
                                style: kTextSemiBold(color: kTextPrimaryColor)
                                    .copyWith(fontSize: 13.sp)),
                            SizedBox(height: 4.h),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: _color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Text(inst.statusText,
                                  style: kTextBold0(color: _color).copyWith(fontSize: 10.sp)),
                            ),
                          ],
                        ),
                      if (canTap) ...[
                        SizedBox(width: 6.w),
                        Icon(Icons.chevron_right_rounded,
                            color: kTextSecondaryColor, size: 16.sp),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleInstallmentPayment(
    BuildContext ctx,
    ServiceRequestDetail sr,
    PaymentInstallment inst,
  ) async {
    // Find all unpaid installments up to the selected one
    final sorted = [...sr.paymentInstallments]
      ..sort((a, b) => a.installmentNumber.compareTo(b.installmentNumber));

    final installmentsToPay = <PaymentInstallment>[];
    double totalAmountToPay = 0;

    for (final installment in sorted) {
      if (!installment.isPaid) {
        installmentsToPay.add(installment);
        totalAmountToPay += installment.amount;
      }
      if (installment.id == inst.id) {
        break; // Stop after including the clicked installment
      }
    }

    Navigator.pop(ctx);
    await navigateToPaymentPage(
      context: ctx,
      serviceRequestId: sr.id,
      totalAmount: totalAmountToPay,
      basePrice: totalAmountToPay,
      distanceCharge: 0,
      gstAmount: 0,
      bookingType: 'installment_payment',
      paymentInstallments: installmentsToPay.map((e) => e.toJson()).toList(),
      serviceName: sr.service?.name ?? sr.serviceTypeText,
      serviceImageUrl: sr.service?.iconImageUrl,
      startDate: sr.startDateText,
      endDate: sr.endDateText,
      durationDays: sr.durationDays,
      durationHours: sr.durationHours?.toInt(),
      isEmergency: sr.isEmergency,
      onCancel: () {
        if (ctx.mounted) ctx.read<BookingDetailBloc>().add(RefreshBookingDetail());
      },
    );
    if (ctx.mounted) ctx.read<BookingDetailBloc>().add(RefreshBookingDetail());
  }

  void _showTransactionSheet(BuildContext ctx, InstallmentPayment payment) {
    Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (_) => TransactionDetailPage(paymentId: payment.id),
      ),
    );
  }
}

class _PayNowButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PayNowButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kPrimaryColor, kPrimaryColor.withValues(alpha: 0.82)],
          ),
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: [
            BoxShadow(
              color: kPrimaryColor.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payment_rounded, color: kWhiteColor, size: 13.sp),
            SizedBox(width: 5.w),
            Text('Pay Now', style: kTextBold0(color: kWhiteColor)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Package card
// ─────────────────────────────────────────────────────────────────────────────
class _PackageCard extends StatelessWidget {
  final PackageInfo pkg;
  final String serviceName;

  const _PackageCard({required this.pkg, required this.serviceName});

  @override
  Widget build(BuildContext context) {
    final hasDiscount = pkg.discountPercentage > 0 && pkg.actualPrice > pkg.price;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryColor.withValues(alpha: 0.05), kSecondaryColor.withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: kPrimaryColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.medical_services_rounded, color: kPrimaryColor, size: 13.sp),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  serviceName,
                  style: kTextSemiBold(color: kTextPrimaryColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: kSuccessColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: kSuccessColor, size: 11.sp),
                    SizedBox(width: 3.w),
                    Text('Package Applied',
                        style: kTextBold0(color: kSuccessColor).copyWith(fontSize: 9.5.sp)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              _PkgChip(
                label: '${pkg.duration} ${pkg.durationType}',
                icon: Icons.calendar_month_rounded,
              ),
              SizedBox(width: 6.w),
              _PkgChip(label: pkg.displayShift, icon: Icons.wb_sunny_rounded),
            ],
          ),
          SizedBox(height: 10.h),
          Divider(height: 1, color: kPrimaryColor.withValues(alpha: 0.1)),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: Text('Package Price', style: kTextNormal(color: kTextSecondaryColor)),
              ),
              if (hasDiscount) ...[
                Text(
                  NumberUtils.formatCurrency(pkg.actualPrice),
                  style: kTextNormal0(color: kTextSecondaryColor)
                      .copyWith(decoration: TextDecoration.lineThrough),
                ),
                SizedBox(width: 6.w),
              ],
              Text(NumberUtils.formatCurrency(pkg.price),
                  style: kTextBold1(color: kPrimaryColor)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PkgChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _PkgChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: kPrimaryColor, size: 11.sp),
          SizedBox(width: 4.w),
          Text(label, style: kTextSemiBold0(color: kTextPrimaryColor)),
        ],
      ),
    );
  }
}

class _PayStatusChip extends StatelessWidget {
  final PaymentDisplayConfig config;

  const _PayStatusChip({required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: config.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, color: config.color, size: 12.sp),
          SizedBox(width: 4.w),
          Text(config.label, style: kTextSemiBold0(color: config.color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Refunds section — combined refund_payments from all installments
// ─────────────────────────────────────────────────────────────────────────────
class _RefundsSection extends StatelessWidget {
  final List<InstallmentRefundPayment> refunds;

  const _RefundsSection({required this.refunds});

  @override
  Widget build(BuildContext context) {
    final totalRefund = refunds.fold<double>(0, (sum, r) => sum + r.displayAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Refunds', style: kTextSemiBold(color: kTextSecondaryColor)),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: kErrorColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                NumberUtils.formatCurrency(totalRefund),
                style: kTextBold0(color: kErrorColor).copyWith(fontSize: 11.sp),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        ...refunds.map((r) => _RefundRow(refund: r)),
      ],
    );
  }
}

class _RefundRow extends StatelessWidget {
  final InstallmentRefundPayment refund;

  const _RefundRow({required this.refund});

  @override
  Widget build(BuildContext context) {
    final isWallet = (refund.paymentMethod ?? '').toLowerCase() == 'wallet' ||
        (refund.refundGatewayReference ?? '').toLowerCase().contains('wallet');
    final refundDate = refund.paidAt != null ? _fmtDate(refund.paidAt!) : '—';
    final methodLabel = isWallet ? 'Wallet Refund' : 'Online Refund';
    final methodColor = isWallet ? const Color(0xFF7C3AED) : kPrimaryColor;

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TransactionDetailPage(paymentId: refund.id),
          ),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: kErrorColor.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: kErrorColor.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: kErrorColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.currency_rupee_rounded, color: kErrorColor, size: 15.sp),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      refund.paymentNumber,
                      style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 12.sp),
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Text(refundDate,
                            style: kTextNormal0(color: kTextSecondaryColor)
                                .copyWith(fontSize: 11.sp)),
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                          decoration: BoxDecoration(
                            color: methodColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Text(methodLabel,
                              style: kTextBold0(color: methodColor).copyWith(fontSize: 9.sp)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                NumberUtils.formatCurrency(refund.displayAmount),
                style: kTextSemiBold(color: kErrorColor).copyWith(fontSize: 13.sp),
              ),
              SizedBox(width: 4.w),
              Icon(Icons.chevron_right_rounded, color: kTextSecondaryColor, size: 16.sp),
            ],
          ),
        ),
      ),
    );
  }
}
