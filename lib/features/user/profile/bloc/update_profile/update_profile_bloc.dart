import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/api/app_exception.dart';
import '../../../../../data/models/user_profile_model.dart';
import '../../data/user_profile_repository.dart';

part 'update_profile_event.dart';
part 'update_profile_state.dart';

class UpdateProfileBloc extends Bloc<UpdateProfileEvent, UpdateProfileState> {
  final UserProfileRepository _repository;

  UpdateProfileBloc(this._repository) : super(UpdateProfileInitial()) {
    on<SubmitUpdateProfile>(_onSubmit);
  }

  Future<void> _onSubmit(SubmitUpdateProfile event, Emitter<UpdateProfileState> emit) async {
    emit(UpdateProfileLoading());
    try {
      final profile = await _repository.updateProfile(
        name: event.name,
        mobileNumber: event.mobileNumber,
        whatsappNumber: event.whatsappNumber,
        email: event.email,
        dateOfBirth: event.dateOfBirth,
        bloodGroup: event.bloodGroup,
        gender: event.gender,
        emergencyContactName: event.emergencyContactName,
        emergencyContactNumber: event.emergencyContactNumber,
        aadharNo: event.aadharNo,
        panNumber: event.panNumber,
        profileImage: event.profileImage,
        aadharFile: event.aadharFile,
        panFile: event.panFile,
      );
      emit(UpdateProfileSuccess(profile));
    } on AppException catch (e) {
      emit(UpdateProfileError(e.message, errors: e.errors));
    } catch (e) {
      emit(UpdateProfileError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
