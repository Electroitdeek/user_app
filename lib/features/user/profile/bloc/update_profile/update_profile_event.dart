part of 'update_profile_bloc.dart';

abstract class UpdateProfileEvent {}

class SubmitUpdateProfile extends UpdateProfileEvent {
  final String name;
  final String mobileNumber;
  final String? whatsappNumber;
  final String? email;
  final String? dateOfBirth;
  final String? bloodGroup;
  final String? gender;
  final String? emergencyContactName;
  final String? emergencyContactNumber;
  final String? aadharNo;
  final String? panNumber;
  final File? profileImage;
  final File? aadharFile;
  final File? panFile;

  SubmitUpdateProfile({
    required this.name,
    required this.mobileNumber,
    this.whatsappNumber,
    this.email,
    this.dateOfBirth,
    this.bloodGroup,
    this.gender,
    this.emergencyContactName,
    this.emergencyContactNumber,
    this.aadharNo,
    this.panNumber,
    this.profileImage,
    this.aadharFile,
    this.panFile,
  });
}