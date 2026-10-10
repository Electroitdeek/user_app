import 'package:adhisaat_health_care/core/theme/screen_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_colors.dart';
import 'app_edge_insets.dart';

/// 🎨 Unified Input Theme Configuration
///
/// This file contains all input decoration themes for:
/// - TextFields
/// - Dropdowns
/// - Date Pickers
/// - Any other form inputs
///
/// Provides consistent styling across the entire app

// ═══════════════════════════════════════════════════════════════
// 📐 INPUT DIMENSIONS
// ═══════════════════════════════════════════════════════════════

class InputDimensions {
  // Heights
  static double get standardHeight => AppButtonHeight.m; // 48.h
  static double get compactHeight => AppButtonHeight.s; // 40.h
  static double get largeHeight => AppButtonHeight.l; // 56.h

  // Border radius
  static double get borderRadius => 12.r;

  static double get largeBorderRadius => 16.r;

  // Border width
  static double get borderWidth => 1.5.w;

  static double get focusedBorderWidth => 2.w;

  // Icon sizes
  static double get iconSize => AppIconSize.s; // 20.sp

  // Padding
  static EdgeInsets get contentPadding => AppPadding.symmetric(h: 16, v: 12);

  static EdgeInsets get multilineContentPadding => AppPadding.symmetric(h: 16, v: 16);
}

// ═══════════════════════════════════════════════════════════════
// 🎨 INPUT DECORATION THEME
// ═══════════════════════════════════════════════════════════════

/// Creates consistent InputDecorationTheme for the entire app
///
/// Usage in MaterialApp:
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     inputDecorationTheme: AppInputTheme.standard(),
///   ),
/// )
/// ```
class AppInputTheme {
  /// Standard input theme (default for the app)
  static InputDecorationTheme standard({Color? backgroundColor, double? borderRadius}) {
    return _buildTheme(
      backgroundColor: backgroundColor ?? kWhiteColor,
      borderRadius: borderRadius ?? InputDimensions.borderRadius,
    );
  }

  /// Filled input theme (with background)
  static InputDecorationTheme filled({Color? backgroundColor, double? borderRadius}) {
    return _buildTheme(
      backgroundColor: backgroundColor ?? kGreyColor1,
      borderRadius: borderRadius ?? InputDimensions.borderRadius,
    );
  }

  /// Outlined input theme (no fill, just border)
  static InputDecorationTheme outlined({double? borderRadius}) {
    return _buildTheme(
      backgroundColor: Colors.transparent,
      borderRadius: borderRadius ?? InputDimensions.borderRadius,
      isFilled: false,
    );
  }

  /// Rounded input theme (extra rounded corners)
  static InputDecorationTheme rounded({Color? backgroundColor}) {
    return _buildTheme(
      backgroundColor: backgroundColor ?? kWhiteColor,
      borderRadius: InputDimensions.largeBorderRadius,
    );
  }

  // Private builder method
  static InputDecorationTheme _buildTheme({
    required Color backgroundColor,
    required double borderRadius,
    bool isFilled = true,
  }) {
    return InputDecorationTheme(
      // Fill
      filled: isFilled,
      fillColor: backgroundColor,
      errorMaxLines: 2,
      isCollapsed: false,
      // Content padding
      contentPadding: InputDimensions.contentPadding,

      // Text styles
      labelStyle: TextStyle(color: kGreyColor6, fontSize: 14.sp),
      hintStyle: TextStyle(color: kGreyColor6, fontSize: 14.sp),
      errorStyle: TextStyle(color: kErrorColor, fontSize: 12.sp),

      // Counter
      counterStyle: TextStyle(color: kGreyColor6, fontSize: 12.sp),

      // Borders
      border: _buildBorder(borderRadius: borderRadius, color: isFilled ? Colors.transparent : kGreyColor4),

      enabledBorder: _buildBorder(
        borderRadius: borderRadius,
        color: kGreyColor4,
        width: InputDimensions.borderWidth,
      ),

      focusedBorder: _buildBorder(
        borderRadius: borderRadius,
        color: kPrimaryColor,
        width: InputDimensions.focusedBorderWidth,
      ),

      errorBorder: _buildBorder(
        borderRadius: borderRadius,
        color: kErrorColor,
        width: InputDimensions.borderWidth,
      ),

      focusedErrorBorder: _buildBorder(
        borderRadius: borderRadius,
        color: kErrorColor,
        width: InputDimensions.focusedBorderWidth,
      ),

      disabledBorder: _buildBorder(
        borderRadius: borderRadius,
        color: kGreyColor3,
        width: InputDimensions.borderWidth,
      ),

      // Icon theme
      iconColor: kPrimaryColor,
      prefixIconColor: kPrimaryColor,
      suffixIconColor: kPrimaryColor,
    );
  }

