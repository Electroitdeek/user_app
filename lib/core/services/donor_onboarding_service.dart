import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/data/models/user_profile_model.dart';
import 'package:adhisaat_health_care/features/blood_donor/donor_profile/data/model/donor_profile_model.dart';
import 'package:adhisaat_health_care/features/blood_donor/donor_profile_register/view/donor_profile_register_page.dart';
import 'package:flutter/material.dart';

class DonorOnboardingService {
  static bool _hasShownInSession = false;

  /// Main function to check donor status and show prompt if needed
  static void checkAndShowDonorRequest(
    BuildContext context,
    UserProfileModel profile,
  ) {
    if (profile.isDonor || _hasShownInSession) return;

    _hasShownInSession = true;

    Future.delayed(const Duration(seconds: 2), () {
      if (context.mounted) {
        _showWarmRequestDialog(context, profile);
      }
    });
  }

  static void _showWarmRequestDialog(BuildContext context, UserProfileModel profile) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _DonorRecruitmentDialog(profile: profile),
    );
  }
}

class _DonorRecruitmentDialog extends StatefulWidget {
  final UserProfileModel profile;
  const _DonorRecruitmentDialog({required this.profile});

  @override
  State<_DonorRecruitmentDialog> createState() =>
      _DonorRecruitmentDialogState();
}

class _DonorRecruitmentDialogState extends State<_DonorRecruitmentDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: AspectRatio(
          aspectRatio: 0.75, // Making it a tall, large dialog
          child: Stack(
            children: [
              // Red Gradient Background
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFF44336),
                      Color(0xFFD32F2F),
                      Color(0xFFB71C1C),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

              // Animated Background Elements (Blood Drops)
              ...List.generate(15, (index) {
                return _AnimatedBloodDrop(
                  controller: _controller,
                  index: index,
                );
              }),

              // Close Button
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ),

              // Main Content
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    // Central Icon with Pulse
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.85, end: 1.0),
                      duration: const Duration(seconds: 2),
                      curve: Curves.easeInOutSine,
                      builder: (context, value, child) {
                        return Transform.scale(scale: value, child: child);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.volunteer_activism_rounded,
                          color: Colors.white,
                          size: 64,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Save a Life Today',
                      style: kTextBold1().copyWith(
                        color: Colors.white,
                        fontSize: 26,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your single blood donation can save up to three lives. Join our community of superheroes today.',
                      style: kTextNormal().copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    // Actions
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DonorProfileEditPage(
                                profile: DonorProfile.fromUserProfileModel(
                                  widget.profile,
                                ),
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFD32F2F),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Register as Donor',
                          style: kTextSemiBold1().copyWith(fontSize: 17),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Maybe later',
                        style: kTextNormal().copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
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
}

class _AnimatedBloodDrop extends StatelessWidget {
  final AnimationController controller;
  final int index;

  const _AnimatedBloodDrop({required this.controller, required this.index});

  @override
  Widget build(BuildContext context) {
    // Adjusted for dialog size
    final double startLeft = (index * 60) % 300.0;
    final double delay = (index * 0.5) % 5.0;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        double progress = (controller.value + (delay / 10.0)) % 1.0;
        return Positioned(
          left: startLeft,
          top: -30 + 500 * progress, // Simplified vertical height for dialog
          child: Opacity(
            opacity: 0.1 + (0.2 * (1.0 - progress)),
            child: Transform.rotate(
              angle: progress * 6.28,
              child: const Icon(
                Icons.water_drop_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        );
      },
    );
  }
}
