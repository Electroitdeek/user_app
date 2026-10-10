import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:flutter/material.dart';

import 'provider_onboarding_page.dart';
import 'user_onboarding_page.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppConstants.isProviderApp) {
      return const ProviderOnboardingPage();
    } else {
      return const UserOnboardingPage();
    }
  }
}
