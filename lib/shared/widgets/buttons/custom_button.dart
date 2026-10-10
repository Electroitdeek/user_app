import 'package:adhisaat_health_care/core/theme/screen_dimensions.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_edge_insets.dart';
import '../../../core/theme/app_text_styles.dart';

class CustomButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final dynamic title;
  final TextStyle? textStyle;
  final Color? backgroundColor;
  final Color? textColor;
  final dynamic iconData;
  final double? iconSize;
  final double? height;
  final double? width;
  final Color? iconColor;
  final Color? overlayColor;
  final Color? shadowColor;
  final bool isIconRight;
  final bool isLoading;
  final BorderRadius? borderRadius;
  final EdgeInsets? innerPadding;
  final double? iconSpace;
  final BorderSide? borderSide;
  final TextScaler? textScaler;
  final bool showIndicator;
  final bool isEnable;
  final Color? buttonTheme1;

  const CustomButton({
    super.key,
    required this.onPressed,
    required this.title,
    this.textStyle,
    this.backgroundColor,
    this.textColor,
    this.iconData,
    this.iconSize,
    this.iconColor,
    this.isIconRight = false,
    this.isLoading = false,
    this.height,
    this.width,
    this.borderRadius,
    this.shadowColor,
    this.innerPadding,
    this.iconSpace,
    this.overlayColor,
    this.borderSide,
    this.textScaler,
    this.showIndicator = false,
    this.isEnable = true,
    this.buttonTheme1,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = SizedBox(
      height: getHeight,
      width: width,
      child: iconData != null ? getTextIconButton : getTextButton,
    );
    if (showIndicator) {
      button = Stack(
        alignment: const Alignment(0.8, -0.5),
        children: [
          button,
          Container(
            width: AppSpacing.sValue,
            height: AppSpacing.sValue,
            decoration: BoxDecoration(color: Colors.red.shade500, shape: BoxShape.circle),
          ),
        ],
      );
    }
    return button;
  }

  Widget get getTextButton {
    return TextButton(
      style: getButtonStyle,
      onPressed: getOnPressed,
      child: isLoading ? getLoading : getLabel,
    );
  }

  VoidCallback? get getOnPressed {
    if (isLoading) {
      return null;
    }
    if (isEnable) {
      return onPressed;
    }
    return null;
  }

  Widget get getTextIconButton {
    return Directionality(
      textDirection: isIconRight ? TextDirection.rtl : TextDirection.ltr,
      child: TextButton(
        style: getButtonStyle,
        onPressed: getOnPressed,
        // icon: isLoading ? getLoading : getIcon,
        child: isLoading
            ? getLoading
            : Row(
                mainAxisSize: MainAxisSize.min,
                // Ensures the button shrinks to fit its content
                children: [
                  getIcon,
                  kSizedBox(width: iconSpace ?? 4),
                  Flexible(child: getLabel),
                ],
              ),
      ),
    );
  }

  Widget get getIcon {
    return Directionality(
      textDirection: isIconRight ? TextDirection.ltr : TextDirection.ltr,
      child: iconData is IconData
          ? Icon(iconData, color: getIconColor ?? kWhiteColor, size: iconSize ?? AppIconSize.xs)
          : Image.asset(
              iconData,
              color: getIconColor,
              width: iconSize ?? AppIconSize.xs,
              height: iconSize ?? AppIconSize.xs,
            ),
    );
  }

  double? get getHeight {
    if (height != null) {
      return height;
    }
    if (buttonTheme1 != null) {
      return AppButtonHeight.xs;
    }
    return AppButtonHeight.s;
  }

  Widget get getLoading {
    if (isLoading) {
      return Padding(
        padding: AppPadding.sHorizontal,
        child: kSizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(color: borderSide?.color ?? kWhiteColor, strokeWidth: 3),
        ),
      );
    } else {
      return const SizedBox();
    }
  }

  ButtonStyle get getButtonStyle {
    return ButtonStyle(
      shadowColor: shadowColor != null ? WidgetStatePropertyAll(shadowColor) : null,
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: borderRadius ?? AppRadius.s)),
      padding: WidgetStatePropertyAll(innerPadding ?? AppPadding.mHorizontal),
      minimumSize: const WidgetStatePropertyAll(Size.zero),
      side: WidgetStatePropertyAll(getBorderSide),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      overlayColor: WidgetStatePropertyAll(overlayColor),
      backgroundColor: WidgetStatePropertyAll(getBackgroundColor ?? kPrimaryColor),
    );
  }

  Color? get getIconColor {
    return iconColor ?? buttonTheme1;
  }

  Color? get getBackgroundColor {
    return backgroundColor ?? buttonTheme1?.withValues(alpha: 0.1) ?? (!isEnable ? kDisableButtonColor : null);
  }

  BorderSide? get getBorderSide {
    return borderSide ?? (buttonTheme1 != null ? BorderSide(color: buttonTheme1!.withValues(alpha: 0.3)) : null);
  }

  TextStyle get getTextStyle {
    if (textStyle != null) {
      return textStyle!;
    } else if (buttonTheme1 != null) {
      return kTextMedium0(color: buttonTheme1);
    } else {
      return kTextBold1(color: textColor ?? iconColor ?? kWhiteColor);
    }
  }

  Widget get getLabel {
    if (title is Widget) {
      return title;
    }
    return Text(
      title ?? '',
      overflow: TextOverflow.ellipsis,
      textDirection: TextDirection.ltr,
      style: getTextStyle,
      textScaler: textScaler,
    );
  }
}
