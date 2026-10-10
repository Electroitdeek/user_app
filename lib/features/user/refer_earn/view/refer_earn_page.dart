import 'dart:math' as math;

import 'package:adhisaat_health_care/core/constants/app_strings.dart';
import 'package:adhisaat_health_care/core/services/launch_url_service.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/api/redirection_url.dart';
import '../../../../data/providers/system_settings_provider.dart';
import '../../../../data/providers/user_profile_provider.dart';
import '../../../../shared/widgets/common/app_bar_custom.dart';

class ReferEarnPage extends ConsumerWidget {
  const ReferEarnPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final settingsAsync = ref.watch(systemSettingsProvider);

    // Extract data from providers
    final referralCode = profile?.referralCode ?? 'N/A';
    final userName = profile?.name ?? 'User';

    return Scaffold(
      backgroundColor: kWhiteColor,
      appBar: CustomAppBar(title: 'Refer & Earn', onBack: () => Navigator.pop(context)),
      body: settingsAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 48.sp, color: kTextHintColor),
              SizedBox(height: 12.h),
              Text('Could not load', style: kTextSemiBold1(color: kTextSecondaryColor)),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: () => ref.invalidate(systemSettingsProvider),
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                child: Text('Retry', style: kTextSemiBold(color: Colors.white)),
              ),
            ],
          ),
        ),
        data: (settings) {
          final rewardAmount = settings.companyData?.customerReferralRewardAmount?.toInt() ?? 0;

          return _LoadedView(referralCode: referralCode, rewardAmount: rewardAmount, userName: userName);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Loaded — main UI
// ─────────────────────────────────────────────────────────────────
class _LoadedView extends StatelessWidget {
  final String referralCode;
  final int rewardAmount;
  final String userName;

  const _LoadedView({required this.referralCode, required this.rewardAmount, required this.userName});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          children: [
            SizedBox(height: 24.h),
            _RewardHeroSection(amount: rewardAmount),
            SizedBox(height: 32.h),
            _ReferralCodeCard(code: referralCode, userName: userName),
            SizedBox(height: 24.h),
            _HowItWorksSection(rewardAmount: rewardAmount),
            SizedBox(height: 24.h),
            _TermsSection(),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }
}

class _RewardHeroSection extends StatelessWidget {
  final int amount;
  const _RewardHeroSection({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: kGreyColor, borderRadius: BorderRadius.circular(6)),
              child: Icon(Icons.card_giftcard_rounded, color: kGreyColor7, size: 16.sp),
            ),
            SizedBox(width: 8.w),
            Text(
              'Referral Reward',
              style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 14.sp),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Text(
          '₹$amount',
          style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 48.sp),
        ),
        Text(
          'For every successful referral',
          style: kTextNormal(color: kTextHintColor).copyWith(fontSize: 12.sp),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Referral code card with copy + share
// ─────────────────────────────────────────────────────────────────
class _ReferralCodeCard extends StatelessWidget {
  final String code;
  final String userName;

  const _ReferralCodeCard({required this.code, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Referral Code', style: kTextSemiBold(color: kGreyColor7)),
          SizedBox(height: 12.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: kGreyColor4, width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    code,
                    style: kTextBold(color: kPrimaryColor).copyWith(fontSize: 22.sp, letterSpacing: 4),
                  ),
                ),
                _CopyButton(code: code),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            height: 50.h,
            child: ElevatedButton.icon(
              onPressed: () => _share(code, userName),
              icon: Icon(Icons.share_rounded, size: 18.sp, color: kWhiteColor),
              label: Text('Share with Friends', style: kTextSemiBold1(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _share(String code, String name, {bool whatsapp = false}) {
    final appLink = RedirectionUrl.shareApp;
    final msg = AppStrings.referralMessage(code, appLink);

    if (whatsapp) {
      LaunchUrlService.launchWhatsApp(msg);
    } else {
      SharePlus.instance.share(ShareParams(text: msg, subject: AppStrings.referralSubject));
    }
  }
}

class _CopyButton extends StatefulWidget {
  final String code;

  const _CopyButton({required this.code});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> with SingleTickerProviderStateMixin {
  bool _copied = false;
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnim = Tween<double>(begin: 1, end: 0.9).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    await _ctrl.forward();
    await _ctrl.reverse();
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scaleAnim,
    child: GestureDetector(
      onTap: _copy,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(color: _copied ? kSuccessColor : kPrimaryColor, borderRadius: BorderRadius.circular(8.r)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, color: Colors.white, size: 14.sp),
            SizedBox(width: 4.w),
            Text(_copied ? 'Copied!' : 'Copy', style: kTextSemiBold0(color: Colors.white)),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
// How it works — 3 steps
// ─────────────────────────────────────────────────────────────────
class _HowItWorksSection extends StatelessWidget {
  final int rewardAmount;

  const _HowItWorksSection({required this.rewardAmount});

  @override
  Widget build(BuildContext context) {
    final steps = [
      _Step(icon: Icons.share_outlined, color: kPrimaryColor, title: 'Share your code', subtitle: 'Send your referral code to friends and family.'),
      _Step(
        icon: Icons.person_add_alt_1_outlined,
        color: kSuccessColor,
        title: 'Friend signs up & books',
        subtitle: 'They register on Adhisaat using your code and complete their first booking.',
      ),
      _Step(
        icon: Icons.payments_outlined,
        color: const Color(0xFFB7791F),
        title: 'Earn ₹$rewardAmount bonus',
        subtitle: 'After their booking is successfully completed, ₹$rewardAmount bonus points are credited to your wallet.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 18.sp, color: kTextSecondaryColor),
            SizedBox(width: 8.w),
            Text('How it works', style: kTextSemiBold2(color: kTextPrimaryColor)),
          ],
        ),
        SizedBox(height: 20.h),
        ...steps.asMap().entries.map((e) => _StepRow(step: e.value, index: e.key, total: steps.length)),
      ],
    );
  }
}

class _Step {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _Step({required this.icon, required this.color, required this.title, required this.subtitle});
}

class _StepRow extends StatelessWidget {
  final _Step step;
  final int index;
  final int total;

  const _StepRow({required this.step, required this.index, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step number + connector line
        Column(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: step.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: step.color.withValues(alpha: 0.3)),
              ),
              child: Icon(step.icon, color: step.color, size: 18.sp),
            ),
            if (index < total - 1)
              Container(
                width: 2,
                height: 28.h,
                margin: EdgeInsets.symmetric(vertical: 4.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [step.color.withValues(alpha: 0.3), Colors.transparent],
                  ),
                ),
              ),
          ],
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 8.h, bottom: index < total - 1 ? 0 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title, style: kTextSemiBold()),
                SizedBox(height: 2.h),
                Text(step.subtitle, style: kTextNormal0(color: kTextSecondaryColor)),
                SizedBox(height: index < total - 1 ? 20.h : 0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Terms section
// ─────────────────────────────────────────────────────────────────
class _TermsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const terms = AppStrings.referralTerms;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(16.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel_rounded, size: 15.sp, color: kTextSecondaryColor),
              SizedBox(width: 6.w),
              Text('Terms & Conditions', style: kTextSemiBold0(color: kTextSecondaryColor)),
            ],
          ),
          SizedBox(height: 12.h),
          ...terms.map(
            (t) => Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 6.h),
                    child: Container(
                      width: 4.w,
                      height: 4.w,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: kTextHintColor),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(t, style: kTextNormal0(color: kTextSecondaryColor).copyWith(height: 1.4)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Loading skeleton
// ─────────────────────────────────────────────────────────────────
class _LoadingView extends StatefulWidget {
  const _LoadingView();

  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _anim = Tween<double>(begin: -1, end: 2).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box(double w, double h, {double? radius}) => AnimatedBuilder(
    animation: _anim,
    builder: (_, _) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius ?? 8.r),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: [
            math.max(0, _anim.value - 0.3).clamp(0.0, 1.0).toDouble(),
            _anim.value.clamp(0.0, 1.0),
            math.min(1, _anim.value + 0.3).clamp(0.0, 1.0).toDouble(),
          ],
          colors: const [Color(0xFFE8EDFF), Color(0xFFF5F8FF), Color(0xFFE8EDFF)],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          _box(double.infinity, 200.h, radius: 0),
          SizedBox(height: 20.h),
          _box(double.infinity, 130.h, radius: 20.r),
          SizedBox(height: 20.h),
          _box(double.infinity, 220.h, radius: 20.r),
          SizedBox(height: 20.h),
          _box(double.infinity, 200.h, radius: 20.r),
        ],
      ),
    );
  }
}
