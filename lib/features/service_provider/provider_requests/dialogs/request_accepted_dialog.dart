import 'package:flutter/material.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/shared/widgets/dialogs/custom_dialogs.dart';

class RequestAcceptedDialog {
  static void show(
    BuildContext context, {
    required int requestId,
    required String message,
    required VoidCallback onViewBooking,
    VoidCallback? onDismissed,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RequestAcceptedContent(
        message: message,
        onViewBooking: onViewBooking,
        onDismissed: onDismissed,
      ),
    );
  }
}

class _RequestAcceptedContent extends StatelessWidget {
  final String message;
  final VoidCallback onViewBooking;
  final VoidCallback? onDismissed;

  const _RequestAcceptedContent({
    required this.message,
    required this.onViewBooking,
    this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, _) => onDismissed?.call(),
      child: AppDialog(
        accentColor: kSuccessColor,
        iconBg: const Color(0xFFF0FDF4),
        icon: Icons.check_rounded,
        iconColor: kSuccessColor,
        title: 'Request Accepted!',
        message: message.isNotEmpty ? message : 'Request accepted successfully.',
        primaryLabel: 'View Booking',
        onPrimary: () {
          Navigator.pop(context);
          onViewBooking();
        },
        primaryColor: kSuccessColor,
        ghostLabel: 'Close',
        onGhost: () {
          Navigator.pop(context);
          onDismissed?.call();
        },
      ),
    );
  }
}
