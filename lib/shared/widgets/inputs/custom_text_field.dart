import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/shared/widgets/inputs/common_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_input_theme.dart';
import '../../../core/theme/screen_dimensions.dart';
import '../../../core/utils/date_utils.dart';

/// 🎨 Modern Custom TextField with Responsive Design
///
/// Features:
/// - Responsive sizing using ScreenUtil
/// - Material 3 design
/// - Proper validation
/// - Auto-format support (phone, decimal, numeric)
/// - Accessible (screen readers, keyboard navigation)
class CustomTextField extends StatelessWidget {
  /// Text editing controller
  final TextEditingController? controller;

  /// Placeholder text
  final String? hintText;

  /// Label text shown above the field
  final String? labelText;

  /// Whether this field is required
  final bool isRequired;

  /// Obscure text (for passwords)
  final bool obscureText;

  /// Keyboard type
  final TextInputType? keyboardType;

  /// Focus node for this field
  final FocusNode? focusNode;

  /// Next field's focus node (for auto-navigation)
  final FocusNode? nextFocusNode;

  /// Text input action
  final TextInputAction? textInputAction;

  /// Custom validator function
  final FormFieldValidator<String>? validator;

  /// Custom validation error message (for required validator)
  final String? errorMessage;

  /// External error message shown below the field
  final String? errorText;

  /// Maximum length of input
  final int? maxLength;

  /// Maximum lines (1 for single line, >1 for multiline)
  final int maxLines;

  /// Minimum lines (for multiline)
  final int? minLines;

  /// Suffix icon widget
  final Widget? suffixIcon;

  /// Prefix icon widget
  final Widget? prefixIcon;

  /// Custom prefix widget (shown inside the field)
  final Widget? prefix;

  /// Prefix text (e.g., "+91" for phone)
  final String? prefixText;

  /// Input formatters
  final List<TextInputFormatter>? inputFormatters;

  /// Auto-format as number (digits only)
  final bool isNumeric;

  /// Auto-format as decimal (allows one decimal point)
  final bool isDecimal;

  /// Auto-capitalize sentences
  final bool capitalizeSentences;

  /// Capitalize all characters (uppercase every letter)
  final bool capitalizeAll;

  /// Text capitalization
  final TextCapitalization? textCapitalization;

  /// On tap callback
  final VoidCallback? onTap;

  /// On changed callback
  final ValueChanged<String>? onChanged;

  /// On field submitted callback
  final ValueChanged<String>? onFieldSubmitted;

  /// Whether field is enabled
  final bool enabled;

  /// Auto-focus on field
  final bool autofocus;

  /// Initial value (use instead of controller for simple cases)
  final String? initialValue;

  /// Background color
  final Color? backgroundColor;

  /// Border radius
  final double? borderRadius;

  /// Field height (default: 48.h)
  final double? height;

  /// Read-only mode (for date pickers, etc.)
  final bool readOnly;

  /// Show cursor
  final bool? showCursor;

  const CustomTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.isRequired = false,
    this.obscureText = false,
    this.keyboardType,
    this.focusNode,
    this.nextFocusNode,
    this.textInputAction,
    this.validator,
    this.errorMessage,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.suffixIcon,
    this.prefixIcon,
    this.prefixText,
    this.inputFormatters,
    this.isNumeric = false,
    this.isDecimal = false,
    this.capitalizeSentences = true,
    this.capitalizeAll = false,
    this.textCapitalization,
    this.onTap,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.initialValue,
    this.backgroundColor,
    this.borderRadius,
    this.height,
    this.readOnly = false,
    this.showCursor,
    this.prefix,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        if (labelText != null)
          CustomLabelForTextField(
            isRequired: isRequired,
            enabled: enabled,
            title: labelText!,
            borderRadius: borderRadius,
            // labelPadding: labelPadding,
            // labelTextColor: labelTextColor,
            // labelTextStyle: labelTextStyle,
          ),

