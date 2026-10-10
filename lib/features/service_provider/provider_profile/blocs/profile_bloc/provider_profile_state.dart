part of 'provider_profile_bloc.dart';

sealed class ProviderProfileState {}

final class ProviderProfileInitial extends ProviderProfileState {}
final class ProviderProfileLoading extends ProviderProfileState {}
final class ProviderProfileLoaded extends ProviderProfileState {
  final UserProfileModel userProfileModel;

  ProviderProfileLoaded(this.userProfileModel);

}
class ProviderProfileError extends ProviderProfileState {
  final String error;

  ProviderProfileError(this.error);
}

class ProviderProfileUpdating extends ProviderProfileState {
  final UserProfileModel profile;
  ProviderProfileUpdating(this.profile);
}

class ProviderProfileUpdateSuccess extends ProviderProfileState {
  final UserProfileModel profile;
  ProviderProfileUpdateSuccess(this.profile);
}
