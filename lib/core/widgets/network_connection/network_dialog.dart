import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:flutter/material.dart';

class NetworkDialog {
  /// Show offline dialog when user tries to perform network action
  static Future<bool?> showOfflineDialog() {
    return showDialog<bool>(
      context: AppNavigator.context!,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.orange[700]),
            const SizedBox(width: 12),
            const Text('No Connection'),
          ],
        ),
        content: const Text(
          'We can\'t reach our network right now. Please check your network connection and try again.',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('OK'))],
      ),
    );
  }

  /// Show when navigation requires network
  static Future<bool?> showNavigationBlockedDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange[700]),
            const SizedBox(width: 12),
            const Text('Offline Mode'),
          ],
        ),
        content: const Text(
          'This feature requires an internet connection. Please connect to the internet and try again.',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('OK'))],
      ),
    );
  }

  /// Show snackbar for quick feedback
  static void showOfflineSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text('No internet connection. Please check your network.', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1F1F1F),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
