import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NoServiceView extends StatelessWidget {
  final String? city;
  final String? zipCode;
  final String? title;
  final String? description;
  final String? actionLabel;
  final String? badgeLabel;
  final IconData? badgeIcon;
  final VoidCallback onChangeLocation;

  const NoServiceView({
    super.key,
    this.city,
    this.zipCode,
    this.title,
    this.description,
    this.actionLabel,
    this.badgeLabel,
    this.badgeIcon,
    required this.onChangeLocation,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasLocation = city != null || zipCode != null;
    final String locationDisplay;
    if (city != null && zipCode != null) {
      locationDisplay = '$city ($zipCode)';
    } else if (city != null) {
      locationDisplay = city!;
    } else if (zipCode != null) {
      locationDisplay = zipCode!;
    } else {
      locationDisplay = 'your area';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24.r),
      child: Stack(
        children: [
          // 1. Realistic Map background
          Positioned.fill(
            child: CustomPaint(
              painter: _MapRoutePainter(
                color: const Color(0xFFE8EAED).withValues(alpha: 0.6),
                accentColor: kPrimaryColor,
              ),
            ),
          ),
          // 2. Soft Gradient Overlay for text legibility
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.85),
                    Colors.white.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),
          // 3. Foreground Content
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 34.h),
            child: Column(
              // mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 'Coming Soon' Badge — only relevant once we know which area is unserved
                if (hasLocation) ...[
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          badgeIcon ?? Icons.location_off_rounded,
                          size: 13.sp,
                          color: kWhiteColor,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          badgeLabel ?? 'COMING SOON',
                          style: kTextBold(
                            color: kWhiteColor,
                          ).copyWith(fontSize: 9.sp, letterSpacing: 1.5),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 22.h),
                ],
                // Main Title with subtle shadow for extra pop
                Text(
                  title ?? 'Not serving in $locationDisplay yet',
                  style: kTextBold(color: kTextPrimaryColor).copyWith(
                    fontSize: 22.sp,
                    letterSpacing: -0.8,
                    height: 1.2,
                    shadows: [
                      Shadow(
                        color: Colors.white.withValues(alpha: 0.8),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.h),
                // Description
                Text(
                  description ??
                      'We are expanding fast! Try changing your location to see services available in nearby areas.',
                  style: kTextNormal(color: kTextPrimaryColor.withValues(alpha: 0.8))
                      .copyWith(
                        fontSize: 14.sp,
                        height: 1.6,
                        fontWeight: FontWeight(600),
                      ),
                ),
                SizedBox(height: 30.h),
                // Action Link
                InkWell(
                  onTap: onChangeLocation,
                  borderRadius: BorderRadius.circular(8.r),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionLabel ?? 'Change Location',
                        style: kTextBold(
                          color: kPrimaryColor,
                        ).copyWith(fontSize: 16.sp),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 16.sp,
                          color: kPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapRoutePainter extends CustomPainter {
  final Color color;
  final Color accentColor;
  _MapRoutePainter({required this.color, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Softened building color
    final buildingPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    // Softened road color with reduced width
    final roadPaint = Paint()
      ..color = const Color(0xFFD1D5DB).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 25.w;

    // 1. Draw Urban Grid (Buildings with soft shadows)
    void drawBlock(double x, double y, double w, double h, [double rot = 0]) {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      canvas.drawRRect(
        RRect.fromLTRBR(1.w, 1.w, w + 1.w, h + 1.w, Radius.circular(4.r)),
        shadowPaint,
      );
      canvas.drawRRect(
        RRect.fromLTRBR(0, 0, w, h, Radius.circular(4.r)),
        buildingPaint,
      );
      canvas.restore();
    }

    drawBlock(20.w, -10.h, 60.w, 80.h, 0.2);
    drawBlock(110.w, 15.h, 75.w, 45.h);
    drawBlock(210.w, -15.h, 55.w, 95.h, -0.12);
    drawBlock(15.w, 110.h, 85.w, 65.h, 0.18);
    drawBlock(125.w, 95.h, 95.w, 55.h, -0.08);
    drawBlock(size.width - 75.w, 130.h, 85.w, 95.h, 0.15);
    drawBlock(-5.w, 210.h, 115.w, 75.h, -0.22);
    drawBlock(155.w, 190.h, 85.w, 115.h, 0.12);

    // 2. Draw Roads
    final roadPath = Path()
      ..moveTo(-50, size.height * 0.38)
      ..lineTo(size.width + 50, size.height * 0.52)
      ..moveTo(size.width * 0.38, -50)
      ..lineTo(size.width * 0.48, size.height + 50)
      ..moveTo(size.width * 0.78, -50)
      ..lineTo(size.width * 0.68, size.height + 50);

    canvas.drawPath(roadPath, roadPaint);

    // 3. Street Labels (Softened)
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    void drawLabel(String text, double x, double y, [double rot = 0]) {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      textPainter.text = TextSpan(
        text: text.toUpperCase(),
        style: TextStyle(
          color: const Color(0xFFBCC1C8).withValues(alpha: 0.5),
          fontSize: 7.sp,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }

    drawLabel("Health St", size.width * 0.42, size.height * 0.1, 1.6);
    drawLabel("Care Ave", size.width * 0.1, size.height * 0.42, 0.15);
    drawLabel("Wellness Rd", size.width * 0.72, size.height * 0.15, 1.5);

    // 4. Marker (Softened pulse)
    final markerPos = Offset(size.width * 0.43, size.height * 0.46);
    canvas.drawCircle(
      markerPos,
      30.r,
      Paint()..color = accentColor.withValues(alpha: 0.08),
    );
    canvas.drawCircle(
      markerPos,
      18.r,
      Paint()..color = accentColor.withValues(alpha: 0.12),
    );
    canvas.drawCircle(
      markerPos,
      9.r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.w,
    );
    canvas.drawCircle(markerPos, 7.r, Paint()..color = accentColor);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
