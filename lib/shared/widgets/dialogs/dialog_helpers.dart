import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:flutter/material.dart';

import 'custom_dialogs.dart';

class DialogHelper {
  // Access the current context via the global navigator key
  static BuildContext? get _context => AppNavigator.navigatorKey.currentContext;

  /// Show Success Dialog
  static void showSuccess({
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onConfirm,
  }) {
    if (_context == null) return;
    showDialog(
      context: _context!,
      barrierDismissible: false,
      builder: (context) =>
          SuccessDialog(title: title, message: message, buttonText: buttonText, onConfirm: onConfirm),
    );
  }

  /// Show Error Dialog
  static void showError({
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onConfirm,
    String? dismissText,
    VoidCallback? onDismiss,
    bool barrierDismissible = false,
  }) {
    if (_context == null) return;
    showDialog(
      context: _context!,
      barrierDismissible: barrierDismissible,
      builder: (context) => ErrorDialog(
        title: title,
        message: message,
        buttonText: buttonText,
        onConfirm: onConfirm,
        dismissText: dismissText,
        onDismiss: onDismiss,
      ),
    );
  }

  /// Show Warning Dialog
  static void showWarning({
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onConfirm,
    String? dismissText,
    VoidCallback? onDismiss,
  }) {
    if (_context == null) return;
    showDialog(
      context: _context!,
      builder: (context) => WarningDialog(
        title: title,
        message: message,
        buttonText: buttonText,
        onConfirm: onConfirm,
        dismissText: dismissText,
        onDismiss: onDismiss,
      ),
    );
  }

  /// Show Confirmation Dialog
  static Future<bool?> showConfirmation({
    required String title,
    required String message,
    VoidCallback? onConfirm,
    String? confirmText,
    String? cancelText,
    VoidCallback? onCancel,
    bool isDangerous = false,
  }) async {
    if (_context == null) return false;
    return await showDialog<bool>(
      context: _context!,
      builder: (context) => ConfirmationDialog(
        title: title,
        message: message,
        onConfirm: onConfirm,
        confirmText: confirmText,
        cancelText: cancelText,
        onCancel: onCancel,
        isDangerous: isDangerous,
      ),
    );
  }

  /// Show Loading Dialog
  static void showLoading({String? message}) {
    if (_context == null) return;
    showDialog(
      context: _context!,
      barrierDismissible: false,
      builder: (context) => LoadingDialog(message: message),
    );
  }

  /// Show Info Dialog
  static void showInfo({
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onConfirm,
  }) {
    if (_context == null) return;
    showDialog(
      context: _context!,
      builder: (context) =>
          InfoDialog(title: title, message: message, buttonText: buttonText, onConfirm: onConfirm),
    );
  }

  /// Show SOS Dialog
  static void showSOS({required String message, required VoidCallback onCallAdmin, VoidCallback? onCancel}) {
    if (_context == null) return;
    showDialog(
      context: _context!,
      barrierDismissible: false,
      builder: (context) => SOSDialog(message: message, onCallAdmin: onCallAdmin, onCancel: onCancel),
    );
  }

  /// Show Verification Dialog
  static void showVerification({
    required String title,
    required String message,
    required Function(String) onVerify,
  }) {
    if (_context == null) return;
    showDialog(
      context: _context!,
      builder: (context) => VerificationDialog(title: title, message: message, onVerify: onVerify),
    );
  }

  /// Show Payment Confirmation Dialog
  static void showPaymentConfirmation({
    required String amount,
    required String serviceName,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
  }) {
    if (_context == null) return;
    showDialog(
      context: _context!,
      builder: (context) => PaymentConfirmationDialog(
        amount: amount,
        serviceName: serviceName,
        onConfirm: onConfirm,
        onCancel: onCancel,
      ),
    );
  }
}
