import 'package:adhisaat_health_care/core/services/network_service.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:flutter/material.dart';

import '../widgets/network_connection/network_dialog.dart';

class AppNavigator {
  static final AppNavigator _instance = AppNavigator._internal();

  factory AppNavigator() => _instance;

  AppNavigator._internal();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static BuildContext? get context => navigatorKey.currentState?.overlay?.context;

  /// Push new page
  static Future<T?> push<T>(Widget page, {bool requiresNetwork = false, bool fullscreenDialog = false}) async {
    final networkService = locator<NetworkService>();
    // If network required and offline, show dialog
    if (requiresNetwork && networkService.isOffline) {
      await NetworkDialog.showNavigationBlockedDialog(context!);
      return null;
    }

    return navigatorKey.currentState!.push(
      MaterialPageRoute(builder: (_) => page, fullscreenDialog: fullscreenDialog),
    );
  }

  Future<T?> pushWithNetworkCheck<T>(Widget page, {bool requiresNetwork = false}) async {
    final networkService = locator<NetworkService>();
    // If network required and offline, show dialog
    if (requiresNetwork && networkService.isOffline) {
      await NetworkDialog.showNavigationBlockedDialog(context!);
      return null;
    }

    return navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => page));
  }

  /// Replace current page
  static Future<T?> pushReplacement<T>(Widget page) {
    return navigatorKey.currentState!.pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

  /// Clear all previous pages and navigate
  static Future<T?> pushAndRemoveUntil<T>(Widget page) {
    return navigatorKey.currentState!.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => page),
      (route) => false,
    );
  }

  /// Pop current page
  static void pop(BuildContext context, [dynamic result]) {
    Navigator.pop(context, result);
  }

  /// Pop until first screen
  static void popToRoot(BuildContext context) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  //  Fade / Slide Animation
  static Future<T?> pushWithFade<T>(Widget page) {
    return navigatorKey.currentState!.push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  // ---------- PUSH ----------
  static Future<dynamic> to(String route, {Object? arguments}) async {
    return await navigatorKey.currentState!.pushNamed(route, arguments: arguments);
  }

  // ---------- PUSH REPLACEMENT ----------
  static Future<void> replaceWith(String route, {Object? args}) {
    return navigatorKey.currentState!.pushReplacementNamed(route, arguments: args);
  }

  // ---------- CLEAR UNTIL FIRST ----------
  static Future<void> toAndRemoveUntil(String route, {Object? args}) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil(route, (route) => route.isFirst, arguments: args);
  }

  // ---------- CLEAR STACK ----------
  static Future<void> removeAndGo(String route, {Object? args}) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil(route, (route) => false, arguments: args);
  }

  // ---------- BACK ----------
  static void back([dynamic result]) {
    navigatorKey.currentState!.pop(result);
  }
}
