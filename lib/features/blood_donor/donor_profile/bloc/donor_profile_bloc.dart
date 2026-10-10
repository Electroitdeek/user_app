import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/repositories/blood_donation_repository.dart';
import '../data/model/donor_profile_model.dart';

part 'donor_profile_event.dart';

part 'donor_profile_state.dart';

class DonorProfileBloc extends Bloc<DonorProfileEvent, DonorProfileState> {
  final BloodDonationRepository repository;

  DonorProfileBloc(this.repository) : super(DonorProfileInitial()) {
    on<LoadDonorProfile>(_onLoadDonorProfile);
    on<UpdateDonorProfile>(_onUpdateDonorProfile);
    on<UpdateAvailability>(_onUpdateAvailability);
  }

  Future<void> _onLoadDonorProfile(LoadDonorProfile event, Emitter<DonorProfileState> emit) async {
    emit(DonorProfileLoading());
    try {
      final profile = await repository.getDonorProfile();
      emit(DonorProfileLoaded(profile));
    } catch (e) {
      emit(DonorProfileError(e.toString()));
    }
  }

  Future<void> _onUpdateDonorProfile(UpdateDonorProfile event, Emitter<DonorProfileState> emit) async {
    final currentState = state;
    if (currentState is DonorProfileLoaded) {
      emit(DonorProfileUpdating(currentState.profile));
    }

    try {
      await repository.updateDonorProfile(event.profile);
      emit(DonorProfileUpdateSuccess(event.profile));
      emit(DonorProfileLoaded(event.profile));
    } catch (e) {
      if (currentState is DonorProfileLoaded) {
        emit(DonorProfileLoaded(currentState.profile));
      }
      emit(DonorProfileError(e.toString()));
    }
  }

  Future<void> _onUpdateAvailability(UpdateAvailability event, Emitter<DonorProfileState> emit) async {
    final currentState = state;
    if (currentState is DonorProfileLoaded) {
      final updatedProfile = currentState.profile.copyWith(isAvailable: event.isAvailable);
      emit(DonorProfileLoaded(updatedProfile));
    }
  }
}
