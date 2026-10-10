import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ─────────────────────────────────────────────────────────────────
// Internal base — shared layout for all single-action dialogs.
//
// Anatomy:
//   ┌─────────────────────────────┐
//   │  4px accent bar (top edge)  │  ← accentColor
//   │  ┌──────────────────────┐   │
//   │  │   icon circle        │   │
//   │  │   title              │   │
//   │  │   message            │   │
//   │  │   [primary button]   │   │
//   │  │   [ghost button]     │   │
//   │  └──────────────────────┘   │
//   └─────────────────────────────┘
// ─────────────────────────────────────────────────────────────────
class AppDialog extends StatelessWidget {
  final Color accentColor;
  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;

  /// Primary action button. Required.
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final Color primaryColor;

  /// Optional ghost/text button below the primary.
  final String? ghostLabel;
  final VoidCallback? onGhost;

  const AppDialog({super.key, 
    required this.accentColor,
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.primaryLabel,
    this.onPrimary,
    required this.primaryColor,
    this.ghostLabel,
    this.onGhost,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 24.h),
      elevation: 20,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Gradient Accent bar ─────────────────────────────────────────
          Container(
            height: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withValues(alpha: 0.7)],
              ),
            ),
          ),

          // ── Body ───────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 24.h),
            child: Column(
              children: [
                // Icon
                Container(
                  width: 68.w,
                  height: 68.w,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.15),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: iconColor, size: 32.sp),
                ),
                SizedBox(height: 18.h),

                // Title
                Text(title, style: kTextBold2(), textAlign: TextAlign.center),
                SizedBox(height: 8.h),

                // Message
                Text(
                  message,
                  style: kTextNormal(color: kTextPrimaryColor),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),

                // Primary button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onPrimary ?? () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
                    ),
                    child: Text(primaryLabel, style: kTextSemiBold(color: Colors.white).copyWith(fontSize: 15.sp)),
                  ),
                ),

                // Ghost button (optional)
                if (ghostLabel != null) ...[
                  SizedBox(height: 4.h),
                  TextButton(
                    onPressed: onGhost ?? () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: kTextSecondaryColor,
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      minimumSize: Size(double.infinity, 0),
                    ),
                    child: Text(ghostLabel!, style: kTextMedium(color: kTextSecondaryColor)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SUCCESS DIALOG
// ─────────────────────────────────────────────────────────────────
class SuccessDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onConfirm;

  const SuccessDialog({
    super.key,
    required this.title,
    required this.message,
    this.buttonText,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      accentColor: kSuccessColor,
      iconBg: const Color(0xFFF0FDF4),
      icon: Icons.check_rounded,
      iconColor: kSuccessColor,
      title: title,
      message: message,
      primaryLabel: buttonText ?? 'Done',
      onPrimary: onConfirm,
      primaryColor: kSuccessColor,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// ERROR DIALOG
// ─────────────────────────────────────────────────────────────────
class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? buttonText;
  final String? dismissText;
  final VoidCallback? onConfirm;
  final VoidCallback? onDismiss;

  const ErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.buttonText,
    this.dismissText,
    this.onConfirm,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      accentColor: kErrorColor,
      iconBg: const Color(0xFFFEF2F2),
      icon: Icons.error_outline_rounded,
      iconColor: kErrorColor,
      title: title,
      message: message,
      primaryLabel: buttonText ?? 'Try again',
      onPrimary: onConfirm,
      primaryColor: kErrorColor,
      ghostLabel: dismissText ?? 'Dismiss',
      onGhost: onDismiss,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// WARNING DIALOG
// ─────────────────────────────────────────────────────────────────
class WarningDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? buttonText;
  final String? dismissText;
  final VoidCallback? onConfirm;
  final VoidCallback? onDismiss;

  const WarningDialog({
    super.key,
    required this.title,
    required this.message,
    this.buttonText,
    this.dismissText,
    this.onConfirm,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      accentColor: kWarningColor,
      iconBg: const Color(0xFFFFFBEB),
      icon: Icons.warning_amber_rounded,
      iconColor: kWarningColor,
      title: title,
      message: message,
      primaryLabel: buttonText ?? 'Got it',
      onPrimary: onConfirm,
      primaryColor: kWarningColor,
      ghostLabel: dismissText ?? 'Later',
      onGhost: onDismiss,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// INFO DIALOG
// ─────────────────────────────────────────────────────────────────
class InfoDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onConfirm;

  const InfoDialog({
    super.key,
    required this.title,
    required this.message,
    this.buttonText,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      accentColor: kInfoColor,
      iconBg: const Color(0xFFEFF6FF),
      icon: Icons.info_outline_rounded,
      iconColor: kInfoColor,
      title: title,
      message: message,
      primaryLabel: buttonText ?? 'Got it',
      onPrimary: onConfirm,
      primaryColor: kInfoColor,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// CONFIRMATION DIALOG  (two-button: cancel + confirm)
// ─────────────────────────────────────────────────────────────────
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDangerous;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    this.confirmText,
    this.cancelText,
    this.onCancel,
    this.isDangerous = false,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isDangerous ? kErrorColor : kPrimaryColor;
    final iconBg = isDangerous ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF);
    final iconColor = isDangerous ? kErrorColor : kPrimaryColor;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      clipBehavior: Clip.antiAlias,
      elevation: 20,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      insetPadding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 24.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withValues(alpha: 0.7)],
              ),
            ),
          ),
          Flexible(
          child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 24.h),
            child: Column(
              children: [
                Container(
                  width: 68.w,
                  height: 68.w,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.15),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    isDangerous ? Icons.delete_outline_rounded : Icons.help_outline_rounded,
                    color: iconColor,
                    size: 32.sp,
                  ),
                ),
                SizedBox(height: 18.h),
                Text(title, style: kTextBold2(), textAlign: TextAlign.center),
                SizedBox(height: 8.h),
                Text(
                  message,
                  style: kTextNormal(color: kTextSecondaryColor),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),

                // Two-button row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancel ?? () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kTextSecondaryColor,
                          side: const BorderSide(color: Color(0xFFF3F4F6), width: 1.5),
                          padding: EdgeInsets.symmetric(vertical: 13.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
                        ),
                        child: Text(cancelText ?? 'Cancel', style: kTextSemiBold(color: kTextSecondaryColor)),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onConfirm ?? () => AppNavigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 13.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
                        ),
                        child: Text(confirmText ?? 'Confirm', style: kTextSemiBold(color: Colors.white).copyWith(fontSize: 14.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// LOADING DIALOG
// ─────────────────────────────────────────────────────────────────
class LoadingDialog extends StatelessWidget {
  final String? message;

  const LoadingDialog({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      insetPadding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 24.h),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 32.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40.w,
              height: 40.w,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
              ),
            ),
            if (message != null) ...[
              SizedBox(height: 20.h),
              Text(message!, style: kTextMedium(), textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SOS EMERGENCY DIALOG
// ─────────────────────────────────────────────────────────────────
class SOSDialog extends StatelessWidget {
  final String message;
  final VoidCallback onCallAdmin;
  final VoidCallback? onCancel;

  const SOSDialog({
    super.key,
    required this.message,
    required this.onCallAdmin,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 4, color: kErrorColor),
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 24.h),
            child: Column(
              children: [
                Container(
                  width: 72.w,
                  height: 72.w,
                  decoration: const BoxDecoration(color: Color(0xFFFEF2F2), shape: BoxShape.circle),
                  child: Icon(Icons.emergency_rounded, color: kErrorColor, size: 36.sp),
                ),
                SizedBox(height: 14.h),
                Text(
                  'Emergency SOS',
                  style: kTextBold2(color: kErrorColor),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8.h),
                Text(
                  message,
                  style: kTextNormal(color: kTextSecondaryColor),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onCallAdmin,
                    icon: Icon(Icons.phone_rounded, size: 18.sp),
                    label: Text('Call Admin Now', style: kTextSemiBold1(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kErrorColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 15.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                TextButton(
                  onPressed: onCancel ?? () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: kTextSecondaryColor,
                    minimumSize: Size(double.infinity, 0),
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                  ),
                  child: Text('Cancel', style: kTextMedium(color: kTextSecondaryColor)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// VERIFICATION DIALOG (OTP)
// ─────────────────────────────────────────────────────────────────
class VerificationDialog extends StatefulWidget {
  final String title;
  final String message;
  final Function(String) onVerify;

  const VerificationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onVerify,
  });

  @override
  State<VerificationDialog> createState() => _VerificationDialogState();
}

class _VerificationDialogState extends State<VerificationDialog> {
  final TextEditingController _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 4, color: const Color(0xFF0D9488)),
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 24.h),
            child: Column(
              children: [
                Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: const BoxDecoration(color: Color(0xFFF0FDFA), shape: BoxShape.circle),
                  child: Icon(Icons.verified_user_rounded, color: const Color(0xFF0D9488), size: 30.sp),
                ),
                SizedBox(height: 18.h),
                Text(widget.title, style: kTextBold2(), textAlign: TextAlign.center),
                SizedBox(height: 8.h),
                Text(widget.message, style: kTextNormal(color: kTextSecondaryColor), textAlign: TextAlign.center),
                SizedBox(height: 24.h),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: kTextBold2(),
                  decoration: InputDecoration(
                    hintText: '• • • • • •',
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(color: kBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(color: Color(0xFF0D9488), width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_otpController.text.length == 6) {
                        widget.onVerify(_otpController.text);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    child: Text('Verify', style: kTextSemiBold1(color: Colors.white)),
                  ),
                ),
                SizedBox(height: 4.h),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: kTextSecondaryColor,
                    minimumSize: Size(double.infinity, 0),
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                  ),
                  child: Text('Cancel', style: kTextMedium(color: kTextSecondaryColor)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// LEAVE PAYMENT DIALOG
// ─────────────────────────────────────────────────────────────────

/// Shows the "Leave Payment?" confirmation dialog.
/// Returns `true` if user chose to leave, `false` if they stay.
Future<bool> showLeavePaymentDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => const LeavePaymentDialog(),
  );
  return result == true;
}

class LeavePaymentDialog extends StatelessWidget {
  const LeavePaymentDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 32, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Icon header ──
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 28.h),
              decoration: BoxDecoration(
                color: kErrorColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56.w,
                    height: 56.w,
                    decoration: BoxDecoration(
                      color: kErrorColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.warning_amber_rounded, size: 28.sp, color: kErrorColor),
                  ),
                  SizedBox(height: 14.h),
                  Text('Leave Payment?', style: kTextBold1(), textAlign: TextAlign.center),
                ],
              ),
            ),
            // ── Body ──
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 24.h),
              child: Column(
                children: [
                  Text(
                    "Your booking request has been created. Leaving now will cancel it and you'll need to start over.",
                    style: kTextNormal(color: kTextSecondaryColor).copyWith(height: 1.55),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: kWarningColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: kWarningColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 15.sp, color: kWarningColor),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Payment will not be processed if you leave.',
                            style: kTextNormal0(color: kWarningColor).copyWith(fontSize: 12.sp),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 22.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            side: BorderSide(color: kBorderColor, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                          ),
                          child: Text('Stay', style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 15.sp)),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kErrorColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                          ),
                          child: Text('Leave', style: kTextSemiBold(color: Colors.white).copyWith(fontSize: 15.sp)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// PAYMENT CONFIRMATION DIALOG
// ─────────────────────────────────────────────────────────────────
class PaymentConfirmationDialog extends StatelessWidget {
  final String amount;
  final String serviceName;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  const PaymentConfirmationDialog({
    super.key,
    required this.amount,
    required this.serviceName,
    required this.onConfirm,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 4, color: kSuccessColor),
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 24.h),
            child: Column(
              children: [
                Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: const BoxDecoration(color: Color(0xFFF0FDF4), shape: BoxShape.circle),
                  child: Icon(Icons.payment_rounded, color: kSuccessColor, size: 30.sp),
                ),
                SizedBox(height: 18.h),
                Text('Confirm Payment', style: kTextBold2(), textAlign: TextAlign.center),
                SizedBox(height: 20.h),

                // Summary card
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: kDividerColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Service', style: kTextNormal(color: kTextSecondaryColor)),
                          Flexible(
                            child: Text(
                              serviceName,
                              style: kTextMedium(),
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Divider(color: kDividerColor, height: 1),
                      SizedBox(height: 10.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total', style: kTextSemiBold(color: kTextSecondaryColor)),
                          Text(
                            NumberUtils.formatCurrency(amount),
                            style: kTextBold2(color: kSuccessColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancel ?? () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kTextSecondaryColor,
                          side: BorderSide(color: kBorderColor),
                          padding: EdgeInsets.symmetric(vertical: 13.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                        ),
                        child: Text('Cancel', style: kTextSemiBold(color: kTextSecondaryColor)),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kSuccessColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 13.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                        ),
                        child: Text('Pay Now', style: kTextSemiBold1(color: Colors.white)),
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