        // Text field
        _buildTextField(context),
      ],
    );
  }

  /// Builds the label with required indicator
  // Widget _buildLabel() {
  //   return RichText(
  //     text: TextSpan(
  //       text: labelText,
  //       style: kTextMedium1().copyWith(color: enabled ? kBlackColor : kGreyColor6),
  //       children: [
  //         if (isRequired)
  //           TextSpan(
  //             text: ' *',
  //             style: kTextMedium1().copyWith(color: kErrorColor),
  //           ),
  //       ],
  //     ),
  //   );
  // }

  /// Builds the main text field
  Widget _buildTextField(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: AppInputTheme.standard(backgroundColor: backgroundColor, borderRadius: borderRadius),
      ),
      child: TextFormField(
        controller: controller,
        initialValue: initialValue,

        // Styling
        style: kTextNormal1().copyWith(color: enabled ? kBlackColor : kGreyColor7),

        // Behavior
        focusNode: readOnly ? AlwaysDisabledFocusNode() : focusNode,
        autofocus: autofocus,
        enabled: enabled,
        readOnly: readOnly,
        showCursor: showCursor,
        obscureText: obscureText,

        // Capitalization
        textCapitalization:
            textCapitalization ??
            (capitalizeAll
                ? TextCapitalization.characters
                : capitalizeSentences
                ? TextCapitalization.sentences
                : TextCapitalization.none),

        // Keyboard
        keyboardType: _getKeyboardType(),
        textInputAction: textInputAction ?? _getDefaultTextInputAction(),

        // Callbacks
        onTap: onTap,
        onChanged: onChanged,
        onFieldSubmitted: (value) {
          if (nextFocusNode != null) {
            FocusScope.of(context).requestFocus(nextFocusNode);
          }
          if (onFieldSubmitted != null) onFieldSubmitted!(value);
        },

        // Validation
        validator: _getValidator(),

        // Length
        maxLength: maxLength,
        maxLines: maxLines,
        minLines: minLines,

        // Input formatters
        inputFormatters: _getInputFormatters(),

        // Decoration
        decoration: InputDecoration(
          filled: true,
          fillColor: enabled ? (backgroundColor ?? kWhiteColor) : kGreyColor2.withValues(alpha: 0.3),

          // Padding
          contentPadding: AppPadding.symmetric(h: 16, v: maxLines > 1 ? 16 : 12),

          // Hint
          hintText: hintText ?? labelText,
          hintStyle: kTextNormal1().copyWith(color: kGreyColor6),
          errorText: errorText,

          // Icons
          prefixIcon: _buildPrefixIcon(),
          prefix: prefix,
          suffixIcon: _buildSuffixIcon(),

          // Counter
          counterText: '',

          // // Border styling
          // border: _buildBorder(kGreyColor4),
          // enabledBorder: _buildBorder(kGreyColor4),
          // focusedBorder: _buildBorder(kPrimaryColor, width: 2),
          // errorBorder: _buildBorder(kErrorColor),
          // focusedErrorBorder: _buildBorder(kErrorColor, width: 2),
          // disabledBorder: _buildBorder(kGreyColor3),

          // Error style
          errorStyle: kTextNormal0().copyWith(color: kErrorColor),
          // errorMaxLines: 2,
          // helperStyle: TextStyle(height: 0.01, fontSize: 0.01),
          // helperText: ' ', // Single space

          // Accessibility
          semanticCounterText: labelText,
        ),
      ),
    );
  }

  /// Builds prefix icon with proper spacing
  Widget? _buildPrefixIcon() {
    if (prefixIcon != null) {
      return prefixIcon;
    }

    if (prefixText != null) {
      return Padding(
        padding: AppPadding.only(left: 12, right: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Prefix text (e.g., "+91")
            Text(prefixText!, style: kTextMedium1().copyWith(color: kBlackColor)),

            AppSpacing.xsHorizontal,

            // Divider
            Container(height: 20.h, width: 1.5.w, color: kGreyColor4),

            AppSpacing.xsHorizontal,
          ],
        ),
      );
    }

    return null;
  }

  /// Builds suffix icon
  Widget? _buildSuffixIcon() {
    if (suffixIcon != null) {
      return suffixIcon;
    }
    return null;
  }

  /// Gets appropriate keyboard type
  TextInputType _getKeyboardType() {
    if (keyboardType != null) return keyboardType!;
    if (isNumeric || isDecimal) return TextInputType.number;
    if (maxLines > 1) return TextInputType.multiline;
    return TextInputType.text;
  }

  /// Gets default text input action
  TextInputAction _getDefaultTextInputAction() {
    if (nextFocusNode != null) return TextInputAction.next;
    if (maxLines > 1) return TextInputAction.newline;
    return TextInputAction.done;
  }

  /// Gets appropriate input formatters
  List<TextInputFormatter> _getInputFormatters() {
    if (inputFormatters != null) return inputFormatters!;

    final formatters = <TextInputFormatter>[];

    if (capitalizeAll) {
      formatters.add(_UpperCaseTextFormatter());
    }

    if (isNumeric) {
      formatters.add(FilteringTextInputFormatter.digitsOnly);
    }

    if (isDecimal) {
      formatters.add(FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')));
    }

    return formatters;
  }

  /// Gets appropriate validator
  FormFieldValidator<String>? _getValidator() {
    // Custom validator takes priority
    if (validator != null) return validator;

    // Auto-validator if required
    if (isRequired) {
      return (String? value) {
        if (value == null || value.trim().isEmpty) {
          return errorMessage ?? '${labelText ?? "This field"} is required';
        }
        return null;
      };
    }

    return null;
  }
}

