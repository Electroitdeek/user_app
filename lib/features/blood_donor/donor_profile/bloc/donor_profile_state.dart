part of 'donor_profile_bloc.dart';


abstract class DonorProfileState extends Equatable {
  const DonorProfileState();

  @override
  List<Object?> get props => [];
}

class DonorProfileInitial extends DonorProfileState {}

class DonorProfileLoading extends DonorProfileState {}

class DonorProfileLoaded extends DonorProfileState {
  final DonorProfile profile;

  const DonorProfileLoaded(this.profile);

  @override
  List<Object?> get props => [profile];
}

class DonorProfileUpdating extends DonorProfileState {
  final DonorProfile currentProfile;

  const DonorProfileUpdating(this.currentProfile);

  @override
  List<Object?> get props => [currentProfile];
}

class DonorProfileUpdateSuccess extends DonorProfileState {
  final DonorProfile profile;

  const DonorProfileUpdateSuccess(this.profile);

  @override
  List<Object?> get props => [profile];
}

class DonorProfileError extends DonorProfileState {
  final String message;

  const DonorProfileError(this.message);

  @override
  List<Object?> get props => [message];
}