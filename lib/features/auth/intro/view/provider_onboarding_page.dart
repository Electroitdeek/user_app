import 'package:adhisaat_health_care/core/constants/app_strings.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/features/auth/login/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../bloc/onboarding_bloc.dart';

class ProviderOnboardingPage extends StatelessWidget {
  const ProviderOnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (context) => OnboardingBloc(), child: const ProviderOnboardingView());
  }
}

class ProviderOnboardingView extends StatefulWidget {
  const ProviderOnboardingView({super.key});

  @override
  State<ProviderOnboardingView> createState() => _ProviderOnboardingViewState();
}

class _ProviderOnboardingViewState extends State<ProviderOnboardingView> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<OnboardingData> _onboardingData = [
    OnboardingData(
      title: AppStrings.providerIntroTitle1,
      subtitle: AppStrings.providerIntroSubtitle1,
      imagePath: AppAssets.providerIntro1,
      tag: AppStrings.providerIntroTag1,
    ),
    OnboardingData(
      title: AppStrings.providerIntroTitle2,
      subtitle: AppStrings.providerIntroSubtitle2,
      imagePath: AppAssets.providerIntro2,
      tag: AppStrings.providerIntroTag2,
    ),
    OnboardingData(
      title: AppStrings.providerIntroTitle3,
      subtitle: AppStrings.providerIntroSubtitle3,
      imagePath: AppAssets.providerIntro3,
      tag: AppStrings.providerIntroTag3,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _nextPage() async {
    if (_currentIndex < _onboardingData.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOutCubic);
    } else {
      await _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    if (mounted) {
      context.read<OnboardingBloc>().add(SkipOnboardingEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentIndex == _onboardingData.length - 1;

    return BlocListener<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        if (state is OnboardingCompleted) {
          context.read<AuthBloc>().add(CheckAuthStatus());
        }
      },
      child: Scaffold(
        backgroundColor: kPrimaryColor,
        body: Column(
          children: [
            // ---------------- HERO IMAGE ----------------
            Expanded(
              flex: 56,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (index) => setState(() => _currentIndex = index),
                    itemCount: _onboardingData.length,
                    itemBuilder: (context, index) => _HeroImage(imagePath: _onboardingData[index].imagePath),
                  ),
                  // Bottom fade into the content sheet
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: 120.h,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [kPrimaryColor.withValues(alpha: 0.0), kPrimaryColor.withValues(alpha: 0.85), kPrimaryColor],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Header (logo + skip) pinned to top
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(bottom: false, child: _buildHeader()),
                  ),
                ],
              ),
            ),

            // ---------------- CONTENT SHEET ----------------
            Expanded(
              flex: 46,
              child: Container(
                width: double.infinity,
                color: kPrimaryColor,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24.w, 4.h, 24.w, 16.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTag(_onboardingData[_currentIndex].tag),
                        SizedBox(height: 14.h),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 350),
                              transitionBuilder: (child, animation) => FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(animation),
                                  child: child,
                                ),
                              ),
                              child: Column(
                                key: ValueKey(_currentIndex),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _onboardingData[_currentIndex].title,
                                    style: appFont(fontSize: 30.sp, fontWeight: FontWeight.w800, color: kWhiteColor).copyWith(height: 1.12, letterSpacing: -0.4),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    _onboardingData[_currentIndex].subtitle,
                                    style: appFont(fontSize: 14.sp, fontWeight: FontWeight.w400, color: kWhiteColor.withValues(alpha: 0.72)).copyWith(height: 1.45),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        _buildDots(),
                        SizedBox(height: 16.h),
                        _buildCta(isLastPage),
                        SizedBox(height: 12.h),
                        _buildTrustFooter(),
                        SizedBox(height: 4.h),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo (top-left, larger)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
            decoration: BoxDecoration(
              color: kWhiteColor,
              borderRadius: BorderRadius.circular(14.r),
              boxShadow: [BoxShadow(color: kBlackColor.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Image.asset(AppAssets.logoLandscape, height: 34.h, fit: BoxFit.contain),
          ),
          // Skip pill (top-right)
          TextButton(
            onPressed: _completeOnboarding,
            style: TextButton.styleFrom(
              backgroundColor: kBlackColor.withValues(alpha: 0.45),
              foregroundColor: kWhiteColor,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
            ),
            child: Text(
              AppStrings.skip,
              style: appFont(fontWeight: FontWeight.w600, fontSize: 13.sp, color: kWhiteColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String tag) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: kAccentColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: kAccentColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        tag,
        style: appFont(color: kAccentColor, fontSize: 10.sp, fontWeight: FontWeight.w700).copyWith(letterSpacing: 1.4),
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      children: List.generate(_onboardingData.length, (index) {
        final isActive = _currentIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          margin: EdgeInsets.only(right: 6.w),
          height: 5.h,
          width: isActive ? 26.w : 8.w,
          decoration: BoxDecoration(
            color: isActive ? kAccentColor : kWhiteColor.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(10.r),
          ),
        );
      }),
    );
  }

  Widget _buildCta(bool isLastPage) {
    return SizedBox(
      width: double.infinity,
      height: 58.h,
      child: ElevatedButton(
        onPressed: _nextPage,
        style: ElevatedButton.styleFrom(
          backgroundColor: kAccentColor,
          foregroundColor: kWhiteColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isLastPage ? AppStrings.joinAsProvider : AppStrings.continueText,
              style: appFont(fontSize: 16.sp, fontWeight: FontWeight.w700, color: kWhiteColor).copyWith(letterSpacing: 0.3),
            ),
            SizedBox(width: 10.w),
            Icon(isLastPage ? Icons.how_to_reg_rounded : Icons.arrow_forward_rounded, size: 20.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _trustItem(AppStrings.reliability),
        _trustDivider(),
        _trustItem(AppStrings.care),
        _trustDivider(),
        _trustItem(AppStrings.success),
      ],
    );
  }

  Widget _trustItem(String text) {
    return Text(
      text,
      style: appFont(color: kWhiteColor.withValues(alpha: 0.6), fontSize: 12.sp, fontWeight: FontWeight.w500).copyWith(letterSpacing: 0.4),
    );
  }

  Widget _trustDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      child: Container(
        width: 4.w,
        height: 4.w,
        decoration: const BoxDecoration(color: kAccentColor, shape: BoxShape.circle),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  final String imagePath;

  const _HeroImage({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: kSecondaryColor,
              child: Center(child: Icon(Icons.medical_services_outlined, size: 60.sp, color: kWhiteColor.withValues(alpha: 0.5))),
            );
          },
        ),
        // Subtle top scrim so header stays legible over any image
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 140.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [kBlackColor.withValues(alpha: 0.35), kBlackColor.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class OnboardingData {
  final String title;
  final String subtitle;
  final String imagePath;
  final String tag;

  OnboardingData({required this.title, required this.subtitle, required this.imagePath, required this.tag});
}
