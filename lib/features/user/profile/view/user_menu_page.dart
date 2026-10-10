import 'package:adhisaat_health_care/core/assets/app_assets.dart';
import 'package:adhisaat_health_care/core/constants/app_strings.dart';
import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/services/launch_url_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/core/widgets/login_required_dialog.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_cached_image.dart';
import 'package:adhisaat_health_care/shared/widgets/dialogs/dialog_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/api/redirection_url.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/providers/user_profile_provider.dart';
import '../../../auth/login/bloc/auth_bloc.dart';

final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return 'v${info.version} (${info.buildNumber})';
  } catch (_) {
    return 'v1.0.0';
  }
});

class UserMenuPage extends ConsumerWidget {
  const UserMenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).maybeWhen(data: (v) => v, orElse: () => 'v1.0.0');
    return Scaffold(
      backgroundColor: kWhiteColor,
      appBar: const CustomAppBar(title: 'Menu', showBack: false),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              children: [
                SizedBox(height: 16.h),

                // ── Profile Section ──
                if (state is AuthGuest) _buildLoginPrompt(context) else _buildProfileHeader(context, ref, state),

                SizedBox(height: 24.h),

                // ── Action Grid ──
                _buildMenuGrid(context, ref, state),

                SizedBox(height: 32.h),

                // ── Menu Groups ──
                _buildCategoryHeader('Manage Account'),
                _buildMenuCard(context, [
                  _SectionItem(
                    icon: Icons.person_outline_rounded,
                    title: 'Account Settings',
                    subtitle: 'Profile, addresses',
                    items: [
                      _MenuItem(
                        icon: Icons.person_outline_rounded,
                        label: 'Edit Profile',
                        subtitle: 'Update your personal details',
                        onTap: () {
                          if (state is AuthAuthenticated) {
                            _handleAuthCheck(context, state, AppRoutes.userUpdateProfile);
                          } else {
                            LoginRequiredDialog.show(context);
                          }
                        },
                      ),
                      _MenuItem(
                        icon: Icons.location_on_outlined,
                        label: 'My Addresses',
                        subtitle: 'Manage your saved locations',
                        onTap: () => _handleAuthCheck(context, state, AppRoutes.userAddressList),
                      ),
                    ],
                  ),
                  _SectionItem(
                    icon: Icons.health_and_safety_outlined,
                    title: 'Health Records',
                    subtitle: 'Medical history & family members',
                    items: [
                      _MenuItem(
                        icon: Icons.health_and_safety_outlined,
                        label: 'Health Records',
                        subtitle: 'View your medical documents',
                        onTap: () => _handleAuthCheck(context, state, AppRoutes.healthRecordsList),
                      ),
                      _MenuItem(
                        icon: Icons.family_restroom_outlined,
                        label: 'Family Members',
                        subtitle: 'Manage family health profiles',
                        onTap: () => _handleAuthCheck(context, state, AppRoutes.familyList),
                      ),
                    ],
                  ),
                ]),

                SizedBox(height: 24.h),
                _buildCategoryHeader('Support & Legal'),
                _buildMenuCard(context, [
                  _SectionItem(
                    icon: Icons.headset_mic_outlined,
                    title: 'Help & Support',
                    subtitle: 'Get help, FAQs & tickets',
                    items: [
                      _MenuItem(
                        icon: Icons.play_lesson_rounded,
                        label: 'How to Use',
                        subtitle: 'Learn how to use Adhisaat',
                        onTap: () => LaunchUrlService.launchInAppWebUrl(RedirectionUrl.howToUse),
                      ),
                      _MenuItem(
                        icon: Icons.headset_mic_outlined,
                        label: 'Need Help?',
                        subtitle: 'Get instant support assistance',
                        onTap: () => AppNavigator.to(AppRoutes.needHelp),
                      ),
                      _MenuItem(
                        icon: Icons.help_outline_rounded,
                        label: 'FAQ',
                        subtitle: 'Find answers to common queries',
                        onTap: () => AppNavigator.to(AppRoutes.faqs),
                      ),
                      _MenuItem(
                        icon: Icons.confirmation_number_outlined,
                        label: 'Raise Ticket',
                        subtitle: 'Submit a new support request',
                        onTap: () => _handleAuthCheck(context, state, AppRoutes.supportTickets),
                      ),
                      // _MenuItem(
                      //   icon: Icons.message_outlined,
                      //   label: 'My Complaints',
                      //   subtitle: 'Track your existing complaints',
                      //   onTap: () => _handleAuthCheck(
                      //     context,
                      //     state,
                      //     AppRoutes.userComplaints,
                      //   ),
                      // ),
                    ],
                  ),
                  _SectionItem(
                    icon: Icons.info_outline_rounded,
                    title: 'About Us',
                    subtitle: 'Our story, rate & share the app',
                    items: [
                      _MenuItem(
                        icon: Icons.info_outline_rounded,
                        label: 'About Adhisaat',
                        subtitle: 'Learn about our mission & team',
                        onTap: () => LaunchUrlService.launchInAppWebUrl(RedirectionUrl.aboutUs),
                      ),
                      _MenuItem(
                        icon: Icons.star_rate_rounded,
                        label: 'Rate This App',
                        subtitle: 'Love us? Leave a review',
                        onTap: () => LaunchUrlService.rateApp(),
                      ),
                      _MenuItem(
                        icon: Icons.share_rounded,
                        label: 'Share App',
                        subtitle: 'Invite friends to Adhisaat',
                        onTap: () {
                          final profile = ref.read(userProfileProvider);
                          final code = profile?.referralCode ?? '';
                          final appLink = RedirectionUrl.shareApp;
                          final msg = code.isNotEmpty
                              ? AppStrings.referralMessage(code, appLink)
                              : 'Book trusted home health care with Adhisaat!\n$appLink';
                          SharePlus.instance.share(ShareParams(text: msg, subject: AppStrings.referralSubject));
                        },
                      ),
                    ],
                  ),
                  _SectionItem(
                    icon: Icons.connect_without_contact_rounded,
                    title: 'Connect With Us',
                    subtitle: 'Call, WhatsApp, email & social media',
                    items: [
                      _MenuItem(
                        icon: Icons.phone_rounded,
                        label: 'Call Us',
                        subtitle: AppConstants.supportPhoneDisplay,
                        onTap: () => LaunchUrlService.makePhoneCall(AppConstants.supportPhone),
                      ),
                      _MenuItem(
                        icon: Icons.chat_rounded,
                        label: 'WhatsApp Support',
                        subtitle: 'Chat with us on WhatsApp',
                        onTap: () => LaunchUrlService.launchWebUrl(
                          AppConstants.supportWhatsAppUrl,
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                      _MenuItem(
                        icon: Icons.email_outlined,
                        label: 'Email Us',
                        subtitle: AppConstants.supportEmail,
                        onTap: () => LaunchUrlService.launchEmail(
                          to: AppConstants.supportEmail,
                          subject: 'Inquiry - Adhisaat Health Care',
                        ),
                      ),
                      _MenuItem(
                        icon: Icons.camera_alt_outlined,
                        label: 'Instagram',
                        subtitle: 'Follow us @adhisaatindia',
                        onTap: () => LaunchUrlService.launchWebUrl(
                          RedirectionUrl.instagram,
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                      _MenuItem(
                        icon: Icons.facebook_rounded,
                        label: 'Facebook',
                        subtitle: 'Like our Facebook page',
                        onTap: () => LaunchUrlService.launchWebUrl(
                          RedirectionUrl.facebook,
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ],
                  ),
                  _SectionItem(
                    icon: Icons.shield_outlined,
                    title: 'Legal & More',
                    subtitle: 'Referrals, privacy, terms & policies',
                    items: [
                      _MenuItem(
                        icon: Icons.shield_outlined,
                        label: 'Privacy Policy',
                        subtitle: 'Review our data protection rules',
                        onTap: () => LaunchUrlService.launchInAppWebUrl(RedirectionUrl.privacyPolicy),
                      ),
                      _MenuItem(
                        icon: Icons.cancel_schedule_send_rounded,
                        label: 'Cancellation Policy',
                        subtitle: 'Rules for cancellations & refunds',
                        onTap: () => LaunchUrlService.launchInAppWebUrl(RedirectionUrl.cancellationPolicy),
                      ),
                      _MenuItem(
                        icon: Icons.currency_rupee_rounded,
                        label: 'Refund Policy',
                        subtitle: 'How & when refunds are processed',
                        onTap: () => LaunchUrlService.launchInAppWebUrl(RedirectionUrl.refundPolicy),
                      ),
                      _MenuItem(
                        icon: Icons.gavel_rounded,
                        label: 'Terms & Conditions',
                        subtitle: 'Read our terms of service',
                        onTap: () => LaunchUrlService.launchInAppWebUrl(RedirectionUrl.userTermsConditions),
                      ),
                      _MenuItem(
                        icon: Icons.medical_information_outlined,
                        label: 'Medico Legal Policy',
                        subtitle: 'Medical liability & legal guidelines',
                        onTap: () => LaunchUrlService.launchInAppWebUrl(RedirectionUrl.medicoLegalPolicy),
                      ),
                      _MenuItem(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete Account',
                        subtitle: 'Request account permanent removal',
                        onTap: () async {
                          final confirmed = await DialogHelper.showConfirmation(
                            title: 'Delete Account',
                            message:
                                'Are you sure you want to delete your account? This action is permanent and will delete all your data.',
                            confirmText: 'Delete',
                            isDangerous: true,
                          );
                          if (confirmed == true) {
                            LaunchUrlService.launchInAppWebUrl(RedirectionUrl.deleteAccount);
                          }
                        },
                      ),
                    ],
                  ),
                ]),

                SizedBox(height: 40.h),
                if (state is AuthAuthenticated) _buildLogoutButton(context, ref),
                SizedBox(height: 48.h),
                _footer(version),
                SizedBox(height: 40.h),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleAuthCheck(BuildContext context, AuthState state, String route) {
    if (state is AuthGuest) {
      LoginRequiredDialog.show(context);
    } else {
      Navigator.of(context).pushNamed(route);
    }
  }

  Widget _buildCategoryHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 3.w,
              height: 14.h,
              decoration: BoxDecoration(color: kAccentColor, borderRadius: BorderRadius.circular(2.r)),
            ),
            SizedBox(width: 8.w),
            Text(title, style: kTextSemiBold(color: kTextSecondaryColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, List<_SectionItem> sections) {
    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: kBorderColor, width: 0.8),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: sections.asMap().entries.map((entry) {
          final index = entry.key;
          final section = entry.value;
          final isLast = index == sections.length - 1;

          return Column(
            children: [
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => _UserSubMenuPage(title: section.title, items: section.items),
                    ),
                  );
                },
                borderRadius: index == 0
                    ? BorderRadius.vertical(top: Radius.circular(20.r))
                    : isLast
                        ? BorderRadius.vertical(bottom: Radius.circular(20.r))
                        : BorderRadius.zero,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(section.icon, color: kPrimaryColor, size: 22.sp),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(section.title, style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 15.sp)),
                            SizedBox(height: 2.h),
                            Text(section.subtitle, style: kTextNormal(color: kTextHintColor).copyWith(fontSize: 12.sp)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: kGreyColor4, size: 24.sp),
                    ],
                  ),
                ),
              ),
              if (!isLast) Divider(height: 1, thickness: 1, color: kDividerColor, indent: 64.w),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, WidgetRef ref, AuthState state) {
    final userProfile = ref.watch(userProfileProvider);
    String name = userProfile?.displayName ?? 'User';
    String? imageUrl = userProfile?.profileImageUrl;

    return GestureDetector(
      onTap: () => AppNavigator.to(AppRoutes.userProfilePage),
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [kPrimaryColor, kSecondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(color: kPrimaryColor.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kWhiteColor,
                border: Border.all(color: kWhiteColor.withValues(alpha: 0.5), width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: ClipOval(
                child: (imageUrl != null && imageUrl.isNotEmpty)
                    ? AppCachedImage(imageUrl: imageUrl, isOval: true)
                    : _buildInitials(name),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: kTextBold(color: kWhiteColor).copyWith(fontSize: 20.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Profile',
                        style: kTextNormal(color: kWhiteColor.withValues(alpha: 0.8)).copyWith(fontSize: 13.sp),
                      ),
                      SizedBox(width: 4.w),
                      Icon(Icons.arrow_forward_ios_rounded, size: 10.sp, color: kWhiteColor.withValues(alpha: 0.8)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: kWhiteColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.edit_outlined, color: kWhiteColor, size: 20.sp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80.w,
          height: 80.w,
          decoration: BoxDecoration(color: kGreyColor, shape: BoxShape.circle),
          child: Icon(Icons.person_outline_rounded, size: 32.sp, color: kTextHintColor),
        ),
        SizedBox(height: 16.h),
        Text(
          'Join Adhisaat',
          style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 20.sp),
        ),
        SizedBox(height: 8.h),
        Text(
          'Sign in to sync your bookings and more',
          textAlign: TextAlign.center,
          style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 14.sp),
        ),
        SizedBox(height: 16.h),
        SizedBox(
          width: 140.w,
          child: ElevatedButton(
            onPressed: () => AppNavigator.removeAndGo(AppRoutes.login),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              elevation: 0,
            ),
            child: Text('Login / Signup', style: kTextSemiBold(color: kWhiteColor)),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuGrid(BuildContext context, WidgetRef ref, AuthState state) {
    final userProfile = ref.watch(userProfileProvider);

    // Calculate total combined balance (Regular + Bonus)
    final double wallet = double.tryParse(userProfile?.walletAmount ?? '0') ?? 0;
    final double bonus = double.tryParse(userProfile?.bonusWalletAmount ?? '0') ?? 0;
    final String totalBalance = NumberUtils.formatCurrency(wallet + bonus, decimalDigits: 0);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildGridCard(
                icon: Icons.calendar_today_rounded,
                title: 'My Bookings',
                subtitle: 'View all bookings',
                color: kPrimaryColor,
                onTap: () => _handleAuthCheck(context, state, AppRoutes.bookingHistory),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildGridCard(
                icon: Icons.account_balance_wallet_rounded,
                title: 'My Wallet',
                subtitle: totalBalance,
                color: kPrimaryColor,
                onTap: () => _handleAuthCheck(context, state, AppRoutes.wallet),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildGridCard(
                icon: Icons.card_giftcard_rounded,
                title: 'Refer & Earn',
                subtitle: 'Invite & get rewards',
                color: kPrimaryColor,
                onTap: () => AppNavigator.to(AppRoutes.referEarn),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildGridCard(
                icon: Icons.help_center_rounded,
                title: 'Help & Support',
                subtitle: 'Get Quick Help',
                color: kPrimaryColor,
                onTap: () => AppNavigator.to(AppRoutes.needHelp),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGridCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: kPrimaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(9.w),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12.r)),
              child: Icon(icon, color: color, size: 20.sp),
            ),
            SizedBox(height: 12.h),
            Text(
              title,
              style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
            ),
            SizedBox(height: 2.h),
            Row(
              children: [
                Expanded(
                  child: Text(
                    subtitle,
                    style: kTextNormal(color: kTextHintColor).copyWith(fontSize: 11.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: kTextHintColor.withValues(alpha: 0.5), size: 16.sp),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        final result = await DialogHelper.showConfirmation(
          title: "Logout",
          message: "Are you sure want to logout?",
        );
        if (result == true) {
          if (!context.mounted) return;
          // Clear all user-specific Riverpod states
          ref.invalidate(userProfileFetchProvider);
          ref.invalidate(userProfileProvider);

          context.read<AuthBloc>().add(LogoutRequested());
        }
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(color: const Color(0xFFFFF1F1), borderRadius: BorderRadius.circular(16.r)),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.logout_rounded, color: kErrorColor, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                'Log Out',
                style: kTextBold(color: kErrorColor).copyWith(fontSize: 16.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitials(String name) {
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (name.isNotEmpty ? name[0].toUpperCase() : 'U');
    return Center(
      child: Text(initials, style: kTextBold1(color: kPrimaryColor)),
    );
  }

  Widget _footer(String version) => Column(
    children: [
      Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(color: kGreyColor, shape: BoxShape.circle),
        child: Image.asset(AppAssets.logoClear, width: 44.w, height: 44.w, fit: BoxFit.contain),
      ),
      SizedBox(height: 12.h),
      Text(
        AppConstants.appName,
        style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 16.sp),
      ),
      SizedBox(height: 4.h),
      Text(
        AppConstants.appTagline,
        style: kTextNormal(color: kTextHintColor).copyWith(fontSize: 12.sp),
      ),
      SizedBox(height: 12.h),
      Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(color: kGreyColor, borderRadius: BorderRadius.circular(100)),
        child: Text(
          version,
          style: kTextSemiBold(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
        ),
      ),
      SizedBox(height: 24.h),
      Text(
        "Developed by ${AppConstants.appDevelopedBy}",
        style: kTextNormal(color: kTextHintColor).copyWith(fontSize: 10.sp),
      ),
    ],
  );
}

class _UserSubMenuPage extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const _UserSubMenuPage({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhiteColor,
      appBar: CustomAppBar(title: title),
      body: SafeArea(
        top: false,
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
          itemCount: items.length,
          separatorBuilder: (context, index) => SizedBox(height: 16.h),
          itemBuilder: (context, index) {
            final item = items[index];
            return _AnimatedMenuCard(
              color: kPrimaryColor,
              onTap: () {
                HapticFeedback.lightImpact();
                item.onTap();
              },
              icon: item.icon,
              title: item.label,
              subtitle: item.subtitle,
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedMenuCard extends StatefulWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _AnimatedMenuCard({
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color = kAccentColor,
  });

  @override
  State<_AnimatedMenuCard> createState() => _AnimatedMenuCardState();
}

class _AnimatedMenuCardState extends State<_AnimatedMenuCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          clipBehavior: Clip.antiAlias,
          // padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 20.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kWhiteColor, const Color(0xFFFBFCFD)],
            ),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: const Color(0xFFF0F1F3), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 8)),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -15.w,
                bottom: -10.h,

                child: Icon(widget.icon, size: 90.sp, color: widget.color.withValues(alpha: 0.05)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 18.w),
                child: Row(
                  children: [
                    Container(
                      width: 52.w,
                      height: 52.w,
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Icon(widget.icon, color: widget.color, size: 24.sp),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 17.sp),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            widget.subtitle,
                            style: kTextNormal(color: kTextHintColor).copyWith(fontSize: 12.sp),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: widget.color.withValues(alpha: 0.5), size: 22.sp),
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

class _SectionItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<_MenuItem> items;

  _SectionItem({required this.icon, required this.title, required this.subtitle, required this.items});
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({required this.icon, required this.label, required this.subtitle, required this.onTap});
}
