part of 'donor_profile_bloc.dart';

abstract class DonorProfileEvent extends Equatable {
  const DonorProfileEvent();

  @override
  List<Object?> get props => [];
}

class LoadDonorProfile extends DonorProfileEvent {

  const LoadDonorProfile();

  @override
  List<Object?> get props => [];
}

class UpdateDonorProfile extends DonorProfileEvent {
  final DonorProfile profile;

  const UpdateDonorProfile( this.profile);

  @override
  List<Object?> get props => [ profile];
}

class UpdateAvailability extends DonorProfileEvent {
  final bool isAvailable;

  const UpdateAvailability(this.isAvailable);

  @override
  List<Object?> get props => [isAvailable];
}
