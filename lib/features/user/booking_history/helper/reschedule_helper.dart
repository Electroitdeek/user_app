import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/user/service_booking/data/service_category_repository.dart';
import 'package:adhisaat_health_care/features/user/service_booking/model/booking_model.dart';
import 'package:adhisaat_health_care/features/user/service_booking/model/service_category_model.dart';
import 'package:adhisaat_health_care/features/user/service_booking/view/service_booking_flow.dart';
import 'package:adhisaat_health_care/shared/widgets/buttons/custom_button.dart';
import 'package:adhisaat_health_care/shared/widgets/progress_bar/transparent_loader.dart';

/// Everything needed to reschedule a booking and raise a support ticket for it.
/// Built from either the booking-detail model or the booking-list model.
class RescheduleInfo {
  final int serviceRequestId;
  final String requestNumber;
  final String serviceName;

  /// Parent category id — the query param for /get-sub-categories.
  final int? serviceCategoryId;

  /// The booked service id — matched against the rate-carded entry.
  final int? serviceSubCategoryId;

  /// 'procedural' | 'long_duration'
  final String bookingType;
  final bool isEmergency;

  final String startDateText;
  final String startTimeText;

  const RescheduleInfo({
    required this.serviceRequestId,
    required this.requestNumber,
    required this.serviceName,
    required this.serviceCategoryId,
    required this.serviceSubCategoryId,
    required this.bookingType,
    required this.isEmergency,
    required this.startDateText,
    required this.startTimeText,
  });
}

/// Shows the "booking time has passed" dialog with Reschedule + Contact Support.
void showPastBookingDialog(BuildContext context, RescheduleInfo info) {
  showDialog(context: context, builder: (_) => _PastBookingDialog(info: info));
}

/// Re-opens the booking flow at Step 2 (date & duration) for the same service.
/// The rate card is refetched via /get-sub-categories?service_category_id=X&with_ratecard=1
/// (only the service id is known at this point). Falls back to Step 1 when the
/// rate card can't be resolved.
Future<void> rescheduleBooking(RescheduleInfo info) async {
  final ctx = AppNavigator.context;
  final categoryId = info.serviceCategoryId;
  final subCategoryId = info.serviceSubCategoryId;
  if (categoryId == null || subCategoryId == null) {
    AppNavigator.to(AppRoutes.serviceBookingFlow);
    return;
  }

  var loaderShown = false;
  if (ctx != null) {
    loaderShown = true;
    showDialog(context: ctx, barrierDismissible: false, builder: (_) => const TransparentLoader());
  }

  ServiceItemModel? service;
  try {
    service = await locator<ServiceCategoryRepository>().getServiceWithRateCards(
      serviceCategoryId: categoryId,
      serviceSubCategoryId: subCategoryId,
    );
  } catch (_) {
    service = null;
  }

  // Dismiss the loader via the navigator state (no BuildContext across the gap).
  if (loaderShown) {
    AppNavigator.navigatorKey.currentState?.pop();
  }

  // No usable rate card → fall back to picking the service from Step 1.
  if (service == null || service.rateCards.isEmpty) {
    AppNavigator.to(AppRoutes.serviceBookingFlow);
    return;
  }

  final rateCard = service.rateCards.firstWhere(
    (rc) => rc.bookingType == info.bookingType,
    orElse: () => service!.rateCards.first,
  );
  final mode = rateCard.bookingType == 'long_duration' ? 'daily' : 'hourly';

  final serviceType = ServiceType(
    id: service.id.toString(),
    name: service.name,
    description: service.description ?? service.name,
    icon: Icons.health_and_safety_rounded,
    color: kPrimaryColor,
    priceFrom: NumberUtils.formatCurrency(rateCard.basePrice, decimalDigits: 0),
    rateCard: rateCard,
    iconUrl: service.iconImageUrl,
    gstPercentage: service.gstPercentage,
  );

  final request = BookingRequest()
    ..serviceType = serviceType
    ..bookingType = rateCard.bookingType
    ..mode = mode
    ..gstPercentage = service.gstPercentage;

  AppNavigator.to(
    AppRoutes.serviceBookingFlow,
    arguments: {
      'initialRequest': request,
      'initialRoute': BookingRoutes.dateDuration,
      'isEmergency': info.isEmergency,
    },
  );
}

class _PastBookingDialog extends StatelessWidget {
  final RescheduleInfo info;

  const _PastBookingDialog({required this.info});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Container(
        padding: EdgeInsets.all(28.r),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(28.r),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 24, offset: const Offset(0, 12)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.event_busy_rounded, color: kErrorColor, size: 32.sp),
            ),
            SizedBox(height: 24.h),
            Text(
              'Booking Time Has Passed',
              style: kTextBold1(color: kTextPrimaryColor).copyWith(fontSize: 18.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              'This booking was scheduled for ${info.startDateText}, ${info.startTimeText}, which is already past. '
              'We can\'t accept payment for a past booking. Please reschedule, or contact support if you need help.',
              style: kTextNormal(color: kTextSecondaryColor).copyWith(height: 1.4, fontSize: 14.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            CustomButton(
              onPressed: () {
                Navigator.pop(context);
                rescheduleBooking(info);
              },
              title: 'Reschedule',
              backgroundColor: kPrimaryColor,
              borderRadius: BorderRadius.circular(16.r),
              height: 50.h,
              width: double.infinity,
            ),
            SizedBox(height: 12.h),
            CustomButton(
              onPressed: () {
                Navigator.pop(context);
                AppNavigator.to(
                  AppRoutes.createSupportTicket,
                  arguments: {
                    'requestId': info.serviceRequestId.toString(),
                    'requestNumber': info.requestNumber,
                    'serviceName': info.serviceName,
                    'subject': info.requestNumber,
                  },
                );
              },
              title: 'Contact Support',
              backgroundColor: Colors.transparent,
              textColor: kPrimaryColor,
              borderSide: BorderSide(color: kPrimaryColor.withValues(alpha: 0.5), width: 1.5),
              borderRadius: BorderRadius.circular(16.r),
              height: 50.h,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}
