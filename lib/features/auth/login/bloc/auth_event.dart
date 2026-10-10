part of 'auth_bloc.dart';

abstract class AuthEvent {}

class SendOtpEvent extends AuthEvent {
  final String mobile;
  final bool isResend;

  SendOtpEvent(this.mobile, {this.isResend = false});
}

class LoginWithPasswordEvent extends AuthEvent {
  final String identifier;
  final String password;

  LoginWithPasswordEvent({required this.identifier, required this.password});
}

class UpdateFcmTokenEvent extends AuthEvent {
  final String token;

  UpdateFcmTokenEvent(this.token);
}

class LoginSuccess extends AuthEvent {
  final UserProfileModel user;
  final String token;

  LoginSuccess({required this.user, required this.token});
}

class LogoutRequested extends AuthEvent {}

class CheckAuthStatus extends AuthEvent {}

class RetryAuthCheck extends AuthEvent {}
class LoginAsGuest extends AuthEvent {}
class RefreshProfile extends AuthEvent {}
class ResetToGuest extends AuthEvent {}



