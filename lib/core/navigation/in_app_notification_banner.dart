import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_navigator.dart';       // for navigatorKey → Overlay

// ─────────────────────────────────────────────────────────────────
// Notification type — drives icon + accent colour
// ─────────────────────────────────────────────────────────────────
enum InAppNotifType { booking, success, warning, info, error }

// ─────────────────────────────────────────────────────────────────
// InAppNotificationBanner
//
// Usage (from anywhere, no BuildContext needed):
//
//   InAppNotificationBanner.show(
//     title: 'Request Accepted ✅',
//     body:  'A provider has accepted your service request.',
//     type:  InAppNotifType.booking,
//     onTap: () => _navigateToDetailSafely(AppRoutes.serviceRequestDetail, reqId),
//   );
//
// ─────────────────────────────────────────────────────────────────
class InAppNotificationBanner {
  InAppNotificationBanner._();

  static OverlayEntry? _current;
  static Timer? _dismissTimer;

  // How long the banner stays visible before auto-dismissing
  static const _autoDismissDuration = Duration(seconds: 5);

  /// Show a new banner. If one is already visible it is dismissed first.
  static void show({
    required String title,
    required String body,
    InAppNotifType type = InAppNotifType.info,
    VoidCallback? onTap,
  }) {
    // Dismiss any existing banner immediately (no fade-out wait)
    _dismissNow();

    final overlay = AppNavigator.navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _BannerWidget(
        title:   title,
        body:    body,
        type:    type,
        onTap:   onTap,
        onDismiss: () => _dismissNow(),
      ),
    );

    _current = entry;
    overlay.insert(entry);

    // Auto-dismiss after [_autoDismissDuration]
    _dismissTimer = Timer(_autoDismissDuration, _dismissNow);
  }

  static void _dismissNow() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _current?.remove();
    _current = null;
  }
}

// ─────────────────────────────────────────────────────────────────
// Internal animated widget
// ─────────────────────────────────────────────────────────────────
class _BannerWidget extends StatefulWidget {
  final String title;
  final String body;
  final InAppNotifType type;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  const _BannerWidget({
    required this.title,
    required this.body,
    required this.type,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _animatedDismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  // ── Colour tokens per type ─────────────────────────────────────
  Color get _accentColor {
    switch (widget.type) {
      case InAppNotifType.booking:  return kPrimaryColor;
      case InAppNotifType.success:  return kSuccessColor;
      case InAppNotifType.warning:  return kWarningColor;
      case InAppNotifType.error:    return kErrorColor;
      case InAppNotifType.info:     return kInfoColor;
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case InAppNotifType.booking:  return Icons.medical_services_rounded;
      case InAppNotifType.success:  return Icons.check_circle_rounded;
      case InAppNotifType.warning:  return Icons.warning_amber_rounded;
      case InAppNotifType.error:    return Icons.error_outline_rounded;
      case InAppNotifType.info:     return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _slideAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SafeArea(
              bottom: false,
              child: GestureDetector(
                // Tap the banner → navigate + dismiss
                onTap: widget.onTap != null
                    ? () {
                  _animatedDismiss();
                  widget.onTap!();
                }
                    : null,
                // Swipe up → dismiss
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null &&
                      details.primaryVelocity! < -200) {
                    _animatedDismiss();
                  }
                },
                child: Container(
                  margin: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 0),
                  decoration: BoxDecoration(
                    color: kWhiteColor.withValues(alpha: 0.98),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: _accentColor.withValues(alpha: 0.15),
                      width: 1.w,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.r),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          // Content
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(10.w, 8.h, 6.w, 8.h),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icon
                                  Container(
                                    width: 30.w,
                                    height: 30.w,
                                    decoration: BoxDecoration(
                                      color: _accentColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                    child: Icon(
                                      _icon,
                                      color: _accentColor,
                                      size: 16.sp,
                                    ),
                                  ),
                                  SizedBox(width: 10.w),

                                  // Title + body
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          widget.title,
                                          style: kTextBold0(color: kTextPrimaryColor),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 2.h),
                                        Text(
                                          widget.body,
                                          style: kTextNormal0(color: kTextSecondaryColor),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        // "View" label when there's an action
                                        if (widget.onTap != null) ...[
                                          SizedBox(height: 4.h),
                                          Text(
                                            'Tap to view details →',
                                            style: kTextBold0(color: _accentColor).copyWith(fontSize: 10.sp),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Dismiss ×
                                  GestureDetector(
                                    onTap: _animatedDismiss,
                                    behavior: HitTestBehavior.opaque,
                                    child: Padding(
                                      padding: EdgeInsets.all(4.w),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 16.sp,
                                        color: kTextHintColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}