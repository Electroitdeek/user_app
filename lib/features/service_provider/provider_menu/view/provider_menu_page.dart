import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/services/launch_url_service.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_cached_image.dart';
import 'package:adhisaat_health_care/shared/widgets/dialogs/dialog_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/api/redirection_url.dart';
import '../../../../core/assets/app_assets.dart';
import '../../../../core/utils/number_utils.dart';
import '../../../auth/login/bloc/auth_bloc.dart';
import '../../provider_home/bloc/provider_dashboard_bloc/provider_dashboard_bloc.dart';
import '../../provider_home/bloc/provider_dashboard_bloc/provider_dashboard_event.dart';
import '../../provider_home/bloc/provider_dashboard_bloc/provider_dashboard_state.dart';

class ProviderMenuPage extends StatefulWidget {
  const ProviderMenuPage({super.key});

  @override
  State<ProviderMenuPage> createState() => _ProviderMenuPageState();
}

class _ProviderMenuPageState extends State<ProviderMenuPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = 'v${info.version} (${info.buildNumber})');
      }
    } catch (_) {
      if (mounted) setState(() => _version = 'v1.0.0');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScaffoldColor,
      appBar: const CustomAppBar(title: 'Menu', showBack: false, backgroundColor: kScaffoldColor),
      body: BlocBuilder<ProviderDashboardBloc, ProviderDashboardState>(
        builder: (context, state) {
          final loaded = state is ProviderDashboardLoaded ? state : null;

          return SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                context.read<ProviderDashboardBloc>().add(RefreshDashboardEvent());
              },
              color: kPrimaryColor,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  children: [
                    SizedBox(height: 16.h),

                    // ── Profile Section ──
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kPrimaryColor, kSecondaryColor]),
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [BoxShadow(color: kPrimaryColor.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      padding: EdgeInsets.all(16.w),
                      child: _buildProfileHeader(context, loaded),
                    ),

                    SizedBox(height: 28.h),

                    // ── Action Grid ──
                    _buildMenuGrid(context, loaded),

                    SizedBox(height: 32.h),

                    // ── Menu Groups ──
                    _buildCategoryHeader('Account Settings'),
                    _buildMenuCard(context, [
                      _SectionItem(
                        icon: Icons.person_outline_rounded,
                        title: 'Profile & Documents',
                        subtitle: 'Update info & manage files',
                        items: [
                          _MenuItem(
                            icon: Icons.person_outline_rounded,
                            label: 'Edit Profile',
                            subtitle: 'Manage your profile & personal details',
                            onTap: () => AppNavigator.to(AppRoutes.providerProfilePage),
                          ),
                          _MenuItem(
                            icon: Icons.document_scanner_outlined,
                            label: 'KYC Documents',
                            subtitle: 'Verify & manage your identity proofs',
                            onTap: () => AppNavigator.to(AppRoutes.providerDocuments),
                          ),
                          _MenuItem(
                            icon: Icons.medical_services_outlined,
                            label: 'My Services',
                            subtitle: 'Manage your professional service list',
                            onTap: () => AppNavigator.to(AppRoutes.manageCategories),
                          ),
                        ],
                      ),
                      _SectionItem(
                        icon: Icons.account_balance_rounded,
                        title: 'Payments & Work',
                        subtitle: 'Manage earnings, bank & schedule',
                        items: [
                          _MenuItem(
                            icon: Icons.account_balance_wallet_rounded,
                            label: 'My Wallet',
                            subtitle: 'Track earnings & request withdrawals',
                            onTap: () => AppNavigator.to(AppRoutes.providerWallet),
                          ),
                          _MenuItem(
                            icon: Icons.account_balance_rounded,
                            label: 'Bank Details',
                            subtitle: 'Manage your primary settlement account',
                            onTap: () => AppNavigator.to(AppRoutes.providerBankDetail),
                          ),
                          _MenuItem(
                            icon: Icons.calendar_month_rounded,
                            label: 'Work Schedule',
                            subtitle: 'Configure your working hours & slots',
                            onTap: () => AppNavigator.to(AppRoutes.providerSchedule),
                          ),
                        ],
                      ),
                      _SectionItem(
                        icon: Icons.card_giftcard_rounded,
                        title: 'Rewards & Referrals',
                        subtitle: 'Invite partners & earn commissions',
                        items: [
                          _MenuItem(
                            icon: Icons.card_giftcard_rounded,
                            label: 'Refer & Earn',
                            subtitle: 'Refer fellow providers & earn rewards',
                            onTap: () => AppNavigator.to(AppRoutes.referEarn),
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
                        subtitle: 'Get help & view FAQs',
                        items: [
                          _MenuItem(
                            icon: Icons.play_lesson_rounded,
                            label: 'How to Use',
                            subtitle: 'Learn how to use the partner app',
                            onTap: () => LaunchUrlService.launchInAppWebUrl(RedirectionUrl.workPartnerApp),
                          ),
                          _MenuItem(
                            icon: Icons.headset_mic_outlined,
                            label: 'Need Help?',
                            subtitle: 'Connect with our support team 24/7',
                            onTap: () => AppNavigator.to(AppRoutes.needHelp),
                          ),
                          _MenuItem(
                            icon: Icons.help_outline_rounded,
                            label: 'FAQ',
                            subtitle: 'Find instant answers to your queries',
                            onTap: () => AppNavigator.to(AppRoutes.faqs),
                          ),
                        ],
                      ),
                      _SectionItem(
                        icon: Icons.shield_outlined,
                        title: 'Legal & More',
                        subtitle: 'Privacy, terms & more',
                        items: [
                          _MenuItem(
                            icon: Icons.article_outlined,
                            label: 'Terms & Conditions',
                            subtitle: 'Read our service & usage policies',
                            onTap: () => LaunchUrlService.launchInAppWebUrl(RedirectionUrl.userTermsConditions),
                          ),
                          _MenuItem(
                            icon: Icons.shield_outlined,
                            label: 'Privacy Policy',
                            subtitle: 'Learn how we safeguard your data',
                            onTap: () => LaunchUrlService.launchInAppWebUrl(RedirectionUrl.privacyPolicy),
                          ),
                          _MenuItem(
                            icon: Icons.cancel_schedule_send_rounded,
                            label: 'Cancellation Policy',
                            subtitle: 'View rules for booking cancellations',
                            onTap: () => LaunchUrlService.launchInAppWebUrl(RedirectionUrl.cancellationPolicy),
                          ),
                          _MenuItem(
                            icon: Icons.delete_outline_rounded,
                            label: 'Delete Account',
                            subtitle: 'Request permanent account removal',
                            onTap: () async {
                              final confirmed = await DialogHelper.showConfirmation(
                                title: 'Delete Account',
                                message: 'Are you sure you want to delete your account? This action is permanent and will delete all your data.',
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
                    _buildLogoutButton(context),
                    SizedBox(height: 48.h),
                    _footer(),
                    SizedBox(height: 40.h),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
        child: Text(title, style: kTextSemiBold(color: kTextSecondaryColor)),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, List<_SectionItem> sections) {
    return Column(
      children: sections.asMap().entries.map((entry) {
        final section = entry.value;
        final isLast = entry.key == sections.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 16.h),
          child: _AnimatedMenuCard(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => _ProviderSubMenuPage(title: section.title, items: section.items),
                ),
              );
            },
            icon: section.icon,
            title: section.title,
            subtitle: section.subtitle,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProfileHeader(BuildContext context, ProviderDashboardLoaded? s) {
    final profile = s?.profile;
    final name = profile?.displayName ?? 'Partner';
    final imgUrl = profile?.profileImageUrl;
    final provider = profile?.serviceProviderProfile;
    final isActive = provider?.isActive ?? false;
    final rating = NumberUtils.toDouble(provider?.rating);
    final initials = profile?.initials ?? 'P';
    final varificationStatus = provider?.verificationStatus;
    final isStandby = provider?.isStandby ?? false;

    return Row(
      children: [
        GestureDetector(
          onTap: () => AppNavigator.to(AppRoutes.providerProfilePage),
          child: Stack(
            children: [
              Container(
                width: 70.w,
                height: 70.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kGreyColor,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: ClipOval(
                  child: (imgUrl != null && imgUrl.isNotEmpty) ? AppCachedImage(imageUrl: imgUrl, isOval: true) : _buildInitials(name, initials),
                ),
              ),
              if (isActive)
                Positioned(
                  right: 4.w,
                  bottom: 4.w,
                  child: Container(
                    width: 18.w,
                    height: 18.w,
                    decoration: BoxDecoration(
                      color: kSuccessColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(Icons.check, color: Colors.white, size: 10.sp),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: GestureDetector(
            onTap: () => AppNavigator.to(AppRoutes.providerProfilePage),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: kTextBold3(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8.w,
                  runSpacing: 4.h,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4.r)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, color: const Color(0xFFFFD700), size: 12.sp),
                          SizedBox(width: 2.w),
                          Text(
                            rating <= 0 ? "No rating" : rating.toStringAsFixed(1),
                            style: kTextSemiBold(color: Colors.white).copyWith(fontSize: 10.sp),
                          ),
                        ],
                      ),
                    ),
                    _verificationStatusBadge(
                      status: varificationStatus,
                      label: (provider?.verificationStatusLabel ?? varificationStatus ?? '').toString(),
                    ),
                  ],
                ),
                SizedBox(height: 8.w),
                if (isStandby) ...[SizedBox(width: 8.w), _standbyBadge()],
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: () => AppNavigator.to(AppRoutes.providerProfilePage),
          child: Padding(
            padding: EdgeInsets.all(8.w),
            child: Icon(Icons.edit, color: Colors.white, size: 20.sp),
          ),
        ),
      ],
    );
  }

  Widget _verificationStatusBadge({String? status, required String label}) {
    final color = _getVerificationStatusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4.r)),
      child: Text(
        label.toUpperCase(),
        style: kTextBold0(color: color).copyWith(fontSize: 9.sp, letterSpacing: 0.5),
      ),
    );
  }

  Widget _standbyBadge() {
    const color = Color(0xFF0EA5E9); // Sky blue for Standby
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, color: color, size: 10.sp),
          SizedBox(width: 2.w),
          Text(
            'STANDBY',
            style: kTextBold0(color: color).copyWith(fontSize: 9.sp, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Color _getVerificationStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return kSuccessColor;
      case 'pending':
        return const Color(0xFFFBBF24);
      case 'in_progress':
        return kInfoColor;
      case 'rejected':
        return kErrorColor;
      case 'hold':
        return const Color(0xFFF97316);
      default:
        return kTextSecondaryColor;
    }
  }

  Widget _buildMenuGrid(BuildContext context, ProviderDashboardLoaded? s) {
    final categories = s?.dashboard.categories;

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildGridCard(
                  icon: Icons.calendar_today_rounded,
                  title: 'My Services',
                  subtitle: '${categories ?? 0} enrolled',
                  accentColor: kPrimaryColor,
                  onTap: () => AppNavigator.to(AppRoutes.manageCategories),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildGridCard(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'My Wallet',
                  subtitle: "Withdraw",
                  accentColor: kSuccessColor,
                  onTap: () => AppNavigator.to(AppRoutes.providerWallet),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildGridCard(
                  icon: Icons.calendar_month_rounded,
                  title: 'My Schedule',
                  subtitle: 'Manage availability',
                  accentColor: const Color(0xFFF97316),
                  onTap: () => AppNavigator.to(AppRoutes.providerSchedule),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildGridCard(
                  icon: Icons.help_center_rounded,
                  title: 'Help & Support',
                  subtitle: 'Get Quick Help',
                  accentColor: const Color(0xFF8B5CF6),
                  onTap: () => AppNavigator.to(AppRoutes.needHelp),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGridCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color accentColor = kPrimaryColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: accentColor.withValues(alpha: 0.12), width: 1.2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: accentColor, size: 18.sp),
            ),
            SizedBox(height: 12.h),
            Text(
              title,
              style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
            ),
            const Spacer(),
            SizedBox(height: 6.h),
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

  Widget _buildLogoutButton(BuildContext context) {
    return InkWell(
      onTap: () async {
        final result = await DialogHelper.showConfirmation(title: "Logout", message: "Are you sure want to logout?");
        if (result == true) {
          if (!context.mounted) return;
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

  Widget _buildInitials(String name, String fallback) {
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2 ? '${parts[0][0]}${parts[1][0]}'.toUpperCase() : (name.isNotEmpty ? name[0].toUpperCase() : fallback);
    return Center(
      child: Text(initials, style: kTextBold1(color: kPrimaryColor)),
    );
  }

  Widget _footer() => Column(
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
          _version,
          style: kTextSemiBold(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
        ),
      ),
      SizedBox(height: 24.h),
      Text(
        "Developed by ${AppConstants.appDevelopedBy}",
        style: kTextNormal(color: kTextHintColor).copyWith(fontSize: 10.sp),
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class _AnimatedMenuCard extends StatefulWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;

  const _AnimatedMenuCard({required this.onTap, required this.icon, required this.title, required this.subtitle});

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
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
          padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
          decoration: BoxDecoration(
            color: kWhiteColor,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: kPrimaryColor.withValues(alpha: 0.08), width: 1.5),
            boxShadow: [BoxShadow(color: kPrimaryColor.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -10.w,
                bottom: -10.h,
                child: Icon(widget.icon, size: 80.sp, color: kPrimaryColor.withValues(alpha: 0.04)),
              ),
              Row(
                children: [
                  Container(
                    width: 52.w,
                    height: 52.w,
                    decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(16.r)),
                    child: Icon(widget.icon, color: kPrimaryColor, size: 24.sp),
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
                  Icon(Icons.chevron_right_rounded, color: kPrimaryColor.withValues(alpha: 0.4), size: 22.sp),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderSubMenuPage extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const _ProviderSubMenuPage({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScaffoldColor,
      appBar: CustomAppBar(title: title, backgroundColor: kScaffoldColor),
      body: SafeArea(
        top: false,
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
          itemCount: items.length,
          separatorBuilder: (context, index) => SizedBox(height: 16.h),
          itemBuilder: (context, index) {
            final item = items[index];
            return _AnimatedMenuCard(
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
