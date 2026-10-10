import 'dart:async';

import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:adhisaat_health_care/core/services/launch_url_service.dart';
import 'package:adhisaat_health_care/core/services/location_service.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/core/utils/message_service.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/models/provider_service_request_model.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/models/sub_block_model.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/repositories/provider_request_repository.dart';
import 'package:adhisaat_health_care/shared/widgets/buttons/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class StartBookingSheet extends StatefulWidget {
  final ProviderServiceRequestModel request;
  final SubBlock block;
  final String mobileNumber;
  final VoidCallback onSuccess;

  const StartBookingSheet({
    super.key,
    required this.request,
    required this.block,
    required this.mobileNumber,
    required this.onSuccess,
  });

  // static Future<void> show({
  //   required BuildContext context,
  //   required ProviderServiceRequestModel request,
  //   required SubBlock block,
  //   required String mobileNumber,
  //   required VoidCallback onSuccess,
  // }) {
  //   return showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     useSafeArea: true,
  //     backgroundColor: Colors.transparent,
  //     builder: (_) => StartBookingSheet(
  //       request: request,
  //       block: block,
  //       mobileNumber: mobileNumber,
  //       onSuccess: onSuccess,
  //     ),
  //   );
  // }

  @override
  State<StartBookingSheet> createState() => _StartBookingSheetState();
}

