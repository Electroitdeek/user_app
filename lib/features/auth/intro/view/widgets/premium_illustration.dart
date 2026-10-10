import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PremiumIllustration extends StatelessWidget {
  final IconData mainIcon;
  final Color baseColor;
  final List<IconData> bubbleIcons;

  const PremiumIllustration({
    super.key,
    required this.mainIcon,
    required this.baseColor,
    required this.bubbleIcons,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Background Decorative Circles
        _buildDecorativeCircle(260.w, 260.w, baseColor.withValues(alpha: 0.1)),
        _buildDecorativeCircle(220.w, 220.w, baseColor.withValues(alpha: 0.15)),

        // Main Icon Container
        Center(
          child: Container(
            width: 180.w,
            height: 180.w,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              mainIcon,
              size: 85.sp,
              color: baseColor,
            ),
          ),
        ),

        // Floating Bubble Icons
        if (bubbleIcons.isNotEmpty)
          Positioned(
            top: 40.h,
            right: 15.w,
            child: _buildBubble(bubbleIcons[0], 0),
          ),
        if (bubbleIcons.length > 1)
          Positioned(
            bottom: 50.h,
            left: 20.w,
            child: _buildBubble(bubbleIcons[1], 1),
          ),
        if (bubbleIcons.length > 2)
          Positioned(
            top: 70.h,
            left: 10.w,
            child: _buildBubble(bubbleIcons[2], 2),
          ),
      ],
    );
  }

  Widget _buildDecorativeCircle(double width, double height, Color color) {
    return Center(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildBubble(IconData icon, int index) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 1000 + (index * 250)),
      curve: Curves.elasticOut,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 55.w,
            height: 55.w,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: baseColor, size: 26.sp),
          ),
        );
      },
    );
  }
}