/// Focus node that never gains focus (for read-only fields)
class AlwaysDisabledFocusNode extends FocusNode {
  @override
  bool get hasFocus => false;
}

/// Formatter that converts all input to uppercase characters.
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

// ═══════════════════════════════════════════════════════════════
// 🎯 SPECIALIZED TEXT FIELD VARIANTS
// ═══════════════════════════════════════════════════════════════

/// Phone number text field with country code prefix
class PhoneTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final bool isRequired;
  final String countryCode;
  final FormFieldValidator<String>? validator;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const PhoneTextField({
    super.key,
    this.controller,
    this.labelText = 'Phone Number',
    this.hintText,
    this.isRequired = false,
    this.countryCode = '+91',
    this.validator,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CommonTextField(
      controller: controller,
      labelText: labelText,
      isRequired: isRequired,
      hintText: hintText ?? 'Enter phone number',
      prefixText: countryCode,
      isNumeric: true,
      maxLength: 10,
      validator:
          validator ??
          (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return 'Phone number is required';
            }
            if (value != null && value.isNotEmpty && value.length != 10) {
              return 'Phone number must be 10 digits';
            }
            return null;
          },
      errorText: errorText,
      onChanged: onChanged,
    );
  }
}

/// Email text field with validation
class EmailTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final bool isRequired;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const EmailTextField({
    super.key,
    this.controller,
    this.labelText = 'Email',
    this.isRequired = false,
    this.enabled = true,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      labelText: labelText,
      isRequired: isRequired,
      enabled: enabled,
      hintText: 'example@email.com',
      keyboardType: TextInputType.emailAddress,
      // textCapitalization: TextCapitalization.words,
      prefixIcon: Icon(Icons.email_outlined, size: AppIconSize.s),
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'Email is required';
        }
        if (value != null && value.isNotEmpty) {
          final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
          if (!emailRegex.hasMatch(value)) {
            return 'Enter a valid email';
          }
        }
        return null;
      },
      errorText: errorText,
      onChanged: onChanged,
    );
  }
}

/// Password text field with visibility toggle
class PasswordTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final String? errorText;
  final String? labelText;
  final bool isRequired;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;

  const PasswordTextField({
    super.key,
    this.controller,
    this.labelText = 'Password',
    this.isRequired = true,
    this.validator,
    this.errorText,
    this.onChanged,
    this.focusNode,
    this.nextFocusNode,
  });

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: widget.controller,
      labelText: widget.labelText,
      isRequired: widget.isRequired,
      hintText: 'Enter password',
      obscureText: _obscureText,
      prefixIcon: Icon(Icons.lock_outline, size: AppIconSize.s),
      suffixIcon: IconButton(
        icon: Icon(_obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: AppIconSize.s),
        onPressed: () => setState(() => _obscureText = !_obscureText),
      ),
      focusNode: widget.focusNode,
      nextFocusNode: widget.nextFocusNode,
      validator: (value) {
        if (widget.isRequired && (value == null || value.isEmpty)) {
          return 'Password is required';
        }
        if (value != null && value.isNotEmpty && value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
      errorText: widget.errorText,
      onChanged: widget.onChanged,
    );
  }
}

