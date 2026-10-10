import 'package:adhisaat_health_care/core/constants/app_strings.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/theme/screen_dimensions.dart';
import 'package:adhisaat_health_care/shared/widgets/buttons/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryButtonText;
  final IconData icon;
  final Color? iconColor;

  const CustomErrorView({
    super.key,
    this.title = 'Oops!',
    this.message = AppStrings.somethingWentWrong,
    this.onRetry,
    this.retryButtonText = AppStrings.retry,
    this.icon = Icons.error_outline_rounded,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: (iconColor ?? kErrorColor).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 52.sp,
                color: iconColor ?? kErrorColor,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              title,
              style: kTextBold1(color: kTextPrimaryColor),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              style: kTextNormal(color: kTextSecondaryColor),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              SizedBox(height: 32.h),
              CustomButton(
                onPressed: onRetry,
                title: retryButtonText,
                iconData: Icons.refresh_rounded,
                backgroundColor: kPrimaryColor,
                borderRadius: AppRadius.l,
                height: AppButtonHeight.m,
                width: double.infinity,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

