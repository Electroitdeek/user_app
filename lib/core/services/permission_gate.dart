import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:adhisaat_health_care/core/services/notification_service.dart';
import 'package:adhisaat_health_care/core/storage/local_storage_service.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/widgets/location_permission_dialog.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/user/address/bloc/selected_address_provider.dart';
import 'package:adhisaat_health_care/features/user/home/view/search_address_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PERMISSION GATE — Dispatcher
// Shows either the Provider or Customer version of the gate.
// ─────────────────────────────────────────────────────────────────────────────

class PermissionGate extends StatelessWidget {
  final Widget child;

  const PermissionGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (AppConstants.isProviderApp) {
      return ProviderPermissionGate(child: child);
    } else {
      return CustomerPermissionGate(child: child);
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 1. PROVIDER PERMISSION GATE
// ════════════════════════════════════════════════════════════════════════════

class ProviderPermissionGate extends ConsumerStatefulWidget {
  final Widget child;

  const ProviderPermissionGate({super.key, required this.child});

  @override
  ConsumerState<ProviderPermissionGate> createState() =>
      _ProviderPermissionGateState();
}

class _ProviderPermissionGateState extends ConsumerState<ProviderPermissionGate>
    with WidgetsBindingObserver {
  _GateStep _step = _GateStep.loading;
  bool _waitingForSettings = false;
  final Color _brandColor = Colors.blue.shade700;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _determineStep();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForSettings) {
      _waitingForSettings = false;
      _determineStep();
    }
  }

  Future<void> _determineStep() async {
    if (!mounted) return;
    setState(() => _step = _GateStep.loading);

    final locPerm = await Permission.location.status;
    if (!mounted) return;
    final hasLoc = locPerm.isGranted || locPerm.isLimited;

    final notifPerm = await Permission.notification.status;
    if (!mounted) return;
    final hasNotif = notifPerm.isGranted;

    if (!hasLoc && !hasNotif) {
      setState(() => _step = _GateStep.combined);
      return;
    }

    if (!hasLoc) {
      setState(() => _step = _GateStep.location);
      return;
    }

    if (!hasNotif) {
      setState(() => _step = _GateStep.notification);
      return;
    }

    setState(() => _step = _GateStep.done);
  }

  // ── Handlers ──
  Future<void> _onLocationContinue() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enable GPS to start receiving requests.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => Geolocator.openLocationSettings(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final status = await Permission.location.request();
    if (!mounted) return;
    if (!status.isGranted && !status.isLimited) {
      // Permanently denied — only option is to open settings, no skip
      if (status.isPermanentlyDenied) {
        _waitingForSettings = true;
        await openAppSettings();
      }
      // If just denied (not permanent), the location page stays visible — no bypass
      return;
    }
    _moveToNotificationStep();
  }

  void _moveToNotificationStep() async {
    final notifPerm = await Permission.notification.status;
    if (!mounted) return;
    setState(
      () =>
          _step = notifPerm.isGranted ? _GateStep.done : _GateStep.notification,
    );
  }