/// Date picker text field
class DatePickerTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final bool isRequired;
  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? errorText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<DateTime>? onDateSelected;

  const DatePickerTextField({
    super.key,
    this.controller,
    this.labelText = 'Date',
    this.hintText,
    this.isRequired = false,
    this.initialDate,
    this.firstDate,
    this.lastDate,
    this.errorText,
    this.validator,
    this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      labelText: labelText,
      isRequired: isRequired,
      hintText: 'Select date',
      readOnly: true,
      errorText: errorText,
      validator: validator,
      suffixIcon: Icon(Icons.calendar_month, color: kPrimaryColor, size: AppIconSize.s),
      onTap: () => _selectDate(context),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    // Yield one frame so any in-progress navigator transitions finish before
    // we push the dialog — prevents the !_debugLocked assertion on Cancel.
    await Future.delayed(Duration.zero);
    if (!context.mounted) return;

    DateTime first = firstDate ?? DateTime(1900);
    DateTime last = lastDate ?? DateTime(2100);
    DateTime initial = initialDate ?? DateTime.now();

    // Ensure initialDate is within range to prevent crash
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kPrimaryColor,
              onPrimary: kWhiteColor,
              surface: kWhiteColor,
              onSurface: kTextPrimaryColor,
            ),
            textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: kPrimaryColor)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      controller?.text = AppDateFormatter.dateOnly(picked);
      if (onDateSelected != null) onDateSelected!(picked);
    }
  }
}

/// Multi-line text area
class TextAreaField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final bool isRequired;
  final int maxLines;
  final int? maxLength;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const TextAreaField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.isRequired = false,
    this.maxLines = 5,
    this.maxLength,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      labelText: labelText,
      hintText: hintText ?? 'Enter details...',
      isRequired: isRequired,
      maxLines: maxLines,
      maxLength: maxLength,
      capitalizeSentences: true,
      errorText: errorText,
      onChanged: onChanged,
    );
  }
}

