import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/models/booking_model.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/models/provider_service_request_model.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/models/sub_block_model.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/widgets/cancellation_preview_sheet.dart';
import 'package:adhisaat_health_care/shared/widgets/dialogs/dialog_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum SessionDetailAction { start, complete, cancel }

class SessionDetailSheet extends StatelessWidget {
  final SubBlock block;
  final ProviderServiceRequestModel request;
  final BookingModel? booking;
  final bool isReadyToStart;
  final bool isOngoing;
  final bool isCompleted;
  final bool isCancelled;
  final bool isExpired;
  final void Function(SubBlock)? onStart;
  final void Function(SubBlock)? onComplete;
  final VoidCallback? onCancelled;

  bool get _isWaitingForPayment => request.isEmergency == 1 &&
      request.requestStatus.toLowerCase() == 'accepted' &&
      request.paymentStatus.toLowerCase() == 'pending';

  static const _purple = kSecondaryColor;
  static const _orange = Color(0xFFD97706);
  static const _navy = Color(0xFF123B61);
  static const _blue = Color(0xFF1F63A2);
  static const _greyText = Color(0xFF6B7280);
  static const _greyBg = Color(0xFFF7F8FC);
  static const _greyBorder = Color(0xFFE5E7EB);

  const SessionDetailSheet({
    super.key,
    required this.block,
    required this.request,
    this.booking,
    required this.isReadyToStart,
    required this.isOngoing,
    required this.isCompleted,
    required this.isCancelled,
    this.isExpired = false,
    this.onStart,
    this.onComplete,
    this.onCancelled,
  });

