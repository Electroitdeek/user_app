import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';

class RequestUnavailableDialog {
  static void show(BuildContext context, {VoidCallback? onDismissed}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RequestUnavailableContent(pageContext: context, onDismissed: onDismissed),
    );
  }
}

class _RequestUnavailableContent extends StatelessWidget {
  final BuildContext pageContext;
  final VoidCallback? onDismissed;

  const _RequestUnavailableContent({required this.pageContext, this.onDismissed});

  void _dismiss(BuildContext context) {
    Navigator.pop(context);
    Navigator.of(pageContext).popUntil(
      (route) => route.settings.name == AppRoutes.providerRequestList || route.isFirst,
    );
    onDismissed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, _) {
        Navigator.of(pageContext).popUntil(
          (route) => route.settings.name == AppRoutes.providerRequestList || route.isFirst,
        );
        onDismissed?.call();
      },
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        contentPadding: EdgeInsets.all(24.w),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.block_rounded, color: kErrorColor, size: 36.sp),
            ),
            SizedBox(height: 16.h),
            Text('Request Unavailable', style: kTextBold2(), textAlign: TextAlign.center),
            SizedBox(height: 8.h),
            Text(
              'Request already accepted by another partner or no longer available.',
              style: kTextNormal(color: const Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _dismiss(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                  elevation: 0,
                ),
                child: Text('OK', style: kTextBold1(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
