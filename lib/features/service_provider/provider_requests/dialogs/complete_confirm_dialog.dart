import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/bloc/provider_request_detail_bloc/provider_request_detail_bloc.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/models/provider_service_request_model.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/widgets/complete_booking_sheet.dart';
import 'package:adhisaat_health_care/shared/widgets/buttons/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CompleteConfirmDialog {
  static void show(BuildContext context, ProviderServiceRequestModel r) {
    final phone = r.customerPhone ?? '';
    final bookingId = r.bookingId;

    if (bookingId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Booking ID not available. Please refresh and try again.')));
      return;
    }
    if (phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Patient phone number not available.')));
      return;
    }

    showDialog(
      context: context,
      builder: (dCtx) =>
          _CompleteConfirmContent(request: r, bookingId: bookingId, phone: phone, pageContext: context),
    );
  }
}

class _CompleteConfirmContent extends StatelessWidget {
  static const _blue = Color(0xFF2D62ED);
  static const _greyText = Color(0xFF6B7280);
  static const _greyBorder = Color(0xFFE5E7EB);

  final ProviderServiceRequestModel request;
  final int bookingId;
  final String phone;
  final BuildContext pageContext;

  const _CompleteConfirmContent({
    required this.request,
    required this.bookingId,
    required this.phone,
    required this.pageContext,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      contentPadding: AppPadding.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(color: _blue.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(Icons.check_circle_outline_rounded, color: _blue, size: 32.sp),
          ),
          SizedBox(height: 16.h),
          Text('Complete Booking?', style: kTextBold2(), textAlign: TextAlign.center),
          SizedBox(height: 8.h),
          Text(
            'An OTP will be sent to the patient\'s registered mobile for verification.',
            style: kTextNormal(color: _greyText),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  onPressed: () => Navigator.pop(context),
                  title: 'Cancel',
                  backgroundColor: Colors.white,
                  textColor: _greyText,
                  borderSide: BorderSide(color: _greyBorder),
                  borderRadius: BorderRadius.circular(10.r),
                  height: 44.h,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: CustomButton(
                  onPressed: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      useSafeArea: true,
                      context: pageContext,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => CompleteBookingSheet(
                        request: request,
                        bookingId: bookingId,
                        mobileNumber: phone,
                        onSuccess: () =>
                            pageContext.read<ProviderRequestDetailBloc>().add(RefreshProviderRequestDetail()),
                      ),
                    );
                  },
                  title: 'Continue',
                  backgroundColor: _blue,
                  iconColor: Colors.white,
                  borderRadius: BorderRadius.circular(10.r),
                  height: 44.h,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
