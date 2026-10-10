import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/theme/screen_dimensions.dart';

class IntroPageBase extends StatelessWidget {
  final String title;
  final String description;
  final Widget illustration;
  final List<Color> gradientColors;
  final VoidCallback onNext;
  final VoidCallback? onSkip;
  final int currentIndex;
  final int totalPages;
  final String buttonText;
  final Color? buttonForegroundColor;

  const IntroPageBase({
    super.key,
    required this.title,
    required this.description,
    required this.illustration,
    required this.gradientColors,
    required this.onNext,
    this.onSkip,
    required this.currentIndex,
    required this.totalPages,
    this.buttonText = 'Next',
    this.buttonForegroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: context.safeHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    SizedBox(height: 40.h),

                    // Illustration Area
                    Container(
                      height: 300.h,
                      padding: EdgeInsets.symmetric(horizontal: 30.w),
                      child: illustration,
                    ),

                    SizedBox(height: 40.h),

                    // Text Content
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40.w),
                      child: Text(
                        title,
                        style: kHeadingLarge().copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    SizedBox(height: 20.h),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 50.w),
                      child: Text(
                        description,
                        style: kTextNormal1().copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const Spacer(),

                    // Page Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        totalPages,
                        (index) => _buildIndicator(index == currentIndex),
                      ),
                    ),

                    SizedBox(height: 40.h),

                    // Action Button
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40.w),
                      child: ElevatedButton(
                        onPressed: onNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: buttonForegroundColor ?? gradientColors.last,
                          minimumSize: Size(double.infinity, 60.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18.r),
                          ),
                          elevation: 8,
                          shadowColor: Colors.black.withValues(alpha: 0.1),
                        ),
                        child: Text(
                          buttonText,
                          style: kTextSemiBold1().copyWith(fontSize: 18.sp),
                        ),
                      ),
                    ),

                    SizedBox(height: 20.h),

                    // Skip Button
                    if (onSkip != null)
                      TextButton(
                        onPressed: onSkip,
                        child: Text(
                          'Skip',
                          style: kTextMedium().copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      )
                    else
                      SizedBox(height: 48.h),

                    SizedBox(height: 30.h),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      width: isActive ? 30.w : 10.w,
      height: 8.h,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
    );
  }
}
