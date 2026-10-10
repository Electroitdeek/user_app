import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class RequestConflictDialog {
  static void show(
    BuildContext context, {
    required String message,
    required List<int> invalidIds,
    VoidCallback? onDismissed,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RequestConflictContent(message: message, invalidIds: invalidIds, onDismissed: onDismissed),
    );
  }
}

class _RequestConflictContent extends StatelessWidget {
  final String message;
  final List<int> invalidIds;
  final VoidCallback? onDismissed;

  const _RequestConflictContent({required this.message, required this.invalidIds, this.onDismissed});

  void _dismiss(BuildContext context) {
    Navigator.pop(context);
    onDismissed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, _) => onDismissed?.call(),
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        contentPadding: EdgeInsets.all(24.w),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(color: kWarningColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.warning_amber_rounded, color: kWarningColor, size: 36.sp),
            ),
            SizedBox(height: 16.h),
            Text('Slots Already Taken', style: kTextBold2(), textAlign: TextAlign.center),
            SizedBox(height: 8.h),
            Text(
              message.isNotEmpty ? message : 'Some booking slots were already accepted by another provider.',
              style: kTextNormal(color: const Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            if (invalidIds.isNotEmpty) ...[
              SizedBox(height: 12.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: kWarningColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: kWarningColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  '${invalidIds.length} slot${invalidIds.length > 1 ? 's' : ''} unavailable',
                  style: kTextSemiBold(color: kWarningColor),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
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