//
// class CustomTextField extends StatelessWidget {
//   final TextEditingController? controller;
//   final String hintText;
//   final String? labelText;
//   final bool obscureText;
//   final TextInputType? keyboardType;
//   final FocusNode? focusNode;
//   final FocusNode? focusNodeNext;
//   final TextInputAction? textInputAction;
//   final FormFieldValidator<String>? validator;
//   final int? maxLength;
//   final bool passwordVisible;
//   final Widget? suffixIcon;
//   final Widget? prefixIcon;
//   final IconData? prefixIconData;
//   final String? prefixText;
//   final ValueChanged<String>? onFieldSubmitted;
//   final bool isMandatory;
//   final int maxLines;
//   final int? minLines;
//   final List<TextInputFormatter>? inputFormatters;
//   final bool? enableInteractiveSelection;
//   final bool isNumeric;
//   final bool isDecimal;
//   final GestureTapCallback? onTap;
//   final ValueChanged<String>? onChanged;
//   final bool? enabled;
//   final bool autofocus;
//   final bool? showCursor;
//   final double? borderRadius;
//   final String? initialValue;
//   final String? validatorMsg;
//   final Color? bgColor;
//   final BorderSide? borderSide;
//   final bool disableFocusNode;
//   final bool isSentence;
//   final EdgeInsetsGeometry? labelPadding;
//   final bool isDatePicker;
//   final Color? labelTextColor;
//   final TextStyle? labelTextStyle;
//
//   const CustomTextField({
//     super.key,
//     required this.controller,
//     this.hintText = '',
//     this.labelText,
//     this.keyboardType,
//     this.focusNode,
//     this.focusNodeNext,
//     this.validator,
//     this.maxLength,
//     this.suffixIcon,
//     this.prefixIcon,
//     this.prefixText,
//     this.prefixIconData,
//     this.textInputAction,
//     this.obscureText = false,
//     this.passwordVisible = false,
//     this.onFieldSubmitted,
//     this.isMandatory = false,
//     this.maxLines = 1,
//     this.inputFormatters,
//     this.enableInteractiveSelection,
//     this.onTap,
//     this.isNumeric = false,
//     this.isDecimal = false,
//     this.onChanged,
//     this.enabled,
//     this.initialValue,
//     this.borderRadius,
//     this.validatorMsg,
//     this.showCursor,
//     this.minLines,
//     this.bgColor,
//     this.borderSide,
//     this.autofocus = false,
//     this.disableFocusNode = false,
//     this.isSentence = true, // Default to true for better UX in health notes
//     this.labelPadding,
//     this.isDatePicker = false,
//     this.labelTextColor,
//     this.labelTextStyle,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         if (labelText != null)
//           CustomLabelForTextField(
//             isMandatory: isMandatory,
//             title: labelText!,
//             borderRadius: getBorderRadius,
//             labelPadding: labelPadding,
//             labelTextColor: labelTextColor,
//             labelTextStyle: labelTextStyle,
//           ),
//         _buildTextField(context),
//       ],
//     );
//   }
//
//   double get getBorderRadius => borderRadius ?? 16;
//
//   Color get getTextColor {
//     if (enabled == false) {
//       return kGreyColor7;
//     } else {
//       return kBlackColor;
//     }
//   }
//
//   Widget _buildTextField(BuildContext context) {
//     return SizedBox(
//       height: AppButtonHeight.m,
//       child: Theme(
//         data: Theme.of(context).copyWith(
//           inputDecorationTheme: appInputDecorationTheme(
//             radius: getBorderRadius,
//             backgroundColor: bgColor ?? Colors.grey.shade50,
//           ),
//         ),
//         child: TextFormField(
//           controller: controller,
//           style: kTextMedium1(color: getTextColor),
//           focusNode: (disableFocusNode || isDatePicker) ? AlwaysDisabledFocusNode() : focusNode,
//           autofocus: autofocus,
//           obscureText: obscureText,
//           textCapitalization: isSentence ? TextCapitalization.sentences : TextCapitalization.none,
//           keyboardType: _keyBoardType,
//           textInputAction: textInputAction ?? (focusNodeNext != null ? TextInputAction.next : TextInputAction.done),
//           onFieldSubmitted: (value) {
//             if (focusNodeNext != null) {
//               FocusScope.of(context).requestFocus(focusNodeNext);
//             }
//             if (onFieldSubmitted != null) onFieldSubmitted!(value);
//           },
//           maxLength: maxLength ?? (isNumeric ? 10 : null),
//           validator: isMandatory && validator == null ? _validateIsNotEmpty : validator,
//           maxLines: maxLines,
//           minLines: minLines,
//           onChanged: onChanged,
//           enabled: enabled,
//           showCursor: showCursor,
//           inputFormatters:
//               inputFormatters ??
//               [
//                 if (isNumeric) FilteringTextInputFormatter.digitsOnly,
//                 if (isDecimal) FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
//               ],
//           enableInteractiveSelection: (disableFocusNode || isDatePicker) ? false : enableInteractiveSelection,
//           onTap: onTap,
//           initialValue: initialValue,
//           decoration: InputDecoration(
//             filled: true,
//             fillColor: bgColor ?? Colors.grey.shade50,
//             counterText: '',
//             suffixIcon: _getSuffixIcon,
//             // prefixText: prefixText,
//             // floatingLabelBehavior: FloatingLabelBehavior.always,
//             // prefixStyle: kTextBold1(color: kBlackColor),
//             prefixIcon: _getPrefixIcon,
//             hintText: hintText.isEmpty ? labelText : hintText,
//             hintStyle: kTextNormal1(color: kGreyColor6),
//             // Adding specific border styles for a "Top-Notch" look
//             // focusedErrorBorder: OutlineInputBorder(
//             //   borderRadius: AppRadius.circular(getBorderRadius),
//             //   borderSide: const BorderSide(color: Colors.orange, width: 1.5),
//             // ),
//             // border: OutlineInputBorder(
//             //   borderRadius: AppRadius.circular(getBorderRadius),
//             //   borderSide: borderSide ?? BorderSide.none,
//             // ),
//             // enabledBorder: OutlineInputBorder(
//             //   borderRadius: AppRadius.circular(getBorderRadius),
//             //   borderSide: borderSide ?? const BorderSide(color: kTextPrimaryColor, width: 1.5),
//             // ),
//             // focusedBorder: OutlineInputBorder(
//             //   borderRadius: AppRadius.circular(getBorderRadius),
//             //   borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
//             // ),
//             // disabledBorder: OutlineInputBorder(
//             //   borderRadius: AppRadius.circular(getBorderRadius),
//             //   borderSide: BorderSide(color: kGreyColor5, width: 1.5),
//             // ),
//             // errorBorder: OutlineInputBorder(
//             //   borderRadius: AppRadius.circular(getBorderRadius),
//             //   borderSide: const BorderSide(color: Colors.red, width: 1),
//             // ),
//             contentPadding: kPaddingSymmetric(h: 8, v: maxLines > 1 ? 16 : 8),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget? get _getPrefixIcon {
//     if (prefixIcon != null) {
//       return prefixIcon;
//     } else if (prefixIconData != null || prefixText != null) {
//       return Padding(
//         padding: kPaddingOnly(left: 12), // Spacing from the left border
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             if (prefixIconData != null) ...[
//               Icon(prefixIconData, color: kPrimaryColor, size: AppIconSize.s),
//               AppSpacing.sHorizontal,
//             ],
//             if (prefixText != null) ...[
//               // The permanent +91
//               Text(prefixText!, style: kTextMedium1(color: kBlackColor)),
//               AppSpacing.sHorizontal, // The "gap" you wanted on the right
//               // Vertical divider for a professional look
//               Container(height: kSize(16), width: 1.w, color: kGreyColor7),
//               AppSpacing.sHorizontal,
//             ],
//           ],
//         ),
//       );
//     }
//     return null;
//   }
//
//   Widget? get _getSuffixIcon {
//     if (suffixIcon != null) {
//       return suffixIcon;
//     } else if (isDatePicker) {
//       return Icon(
//         Icons.calendar_month_rounded,
//         color: enabled == false ? kGreyColor6 : kPrimaryColor,
//         size: AppIconSize.s,
//       );
//     } else {
//       return null;
//     }
//   }
//
//   TextInputType get _keyBoardType {
//     if (keyboardType != null) return keyboardType!;
//     if (isNumeric || isDecimal) return TextInputType.number;
//     if (maxLines > 1) return TextInputType.multiline;
//     return TextInputType.text;
//   }
//
//   String? _validateIsNotEmpty(String? value) {
//     if (value == null || value.trim().isEmpty) {
//       return validatorMsg ?? "This field is required";
//     }
//     return null;
//   }
// }
//
class CustomLabelForTextField extends StatelessWidget {
  final String title;
  final bool isRequired;
  final bool enabled;
  final double? borderRadius;
  final EdgeInsetsGeometry? labelPadding;
  final Color? labelTextColor;
  final TextStyle? labelTextStyle;

  const CustomLabelForTextField({
    super.key,
    required this.title,
    required this.isRequired,
    this.borderRadius,
    this.labelPadding,
    this.labelTextColor,
    this.labelTextStyle,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          labelPadding ??
          kPaddingOnly(bottom: 6, top: 12, left: borderRadius != null ? (borderRadius! > 20 ? 8 : 4) : 4),
      child: RichText(
        text: TextSpan(
          text: title,
          style: labelTextStyle ?? kTextMedium1(color: labelTextColor ?? (enabled ? kBlackColor : kGreyColor6)),
          children: [
            if (isRequired)
              TextSpan(
                text: ' *',
                style: kTextMedium1().copyWith(color: kErrorColor),
              ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    // return Padding(
    //   padding:
    //       labelPadding ??
    //       kPaddingOnly(bottom: 6, top: 12, left: borderRadius != null ? (borderRadius! > 20 ? 8 : 4) : 4),
    //   child: RichText(
    //     text: TextSpan(
    //       text: title,
    //       children: [
    //         TextSpan(
    //           text: isMandatory ? ' *' : '',
    //           style: TextStyle(color: Colors.red.shade700),
    //         ),
    //       ],
    //       style: labelTextStyle ?? kTextSemiBold(color: labelTextColor ?? kGreyColor8),
    //     ),
    //     maxLines: 1,
    //     overflow: TextOverflow.ellipsis,
    //   ),
    // );
  }
}

// class AlwaysDisabledFocusNode extends FocusNode {
//   @override
//   bool get hasFocus => false;
// }
