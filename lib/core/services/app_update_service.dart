import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:upgrader/upgrader.dart';

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();

  factory AppUpdateService() => _instance;

  AppUpdateService._internal();

  /// Check for updates on Android using Play Store (Immediate / Force update)
  Future<void> checkForAndroidUpdate() async {
    if (!Platform.isAndroid) return;

    try {
      final updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (updateInfo.immediateUpdateAllowed) {
          // Immediate update - forces full-screen blocking update flow
          await InAppUpdate.performImmediateUpdate();
        }
      }
    } catch (e) {
      debugPrint('Error checking for Android update: $e');
    }
  }

  /// Check for updates on iOS using Upgrader package (Immediate / Force update)
  Widget wrapWithUpgrader({required Widget child}) {
    return UpgradeAlert(
      barrierDismissible: false,
      shouldPopScope: () => false,
      showIgnore: false,
      showLater: false,
      dialogStyle: Platform.isIOS ? UpgradeDialogStyle.cupertino : UpgradeDialogStyle.material,
      upgrader: Upgrader(durationUntilAlertAgain: Duration.zero),
      child: child,
    );
  }

  /// Initialize update check on app start
  Future<void> initializeUpdateCheck() async {
    if (kReleaseMode) {
      await Future.delayed(const Duration(seconds: 2));

      if (Platform.isAndroid) {
        await checkForAndroidUpdate();
      }
    }
    // iOS update is handled by wrapWithUpgrader widget
  }

  /// Get current app version
  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }

  /// Force update check (manual trigger)
  // Future<void> manualUpdateCheck(BuildContext context) async {
  //   if (Platform.isAndroid) {
  //     await checkForAndroidUpdate();
  //   } else if (Platform.isIOS) {
  //     // Show update dialog for iOS
  //     Upgrader().checkVersion(context: context);
  //   }
  // }
}

/// Widget wrapper for auto-update functionality
class AppUpdateWrapper extends StatefulWidget {
  final Widget child;

  const AppUpdateWrapper({super.key, required this.child});

  @override
  State<AppUpdateWrapper> createState() => _AppUpdateWrapperState();
}

class _AppUpdateWrapperState extends State<AppUpdateWrapper> {
  @override
  void initState() {
    super.initState();
    _initializeUpdate();
  }

  Future<void> _initializeUpdate() async {
    await AppUpdateService().initializeUpdateCheck();
  }

  @override
  Widget build(BuildContext context) {
    // Wrap with Upgrader for iOS
    if (Platform.isIOS) {
      return AppUpdateService().wrapWithUpgrader(child: widget.child);
    }

    // Android handles updates via InAppUpdate
    return widget.child;
  }
}
