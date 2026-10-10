import 'dart:math' as math;
import 'dart:ui' as ui;

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

class ProviderReferEarnPage extends ConsumerWidget {
  const ProviderReferEarnPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final settingsAsync = ref.watch(systemSettingsProvider);

    // Extract data from providers
    // Primary source: service_provider_profile.referral_code as requested by user
    final referralCode = profile?.serviceProviderProfile?.referralCode ?? 'N/A';
    final userName = profile?.name ?? 'Partner';
    final verificationStatus =
        profile?.serviceProviderProfile?.verificationStatus.toLowerCase() ??
        'pending';
    final isApproved = verificationStatus == 'approved';

    return Scaffold(
      backgroundColor: kWhiteColor,
      appBar: CustomAppBar(
        title: 'Refer & Earn',
        onBack: () => Navigator.pop(context),
      ),
      body: settingsAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 48.sp, color: kTextHintColor),
              SizedBox(height: 12.h),
              Text(
                'Could not load',
                style: kTextSemiBold1(color: kTextSecondaryColor),
              ),
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
          // Take provider referral reward amount from system settings in company_data
          final rewardAmount =
              settings.companyData?.providerReferralRewardAmount?.toInt() ??
              settings.companyData?.customerReferralRewardAmount?.toInt() ??
              0;

          return _LoadedView(
            referralCode: referralCode,
            rewardAmount: rewardAmount,
            userName: userName,
            isApproved: isApproved,
            verificationStatus: verificationStatus,
          );
        },
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  final String referralCode;
  final int rewardAmount;
  final String userName;
  final bool isApproved;
  final String verificationStatus;

  const _LoadedView({
    required this.referralCode,
    required this.rewardAmount,
    required this.userName,
    required this.isApproved,
    required this.verificationStatus,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(
          children: [
            SizedBox(height: 24.h),
            _RewardHeroSection(amount: rewardAmount),
            SizedBox(height: 32.h),
            _ReferralCodeCard(
              code: referralCode,
              userName: userName,
              isApproved: isApproved,
              verificationStatus: verificationStatus,
            ),
            SizedBox(height: 24.h),
            _HowItWorksSection(rewardAmount: rewardAmount),
            SizedBox(height: 24.h),
            _UnlockLogicSection(),
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
              decoration: BoxDecoration(
                color: kGreyColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.card_giftcard_rounded,
                color: kGreyColor7,
                size: 16.sp,
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              'Referral Reward',
              style: kTextNormal(
                color: kTextSecondaryColor,
              ).copyWith(fontSize: 14.sp),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Text(
          '₹$amount',
          style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 48.sp),
        ),
        Text(
          'For every partner you refer',
          style: kTextNormal(color: kTextHintColor).copyWith(fontSize: 12.sp),
        ),
      ],
    );
  }
}

class _ReferralCodeCard extends StatelessWidget {
  final String code;
  final String userName;
  final bool isApproved;
  final String verificationStatus;

