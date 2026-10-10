import 'package:flutter/material.dart';

class MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String? badge;
  final Color? badgeColor;
  final Widget? trailing;
  final VoidCallback onTap;

  MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.badge,
    this.badgeColor,
    this.trailing,
    required this.onTap,
  });
}
