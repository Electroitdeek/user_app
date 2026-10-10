part of 'provider_profile_registration_bloc.dart';

sealed class ProviderProfileRegistrationEvent extends Equatable {
  const ProviderProfileRegistrationEvent();
}

class SubmitProviderProfile extends ProviderProfileRegistrationEvent {
  final ProviderProfileRequest data;

  const SubmitProviderProfile(this.data);

  @override
  List<Object?> get props => [data];
}

class FetchDropdownData extends ProviderProfileRegistrationEvent {
  @override
  List<Object?> get props => [];
}

class CheckServiceAvailability extends ProviderProfileRegistrationEvent {
  final String zipcode;

  const CheckServiceAvailability(this.zipcode);

  @override
  List<Object?> get props => [zipcode];
}

class FetchConsent extends ProviderProfileRegistrationEvent {
  final String consentType;

  const FetchConsent(this.consentType);

  @override
  List<Object?> get props => [consentType];
}

class ValidateReferralCode extends ProviderProfileRegistrationEvent {
  final String code;

  const ValidateReferralCode(this.code);

  @override
  List<Object?> get props => [code];
}
