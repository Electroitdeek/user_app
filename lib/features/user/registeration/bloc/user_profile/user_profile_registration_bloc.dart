import 'package:adhisaat_health_care/data/repositories/auth_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../data/models/dropdown_response_model.dart';
import '../../models/user_registration_request.dart';

import '../../../../../core/services/analytics_service.dart';
import '../../../../../di/locator.dart';

part 'user_profile_registration_event.dart';
part 'user_profile_registration_state.dart';

class UserProfileRegistrationBloc extends Bloc<UserProfileRegistrationEvent, UserProfileRegistrationState> {
  final AuthRepository repository;

  UserProfileRegistrationBloc(this.repository) : super(UserProfileRegistrationInitial()) {
    on<SubmitUserProfile>((event, emit) async {
      emit(ProfileLoading());
      try {
        final result = await repository.registerUser(event.data.toJson());
        final data = result is Map ? result['data'] : null;
        final token = data is Map ? data['token']?.toString() : null;
        if (result is Map && result['success'] == true && token != null && token.isNotEmpty) {
          final user = data is Map && data['user'] is Map
              ? legacyProfileFromApiUser(Map<String, dynamic>.from(data['user'] as Map))
              : <String, dynamic>{};
          locator<AnalyticsService>().logSignUp(signUpMethod: 'password');
          emit(ProfileSuccess({'token': token, 'access_token': token, 'user': user}));
        } else if (result is Map && result['status'] == true) {
          locator<AnalyticsService>().logSignUp(signUpMethod: 'phone_otp');
          emit(ProfileSuccess(Map<String, dynamic>.from(result)));
        } else {
          emit(
            ProfileError(
              result['message'] ?? "Validation failed",
              errors: result['errors'] is Map ? Map<String, dynamic>.from(result['errors'] as Map) : null,
            ),
          );
        }
      } catch (e) {
        emit(ProfileError(e.toString()));
      } finally {
        emit(UserProfileRegistrationInitial());
      }
    });

    on<FetchDropdownData>((event, emit) async {
      emit(DropdownLoading());
      try {
        final DropdownResponse response = await repository.fetchDropdowns();

        // Extracting Maps to Lists for UI convenience
        final genders = response.data.genders;
        final experiences = response.data.totalExperience;
        final dutyTypes = response.data.dutyTypes;
        final bloodGroups = response.data.bloodGroups;
        final categories = response.data.serviceCategories;

        emit(
          DropdownLoaded(
            genders: genders,
            dutyTypes: dutyTypes,
            experiences: experiences,
            bloodGroups: bloodGroups,
            serviceCategories: categories,
          ),
        );
      } catch (e) {
        emit(const ProfileError("Something went wrong"));
      }
    });

    on<ValidateReferralCode>((event, emit) async {
      emit(ReferralCodeValidationLoading());
      try {
        final result = await repository.validateReferralCode(event.code, userType: 'customer');
        final bool isSuccess =
            result['success'] == true ||
            result['success'] == 'true' ||
            result['status'] == true ||
            result['status'] == 'true';

        if (isSuccess) {
          final data = result['data'] ?? {};
          final referredId = data['referred_by_id'] ?? result['referred_by_id'];
          emit(ReferralCodeValidated(int.tryParse(referredId.toString()) ?? 0, 'Referral code applied'));
        } else {
          emit(ReferralCodeInvalid(result['message'] ?? 'Invalid referral code'));
        }
      } catch (e) {
        emit(const ReferralCodeInvalid("Something went wrong"));
      }
    });
  }
}
