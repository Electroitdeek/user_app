import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_edge_insets.dart';
import '../../../core/theme/app_input_theme.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/screen_dimensions.dart';
import 'custom_text_field.dart';

class CustomDropDown<T> extends StatelessWidget {
  /// Label text shown above the dropdown
  final String? labelText;

  /// Placeholder text when no value is selected
  final String? hintText;

  /// Callback when selection changes
  final ValueChanged<T?>? onChanged;

  /// Whether this field is required
  final bool isRequired;

  /// Custom validator function
  final FormFieldValidator<T>? validator;

  /// Currently selected value
  final T? value;

  /// List of dropdown items
  final List<DropdownMenuItem<T>>? items;

  /// Custom validation error message
  final String? errorMessage;

  /// Dropdown height (default: 48.h)
  final double? height;

  /// Border radius (default: 12.r)
  final double? borderRadius;

  /// Maximum height of dropdown menu
  final double? dropdownMaxHeight;

  /// Background color
  final Color? backgroundColor;

  /// Border color
  final Color? borderColor;

  /// Whether dropdown is enabled
  final bool enabled;

  /// Prefix icon
  final Widget? prefixIcon;

  /// Custom dropdown icon
  final Widget? suffixIcon;
  final EdgeInsets? labelPadding;
  final Color? labelTextColor;
  final TextStyle? labelTextStyle;
  final String? errorText;

  const CustomDropDown({
    super.key,
    this.labelText,
    this.hintText,
    this.onChanged,
    this.validator,
    this.value,
    this.items,
    this.isRequired = false,
    this.errorMessage,
    this.height,
    this.borderRadius,
    this.dropdownMaxHeight,
    this.backgroundColor,
    this.borderColor,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
    this.labelPadding,
    this.labelTextColor,
    this.labelTextStyle,
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
            title: labelText!,
            borderRadius: borderRadius,
            enabled: enabled,
            labelPadding: labelPadding,
            labelTextColor: labelTextColor,
            labelTextStyle: labelTextStyle,
          ),

        // Dropdown
        _buildDropdown(context),
      ],
    );
  }

  /// Builds the main dropdown
  Widget _buildDropdown(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: AppInputTheme.standard(backgroundColor: backgroundColor, borderRadius: borderRadius),
      ),
      child: DropdownButtonFormField2<T>(
        isExpanded: true,
        isDense: true,

        // Styling
        style: kTextNormal1().copyWith(color: enabled ? kBlackColor : kGreyColor7),

        // Decoration
        decoration: InputDecoration(
          filled: true,
          fillColor: enabled ? (backgroundColor ?? kWhiteColor) : kGreyColor2.withValues(alpha: 0.3),

          // Content padding: Zero because buttonStyleData handles the height
          contentPadding: EdgeInsets.zero,

          // Prefix icon
          prefixIcon: prefixIcon,

          // Border styling
          border: _buildBorder(kGreyColor4),
          enabledBorder: _buildBorder(borderColor ?? kGreyColor4),
          focusedBorder: _buildBorder(kPrimaryColor),
          errorBorder: _buildBorder(kErrorColor),
          focusedErrorBorder: _buildBorder(kErrorColor),
          disabledBorder: _buildBorder(kGreyColor3),

          // Error style
          errorStyle: kTextNormal0().copyWith(color: kErrorColor),
          errorText: errorText,

          // Accessibility
          semanticCounterText: labelText,
        ),

        // Hint
        hint: Text(hintText ?? 'Select', style: kTextNormal1().copyWith(color: kGreyColor6)),

        // Items
        items: items,
        value: _getSafeValue(),

        // Validation
        validator: _getValidator(),

        // Callbacks
        onChanged: enabled ? onChanged : null,

        // Button style
        buttonStyleData: ButtonStyleData(
          height: height ?? AppButtonHeight.m,
          padding: EdgeInsets.only(right: 8.w),
        ),

        // Icon style
        iconStyleData: IconStyleData(
          icon: suffixIcon ?? Icon(Icons.keyboard_arrow_down_rounded, color: enabled ? kGreyColor6 : kGreyColor4),
          iconSize: 24.sp,
        ),

        // Dropdown menu style
        dropdownStyleData: DropdownStyleData(
          maxHeight: dropdownMaxHeight ?? ScreenDimensions.halfHeight,
          offset: const Offset(0, -4),
          elevation: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular((borderRadius ?? 12).r),
            color: kWhiteColor,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: Offset(0, 4.h)),
            ],
          ),
          scrollbarTheme: ScrollbarThemeData(
            radius: Radius.circular(40.r),
            thickness: WidgetStateProperty.all(6.w),
            thumbVisibility: WidgetStateProperty.all(true),
            thumbColor: WidgetStateProperty.all(kGreyColor4),
          ),
        ),

        // Menu item style
        menuItemStyleData: MenuItemStyleData(height: AppButtonHeight.m, padding: AppPadding.mHorizontal),
      ),
    );
  }

  /// Builds border with consistent styling
  OutlineInputBorder _buildBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular((borderRadius ?? 12).r),
      borderSide: BorderSide(color: color, width: 1.5.w),
    );
  }

  /// Ensures selected value exists in items list
  T? _getSafeValue() {
    if (items == null || items!.isEmpty || value == null) return null;

    final bool valueExists = items!.any((item) => item.value == value);
    return valueExists ? value : null;
  }

  /// Gets appropriate validator
  FormFieldValidator<T>? _getValidator() {
    // Custom validator takes priority
    if (validator != null) return validator;

    // Auto-validator if required
    if (isRequired) {
      return (T? value) {
        if (value == null) {
          return errorMessage ?? 'Please select ${labelText?.toLowerCase() ?? 'an option'}';
        }
        return null;
      };
    }

    return null;
  }
}

