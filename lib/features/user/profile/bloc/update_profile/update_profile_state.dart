part of 'update_profile_bloc.dart';

abstract class UpdateProfileState {}

class UpdateProfileInitial extends UpdateProfileState {}

class UpdateProfileLoading extends UpdateProfileState {}

class UpdateProfileSuccess extends UpdateProfileState {
  final UserProfileModel profile;
  final String message;
  UpdateProfileSuccess(this.profile, {this.message = 'Profile updated successfully!'});
}

class UpdateProfileError extends UpdateProfileState {
  final String message;
  final Map<String, dynamic>? errors;
  UpdateProfileError(this.message, {this.errors});
}