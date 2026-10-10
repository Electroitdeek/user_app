import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/shared/widgets/buttons/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LoginRequiredDialog extends StatelessWidget {
  const LoginRequiredDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(context: context, builder: (context) => const LoginRequiredDialog());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      backgroundColor: kWhiteColor,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.lock_outline_rounded, color: kPrimaryColor, size: 40.sp),
            ),
            SizedBox(height: 24.h),
            Text("Login Required", style: kTextBold3(color: kTextPrimaryColor)),
            SizedBox(height: 12.h),
            Text(
              "Sign in to access your bookings, manage payments, and book specialized healthcare services.",
              style: kTextMedium(color: kTextSecondaryColor),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            CustomButton(
              title: "Login / Signup",
              width: double.infinity,
              onPressed: () => AppNavigator.to(AppRoutes.login),
            ),
            SizedBox(height: 12.h),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Later", style: kTextSemiBold(color: kGreyColor6)),
            ),
          ],
        ),
      ),
    );
  }
}
