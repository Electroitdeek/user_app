import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/api/api_error_handler.dart';


import '../data/user_address_repository.dart';
import '../model/user_address_model.dart';

part 'user_address_event.dart';
part 'user_address_state.dart';

class UserAddressBloc extends Bloc<UserAddressEvent, UserAddressState> {
  final UserAddressRepository _repository;

  UserAddressBloc(this._repository) : super(UserAddressInitial()) {
    on<LoadAddresses>(_onLoad);
    on<AddAddress>(_onAdd);
    on<UpdateAddress>(_onUpdate);
    on<DeleteAddress>(_onDelete);
  }

  // ── Load ──────────────────────────────────────────────────────────────────
  Future<void> _onLoad(LoadAddresses event, Emitter<UserAddressState> emit) async {
    emit(UserAddressLoading());
    try {
      final addresses = await _repository.getAddresses();
      emit(UserAddressLoaded(addresses));
    } catch (e) {
      emit(UserAddressError(ApiErrorHandler.getErrorMessage(e)));
    }
  }

  // ── Add ───────────────────────────────────────────────────────────────────
  Future<void> _onAdd(AddAddress event, Emitter<UserAddressState> emit) async {
    emit(UserAddressLoading());
    try {
      await _repository.addOrUpdateAddress(event.address);
      final updated = await _repository.getAddresses();
      emit(UserAddressActionSuccess(message: 'Address added successfully', addresses: updated));
    } catch (e) {
      emit(UserAddressError(ApiErrorHandler.getErrorMessage(e)));
    }
  }

  // ── Update ────────────────────────────────────────────────────────────────
  Future<void> _onUpdate(UpdateAddress event, Emitter<UserAddressState> emit) async {
    emit(UserAddressLoading());
    try {
      await _repository.addOrUpdateAddress(event.address);
      final updated = await _repository.getAddresses();
      emit(UserAddressActionSuccess(message: 'Address updated successfully', addresses: updated));
    } catch (e) {
      emit(UserAddressError(ApiErrorHandler.getErrorMessage(e)));
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<void> _onDelete(DeleteAddress event, Emitter<UserAddressState> emit) async {
    final current = state is UserAddressLoaded
        ? (state as UserAddressLoaded).addresses
        : (state is UserAddressActionSuccess
              ? (state as UserAddressActionSuccess).addresses
              : <UserAddressModel>[]);
    emit(UserAddressLoading());
    try {
      await _repository.deleteAddress(event.id);
      final updated = current.where((a) => a.id != event.id).toList();
      emit(UserAddressActionSuccess(message: 'Address deleted', addresses: updated));
    } catch (e) {
      // Keep the existing list visible; surface the reason in a dialog.
      emit(UserAddressActionFailure(message: ApiErrorHandler.getErrorMessage(e), addresses: current));
    }
  }
}
