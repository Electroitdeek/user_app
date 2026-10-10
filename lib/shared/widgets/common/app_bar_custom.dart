import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final bool centerTitle;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Color? titleColor;
  final double elevation;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.onBack,
    this.actions,
    this.backgroundColor,
    this.titleColor,
    this.centerTitle = false,
    this.elevation = 0,
    this.leading,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: elevation,
      backgroundColor: backgroundColor ?? kWhiteColor,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      automaticallyImplyLeading: false,

      // ---------- LEADING ----------
      leading: showBack
          ? leading ?? IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: onBack ?? () => Navigator.pop(context))
          : null,

      // ---------- TITLE ----------
      title: Text(title, style: kTextSemiBold3(color: titleColor ?? Colors.black)),

      // ---------- ACTIONS ----------
      actions: actions,

      // ---------- BOTTOM ----------
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));
}
