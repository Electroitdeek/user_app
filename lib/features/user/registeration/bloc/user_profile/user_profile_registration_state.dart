part of 'user_profile_registration_bloc.dart';

sealed class UserProfileRegistrationState extends Equatable {
  const UserProfileRegistrationState();

  @override
  List<Object> get props => [];
}

final class UserProfileRegistrationInitial extends UserProfileRegistrationState {}

class ProfileInitial extends UserProfileRegistrationState {}

class ProfileLoading extends UserProfileRegistrationState {}

class ProfileSuccess extends UserProfileRegistrationState {
  final Map<String, dynamic> data;

  const ProfileSuccess(this.data);
}

class ProfileError extends UserProfileRegistrationState {
  final String message;
  final Map<String, dynamic>? errors;

  const ProfileError(this.message, {this.errors});

  @override
  List<Object> get props => [message, errors ?? {}];
}

class DropdownLoading extends UserProfileRegistrationState {}

class DropdownLoaded extends UserProfileRegistrationState {
  final Map<String, String> genders, experiences, dutyTypes, bloodGroups;
  final List<ServiceCategory> serviceCategories;

  const DropdownLoaded({
    required this.genders,
    required this.experiences,
    required this.dutyTypes,
    required this.serviceCategories,
    required this.bloodGroups,
  });
}

class DropdownError extends UserProfileRegistrationState {
  final String message;

  const DropdownError(this.message);
}

class ReferralCodeValidationLoading extends UserProfileRegistrationState {}

class ReferralCodeValidated extends UserProfileRegistrationState {
  final int referredById;
  final String message;
  const ReferralCodeValidated(this.referredById, this.message);

  @override
  List<Object> get props => [referredById, message];
}

class ReferralCodeInvalid extends UserProfileRegistrationState {
  final String message;
  const ReferralCodeInvalid(this.message);

  @override
  List<Object> get props => [message];
}
