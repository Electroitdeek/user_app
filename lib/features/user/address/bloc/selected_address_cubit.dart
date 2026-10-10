import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/local_storage_service.dart';
import '../data/user_address_repository.dart';
import '../model/user_address_model.dart';

class SelectedAddressCubit extends Cubit<UserAddressModel?> {
  final LocalStorageService _storage;
  final UserAddressRepository _repository;

  SelectedAddressCubit(this._storage, this._repository) : super(null);
  // Note: loadAddress() is NOT called here intentionally.
  // This cubit is provided globally (main.dart) so it exists before login.
  // loadAddress() is triggered by AuthWrapper once the user is confirmed
  // as a customer — avoiding an unauthorized API call for providers.

  Future<void> loadAddress() async {
    final addressJson = await _storage.getSelectedAddress();
    if (addressJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(addressJson);
        final address = UserAddressModel.fromJson(decoded);
        emit(address);
        return;
      } catch (e) {
        // failed to parse
      }
    }

    // Auto-select address from API
    try {
      final addresses = await _repository.getAddresses();
      if (addresses.isNotEmpty) {
        final defaultAddress = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
        await selectAddress(defaultAddress);
      }
    } catch (e) {
      // API call failed
    }
  }

  Future<void> selectAddress(UserAddressModel address) async {
    final encoded = jsonEncode(address.toJson());
    await _storage.saveSelectedAddress(encoded);
    emit(address);
  }

  Future<void> clearAddress() async {
    await _storage.clearSelectedAddress();
    emit(null);
  }
}
