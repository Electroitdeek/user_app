import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class CustomRefreshIndicator extends StatelessWidget {
  final RefreshCallback onRefresh;
  final Widget child;

  const CustomRefreshIndicator({super.key, required this.onRefresh, required this.child});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      displacement: 10,
      backgroundColor: kPrimaryColor,
      color: Colors.white,
      strokeWidth: 3,
      triggerMode: RefreshIndicatorTriggerMode.onEdge,
      onRefresh: onRefresh,
      child: Stack(
        children: [
          ListView(),
          child,
        ],
      ),
    );
  }
}