  const _ReferralCodeCard({
    required this.code,
    required this.userName,
    required this.isApproved,
    required this.verificationStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text('Your Referral Code', style: kTextSemiBold(color: kGreyColor7), overflow: TextOverflow.ellipsis)),
              if (!isApproved)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: kErrorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    'Locked',
                    style: kTextBold0(
                      color: kErrorColor,
                    ).copyWith(fontSize: 10.sp),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isApproved
                        ? kGreyColor4
                        : kErrorColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ImageFiltered(
                        imageFilter: isApproved
                            ? ColorFilter.mode(
                                Colors.transparent,
                                BlendMode.multiply,
                              )
                            : ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                        child: Text(
                          code,
                          style: kTextBold(
                            color: kPrimaryColor,
                          ).copyWith(fontSize: 22.sp, letterSpacing: 4),
                        ),
                      ),
                    ),
                    if (isApproved) _CopyButton(code: code),
                  ],
                ),
              ),
              if (!isApproved)
                Icon(
                  Icons.lock_outline_rounded,
                  color: kErrorColor.withValues(alpha: 0.5),
                  size: 28.sp,
                ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            _getStatusMessage(),
            style: kTextSemiBold(
              color: isApproved ? kSuccessColor : kErrorColor,
            ).copyWith(fontSize: 12.sp),
          ),
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            height: 50.h,
            child: ElevatedButton.icon(
              onPressed: isApproved ? () => _share(code, userName) : null,
              icon: Icon(Icons.share_rounded, size: 18.sp, color: kWhiteColor),
              label: Text(
                'Share with Partners',
                style: kTextSemiBold1(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isApproved ? kPrimaryColor : kGreyColor1,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusMessage() {
    switch (verificationStatus) {
      case 'approved':
        return '✓ Your account is verified. You can now share and earn!';
      case 'rejected':
        return '⚠ Verification failed. Please check your documents to unlock referrals.';
      case 'pending':
      default:
        return '🕒 Verification in progress. Referral code will be unlocked once approved.';
    }
  }

  void _share(String code, String name, {bool whatsapp = false}) {
    final appLink = RedirectionUrl.partnerShareApp;
    final msg = AppStrings.providerReferralMessage(code, appLink);

    if (whatsapp) {
      LaunchUrlService.launchWhatsApp(msg);
    } else {
      SharePlus.instance.share(ShareParams(text: msg, subject: AppStrings.providerReferralSubject));
    }
  }
}

class _CopyButton extends StatefulWidget {
  final String code;

  const _CopyButton({required this.code});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton>
    with SingleTickerProviderStateMixin {
  bool _copied = false;
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(
      begin: 1,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
        decoration: BoxDecoration(
          color: _copied ? kSuccessColor : kPrimaryColor,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              color: Colors.white,
              size: 14.sp,
            ),
            SizedBox(width: 4.w),
            Text(
              _copied ? 'Copied!' : 'Copy',
              style: kTextSemiBold0(color: Colors.white),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HowItWorksSection extends StatelessWidget {
  final int rewardAmount;

  const _HowItWorksSection({required this.rewardAmount});

  @override
  Widget build(BuildContext context) {
    final steps = [
      _Step(
        icon: Icons.share_outlined,
        color: kPrimaryColor,
        title: 'Share with a Colleague',
        subtitle: 'Send your referral code to fellow healthcare professionals.',
      ),
      _Step(
        icon: Icons.person_add_alt_1_outlined,
        color: kSuccessColor,
        title: 'Partner Signs Up',
        subtitle: 'They register as a Service Partner using your code.',
      ),
      _Step(
        icon: Icons.lock_clock_outlined,
        color: const Color(0xFFB7791F),
        title: 'Reward Credited (Locked)',
        subtitle:
            'Reward is added to your wallet in a locked state immediately after registration.',
      ),
      _Step(
        icon: Icons.lock_open_rounded,
        color: kPrimaryColor,
        title: 'Complete a Booking to Unlock',
        subtitle:
            'Both you and your friend must complete at least one service booking to unlock the ₹$rewardAmount reward.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18.sp,
              color: kTextSecondaryColor,
            ),
            SizedBox(width: 8.w),
            Text(
              'How it works',
              style: kTextSemiBold2(color: kTextPrimaryColor),
            ),
          ],
        ),
        SizedBox(height: 20.h),
        ...steps.asMap().entries.map(
          (e) => _StepRow(step: e.value, index: e.key, total: steps.length),
        ),
      ],
    );
  }
}

class _Step {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _Step({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}

class _StepRow extends StatelessWidget {
  final _Step step;
  final int index;
  final int total;

  const _StepRow({
    required this.step,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            padding: EdgeInsets.only(top: 8.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title, style: kTextSemiBold()),
                SizedBox(height: 2.h),
                Text(
                  step.subtitle,
                  style: kTextNormal0(color: kTextSecondaryColor),
                ),
                SizedBox(height: index < total - 1 ? 20.h : 0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _UnlockLogicSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: kPrimaryColor.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: const BoxDecoration(
                  color: kPrimaryColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.security_rounded,
                  color: Colors.white,
                  size: 16.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reward Unlock Logic',
                      style: kTextBold(
                        color: kTextPrimaryColor,
                      ).copyWith(fontSize: 15.sp),
                    ),
                    Text(
                      'Dual Condition Policy',
                      style: kTextNormal(
                        color: kTextSecondaryColor,
                      ).copyWith(fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Text(
            'The referral reward is released only when BOTH conditions are satisfied:',
            style: kTextSemiBold(
              color: kTextPrimaryColor,
            ).copyWith(fontSize: 13.sp),
          ),
          SizedBox(height: 16.h),
          _ConditionItem(
            icon: Icons.person_rounded,
            title: 'Condition 1: You',
            desc:
                'Must have completed at least one successful service booking.',
          ),
          SizedBox(height: 12.h),
          _ConditionItem(
            icon: Icons.person_add_rounded,
            title: 'Condition 2: Your Friend',
            desc:
                'Must have independently completed at least one successful service booking.',
          ),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: kPrimaryColor,
                  size: 16.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Until both conditions are met, rewards remain locked and unavailable for withdrawal.',
                    style: kTextMedium(
                      color: kTextSecondaryColor,
                    ).copyWith(fontSize: 11.sp),
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

class _ConditionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _ConditionItem({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: kPrimaryColor, size: 20.sp),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: kTextSemiBold(
                  color: kTextPrimaryColor,
                ).copyWith(fontSize: 13.sp),
              ),
              Text(desc, style: kTextNormal0(color: kTextSecondaryColor)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TermsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final terms = [
      'This program is exclusively for Service Partner to Service Partner referrals.',
      'Referral reward is credited in a locked state at the time of referral.',
      'The reward is released only when BOTH you and your referred partner complete at least one successful booking.',
      'Locked rewards are not available for withdrawal or settlement cycles.',
      'Adhisaat reserves the right to modify or cancel this program at any time.',
      'Misuse or self-referrals will lead to disqualification.',
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.gavel_rounded,
                size: 15.sp,
                color: kTextSecondaryColor,
              ),
              SizedBox(width: 6.w),
              Text(
                'Terms & Conditions',
                style: kTextSemiBold0(color: kTextSecondaryColor),
              ),
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
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: kTextHintColor,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      t,
                      style: kTextNormal0(
                        color: kTextSecondaryColor,
                      ).copyWith(height: 1.4),
                    ),
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

class _LoadingView extends StatefulWidget {
  const _LoadingView();

  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(
      begin: -1,
      end: 2,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
          colors: const [
            Color(0xFFE8EDFF),
            Color(0xFFF5F8FF),
            Color(0xFFE8EDFF),
          ],
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
