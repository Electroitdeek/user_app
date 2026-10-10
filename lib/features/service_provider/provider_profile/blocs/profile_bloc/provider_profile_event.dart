part of 'provider_profile_bloc.dart';

sealed class ProviderProfileEvent {}

class LoadProviderProfile extends ProviderProfileEvent {}

class UpdateProviderProfile extends ProviderProfileEvent {
  final ProviderProfileModel profile;
  final File? profileImage;
  final File? aadharFile;
  final File? panFile;
  final List<String>? skills;

  UpdateProviderProfile({
    required this.profile,
    this.profileImage,
    this.aadharFile,
    this.panFile,
    this.skills,
  });
}

