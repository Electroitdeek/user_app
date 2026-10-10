part of 'provider_profile_registration_bloc.dart';

sealed class ProviderProfileRegistrationState extends Equatable {
  const ProviderProfileRegistrationState();

  @override
  List<Object> get props => [];
}

final class ProviderProfileInitial extends ProviderProfileRegistrationState {}

class ProfileInitial extends ProviderProfileRegistrationState {}

class ProfileLoading extends ProviderProfileRegistrationState {}

class ProfileSuccess extends ProviderProfileRegistrationState {
  final Map<String, dynamic> data;

  const ProfileSuccess(this.data);
}

class ProfileError extends ProviderProfileRegistrationState {
  final String message;
  final Map<String, dynamic>? errors;

  const ProfileError(this.message, {this.errors});

  @override
  List<Object> get props => [message, ?errors];
}

class DropdownLoading extends ProviderProfileRegistrationState {}

class DropdownLoaded extends ProviderProfileRegistrationState {
  final Map<String, String> genders, experiences, dutyTypes, bloodGroups, documentType;
  final List<ServiceCategory> serviceCategories;
  final List<DynamicDocumentType> dynamicDocumentTypes;

  const DropdownLoaded({
    required this.genders,
    required this.experiences,
    required this.dutyTypes,
    required this.serviceCategories,
    required this.bloodGroups,
    required this.documentType,
    required this.dynamicDocumentTypes,
  });
}

class DropdownError extends ProviderProfileRegistrationState {
  final String message;

  const DropdownError(this.message);
}

class ServiceAvailabilityChecking extends ProviderProfileRegistrationState {}

class ServiceAvailabilityLoaded extends ProviderProfileRegistrationState {
  final List<ServiceCategory> serviceCategories;
  final int? cityAdminId;

  const ServiceAvailabilityLoaded(this.serviceCategories, {this.cityAdminId});

  @override
  List<Object> get props => [serviceCategories];
}

class ServiceAvailabilityUnavailable extends ProviderProfileRegistrationState {
  final String message;

  const ServiceAvailabilityUnavailable(this.message);

  @override
  List<Object> get props => [message];
}

class ConsentLoading extends ProviderProfileRegistrationState {}

class ConsentLoaded extends ProviderProfileRegistrationState {
  final List<dynamic> consents;

  const ConsentLoaded(this.consents);

  @override
  List<Object> get props => [consents];
}

class ConsentError extends ProviderProfileRegistrationState {
  final String message;

  const ConsentError(this.message);

  @override
  List<Object> get props => [message];
}

class ReferralCodeValidationLoading extends ProviderProfileRegistrationState {}

class ReferralCodeValidated extends ProviderProfileRegistrationState {
  final String message;
  final dynamic referredById;

  const ReferralCodeValidated(this.message, this.referredById);

  @override
  List<Object> get props => [message, referredById];
}

class ReferralCodeInvalid extends ProviderProfileRegistrationState {
  final String message;

  const ReferralCodeInvalid(this.message);

  @override
  List<Object> get props => [message];
}