  // Helper to build border
  static OutlineInputBorder _buildBorder({required double borderRadius, required Color color, double? width}) {
    return OutlineInputBorder(
      borderRadius: AppRadius.circular(borderRadius),
      borderSide: BorderSide(color: color, width: width ?? 0),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 🎯 INPUT DECORATION HELPERS
// ═══════════════════════════════════════════════════════════════

/// Helper functions to create InputDecoration for specific use cases

class InputDecorationHelpers {
  /// Standard text field decoration
  static InputDecoration textField({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? prefixText,
    bool enabled = true,
    Color? fillColor,
    double? borderRadius,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      prefixText: prefixText,
      enabled: enabled,
      fillColor: fillColor ?? (enabled ? kWhiteColor : kGreyColor2.withValues(alpha: 0.3)),
      border: AppInputTheme._buildBorder(
        borderRadius: borderRadius ?? InputDimensions.borderRadius,
        color: kGreyColor4,
      ),
    );
  }

  /// Search field decoration
  static InputDecoration searchField({String hintText = 'Search...', VoidCallback? onClear}) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(Icons.search, size: AppIconSize.m),
      suffixIcon: onClear != null
          ? IconButton(
              icon: Icon(Icons.clear, size: AppIconSize.s),
              onPressed: onClear,
            )
          : null,
      filled: true,
      fillColor: kGreyColor1,
      border: AppInputTheme._buildBorder(
        borderRadius: 24.r, // Extra rounded for search
        color: Colors.transparent,
      ),
      enabledBorder: AppInputTheme._buildBorder(borderRadius: 24.r, color: Colors.transparent),
      focusedBorder: AppInputTheme._buildBorder(
        borderRadius: 24.r,
        color: kPrimaryColor,
        width: InputDimensions.focusedBorderWidth,
      ),
    );
  }

  /// Dropdown decoration
  static InputDecoration dropdown({
    String? hintText,
    Widget? prefixIcon,
    bool enabled = true,
    Color? fillColor,
    double? borderRadius,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon,
      enabled: enabled,
      isDense: true,
      contentPadding: AppPadding.symmetric(h: 16, v: 12),
      fillColor: fillColor ?? (enabled ? kWhiteColor : kGreyColor2.withValues(alpha: 0.3)),
      border: AppInputTheme._buildBorder(
        borderRadius: borderRadius ?? InputDimensions.borderRadius,
        color: kGreyColor4,
      ),
    );
  }

  /// Multiline text area decoration
  static InputDecoration textArea({String? labelText, String? hintText, bool enabled = true, Color? fillColor}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      enabled: enabled,
      alignLabelWithHint: true,
      contentPadding: InputDimensions.multilineContentPadding,
      fillColor: fillColor ?? (enabled ? kWhiteColor : kGreyColor2.withValues(alpha: 0.3)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 🎨 INPUT COLORS (Centralized color management)
// ═══════════════════════════════════════════════════════════════

class InputColors {
  // Background colors
  static const Color backgroundDefault = kWhiteColor;
  static Color backgroundDisabled = kGreyColor2.withValues(alpha: 0.3);
  static Color backgroundFilled = kGreyColor1;

  // Border colors
  static Color borderDefault = kGreyColor4;
  static const Color borderFocused = kPrimaryColor;
  static const Color borderError = kErrorColor;
  static Color borderDisabled = kGreyColor3;

  // Text colors
  static const Color textDefault = kBlackColor;
  static Color textDisabled = kGreyColor7;
  static Color textHint = kGreyColor6;
  static const Color textError = kErrorColor;

  // Icon colors
  static const Color iconDefault = kPrimaryColor;
  static Color iconDisabled = kGreyColor5;
}

// ═══════════════════════════════════════════════════════════════
// 🎯 USAGE EXAMPLES
// ═══════════════════════════════════════════════════════════════

// class InputThemeExamples extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         // Example 1: Using theme in MaterialApp
//         // MaterialApp(
//         //   theme: ThemeData(
//         //     inputDecorationTheme: AppInputTheme.standard(),
//         //   ),
//         // )
//
//         // Example 2: Custom decoration
//         TextField(
//           decoration: InputDecorationHelpers.textField(
//             labelText: 'Name',
//             hintText: 'Enter your name',
//             prefixIcon: Icon(Icons.person),
//           ),
//         ),
//
//         AppSpacing.m,
//
//         // Example 3: Search field
//         TextField(
//           decoration: InputDecorationHelpers.searchField(hintText: 'Search services...', onClear: () {}),
//         ),
//
//         AppSpacing.m,
//
//         // Example 4: Dropdown
//         DropdownButtonFormField(
//           decoration: InputDecorationHelpers.dropdown(hintText: 'Select option'),
//           items: [],
//           onChanged: null,
//         ),
//
//         AppSpacing.m,
//
//         // Example 5: Text area
//         TextField(
//           maxLines: 5,
//           decoration: InputDecorationHelpers.textArea(labelText: 'Description', hintText: 'Enter details...'),
//         ),
//       ],
//     );
//   }
// }

// InputDecorationTheme appInputDecorationTheme({
//   double radius = 8.0,
//   Color? backgroundColor,
//   BorderSide? enabledBorderSide,
// }) {
//   final borderRadius = AppRadius.circular(radius);
//
//   OutlineInputBorder outline(BorderSide side) {
//     return OutlineInputBorder(borderRadius: borderRadius, borderSide: side);
//   }
//
//   return InputDecorationTheme(
//     filled: true,
//     fillColor: backgroundColor ?? kWhiteColor,
//
//     labelStyle: TextStyle(color: kGreyColor6),
//     hintStyle: TextStyle(color: kGreyColor6),
//
//     border: outline(enabledBorderSide ?? BorderSide.none),
//     enabledBorder: outline(enabledBorderSide ?? BorderSide(color: kGreyColor7, width: 1.5)),
//     focusedBorder: outline(const BorderSide(color: kPrimaryColor, width: 2)),
//
//     disabledBorder: outline(BorderSide(color: kGreyColor5, width: 1.5)),
//
//     errorBorder: outline(const BorderSide(color: kWarningColor, width: 1)),
//     focusedErrorBorder: outline(const BorderSide(color: kWarningColor, width: 2)),
//
//     // enabledBorder: outline(enabledBorderSide ?? BorderSide(color: kGreyColor7, width: 1.5)),
//     //
//     // focusedBorder: outline(const BorderSide(color: kPrimaryColor, width: 2)),
//     //
//     // errorBorder: outline(const BorderSide(color: kWarningColor)),
//     //
//     // focusedErrorBorder: outline(const BorderSide(color: kWarningColor, width: 2)),
//     //
//     // disabledBorder: outline(BorderSide(color: Colors.grey.shade600, width: 1.5)),
//     //
//     // border: outline(const BorderSide(width: 1.5)),
//   );
// }

// InputDecorationTheme appInputDecorationTheme1({
//   double radius = 35.0, // Default to your "Top-Notch" rounded look
//   Color? backgroundColor,
//   BorderSide? enabledBorderSide,
// }) {
//   final borderRadius = BorderRadius.circular(radius);
//
//   OutlineInputBorder outline(BorderSide side) {
//     return OutlineInputBorder(borderRadius: borderRadius, borderSide: side);
//   }
//
//   return InputDecorationTheme(
//     filled: true,
//     fillColor: backgroundColor ?? Colors.grey.shade100,
//     // Light grey for medical feel
//     labelStyle: kTextNormal1(color: kGreyColor6),
//     hintStyle: kTextNormal1(color: kGreyColor6),
//     contentPadding: kPaddingSymmetric(h: 5, v: 2),
//
//     enabledBorder: outline(enabledBorderSide ?? BorderSide(color: kGreyColor7, width: 1.0)),
//     focusedBorder: outline(const BorderSide(color: kPrimaryColor, width: 1.5)),
//     errorBorder: outline(const BorderSide(color: Colors.red, width: 1.0)),
//     focusedErrorBorder: outline(const BorderSide(color: Colors.red, width: 1.5)),
//     disabledBorder: outline(BorderSide(color: Colors.grey.shade300, width: 1.0)),
//     border: outline(const BorderSide(width: 1.0)),
//   );
// }

// ThemeData textFieldThemeData({double? radius, Color? bgColor, BorderSide? enableBorderSide}) {
//   BorderRadius borderRadius = BorderRadius.circular(radius ?? 8.0);
//   return ThemeData(
//     primarySwatch: Colors.grey,
//     primaryColor: kPrimaryColor,
//     textTheme: appDefaultTextTheme,
//     inputDecorationTheme: InputDecorationTheme(
//       labelStyle: TextStyle(color: kGreyColor6),
//       hintStyle: TextStyle(color: kGreyColor6),
//       filled: true,
//       fillColor: bgColor ?? kWhiteColor,
//       enabledBorder: OutlineInputBorder(
//         borderSide: enableBorderSide ?? BorderSide(color: kGreyColor7, width: 1.5),
//         borderRadius: borderRadius,
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderSide: BorderSide(color: kPrimaryColor, width: 2.0),
//         borderRadius: borderRadius,
//       ),
//       border: OutlineInputBorder(borderRadius: borderRadius, borderSide: const BorderSide(width: 1.5)),
//       focusedErrorBorder: OutlineInputBorder(
//         borderRadius: borderRadius,
//         borderSide: const BorderSide(width: 2.0, color: kWarningColor),
//       ),
//       errorBorder: OutlineInputBorder(
//         borderRadius: borderRadius,
//         borderSide: const BorderSide(color: kWarningColor),
//       ),
//       disabledBorder: OutlineInputBorder(
//         borderRadius: borderRadius,
//         borderSide: BorderSide(width: 1.5, color: Colors.grey.shade600),
//       ),
//     ),
//   );
// }
