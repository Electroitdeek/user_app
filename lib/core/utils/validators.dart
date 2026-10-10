import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class Validators {
  static String? validateIsNoEmpty(String? value) {
    if (value!.isEmpty) {
      return "Field can't be empty";
    }
    return null;
  }

  Validators._();

  /// Aadhaar validation
  static String? validateAadhaar(String? value) {
    if (kDebugMode) return null; // Skip validation in debug mode for testing
    if (value == null || value.trim().isEmpty) {
      return 'Aadhaar number is required';
    }

    // Remove spaces
    final aadhaar = value.replaceAll(' ', '');

    // Check length
    if (aadhaar.length != 12) {
      return 'Aadhaar must be 12 digits';
    }

    // Check if all digits
    if (!RegExp(r'^\d{12}$').hasMatch(aadhaar)) {
      return 'Aadhaar must contain only digits';
    }

    // Verhoeff algorithm validation
    if (!_verhoeffValidate(aadhaar)) {
      return 'Invalid Aadhaar number';
    }

    return null;
  }

  /// PAN validation
  static String? validatePAN(String? value) {
    // if (kDebugMode) return null; // Skip validation in debug mode for testing
    if (value == null || value.trim().isEmpty) {
      return 'PAN number is required';
    }

    final pan = value.toUpperCase().trim();

    // PAN format: AAAAA9999A
    // 5 letters, 4 digits, 1 letter
    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');

    if (!panRegex.hasMatch(pan)) {
      return 'Invalid PAN format (e.g., ABCDE1234F)';
    }

    // 4th character must be 'P' for individual
    if (pan[3] != 'P') {
      return 'Only individual PAN allowed';
    }

    return null;
  }

  /// Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Phone validation (10 digits)
  static String? validatePhone(String? value, {String label = 'Phone number'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    if (value.trim().length != 10) {
      return '$label must be 10 digits';
    }
    if (!RegExp(r'^\d{10}$').hasMatch(value.trim())) {
      return '$label must contain only digits';
    }
    return null;
  }

  /// Minimum age validation
  static String? validateMinimumAge(String? value, {int minAge = 18}) {
    if (value == null || value.trim().isEmpty) {
      return 'Date of birth is required';
    }
    try {
      DateTime? dob;
      // Try multiple formats
      try {
        dob = DateFormat('yyyy-MM-dd').parse(value);
      } catch (_) {
        try {
          dob = DateFormat('dd MMM yyyy').parse(value);
        } catch (_) {
          try {
            dob = DateTime.parse(value);
          } catch (_) {
            return 'Invalid date format';
          }
        }
      }

      final now = DateTime.now();
      final ageDate = DateTime(dob.year + minAge, dob.month, dob.day);
      if (ageDate.isAfter(now)) {
        return 'You must be at least $minAge years old';
      }
    } catch (_) {
      return 'Invalid date format';
    }
    return null;
  }

  /// Verhoeff algorithm for Aadhaar
  static bool _verhoeffValidate(String num) {
    final d = [
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
      [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
      [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
      [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
      [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
      [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
      [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
      [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
      [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
      [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
    ];

    final p = [
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
      [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
      [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
      [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
      [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
      [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
      [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
      [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
    ];

    int c = 0;
    final myArray = num.split('').reversed.toList();

    for (int i = 0; i < myArray.length; i++) {
      c = d[c][p[(i % 8)][int.parse(myArray[i])]];
    }

    return c == 0;
  }
}
