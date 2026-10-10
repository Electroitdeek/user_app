import 'package:adhisaat_health_care/core/api/redirection_url.dart';
import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/services/launch_url_service.dart';
import 'package:adhisaat_health_care/features/auth/otp/view/otp_verification_page.dart';
import 'package:adhisaat_health_care/shared/widgets/inputs/custom_text_field.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_edge_insets.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/screen_dimensions.dart';
import '../bloc/auth_bloc.dart';

// ── Brand palette ─────────────────────────────────────────────────────────────
const _kNavy = Color(0xFF0D2B6E);
const _kNavyDark = Color(0xFF071845);
const _kOrange = Color(0xFFF97316);
const _kOrangeDark = Color(0xFFE05E00);
const _kNavyLight = Color(0xFFEEF2FB);
// ─────────────────────────────────────────────────────────────────────────────

class LoginPage extends HookWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mobileController = useTextEditingController();
    final formKey = useMemoized(() => GlobalKey<FormState>(), []);
    final mobile = useState<String>('');
    final lastBackPressTime = useRef<DateTime?>(null);

    // Login pushed over the guest home can be popped — show a close button so
    // guest users can dismiss it and return to browsing.
    final canClose = Navigator.of(context).canPop();

    useEffect(() {
      void listener() => mobile.value = mobileController.text;
      mobileController.addListener(listener);
      return () => mobileController.removeListener(listener);
    }, [mobileController]);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // white icons on navy
        statusBarBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: Navigator.of(context).canPop(),
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) {
            final s = context.read<AuthBloc>().state;
            if (s is! AuthAuthenticated) context.read<AuthBloc>().add(ResetToGuest());
            return;
          }
          final now = DateTime.now();
          if (lastBackPressTime.value == null ||
              now.difference(lastBackPressTime.value!) > const Duration(seconds: 2)) {
            lastBackPressTime.value = now;
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Press back again to exit', style: kTextMedium(color: kWhiteColor)),
                  backgroundColor: kBlackColor.withValues(alpha: 0.8),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  margin: EdgeInsets.symmetric(horizontal: 40.w, vertical: 40.h),
                ),
              );
            }
          } else {
            SystemNavigator.pop();
          }
        },
        child: Scaffold(
          // Scaffold itself is white — the navy header is part of the scroll
          backgroundColor: Colors.white,
          body: SafeArea(
            top: false,
            child: Stack(
              children: [
                BlocConsumer<AuthBloc, AuthState>(
                  listener: (context, state) {
                    if (state is AuthOtpSent) {
                      AppNavigator.push(OtpVerificationPage(mobileNumber: state.mobile, isRegistration: true));
                    }
                    if (state is AuthAuthenticated) {
                      AppNavigator.removeAndGo(
                        AppConstants.isProviderApp ? AppRoutes.providerDashboard : AppRoutes.userDashboard,
                      );
                    }
                    if (state is AuthGuest) AppNavigator.popToRoot(context);
                  },
                  builder: (context, state) {
                    return CustomScrollView(
                      slivers: [
                        // ── 1. Navy hero header (scrolls away with content) ────────
                        SliverToBoxAdapter(child: _HeroHeader(logo: _logo)),

                        // ── 2. White body ─────────────────────────────────────────
                        SliverToBoxAdapter(
                          child: Container(
                            color: Colors.white,
                            padding: EdgeInsets.fromLTRB(16.w, 24.h, 12.w, 24.h),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Heading
                                RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Care beyond ',
                                        style: kHeadingLarge(
                                          color: _kNavy,
                                        ).copyWith(fontSize: 22.sp, height: 1.25),
                                      ),
                                      TextSpan(
                                        text: 'hospital walls',
                                        style: kHeadingLarge(
                                          color: _kOrange,
                                        ).copyWith(fontSize: 22.sp, height: 1.25),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  _loginSubtitle,
                                  style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                                  textAlign: TextAlign.center,
                                ),

                                SizedBox(height: 16.h),

                                // ── Form card ──────────────────────────────────────
                                _FormCard(
                                  formKey: formKey,
                                  mobileController: mobileController,
                                  mobile: mobile.value,
                                  state: state,
                                ),

                                SizedBox(height: 24.h),

                                // ── Trust strip ────────────────────────────────────
                                //

                                // ── Legal ──────────────────────────────────────────
                                _LegalText(),

                                SizedBox(height: 16.h),
                                const _TrustStrip(),
                                SizedBox(height: 16.h),
                                const _ContactSupport(),
                                SizedBox(height: 24.h),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // ── Close button (guest only) ──────────────────────────────
                if (canClose)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8.h,
                    right: 12.w,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Padding(
                          padding: EdgeInsets.all(8.w),
                          child: Icon(Icons.close_rounded, color: Colors.white, size: 22.sp),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _logo => AppConstants.isProviderApp ? AppAssets.logoProvider : AppAssets.logoCustomer;

  String get _loginSubtitle => AppConstants.isProviderApp
      ? 'Manage your partner services with our premium dashboard.'
      : 'Access premium healthcare services with a single tap.';
}

// ── Hero Header ───────────────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.logo});

  final String logo;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _BottomWaveClipper(),
      child: Container(
        width: double.infinity,
        // No fixed height — let content size it naturally + extra bottom for wave
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 28.h,
          bottom: 56.h, // extra so wave doesn't clip logo
          left: 24.w,
          right: 24.w,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_kNavyDark, _kNavy],
          ),
        ),
        child: Column(
          children: [
            // Dot pattern row (decorative, constrained width)
            Align(alignment: Alignment.centerRight, child: _DotGrid()),
            SizedBox(height: 8.h),
            // Logo card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24.r),
                child: Image.asset(logo, width: 110.w, height: 110.w, fit: BoxFit.cover),
              ),
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }
}

// ── Form card ─────────────────────────────────────────────────────────────────
class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.formKey,
    required this.mobileController,
    required this.mobile,
    required this.state,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController mobileController;
  final String mobile;
  final AuthState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: _kNavy.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.07), blurRadius: 24, offset: const Offset(0, 6))],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card heading with orange accent bar
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 3.5.w,
                  height: 20.h,
                  decoration: BoxDecoration(color: _kOrange, borderRadius: BorderRadius.circular(4.r)),
                ),
                SizedBox(width: 10.w),
                Text(
                  'Welcome to Adhisaat',
                  style: kTextSemiBold(color: _kNavy).copyWith(fontSize: 15.sp),
                ),
              ],
            ),

            // SizedBox(height: 4.h),
            // Padding(
            //   padding: EdgeInsets.only(left: 13.5.w),
            //   child: Text(
            //     'Enter your mobile number to get started',
            //     style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
            //   ),
            // ),
            SizedBox(height: 20.h),

            if (state is AuthError) ...[_ErrorBanner(state as AuthError), SizedBox(height: 12.h)],

            // Field label
            Text(
              'Mobile Number',
              style: kTextSemiBold0(color: _kNavy).copyWith(fontSize: 12.sp),
            ),
            SizedBox(height: 8.h),

            CustomTextField(
              controller: mobileController,
              hintText: '98765 43210',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: 10,
              prefixIcon: _PrefixIcon(),
              isNumeric: true,
              borderRadius: 14.r,
              backgroundColor: _kNavyLight.withValues(alpha: 0.5),
              onChanged: (val) {
                if (val.length == 10) FocusScope.of(context).unfocus();
              },
              validator: (value) {
                if (value == null || value.isEmpty) return 'Enter mobile number';
                if (value.length != 10) return 'Must be 10 digits';
                if (!RegExp(r'^[6-9]').hasMatch(value)) return 'Enter a valid mobile number';
                return null;
              },
              onFieldSubmitted: (_) => _submit(context),
            ),

            SizedBox(height: 20.h),

            _SendOtpButton(
              label: 'Send OTP',
              isEnable: mobile.length == 10,
              isLoading: state is AuthLoading,
              onPressed: () => _submit(context),
            ),

            // SizedBox(height: 14.h),

            // Privacy note
            // _LegalText(),
            // Row(
            //   children: [
            //     Icon(Icons.shield_outlined, size: 13.sp, color: _kNavy.withValues(alpha: 0.4)),
            //     SizedBox(width: 6.w),
            //     Expanded(
            //       child: Text(
            //         'We respect your privacy and do not share your information.',
            //         style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 10.5.sp),
            //       ),
            //     ),
            //   ],
            // ),
          ],
        ),
      ),
    );
  }

  void _submit(BuildContext context) {
    if (formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(SendOtpEvent(mobileController.text.trim()));
    }
  }
}

