import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/data/repositories/auth_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../data/models/dropdown_response_model.dart';
import '../../models/provider_profile_model.dart';

import '../../../../../core/services/analytics_service.dart';
import '../../../../../di/locator.dart';

part 'provider_profile_registration_event.dart';
part 'provider_profile_registration_state.dart';

class ProviderProfileRegistrationBloc
    extends Bloc<ProviderProfileRegistrationEvent, ProviderProfileRegistrationState> {
  final AuthRepository repository;

  ProviderProfileRegistrationBloc(this.repository) : super(ProviderProfileInitial()) {
    on<SubmitProviderProfile>((event, emit) async {
      emit(ProfileLoading());
      try {
        // Build FormData asynchronously — handles MultipartFile for document uploads
        final formData = await event.data.toFormData();
        final result = await repository.registerProvider(formData);
        if (result['success'] == true || result['status'] == true) {
          locator<AnalyticsService>().logSignUp(signUpMethod: 'phone_otp');
          emit(ProfileSuccess(result));
        } else {
          final errors = result['errors'] as Map<String, dynamic>?;
          emit(ProfileError(result['message']?.toString() ?? 'Registration failed', errors: errors));
        }
      } catch (e) {
        emit(ProfileError(e.toString()));
      } finally {
        emit(ProviderProfileInitial());
      }
    });

    on<FetchDropdownData>((event, emit) async {
      emit(DropdownLoading());
      try {
        final DropdownResponse response = await repository.fetchDropdowns();
        emit(
          DropdownLoaded(
            genders: response.data.genders,
            dutyTypes: response.data.dutyTypes,
            experiences: response.data.totalExperience,
            bloodGroups: response.data.bloodGroups,
            serviceCategories: response.data.serviceCategories,
            documentType: response.data.documentTypes,
            dynamicDocumentTypes: response.data.dynamicDocumentTypes,
          ),
        );
      } catch (e) {
        emit(ProfileError(e.toString()));
      }
    });

    on<CheckServiceAvailability>((event, emit) async {
      // Always emit a checking state first so BLoC sees a real state transition
      // on every PIN change — prevents the Equatable equality issue where
      // two identical error results appear as the same state and the listener
      // never fires a second time.
      emit(ServiceAvailabilityChecking());
      try {
        final response = await repository.checkServiceAvailability(
          event.zipcode,
          excludeManMachineServices: true,
        );
        kPrint(response);
        if (response.status && response.data != null) {
          emit(
            ServiceAvailabilityLoaded(response.data!.serviceCategories, cityAdminId: response.data!.cityAdmin?.id),
          );
        } else {
          emit(
            ServiceAvailabilityUnavailable(
              response.message.isNotEmpty ? response.message : 'Services are not available in this area.',
            ),
          );
        }
      } catch (e) {
        kPrintError("Error checking service availability: $e");
      }
    });

    on<FetchConsent>((event, emit) async {
      emit(ConsentLoading());
      try {
        final response = await repository.fetchConsents(event.consentType);
        if (response['status'] == true) {
          emit(ConsentLoaded(response['data'] ?? []));
        } else {
          emit(ConsentError(response['message'] ?? 'Failed to fetch consent'));
        }
      } catch (e) {
        emit(ConsentError(e.toString()));
      }
    });

    on<ValidateReferralCode>((event, emit) async {
      emit(ReferralCodeValidationLoading());
      try {
        final result = await repository.validateReferralCode(event.code, userType: 'service_provider');
        final bool isSuccess =
            result['success'] == true ||
            result['success'] == 'true' ||
            result['status'] == true ||
            result['status'] == 'true';

        if (isSuccess) {
          final data = result['data'] ?? {};
          final referredId = data['referred_by_id'] ?? result['referred_by_id'];
          emit(ReferralCodeValidated('Referral code applied', referredId));
        } else {
          emit(ReferralCodeInvalid(result['message'] ?? 'Invalid referral code'));
        }
      } catch (e) {
        emit(ReferralCodeInvalid(e.toString()));
      }
    });
  }
}
