part of 'auth_bloc.dart';

abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthInitializeLoading extends AuthState {}

class AuthLoading extends AuthState {}

class AuthOtpSent extends AuthState {
  final String mobile;

  /// Raw user object returned by the send-OTP API (null when new user).
  final Map<String, dynamic>? userData;

  AuthOtpSent(this.mobile, {this.userData});
}

class AuthError extends AuthState {
  final String message;
  final bool isBlocked;
  final bool isGlobal;

  AuthError(this.message, {this.isBlocked = false, this.isGlobal = false});
}

class UpdateFcmTokenLoading extends AuthState {}

class UpdateFcmTokenError extends AuthState {
  final String message;

  UpdateFcmTokenError(this.message);
}

class AuthAuthenticated extends AuthState {
  final UserProfileModel user;
  final bool isOfflineMode;

  AuthAuthenticated({required this.user, this.isOfflineMode = false});
}

class AuthUnauthenticated extends AuthState {}

class AuthGuest extends AuthState {}

class AuthLoggingOut extends AuthState {}

class AuthNetworkError extends AuthState {
  final String message;

  AuthNetworkError(this.message);
}