// ── Send OTP button ───────────────────────────────────────────────────────────
class _SendOtpButton extends StatelessWidget {
  const _SendOtpButton({required this.isEnable, required this.isLoading, required this.onPressed, this.label = 'Sign in'});

  final bool isEnable;
  final bool isLoading;
  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnable && !isLoading ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        height: 52.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.r),
          gradient: isEnable
              ? const LinearGradient(colors: [_kOrange, _kOrangeDark])
              : LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade300]),
          boxShadow: isEnable
              ? [BoxShadow(color: _kOrange.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 22.w,
                  height: 22.w,
                  child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: kTextSemiBold(
                        color: isEnable ? Colors.white : Colors.grey.shade500,
                      ).copyWith(fontSize: 15.sp, letterSpacing: 0.4),
                    ),
                    SizedBox(width: 8.w),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: isEnable ? Colors.white : Colors.grey.shade500,
                      size: 18.sp,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.state);

  final AuthError state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: kErrorColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: kErrorColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: kErrorColor, size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(state.message, style: kTextMedium0(color: kErrorColor)),
          ),
        ],
      ),
    );
  }
}

// ── Prefix icon ───────────────────────────────────────────────────────────────
class _PrefixIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: kPaddingOnly(left: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.phone_iphone_rounded, color: _kOrange, size: 20.w),
          AppSpacing.sHorizontal,
          Text('+91', style: kTextSemiBold1(color: _kNavy)),
          SizedBox(width: 8.w),
          Container(height: 20.h, width: 1.w, color: kGreyColor4),
          AppSpacing.sHorizontal,
        ],
      ),
    );
  }
}