class _StartBookingSheetState extends State<StartBookingSheet> with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF16A34A);
  static const _grey = Color(0xFF6B7280);
  static const _greyBorder = Color(0xFFE5E7EB);

  final _otpController = TextEditingController();
  final _repo = locator<ProviderRequestRepository>();

  bool _otpSending = true;
  bool _otpSent = false;
  bool _starting = false;
  String? _otpError;
  String? _startError;
  int _resendCountdown = 30;
  Timer? _resendTimer;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -5.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
    _sendOtp();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _resendTimer?.cancel();
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp({bool resend = false}) async {
    setState(() {
      _otpSending = true;
      _otpError = null;
    });
    try {
      await _repo.sendStartOtp(
        serviceRequestId: widget.request.id,
        subBlockId: widget.block.id,
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
      if (resend) MessageService.showSuccess('OTP resent successfully');
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

  Future<void> _shake() async {
    HapticFeedback.heavyImpact();
    await _shakeCtrl.forward(from: 0);
    _shakeCtrl.reset();
  }

  Future<void> _startBooking() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4) {
      setState(() => _startError = 'Please enter a valid OTP');
      _shake();
      return;
    }
    setState(() {
      _starting = true;
      _startError = null;
    });
    try {
      final position = await LocationService().getLocationPosition();
      if (position == null) {
        if (!mounted) return;
        setState(() {
          _starting = false;
          _startError = 'Location permission is required to start the session.';
        });
        return;
      }
      await _repo.startServiceRequest(
        requestId: widget.request.id,
        subBlockId: widget.block.id,
        otp: otp,
        checkinLatitude: position.latitude,
        checkinLongitude: position.longitude,
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
      MessageService.showSuccess('Session started successfully!');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _startError = e.toString().replaceFirst('Exception: ', '');
      });
      _shake();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 12.h, bottom: 4.h),
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(color: _greyBorder, borderRadius: BorderRadius.circular(2.r)),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      SizedBox(height: 16.h),
                      _buildSessionCard(),
                      SizedBox(height: 12.h),
                      _buildPatientCard(),
                      SizedBox(height: 16.h),
                      _buildOtpSection(),
                      SizedBox(height: 20.h),
                      _buildActions(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: AppPadding.all(8),
          decoration: BoxDecoration(
            color: _green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(Icons.play_circle_outline_rounded, color: _green, size: 22.sp),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Start Session', style: kTextBold2()),
              Text('OTP verification required', style: kTextNormal0(color: _grey)),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close_rounded, size: 22.sp, color: _grey),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildSessionCard() {
    return Container(
      padding: AppPadding.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.request.serviceCategoryName, style: kTextBold1(color: const Color(0xFF166534))),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children: [
              _chip(Icons.calendar_today_rounded, AppDateFormatter.dayMonthShort(widget.block.scheduledDate)),
              _chip(Icons.schedule_rounded, widget.block.timeRange),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, size: 14.sp, color: const Color(0xFF16A34A)),
              SizedBox(width: 6.w),
              Text(
                'Session Earnings  ',
                style: kTextNormal0(color: const Color(0xFF16A34A)).copyWith(fontSize: 12.sp),
              ),
              Text(
                NumberUtils.formatCurrency(widget.block.providerPayout),
                style: kTextBold1(color: const Color(0xFF15803D)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.sp, color: _green),
          SizedBox(width: 4.w),
          Text(
            label,
            style: kTextMedium(color: const Color(0xFF166534)).copyWith(fontSize: 11.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard() {
    final fm = widget.request.familyMember;
    final patientName = fm?.fullName ?? widget.request.customerName;
    final relationship = fm?.relationship;

    return Container(
      padding: AppPadding.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: const BoxDecoration(color: Color(0xFF1D4ED8), shape: BoxShape.circle),
            child: Icon(Icons.person_rounded, size: 16.sp, color: Colors.white),
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
                    '${widget.request.customerName} · $relationship',
                    style: kTextNormal0(color: const Color(0xFF1D4ED8)).copyWith(fontSize: 11.sp),
                  ),
                ],
                // SizedBox(height: 4.h),
                // Row(
                //   children: [
                //     Icon(Icons.phone_rounded, size: 12.sp, color: _grey),
                //     SizedBox(width: 4.w),
                //     Text(widget.mobileNumber,
                //         style: kTextNormal0(color: _grey).copyWith(fontSize: 12.sp)),
                //   ],
                // ),
              ],
            ),
          ),
          GestureDetector(
            // onTap: () => LaunchUrlService.makePhoneCall(widget.mobileNumber),
            onTap: () => LaunchUrlService.makePhoneCall(AppConstants.partnerCustomerPhone),
            child: Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: _green.withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.call_rounded, size: 18.sp, color: _green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_otpSending) ...[
          Container(
            padding: AppPadding.all(14),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: _green.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 18.sp,
                  height: 18.sp,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _green),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Sending OTP to ${NumberUtils.maskPhone(widget.mobileNumber)}…',
                    style: kTextNormal(color: _green),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_otpError != null && !_otpSending) ...[
          Container(
            padding: AppPadding.all(12),
            decoration: BoxDecoration(
              color: kErrorColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: kErrorColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: kErrorColor, size: 18.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(_otpError!, style: kTextNormal(color: kErrorColor)),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          CustomButton(
            onPressed: () => _sendOtp(),
            title: 'Retry Send OTP',
            iconData: Icons.refresh_rounded,
            backgroundColor: Colors.white,
            textColor: _green,
            borderSide: BorderSide(color: _green),
            borderRadius: BorderRadius.circular(10.r),
            height: 44.h,
          ),
        ],
        if (_otpSent) ...[
          Container(
            padding: AppPadding.symmetric(h: 14, v: 10),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: _green.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.mark_email_read_outlined, color: _green, size: 18.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'OTP sent to ${NumberUtils.maskPhone(widget.mobileNumber)}',
                    style: kTextNormal(color: _green),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Text('Enter verification OTP from patient', style: kTextSemiBold1()),
          SizedBox(height: 4.h),
          Text(
            'Ask the patient for the OTP sent to their mobile',
            style: kTextNormal0(color: _grey).copyWith(fontSize: 12.sp),
          ),
          SizedBox(height: 10.h),
          AnimatedBuilder(
            animation: _shakeAnim,
            builder: (_, child) => Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child),
            child: TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: kTextBold2().copyWith(fontSize: 22.sp, letterSpacing: 8),
              textAlign: TextAlign.center,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) {
                if (_startError != null) setState(() => _startError = null);
                if (value.length == 6 && !_starting) {
                  FocusScope.of(context).unfocus();
                  _startBooking();
                }
              },
              decoration: InputDecoration(
                counterText: '',
                hintText: '• • • • • •',
                hintStyle: kTextBold1(color: const Color(0xFFD1D5DB)).copyWith(letterSpacing: 8),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: AppPadding.symmetric(h: 16, v: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: _green, width: 2),
                ),
                errorText: _startError,
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
              ),
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  "Didn't receive OTP? ",
                  style: kTextNormal0(color: _grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _resendCountdown > 0
                  ? Flexible(
                      child: Text(
                        'Resend in ${_resendCountdown}s',
                        style: kTextSemiBold0(color: _grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : GestureDetector(
                      onTap: _otpSending ? null : () => _sendOtp(resend: true),
                      child: Text('Resend OTP', style: kTextSemiBold0(color: _green)),
                    ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        if (_otpSent)
          CustomButton(
            onPressed: _starting ? null : _startBooking,
            title: 'Verify & Start Session',
            iconData: Icons.play_circle_rounded,
            isLoading: _starting,
            backgroundColor: _green,
            iconColor: Colors.white,
            textStyle: kTextSemiBold1(color: Colors.white),
            borderRadius: BorderRadius.circular(14.r),
            height: 54.h,
            width: double.infinity,
          ),
        SizedBox(height: 10.h),
        CustomButton(
          onPressed: () => Navigator.pop(context),
          title: 'Cancel',
          backgroundColor: Colors.white,
          textColor: _grey,
          borderSide: BorderSide(color: _greyBorder),
          borderRadius: BorderRadius.circular(14.r),
          height: 44.h,
          width: double.infinity,
        ),
      ],
    );
  }
}
