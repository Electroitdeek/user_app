import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';

/// App Store compliant location permission dialog.
///
/// This dialog handles the permission logic internally:
/// 1. If not permanently denied: "Continue" triggers the OS permission prompt.
/// 2. If the user denies permanently: The dialog updates to show "Open Settings".
/// 3. If the user grants: The dialog closes with `true`.
class LocationPermissionDialog extends StatefulWidget {
  final bool initialPermanentlyDenied;

  const LocationPermissionDialog({
    super.key,
    this.initialPermanentlyDenied = false,
  });

  @override
  State<LocationPermissionDialog> createState() =>
      _LocationPermissionDialogState();

  /// Show the dialog and handle the permission flow internally.
  /// Returns `true` if permission was granted, or if user was sent to settings.
  /// Returns `false` if user tapped "Not Now".
  static Future<bool?> show(
    BuildContext context, {
    bool isPermanentlyDenied = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LocationPermissionDialog(
        initialPermanentlyDenied: isPermanentlyDenied,
      ),
    );
  }
}

class _LocationPermissionDialogState extends State<LocationPermissionDialog> {
  late bool _isPermanentlyDenied;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _isPermanentlyDenied = widget.initialPermanentlyDenied;
    _checkInitialPermission();
  }

  Future<void> _checkInitialPermission() async {
    final isPermanent = await Permission.location.isPermanentlyDenied;
    if (isPermanent && mounted) {
      setState(() {
        _isPermanentlyDenied = true;
      });
    }
  }

  Future<void> _handlePrimaryAction() async {
    if (_isRequesting) return;

    setState(() {
      _isRequesting = true;
    });

    try {
      if (_isPermanentlyDenied) {
        // Direct redirect to settings
        await openAppSettings();
        if (mounted) Navigator.pop(context, true);
        return;
      }

      // Request actual OS permission
      final status = await Permission.location.request();

      if (status.isGranted || status.isLimited) {
        if (mounted) Navigator.pop(context, true);
      } else if (status.isPermanentlyDenied) {
        // Update UI to show Settings button
        setState(() {
          _isPermanentlyDenied = true;
        });
        // Direct redirect to settings
        await openAppSettings();
        if (mounted) Navigator.pop(context, true);
      } else {
        // Still denied, check if it was actually permanently denied
        final isPermanent = await Permission.location.isPermanentlyDenied;
        if (isPermanent) {
          setState(() {
            _isPermanentlyDenied = true;
          });
          await openAppSettings();
          if (mounted) Navigator.pop(context, true);
        } else {
          // Still denied, but not permanently.
          // Usually the OS prompt doesn't show again if it was just denied,
          // but we let the user stay here and try again or choose "Not Now".
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isProvider = AppConstants.isProviderApp;
    final Color brandColor = isProvider ? Colors.blue.shade700 : kPrimaryColor;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      backgroundColor: Colors.white,
      elevation: 8,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon ──────────────────────────────────────────────────
              Container(
                width: 72.w,
                height: 72.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isPermanentlyDenied
                      ? const Color(0xFFFFF3E0) // warm amber for settings
                      : brandColor.withValues(alpha: 0.1),
                ),
                child: Icon(
                  _isPermanentlyDenied
                      ? Icons.settings_suggest_rounded
                      : Icons.location_on_rounded,
                  size: 36.sp,
                  color: _isPermanentlyDenied
                      ? const Color(0xFFF57C00)
                      : brandColor,
                ),
              ),

              SizedBox(height: 24.h),

              // ── Title ─────────────────────────────────────────────────
              Text(
                _isPermanentlyDenied
                    ? 'Location Access Required'
                    : (isProvider
                          ? 'Maximize Your Earnings'
                          : 'Location Permission'),
                style: kTextBold2(
                  color: Colors.grey.shade900,
                ).copyWith(fontSize: 20.sp),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 12.h),

              // ── Description ───────────────────────────────────────────
              Text(
                _isPermanentlyDenied
                    ? (isProvider
                          ? 'Location access is blocked. To start receiving nearby requests and go online, please enable it in Settings.'
                          : 'Location access is blocked. To find nearby healthcare partners, please enable it in Settings.')
                    : (isProvider
                          ? 'By enabling location, you can receive booking requests closest to you and provide faster service to patients.'
                          : 'We use your location to find nearby healthcare partners and calculate accurate service costs.'),
                style: kTextNormal(
                  color: Colors.grey.shade600,
                ).copyWith(height: 1.55, fontSize: 14.sp),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 20.h),

              // ── Privacy/Info box ──────────────────────────────────────
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F8FF),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      color: brandColor.withValues(alpha: 0.6),
                      size: 18.sp,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        isProvider
                            ? 'Your location is only tracked while you are online and working.'
                            : 'Your privacy is important. Location is only used for service matching.',
                        style: kTextNormal0(
                          color: Colors.grey.shade700,
                        ).copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 28.h),

              // ── Primary button ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton.icon(
                  onPressed: _isRequesting ? null : _handlePrimaryAction,
                  icon: Icon(
                    _isPermanentlyDenied
                        ? Icons.settings_rounded
                        : Icons.check_circle_rounded,
                    size: 20.sp,
                  ),
                  label: Text(
                    _isPermanentlyDenied
                        ? 'Open Settings'
                        : (isProvider ? 'Allow & Start' : 'Continue'),
                    style: kTextSemiBold(
                      color: Colors.white,
                    ).copyWith(fontSize: 15.sp),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPermanentlyDenied
                        ? const Color(0xFFF57C00)
                        : brandColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              SizedBox(height: 12.h),

              // ── Secondary button ──────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 44.h,
                child: TextButton(
                  onPressed: _isRequesting ? null : () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    isProvider ? 'Decide Later' : 'Not Now',
                    style: kTextSemiBold(
                      color: Colors.grey.shade500,
                    ).copyWith(fontSize: 15.sp),
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
