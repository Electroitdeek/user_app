import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:open_filex/open_filex.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/services/file_downloading_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/number_utils.dart';
import '../../../../di/locator.dart';
import '../../../../shared/widgets/buttons/custom_button.dart';
import '../../../../shared/widgets/common/app_bar_custom.dart';
import '../../payment/data/payment_repository.dart';
import '../model/payment_model.dart';

/// Full-screen transaction detail.
///
/// Pass either [payment] directly OR [paymentId] to fetch via API.
/// When [paymentId] is given, the page fetches from `/customer/payments?payment_id=`.
class TransactionDetailPage extends StatefulWidget {
  final PaymentModel? payment;
  final int? paymentId;
  final Future<void> Function()? onDownload;

  const TransactionDetailPage({
    super.key,
    this.payment,
    this.paymentId,
    this.onDownload,
  }) : assert(payment != null || paymentId != null, 'Provide payment or paymentId');

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  bool _localDownloading = false;
  PaymentModel? _fetchedPayment;
  bool _isFetching = false;
  String? _fetchError;

  @override
  void initState() {
    super.initState();
    if (widget.payment == null && widget.paymentId != null) {
      _isFetching = true; // set before first build so the loading screen renders
      _fetchPayment();
    }
  }

  Future<void> _fetchPayment() async {
    if (!_isFetching) setState(() => _isFetching = true);
    _fetchError = null;
    try {
      final p = await locator<PaymentRepository>().getPaymentById(widget.paymentId!);
      if (mounted) setState(() => _fetchedPayment = p);
    } catch (e) {
      if (mounted) setState(() => _fetchError = e.toString());
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  Future<void> _downloadByPaymentId(int paymentId, String paymentNumber) async {
    final pathOrUrl = await locator<PaymentRepository>().downloadInvoice(paymentId, paymentNumber);
    if (pathOrUrl != null && mounted) {
      if (pathOrUrl.startsWith('http')) {
        await FileDownloadService().downloadAndViewFile(url: pathOrUrl, originalName: '${paymentNumber}_invoice');
      } else {
        await OpenFilex.open(pathOrUrl, type: 'application/pdf');
      }
    }
  }

  String _methodText(PaymentModel p) {
    if (p.paymentGateway != 'wallet' && p.paymentMethod == 'wallet') return 'Online';
    return p.paymentMethod != null ? p.paymentMethod!.replaceAll('_', ' ').toUpperCase() : 'Online';
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetching) {
      return Scaffold(
        backgroundColor: kScaffoldColor,
        appBar: CustomAppBar(title: 'Transaction Detail', centerTitle: true),
        body: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      );
    }

    if (_fetchError != null) {
      return Scaffold(
        backgroundColor: kScaffoldColor,
        appBar: CustomAppBar(title: 'Transaction Detail', centerTitle: true),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48.sp, color: kErrorColor),
              SizedBox(height: 12.h),
              Text('Failed to load transaction', style: kTextBold(color: kTextPrimaryColor)),
              SizedBox(height: 8.h),
              TextButton(onPressed: _fetchPayment, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final p = _fetchedPayment ?? widget.payment;
    if (p == null) {
      return Scaffold(
        backgroundColor: kScaffoldColor,
        appBar: CustomAppBar(title: 'Transaction Detail', centerTitle: true),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined, size: 48.sp, color: kTextHintColor),
              SizedBox(height: 12.h),
              Text('Transaction not found', style: kTextBold(color: kTextPrimaryColor)),
              SizedBox(height: 8.h),
              if (widget.paymentId != null)
                TextButton(onPressed: _fetchPayment, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final onDownload = widget.onDownload ?? () => _downloadByPaymentId(p.id, p.paymentNumber);

    return Scaffold(
      backgroundColor: kScaffoldColor,
      appBar: CustomAppBar(
        title: 'Transaction Detail',
        centerTitle: true,
        actions: [_NeedHelpButton(payment: p)],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHero(p),
              SizedBox(height: 16.h),
              _buildInfoCard(p),
              SizedBox(height: 14.h),
              _buildBillingSummary(p),
              if (p.hasRefunds) ...[
                SizedBox(height: 14.h),
                _buildRefundSection(p),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomActions(p, onDownload),
    );
  }

  Color _statusColor(PaymentModel p) {
    if (p.isSuccess) return kSuccessColor;
    if (p.isFailed) return kErrorColor;
    return kOrangeColor;
  }

  IconData _methodIcon(String? method) {
    switch (method) {
      case 'upi':
        return Icons.qr_code_rounded;
      case 'card':
        return Icons.credit_card_rounded;
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      case 'netbanking':
        return Icons.account_balance_rounded;
      case 'cash':
        return Icons.payments_rounded;
      default:
        return Icons.payments_rounded;
    }
  }

  // ── Amount hero ────────────────────────────────────────────────────────────
  Widget _buildHero(PaymentModel p) {
    final statusColor = _statusColor(p);
    final isDone = p.isSuccess;
    final badgeColor = p.isRefundTxn ? kSuccessColor : statusColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: double.infinity),
        SizedBox(height: 8.h),
        // Status ring + icon
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 76.w,
              height: 76.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: badgeColor.withValues(alpha: 0.10),
              ),
              child: Icon(
                p.isRefundTxn ? Icons.replay_rounded : _methodIcon(p.paymentMethod),
                size: 32.sp,
                color: badgeColor,
              ),
            ),
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: const BoxDecoration(color: kWhiteColor, shape: BoxShape.circle),
              child: Icon(
                isDone ? Icons.check_circle_rounded : (p.isFailed ? Icons.cancel_rounded : Icons.access_time_filled_rounded),
                size: 22.sp,
                color: statusColor,
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Text(
          p.isRefundTxn ? 'Refunded Amount' : 'Total Paid',
          style: kTextMedium(color: kTextSecondaryColor).copyWith(fontSize: 13.sp),
        ),
        SizedBox(height: 6.h),
        Text(
          NumberUtils.formatCurrency(p.displayAmount),
          style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 32.sp),
        ),
        SizedBox(height: 10.h),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusPill(label: p.status, color: statusColor),
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: kGreyColor1.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                _methodText(p),
                style: kTextSemiBold(color: kTextSecondaryColor).copyWith(fontSize: 9.sp, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Transaction info card ──────────────────────────────────────────────────
  Widget _buildInfoCard(PaymentModel p) {
    final rows = <Widget>[
      if (p.paymentNumber.isNotEmpty) _CompactRow(label: 'Payment ID', value: p.paymentNumber),
      if (p.serviceCategoryName != null && p.serviceCategoryName!.isNotEmpty)
        _CompactRow(label: 'Service', value: p.serviceCategoryName!),
      if (p.requestNumber != null)
        _CompactRow(
          label: 'Request',
          value: p.requestNumber!,
          onTap: p.serviceRequestId != null
              ? () => Navigator.pushNamed(context, AppRoutes.serviceRequestDetail, arguments: p.serviceRequestId)
              : null,
        ),
      if (p.paymentType != null && p.paymentType!.isNotEmpty)
        _CompactRow(label: 'Payment Type', value: p.paymentType!.toUpperCase()),
      if (p.transactionId != null && p.transactionId!.isNotEmpty && p.transactionId != 'wallet_refund')
        _CompactRow(label: 'Transaction ID', value: p.transactionId!),
      _CompactRow(label: 'Date', value: AppDateFormatter.timelineDateTime(p.paidAt ?? p.createdAt)),
    ];

    return _SectionCard(
      title: 'Payment Details',
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i != 0)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 11.h),
                child: Divider(height: 1, color: kGreyColor1.withValues(alpha: 0.7)),
              ),
            rows[i],
          ],
        ],
      ),
    );
  }

