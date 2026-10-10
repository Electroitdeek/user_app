import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/models/provider_service_request_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class StartBookingPopup extends StatefulWidget {
  final ProviderServiceRequestModel request;
  final Function(bool navigate) onStart;

  const StartBookingPopup({super.key, required this.request, required this.onStart});

  @override
  State<StartBookingPopup> createState() => StartBookingPopupState();
}

class StartBookingPopupState extends State<StartBookingPopup> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 32.w),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.r),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, 15))
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, _) =>
                      CustomPaint(painter: _EnhancedMapPainter(progress: _controller.value)),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Colors.white.withValues(alpha: 0.2), Colors.white.withValues(alpha: 0.95)],
                      radius: 1.0,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12.h,
                right: 12.w,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.black38),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 40.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80.w,
                      height: 80.w,
                      decoration:
                          BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.08), shape: BoxShape.circle),
                      child: Stack(alignment: Alignment.center, children: [
                        _PulsingRing(color: kPrimaryColor),
                        Icon(Icons.navigation_rounded, color: kPrimaryColor, size: 38.sp),
                      ]),
                    ),
                    SizedBox(height: 24.h),
                    Text('ON YOUR WAY?',
                        textAlign: TextAlign.center,
                        style: kTextBold1().copyWith(
                            color: const Color(0xFF1A1C1E), fontSize: 22.sp, letterSpacing: 0.8)),
                    SizedBox(height: 12.h),
                    Text(
                      'Starting this service will notify the customer. Navigation will launch immediately after you confirm.',
                      textAlign: TextAlign.center,
                      style: kTextNormal().copyWith(color: Colors.black54, fontSize: 14.sp, height: 1.5),
                    ),
                    SizedBox(height: 36.h),
                    Container(
                      width: double.infinity,
                      height: 58.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18.r),
                        boxShadow: [
                          BoxShadow(
                              color: kPrimaryColor.withValues(alpha: 0.25),
                              blurRadius: 15,
                              offset: const Offset(0, 8))
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onStart(true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.directions_rounded, size: 20.sp),
                          SizedBox(width: 10.w),
                          Text('CONFIRM & START',
                              style: kTextBold1().copyWith(fontSize: 15.sp, letterSpacing: 0.5)),
                        ]),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.black45, minimumSize: Size(double.infinity, 44.h)),
                      child: Text('NOT YET',
                          style: kTextBold1().copyWith(fontSize: 13.sp, letterSpacing: 1.1)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingRing extends StatefulWidget {
  final Color color;

  const _PulsingRing({required this.color});

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _animation = Tween<double>(begin: 1.0, end: 1.5)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, _) => Container(
        width: 60.w * _animation.value,
        height: 60.w * _animation.value,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.color.withValues(alpha: (1.5 - _animation.value).clamp(0.0, 1.0)),
            width: 2,
          ),
        ),
      ),
    );
  }
}

class _EnhancedMapPainter extends CustomPainter {
  final double progress;

  _EnhancedMapPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = Colors.black.withValues(alpha: 0.05);
    final roadPaint = Paint()
      ..color = kPrimaryColor.withValues(alpha: 0.04)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (double x = 0; x < size.width; x += 25) {
      for (double y = 0; y < size.height; y += 25) {
        canvas.drawCircle(Offset(x, y), 0.8, dotPaint);
      }
    }

    final path1 = Path()
      ..moveTo(-50, size.height * 0.3)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.1, size.width + 50, size.height * 0.5);
    final path2 = Path()
      ..moveTo(size.width * 0.2, size.height + 50)
      ..quadraticBezierTo(size.width * 0.8, size.height * 0.5, size.width * 0.4, -50);

    canvas.drawPath(path1, roadPaint);
    canvas.drawPath(path2, roadPaint);

    final nodePaint =
        Paint()..color = kPrimaryColor.withValues(alpha: (0.05 + (progress * 0.05)).clamp(0.0, 1.0));
    for (var node in [
      Offset(size.width * 0.15, size.height * 0.2),
      Offset(size.width * 0.85, size.height * 0.75),
      Offset(size.width * 0.5, size.height * 0.85),
    ]) {
      canvas.drawCircle(node, 20 + (progress * 15), nodePaint);
      canvas.drawCircle(node, 4, Paint()..color = kPrimaryColor.withValues(alpha: 0.1));
    }
  }

  @override
  bool shouldRepaint(covariant _EnhancedMapPainter old) => old.progress != progress;
}
