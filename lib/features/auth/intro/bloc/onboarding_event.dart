part of 'onboarding_bloc.dart';

abstract class OnboardingState extends Equatable {
  const OnboardingState();

  @override
  List<Object?> get props => [];
}

abstract class OnboardingEvent extends Equatable {
  const OnboardingEvent();

  @override
  List<Object?> get props => [];
}

/// User navigates to next screen
class NextPageEvent extends OnboardingEvent {
  final int currentPage;

  const NextPageEvent(this.currentPage);

  @override
  List<Object?> get props => [currentPage];
}

/// User taps skip button
class SkipOnboardingEvent extends OnboardingEvent {}

/// User goes to previous screen
class PreviousPageEvent extends OnboardingEvent {
  final int currentPage;

  const PreviousPageEvent(this.currentPage);

  @override
  List<Object?> get props => [currentPage];
}

/// Onboarding completed
class CompleteOnboardingEvent extends OnboardingEvent {}
