import 'package:adhisaat_health_care/core/api/redirection_url.dart';
import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/services/launch_url_service.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../widgets/common/app_bar_custom.dart';

class NeedHelpPage extends StatelessWidget {
  final String? contextMessage;

  const NeedHelpPage({super.key, this.contextMessage});

  String get _whatsappMessage {
    final ctx = contextMessage;
    if (ctx == null || ctx.isEmpty) return 'Hello Adhisaat Support, I need assistance';
    return 'Hello Adhisaat Support, I need help regarding $ctx.';
  }

  String get _whatsappUrl {
    final ctx = contextMessage;
    if (ctx == null || ctx.isEmpty) return AppConstants.supportWhatsAppUrl;
    final phone = AppConstants.supportPhone.replaceFirst('+', '');
    return 'https://api.whatsapp.com/send/?phone=$phone'
        '&text=${Uri.encodeComponent(_whatsappMessage)}'
        '&type=phone_number&app_absent=0';
  }

  String get _emailSubject {
    final ctx = contextMessage;
    if (ctx == null || ctx.isEmpty) return 'Support Request - Adhisaat App';
    return 'Support Request - $ctx';
  }

  String get _emailBody {
    final ctx = contextMessage;
    if (ctx == null || ctx.isEmpty) return '';
    return 'Hello Adhisaat Support,\n\nI need help regarding $ctx.\n\n';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Light clean background
      appBar: CustomAppBar(title: '', backgroundColor: Colors.transparent),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── Background Decorative Elements ──
          // Positioned(
          //   right: -100.w,
          //   bottom: -50.h,
          //   child: Container(
          //     width: 350.w,
          //     height: 350.w,
          //     decoration: const BoxDecoration(
          //       color: kPrimaryColor,
          //       shape: BoxShape.circle,
          //     ),
          //   ),
          // ),
          // Positioned(
          //   right: -20.w,
          //   bottom: 220.h,
          //   child: Container(
          //     width: 150.w,
          //     height: 150.w,
          //     decoration: const BoxDecoration(
          //       color: kOrangeColor,
          //       shape: BoxShape.circle,
          //     ),
          //   ),
          // ),
          // Positioned(
          //   left: -50.w,
          //   top: -50.h,
          //   child: Container(
          //     width: 150.w,
          //     height: 150.w,
          //     decoration: BoxDecoration(
          //       color: kPrimaryColor.withValues(alpha: 0.05),
          //       shape: BoxShape.circle,
          //     ),
          //   ),
          // ),

          // ── Main Content ──
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroHeader(),
                  SizedBox(height: 32.h),

                  // ── Quick Registration / Secure Badges ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _BadgeIcon(icon: Icons.support_agent_rounded, label: '24/7\nSupport'),
                      _BadgeIcon(icon: Icons.verified_user_rounded, label: 'Secure &\nSafe'),
                      _BadgeIcon(icon: Icons.timer_outlined, label: 'Quick\nResolution'),
                    ],
                  ),
                  SizedBox(height: 32.h),

                  // ── Contact Options ──
                  _ContactCard(
                    icon: Icons.phone_in_talk_rounded,
                    iconBg: kPrimaryColor,
                    label: 'Call Us',
                    description: 'Talk directly to our support team',
                    detail: '+91-7023221110',
                    onTap: () => LaunchUrlService.makePhoneCall(AppConstants.supportPhone),
                  ),

                  _ContactCard(
                    icon: Icons.chat_bubble_outline_rounded,
                    iconBg: kWhatsAppColor,
                    label: 'WhatsApp',
                    description: 'Chat with us for quick support',
                    detail: '+91-7023221110',
                    onTap: () => LaunchUrlService.launchWebUrl(_whatsappUrl),
                  ),

                  _ContactCard(
                    icon: Icons.mail_outline_rounded,
                    iconBg: kAccentColor,
                    label: 'Email Us',
                    description: 'Send us a detailed message',
                    detail: AppConstants.supportEmail,
                    badge: 'Reply within 24 hrs',
                    onTap: () => LaunchUrlService.launchEmail(
                      to: AppConstants.supportEmail,
                      subject: _emailSubject,
                      body: _emailBody,
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // ── FAQ Banner ──
                  _FaqBanner(),

                  SizedBox(height: 24.h),

                  // ── Policies Section ──
                  Text('Policy & Terms', style: kTextBold1()),
                  SizedBox(height: 12.h),
                  _ContactCard(
                    icon: Icons.article_outlined,
                    iconBg: kPrimaryColor,
                    label: 'Cancellation Policy',
                    description: 'Understand our refund process',
                    detail: 'Read policy',
                    onTap: () => LaunchUrlService.launchInAppWebUrl(RedirectionUrl.cancellationPolicy),
                  ),

                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Header
// ─────────────────────────────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'How can we\n',
                style: kTextBold(color: kPrimaryColor).copyWith(fontSize: 36.sp, height: 1.2),
              ),
              TextSpan(
                text: 'Help You?',
                style: kTextBold(color: kAccentColor).copyWith(fontSize: 36.sp, height: 1.2),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          width: 50.w,
          height: 5.h,
          decoration: BoxDecoration(color: kPrimaryColor, borderRadius: BorderRadius.circular(4.r)),
        ),
        SizedBox(height: 16.h),
        Text(
          'Choose an option below to connect with our support team for a hassle-free process.',
          style: kTextMedium(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge Icon
// ─────────────────────────────────────────────────────────────────────────────
class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BadgeIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64.w,
          height: 64.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kWhiteColor,
            border: Border.all(color: kPrimaryColor.withValues(alpha: 0.2), width: 1.5),
            boxShadow: [
              BoxShadow(color: kPrimaryColor.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Center(
            child: Icon(icon, color: kPrimaryColor, size: 28.sp),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          label,
          textAlign: TextAlign.center,
          style: kTextMedium(color: kTextPrimaryColor).copyWith(fontSize: 11.sp),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Contact Card
// ─────────────────────────────────────────────────────────────────────────────
class _ContactCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String label;
  final String description;
  final String detail;
  final String? badge;
  final VoidCallback onTap;

  const _ContactCard({
    required this.icon,
    required this.iconBg,
    required this.label,
    required this.description,
    required this.detail,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: kBorderColor, width: 1),
        boxShadow: [
          BoxShadow(color: kBlackColor.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kWhiteColor,
                    border: Border.all(color: iconBg.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Center(
                    child: Icon(icon, color: iconBg, size: 24.sp),
                  ),
                ),
                SizedBox(width: 16.w),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              style: kTextSemiBold1(color: kTextPrimaryColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badge != null) SizedBox(width: 8.w),
                          if (badge != null)
                            Flexible(
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: iconBg.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                child: Text(
                                  badge!,
                                  style: kTextNormal(color: iconBg).copyWith(fontSize: 9.sp),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        description,
                        style: kTextMedium(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        detail,
                        style: kTextSemiBold(color: iconBg).copyWith(fontSize: 13.sp),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                // Arrow
                Icon(Icons.arrow_forward_ios_rounded, color: kBorderColor, size: 14.sp),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAQ Banner
// ─────────────────────────────────────────────────────────────────────────────
class _FaqBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => AppNavigator.to(AppRoutes.faqs),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
        decoration: BoxDecoration(
          color: kPrimaryColor,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(color: kPrimaryColor.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(color: kWhiteColor.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(Icons.quiz_rounded, color: kWhiteColor, size: 24.sp),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Frequently Asked Questions', style: kTextSemiBold1(color: kWhiteColor)),
                  SizedBox(height: 2.h),
                  Text(
                    'Find instant answers to common questions',
                    style: kTextMedium(color: kWhiteColor.withValues(alpha: 0.8)).copyWith(fontSize: 12.sp),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: kWhiteColor, size: 20.sp),
          ],
        ),
      ),
    );
  }
}
