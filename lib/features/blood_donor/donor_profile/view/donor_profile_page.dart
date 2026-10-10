import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/repositories/blood_donation_repository.dart';
import '../../../../shared/widgets/common/custom_refresh_indicator.dart';
import '../../donor_profile_register/view/donor_profile_register_page.dart';
import '../bloc/donor_profile_bloc.dart';
import '../data/model/donor_profile_model.dart';

class DonorProfilePage extends StatefulWidget {
  const DonorProfilePage({super.key});

  @override
  State<DonorProfilePage> createState() => _DonorProfilePageState();
}

class _DonorProfilePageState extends State<DonorProfilePage> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DonorProfileBloc(locator<BloodDonationRepository>())..add(LoadDonorProfile()),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: CustomAppBar(
          title: 'Donor Profile',
          actions: [
            BlocBuilder<DonorProfileBloc, DonorProfileState>(
              builder: (context, state) {
                if (state is DonorProfileLoaded) {
                  return IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _navigateToEdit(state.profile, context),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        body: BlocConsumer<DonorProfileBloc, DonorProfileState>(
          listener: (context, state) {
            if (state is DonorProfileError) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
            }
          },
          builder: (context, state) {
            if (state is DonorProfileLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is DonorProfileLoaded) {
              return _buildProfileContent(state.profile, context);
            }

            if (state is DonorProfileError) {
              return _buildErrorView(state.message);
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildProfileContent(DonorProfile profile, BuildContext context) {
    return CustomRefreshIndicator(
      onRefresh: () async {
        context.read<DonorProfileBloc>().add(LoadDonorProfile());
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeaderCard(profile),
            const SizedBox(height: 16),
            _buildAvailabilityCard(profile),
            const SizedBox(height: 16),
            _buildPersonalInfoCard(profile),
            const SizedBox(height: 16),
            _buildContactPreferencesCard(profile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(DonorProfile profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[400]!, Colors.red[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            child: Text(profile.bloodGroup ?? 'N/A', style: kHeadingLarge().copyWith(color: Colors.red[600])),
          ),
          const SizedBox(height: 16),
          Text(profile.name ?? 'Guest User', style: kTextBold2().copyWith(color: Colors.white)),
          const SizedBox(height: 4),
          Text(profile.email ?? '', style: kTextNormal().copyWith(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(profile.mobile ?? '', style: kTextNormal().copyWith(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard(DonorProfile profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (profile.isAvailable ?? false) ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              (profile.isAvailable ?? false) ? Icons.check_circle : Icons.cancel,
              color: (profile.isAvailable ?? false) ? Colors.green : Colors.red,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Availability Status', style: kTextMedium1()),
                const SizedBox(height: 4),
                Text(
                  (profile.isAvailable ?? false) ? 'Available for donation' : 'Not available',
                  style: kTextNormal0().copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(
            value: profile.isAvailable ?? false,
            onChanged: (value) {
              final updatedProfile = profile.copyWith(isAvailable: value);
              context.read<DonorProfileBloc>().add(UpdateDonorProfile(updatedProfile));
            },
            activeThumbColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard(DonorProfile profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal Information', style: kTextSemiBold1()),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.cake, 'Date of Birth', profile.dateOfBirth ?? 'N/A'),
          _buildInfoRow(Icons.person, 'Gender', profile.gender ?? 'N/A'),
          _buildInfoRow(
            Icons.fitness_center,
            'Weight',
            profile.weightKg != null ? '${profile.weightKg} kg' : 'N/A',
          ),
          _buildInfoRow(Icons.location_city, 'City', profile.city ?? 'N/A'),
          _buildInfoRow(Icons.location_on, 'State', profile.state ?? 'N/A'),
          if (profile.lastDonationDate != null)
            _buildInfoRow(Icons.calendar_today, 'Last Donation', profile.lastDonationDate!),
        ],
      ),
    );
  }

  Widget _buildContactPreferencesCard(DonorProfile profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contact Preferences', style: kTextSemiBold1()),
          const SizedBox(height: 16),
          _buildPreferenceRow(Icons.message, 'Preferred Contact', profile.preferredContactMethod ?? 'N/A'),
          _buildPreferenceRow(
            Icons.visibility,
            'Show Contact Publicly',
            (profile.showContactPublicly ?? false) ? 'Yes' : 'No',
          ),
          _buildPreferenceRow(
            Icons.notifications,
            'Receive Notifications',
            (profile.receiveNotifications ?? false) ? 'Yes' : 'No',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: kTextNormal0().copyWith(color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text(value, style: kTextMedium()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: kTextNormal())),
          Text(value, style: kTextMedium()),
        ],
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(message, style: kTextNormal()),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              context.read<DonorProfileBloc>().add(LoadDonorProfile());
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _navigateToEdit(DonorProfile profile, BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DonorProfileEditPage(profile: profile)),
    );

    if (result == true) {
      if (!context.mounted) return;
      context.read<DonorProfileBloc>().add(LoadDonorProfile());
    }
  }
}
