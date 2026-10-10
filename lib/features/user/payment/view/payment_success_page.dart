import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/user/booking_history/model/booking_detail_model.dart';
import 'package:adhisaat_health_care/features/user/service_booking/data/service_request_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/services/file_downloading_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/buttons/custom_button.dart';
import '../data/payment_repository.dart';

class PaymentSuccessPage extends StatefulWidget {
  final int serviceRequestId;
  final String? unitType;

  const PaymentSuccessPage({super.key, required this.serviceRequestId, this.unitType});

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isDownloading = false;
  double? _amount;
  String? _serviceName;
  int? _paymentId;
  String? _paymentNumber;
  String? _bookingNumber;
  String? _paidAt;
  double? _basePrice;
  double? _gst;
  double? _surge;
  double? _walletUsed;
  double? _bonusUsed;
  String? _scheduleText;

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
      ),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final response = await locator<ServiceRequestRepository>().getServiceRequestDetailsById(
        widget.serviceRequestId,
      );
      final model = BookingDetailModel.fromJson(response);
      final sr = model.serviceRequest;
      // Find the paid installment — search by status and get the latest paid
      final paidInstallments = sr.paymentInstallments.where((i) => i.isPaid).toList();
      paidInstallments.sort((a, b) {
        if (a.paidAt == null && b.paidAt == null) return 0;
        if (a.paidAt == null) return 1;
        if (b.paidAt == null) return -1;
        return DateTime.parse(b.paidAt!).compareTo(DateTime.parse(a.paidAt!));
      });
      final installment = paidInstallments.firstOrNull ?? sr.paymentInstallments.firstOrNull;
      final payment = installment?.payment;

      double calculatedAmount = 0.0;
      double calculatedBasePrice = 0.0;
      double calculatedWallet = 0.0;
      double calculatedBonus = 0.0;

      /* if (payment != null && payment.transactionId != null) {
        final sameTransaction = paidInstallments.where((i) => i.payment?.transactionId == payment.transactionId);
        for (var i in sameTransaction) {
          final p = i.payment!;
          calculatedAmount += (p.subtotal - p.discountAmount);
          calculatedBasePrice += p.subtotal;
          calculatedWallet += p.walletAmountUsed;
          calculatedBonus += p.bonusAmountUsed;
        }
      } else*/
      if (payment != null) {
        calculatedAmount = payment.subtotal - payment.discountAmount;
        calculatedBasePrice = payment.subtotal;
        calculatedWallet = payment.walletAmountUsed;
        calculatedBonus = payment.bonusAmountUsed;
      } else {
        calculatedAmount = sr.totalAmount;
        calculatedBasePrice = sr.basePrice;
      }

      setState(() {
        _paidAt = installment?.paidAt;
        _paymentId = payment?.id;
        _paymentNumber = payment?.paymentNumber;
        _bookingNumber = sr.requestNumber;
        _amount = calculatedAmount;
        _serviceName = sr.service?.name;
        _basePrice = calculatedBasePrice;
        _gst = (sr.pricingBreakdown?.gstAmount ?? 0) > 0 ? sr.pricingBreakdown?.gstAmount : null;
        _surge = (sr.pricingBreakdown?.surgeCharge ?? 0) > 0 ? sr.pricingBreakdown?.surgeCharge : null;
        _walletUsed = calculatedWallet > 0 ? calculatedWallet : null;
        _bonusUsed = calculatedBonus > 0 ? calculatedBonus : null;
        _scheduleText = _buildScheduleText(sr);
        _isLoading = false;
      });
      _controller.forward();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        setState(() => _isLoading = false);
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _viewReceipt() async {
    if (_paymentId == null) return;
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final repo = locator<PaymentRepository>();
      final pathOrUrl = await repo.downloadInvoice(_paymentId!, _paymentNumber ?? '');
      if (pathOrUrl != null && mounted) {
        await FileDownloadService().downloadAndViewFile(
          url: pathOrUrl,
          originalName: "${_paymentNumber ?? 'receipt'}.pdf",
        );
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to get receipt. Please try again later.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  String _formatPaidAt() {
    if (_paidAt != null) {
      final dt = DateTime.tryParse(_paidAt!);
      if (dt != null) return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
    }
    return DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
  }

  String? _buildScheduleText(dynamic sr) {
    try {
      final startDateRaw = sr.startDate as String?;
      final endDateRaw = sr.endDate as String?;
      final startTimeRaw = sr.startTime as String?;
      final endTimeRaw = sr.endTime as String?;
      final days = sr.durationDays as int?;
      final hrs = (sr.durationHours as num?)?.toInt();

      if (startDateRaw == null || startDateRaw.isEmpty) return null;

      final startDt = DateTime.tryParse(startDateRaw);
      final endDt = endDateRaw != null && endDateRaw.isNotEmpty ? DateTime.tryParse(endDateRaw) : null;

      final startFmt = startDt != null ? DateFormat('dd MMM yyyy').format(startDt) : startDateRaw;
      final endFmt = endDt != null ? DateFormat('dd MMM yyyy').format(endDt) : endDateRaw;

      final isMultiDay = endDt != null && endDt.isAfter(startDt ?? endDt);
      final dateText = isMultiDay ? '$startFmt → $endFmt' : startFmt;

      String? timeRange;
      if (startTimeRaw != null && startTimeRaw.isNotEmpty) {
        final sFmt = _fmtRawTime(startTimeRaw);
        final eFmt = endTimeRaw != null && endTimeRaw.isNotEmpty ? _fmtRawTime(endTimeRaw) : null;
        timeRange = eFmt != null ? '$sFmt – $eFmt' : sFmt;
      }

      final line1 = timeRange != null ? '$dateText  ·  $timeRange' : dateText;

      if (isMultiDay && days != null && days > 1 && hrs != null && hrs > 0) {
        final ut = widget.unitType;
        final perDay = ut != null ? '$hrs $ut / day' : '$hrs hr${hrs != 1 ? 's' : ''} / day';
        return '$line1\n$days days · $perDay';
      }
      return line1;
    } catch (_) {
      return null;
    }
  }

  /// Parses "06:00:00" or "06:00" → "6:00 AM"
  String _fmtRawTime(String raw) {
    try {
      final parts = raw.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return DateFormat.jm().format(DateTime(2000, 1, 1, h, m));
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) AppNavigator.popToRoot(context);
      },
      child: Scaffold(
        backgroundColor: kScaffoldColor,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
            : Stack(
                children: [
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        // ── Hero ──────────────────────────────────────────
                        _HeroSection(
                          amount: _amount,
                          bookingNumber: _bookingNumber,
                          scaleAnimation: _scaleAnimation,
                          fadeAnimation: _fadeAnimation,
                        ),

                        // ── Receipt Card ──────────────────────────────────
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: _ReceiptCard(
                              serviceName: _serviceName,
                              scheduleText: _scheduleText,
                              paymentNumber: _paymentNumber,
                              paidAtText: _formatPaidAt(),
                              amount: _amount,
                              basePrice: _basePrice,
                              gst: _gst,
                              surge: _surge,
                              walletUsed: _walletUsed,
                              bonusUsed: _bonusUsed,
                              onInvoiceTap: _paymentId != null ? _viewReceipt : null,
                              isDownloading: _isDownloading,
                            ),
                          ),
                        ),

                        SizedBox(height: MediaQuery.of(context).padding.bottom),
                      ],
                    ),
                  ),

                  // Close button
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.only(top: 6.h, right: 8.w),
                        child: IconButton(
                          onPressed: () => AppNavigator.popToRoot(context),
                          icon: Container(
                            padding: EdgeInsets.all(6.w),
                            decoration: BoxDecoration(
                              color: kWhiteColor.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
                            ),
                            child: Icon(Icons.close_rounded, size: 18.sp, color: kTextPrimaryColor),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: _isLoading
            ? null
            : FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h + MediaQuery.of(context).padding.bottom),
                  decoration: BoxDecoration(
                    color: kWhiteColor,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => AppNavigator.popToRoot(context),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            decoration: BoxDecoration(
                              color: kWhiteColor,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(color: kBorderColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.home_outlined, size: 18.sp, color: kPrimaryColor),
                                SizedBox(width: 6.w),
                                Text(
                                  'Home',
                                  style: kTextSemiBold(color: kPrimaryColor).copyWith(fontSize: 14.sp),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: CustomButton(
                          title: 'View Booking',
                          onPressed: () => AppNavigator.toAndRemoveUntil(
                            AppRoutes.serviceRequestDetail,
                            args: widget.serviceRequestId,
                          ),
                          backgroundColor: kPrimaryColor,
                          borderRadius: BorderRadius.circular(16.r),
                          height: 54.h,
                          textStyle: kTextBold(color: kWhiteColor).copyWith(fontSize: 14.sp),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// ─── Hero Section ─────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final double? amount;
  final String? bookingNumber;
  final Animation<double> scaleAnimation;
  final Animation<double> fadeAnimation;

  const _HeroSection({
    required this.amount,
    this.bookingNumber,
    required this.scaleAnimation,
    required this.fadeAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32.r), bottomRight: Radius.circular(32.r)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 48.h, 24.w, 32.h),
          child: Column(
            children: [
              // Animated check icon
              ScaleTransition(
                scale: scaleAnimation,
                child: Container(
                  width: 88.w,
                  height: 88.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [kSuccessColor, const Color(0xFF00C566)],
                    ),
                    boxShadow: [
                      BoxShadow(color: kSuccessColor.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 4),
                    ],
                  ),
                  child: Icon(Icons.check_rounded, color: kWhiteColor, size: 44.sp),
                ),
              ),

              SizedBox(height: 20.h),

              FadeTransition(
                opacity: fadeAnimation,
                child: Column(
                  children: [
                    Text(
                      'Payment Successful',
                      style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 22.sp),
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: kSuccessColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6.w,
                            height: 6.w,
                            decoration: const BoxDecoration(color: kSuccessColor, shape: BoxShape.circle),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'Booking Confirmed',
                            style: kTextSemiBold(color: kSuccessColor).copyWith(fontSize: 12.sp),
                          ),
                        ],
                      ),
                    ),

                    if (bookingNumber != null) ...[
                      SizedBox(height: 10.h),
                      Text(
                        '#$bookingNumber',
                        style: kTextSemiBold(color: kTextSecondaryColor).copyWith(fontSize: 14.sp),
                      ),
                    ],

                    // if (amount != null) ...[
                    //   SizedBox(height: 20.h),
                    //   Text(
                    //     "$bookingNumber",
                    //     style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 36.sp),
                    //   ),
                    //   SizedBox(height: 4.h),
                    //   Text(
                    //     'Total Amount Paid',
                    //     style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 13.sp),
                    //   ),
                    // ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Receipt Card ─────────────────────────────────────────────────────────────

class _ReceiptCard extends StatelessWidget {
  final String? serviceName;
  final String? scheduleText;
  final String? paymentNumber;
  final String paidAtText;
  final double? amount;
  final double? basePrice;
  final double? gst;
  final double? surge;
  final double? walletUsed;
  final double? bonusUsed;
  final VoidCallback? onInvoiceTap;
  final bool isDownloading;

  const _ReceiptCard({
    required this.serviceName,
    this.scheduleText,
    required this.paymentNumber,
    required this.paidAtText,
    required this.amount,
    this.basePrice,
    this.gst,
    this.surge,
    this.walletUsed,
    this.bonusUsed,
    this.onInvoiceTap,
    this.isDownloading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 0),
      child: Container(
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card header
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 14.h),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(Icons.receipt_long_rounded, color: kPrimaryColor, size: 18.sp),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    'Transaction Details',
                    style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 15.sp),
                  ),
                ],
              ),
            ),

            _dashedDivider(),

            // Rows
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
              child: Column(
                children: [
                  if (serviceName != null)
                    _Row(
                      icon: Icons.medical_services_rounded,
                      label: 'Service',
                      value: serviceName!,
                      subtitle: scheduleText,
                    ),
                  if (paymentNumber != null)
                    _Row(
                      icon: Icons.tag_rounded,
                      label: 'Payment ID',
                      value: paymentNumber!,
                      onTrailing: isDownloading ? null : onInvoiceTap,
                      trailingIcon: isDownloading ? null : Icons.receipt_long_rounded,
                      trailingLoading: isDownloading,
                    ),
                  _Row(icon: Icons.calendar_today_rounded, label: 'Date & Time', value: paidAtText),
                ],
              ),
            ),

            _dashedDivider(),

            // Total
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 18.h),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(7.w),
                    decoration: BoxDecoration(
                      color: kSuccessColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(Icons.currency_rupee_rounded, color: kSuccessColor, size: 16.sp),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'Amount Paid',
                    style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
                  ),
                  const Spacer(),
                  Text(
                    NumberUtils.formatCurrency(amount),
                    style: kTextBold(color: kSuccessColor).copyWith(fontSize: 18.sp),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashedDivider() {
    return CustomPaint(size: Size(double.infinity, 1), painter: _DashedLinePainter());
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color? valueColor;
  final VoidCallback? onTrailing;
  final IconData? trailingIcon;
  final bool trailingLoading;

  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.onTrailing,
    this.trailingIcon,
    this.trailingLoading = false,
  }) : valueColor = null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: kGreyColor1.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, size: 15.sp, color: kTextSecondaryColor),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: kTextSemiBold(color: valueColor ?? kTextPrimaryColor).copyWith(fontSize: 13.sp),
                  maxLines: 2,
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 2.h),
                  Text(
                    subtitle!,
                    style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          if (trailingLoading)
            Padding(
              padding: EdgeInsets.all(6.w),
              child: SizedBox(
                width: 13.sp,
                height: 13.sp,
                child: const CircularProgressIndicator(strokeWidth: 1.5, color: kPrimaryColor),
              ),
            )
          else if (onTrailing != null && trailingIcon != null)
            GestureDetector(
              onTap: onTrailing,
              child: Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Icon(trailingIcon, size: 13.sp, color: kPrimaryColor),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Dashed line painter ──────────────────────────────────────────────────────

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFEEEFF1)
      ..strokeWidth = 1;
    double x = 0;
    const dashW = 6.0;
    const gap = 4.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashW, 0), paint);
      x += dashW + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
