import 'dart:async';

import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

import '../../services/network_service.dart';

/// A slim banner that slides down from the top when the device goes offline.
///
/// Fix notes
/// ─────────
/// • `initialData` is seeded from `currentStatus` (which is now `online` by
///   default in NetworkService) so the banner never flickers on cold start.
/// • We only show the banner for `offline` — `unknown` is treated as online.
/// • A `_stableOffline` latch requires the service to stay offline for at
///   least [_minOfflineDuration] before the banner appears, preventing a
///   false-positive flash on foreground resume when the connectivity check
///   briefly reports offline before confirming the connection is alive.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  // How long offline must persist before the banner appears.
  // Must exceed NetworkService._resumeDebounce (1500 ms) so a probe that
  // is still in-flight on foreground resume never triggers a visible flash.
  static const _minOfflineDuration = Duration(milliseconds: 1800);

  bool _stableOffline = false;
  bool _retrying = false;
  Timer? _showTimer;

  @override
  void dispose() {
    _showTimer?.cancel();
    super.dispose();
  }

  void _handleStatus(NetworkStatus? status) {
    final isOffline = status == NetworkStatus.offline;

    if (isOffline && !_stableOffline) {
      // Start the stability timer — only show banner if still offline after delay
      _showTimer ??= Timer(_minOfflineDuration, () {
        if (mounted) setState(() => _stableOffline = true);
      });
    } else if (!isOffline) {
      // Back online — cancel pending timer and hide immediately
      _showTimer?.cancel();
      _showTimer = null;
      if ((_stableOffline || _retrying) && mounted) {
        // Defer setState to avoid calling it during a build phase
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
            _stableOffline = false;
            _retrying = false;
          });
          }
        });
      }
    }
  }

  /// Called when the user taps "Retry" on the banner.
  Future<void> _onRetry() async {
    if (_retrying) return;
    if (mounted) setState(() => _retrying = true);

    await NetworkService().checkNetworkStatus();

    // If still offline after the check, stop spinner but keep banner visible.
    if (mounted && _retrying) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NetworkStatus>(
      stream: NetworkService().onNetworkStatusChange,
      initialData: NetworkService().currentStatus,
      builder: (context, snapshot) {
        // Schedule outside the build phase to avoid setState-during-build errors
        Future.microtask(() => _handleStatus(snapshot.data));

        return Material(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _stableOffline ? kSize(100) : 0,
            color: kErrorColor,
            child: _stableOffline
                ? SafeArea(
                    bottom: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No internet connection.',
                              style: kTextMedium1(color: kWhiteColor).merge(const TextStyle(height: 1.3)),
                            ),
                          ),
                          // ── Retry button ───────────────────────────
                          _retrying
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : TextButton(
                                  onPressed: _onRetry,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    minimumSize: Size.zero,
                                  ),
                                  child: const Text(
                                    'Retry',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Colors.white,
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}