  Future<void> _onNotificationContinue() async {
    await locator<NotificationService>().requestNotificationPermission();
    if (!mounted) return;
    final status = await Permission.notification.status;
    if (!mounted) return;
    if (status.isGranted) {
      setState(() => _step = _GateStep.done);
    } else {
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _NotificationDeniedDialog(
          isPermanentlyDenied: status.isPermanentlyDenied,
          brandColor: _brandColor,
        ),
      );
      if (!mounted) return;
      if (result == 'settings') {
        _waitingForSettings = true;
        await openAppSettings();
      } else if (result == 'skip') {
        setState(() => _step = _GateStep.done);
      }
    }
  }

  Future<void> _onCombinedContinue() async {
    // 1. Check/Enable Location Service
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enable GPS to start receiving requests.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => Geolocator.openLocationSettings(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 2. Request Location Permission
    final locStatus = await Permission.location.request();
    if (!mounted) return;

    // 3. Request Notification Permission
    await locator<NotificationService>().requestNotificationPermission();
    if (!mounted) return;

    // 4. Final status check
    if (locStatus.isPermanentlyDenied) {
      _waitingForSettings = true;
      await openAppSettings();
    } else {
      _determineStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _GateStep.loading:
        // Show the real app/splash while checking permissions; don't gate behind a loader.
        return widget.child;
      case _GateStep.location:
        return _ProviderLocationPage(onContinue: _onLocationContinue);
      case _GateStep.notification:
        return _ProviderNotificationPage(
          onContinue: _onNotificationContinue,
          onSkip: () => setState(() => _step = _GateStep.done),
        );
      case _GateStep.combined:
        return _ProviderUnifiedPermissionPage(onContinue: _onCombinedContinue);
      case _GateStep.done:
        return widget.child;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 2. CUSTOMER PERMISSION GATE
// ════════════════════════════════════════════════════════════════════════════

class CustomerPermissionGate extends ConsumerStatefulWidget {
  final Widget child;

  const CustomerPermissionGate({super.key, required this.child});

  @override
  ConsumerState<CustomerPermissionGate> createState() =>
      _CustomerPermissionGateState();
}

class _CustomerPermissionGateState extends ConsumerState<CustomerPermissionGate>
    with WidgetsBindingObserver {
  _GateStep _step = _GateStep.loading;
  bool _waitingForSettings = false;
  final Color _brandColor = kPrimaryColor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _determineStep();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForSettings) {
      _waitingForSettings = false;
      _determineStep();
    }
  }

  Future<void> _determineStep() async {
    if (!mounted) return;
    setState(() => _step = _GateStep.loading);
    final locPerm = await Permission.location.status;
    if (!mounted) return;
    final hasManualAddress =
        await locator<LocalStorageService>().getSelectedAddress() != null;
    if (!mounted) return;

    if (!locPerm.isGranted && !locPerm.isLimited && !hasManualAddress) {
      setState(() => _step = _GateStep.location);
      return;
    }
    final notifPerm = await Permission.notification.status;
    if (!mounted) return;
    if (!notifPerm.isGranted) {
      setState(() => _step = _GateStep.notification);
      return;
    }
    setState(() => _step = _GateStep.done);
  }

  Future<void> _onLocationContinue() async {
    final status = await Permission.location.request();
    if (!mounted) return;
    if (!status.isGranted && !status.isLimited) {
      final result = await LocationPermissionDialog.show(
        context,
        isPermanentlyDenied: status.isPermanentlyDenied,
      );
      if (!mounted) return;
      if (result == true && status.isPermanentlyDenied) {
        _waitingForSettings = true;
      } else if (result == true) {
        _moveToNotificationStep();
      }
      return;
    }
    _moveToNotificationStep();
  }

  Future<void> _onManualLocation() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const SearchAddressPage(isFromPermissionGate: true),
      ),
    );
    if (!mounted) return;
    if (ref.read(selectedAddressProvider) != null) _moveToNotificationStep();
  }

  void _moveToNotificationStep() {
    if (!mounted) return;
    setState(() => _step = _GateStep.notification);
  }

  Future<void> _onNotificationContinue() async {
    await locator<NotificationService>().requestNotificationPermission();
    if (!mounted) return;
    final status = await Permission.notification.status;
    if (!mounted) return;
    if (status.isGranted) {
      setState(() => _step = _GateStep.done);
    } else {
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _NotificationDeniedDialog(
          isPermanentlyDenied: status.isPermanentlyDenied,
          brandColor: _brandColor,
        ),
      );
      if (!mounted) return;
      if (result == 'settings') {
        _waitingForSettings = true;
        await openAppSettings();
      } else if (result == 'skip') {
        setState(() => _step = _GateStep.done);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _GateStep.loading:
        // Show the real app/splash while checking permissions; don't gate behind a loader.
        return widget.child;
      case _GateStep.location:
        return _CustomerLocationPage(
          onContinue: _onLocationContinue,
          onManual: _onManualLocation,
        );
      case _GateStep.notification:
        return _CustomerNotificationPage(
          onContinue: _onNotificationContinue,
          onSkip: () => setState(() => _step = _GateStep.done),
        );
      case _GateStep.combined:
        // Customers currently don't use the unified flow, fallback to location
        return _CustomerLocationPage(
          onContinue: _onLocationContinue,
          onManual: _onManualLocation,
        );
      case _GateStep.done:
        return widget.child;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PROVIDER PAGES
// ════════════════════════════════════════════════════════════════════════════

class _ProviderLocationPage extends StatelessWidget {
  final VoidCallback onContinue;

  const _ProviderLocationPage({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final brandColor = kPrimaryColor;
    return Scaffold(
      backgroundColor: Colors.white,
      // Button pinned at bottom — always visible regardless of screen size
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 16.h),
          child: SizedBox(
            width: double.infinity,
            height: 54.h,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: brandColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on_rounded, size: 20.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'Grant Location Access',
                    style: kTextSemiBold(
                      color: Colors.white,
                    ).copyWith(fontSize: 16.sp),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 36.h),
              Center(
                child: Container(
                  width: 110.w,
                  height: 110.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: brandColor.withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    size: 54.sp,
                    color: brandColor,
                  ),
                ),
              ),
              SizedBox(height: 32.h),
              Text(
                'Enable Location to Get Started',
                style: kTextBold2(
                  color: Colors.grey.shade800,
                ).copyWith(fontSize: 22.sp),
              ),
              SizedBox(height: 10.h),
              Text(
                'Adhisaat uses your live location to match you with patients nearby and send you service requests in real time. This is a core requirement — the app cannot work without it.',
                style: kTextNormal(
                  color: Colors.grey.shade600,
                ).copyWith(height: 1.6, fontSize: 15.sp),
              ),
              SizedBox(height: 28.h),
              _BulletPoint(
                icon: Icons.flash_on_rounded,
                iconColor: Colors.amber.shade700,
                text:
                    'Get matched instantly with patients who need care near your location.',
              ),
              SizedBox(height: 16.h),
              _BulletPoint(
                icon: Icons.route_rounded,
                iconColor: brandColor,
                text:
                    'Navigate directly to patients with turn-by-turn routing support.',
              ),
              SizedBox(height: 16.h),
              _BulletPoint(
                icon: Icons.lock_outline_rounded,
                iconColor: Colors.green.shade600,
                text:
                    'Your location stays private — shared only after you accept a request.',
              ),
              SizedBox(height: 28.h),
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red.shade600,
                      size: 20.sp,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        'Location permission is required to use this app.',
                        style: kTextNormal0(
                          color: Colors.red.shade700,
                        ).copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderNotificationPage extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  const _ProviderNotificationPage({
    required this.onContinue,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final brandColor = kPrimaryColor;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 28.w,
                      vertical: 24.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 48.h),
                        Center(
                          child: Container(
                            width: 120.w,
                            height: 120.w,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFE3F2FD),
                            ),
                            child: Icon(
                              Icons.notifications_active_rounded,
                              size: 56.sp,
                              color: brandColor,
                            ),
                          ),
                        ),
                        SizedBox(height: 32.h),
                        Text(
                          'Don\'t Miss Any Bookings',
                          style: kTextBold2(
                            color: Colors.grey.shade800,
                          ).copyWith(fontSize: 22.sp),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'Stay updated with real-time request alerts, payment confirmations, and service status changes.',
                          style: kTextNormal(
                            color: Colors.grey.shade600,
                          ).copyWith(height: 1.55, fontSize: 15.sp),
                        ),
                        SizedBox(height: 28.h),
                        _BulletPoint(
                          icon: Icons.bolt_rounded,
                          iconColor: Colors.amber.shade700,
                          text:
                              'New Requests: Be the first to know when a nearby patient needs care.',
                        ),
                        SizedBox(height: 16.h),
                        _BulletPoint(
                          icon: Icons.payments_rounded,
                          iconColor: Colors.green.shade600,
                          text:
                              'Payment Alerts: Get notified instantly when a payment is processed.',
                        ),
                        SizedBox(height: 16.h),
                        _BulletPoint(
                          icon: Icons.update_rounded,
                          iconColor: brandColor,
                          text:
                              'Service Updates: Stay informed about booking status and schedule changes.',
                        ),
                        const Spacer(),
                        SizedBox(height: 48.h),
                        SizedBox(
                          width: double.infinity,
                          height: 54.h,
                          child: ElevatedButton(
                            onPressed: onContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Turn On Notifications',
                              style: kTextSemiBold(
                                color: Colors.white,
                              ).copyWith(fontSize: 16.sp),
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        SizedBox(
                          width: double.infinity,
                          height: 52.h,
                          child: TextButton(
                            onPressed: onSkip,
                            child: Text(
                              'Skip for now',
                              style: kTextSemiBold(
                                color: Colors.grey.shade500,
                              ).copyWith(fontSize: 15.sp),
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CUSTOMER PAGES
// ════════════════════════════════════════════════════════════════════════════

class _CustomerLocationPage extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onManual;

  const _CustomerLocationPage({
    required this.onContinue,
    required this.onManual,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 28.w,
                      vertical: 24.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 48.h),
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 140.w,
                                height: 140.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: kPrimaryColor.withValues(alpha: 0.08),
                                ),
                              ),
                              Container(
                                width: 100.w,
                                height: 100.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: kPrimaryColor.withValues(alpha: 0.12),
                                ),
                                child: Icon(
                                  Icons.location_on_rounded,
                                  size: 52.sp,
                                  color: kPrimaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 40.h),
                        Text(
                          'Find Nearby Care',
                          style: kTextBold2(
                            color: Colors.grey.shade800,
                          ).copyWith(fontSize: 22.sp),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'Location helps us connect you with nearby healthcare services and enables real-time updates for your bookings.',
                          style: kTextNormal(
                            color: Colors.grey.shade600,
                          ).copyWith(height: 1.55, fontSize: 15.sp),
                        ),
                        SizedBox(height: 28.h),
                        _BulletPoint(
                          icon: Icons.search_rounded,
                          iconColor: kPrimaryColor,
                          text:
                              'Discover local healthcare providers instantly.',
                        ),
                        SizedBox(height: 16.h),
                        _BulletPoint(
                          icon: Icons.emergency_rounded,
                          iconColor: Colors.red.shade600,
                          text: 'Faster response and help during emergencies.',
                        ),
                        SizedBox(height: 16.h),
                        _BulletPoint(
                          icon: Icons.local_hospital_outlined,
                          iconColor: kPrimaryColor,
                          text:
                              'Accurate arrival times for your scheduled health visits.',
                        ),
                        const Spacer(),
                        SizedBox(height: 32.h),
                        Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4FF),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: kPrimaryColor.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                color: kPrimaryColor,
                                size: 20.sp,
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  'We value your privacy. Your location is handled securely and used only for service matching.',
                                  style: kTextNormal0(
                                    color: Colors.grey.shade700,
                                  ).copyWith(height: 1.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 32.h),
                        SizedBox(
                          width: double.infinity,
                          height: 54.h,
                          child: ElevatedButton(
                            onPressed: onContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Enable Location Access',
                              style: kTextSemiBold(
                                color: Colors.white,
                              ).copyWith(fontSize: 16.sp),
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        SizedBox(
                          width: double.infinity,
                          height: 52.h,
                          child: OutlinedButton.icon(
                            onPressed: onManual,
                            icon: const Icon(
                              Icons.edit_location_alt_outlined,
                              size: 20,
                              color: kPrimaryColor,
                            ),
                            label: Text(
                              'Enter Location Manually',
                              style: kTextSemiBold(
                                color: kPrimaryColor,
                              ).copyWith(fontSize: 15.sp),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: kPrimaryColor,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CustomerNotificationPage extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  const _CustomerNotificationPage({
    required this.onContinue,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 28.w,
                      vertical: 24.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 48.h),
                        Center(
                          child: Container(
                            width: 120.w,
                            height: 120.w,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFFFF3E0),
                            ),
                            child: Icon(
                              Icons.notifications_active_rounded,
                              size: 56.sp,
                              color: const Color(0xFFF57C00),
                            ),
                          ),
                        ),
                        SizedBox(height: 32.h),
                        Text(
                          'Stay Updated',
                          style: kTextBold2(
                            color: Colors.grey.shade800,
                          ).copyWith(fontSize: 22.sp),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'Enable notifications so you never miss important updates about your bookings and health services.',
                          style: kTextNormal(
                            color: Colors.grey.shade600,
                          ).copyWith(height: 1.55, fontSize: 15.sp),
                        ),
                        SizedBox(height: 28.h),
                        _BulletPoint(
                          icon: Icons.calendar_today_rounded,
                          iconColor: kPrimaryColor,
                          text:
                              'Booking confirmations, reminders, and status updates.',
                        ),
                        SizedBox(height: 16.h),
                        _BulletPoint(
                          icon: Icons.local_offer_rounded,
                          iconColor: const Color(0xFF2E7D32),
                          text: 'Special offers and important health alerts.',
                        ),
                        SizedBox(height: 16.h),
                        _BulletPoint(
                          icon: Icons.chat_bubble_outline_rounded,
                          iconColor: const Color(0xFFF57C00),
                          text:
                              'Real-time messages from your healthcare partner.',
                        ),
                        const Spacer(),
                        SizedBox(height: 48.h),
                        SizedBox(
                          width: double.infinity,
                          height: 54.h,
                          child: ElevatedButton(
                            onPressed: onContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Allow Notifications',
                              style: kTextSemiBold(
                                color: Colors.white,
                              ).copyWith(fontSize: 16.sp),
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        SizedBox(
                          width: double.infinity,
                          height: 52.h,
                          child: TextButton(
                            onPressed: onSkip,
                            child: Text(
                              'Not Now',
                              style: kTextSemiBold(
                                color: Colors.grey.shade500,
                              ).copyWith(fontSize: 15.sp),
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Shared Helper Widgets ────────────────────────────────────────────────────

enum _GateStep { loading, location, notification, combined, done }

class _NotificationDeniedDialog extends StatelessWidget {
  final bool isPermanentlyDenied;
  final Color brandColor;

  const _NotificationDeniedDialog({
    required this.isPermanentlyDenied,
    required this.brandColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64.w,
              height: 64.w,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFF3E0),
              ),
              child: Icon(
                Icons.notifications_off_rounded,
                size: 32.sp,
                color: Color(0xFFF57C00),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Notifications Disabled',
              style: kTextBold2(
                color: Colors.grey.shade800,
              ).copyWith(fontSize: 18.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              isPermanentlyDenied
                  ? 'Notifications are blocked. Please enable them in device Settings to receive importance updates.'
                  : 'Without notifications you may miss booking updates and important alerts.',
              style: kTextNormal(
                color: Colors.grey.shade600,
              ).copyWith(height: 1.55),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: const Color(0xFFF57C00),
                    size: 16.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'You can enable notifications later from your device Settings.',
                      style: kTextNormal0(
                        color: Colors.grey.shade600,
                      ).copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, 'settings'),
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: Text(
                  'Open Settings',
                  style: kTextSemiBold(
                    color: Colors.white,
                  ).copyWith(fontSize: 14.sp),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            SizedBox(height: 10.h),
            SizedBox(
              width: double.infinity,
              height: 44.h,
              child: TextButton(
                onPressed: () => Navigator.pop(context, 'skip'),
                child: Text(
                  'Skip',
                  style: kTextSemiBold(
                    color: Colors.grey.shade500,
                  ).copyWith(fontSize: 14.sp),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _BulletPoint({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 16.sp),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: kTextNormal(
              color: Colors.grey.shade700,
            ).copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _ProviderUnifiedPermissionPage extends StatelessWidget {
  final VoidCallback onContinue;

  const _ProviderUnifiedPermissionPage({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final brandColor = kPrimaryColor;
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 16.h),
          child: SizedBox(
            width: double.infinity,
            height: 54.h,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: brandColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                elevation: 0,
              ),
              child: Text(
                'Enable All Permissions',
                style: kTextSemiBold(
                  color: Colors.white,
                ).copyWith(fontSize: 16.sp),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 36.h),
              Center(
                child: Container(
                  width: 100.w,
                  height: 100.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: brandColor.withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    Icons.security_rounded,
                    size: 50.sp,
                    color: brandColor,
                  ),
                ),
              ),
              SizedBox(height: 32.h),
              Text(
                'Permissions Required',
                style: kTextBold2(
                  color: Colors.grey.shade800,
                ).copyWith(fontSize: 22.sp),
              ),
              SizedBox(height: 10.h),
              Text(
                'To start working as a partner, Adhisaat needs access to your location and notifications.',
                style: kTextNormal(
                  color: Colors.grey.shade600,
                ).copyWith(height: 1.6, fontSize: 15.sp),
              ),
              SizedBox(height: 32.h),
              _UnifiedPoint(
                icon: Icons.location_on_rounded,
                title: 'Live Location',
                subtitle:
                    'To match you with patients nearby and show you the fastest routes.',
                color: brandColor,
              ),
              SizedBox(height: 24.h),
              _UnifiedPoint(
                icon: Icons.notifications_active_rounded,
                title: 'Instant Alerts',
                subtitle:
                    'To notify you about new booking requests and important updates.',
                color: Colors.green.shade600,
              ),
              SizedBox(height: 32.h),
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.blue.shade600,
                      size: 20.sp,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        'You can manage these permissions anytime in your phone settings.',
                        style: kTextNormal0(
                          color: Colors.blue.shade700,
                        ).copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnifiedPoint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _UnifiedPoint({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(icon, color: color, size: 24.sp),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: kTextSemiBold(
                  color: Colors.grey.shade800,
                ).copyWith(fontSize: 16.sp),
              ),
              SizedBox(height: 4.h),
              Text(
                subtitle,
                style: kTextNormal(
                  color: Colors.grey.shade600,
                ).copyWith(fontSize: 14.sp, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
