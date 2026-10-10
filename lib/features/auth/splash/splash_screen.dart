import 'package:adhisaat_health_care/core/assets/app_assets.dart';
import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/theme/screen_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SplashPage extends HookWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Initialize the AnimationController using hooks
    final logoController = useAnimationController(duration: const Duration(seconds: 2));

    // 2. Setup the CurvedAnimation
    final logoAnimation = useMemoized(() => CurvedAnimation(parent: logoController, curve: Curves.easeOutBack), [
      logoController,
    ]);

    // 3. Trigger the animation
    useEffect(() {
      logoController.forward();
      return null; // Hooks handle disposal automatically
    }, []);

    return Scaffold(
      backgroundColor: kScaffoldColor,
      body: Stack(
        children: [
          // ─── BACKGROUND DECORATIONS (GLOW EFFECTS) ───
          // Top-right soft orange glow
          Positioned(
            top: -100.h,
            right: -100.w,
            child: Container(
              width: 320.w,
              height: 320.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kAccentColor.withValues(alpha: 0.06),
                    kAccentColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Bottom-left soft secondary brand blue glow
          Positioned(
            bottom: -80.h,
            left: -120.w,
            child: Container(
              width: 360.w,
              height: 360.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kSecondaryColor.withValues(alpha: 0.08),
                    kSecondaryColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Logo center-back soft blue glow
          Positioned(
            top: context.screenHeight * 0.15,
            left: context.screenWidth * 0.1,
            right: context.screenWidth * 0.1,
            child: Container(
              height: 320.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kPrimaryColor.withValues(alpha: 0.05),
                    kPrimaryColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // ─── MAIN CONTENT LAYER ───
          Positioned.fill(
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // ─── ELEVATED LOGO CONTAINER ───
                    ScaleTransition(
                      scale: logoAnimation,
                      child: Container(
                        padding: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kWhiteColor,
                          boxShadow: [
                            BoxShadow(
                              color: kPrimaryColor.withValues(alpha: 0.08),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                            BoxShadow(
                              color: kSecondaryColor.withValues(alpha: 0.03),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          border: Border.all(
                            color: kPrimaryColor.withValues(alpha: 0.06),
                            width: 1.5.w,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            _logo,
                            width: 124.w,
                            height: 124.w,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 28.h),

                    // ─── APP NAME ───
                    FadeTransition(
                      opacity: logoAnimation,
                      child: Text(
                        AppConstants.appName,
                        style: appFont(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w800,
                          color: kPrimaryColor,
                        ).copyWith(letterSpacing: 1.5.w),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: 10.h),

                    // ─── TAGLINE ───
                    FadeTransition(
                      opacity: logoAnimation,
                      child: Text(
                        AppConstants.appTagline.replaceAll('•', '·').toUpperCase(),
                        style: appFont(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w700,
                          color: kSecondaryColor,
                        ).copyWith(letterSpacing: 2.2.w),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: 54.h),

                    // ─── SLEEK PROGRESS LOADER ───
                    FadeTransition(
                      opacity: logoAnimation,
                      child: Container(
                        width: 140.w,
                        height: 3.h,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4.r),
                          color: kPrimaryColor.withValues(alpha: 0.08),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4.r),
                          child: LinearProgressIndicator(
                            backgroundColor: kTransparentColor,
                            valueColor: const AlwaysStoppedAnimation<Color>(kPrimaryColor),
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 4),

                    // ─── DEVELOPER ATTRIBUTION ───
                    FadeTransition(
                      opacity: logoAnimation,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'DEVELOPED BY',
                              style: appFont(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                                color: kTextSecondaryColor.withValues(alpha: 0.7),
                              ).copyWith(letterSpacing: 2.0.w),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              AppConstants.appDevelopedBy.toUpperCase(),
                              style: appFont(
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w700,
                                color: kPrimaryColor,
                              ).copyWith(letterSpacing: 1.2.w),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _logo {
    return AppConstants.isProviderApp ? AppAssets.logoProvider : AppAssets.logoCustomer;
  }
}