// ── Trust strip ───────────────────────────────────────────────────────────────
class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 18.h),
      decoration: BoxDecoration(
        color: _kNavyLight.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: _kNavy.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          _TrustItem(icon: Icons.verified_user_rounded, label: 'Verified\nExperts', color: _kNavy),
          _Divider(),
          _TrustItem(icon: Icons.lock_rounded, label: 'Secure\nPayments', color: _kOrange),
          _Divider(),
          _TrustItem(icon: Icons.support_agent_rounded, label: '24/7\nSupport', color: _kNavy),
        ],
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.10)),
            child: Icon(icon, color: color, size: 20.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: kTextBold0(color: _kNavy).copyWith(fontSize: 10.sp, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 36.h, width: 1.w, color: _kNavy.withValues(alpha: 0.10));
  }
}

// ── Contact support ───────────────────────────────────────────────────────────
class _ContactSupport extends StatelessWidget {
  const _ContactSupport();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () => LaunchUrlService.makePhoneCall(AppConstants.supportPhone),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: _kNavyLight.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(30.r),
            border: Border.all(color: _kNavy.withValues(alpha: 0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.headset_mic_rounded, color: _kOrange, size: 16.sp),
              SizedBox(width: 8.w),
              Text(
                'Need help? ',
                style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
              ),
              Text(
                'Contact Support',
                style: kTextSemiBold0(color: _kNavy).copyWith(fontSize: 12.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Legal text ────────────────────────────────────────────────────────────────
class _LegalText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RichText(
      // textAlign: TextAlign.center,
      text: TextSpan(
        text: 'By continuing, you agree to our '.toUpperCase(),
        style: appFont(
          fontSize: 8.5.sp,
          fontWeight: FontWeight.w600,
          color: kTextHintColor.withValues(alpha: 0.8),
        ).copyWith(letterSpacing: 0.8.w),
        children: [
          _linkSpan(
            'T&C',
            AppConstants.isUserApp ? RedirectionUrl.userTermsConditions : RedirectionUrl.partnerTermsConditions,
          ),
          TextSpan(
            text: ' & '.toUpperCase(),
            style: appFont(
              fontSize: 8.5.sp,
              fontWeight: FontWeight.w600,
              color: kTextHintColor.withValues(alpha: 0.8),
            ).copyWith(letterSpacing: 0.8.w),
          ),
          _linkSpan('Privacy Policy', RedirectionUrl.privacyPolicy),
        ],
      ),
    );
  }

  TextSpan _linkSpan(String text, String url) => TextSpan(
    text: text.toUpperCase(),
    style: appFont(
      fontSize: 8.5.sp,
      fontWeight: FontWeight.w700,
      color: _kOrange,
    ).copyWith(letterSpacing: 0.8.w, decoration: TextDecoration.underline),
    recognizer: TapGestureRecognizer()..onTap = () => LaunchUrlService.launchInAppWebUrl(url),
  );
}

// ── Bottom wave clipper (cuts the navy header at the bottom) ──────────────────
class _BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..lineTo(0, size.height - 40);
    path.quadraticBezierTo(size.width * 0.25, size.height, size.width * 0.5, size.height - 24);
    path.quadraticBezierTo(size.width * 0.75, size.height - 48, size.width, size.height - 16);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> _) => false;
}

// ── Dot grid decoration ───────────────────────────────────────────────────────
class _DotGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56.w,
      height: 28.h,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 5.w,
          mainAxisSpacing: 5.h,
        ),
        itemCount: 8,
        itemBuilder: (_, _) => Container(
          decoration: BoxDecoration(shape: BoxShape.circle, color: _kOrange.withValues(alpha: 0.65)),
        ),
      ),
    );
  }
}
