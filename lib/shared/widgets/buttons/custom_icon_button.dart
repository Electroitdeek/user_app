import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:flutter/material.dart';

class CustomIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Color? color;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final IconData iconData;
  final double? iconSize;
  final String? tooltip;

  const CustomIconButton({
    super.key,
    required this.onPressed,
    this.color,
    this.backgroundColor,
    this.margin,
    required this.iconData,
    this.iconSize,
    this.padding,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: IconButton(
        icon: Container(
          padding: padding ?? kPaddingAll(2),
          decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(12)),
          child: Icon(iconData, size: iconSize ?? kSize(5)),
        ),
        color: color,
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}
