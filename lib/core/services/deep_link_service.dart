import 'dart:async';

import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/storage/local_storage_service.dart';
import 'package:app_links/app_links.dart';

import '../../di/locator.dart';
import '../navigation/app_navigator.dart';
import '../navigation/app_routes.dart';

class DeepLinkService {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  // Stored when a link arrives before the user has logged in.
  Uri? _pendingLink;

  bool get hasPendingLink => _pendingLink != null;

  void init() {
    _appLinks = AppLinks();

    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });

    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (err) => kPrint('DeepLinkService error: $err'),
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    kPrint('DeepLinkService: received $uri');

    final isLoggedIn = await locator<LocalStorageService>().isLoggedIn;
    if (!isLoggedIn) {
      _pendingLink = uri;
      kPrint('DeepLinkService: not logged in — navigating to login');
      // Delay until the navigator is mounted after cold start.
      Future.delayed(const Duration(milliseconds: 800), () {
        if (AppNavigator.navigatorKey.currentState != null) {
          AppNavigator.removeAndGo(AppRoutes.login);
        }
      });
      return;
    }

    _navigate(uri);
  }

  void _navigate(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return;

    // https://adhisaat.com/booking/{id}
    if (segments.first == 'booking' && segments.length > 1) {
      final id = int.tryParse(segments[1]);
      if (id != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          // Pop to home then push detail — back button returns to home.
          AppNavigator.toAndRemoveUntil(AppRoutes.serviceRequestDetail, args: id);
        });
      }
      return;
    }

    // https://adhisaat.com/provider-booking/{id}
    if (segments.first == 'provider-booking' && segments.length > 1) {
      final id = int.tryParse(segments[1]);
      if (id != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          AppNavigator.toAndRemoveUntil(AppRoutes.providerRequestDetail, args: id);
        });
      }
      return;
    }

    // https://adhisaat.com/refer?code=ABC
    if (segments.first == 'refer') {
      final code = uri.queryParameters['code'];
      Future.delayed(const Duration(milliseconds: 500), () {
        AppNavigator.toAndRemoveUntil(AppRoutes.referEarn, args: code);
      });
      return;
    }

    kPrint('DeepLinkService: unhandled path ${uri.path}');
  }

  /// Call this once the user successfully authenticates so any link that
  /// arrived before login is processed immediately.
  void processPendingLink() {
    final pending = _pendingLink;
    if (pending == null) return;
    _pendingLink = null;
    kPrint('DeepLinkService: processing pending link $pending');
    // Delay so the dashboard finishes mounting after login before we navigate.
    Future.delayed(const Duration(milliseconds: 500), () => _navigate(pending));
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
