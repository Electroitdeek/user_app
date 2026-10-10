part of 'otp_bloc.dart';

@immutable
sealed class OtpEvent {}

class VerifyOtpEvent extends OtpEvent {
  final String otp;
  final String mobile;

  VerifyOtpEvent(this.otp, this.mobile);
}

class ResendOtpEvent extends OtpEvent {
  final String mobile;

  ResendOtpEvent(this.mobile);
}
