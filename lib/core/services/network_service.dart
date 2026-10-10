import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class NetworkService with WidgetsBindingObserver {
  static final NetworkService _instance = NetworkService._internal();

  factory NetworkService() => _instance;

  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  final _connectionChecker = InternetConnectionChecker.instance;

  final StreamController<NetworkStatus> _statusController =
      StreamController<NetworkStatus>.broadcast();

  Stream<NetworkStatus> get onNetworkStatusChange => _statusController.stream;

  // FIX 1: Start as `online` not `unknown`.
  // Both OfflineBanner and AuthWrapper treat any non-online value as "show
  // error", so starting unknown caused a visible flash on every cold start and
  // every foreground resume while the first real check was in-flight.
  NetworkStatus _currentStatus = NetworkStatus.online;

  NetworkStatus get currentStatus => _currentStatus;

  bool get isConnected => _currentStatus == NetworkStatus.online;

  bool get isOffline => _currentStatus == NetworkStatus.offline;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // FIX 2: Remove the dual-listener race.
  // The old code subscribed to BOTH connectivity_plus AND
  // InternetConnectionChecker.onStatusChange. On foreground resume,
  // connectivity_plus fires fast (→ online), then InternetConnectionChecker
  // fires ~2 s later (→ briefly offline) causing the no-network flash even
  // when the phone is online. Now only connectivity_plus is listened to; it
  // acts purely as a trigger and InternetConnectionChecker is used once per
  // trigger for the actual TCP probe.

  // FIX 3: Debounce rapid connectivity events.
  // Android fires 2–4 connectivity events within ~400 ms on foreground resume.
  // We absorb them into a single check with a short debounce.
  Timer? _debounce;
  static const _debounceDuration = Duration(milliseconds: 600);

  // ── Resume-cooldown ───────────────────────────────────────────
  // When the app returns from background the TCP stack takes time to
  // re-establish.  Probing too early (< ~1 s) returns false-offline.
  // During the cooldown window we ignore connectivity_plus events and
  // let a single longer-debounced probe fire instead.
  static const _resumeDebounce = Duration(milliseconds: 1500);
  bool _isInResumeCooldown = false;

  /// Call once from main() after Firebase.initializeApp().
  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);

    // Kick off the initial real check in the background — does not block UI.
    _scheduleCheck();

    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((_) {
      _scheduleCheck();
    });
  }

  // ── Lifecycle observer ────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Enter cooldown: ignore connectivity_plus events for 1500 ms and
      // fire exactly one probe after the network stack has had time to settle.
      _isInResumeCooldown = true;
      _debounce?.cancel();
      _debounce = Timer(_resumeDebounce, () {
        _isInResumeCooldown = false;
        _performCheck();
      });
    }
  }

  void _scheduleCheck() {
    // While the resume cooldown is active the lifecycle-initiated timer
    // already covers this event — skip to avoid resetting to a shorter debounce.
    if (_isInResumeCooldown) return;

    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, _performCheck);
  }

  Future<void> _performCheck() async {
    try {
      final result = await _connectivity.checkConnectivity();

      if (result.contains(ConnectivityResult.none)) {
        _updateStatus(NetworkStatus.offline);
        return;
      }

      // Has a network interface — do a real TCP probe.
      final hasInternet = await _connectionChecker.hasConnection;
      _updateStatus(hasInternet ? NetworkStatus.online : NetworkStatus.offline);
    } catch (_) {
      _updateStatus(NetworkStatus.offline);
    }
  }

  void _updateStatus(NetworkStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _statusController.add(status);
    }
  }

  /// Force a fresh check and return the result. Safe to await from UI.
  ///
  /// Always emits the result on the stream so callers (e.g. a Retry button)
  /// always get a UI update — even when the status did not change (stale
  /// banner from a previous session, or the service already recovered but
  /// the widget hasn't heard yet).
  Future<NetworkStatus> checkNetworkStatus() async {
    await _performCheck();
    // Force-emit so the OfflineBanner / NetworkAwareWidget always refresh.
    _statusController.add(_currentStatus);
    return _currentStatus;
  }

  Future<void> waitForConnection(
      {Duration timeout = const Duration(seconds: 30)}) async {
    if (isConnected) return;

    final completer = Completer<void>();
    StreamSubscription? sub;

    sub = onNetworkStatusChange.listen((status) {
      if (status == NetworkStatus.online) {
        sub?.cancel();
        if (!completer.isCompleted) completer.complete();
      }
    });

    Future.delayed(timeout, () {
      sub?.cancel();
      if (!completer.isCompleted) {
        completer.completeError('Network connection timeout');
      }
    });

    return completer.future;
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _connectivitySubscription?.cancel();
    _statusController.close();
  }
}

enum NetworkStatus { online, offline, unknown }

// Notification types
class NotificationType {
  static const String bookingRequest = 'booking_request';
  static const String providerAssigned = 'provider_assigned';
  static const String serviceStarted = 'service_started';
  static const String serviceCompleted = 'service_completed';
  static const String paymentReceived = 'payment_received';
  static const String providerOnWay = 'provider_on_way';
  static const String providerArrived = 'provider_arrived';
  static const String bookingCancelled = 'booking_cancelled';
  static const String bookingExpired = 'booking_expired';
  static const String bookingCompleted = 'booking_completed';
  static const String settlementDue = 'settlement_due';
  static const String promoCode = 'promo_code';
  static const String providerPayoutCompleted = 'provider_payout_completed';
}
