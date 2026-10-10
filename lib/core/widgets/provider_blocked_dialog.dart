import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProviderBlockedDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onOkPressed;

  const ProviderBlockedDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onOkPressed,
  });

  /// Static helper to show the dialog
  static void show(BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onOkPressed,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProviderBlockedDialog(
        title: title,
        message: message,
        onOkPressed: onOkPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70.w,
                height: 70.w,
                decoration: BoxDecoration(
                  color: kErrorColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.block_rounded,
                  color: kErrorColor,
                  size: 36.sp,
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                title,
                textAlign: TextAlign.center,
                style: kTextBold3(color: kTextPrimaryColor),
              ),
              SizedBox(height: 12.h),
              Text(
                message,
                textAlign: TextAlign.center,
                style: kTextNormal(color: kTextSecondaryColor),
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: onOkPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'OK',
                    style: kTextBold2(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
