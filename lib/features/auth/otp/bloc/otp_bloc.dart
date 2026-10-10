import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/app_exception.dart';
import '../../../../core/constants/error_constants.dart';
import '../../../../data/repositories/auth_repository.dart';

part 'otp_event.dart';
part 'otp_state.dart';

class OtpBloc extends Bloc<OtpEvent, OtpState> {
  final AuthRepository repository;

  OtpBloc(this.repository) : super(OtpInitial()) {
    on<VerifyOtpEvent>((event, emit) async {
      emit(OtpLoading());
      try {
        final result = await repository.verifyOtp(mobile: event.mobile, otp: event.otp);
        if (result['success'] == true || result['status'] == true) {
          bool isNewUser = result['is_new_user'] == true || result['user'] == null;

          emit(AfterSuccessfulOtpVerification(event.mobile, isNewUser: isNewUser, data: result));
        } else {
          emit(OtpVerifyError(result['message'] ?? ErrorConstants.defaultError));
        }
      } on AppException catch (e) {
        emit(OtpVerifyError(e.toString()));
      }
    });

    on<ResendOtpEvent>(_onResendOtp);
  }

  Future<void> _onResendOtp(ResendOtpEvent event, Emitter<OtpState> emit) async {
    emit(OtpLoading());
    try {
      final result = await repository.sendOtp(mobile: event.mobile, isResend: true);

      final bool isBlocked = result['is_blocked'] == true ||
          result['is_blocked'] == 'true' ||
          result['is_blocked'] == 1 ||
          (result['message']?.toString().toLowerCase().contains('blocked') ?? false);

      final bool isExplicitFailure = result['success'] == false ||
          result['success'] == 'false' ||
          result['status'] == false ||
          result['status'] == 'false' ||
          isBlocked;

      final bool isSuccess = (result['success'] == true ||
              result['success'] == 'true' ||
              result['status'] == true ||
              result['status'] == 'true') &&
          !isExplicitFailure;

      if (isSuccess) {
        emit(OtpResent());
      } else {
        String apiMessage = result['message']?.toString() ?? ErrorConstants.defaultError;

        // Mask 404 framework errors (e.g. Route not found)
        if (apiMessage.toLowerCase().contains('could not be found') ||
            apiMessage.toLowerCase().contains('not found')) {
          apiMessage = ErrorConstants.defaultError;
        }

        emit(OtpVerifyError(apiMessage, isBlocked: isBlocked));
      }
    } catch (e) {
      String errorMessage = e.toString().replaceAll('Exception: ', '');

      // Mask 404 framework errors
      if (errorMessage.toLowerCase().contains('could not be found') ||
          errorMessage.toLowerCase().contains('not found')) {
        errorMessage = ErrorConstants.defaultError;
      }

      emit(OtpVerifyError(errorMessage));
    }
  }
}
