import 'dart:async';

import 'package:adhisaat_health_care/core/services/location_service.dart';
import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/message_service.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/models/provider_service_request_model.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/repositories/provider_request_repository.dart';
import 'package:adhisaat_health_care/shared/widgets/buttons/custom_button.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CompleteBookingSheet extends StatefulWidget {
  final ProviderServiceRequestModel request;
  final int bookingId;
  final String mobileNumber;
  final VoidCallback onSuccess;

  const CompleteBookingSheet({
    super.key,
    required this.request,
    required this.bookingId,
    required this.mobileNumber,
    required this.onSuccess,
  });

  @override
  State<CompleteBookingSheet> createState() => _CompleteBookingSheetState();
}

class _CompleteBookingSheetState extends State<CompleteBookingSheet> {
  static const _blue = Color(0xFF2D62ED);
  static const _grey = Color(0xFF6B7280);
  static const _greyBorder = Color(0xFFE5E7EB);

  final _otpController = TextEditingController();
  final _repo = locator<ProviderRequestRepository>();

  bool _otpSending = true;
  bool _otpSent = false;
  bool _completing = false;
  String? _otpError;
  String? _completeError;
  int _resendCountdown = 30;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendOtp({bool resend = false}) async {
    setState(() {
      _otpSending = true;
      _otpError = null;
    });
    try {
      await _repo.sendCompletionOtp(
        bookingId: widget.bookingId,
        mobileNumber: widget.mobileNumber,
        resend: resend,
      );
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _otpSending = false;
        _resendCountdown = 30;
      });
      _startResendTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _otpSending = false;
        _otpError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendCountdown <= 1) {
        t.cancel();
        setState(() => _resendCountdown = 0);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _completeBooking() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4) {
      setState(() => _completeError = 'Please enter a valid OTP');
      return;
    }
    setState(() {
      _completing = true;
      _completeError = null;
    });
    try {
      final position = await LocationService().getLocationPosition();
      if (position == null) {
        setState(() {
          _completing = false;
          _completeError = 'Location permission is required to complete the booking.';
        });
        return;
      }
      await _repo.completeBooking(
        bookingId: widget.bookingId,
        otp: otp,
        checkoutLatitude: position.latitude,
        checkoutLongitude: position.longitude,
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
      MessageService.showSuccess('Booking completed successfully!');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _completing = false;
        _completeError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: AppPadding.only(top: 12, bottom: 4),
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(color: _greyBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: AppPadding.symmetric(h: 20, v: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: AppPadding.all(8),
                          decoration: BoxDecoration(
                            color: _blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(Icons.verified_outlined, color: _blue, size: 22.sp),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Complete Booking', style: kTextBold2()),
                            Text('OTP verification required', style: kTextNormal0(color: _grey)),
                          ]),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, size: 22.sp, color: _grey),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),
                    Container(
                      padding: AppPadding.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: _greyBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50.w,
                            height: 50.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _blue.withValues(alpha: 0.08),
                              border: Border.all(color: _blue.withValues(alpha: 0.2)),
                            ),
                            child: widget.request.customerProfileImageUrl != null
                                ? AppCachedImage(
                                    imageUrl: widget.request.customerProfileImageUrl, isOval: true)
                                : Center(
                                    child: Text(
                                      widget.request.customerName.isNotEmpty
                                          ? widget.request.customerName[0].toUpperCase()
                                          : '?',
                                      style: kTextBold2(color: _blue),
                                    ),
                                  ),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(
                                widget.request.customerName.isNotEmpty
                                    ? widget.request.customerName
                                    : 'Customer',
                                style: kTextSemiBold1(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4.h),
                              Row(children: [
                                Icon(Icons.phone_outlined, size: 14.sp, color: _grey),
                                SizedBox(width: 4.w),
                                Text(widget.mobileNumber, style: kTextNormal0(color: _grey)),
                              ]),
                              SizedBox(height: 4.h),
                              Row(children: [
                                Icon(Icons.medical_services_outlined, size: 14.sp, color: _grey),
                                SizedBox(width: 4.w),
                                Expanded(
                                  child: Text(widget.request.serviceCategoryName,
                                      style: kTextNormal0(color: _grey),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ]),
                            ]),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                    if (_otpSending) ...[
                      Container(
                        padding: AppPadding.all(14),
                        decoration: BoxDecoration(
                          color: _blue.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: _blue.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 18.sp,
                              height: 18.sp,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _blue),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text('Sending OTP to ${NumberUtils.maskPhone(widget.mobileNumber)}…',
                                  style: kTextNormal(color: _blue)),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20.h),
                    ],
                    if (_otpError != null && !_otpSending) ...[
                      Container(
                        padding: AppPadding.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red, size: 18.sp),
                            SizedBox(width: 8.w),
                            Expanded(child: Text(_otpError!, style: kTextNormal(color: Colors.red))),
                          ],
                        ),
                      ),
                      SizedBox(height: 12.h),
                      CustomButton(
                        onPressed: () => _sendOtp(),
                        title: 'Retry Send OTP',
                        iconData: Icons.refresh_rounded,
                        backgroundColor: Colors.white,
                        textColor: _blue,
                        borderSide: const BorderSide(color: Color(0xFF2D62ED)),
                        borderRadius: BorderRadius.circular(10.r),
                        height: 44.h,
                      ),
                      SizedBox(height: 20.h),
                    ],
                    if (_otpSent) ...[
                      Container(
                        padding: AppPadding.symmetric(h: 14, v: 10),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          Icon(Icons.mark_email_read_outlined, color: Colors.green.shade600, size: 18.sp),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text('OTP sent to ${NumberUtils.maskPhone(widget.mobileNumber)}. Valid for 10 minutes.',
                                style: kTextNormal(color: Colors.green.shade700)),
                          ),
                        ]),
                      ),
                      SizedBox(height: 20.h),
                      Text('Enter OTP from Patient', style: kTextSemiBold1()),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: kTextBold2(),
                        textAlign: TextAlign.center,
                        autofocus: true,
                        onChanged: (_) {
                          if (_completeError != null) setState(() => _completeError = null);
                        },
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '· · · · · ·',
                          hintStyle: kTextBold1(color: const Color(0xFFD1D5DB)),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          contentPadding: AppPadding.symmetric(h: 16, v: 16),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: const BorderSide(color: Color(0xFF2D62ED), width: 2)),
                          errorText: _completeError,
                          errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: const BorderSide(color: Colors.red)),
                          focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: const BorderSide(color: Colors.red, width: 2)),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Didn't receive OTP? ", style: kTextNormal0(color: _grey)),
                          _resendCountdown > 0
                              ? Text('Resend in ${_resendCountdown}s',
                                  style: kTextSemiBold0(color: _grey))
                              : GestureDetector(
                                  onTap: _otpSending ? null : () => _sendOtp(resend: true),
                                  child: Text('Resend OTP', style: kTextSemiBold0(color: _blue)),
                                ),
                        ],
                      ),
                      SizedBox(height: 24.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          CustomButton(
                            onPressed: _completing ? null : _completeBooking,
                            title: 'Complete Booking',
                            iconData: Icons.check_circle_rounded,
                            isLoading: _completing,
                            backgroundColor: Colors.green.shade600,
                            iconColor: Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            height: 50.h,
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
