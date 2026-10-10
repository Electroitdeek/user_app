import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_flavor/flutter_flavor.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../di/locator.dart';

part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  static const int totalPages = 3;

  final LocalStorageService storage = locator<LocalStorageService>();
  final String role = FlavorConfig.instance.variables['role'] ?? 'user';

  OnboardingBloc() : super(OnboardingInitial()) {
    on<NextPageEvent>(_onNextPage);
    on<PreviousPageEvent>(_onPreviousPage);
    on<SkipOnboardingEvent>(_onSkip);
    on<CompleteOnboardingEvent>(_onComplete);

    // Start with first page
    add(const NextPageEvent(-1));
  }

  void _onNextPage(NextPageEvent event, Emitter<OnboardingState> emit) {
    final nextPage = event.currentPage + 1;

    if (nextPage >= totalPages) {
      storage.setOnboardingComplete(role);
      emit(OnboardingCompleted());
    } else {
      emit(OnboardingPageChanged(currentPage: nextPage, totalPages: totalPages));
    }
  }

  void _onPreviousPage(PreviousPageEvent event, Emitter<OnboardingState> emit) {
    final previousPage = event.currentPage - 1;

    if (previousPage < 0) {
      emit(OnboardingInitial());
    } else {
      emit(OnboardingPageChanged(currentPage: previousPage, totalPages: totalPages));
    }
  }

  void _onSkip(SkipOnboardingEvent event, Emitter<OnboardingState> emit) {
    storage.setOnboardingComplete(role);
    emit(OnboardingCompleted());
  }

  void _onComplete(CompleteOnboardingEvent event, Emitter<OnboardingState> emit) {
    storage.setOnboardingComplete(role);
    emit(OnboardingCompleted());
  }
}
