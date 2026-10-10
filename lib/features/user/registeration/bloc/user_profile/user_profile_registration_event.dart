part of 'user_profile_registration_bloc.dart';

sealed class UserProfileRegistrationEvent extends Equatable {
  const UserProfileRegistrationEvent();
}

class SubmitUserProfile extends UserProfileRegistrationEvent {
  final UserRegistrationRequest data;

  const SubmitUserProfile(this.data);

  @override
  List<Object?> get props => [data];
}

class FetchDropdownData extends UserProfileRegistrationEvent {
  @override
  List<Object?> get props => [];
}

class ValidateReferralCode extends UserProfileRegistrationEvent {
  final String code;
  const ValidateReferralCode(this.code);

  @override
  List<Object?> get props => [code];
}
