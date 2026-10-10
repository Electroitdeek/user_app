import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/services/file_downloading_service.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/shared/widgets/buttons/custom_button.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:super_tooltip/super_tooltip.dart';

import '../../../../data/models/user_profile_model.dart';
import '../../../../data/repositories/blood_donation_repository.dart';
import '../../../../di/locator.dart';
import '../../../../shared/widgets/common/custom_refresh_indicator.dart';
import '../../../blood_donor/donor_profile/bloc/donor_profile_bloc.dart';
import '../../../blood_donor/donor_profile/data/model/donor_profile_model.dart';
import '../../../blood_donor/donor_profile_register/view/donor_profile_register_page.dart';
import '../../provider_home/data/models/service_provider_models.dart';
import '../blocs/profile_bloc/provider_profile_bloc.dart';

class ProviderProfileViewPage extends StatefulWidget {
  const ProviderProfileViewPage({super.key});

  @override
  State<ProviderProfileViewPage> createState() => _ProviderProfileViewPageState();
}

class _ProviderProfileViewPageState extends State<ProviderProfileViewPage> {
  late ScrollController _scrollController;
  bool _isScrolled = false;
  final SuperTooltipController _tooltipController = SuperTooltipController();
  final SuperTooltipController _verificationTooltipController = SuperTooltipController();
  bool _isSkillsExpanded = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        if (_scrollController.offset > 80.h && !_isScrolled) {
          setState(() => _isScrolled = true);
        } else if (_scrollController.offset <= 80.h && _isScrolled) {
          setState(() => _isScrolled = false);
        }
      });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tooltipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status bar icons over the blue gradient header on iOS
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: BlocProvider(
        create: (context) => DonorProfileBloc(locator<BloodDonationRepository>()),
        child: Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: kScaffoldColor,
          appBar: CustomAppBar(
            title: 'My Profile',
            backgroundColor: kScaffoldColor,
            titleColor: kBlackColor,
            centerTitle: true,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: kPrimaryColor),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.edit_note_rounded, size: 26, color: kPrimaryColor),
                  onPressed: () => _navigateToEdit(context),
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: BlocBuilder<ProviderProfileBloc, ProviderProfileState>(
              builder: (context, state) {
                if (state is ProviderProfileLoading) {
                  return const Center(child: CircularProgressIndicator.adaptive());
                }

                if (state is ProviderProfileError) {
                  return _buildErrorState(state.error);
                }

                if (state is ProviderProfileLoaded) {
                  final profile = state.userProfileModel;
                  final sp = profile.serviceProviderProfile;

                  // Fetch donor profile if provider is a donor
                  if (profile.isDonor == true) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final donorBloc = context.read<DonorProfileBloc>();
                      if (donorBloc.state is DonorProfileInitial) {
                        donorBloc.add(LoadDonorProfile());
                      }
                    });
                  }

                  return CustomRefreshIndicator(
                    onRefresh: () async {
                      context.read<ProviderProfileBloc>().add(LoadProviderProfile());
                      if (profile.isDonor == true) {
                        context.read<DonorProfileBloc>().add(LoadDonorProfile());
                      }
                    },
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          _buildHeader(profile, sp),
                          _buildKycPendingBanner(profile, sp),
                          if (profile.isDonor != true) ...[
                            SizedBox(height: 16.h),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.w),
                              child: _buildDonorRegistrationCard(context, profile),
                            ),
                            SizedBox(height: 8.h),
                          ],
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                _buildQuickStats(sp),
                                _buildBadgesSection(sp),
                                if (sp?.about != null && sp!.about!.isNotEmpty) _buildAboutSection(sp.about!),
                                _buildSection(
                                  title: 'Personal Info',
                                  icon: Icons.person_outline_rounded,
                                  children: [
                                    _InfoItem(
                                      icon: Icons.phone_android_rounded,
                                      label: 'Mobile',
                                      value: profile.mobileNumber,
                                    ),
                                    if (profile.whatsappNumber != null)
                                      _InfoItem(
                                        icon: Icons.chat_bubble_outline_rounded,
                                        label: 'WhatsApp',
                                        value: profile.whatsappNumber!,
                                      ),
                                    _InfoItem(icon: Icons.email_outlined, label: 'Email', value: profile.email),
                                    _InfoItem(
                                      icon: Icons.cake_outlined,
                                      label: 'Date of Birth',
                                      value: AppDateFormatter.dateFromApi(profile.dateOfBirth ?? ''),
                                    ),
                                    _InfoItem(
                                      icon: Icons.bloodtype_outlined,
                                      label: 'Blood Group',
                                      value: profile.bloodGroup?.toUpperCase(),
                                    ),
                                    _InfoItem(
                                      icon: Icons.person_outline_rounded,
                                      label: 'Gender',
                                      value: profile.gender?.capitalize(),
                                    ),
                                    if (profile.isDonor)
                                      _InfoItem(
                                        icon: Icons.volunteer_activism_rounded,
                                        label: 'Donor Status',
                                        value: 'Registered Blood Donor',
                                      ),
                                  ],
                                ),
                                _buildSection(
                                  title: 'Professional Info',
                                  icon: Icons.work_outline_rounded,
                                  children: [
                                    _InfoItem(
                                      icon: Icons.school_outlined,
                                      label: 'Highest Qualification',
                                      value: sp?.highestQualification,
                                    ),
                                    _InfoItem(
                                      icon: Icons.account_balance_outlined,
                                      label: 'Council / Board Name',
                                      value: sp?.councilBoardName,
                                    ),
                                    _InfoItem(
                                      icon: Icons.business_rounded,
                                      label: 'Previous Workplace',
                                      value: sp?.previousWorkplace,
                                    ),
                                    _InfoItem(
                                      icon: Icons.assignment_ind_outlined,
                                      label: 'Registration Number',
                                      value: sp?.professionalRegistrationNumber,
                                    ),
                                    _InfoItem(
                                      icon: Icons.history_edu_rounded,
                                      label: 'Experience',
                                      value: sp?.totalExperienceText ?? sp?.totalExperience,
                                    ),
                                    // _InfoItem(
                                    //   icon: Icons.location_on_outlined,
                                    //   label: 'Area / Locality',
                                    //   value: sp?.preferredWorkingArea,
                                    // ),
                                  ],
                                ),
                                // _buildSection(
                                //   title: 'Work Preferences',
                                //   icon: Icons.tune_rounded,
                                //   children: [
                                //     _InfoItem(icon: Icons.access_time_rounded, label: 'Duty Type', value: sp?.dutyTypeText, isCapsule: true),
                                //     _InfoItem(icon: Icons.map_outlined, label: 'Preferred Area', value: sp?.preferredWorkingArea),
                                //   ],
                                // ),
                                // _buildServicesSection(sp),
                                _buildSkillsSection(sp),
                                // _buildDocumentsSection(sp),
                                _buildAddressesSection(sp),
                                _buildSection(
                                  title: 'KYC Details',
                                  icon: Icons.verified_user_outlined,
                                  children: [
                                    _KycInfoItem(
                                      icon: Icons.credit_card_rounded,
                                      label: 'Aadhaar Number',
                                      value: profile.aadharNo,
                                      status: profile.aadharVerified,
                                      onViewTap: profile.aadharFilePathUrl != null
                                          ? () => FileDownloadService().downloadAndViewFile(
                                              url: profile.aadharFilePathUrl!,
                                              originalName: 'Aadhaar_Card',
                                            )
                                          : null,
                                    ),
                                    _KycInfoItem(
                                      icon: Icons.badge_outlined,
                                      label: 'PAN Number',
                                      value: profile.panNumber?.toUpperCase(),
                                      status: profile.panVerified,
                                      onViewTap: profile.panFilePathUrl != null
                                          ? () => FileDownloadService().downloadAndViewFile(
                                              url: profile.panFilePathUrl!,
                                              originalName: 'PAN_Card',
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2.h),
                              ],
                            ),
                          ),
                          if (profile.isDonor == true) ...[
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.w),
                              child: BlocBuilder<DonorProfileBloc, DonorProfileState>(
                                builder: (context, donorState) {
                                  if (donorState is DonorProfileLoaded) {
                                    return _buildDonorProfileCard(
                                      donorState.profile,
                                      context.read<DonorProfileBloc>(),
                                    );
                                  }
                                  if (donorState is DonorProfileLoading) {
                                    return const Center(child: LinearProgressIndicator());
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                            SizedBox(height: 8.h),
                          ],
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ), // closes BlocBuilder (body)
        ), // closes Scaffold (child of BlocProvider)
      ), // closes BlocProvider (child of AnnotatedRegion)
    ); // closes AnnotatedRegion
  }

  Widget _buildDonorRegistrationCard(BuildContext context, UserProfileModel profile) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFC62828)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: kErrorColor.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Icon(Icons.volunteer_activism, color: Colors.white, size: 24.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Become a Lifesaver', style: kTextBold1(color: kWhiteColor)),
                    Text(
                      'Join our blood donor community',
                      style: kTextNormal0(color: kWhiteColor.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DonorProfileEditPage(profile: DonorProfile.fromUserProfileModel(profile)),
                  ),
                ).then((result) {
                  if (result == true) {
                    if (!context.mounted) return;
                    context.read<ProviderProfileBloc>().add(LoadProviderProfile());
                    context.read<DonorProfileBloc>().add(LoadDonorProfile());
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: kErrorColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 12.h),
              ),
              child: Text('Register as Donor', style: kTextBold1()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonorProfileCard(DonorProfile donor, DonorProfileBloc donorBloc) {
    return _buildSection(
      title: 'Donor Profile Details',
      icon: Icons.favorite_rounded,
      onEdit: () async {
        final providerBloc = context.read<ProviderProfileBloc>();
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DonorProfileEditPage(profile: donor)),
        );
        if (result == true) {
          providerBloc.add(LoadProviderProfile());
          donorBloc.add(LoadDonorProfile());
        }
      },
      children: [
        _InfoItem(icon: Icons.bloodtype_rounded, label: 'Blood Group', value: donor.bloodGroup ?? '—'),
        _InfoItem(
          icon: Icons.event_available_rounded,
          label: 'Availability',
          value: donor.isAvailable == true ? 'Available to Donate' : 'Currently Unavailable',
        ),
        _InfoItem(
          icon: Icons.monitor_weight_rounded,
          label: 'Weight',
          value: donor.weightKg != null ? '${donor.weightKg} kg' : '—',
        ),
        _InfoItem(
          icon: Icons.history_rounded,
          label: 'Last Donation',
          value: donor.lastDonationDate ?? 'No recent donations',
        ),
        _InfoItem(
          icon: Icons.contact_phone_rounded,
          label: 'Contact Method',
          value: (donor.preferredContactMethod != null && donor.preferredContactMethod!.isNotEmpty)
              ? '${donor.preferredContactMethod![0].toUpperCase()}${donor.preferredContactMethod!.substring(1)}'
              : '—',
        ),
      ],
    );
  }

  void _navigateToEdit(BuildContext context) {
    AppNavigator.to(AppRoutes.providerEditProfile).then((result) {
      if (result == true && context.mounted) {
        context.read<ProviderProfileBloc>().add(LoadProviderProfile());
      }
    });
  }

  Widget _buildKycPendingBanner(dynamic profile, ServiceProviderProfile? sp) {
    final aadharStatus = profile.aadharVerified as String?;
    final panStatus = profile.panVerified as String?;
    final aadharBad = aadharStatus == 'pending' || aadharStatus == 'rejected';
    final panBad = panStatus == 'pending' || panStatus == 'rejected';

    final verStatus = sp?.verificationStatus;
    final profileRejected = verStatus == 'rejected';
    final profileOnHold = verStatus == 'hold';
    final adminRemarks = sp?.adminRemarks;
    final hasRemarks = adminRemarks != null && adminRemarks.isNotEmpty;

    if (!aadharBad && !panBad && !profileRejected && !profileOnHold) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
      child: Column(
        children: [
          // Profile verification rejected banner (with admin remarks)
          if (profileRejected) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: kErrorColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cancel_rounded, color: kErrorColor, size: 18),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profile Verification Rejected',
                          style: kTextSemiBold(color: const Color(0xFFB91C1C)).copyWith(fontSize: 13),
                        ),
                        if (hasRemarks) ...[
                          SizedBox(height: 3.h),
                          Text(
                            'Reason: $adminRemarks',
                            style: kTextNormal0(color: const Color(0xFF991B1B)).copyWith(fontSize: 11),
                          ),
                        ],
                        SizedBox(height: 6.h),
                        GestureDetector(
                          onTap: () => _navigateToEdit(context),
                          child: Text(
                            'Update Profile →',
                            style: kTextSemiBold(color: kErrorColor).copyWith(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (profileOnHold || aadharBad || panBad) SizedBox(height: 8.h),
          ],

          // Hold banner
          if (profileOnHold) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.pause_circle_rounded, color: Color(0xFFF97316), size: 18),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profile On Hold',
                          style: kTextSemiBold(color: const Color(0xFFB45309)).copyWith(fontSize: 13),
                        ),
                        if (hasRemarks) ...[
                          SizedBox(height: 3.h),
                          Text(
                            adminRemarks,
                            style: kTextNormal0(color: const Color(0xFF92400E)).copyWith(fontSize: 11),
                          ),
                        ],
                        SizedBox(height: 6.h),
                        Text(
                          'Please contact support for assistance.',
                          style: kTextNormal0(color: const Color(0xFF92400E)).copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (aadharBad || panBad) SizedBox(height: 8.h),
          ],

          // KYC doc status banner (pending / rejected per doc)
          if (aadharBad || panBad) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: aadharStatus == 'rejected' || panStatus == 'rejected'
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: (aadharStatus == 'rejected' || panStatus == 'rejected')
                      ? kErrorColor.withValues(alpha: 0.3)
                      : const Color(0xFFF97316).withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        (aadharStatus == 'rejected' || panStatus == 'rejected')
                            ? Icons.cancel_rounded
                            : Icons.hourglass_top_rounded,
                        color: (aadharStatus == 'rejected' || panStatus == 'rejected')
                            ? kErrorColor
                            : const Color(0xFFF97316),
                        size: 16,
                      ),
                      SizedBox(width: 6.w),
                      Flexible(
                        child: Text(
                          'KYC Document Status',
                          overflow: TextOverflow.ellipsis,
                          style: kTextSemiBold(
                            color: (aadharStatus == 'rejected' || panStatus == 'rejected')
                                ? const Color(0xFFB91C1C)
                                : const Color(0xFFB45309),
                          ).copyWith(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  if (aadharBad) _kycDocRow('Aadhaar Card', aadharStatus),
                  if (aadharBad && panBad) SizedBox(height: 4.h),
                  if (panBad) _kycDocRow('PAN Card', panStatus),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kycDocRow(String docName, String? status) {
    final isRejected = status == 'rejected';
    final color = isRejected ? kErrorColor : const Color(0xFFF97316);
    final label = isRejected ? 'Rejected – Re-upload required' : 'Pending for Verification';
    final icon = isRejected ? Icons.cancel_outlined : Icons.hourglass_empty_rounded;
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        SizedBox(width: 6.w),
        Text('$docName: ', style: kTextSemiBold(color: color).copyWith(fontSize: 11)),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: kTextNormal0(color: color).copyWith(fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(dynamic profile, ServiceProviderProfile? sp) {
    final initial =
        ((profile.name != null && profile.name.toString().isNotEmpty) ? profile.name.toString()[0] : '?')
            .toUpperCase();

    return Container(
      margin: EdgeInsets.only(top: 90.h),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A4A7A), kPrimaryColor, kSecondaryColor],
              stops: [0.0, 0.45, 1.0],
            ),
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(color: kPrimaryColor.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
            ],
          ),
          child: Stack(
            children: [
              // Decorative background circles
              Positioned(
                top: -40.r,
                right: -30.r,
                child: Container(
                  width: 150.r,
                  height: 150.r,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)),
                ),
              ),
              Positioned(
                bottom: -30.r,
                left: -40.r,
                child: Container(
                  width: 120.r,
                  height: 120.r,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)),
                ),
              ),
              Positioned(
                top: 30.r,
                left: -15.r,
                child: Container(
                  width: 70.r,
                  height: 70.r,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.04)),
                ),
              ),
              Positioned(
                bottom: 20.r,
                right: 20.r,
                child: Container(
                  width: 50.r,
                  height: 50.r,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.04)),
                ),
              ),

              // Content
              Padding(
                padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 22.h),
                child: Column(
                  children: [
                    // Avatar
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 42.r,
                            backgroundColor: Colors.white.withValues(alpha: 0.12),
                            backgroundImage: profile.profileImageUrl != null
                                ? NetworkImage(profile.profileImageUrl!)
                                : null,
                            child: profile.profileImageUrl == null
                                ? Text(
                                    initial,
                                    style: kHeadingLarge().copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        if (profile.isVerified)
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: kSuccessColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 11),
                          ),
                      ],
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      profile.name,
                      style: kHeadingMedium().copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      sp?.highestQualification ?? 'Healthcare Professional',
                      style: kTextMedium().copyWith(color: Colors.white.withValues(alpha: 0.75)),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16.h),
                    // Divider line
                    Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.white.withValues(alpha: 0.2), Colors.transparent],
                        ),
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildVerificationBadge(
                          sp?.verificationStatus,
                          sp?.verificationStatusLabel ?? 'Pending',
                          adminRemarks: sp?.adminRemarks,
                        ),
                        if (sp?.isActive == false) _buildInactiveBadge(context, sp),
                        ...?sp?.badges.map((b) => _buildEarnedBadge(b)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInactiveBadge(BuildContext context, dynamic sp) {
    return GestureDetector(
      onTap: () async {
        await _tooltipController.showTooltip();
      },
      child: SuperTooltip(
        barrierConfig: const BarrierConfiguration(show: true),
        controller: _tooltipController,
        positionConfig: const PositionConfiguration(preferredDirection: TooltipDirection.down),
        style: TooltipStyle(
          backgroundColor: Colors.white,
          borderWidth: 1,
          borderColor: Colors.red.withValues(alpha: 0.2),
          borderRadius: 12.0,
          shadowColor: Colors.black.withValues(alpha: 0.1),
        ),
        content: Material(
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Text('Service Inactive', style: kTextSemiBold0().copyWith(color: Colors.red)),
                  ],
                ),
              ],
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, color: Colors.red, size: 14),
              const SizedBox(width: 6),
              Text(
                'Inactive',
                style: kTextSemiBold0().copyWith(color: Colors.red, fontSize: 13.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationBadge(String? status, String label, {String? adminRemarks}) {
    final color = _getStatusColor(status ?? 'pending');
    final isApproved = status == 'approved' || status == 'verified';

    final IconData badgeIcon;
    switch (status?.toLowerCase()) {
      case 'approved':
      case 'verified':
        badgeIcon = Icons.verified_rounded;
      case 'rejected':
        badgeIcon = Icons.cancel_rounded;
      case 'in_progress':
        badgeIcon = Icons.hourglass_top_rounded;
      case 'hold':
        badgeIcon = Icons.pause_circle_rounded;
      default:
        badgeIcon = Icons.verified_user_rounded;
    }

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: kTextSemiBold0().copyWith(color: color, fontSize: 13.sp),
          ),
        ],
      ),
    );

    if (isApproved) return badge;

    final info = _verificationStatusInfo(status, adminRemarks);

    return GestureDetector(
      onTap: () async => _verificationTooltipController.showTooltip(),
      child: SuperTooltip(
        barrierConfig: const BarrierConfiguration(show: true),
        controller: _verificationTooltipController,
        positionConfig: const PositionConfiguration(preferredDirection: TooltipDirection.down),
        style: TooltipStyle(
          backgroundColor: Colors.white,
          borderWidth: 1,
          borderColor: color.withValues(alpha: 0.2),
          borderRadius: 12.0,
          shadowColor: Colors.black.withValues(alpha: 0.1),
        ),
        content: Material(
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: color, size: 18),
                    const SizedBox(width: 8),
                    Text(info.title, style: kTextSemiBold0().copyWith(color: color)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(info.message, style: kTextNormal0().copyWith(color: Colors.black87)),
              ],
            ),
          ),
        ),
        child: badge,
      ),
    );
  }

  Widget _buildQuickStats(dynamic sp) {
    if (sp == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatBlock(icon: Icons.star_rounded, color: Colors.amber, value: sp.rating.toString(), label: 'Rating'),
          _StatDivider(),
          _StatBlock(
            icon: Icons.rate_review_rounded,
            color: Colors.blue,
            value: sp.totalRatings.toString(),
            label: 'Reviews',
          ),
          _StatDivider(),
          _StatBlock(
            icon: Icons.check_circle_rounded,
            color: Colors.green,
            value: sp.totalJobsCompleted.toString(),
            label: 'Jobs Done',
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(String about) {
    return _buildSection(
      title: 'About',
      icon: Icons.info_outline_rounded,
      children: [Text(about, style: kTextNormal().copyWith(color: Colors.grey[700], height: 1.5))],
    );
  }

  Widget _buildBadgesSection(dynamic sp) {
    if (sp?.badges == null || sp!.badges.isEmpty) return const SizedBox.shrink();
    return _buildSection(
      title: 'Recognition & Badges',
      icon: Icons.workspace_premium_rounded,
      children: [Column(children: sp.badges.map<Widget>((badge) => _buildBadgeCard(badge)).toList())],
    );
  }

  Widget _buildBadgeCard(dynamic badge) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: badge.badgeIconUrl != null
                ? Image.network(badge.badgeIconUrl!, width: 32, height: 32)
                : Icon(Icons.shield_rounded, color: kPrimaryColor, size: 32),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(badge.badgeName, style: kTextSemiBold1().copyWith(fontSize: 14.sp)),
                    SizedBox(width: 6.w),
                    Icon(Icons.verified_rounded, color: kPrimaryColor, size: 14.sp),
                  ],
                ),
                if (badge.badgeDescription != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    badge.badgeDescription!,
                    style: kTextNormal0(color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                SizedBox(height: 6.h),
                Text(
                  'Awarded: ${AppDateFormatter.dateFromApi(badge.pivot.awardedAt)}',
                  style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 10.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarnedBadge(dynamic badge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4), // LinkedIn uses more square-ish chips for assessments
        border: Border.all(color: kPrimaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, color: kPrimaryColor, size: 12.sp),
          const SizedBox(width: 6),
          Text(
            badge.badgeName,
            style: kTextSemiBold0().copyWith(color: kPrimaryColor, fontSize: 13.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    VoidCallback? onEdit,
    bool? isExpanded,
    VoidCallback? onToggle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: kPrimaryColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: kTextSemiBold1().copyWith(color: Colors.black87),
                  ),
                ),
                // const Spacer(),
                if (onEdit != null)
                  TextButton(
                    onPressed: onEdit,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('Edit', style: kTextSemiBold(color: kErrorColor)),
                  ),
                if (onToggle != null)
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 300),
                    turns: (isExpanded ?? true) ? 0.5 : 0,
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: kTextSecondaryColor, size: 24.sp),
                  ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),
                ...() {
                  final filtered = children.where((child) {
                    if (child is _InfoItem) return child.value != null && child.value!.isNotEmpty;
                    if (child is _KycInfoItem) return child.value != null && child.value!.isNotEmpty;
                    return true;
                  }).toList();
                  final spaced = filtered.expand((e) => [e, const SizedBox(height: 12)]).toList();
                  if (spaced.isNotEmpty) spaced.removeLast();
                  return spaced;
                }(),
              ],
            ),
            crossFadeState: (isExpanded ?? true) ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsSection(dynamic sp) {
    if (sp?.skills == null || sp.skills.isEmpty) {
      return const SizedBox.shrink();
    }
    return _buildSection(
      title: 'Skills',
      icon: Icons.psychology_outlined,
      isExpanded: _isSkillsExpanded,
      onToggle: () => setState(() => _isSkillsExpanded = !_isSkillsExpanded),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sp.skills
              .map<Widget>(
                (skill) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F4FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kPrimaryColor.withValues(alpha: 0.1), width: 1),
                  ),
                  child: Text(
                    skill.skillName,
                    style: kTextMedium().copyWith(
                      color: kPrimaryColor,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildAddressesSection(dynamic sp) {
    if (sp?.addresses == null || sp.addresses.isEmpty) {
      return const SizedBox.shrink();
    }
    return _buildSection(
      title: 'Full Address',
      icon: Icons.location_on_outlined,
      children: [
        ...sp.addresses.expand(
          (addr) => [
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.map_rounded, color: Colors.blueGrey),
                title: Text(addr.fullAddress, style: kTextNormal()),
                subtitle: Text(
                  "${addr.city}, ${addr.state} - ${addr.pinCode}",
                  style: kTextNormal0(color: Colors.grey[600]),
                ),
              ),
            ),
            if (addr.area != null && addr.area!.isNotEmpty)
              _InfoItem(
                icon: Icons.near_me_outlined,
                label: 'Preferred Working Area',
                value: addr.area,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 80.r, color: Colors.red[300]),
          const SizedBox(height: 24),
          Text(error, style: kTextNormal(), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          CustomButton(
            width: 160.w,
            title: 'Retry',
            onPressed: () {
              context.read<ProviderProfileBloc>().add(LoadProviderProfile());
            },
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'verified':
        return const Color(0xFF22C55E);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'in_progress':
        return const Color(0xFF3B82F6);
      case 'hold':
        return const Color(0xFFF97316);
      case 'pending':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6B7280);
    }
  }

  ({String title, String message}) _verificationStatusInfo(String? status, String? adminRemarks) {
    final remarks = (adminRemarks != null && adminRemarks.isNotEmpty) ? adminRemarks : null;
    switch (status?.toLowerCase()) {
      case 'pending':
        return (
          title: 'Verification Pending',
          message: 'Your profile is pending review. Our team will verify it shortly.',
        );
      case 'in_progress':
        return (
          title: 'Verification In Progress',
          message: 'Our team is actively reviewing your profile. You will be notified once completed.',
        );
      case 'rejected':
        return (
          title: 'Verification Rejected',
          message: remarks != null
              ? 'Reason: $remarks\n\nPlease update your profile and re-submit.'
              : 'Your profile was rejected. Please update your details and documents.',
        );
      case 'hold':
        return (
          title: 'Profile On Hold',
          message: remarks != null
              ? '$remarks\n\nPlease contact support for assistance.'
              : 'Your profile is on hold. Please contact support for assistance.',
        );
      default:
        return (title: 'Verification Status', message: 'Status: ${status ?? "unknown"}');
    }
  }
}

// --- Specific Private Widgets ---

class _KycInfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String? status;
  final VoidCallback? onViewTap;

  const _KycInfoItem({required this.icon, required this.label, this.value, this.status, this.onViewTap});

  Color get _statusColor {
    switch (status?.toLowerCase()) {
      case 'verified':
        return const Color(0xFF22C55E);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'pending':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String get _statusLabel {
    switch (status?.toLowerCase()) {
      case 'verified':
        return 'Verified';
      case 'rejected':
        return 'Rejected – Re-upload required';
      case 'pending':
        return 'Pending for Verification';
      case 'not_uploaded':
        return 'Not Uploaded';
      default:
        return status ?? '';
    }
  }

  IconData get _statusIcon {
    switch (status?.toLowerCase()) {
      case 'verified':
        return Icons.verified_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: kPrimaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: kTextNormal0(color: Colors.grey[600])),
              const SizedBox(height: 2),
              Text(
                value!,
                style: kTextMedium().copyWith(color: Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (status != null && status!.isNotEmpty) ...[
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _statusColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon, size: 11, color: _statusColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _statusLabel,
                          style: kTextNormal0(color: _statusColor).copyWith(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onViewTap != null)
          IconButton(
            onPressed: onViewTap,
            icon: Icon(Icons.visibility_rounded, size: 20, color: kPrimaryColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const _InfoItem({
    required this.icon,
    required this.label,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: kPrimaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: kTextNormal0(color: Colors.grey[600])),
              const SizedBox(height: 6),
              Text(value!, style: kTextMedium().copyWith(color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatBlock({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24.r),
        const SizedBox(height: 6),
        Text(value, style: kTextBold1().copyWith(fontSize: 18.sp)),
        Text(label, style: kTextNormal0(color: Colors.grey[500])),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 30, width: 1, color: Colors.grey[200]);
  }
}

// Extension for string capitalization (if not already defined)
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
