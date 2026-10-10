part of 'user_address_bloc.dart';

abstract class UserAddressEvent {}

class LoadAddresses extends UserAddressEvent {}

class AddAddress extends UserAddressEvent {
  final UserAddressModel address;
  AddAddress(this.address);
}

class UpdateAddress extends UserAddressEvent {
  final UserAddressModel address;
  UpdateAddress(this.address);
}

class DeleteAddress extends UserAddressEvent {
  final int id;
  DeleteAddress(this.id);
}
