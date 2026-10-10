import 'package:intl/intl.dart';

class NumberUtils {
  NumberUtils._();

  // ---------------- CURRENCY ----------------

  /// ₹ 1,500
  static String formatCurrency(dynamic value, {String symbol = '₹', String locale = 'en_IN', int decimalDigits = 2}) {
    final numValue = toDouble(value);
    // If it's a whole number, set decimalDigits to 0
    final usedDecimalDigits = (numValue % 1 == 0) ? 0 : decimalDigits;
    final formatter = NumberFormat.currency(symbol: symbol, locale: locale, decimalDigits: usedDecimalDigits);

    return formatter.format(numValue);
  }

  // ---------------- SAFE CONVERSIONS ----------------

  static int toInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;
    if (value is double) return value.round();

    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed?.round() ?? 0;
    }

    return 0;
  }

  static double toDouble(dynamic value) {
    if (value == null) return 0.0;

    if (value is double) return value;
    if (value is int) return value.toDouble();

    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }

    return 0.0;
  }

  // ---------------- EXTRACT NUMBERS ----------------

  /// "AB-1234" → 1234
  static int extractNumber(dynamic value) {
    if (value == null) return 0;
    final numeric = value.toString().replaceAll(RegExp(r'\D'), '');
    return int.tryParse(numeric) ?? 0;
  }

  /// "8094663744" → "80xxxxxx44"
  static String maskPhone(String phone) {
    final clean = phone.trim();
    if (clean.length < 4) return clean;
    if (clean.length == 10) {
      return '${clean.substring(0, 2)}xxxxxx${clean.substring(8)}';
    }
    return '${clean.substring(0, 2)}${'x' * (clean.length - 4)}${clean.substring(clean.length - 2)}';
  }
}
// ---------------- STRING HELPERS ----------------

String cleanDecimal(dynamic value) {
  final d = NumberUtils.toDouble(value);
  String s = d.toStringAsFixed(2);
  if (s.contains('.')) {
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.')) {
      s = s.substring(0, s.length - 1);
    }
  }
  return s;
}

bool isNotNull(dynamic value) {
  return value != null && value.toString().trim().isNotEmpty;
}

String? nonEmptyOrNull(dynamic value) {
  if (isNotNull(value)) {
    return value.toString().trim();
  }
  return null;
}
