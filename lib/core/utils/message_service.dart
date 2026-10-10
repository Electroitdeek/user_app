import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MessageService {
  // Access the current context via the global navigator key
  static BuildContext? get _context => AppNavigator.navigatorKey.currentContext;

  /// Shows a professional Success SnackBar
  static void showSuccess(String message) {
    if (_context == null) return;
    _showSnackBar(
      message: message,
      backgroundColor: const Color(0xFF4CAF50), // Healthy Green
      icon: Icons.check_circle_rounded,
    );
  }

  /// Shows a professional Error SnackBar
  static void showError(String message) {
    if (_context == null) return;
    _showSnackBar(message: message, backgroundColor: Colors.redAccent, icon: Icons.error_outline_rounded);
  }

  /// Shows an Informational SnackBar
  static void showInfo(String message) {
    if (_context == null) return;
    _showSnackBar(message: message, backgroundColor: kAccentColor, icon: Icons.info_outline_rounded);
  }

  static void showWarning(String message, {BuildContext? context}) {
    if (_context == null) return;
    _showSnackBar(context: context, message: message, backgroundColor: kWarningColor, icon: Icons.warning_amber);
  }

  /// Shows a short, compact toast-style message (e.g. "Copied")
  static void showToast(String message, {IconData? icon}) {
    if (_context == null) return;
    ScaffoldMessenger.of(_context!)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, color: Colors.white, size: 16.sp), SizedBox(width: 6.w)],
              Text(message, style: kTextMedium0(color: Colors.white)),
            ],
          ),
          backgroundColor: kBlackColor.withValues(alpha: 0.8),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.symmetric(horizontal: 100.w, vertical: 16.h),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
          duration: const Duration(seconds: 2),
          elevation: 4,
        ),
      );
  }

  static void _showSnackBar({
    required String message,
    required Color backgroundColor,
    required IconData icon,
    BuildContext? context,
  }) {
    ScaffoldMessenger.of(context ?? _context!).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: kTextNormal(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
