part of 'otp_bloc.dart';

@immutable
sealed class OtpState {}

final class OtpInitial extends OtpState {}

final class OtpLoading extends OtpState {}

final class OtpResent extends OtpState {}

final class AfterSuccessfulOtpVerification extends OtpState {
  final String mobile;
  final bool isNewUser;
  final Map<String, dynamic> data;

  AfterSuccessfulOtpVerification(this.mobile, {required this.isNewUser, required this.data});
}

final class OtpVerifyError extends OtpState {
  final String message;
  final bool isBlocked;

  OtpVerifyError(this.message, {this.isBlocked = false});
}
