import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/theme/app_edge_insets.dart';
import '../../../../../core/theme/screen_dimensions.dart';

class OnboardingHeader extends StatelessWidget {
  final bool showSkip;
  final VoidCallback? onSkip;

  const OnboardingHeader({
    super.key,
    this.showSkip = false,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppPadding.symmetric(h: 20, v: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/logo/ic_logo_clear.png',
                height: AppSize.height(32),
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.health_and_safety,
                  color: kPrimaryColor,
                  size: AppIconSize.l,
                ),
              ),
              AppSpacing.sHorizontal,
              Text(
                'Adhisaat',
                style: kHeadingSmall().copyWith(
                  color: kPrimaryColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          if (showSkip)
            TextButton(
              onPressed: onSkip,
              child: Text(
                'Skip',
                style: kTextMedium2().copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const FeatureChip({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppPadding.symmetric(h: 16, v: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9).withValues(alpha: 0.8),
        borderRadius: AppRadius.xl,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.xs, color: kPrimaryColor),
          AppSpacing.sHorizontal,
          Text(
            label,
            style: kTextMedium().copyWith(
              color: const Color(0xFF334155),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;

  const PremiumButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor,
          foregroundColor: Colors.white,
          minimumSize: Size(double.infinity, AppButtonHeight.xl),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.circular(100),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: kTextBold2().copyWith(color: Colors.white),
            ),
            if (icon != null) ...[
              AppSpacing.mHorizontal,
              Icon(icon, size: AppIconSize.m),
            ],
          ],
        ),
      ),
    );
  }
}

class OnboardingPageIndicator extends StatelessWidget {
  final int currentIndex;
  final int totalPages;

  const OnboardingPageIndicator({
    super.key,
    required this.currentIndex,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        totalPages,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: AppPadding.xsHorizontal,
          width: index == currentIndex ? AppSize.width(32) : AppSize.width(10),
          height: AppSize.height(8),
          decoration: BoxDecoration(
            color: index == currentIndex
                ? kPrimaryColor
                : kPrimaryColor.withValues(alpha: 0.2),
            borderRadius: AppRadius.s,
          ),
        ),
      ),
    );
  }
}

class ProfessionalCard extends StatelessWidget {
  final String imagePath;
  final String name;
  final String role;
  final double rating;

  const ProfessionalCard({
    super.key,
    required this.imagePath,
    required this.name,
    required this.role,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppPadding.l,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.xxl,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppRadius.xl,
            child: Image.asset(
              imagePath,
              height: AppSize.height(240),
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: AppSize.height(240),
                color: const Color(0xFFF1F5F9),
                child: Icon(Icons.person, size: AppSize.font(80), color: const Color(0xFF94A3B8)),
              ),
            ),
          ),
          AppSpacing.xxlVertical,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: kHeadingSmall().copyWith(
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: AppPadding.symmetric(h: 10, v: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: AppRadius.s,
                ),
                child: Row(
                  children: [
                    Icon(Icons.star_rounded, color: kPrimaryColor, size: AppIconSize.xs),
                    AppSpacing.xsHorizontal,
                    Text(
                      rating.toString(),
                      style: kTextBold().copyWith(color: kPrimaryColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.xsVertical,
          Text(
            role,
            style: kTextMedium2().copyWith(color: const Color(0xFF64748B)),
          ),
          AppSpacing.lVertical,
          const Divider(color: Color(0xFFF1F5F9)),
          AppSpacing.lVertical,
          Row(
            children: [
              Container(
                padding: AppPadding.s,
                decoration: const BoxDecoration(
                  color: kPrimaryColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.verified_rounded, color: Colors.white, size: AppIconSize.xs),
              ),
              AppSpacing.sHorizontal,
              Text(
                'BACKGROUND VERIFIED',
                style: kTextBold0().copyWith(
                  color: kPrimaryColor,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
