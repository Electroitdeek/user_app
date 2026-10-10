import 'package:flutter/material.dart';
import 'package:flutter_flavor/flutter_flavor.dart';
import 'user_onboarding_page.dart';
import 'provider_onboarding_page.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine the onboarding flow based on the flavor role
    final role = FlavorConfig.instance.variables['role'];

    if (role == 'provider') {
      return const ProviderOnboardingPage();
    } else {
      return const UserOnboardingPage();
    }
  }
}
