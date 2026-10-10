part of 'user_profile_bloc.dart';

sealed class UserEvent {}

class LoadUserProfile extends UserEvent {
  final bool forceRefresh;

  LoadUserProfile({this.forceRefresh = false});
}

class RefreshUserProfile extends UserEvent {}

class UpdateUserProfile extends UserEvent {
  final UserProfileModel user;

  UpdateUserProfile(this.user);
}
