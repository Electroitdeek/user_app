import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/network_service.dart';

class NetworkAwareWidget extends StatefulWidget {
  final Widget Function(BuildContext context, NetworkStatus status) builder;
  final Widget? offlineWidget;

  const NetworkAwareWidget({super.key, required this.builder, this.offlineWidget});

  @override
  State<NetworkAwareWidget> createState() => _NetworkAwareWidgetState();
}

class _NetworkAwareWidgetState extends State<NetworkAwareWidget> {
  final _networkService = NetworkService();
  late StreamSubscription<NetworkStatus> _subscription;
  Timer? _offlineTimer;

  // Never start as offline — the service's initial online state is authoritative.
  // Transient offline events (e.g. false-offline during resume TCP re-probe)
  // are absorbed by the debounce below.
  bool _showOffline = false;

  @override
  void initState() {
    super.initState();
    _subscription = _networkService.onNetworkStatusChange.listen(_handleStatus);
  }

  void _handleStatus(NetworkStatus status) {
    if (status == NetworkStatus.offline) {
      // Only switch to offline view after 3.5 s of sustained no-internet.
      // This absorbs the false-offline flash that occurs on foreground resume
      // while the TCP stack is re-establishing (typically resolves in <2 s).
      _offlineTimer ??= Timer(const Duration(milliseconds: 3500), () {
        _offlineTimer = null;
        if (mounted) setState(() => _showOffline = true);
      });
    } else {
      // Back online — cancel any pending offline transition and restore immediately.
      _offlineTimer?.cancel();
      _offlineTimer = null;
      if (_showOffline && mounted) setState(() => _showOffline = false);
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _offlineTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showOffline && widget.offlineWidget != null) {
      return widget.offlineWidget!;
    }
    return widget.builder(context, _showOffline ? NetworkStatus.offline : NetworkStatus.online);
  }
}
