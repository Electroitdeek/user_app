import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class CustomTextButton extends StatelessWidget {
  final String title;
  final VoidCallback? onPressed;
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final bool isLoading;
  final IconData? icon;
  final MainAxisAlignment alignment;

  const CustomTextButton({
    super.key,
    required this.title,
    required this.onPressed,
    this.color,
    this.fontSize,
    this.fontWeight,
    this.isLoading = false,
    this.icon,
    this.alignment = MainAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: color ?? kPrimaryColor, // Default to your theme primary
      ),
      child: isLoading
          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: alignment,
              children: [
                if (icon != null) ...[Icon(icon, size: (fontSize ?? 14) + 2), const SizedBox(width: 4)],
                Text(
                  title,
                  style: kTextSemiBold().copyWith(
                    color: onPressed == null ? kGreyColor7 : (color ?? kPrimaryColor),
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                  ),
                ),
              ],
            ),
    );
  }
}
