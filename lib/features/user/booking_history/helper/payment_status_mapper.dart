import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

enum PaymentStatus {
  pending,
  partiallyPaid,
  paid,
  failed,
  unknown,
}

class PaymentDisplayConfig {
  final String label;
  final Color color;
  final Color bgColor;
  final IconData icon;

  const PaymentDisplayConfig({
    required this.label,
    required this.color,
    required this.bgColor,
    required this.icon,
  });
}

class PaymentStatusMapper {
  PaymentStatusMapper._();

  static PaymentStatus fromString(String raw) {
    switch (raw.toLowerCase()) {
      case 'pending':
        return PaymentStatus.pending;
      case 'partially_paid':
        return PaymentStatus.partiallyPaid;
      case 'paid':
        return PaymentStatus.paid;
      case 'failed':
        return PaymentStatus.failed;
      default:
        return PaymentStatus.unknown;
    }
  }

  static PaymentDisplayConfig getConfig(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return PaymentDisplayConfig(
          label: 'Paid',
          color: kSuccessColor,
          bgColor: kSuccessColor.withValues(alpha: 0.1),
          icon: Icons.check_circle_rounded,
        );
      case PaymentStatus.partiallyPaid:
        return PaymentDisplayConfig(
          label: 'Partially Paid',
          color: kSecondaryColor,
          bgColor: kSecondaryColor.withValues(alpha: 0.1),
          icon: Icons.pie_chart_rounded,
        );
      case PaymentStatus.pending:
        return PaymentDisplayConfig(
          label: 'Pending',
          color: kAccentColor,
          bgColor: kAccentColor.withValues(alpha: 0.1),
          icon: Icons.pending_rounded,
        );
      case PaymentStatus.failed:
        return PaymentDisplayConfig(
          label: 'Failed',
          color: kErrorColor,
          bgColor: kErrorColor.withValues(alpha: 0.1),
          icon: Icons.error_rounded,
        );
      default:
        return PaymentDisplayConfig(
          label: 'Unknown',
          color: const Color(0xFF9CA3AF),
          bgColor: const Color(0xFFF3F4F6),
          icon: Icons.help_outline_rounded,
        );
    }
  }
}
