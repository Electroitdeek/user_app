import 'dart:async';

import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/models/cancellation_preview_model.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/models/provider_service_request_model.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/models/sub_block_model.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/repositories/provider_request_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CancellationPreviewSheet extends StatefulWidget {
  final SubBlock block;
  final ProviderServiceRequestModel request;
  final VoidCallback? onCancelled;

  const CancellationPreviewSheet({super.key, required this.block, required this.request, this.onCancelled});

  static Future<void> show({
    required BuildContext context,
    required SubBlock block,
    required ProviderServiceRequestModel request,
    VoidCallback? onCancelled,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => CancellationPreviewSheet(block: block, request: request, onCancelled: onCancelled),
    );
  }

  @override
  State<CancellationPreviewSheet> createState() => _CancellationPreviewSheetState();
}

class _CancellationPreviewSheetState extends State<CancellationPreviewSheet> with SingleTickerProviderStateMixin {
  static const _orange = Color(0xFFD97706);
  static const _red = Color(0xFFDC2626);
  static const _navy = Color(0xFF123B61);
  static const _greyText = Color(0xFF6B7280);
  static const _greyBg = Color(0xFFF7F8FC);

  CancellationPreviewModel? _preview;
  bool _loading = true;
  String? _error;
  bool _confirming = false;
  String? _selectedReason;
  bool _reasonError = false;