  // ── Billing summary ────────────────────────────────────────────────────────
  Widget _buildBillingSummary(PaymentModel p) {
    return _SectionCard(
      title: 'Billing Summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CompactSummaryRow(label: 'Sub Total', value: p.subtotal),
          if (p.distanceCharge > 0) _CompactSummaryRow(label: 'Distance Charge', value: p.distanceCharge),
          if (p.discountAmount > 0)
            _CompactSummaryRow(label: 'Discount', value: -p.discountAmount, valueColor: kErrorColor),
          if (p.walletAmountUsed > 0)
            _CompactSummaryRow(label: 'Wallet Applied', value: -p.walletAmountUsed, valueColor: kSuccessColor),
          if (p.bonusAmountUsed > 0)
            _CompactSummaryRow(label: 'Bonus Applied', value: -p.bonusAmountUsed, valueColor: kSuccessColor),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 6.h),
            child: Divider(color: kGreyColor1, height: 1),
          ),
          if (p.displayAmount > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${p.isRefundTxn ? 'Total Refunded' : 'Total Paid'} (${_methodText(p)})',
                    style: kTextBold().copyWith(fontSize: 14.sp),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  NumberUtils.formatCurrency(p.displayAmount),
                  style: kTextBold(color: kPrimaryColor).copyWith(fontSize: 17.sp),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Refund section ─────────────────────────────────────────────────────────
  Widget _buildRefundSection(PaymentModel p) {
    final refundTotal = p.refundAmount ?? p.refundPayments.fold<double>(0, (s, r) => s + r.totalAmount);
    final penalty = p.totalPenaltyApplied ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: kSuccessColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: kSuccessColor.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: kSuccessColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(color: kSuccessColor.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(Icons.assured_workload_rounded, size: 18.sp, color: kSuccessColor),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text('Refund Details', style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 14.sp)),
                ),
                if (p.refundStatus != null && p.refundStatus!.isNotEmpty)
                  _StatusPill(label: p.refundStatus!, color: kSuccessColor),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (refundTotal > 0)
                  _CompactSummaryRow(label: 'Refund Amount', value: refundTotal, valueColor: kSuccessColor),
                if (penalty > 0)
                  _CompactSummaryRow(label: 'Cancellation Penalty', value: -penalty, valueColor: kErrorColor),
                if ((p.cancelledSubBlocksCount ?? 0) > 0)
                  Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cancelled Sessions',
                            style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp)),
                        Text('${p.cancelledSubBlocksCount}',
                            style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 13.sp)),
                      ],
                    ),
                  ),
                SizedBox(height: 4.h),
                Text(
                  'REFUND TRANSACTIONS',
                  style: kTextSemiBold(color: kTextSecondaryColor).copyWith(fontSize: 10.sp, letterSpacing: 0.6),
                ),
                SizedBox(height: 8.h),
                ...p.refundPayments.map((r) => _RefundTxnTile(refund: r)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom actions ─────────────────────────────────────────────────────────
  Widget _buildBottomActions(PaymentModel p, Future<void> Function() onDownload) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
        child: Row(
          children: [
            if (p.isSuccess) ...[
              CustomButton(
                onPressed: () async {
                  setState(() => _localDownloading = true);
                  await onDownload();
                  if (mounted) setState(() => _localDownloading = false);
                },
                title: _localDownloading ? 'Wait...' : 'Invoice',
                iconData: Icons.download_rounded,
                iconColor: kPrimaryColor,
                backgroundColor: kPrimaryColor.withValues(alpha: 0.1),
                textColor: kPrimaryColor,
                height: 44.h,
                innerPadding: EdgeInsets.symmetric(horizontal: 16.w),
                borderRadius: BorderRadius.circular(12.r),
                textStyle: kTextBold(color: kPrimaryColor).copyWith(fontSize: 13.sp),
                isLoading: _localDownloading,
              ),
              SizedBox(width: 12.w),
            ],
            Expanded(
              child: CustomButton(
                onPressed: () => Navigator.pop(context),
                title: 'OK',
                backgroundColor: kPrimaryColor,
                height: 44.h,
                borderRadius: BorderRadius.circular(12.r),
                textStyle: kTextBold(color: kWhiteColor).copyWith(fontSize: 13.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Need help button ──────────────────────────────────────────────────────────
class _NeedHelpButton extends StatelessWidget {
  final PaymentModel payment;
  const _NeedHelpButton({required this.payment});

  @override
  Widget build(BuildContext context) {
    final p = payment;
    return TextButton.icon(
      onPressed: () => Navigator.pushNamed(
        context,
        AppRoutes.createSupportTicket,
        arguments: {
          'requestId': p.serviceRequestId?.toString(),
          'requestNumber': p.requestNumber,
          'serviceName': p.serviceCategoryName,
          'subject': 'Payment query – ${p.paymentNumber}'
              '${p.requestNumber != null ? ' | ${p.requestNumber}' : ''}',
          'category': 'payment',
        },
      ),
      icon: Icon(Icons.help_outline_rounded, size: 18.sp, color: kPrimaryColor),
      label: Text('Need Help?', style: kTextMedium0(color: kPrimaryColor)),
    );
  }
}

// ── Refund transaction tile ────────────────────────────────────────────────────
class _RefundTxnTile extends StatelessWidget {
  final PaymentModel refund;
  const _RefundTxnTile({required this.refund});

  @override
  Widget build(BuildContext context) {
    final r = refund;
    final rawReference = r.refundGatewayReference ?? r.transactionId;
    final reference = rawReference == 'wallet_refund' ? null : rawReference;
    final method = r.paymentMethodOriginal != null
        ? r.paymentMethodOriginal!.replaceAll('_', ' ').toUpperCase()
        : 'Online';

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: kGreyColor1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  r.paymentNumber,
                  style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 12.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                '+ ${NumberUtils.formatCurrency(r.totalAmount)}',
                style: kTextBold(color: kSuccessColor).copyWith(fontSize: 13.sp),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          _MiniRow(label: 'Method', value: method),
          SizedBox(height: 4.h),
          _MiniRow(label: 'Date', value: AppDateFormatter.timelineDateTime(r.refundedAt ?? r.paidAt ?? r.createdAt)),
          if (reference != null && reference.isNotEmpty) ...[
            SizedBox(height: 4.h),
            _MiniRow(label: 'Reference', value: reference),
          ],
        ],
      ),
    );
  }
}

class _MiniRow extends StatelessWidget {
  final String label;
  final String value;
  const _MiniRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 11.sp)),
        Flexible(
          child: Text(
            value,
            style: kTextMedium(color: kTextPrimaryColor).copyWith(fontSize: 11.sp),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6.r)),
      child: Text(
        label.toUpperCase(),
        style: kTextBold(color: color).copyWith(fontSize: 9.sp, letterSpacing: 0.5),
      ),
    );
  }
}

