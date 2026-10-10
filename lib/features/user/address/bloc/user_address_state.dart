part of 'user_address_bloc.dart';

abstract class UserAddressState {}

class UserAddressInitial extends UserAddressState {}

class UserAddressLoading extends UserAddressState {}

class UserAddressLoaded extends UserAddressState {
  final List<UserAddressModel> addresses;
  UserAddressLoaded(this.addresses);
}

class UserAddressActionSuccess extends UserAddressState {
  final String message;
  final List<UserAddressModel> addresses;
  UserAddressActionSuccess({required this.message, required this.addresses});
}

class UserAddressError extends UserAddressState {
  final String message;
  UserAddressError(this.message);
}

/// An action (e.g. delete) failed but the existing list is still valid —
/// keeps [addresses] so the UI shows the list and surfaces [message] in a dialog.
class UserAddressActionFailure extends UserAddressState {
  final String message;
  final List<UserAddressModel> addresses;
  UserAddressActionFailure({required this.message, required this.addresses});
}