  static const _reasons = [
    'Not available at scheduled time',
    'Personal emergency',
    'Schedule conflict',
    'Unable to reach on time',
    'Location too far',
    'Transportation issue',
    'Shift timing not feasible',
    'Long duration commitment issue',
    'Service not suitable for me',
    'Required skills/equipment unavailable',
    'Incorrect booking details',
    'Patient unavailable',
    'Duplicate booking',
    'Other reason',
  ];

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _fetchPreview();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPreview() async {
    try {
      final bookingId = widget.block.bookingId ?? widget.request.bookings.firstOrNull?.id ?? 0;
      final preview = await locator<ProviderRequestRepository>().getCancellationPreview(
        serviceRequestId: widget.request.id,
        bookingId: bookingId,
        subBlockIds: [widget.block.id],
      );
      if (mounted) {
        setState(() {
          _preview = preview;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _confirmCancel() async {
    if (_confirming) return;
    if (_selectedReason == null) {
      setState(() => _reasonError = true);
      return;
    }
    setState(() => _confirming = true);
    try {
      final bookingId = widget.block.bookingId ?? widget.request.bookings.firstOrNull?.id ?? 0;
      await locator<ProviderRequestRepository>().cancelSession(
        serviceRequestId: widget.request.id,
        bookingId: bookingId,
        subBlockIds: [widget.block.id],
        reason: _selectedReason,
      );
      if (mounted) {
        Navigator.pop(context);
        await _showCancelSuccess();
        widget.onCancelled?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _confirming = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: _red));
      }
    }
  }

  Future<void> _showCancelSuccess() {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CancelSuccessDialog(block: widget.block),
    );
  }

  // ── Colour/label helpers ──────────────────────────────────────────────────

  Color _accentColor(CancellationPreviewModel p) {
    if (!p.allowed) return _red;
    if (p.totalPenalty <= 0) return const Color(0xFF16A34A);
    if (p.totalPenalty < 300) return _orange;
    return _red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: _loading
            ? _buildLoading()
            : _error != null
            ? _buildError()
            : _buildContent(_preview!),
      ),
    );
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 48.h, horizontal: 24.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          SizedBox(height: 32.h),
          const CircularProgressIndicator(),
          SizedBox(height: 16.h),
          Text('Checking cancellation eligibility…', style: kTextNormal(color: _greyText)),
        ],
      ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          SizedBox(height: 24.h),
          Icon(Icons.error_outline_rounded, size: 48.sp, color: _red),
          SizedBox(height: 12.h),
          Text('Could not load preview', style: kTextBold1()),
          SizedBox(height: 6.h),
          Text(
            _error!,
            style: kTextNormal(color: _greyText),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20.h),
          _fullBtn('Retry', _orange, () {
            setState(() {
              _loading = true;
              _error = null;
            });
            _fetchPreview();
          }),
          SizedBox(height: 10.h),
          _outlineBtn('Close', () => Navigator.pop(context)),
        ],
      ),
    );
  }

  // ── Main content ───────────────────────────────────────────────────────────

  Widget _buildContent(CancellationPreviewModel p) {
    final accent = _accentColor(p);
    final patientName = widget.request.familyMember?.fullName ?? widget.request.customerName;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _handle(),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 10.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Impact summary header ──
                _buildImpactHeader(p, accent),
                SizedBox(height: 14.h),

                // ── Session card ──
                _buildSessionCard(patientName),
                SizedBox(height: 12.h),

                // ── Financial summary ──
                _buildFinancialSummary(p, accent),
                SizedBox(height: 12.h),

                // ── Reason ──
                if (p.allowed) ...[_buildReasonDropdown(), SizedBox(height: 8.h)],

                // ── Reliability notice ──
                SizedBox(height: 16.h),
                _buildReliabilityNotice(),
              ],
            ),
          ),
        ),
        // ── Sticky Actions at the bottom ──
        Container(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade100)),
          ),
          child: _buildActions(p, accent),
        ),
      ],
    );
  }

  // ── Impact header ─────────────────────────────────────────────────────────

  Widget _buildImpactHeader(CancellationPreviewModel p, Color accent) {
    final isBlocked = !p.allowed;
    final hasPenalty = p.hasPenalty;

    final title = isBlocked
        ? 'Session Cannot Be Cancelled'
        : hasPenalty
        ? 'Cancellation Penalty Applies'
        : 'Cancellation Allowed';

    final subtitle = isBlocked
        ? 'This session is too close to start time. Cancellation is no longer permitted.'
        : hasPenalty
        ? '${NumberUtils.formatCurrency(p.totalPenalty)} will be deducted from your wallet if you cancel this session.'
        : 'No amount will be deducted from your wallet. No cancellation fee applies for this session.';

    final icon = isBlocked
        ? Icons.block_rounded
        : hasPenalty
        ? Icons.account_balance_wallet_rounded
        : Icons.check_circle_rounded;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10.r)),
                child: hasPenalty && !isBlocked
                    ? ScaleTransition(
                        scale: _pulseAnim,
                        child: Icon(icon, color: accent, size: 18.sp),
                      )
                    : Icon(icon, color: accent, size: 18.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: kTextBold1(color: accent)),
                    SizedBox(height: 4.h),
                    Text(
                      subtitle,
                      style: kTextNormal(color: Colors.black87).copyWith(fontSize: 12.sp, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Session card ──────────────────────────────────────────────────────────

  Widget _buildSessionCard(String patientName) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          _sessionRow(
            leading: Container(
              padding: EdgeInsets.all(7.w),
              decoration: BoxDecoration(color: _navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8.r)),
              child: Icon(Icons.medical_services_outlined, size: 14.sp, color: _navy),
            ),
            label: widget.request.serviceCategoryName,
            sublabel: widget.request.requestNumber,
          ),
          Divider(height: 20.h, color: Colors.grey.shade100),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _iconLabelValue(Icons.calendar_today_rounded, 'Date', AppDateFormatter.dayMonthShort(widget.block.scheduledDate))),
              Container(width: 1, height: 32.h, color: Colors.grey.shade100),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 16.w),
                  child: _iconLabelValue(Icons.schedule_rounded, 'Time', widget.block.timeRange),
                ),
              ),
            ],
          ),
          Divider(height: 20.h, color: Colors.grey.shade100),
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(7.w),
                decoration: BoxDecoration(color: const Color(0xFF1D4ED8).withValues(alpha: 0.08), shape: BoxShape.circle),
                child: Icon(Icons.person_rounded, size: 14.sp, color: const Color(0xFF1D4ED8)),
              ),
              SizedBox(width: 10.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patient',
                    style: kTextNormal0(color: _greyText).copyWith(fontSize: 10.sp),
                  ),
                  Text(patientName, style: kTextSemiBold0(color: Colors.black87)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sessionRow({required Widget leading, required String label, String? sublabel}) {
    return Row(
      children: [
        leading,
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: kTextSemiBold0(color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
              if (sublabel != null)
                Text(
                  sublabel,
                  style: kTextNormal0(color: _greyText).copyWith(fontSize: 10.sp),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconLabelValue(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: kTextNormal0(color: _greyText).copyWith(fontSize: 10.sp),
        ),
        SizedBox(height: 2.h),
        Row(
          children: [
            Icon(icon, size: 11.sp, color: _navy),
            SizedBox(width: 6.w),
            Flexible(
              child: Text(
                value,
                style: kTextSemiBold0(color: Colors.black87),
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Financial summary ──────────────────────────────────────────────────────

  Widget _buildFinancialSummary(CancellationPreviewModel p, Color accent) {
    final sessionAmount = widget.block.providerPayout;
    final penalty = p.totalPenalty;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: _greyBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _finRow('Session Amount', NumberUtils.formatCurrency(sessionAmount), Colors.black87),
          Divider(height: 16.h, color: Colors.grey.shade200),
          _finRow('Wallet Deduction', penalty > 0 ? NumberUtils.formatCurrency(penalty) : '₹0', penalty > 0 ? accent : kSuccessColor, bold: true),
          Divider(height: 16.h, color: Colors.grey.shade200),
          _finRow('Cancellation Fee', penalty > 0 ? 'Applied' : 'N/A', penalty > 0 ? accent : kSuccessColor),
        ],
      ),
    );
  }

  Widget _finRow(String label, String value, Color valueColor, {bool bold = false}) {
    return Row(
      children: [
        Text(
          label,
          style: kTextNormal(color: _greyText).copyWith(fontSize: 13.sp),
        ),
        const Spacer(),
        Text(
          value,
          style: bold ? kTextBold1(color: valueColor) : kTextSemiBold(color: valueColor).copyWith(fontSize: 13.sp),
        ),
      ],
    );
  }

  // ── Reliability notice ────────────────────────────────────────────────────

  Widget _buildReliabilityNotice() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: kPrimaryColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 14.sp, color: kPrimaryColor),
              SizedBox(width: 6.w),
              Text('Reliability Notice', style: kTextSemiBold0(color: kPrimaryColor)),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'Frequent cancellations may affect your:',
            style: kTextNormal(color: Colors.black87).copyWith(fontSize: 12.sp),
          ),
          SizedBox(height: 6.h),
          ...['Partner performance score', 'Reliability rating', 'Future booking priority'].map(
            (item) => Padding(
              padding: EdgeInsets.only(top: 3.h),
              child: Row(
                children: [
                  Container(
                    width: 4.w,
                    height: 4.w,
                    margin: EdgeInsets.only(right: 8.w, top: 1.h),
                    decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.6), shape: BoxShape.circle),
                  ),
                  Text(
                    item,
                    style: kTextNormal(color: Colors.black54).copyWith(fontSize: 12.sp),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reason dropdown ───────────────────────────────────────────────────────

  Widget _buildReasonDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Why are you cancelling?', style: kTextSemiBold0(color: _navy)),
            SizedBox(width: 4.w),
            Text('*', style: kTextBold1(color: _red)),
          ],
        ),
        SizedBox(height: 8.h),
        GestureDetector(
          onTap: _showReasonPicker,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
            decoration: BoxDecoration(
              color: _reasonError && _selectedReason == null ? _red.withValues(alpha: 0.04) : _greyBg,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: _reasonError && _selectedReason == null
                    ? _red.withValues(alpha: 0.5)
                    : _selectedReason != null
                    ? _navy.withValues(alpha: 0.4)
                    : Colors.grey.shade300,
                width: _reasonError && _selectedReason == null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.flag_outlined, size: 16.sp, color: _selectedReason != null ? _navy : Colors.grey.shade400),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    _selectedReason ?? 'Select a reason…',
                    style: _selectedReason != null
                        ? kTextSemiBold0(color: _navy)
                        : kTextNormal(color: Colors.grey.shade400).copyWith(fontSize: 13.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded, size: 18.sp, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
        if (_reasonError && _selectedReason == null) ...[
          SizedBox(height: 5.h),
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 12.sp, color: _red),
              SizedBox(width: 4.w),
              Text(
                'Please select a reason to proceed',
                style: kTextNormal0(color: _red).copyWith(fontSize: 11.sp),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _showReasonPicker() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: EdgeInsets.symmetric(vertical: 12.h),
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2.r)),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, size: 16.sp, color: _navy),
                      SizedBox(width: 8.w),
                      Text('Why are you cancelling?', style: kTextSemiBold1(color: _navy)),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                Divider(height: 1, color: Colors.grey.shade200),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _reasons.length,
                  separatorBuilder: (context0, i0) => Divider(height: 1, indent: 20.w, endIndent: 20.w, color: Colors.grey.shade100),
                  itemBuilder: (_, i) {
                    final reason = _reasons[i];
                    final isSelected = _selectedReason == reason;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedReason = reason;
                          _reasonError = false;
                        });
                        Navigator.pop(context);
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                reason,
                                style: isSelected ? kTextSemiBold0(color: _navy) : kTextNormal(color: Colors.black87).copyWith(fontSize: 13.sp),
                              ),
                            ),
                            if (isSelected) Icon(Icons.check_circle_rounded, size: 18.sp, color: _navy),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Widget _buildActions(CancellationPreviewModel p, Color accent) {
    final ctaLabel = !p.allowed
        ? 'Cannot Cancel'
        : p.hasPenalty
        ? 'Cancel Session  ·  ${NumberUtils.formatCurrency(p.totalPenalty)} Deduction'
        : 'Cancel Session';

    return Column(
      children: [
        if (p.allowed)
          GestureDetector(
            onTap: _confirming ? null : _confirmCancel,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 15.h),
              decoration: BoxDecoration(
                color: _confirming ? _red.withValues(alpha: 0.5) : _red,
                borderRadius: BorderRadius.circular(14.r),
                boxShadow: _confirming ? null : [BoxShadow(color: _red.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: _confirming
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16.sp,
                          height: 16.sp,
                          child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                        SizedBox(width: 10.w),
                        Text('Cancelling…', style: kTextSemiBold1(color: Colors.white)),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cancel_outlined, size: 18.sp, color: Colors.white),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Text(
                            ctaLabel,
                            style: kTextSemiBold1(color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        if (!p.allowed)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 15.h),
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(14.r)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.block_rounded, size: 16.sp, color: Colors.grey.shade500),
                SizedBox(width: 8.w),
                Text(ctaLabel, style: kTextSemiBold1(color: Colors.grey.shade500)),
              ],
            ),
          ),
        SizedBox(height: 10.h),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 15.h),
            decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(14.r)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_outlined, size: 16.sp, color: _navy),
                SizedBox(width: 8.w),
                Text('Keep Session', style: kTextSemiBold1(color: _navy)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Button helpers ─────────────────────────────────────────────────────────

  Widget _fullBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 13.h),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12.r)),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: kTextSemiBold1(color: Colors.white),
        ),
      ),
    );
  }

  Widget _outlineBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 13.h),
        decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(14.r)),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: kTextSemiBold1(color: _navy),
        ),
      ),
    );
  }

  Widget _handle() => Center(
    child: Container(
      margin: EdgeInsets.symmetric(vertical: 12.h),
      width: 40.w,
      height: 4.h,
      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2.r)),
    ),
  );
}

