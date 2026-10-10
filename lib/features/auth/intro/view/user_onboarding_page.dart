import 'dart:async';

import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/screen_dimensions.dart';
import 'package:adhisaat_health_care/features/auth/login/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/assets/app_assets.dart';
import '../bloc/onboarding_bloc.dart';

class UserOnboardingPage extends StatelessWidget {
  const UserOnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (context) => OnboardingBloc(), child: const UserOnboardingView());
  }
}

class UserOnboardingView extends StatefulWidget {
  const UserOnboardingView({super.key});

  @override
  State<UserOnboardingView> createState() => _UserOnboardingViewState();
}

class _UserOnboardingViewState extends State<UserOnboardingView> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  static const List<_IntroSlide> _slides = [
    _IntroSlide(
      tag: 'TRUST',
      title: 'Care You Can Trust',
      subtitle: 'Verified, background-checked nurses and caregivers — welcomed into your home with confidence.',
      image: AppAssets.userIntro1,
    ),
    _IntroSlide(
      tag: 'CARE',
      title: 'Compassionate Care',
      subtitle: 'Expert home health for elders, mothers and newborns — delivered with warmth and real skill.',
      image: AppAssets.userIntro2,
    ),
    _IntroSlide(
      tag: 'SUPPORT',
      title: 'Always By Your Side',
      subtitle: 'Book, track and manage every visit with 24/7 support, right from your phone.',
      image: AppAssets.userIntro3,
    ),
  ];

  bool get _isLast => _currentIndex == _slides.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (!_isLast) {
      _pageController.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeInOutCubic);
    } else {
      _openWelcome();
    }
  }

  void _finish() {
    // Capture the navigator before dispatching: completing onboarding makes
    // AuthWrapper rebuild the underlying route into LoginPage and unmounts this
    // view, after which `context` is defunct.
    final navigator = Navigator.of(context);
    context.read<OnboardingBloc>().add(SkipOnboardingEvent());
    // Pop the pushed _WelcomeScreen overlay so the LoginPage underneath shows.
    navigator.popUntil((route) => route.isFirst);
  }

  // Final entry screen after the Trust/Care/Support slides.
  void _openWelcome() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => _WelcomeScreen(
          onGetStarted: _finish,
          onHowItWorks: () {
            Navigator.of(context).pop();
            _pageController.animateToPage(0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
          },
        ),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        if (state is OnboardingCompleted) {
          context.read<AuthBloc>().add(CheckAuthStatus());
        }
      },
      child: Scaffold(
        backgroundColor: kPrimaryColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Full-bleed image carousel ──
            PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (_, i) => _SlideBackground(slide: _slides[i]),
            ),

            // ── Top bar: logo + skip ──
            Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Image.asset(AppAssets.logoClear, height: 28.h, fit: BoxFit.contain),
                      ),
                      TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.25),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        ),
                        child: Text(
                          'Skip',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Bottom content over the scrim ──
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TagPill(text: _slides[_currentIndex].tag),
                      SizedBox(height: 16.h),
                      Text(
                        _slides[_currentIndex].title,
                        style: GoogleFonts.inter(
                          fontSize: 32.sp,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -0.8,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        _slides[_currentIndex].subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 15.sp,
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      SizedBox(height: 28.h),
                      Row(
                        children: [
                          _ProgressBar(count: _slides.length, active: _currentIndex),
                          const Spacer(),
                          _NextButton(isLast: false, onTap: _next),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Background image + gradient scrim ──
class _SlideBackground extends StatelessWidget {
  final _IntroSlide slide;

  const _SlideBackground({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(slide.image, fit: BoxFit.cover, alignment: Alignment.topCenter),
        // Darken toward bottom (primary) so white text stays readable.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.42, 1.0],
              colors: [
                kPrimaryColor.withValues(alpha: 0.18),
                kPrimaryColor.withValues(alpha: 0.55),
                kPrimaryColor.withValues(alpha: 0.96),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Accent tag pill ──
class _TagPill extends StatelessWidget {
  final String text;

  const _TagPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: kAccentColor,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(color: kAccentColor.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Segmented progress bar ──
class _ProgressBar extends StatelessWidget {
  final int count;
  final int active;

  const _ProgressBar({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: EdgeInsets.only(right: 6.w),
          height: 6.h,
          width: isActive ? 28.w : 8.w,
          decoration: BoxDecoration(
            color: isActive ? kAccentColor : Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ── Circular next / get-started button ──
class _NextButton extends StatelessWidget {
  final bool isLast;
  final VoidCallback onTap;

  const _NextButton({required this.isLast, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (isLast) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56.h,
          padding: EdgeInsets.symmetric(horizontal: 28.w),
          decoration: BoxDecoration(
            color: kAccentColor,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(color: kAccentColor.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Get Started',
                style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              SizedBox(width: 8.w),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20.sp),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56.w,
        height: 56.w,
        decoration: BoxDecoration(
          color: kAccentColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: kAccentColor.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24.sp),
      ),
    );
  }
}

class _IntroSlide {
  final String tag;
  final String title;
  final String subtitle;
  final String image;

  const _IntroSlide({required this.tag, required this.title, required this.subtitle, required this.image});
}

// ── Auto-swiping feature highlight pill (floats over the illustration) ──
class _FeatureCarousel extends StatefulWidget {
  const _FeatureCarousel();

  @override
  State<_FeatureCarousel> createState() => _FeatureCarouselState();
}

class _FeatureCarouselState extends State<_FeatureCarousel> {
  static const _features = <_FeatureData>[
    _FeatureData(icon: Icons.verified_user_rounded, label: 'Verified Professionals'),
    _FeatureData(icon: Icons.favorite_rounded, label: 'Compassionate Care'),
    _FeatureData(icon: Icons.headset_mic_rounded, label: '24/7 Support'),
  ];

  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (!_controller.hasClients) return;
      final next = (_index + 1) % _features.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(color: kPrimaryColor.withValues(alpha: 0.15), blurRadius: 22, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 40.h,
            child: PageView.builder(
              controller: _controller,
              itemCount: _features.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final f = _features[i];
                return Row(
                  children: [
                    Container(
                      width: 36.w,
                      height: 36.w,
                      decoration: const BoxDecoration(color: kAccentColor, shape: BoxShape.circle),
                      child: Icon(f.icon, color: Colors.white, size: 18.sp),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        f.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: kPrimaryColor,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_features.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                width: active ? 16.w : 6.w,
                height: 6.w,
                decoration: BoxDecoration(
                  color: active ? kAccentColor : kGreyColor3,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _FeatureData {
  final IconData icon;
  final String label;

  const _FeatureData({required this.icon, required this.label});
}

// ─────────────────────────────────────────────────────────────────────────────
//  Final welcome screen — premium entry point after the intro slides.
// ─────────────────────────────────────────────────────────────────────────────
class _WelcomeScreen extends StatefulWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onHowItWorks;

  const _WelcomeScreen({required this.onGetStarted, required this.onHowItWorks});

  @override
  State<_WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<_WelcomeScreen> with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
    _float = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _intro.dispose();
    _float.dispose();
    super.dispose();
  }

  Animation<double> _fade(double begin, double end) => CurvedAnimation(
    parent: _intro,
    curve: Interval(begin, end, curve: Curves.easeOut),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhiteColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              SizedBox(height: 16.h),

              // ── Brand: logo + name + tagline ──
              FadeTransition(
                opacity: _fade(0.0, 0.5),
                child: Column(
                  children: [
                    Image.asset(AppAssets.logoClear, height: 56.h, fit: BoxFit.contain),
                    SizedBox(height: 10.h),
                    Text(
                      'Adhisaat',
                      style: GoogleFonts.inter(
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: kPrimaryColor,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Trust • Care • Support',
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: kAccentColor,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Illustration: white-bordered card + floating feature pill ──
              Expanded(
                child: FadeTransition(
                  opacity: _fade(0.2, 0.7),
                  child: AnimatedBuilder(
                    animation: _float,
                    builder: (context, child) =>
                        Transform.translate(offset: Offset(0, -6 + _float.value * 12), child: child),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(4.w, 16.h, 4.w, 28.h),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // White border frame around the image.
                          Positioned.fill(
                            child: Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: kWhiteColor,
                                borderRadius: BorderRadius.circular(28.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: kPrimaryColor.withValues(alpha: 0.12),
                                    blurRadius: 28,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22.r),
                                child: Image.asset(
                                  AppAssets.userIntro4,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                            ),
                          ),
                          // Floating, auto-swiping feature pill overlapping the image bottom.
                          Positioned(left: 56.w, right: 4.w, bottom: -20.h, child: const _FeatureCarousel()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              AppSpacing.lVertical,
              // ── Message + actions ──
              FadeTransition(
                opacity: _fade(0.45, 1.0),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.15),
                    end: Offset.zero,
                  ).animate(_fade(0.45, 1.0)),
                  child: Column(
                    children: [
                      Text(
                        'Welcome to Adhisaat',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 26.sp,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.6,
                          color: kPrimaryColor,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'Your trusted companion for professional home healthcare. Book verified professionals, '
                        'manage appointments, and receive compassionate care whenever you need it.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                          color: kGreyColor7,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      SizedBox(
                        width: double.infinity,
                        height: 56.h,
                        child: ElevatedButton(
                          onPressed: widget.onGetStarted,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            elevation: 6,
                            shadowColor: kPrimaryColor.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Get Started',
                                style: GoogleFonts.inter(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20.sp),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      // TextButton(
                      //   onPressed: widget.onHowItWorks,
                      //   child: Text(
                      //     'How It Works',
                      //     style: GoogleFonts.inter(
                      //       fontSize: 14.sp,
                      //       fontWeight: FontWeight.w700,
                      //       color: kAccentColor,
                      //     ),
                      //   ),
                      // ),
                      // SizedBox(height: 8.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