// ── Section card ────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: kBorderColor.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: kTextSemiBold(color: kPrimaryColor).copyWith(fontSize: 13.sp)),
          SizedBox(height: 14.h),
          child,
        ],
      ),
    );
  }
}

// ── Shared rows ─────────────────────────────────────────────────────────────
class _CompactRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _CompactRow({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final valueWidget = onTap != null
        ? GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: kTextSemiBold(color: kPrimaryColor).copyWith(
                      fontSize: 12.sp,
                      decoration: TextDecoration.underline,
                      decorationColor: kPrimaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 3.w),
                Icon(Icons.open_in_new_rounded, size: 13.sp, color: kPrimaryColor),
              ],
            ),
          )
        : Text(
            value,
            textAlign: TextAlign.right,
            style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 12.sp),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96.w,
          child: Text(label, style: kTextMedium(color: kTextSecondaryColor).copyWith(fontSize: 12.sp)),
        ),
        SizedBox(width: 12.w),
        Expanded(child: valueWidget),
      ],
    );
  }
}

class _CompactSummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final Color? valueColor;

  const _CompactSummaryRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp)),
          Text(
            '${value < 0 ? '− ' : ''}${NumberUtils.formatCurrency(value.abs())}',
            style: kTextSemiBold(color: valueColor ?? kTextPrimaryColor).copyWith(fontSize: 13.sp),
          ),
        ],
      ),
    );
  }
}
