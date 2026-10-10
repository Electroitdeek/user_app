import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/shared/widgets/common/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../../core/navigation/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../di/locator.dart';
import '../../../../data/models/user_profile_model.dart';
import '../../../../data/repositories/blood_donation_repository.dart';
import '../../../../shared/widgets/common/app_bar_custom.dart';
import '../../../../shared/widgets/common/app_cached_image.dart';
import '../../../../shared/widgets/common/custom_error_view.dart';
import '../../../../shared/widgets/shimmer/user_shimmers.dart';
import '../../../blood_donor/donor_profile/bloc/donor_profile_bloc.dart';
import '../../../blood_donor/donor_profile/data/model/donor_profile_model.dart';
import '../../../blood_donor/donor_profile_register/view/donor_profile_register_page.dart';
import '../bloc/user_profile_bloc.dart';
import '../data/user_profile_repository.dart';

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => UserProfileBloc(locator<UserProfileRepository>())..add(LoadUserProfile())),
        BlocProvider(create: (_) => DonorProfileBloc(locator<BloodDonationRepository>())),
      ],
      child: const _UserProfileView(),
    );
  }
}

class _UserProfileView extends StatelessWidget {
  const _UserProfileView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhiteColor,
      appBar: const CustomAppBar(title: 'Profile'),
      body: BlocBuilder<UserProfileBloc, UserProfileState>(
        builder: (context, state) {
          if (state is UserProfileLoading) {
            return const ProfileShimmer();
          }
          if (state is UserProfileError) {
            return CustomErrorView(
              title: 'Could not load profile',
              message: state.message,
              icon: Icons.person_off_rounded,
              onRetry: () => context.read<UserProfileBloc>().add(LoadUserProfile()),
            );
          }
          if (state is UserProfileLoaded) {
            if (state.profile.isDonor == true) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final donorBloc = context.read<DonorProfileBloc>();
                if (donorBloc.state is DonorProfileInitial) {
                  donorBloc.add(LoadDonorProfile());
                }
              });
            }
            return _ProfileContent(
              profile: state.profile,
              onRefresh: () {
                context.read<UserProfileBloc>().add(RefreshUserProfile());
                if (state.profile.isDonor == true) {
                  context.read<DonorProfileBloc>().add(LoadDonorProfile());
                }
              },
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  final UserProfileModel profile;
  final VoidCallback onRefresh;

  const _ProfileContent({required this.profile, required this.onRefresh});

  int get _completionScore {
    int filled = 0;
    if (profile.name.isNotEmpty) filled++;
    if (profile.mobileNumber.isNotEmpty) filled++;
    if (profile.email.isNotEmpty) filled++;
    if (profile.dateOfBirth != null) filled++;
    if (profile.gender != null) filled++;
    if (profile.bloodGroup != null) filled++;
    if (profile.fullAddress != null) filled++;
    if (profile.city != null) filled++;
    if (profile.emergencyContactName != null) filled++;
    if (profile.emergencyContactNumber != null) filled++;
    return ((filled / 10) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    return CustomRefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(
          children: [
            SizedBox(height: 16.h),

            // ── Profile Header ──
            _buildProfileCard(context),
            SizedBox(height: 12.h),
            _ProfileCompletionMeter(score: _completionScore),
            SizedBox(height: 12.h),
            if (!(profile.isDonor)) ...[_buildDonorRegistrationCard(context), SizedBox(height: 12.h)],

            _buildInfoCard([
              _InfoItem(icon: Icons.badge_outlined, label: 'Full Name', value: profile.name),
              _InfoItem(icon: Icons.phone_outlined, label: 'Mobile', value: profile.mobileNumber),
              if (profile.email.isNotEmpty) _InfoItem(icon: Icons.email_outlined, label: 'Email', value: profile.email),
              _InfoItem(icon: Icons.cake_outlined, label: 'Date of Birth', value: _formatDate(profile.dateOfBirth)),
              _InfoItem(icon: Icons.wc_outlined, label: 'Gender', value: profile.displayGender),
              _InfoItem(icon: Icons.water_drop_outlined, label: 'Blood Group', value: profile.bloodGroup ?? '—'),
            ]),

            // ── Identity Documents ──
            if ((profile.aadharNo != null && profile.aadharNo!.isNotEmpty) || (profile.panNumber != null && profile.panNumber!.isNotEmpty)) ...[
              SizedBox(height: 12.h),
              _buildSectionHeader('Identity Documents'),
              _buildInfoCard([
                if (profile.aadharNo != null && profile.aadharNo!.isNotEmpty)
                  _InfoItem(icon: Icons.credit_card_outlined, label: 'Aadhaar Number', value: _maskAadhaar(profile.aadharNo!)),
                if (profile.panNumber != null && profile.panNumber!.isNotEmpty)
                  _InfoItem(icon: Icons.badge_outlined, label: 'PAN Number', value: profile.panNumber!),
              ]),
            ],

            if (profile.formattedAddress != '—') ...[
              SizedBox(height: 12.h),
              _buildSectionHeader('Primary Address'),
              _buildInfoCard([_InfoItem(icon: Icons.location_on_outlined, label: 'Address', value: profile.formattedAddress, maxLines: 4)]),
            ],

            if (profile.emergencyContactName != null && profile.emergencyContactName!.isNotEmpty) ...[
              SizedBox(height: 12.h),
              _buildSectionHeader('Emergency Contact'),
              _buildInfoCard([
                _InfoItem(icon: Icons.person_outline, label: 'Contact Name', value: profile.emergencyContactName!),
                _InfoItem(icon: Icons.phone_outlined, label: 'Contact Number', value: profile.emergencyContactNumber ?? '—'),
              ]),
            ],
            SizedBox(height: 24.h),
            if (profile.isDonor) ...[
              BlocBuilder<DonorProfileBloc, DonorProfileState>(
                builder: (context, donorState) {
                  if (donorState is DonorProfileLoaded) {
                    return _DonorProfileCard(
                      donor: donorState.profile,
                      onEdit: () async {
                        final userBloc = context.read<UserProfileBloc>();
                        final donorBloc = context.read<DonorProfileBloc>();
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => DonorProfileEditPage(profile: donorState.profile)),
                        );
                        if (result == true) {
                          userBloc.add(RefreshUserProfile());
                          donorBloc.add(LoadDonorProfile());
                        }
                      },
                    );
                  }
                  if (donorState is DonorProfileLoading) {
                    return const Center(child: LinearProgressIndicator());
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
            SizedBox(height: 24.h),
          ],
        ),
      )
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 72.w,
            height: 72.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kGreyColor,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: ClipOval(
              child: (profile.profilePhoto != null && profile.profilePhoto!.isNotEmpty)
                  ? AppCachedImage(imageUrl: profile.profilePhoto!, isOval: true)
                  : _buildInitials(profile.name),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 18.sp),
                ),
                SizedBox(height: 2.h),
                Text(
                  profile.email.isNotEmpty ? profile.email : profile.mobileNumber,
                  style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => AppNavigator.to(AppRoutes.userUpdateProfile).then((_) => onRefresh()),
            icon: Icon(Icons.edit_note_rounded, color: kPrimaryColor, size: 28.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildDonorRegistrationCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [kErrorColor, kErrorColor.withValues(alpha: 0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [BoxShadow(color: kErrorColor.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
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
                    Text(
                      'Become a Lifesaver',
                      style: kTextBold(color: kWhiteColor).copyWith(fontSize: 16.sp),
                    ),
                    Text(
                      'Join our blood donor community',
                      style: kTextNormal(color: kWhiteColor.withValues(alpha: 0.9)).copyWith(fontSize: 12.sp),
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
                  MaterialPageRoute(builder: (_) => DonorProfileEditPage(profile: DonorProfile.fromUserProfileModel(profile))),
                ).then((result) {
                  if (result == true) {
                    if (!context.mounted) return;
                    context.read<UserProfileBloc>().add(LoadUserProfile());
                    context.read<DonorProfileBloc>().add(LoadDonorProfile());
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kWhiteColor,
                foregroundColor: kErrorColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 12.h),
              ),
              child: Text('Register as Donor', style: kTextBold(color: kErrorColor)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
        child: Text(
          title,
          style: kTextSemiBold(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<_InfoItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 6))],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => Divider(height: 1, indent: 50.w, color: kGreyColor),
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(color: kGreyColor, borderRadius: BorderRadius.circular(8.r)),
                  child: Icon(item.icon, color: kGreyColor7, size: 20.sp),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
                      ),
                      Text(
                        item.value,
                        style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
                        maxLines: item.maxLines,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInitials(String name) {
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2 ? '${parts[0][0]}${parts[1][0]}'.toUpperCase() : (name.isNotEmpty ? name[0].toUpperCase() : 'U');
    return Center(
      child: Text(initials, style: kTextBold(color: kPrimaryColor)),
    );
  }

  String _maskAadhaar(String aadhaar) {
    if (aadhaar.length < 4) return aadhaar;
    final clean = aadhaar.replaceAll(' ', '');
    if (clean.length < 4) return clean;
    return 'XXXX XXXX ${clean.substring(clean.length - 4)}';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == '—') return '—';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}

class _ProfileCompletionMeter extends StatelessWidget {
  final int score;

  const _ProfileCompletionMeter({required this.score});

  Color get _barColor {
    if (score >= 80) return kSuccessColor;
    if (score >= 50) return kWarningColor;
    return kErrorColor;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(color: _barColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8.r)),
                child: Icon(Icons.person_pin_rounded, color: _barColor, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile $score% complete',
                      style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      score >= 80 ? 'Great! Profile looks good.' : 'Complete your profile for better service.',
                      style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(value: score / 100, backgroundColor: kGreyColor, color: _barColor, minHeight: 6.h),
          ),
        ],
      ),
    );
  }
}

class _DonorProfileCard extends StatelessWidget {
  final DonorProfile donor;
  final VoidCallback? onEdit;

  const _DonorProfileCard({required this.donor, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Donor Profile'),
        Container(
          decoration: BoxDecoration(
            color: kWhiteColor,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 6))],
          ),
          child: Column(
            children: [
              // ── Edit header row ──
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8.r)),
                      child: Icon(Icons.favorite_rounded, color: kErrorColor, size: 18.sp),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        'Donor Details',
                        style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
                      ),
                    ),
                    if (onEdit != null)
                      GestureDetector(
                        onTap: onEdit,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                          decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20.r)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_rounded, color: kErrorColor, size: 13.sp),
                              SizedBox(width: 4.w),
                              Text(
                                'Edit',
                                style: kTextSemiBold(color: kErrorColor).copyWith(fontSize: 11.sp),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, indent: 50.w, color: kGreyColor),
              _buildDonorRow(Icons.bloodtype_rounded, 'Blood Group', donor.bloodGroup ?? '—', kErrorColor),
              Divider(height: 1, indent: 50.w, color: kGreyColor),
              _buildDonorRow(
                Icons.event_available_rounded,
                'Availability',
                donor.isAvailable == true ? 'Available to Donate' : 'Currently Unavailable',
                donor.isAvailable == true ? kSuccessColor : kGreyColor6,
              ),
              Divider(height: 1, indent: 50.w, color: kGreyColor),
              _buildDonorRow(Icons.monitor_weight_rounded, 'Weight', donor.weightKg != null ? '${donor.weightKg} kg' : '—', kPrimaryColor),
              Divider(height: 1, indent: 50.w, color: kGreyColor),
              _buildDonorRow(
                Icons.history_rounded,
                'Last Donation',
                _formatDate(donor.lastDonationDate) == '—' ? 'No recent donations' : _formatDate(donor.lastDonationDate),
                kWarningColor,
              ),
              if (donor.preferredContactMethod != null && donor.preferredContactMethod!.isNotEmpty) ...[
                Divider(height: 1, indent: 50.w, color: kGreyColor),
                _buildDonorRow(
                  Icons.contact_phone_rounded,
                  'Contact Method',
                  '${donor.preferredContactMethod![0].toUpperCase()}${donor.preferredContactMethod!.substring(1)}',
                  kPrimaryColor,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDonorRow(IconData icon, String label, String value, Color iconColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8.r)),
            child: Icon(icon, color: iconColor, size: 20.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
                ),
                Text(
                  value,
                  style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
      child: Text(title, style: kTextSemiBold(color: kTextSecondaryColor)),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == '—') return '—';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  final int maxLines;

  _InfoItem({required this.icon, required this.label, required this.value, this.maxLines = 1});
}
