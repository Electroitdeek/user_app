part of 'user_profile_bloc.dart';

sealed class UserState {}

class UserInitial extends UserState {}

class UserLoading extends UserState {}

class UserLoaded extends UserState {
  final UserProfileModel user;

  UserLoaded(this.user);
}

class UserError extends UserState {
  final String message;

  UserError(this.message);
}