  static Future<void> show({
    required BuildContext context,
    required SubBlock block,
    required ProviderServiceRequestModel request,
    required bool isReadyToStart,
    required bool isOngoing,
    required bool isCompleted,
    required bool isCancelled,
    bool isExpired = false,
    void Function(SubBlock)? onStart,
    void Function(SubBlock)? onComplete,
    VoidCallback? onCancelled,
  }) {
    final booking = request.bookings
        .cast<BookingModel?>()
        .firstWhere((b) => b?.id == block.bookingId, orElse: () => null);

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => SessionDetailSheet(
        block: block,
        request: request,
        booking: booking,
        isReadyToStart: isReadyToStart,
        isOngoing: isOngoing,
        isCompleted: isCompleted,
        isCancelled: isCancelled,
        isExpired: isExpired,
        onStart: onStart,
        onComplete: onComplete,
        onCancelled: onCancelled,
      ),
    );
  }

  Color get _statusColor {
    if (isOngoing) return _purple;
    if (isReadyToStart) return isExpired ? Colors.grey.shade600 : _orange;
    if (isCompleted) return kSuccessColor;
    if (isCancelled) return kErrorColor;
    return kPrimaryColor;
  }

  String get _statusLabel {
    if (isOngoing) return 'Ongoing';
    if (isReadyToStart) return isExpired ? 'Expired' : 'Ready to Start';
    if (isCompleted) return 'Completed';
    if (isCancelled) return 'Cancelled';
    return 'Upcoming';
  }

  IconData get _statusIcon {
    if (isOngoing) return Icons.radio_button_checked_rounded;
    if (isReadyToStart) return isExpired ? Icons.block_rounded : Icons.play_circle_rounded;
    if (isCompleted) return Icons.check_circle_rounded;
    if (isCancelled) return Icons.cancel_rounded;
    return Icons.schedule_rounded;
  }

   String get _helpContext {
    final dateLabel = AppDateFormatter.dayMonthShort(block.scheduledDate);
    final bookingNumber = booking?.bookingNumber ?? request.requestNumber;
    return '${request.serviceCategoryName} session on $dateLabel (Booking $bookingNumber) - $_statusLabel';
  }

  @override
  Widget build(BuildContext context) {
    final fm = request.familyMember;
    final patientName = fm?.fullName ?? request.customerName;
    final relationship = fm?.relationship;

    final startFmt = AppDateFormatter.formatTimeString(block.scheduledStartTime);
    final endFmt = AppDateFormatter.formatTimeString(block.scheduledEndTime);
    final crossesMidnight = () {
      final sh = int.tryParse(block.scheduledStartTime.split(':').first) ?? 0;
      final eh = int.tryParse(block.scheduledEndTime.split(':').first) ?? 0;
      return sh > eh;
    }();
    final nextDay = block.isFullDay || (block.scheduledStartTime == block.scheduledEndTime && block.scheduledStartTime.isNotEmpty) || crossesMidnight;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 32, offset: const Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Top bar: handle + close ──
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 0),
              child: Row(
                children: [
                  SizedBox(width: 32.w),
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32.w,
                      height: 32.w,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded, size: 16.sp, color: _greyText),
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable content ──
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Status chip + booking number ──
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                          decoration: BoxDecoration(
                            color: _statusColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(color: _statusColor.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_statusIcon, size: 12.sp, color: _statusColor),
                              SizedBox(width: 5.w),
                              Text(_statusLabel, style: kTextSemiBold0(color: _statusColor)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (booking != null)
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: booking!.bookingNumber));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Booking number copied'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: _greyBg,
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(color: _greyBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    booking!.bookingNumber,
                                    style: kTextNormal0(color: _greyText).copyWith(fontSize: 11.sp),
                                  ),
                                  SizedBox(width: 4.w),
                                  Icon(Icons.copy_rounded, size: 11.sp, color: _greyText),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 14.h),

                    // ── Service name ──
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            color: _blue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.medical_services_rounded, size: 14.sp, color: _blue),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            request.serviceCategoryName,
                            style: kTextBold3(),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: request.requestNumber));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Request number copied'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                        decoration: BoxDecoration(
                          color: _greyBg,
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: _greyBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.confirmation_number_outlined, size: 12.sp, color: _greyText),
                            SizedBox(width: 5.w),
                            Text(
                              request.requestNumber,
                              style: kTextNormal0(color: _greyText).copyWith(fontSize: 11.sp),
                            ),
                            SizedBox(width: 4.w),
                            Icon(Icons.copy_rounded, size: 10.sp, color: _greyText),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 18.h),

                    // ── Date & Time Info ──
                    Row(
                      children: [
                        // Date Card
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFF),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(color: kPrimaryColor.withValues(alpha: 0.15)),
                              boxShadow: [
                                BoxShadow(
                                  color: kPrimaryColor.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(6.w),
                                      decoration: BoxDecoration(
                                        color: kPrimaryColor.withValues(alpha: 0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.calendar_today_rounded, size: 13.sp, color: kPrimaryColor),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'DATE',
                                      style: kTextBold0(color: Colors.grey.shade500).copyWith(
                                        fontSize: 9.sp,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12.h),
                                Text(
                                  AppDateFormatter.dayMonthShort(block.scheduledDate),
                                  style: kTextBold1().copyWith(fontSize: 13.5.sp, color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 3.h),
                                Text(
                                  AppDateFormatter.weekdayFull(block.scheduledDate),
                                  style: kTextMedium(color: Colors.grey.shade500).copyWith(fontSize: 11.sp),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        // Time Card
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFF),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(color: kPrimaryColor.withValues(alpha: 0.15)),
                              boxShadow: [
                                BoxShadow(
                                  color: kPrimaryColor.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(6.w),
                                      decoration: BoxDecoration(
                                        color: kPrimaryColor.withValues(alpha: 0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.schedule_rounded, size: 13.sp, color: kPrimaryColor),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'TIME',
                                      style: kTextBold0(color: Colors.grey.shade500).copyWith(
                                        fontSize: 9.sp,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12.h),
                                if (nextDay) ...[
                                  Text(
                                    startFmt,
                                    style: kTextBold1().copyWith(fontSize: 13.5.sp, color: Colors.black87),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 3.h),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.arrow_forward_rounded, size: 9.sp, color: Colors.grey.shade500),
                                      SizedBox(width: 3.w),
                                      Expanded(
                                        child: Text(
                                          'Next Day $endFmt',
                                          style: kTextMedium(color: Colors.grey.shade500).copyWith(fontSize: 10.sp),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  Text(
                                    '$startFmt – $endFmt',
                                    style: kTextBold1().copyWith(fontSize: 13.5.sp, color: Colors.black87),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 3.h),
                                  Text(
                                    'Same Day',
                                    style: kTextMedium(color: Colors.grey.shade500).copyWith(fontSize: 11.sp),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),

                    // ── Session Payout Card ──
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                      decoration: BoxDecoration(
                        gradient: isCancelled
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFFF0FDF4), Color(0xFFECFCF4)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        color: isCancelled ? Colors.grey.shade100 : null,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: isCancelled ? Colors.grey.shade300 : const Color(0xFFBBF7D0)),
                        boxShadow: isCancelled
                            ? null
                            : [
                                BoxShadow(
                                  color: kSuccessColor.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(7.w),
                            decoration: BoxDecoration(
                              color: isCancelled ? Colors.grey.shade400 : kSuccessColor,
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Icon(
                              isCancelled ? Icons.money_off_rounded : Icons.account_balance_wallet_rounded,
                              color: Colors.white,
                              size: 16.sp,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isCancelled ? 'PAYOUT' : 'YOUR PAYOUT',
                                  style: kTextBold0(color: isCancelled ? Colors.grey.shade600 : const Color(0xFF15803D))
                                      .copyWith(fontSize: 9.sp, letterSpacing: 0.8),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  isCancelled ? 'Not earned — session cancelled' : 'Session Payout',
                                  style: kTextSemiBold0(color: isCancelled ? Colors.grey.shade600 : const Color(0xFF16A34A))
                                      .copyWith(fontSize: 11.sp),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            NumberUtils.formatCurrency(block.providerPayout),
                            style: kTextBold3(color: isCancelled ? Colors.grey.shade500 : const Color(0xFF15803D))
                                .copyWith(
                                  fontSize: 18.sp,
                                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                                ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14.h),

                    // ── Patient card ──
                    Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEFF6FF), Color(0xFFF5F9FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42.w,
                            height: 42.w,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1D4ED8),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.person_rounded, size: 20.sp, color: Colors.white),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(patientName, style: kTextSemiBold1()),
                                if (relationship != null) ...[
                                  SizedBox(height: 2.h),
                                  Text(
                                    '${request.customerName} · $relationship',
                                    style: kTextNormal0(color: const Color(0xFF1D4ED8)).copyWith(fontSize: 11.sp),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(Icons.person_outline_rounded, size: 16.sp, color: const Color(0xFF1D4ED8).withValues(alpha: 0.5)),
                        ],
                      ),
                    ),

                    // ── Cancellation info ──
                    if (isCancelled && (block.cancelledAt != null || block.cancelledBy != null)) ...[
                      SizedBox(height: 14.h),
                      Container(
                        decoration: BoxDecoration(
                          color: kErrorColor.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: kErrorColor.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            if (block.cancelledBy != null)
                              _infoRow(
                                Icons.person_off_rounded,
                                'Cancelled By',
                                block.cancelledBy == 'provider' ? 'You' : 'Customer',
                                valueColor: kErrorColor,
                              ),
                            if (block.cancelledBy != null && block.cancelledAt != null)
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                child: Divider(height: 1, color: kErrorColor.withValues(alpha: 0.15)),
                              ),
                            if (block.cancelledAt != null)
                              _infoRow(
                                Icons.access_time_rounded,
                                'Cancelled At',
                                AppDateFormatter.fromApiDateTime(block.cancelledAt!),
                              ),
                          ],
                        ),
                      ),
                    ],

                    // ── Action buttons ──
                    if (!isCompleted && !isCancelled) ...[
                      SizedBox(height: 20.h),
                      if (isOngoing)
                        _actionButton(
                          label: 'Complete Session',
                          icon: Icons.verified_rounded,
                          color: _purple,
                          onTap: () {
                            Navigator.pop(context);
                            onComplete?.call(block);
                          },
                        ),
                      if (isReadyToStart)
                        _actionButton(
                          label: isExpired
                              ? 'Session Time Has Ended'
                              : (_isWaitingForPayment ? 'Waiting for Customer Payment' : 'Start Session'),
                          icon: isExpired
                              ? Icons.block_rounded
                              : (_isWaitingForPayment ? Icons.hourglass_empty_rounded : Icons.play_circle_rounded),
                          color: _orange,
                          enabled: !_isWaitingForPayment && !isExpired,
                          onDisabledTap: isExpired ? () => _showExpiredMessage(context) : null,
                          onTap: () {
                            Navigator.pop(context);
                            onStart?.call(block);
                          },
                        ),
                      if (!isOngoing && !isReadyToStart)
                        _actionButton(
                          label: 'Start Session',
                          icon: Icons.play_circle_rounded,
                          color: _orange,
                          enabled: false,
                          onDisabledTap: () => _showUpcomingMessage(context),
                          onTap: () {},
                        ),
                      if (!isOngoing) ...[
                        SizedBox(height: 10.h),
                        _actionButton(
                          label: 'Cancel Session',
                          icon: Icons.cancel_outlined,
                          color: kErrorColor,
                          outlined: true,
                          onTap: () {
                            Navigator.pop(context);
                            CancellationPreviewSheet.show(
                              context: context,
                              block: block,
                              request: request,
                              onCancelled: onCancelled,
                            );
                          },
                        ),
                      ],
                    ] else
                      SizedBox(height: 20.h),

                    // ── Need Help ──
                    SizedBox(height: 10.h),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        AppNavigator.to(AppRoutes.needHelp, arguments: _helpContext);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 13.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4FF),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: kPrimaryColor.withValues(alpha: 0.18)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.headset_mic_rounded, size: 16.sp, color: _navy),
                            SizedBox(width: 8.w),
                            Text('Need Help?', style: kTextMedium(color: _navy)),
                            SizedBox(width: 4.w),
                            Icon(Icons.arrow_forward_ios_rounded, size: 11.sp, color: _navy.withValues(alpha: 0.5)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
    bool valueBold = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Icon(icon, size: 14.sp, color: _greyText),
          SizedBox(width: 8.w),
          Text(label, style: kTextNormal(color: _greyText).copyWith(fontSize: 13.sp)),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              value,
              style: valueBold
                  ? kTextBold1(color: valueColor ?? Colors.black87)
                  : kTextSemiBold(color: valueColor ?? Colors.black87).copyWith(fontSize: 13.sp),
              textAlign: TextAlign.end,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  void _showExpiredMessage(BuildContext context) {
    DialogHelper.showError(
      title: 'Session Time Ended',
      message:
          'This session\'s scheduled time has already passed. You can no longer start it. Please contact support if you need help.',
      buttonText: 'OK',
    );
  }

  DateTime? get _sessionStart {
    try {
      final date = DateTime.parse(block.scheduledDate);
      final parts = block.scheduledStartTime.split(':');
      return DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(parts[0]),
        int.parse(parts.length > 1 ? parts[1] : '0'),
      );
    } catch (_) {
      return null;
    }
  }

  void _showUpcomingMessage(BuildContext context) {
    final start = _sessionStart;
    final message = start == null
        ? 'You can start this session 30 minutes before its scheduled shift time.'
        : 'This session is scheduled for ${AppDateFormatter.dayMonthShort(block.scheduledDate)} at '
              '${AppDateFormatter.timeOnly(start)}. You can start it from '
              '${AppDateFormatter.timeOnly(start.subtract(const Duration(minutes: 30)))} — 30 minutes before the shift begins.';
    DialogHelper.showWarning(
      title: 'Too Early to Start',
      message: message,
      buttonText: 'OK',
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool outlined = false,
    bool enabled = true,
    VoidCallback? onDisabledTap,
  }) {
    final finalBgColor = enabled
        ? (outlined ? Colors.transparent : color)
        : Colors.grey.shade200;
    final finalTextColor = enabled
        ? (outlined ? color : Colors.white)
        : Colors.grey.shade600;
    final finalBorder = outlined && enabled
        ? Border.all(color: color, width: 1.5)
        : (!enabled ? Border.all(color: Colors.grey.shade300, width: 1.5) : null);

    return GestureDetector(
      onTap: enabled ? onTap : onDisabledTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 15.h),
        decoration: BoxDecoration(
          color: finalBgColor,
          borderRadius: BorderRadius.circular(14.r),
          border: finalBorder,
          boxShadow: (outlined || !enabled)
              ? null
              : [BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18.sp, color: finalTextColor),
            SizedBox(width: 8.w),
            Text(
              label,
              style: kTextSemiBold1(color: finalTextColor),
            ),
          ],
        ),
      ),
    );
  }
}
