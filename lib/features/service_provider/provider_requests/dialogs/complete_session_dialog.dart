import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:adhisaat_health_care/core/services/location_service.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/core/utils/message_service.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/models/provider_service_request_model.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/models/sub_block_model.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/repositories/provider_request_repository.dart';

class CompleteSessionDialog extends StatefulWidget {
  final ProviderServiceRequestModel request;
  final SubBlock block;
  final VoidCallback onSuccess;

  const CompleteSessionDialog({
    super.key,
    required this.request,
    required this.block,
    required this.onSuccess,
  });

  static void show(
    BuildContext context, {
    required ProviderServiceRequestModel request,
    required SubBlock block,
    required VoidCallback onSuccess,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CompleteSessionDialog(request: request, block: block, onSuccess: onSuccess),
    );
  }

  @override
  State<CompleteSessionDialog> createState() => _CompleteSessionDialogState();
}

class _CompleteSessionDialogState extends State<CompleteSessionDialog> {
  bool _completing = false;
  String? _error;

  Future<void> _complete() async {
    setState(() {
      _completing = true;
      _error = null;
    });
    try {
      final position = await LocationService().getLocationPosition();
      if (!mounted) return;
      await locator<ProviderRequestRepository>().completeSession(
        serviceRequestId: widget.request.id,
        subBlockId: widget.block.id,
        checkoutLatitude: position?.latitude,
        checkoutLongitude: position?.longitude,
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
      MessageService.showSuccess('Session completed successfully!');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _completing = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  static const _grey = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header band with layered success icon ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 24.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kSuccessColor.withValues(alpha: 0.12), kSuccessColor.withValues(alpha: 0.02)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 72.w,
                  height: 72.w,
                  decoration: BoxDecoration(color: kSuccessColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Center(
                    child: Container(
                      width: 52.w,
                      height: 52.w,
                      decoration: BoxDecoration(color: kSuccessColor, shape: BoxShape.circle, boxShadow: [
                        BoxShadow(color: kSuccessColor.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4)),
                      ]),
                      child: Icon(Icons.check_rounded, color: Colors.white, size: 30.sp),
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                Text('Complete Session?', style: kTextBold2(), textAlign: TextAlign.center),
              ],
            ),
          ),

          // ── Body ──
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'This will mark the session as completed and record your check-out location.',
                  style: kTextNormal(color: _grey).copyWith(height: 1.45),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),

                // Session info chip
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FC),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.event_available_rounded, size: 16.sp, color: kSuccessColor),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              AppDateFormatter.dayMonthShort(widget.block.scheduledDate),
                              style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 13.sp),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 14.sp, color: _grey),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              widget.block.timeRange,
                              style: kTextNormal0(color: _grey).copyWith(fontSize: 12.sp),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (_error != null) ...[
                  SizedBox(height: 12.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: kErrorColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: kErrorColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, size: 16.sp, color: kErrorColor),
                        SizedBox(width: 8.w),
                        Expanded(child: Text(_error!, style: kTextNormal0(color: kErrorColor))),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 22.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _completing ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                        ),
                        child: Text('Cancel', style: kTextSemiBold(color: _grey)),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _completing ? null : _complete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kSuccessColor,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                          elevation: 0,
                        ),
                        child: _completing
                            ? SizedBox(
                                width: 18.sp,
                                height: 18.sp,
                                child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_rounded, size: 18.sp, color: Colors.white),
                                  SizedBox(width: 6.w),
                                  Text('Complete', style: kTextSemiBold(color: Colors.white)),
                                ],
                              ),
                      ),
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
}