// ═══════════════════════════════════════════════════════════════
// 🎯 HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════

/// Converts Map to DropdownMenuItem list
///
/// Example:
/// ```dart
/// final genderMap = {'M': 'Male', 'F': 'Female', 'O': 'Other'};
/// final items = mapToDropdownItems(genderMap);
/// ```
List<DropdownMenuItem<String>> mapToDropdownItems(Map<String, String> data, {TextStyle? textStyle}) {
  return data.entries.map((entry) {
    return DropdownMenuItem<String>(
      value: entry.key, // API value (e.g., "M")
      child: Text(
        entry.value, // Display value (e.g., "Male")
        style: textStyle ?? kTextNormal1(),
      ),
    );
  }).toList();
}

/// Converts List of objects to DropdownMenuItem
///
/// Example:
/// ```dart
/// final cities = [City(id: '1', name: 'Delhi'), City(id: '2', name: 'Mumbai')];
/// final items = listToDropdownItems(
///   cities,
///   valueGetter: (city) => city.id,
///   displayGetter: (city) => city.name,
/// );
/// ```
List<DropdownMenuItem<T>> listToDropdownItems<T, V>(
  List<V> data, {
  required T Function(V) valueGetter,
  required String Function(V) displayGetter,
  TextStyle? textStyle,
}) {
  return data.map((item) {
    return DropdownMenuItem<T>(
      value: valueGetter(item),
      child: Text(displayGetter(item), style: textStyle ?? kTextNormal1()),
    );
  }).toList();
}

/// Creates simple string dropdown items
///
/// Example:
/// ```dart
/// final shifts = ['Day Shift', 'Night Shift', '24 Hours'];
/// final items = stringToDropdownItems(shifts);
/// ```
List<DropdownMenuItem<String>> stringToDropdownItems(List<String> values, {TextStyle? textStyle}) {
  return values.map((value) {
    return DropdownMenuItem<String>(
      value: value,
      child: Text(value, style: textStyle ?? kTextNormal1()),
    );
  }).toList();
}

// ═══════════════════════════════════════════════════════════════
// 🎨 COMMON DROPDOWN VARIANTS
// ═══════════════════════════════════════════════════════════════

/// Searchable dropdown (requires dropdown_search package)
class SearchableDropdown<T> extends StatelessWidget {
  final String? labelText;
  final String? hintText;
  final List<T> items;
  final T? selectedItem;
  final ValueChanged<T?>? onChanged;
  final String Function(T) itemAsString;
  final bool isRequired;

  const SearchableDropdown({
    super.key,
    this.labelText,
    this.hintText,
    required this.items,
    this.selectedItem,
    this.onChanged,
    required this.itemAsString,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    // Implementation with dropdown_search package
    // This is a placeholder - implement based on your needs
    return CustomDropDown<T>(
      labelText: labelText,
      hintText: hintText,
      isRequired: isRequired,
      // Add search functionality
    );
  }
}