class _CancelSuccessDialog extends StatefulWidget {
  final SubBlock block;

  const _CancelSuccessDialog({required this.block});

  @override
  State<_CancelSuccessDialog> createState() => _CancelSuccessDialogState();
}

class _CancelSuccessDialogState extends State<_CancelSuccessDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<double>(begin: 15.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Concentric ripple success icon with scale animation
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 84.w,
                height: 84.w,
                decoration: BoxDecoration(
                  color: kSuccessColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: BoxDecoration(
                    color: kSuccessColor.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 46.w,
                    height: 46.w,
                    decoration: BoxDecoration(
                      color: kSuccessColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: kSuccessColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(Icons.check_rounded, color: Colors.white, size: 26.sp),
                  ),
                ),
              ),
            ),
            SizedBox(height: 24.h),
            
            // Fading and sliding text content
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Session Cancelled',
                    style: kTextBold2().copyWith(
                      color: Colors.black87,
                      fontSize: 19.sp,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    'Your session has been successfully cancelled. No further action is required.',
                    style: kTextNormal(color: const Color(0xFF6B7280)).copyWith(
                      fontSize: 13.sp,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FC),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 13.sp, color: const Color(0xFF6B7280)),
                        SizedBox(width: 6.w),
                        Flexible(
                          child: Text(
                            AppDateFormatter.dayMonthShort(widget.block.scheduledDate),
                            style: kTextSemiBold0(color: const Color(0xFF374151)).copyWith(fontSize: 12.sp),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Icon(Icons.schedule_rounded, size: 13.sp, color: const Color(0xFF6B7280)),
                        SizedBox(width: 6.w),
                        Flexible(
                          child: Text(
                            widget.block.timeRange,
                            style: kTextSemiBold0(color: const Color(0xFF374151)).copyWith(fontSize: 12.sp),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF123B61),
                        borderRadius: BorderRadius.circular(14.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF123B61).withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        'Done',
                        textAlign: TextAlign.center,
                        style: kTextSemiBold1(color: Colors.white).copyWith(fontSize: 15.sp),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

