import 'dart:io';

import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/data/models/provider_models/provider_profile_payload_model.dart';
import 'package:adhisaat_health_care/data/repositories/provider_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../data/models/user_profile_model.dart';

part 'provider_profile_event.dart';
part 'provider_profile_state.dart';

class ProviderProfileBloc extends Bloc<ProviderProfileEvent, ProviderProfileState> {
  final ProviderRepository repository;

  ProviderProfileBloc({required this.repository}) : super(ProviderProfileInitial()) {
    on<LoadProviderProfile>(_onLoadProviderProfile);
    on<UpdateProviderProfile>(_onUpdateProviderProfile);
  }

  Future<void> _onLoadProviderProfile(LoadProviderProfile event, Emitter<ProviderProfileState> emit) async {
    emit(ProviderProfileLoading());
    try {
      final profile = await repository.getProfile();
      emit(ProviderProfileLoaded(profile));
    } catch (e) {
      emit(ProviderProfileError(e.toString()));
    }
  }

  Future<void> _onUpdateProviderProfile(
      UpdateProviderProfile event,
      Emitter<ProviderProfileState> emit,
      ) async {
    final currentState = state;
    if (currentState is ProviderProfileLoaded) {
      emit(ProviderProfileUpdating(currentState.userProfileModel));
    }

    try {
      final response = await repository.updateProfile(
        profile: event.profile,
        profileImage: event.profileImage,
        aadharFile: event.aadharFile,
        panFile: event.panFile,
        skills: event.skills,
      );
      kPrint(response);

      if (response['status'] == true || response['success'] == true) {
        final updatedProfile = await repository.getProfile();
        emit(ProviderProfileUpdateSuccess(updatedProfile));
        emit(ProviderProfileLoaded(updatedProfile));
      } else {
        emit(ProviderProfileError(response['message'] ?? 'Failed to update profile'));
        if (currentState is ProviderProfileLoaded) {
          emit(ProviderProfileLoaded(currentState.userProfileModel));
        }
      }
    } catch (e) {
      if (currentState is ProviderProfileLoaded) {
        emit(ProviderProfileError(e.toString()));
        emit(ProviderProfileLoaded(currentState.userProfileModel));
      } else {
        emit(ProviderProfileError(e.toString()));
      }
    }
  }
}
