part of 'onboarding_bloc.dart';
class OnboardingInitial extends OnboardingState {}

/// Showing specific page
class OnboardingPageChanged extends OnboardingState {
  final int currentPage;
  final int totalPages;

  const OnboardingPageChanged({
    required this.currentPage,
    required this.totalPages,
  });

  bool get isLastPage => currentPage == totalPages - 1;

  @override
  List<Object?> get props => [currentPage, totalPages];
}

/// Onboarding completed - navigate to phone number screen
class OnboardingCompleted extends OnboardingState {}
