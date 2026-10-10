import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/utils/validators.dart';

/// 🎯 Premium Common Inputs for the entire application (User & Provider side)
///
/// Use these widgets to ensure consistent, high-quality UI across all forms.

class CommonSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final VoidCallback? ontap;
  final bool autofocus;
  final bool readOnly;
  final FocusNode? focusNode;

  const CommonSearchField({
    super.key,
    this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.readOnly = false,
    this.ontap,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: TextField(
        readOnly: readOnly,
        onTap: ontap,
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        autofocus: autofocus,
        style: kTextMedium(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: kTextNormal(color: kTextHintColor).copyWith(fontSize: 14.sp),
          prefixIcon: Icon(Icons.search_rounded, color: kPrimaryColor, size: 20.sp),
          suffixIcon: onClear != null || (controller?.text.isNotEmpty ?? false)
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: kTextHintColor, size: 20.sp),
                  onPressed: onClear ?? () => controller?.clear(),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: kBorderColor.withValues(alpha: 0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: kBorderColor.withValues(alpha: 0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: kPrimaryColor.withValues(alpha: 0.5)),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
        ),
      ),
    );
  }
}

class CommonTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final bool isRequired;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final bool enabled;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final String? prefixText;
  final bool isNumeric;
  final bool isDecimal;
  final bool capitalizeAll;
  final bool capitalizeSentences;
  final TextCapitalization? textCapitalization;
  final VoidCallback? onTap;
  final bool autofocus;
  final bool? showCursor;
  final Widget? prefix;
  final String? initialValue;
  final ValueChanged<String>? onFieldSubmitted;
  final FocusNode? nextFocusNode;
  final String? errorText;
  final int? maxLength;
  final bool readOnly;
  final int? minLines;

  const CommonTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.isRequired = false,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
    this.focusNode,
    this.textInputAction,
    this.errorText,
    this.maxLength,
    this.readOnly = false,
    this.minLines,
    this.prefixText,
    this.isNumeric = false,
    this.isDecimal = false,
    this.capitalizeAll = false,
    this.capitalizeSentences = true,
    this.textCapitalization,
    this.onTap,
    this.autofocus = false,
    this.showCursor,
    this.prefix,
    this.initialValue,
    this.onFieldSubmitted,
    this.nextFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labelText != null) SizedBox(height: 12.h),
        if (labelText != null) ...[
          Row(
            children: [
              Text(
                labelText!,
                style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
              ),
              if (isRequired)
                Text(
                  " *",
                  style: kTextBold(color: Colors.red).copyWith(fontSize: 14.sp),
                ),
            ],
          ),
          SizedBox(height: 8.h),
        ],
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          obscureText: obscureText,
          keyboardType: _getKeyboardType(),
          inputFormatters: _getInputFormatters(),
          validator: validator ?? (isRequired ? Validators.validateIsNoEmpty : null),
          onChanged: onChanged,
          onFieldSubmitted: (value) {
            if (nextFocusNode != null) {
              FocusScope.of(context).requestFocus(nextFocusNode);
            }
            if (onFieldSubmitted != null) onFieldSubmitted!(value);
          },
          maxLines: maxLines,
          minLines: minLines,
          maxLength: maxLength,
          enabled: enabled,
          readOnly: readOnly,
          focusNode: focusNode,
          autofocus: autofocus,
          showCursor: showCursor,
          onTap: onTap,
          textCapitalization:
              textCapitalization ??
              (capitalizeAll
                  ? TextCapitalization.characters
                  : capitalizeSentences
                  ? TextCapitalization.sentences
                  : TextCapitalization.none),
          textInputAction: textInputAction ?? (nextFocusNode != null ? TextInputAction.next : null),
          style: kTextMedium(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
          decoration: InputDecoration(
            hintText: hintText ?? labelText,
            hintStyle: kTextNormal(color: kTextHintColor).copyWith(fontSize: 14.sp),
            prefixIcon: _buildPrefixIcon(),
            prefix: prefix,
            suffixIcon: suffixIcon,
            errorText: errorText,
            errorStyle: kTextNormal(color: Colors.red).copyWith(fontSize: 12.sp),
            counterText: "",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(color: kGreyColor4.withValues(alpha: 0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(color: kGreyColor4.withValues(alpha: 0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(color: kGreyColor4.withValues(alpha: 0.2)),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          ),
        ),
      ],
    );
  }

  Widget? _buildPrefixIcon() {
    if (prefixIcon != null) return prefixIcon;
    if (prefixText != null) {
      return Padding(
        padding: EdgeInsets.only(left: 12.w, right: 8.w),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              prefixText!,
              style: kTextMedium(color: kBlackColor).copyWith(fontSize: 14.sp),
            ),
            SizedBox(width: 8.w),
            Container(height: 20.h, width: 1.w, color: kGreyColor4),
          ],
        ),
      );
    }
    return null;
  }

  TextInputType _getKeyboardType() {
    if (keyboardType != null) return keyboardType!;
    if (isNumeric || isDecimal) return TextInputType.number;
    if (maxLines > 1) return TextInputType.multiline;
    return TextInputType.text;
  }

  List<TextInputFormatter> _getInputFormatters() {
    if (inputFormatters != null) return inputFormatters!;
    final formatters = <TextInputFormatter>[];
    if (isNumeric) formatters.add(FilteringTextInputFormatter.digitsOnly);
    if (isDecimal) formatters.add(FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')));
    return formatters;
  }
}

class CommonDecoration {
  static BoxDecoration searchField({double? radius}) => BoxDecoration(
    color: kWhiteColor,
    borderRadius: BorderRadius.circular(radius ?? 16.r),
    border: Border.all(color: kGreyColor4.withValues(alpha: 0.5)),
    boxShadow: [
      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
    ],
  );

  static InputDecoration searchInput({String? hintText}) => InputDecoration(
    hintText: hintText ?? "Search...",
    hintStyle: kTextNormal(color: kTextHintColor).copyWith(fontSize: 14.sp),
    prefixIcon: Icon(Icons.search_rounded, color: kTextHintColor, size: 22.sp),
    border: InputBorder.none,
    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
  );
}
