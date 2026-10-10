import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/local_storage_service.dart';
import '../../../../di/locator.dart';
import '../data/user_address_repository.dart';
import '../model/user_address_model.dart';

/// Riverpod notifier that holds the currently-selected service address.
///
/// Lifecycle:
///   • [build] kicks off an async load from local storage the moment the
///     provider is first watched — no explicit `init()` call needed.
///   • For logged-in customers, call [loadForLoggedInUser] which adds an
///     API fallback if no address is cached locally.
///   • [selectAddress] persists to secure storage AND updates in-memory state.
class SelectedAddressNotifier extends Notifier<UserAddressModel?> {
  LocalStorageService get _storage => locator<LocalStorageService>();
  UserAddressRepository get _repo => locator<UserAddressRepository>();

  @override
  UserAddressModel? build() {
    // Fire-and-forget: reads Hive/SecureStorage and updates state once done.
    // Initial synchronous value is null; widgets rebuild when storage is read.
    _loadFromStorage();
    return null;
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

  Future<void> _loadFromStorage() async {
    final json = await _storage.getSelectedAddress();
    if (json == null) return;
    try {
      state = UserAddressModel.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
    } catch (_) {
      // Corrupted cache — silently ignore
    }
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Called after login / registration.
  /// Loads from storage first; if nothing cached, fetches from the API and
  /// auto-selects the default (or first) address.
  Future<void> loadForLoggedInUser({bool force = false}) async {
    final current = state;
    final hasSaved = current != null && current.id != null && current.fullAddress.trim().isNotEmpty;
    if (!force && hasSaved) return;
    if (current == null) await _loadFromStorage();

    try {
      final addresses = await _repo.getAddresses();
      if (addresses.isEmpty) return;
      final selected = state;
      UserAddressModel? match;
      for (final address in addresses) {
        if (selected != null && (address.id == selected.id || address.mongoId == selected.mongoId)) {
          match = address;
          break;
        }
      }
      final next = match ??
          addresses.firstWhere(
            (address) => address.isDefault,
            orElse: () => addresses.first,
          );
      await selectAddress(next);
    } catch (_) {
      // Network / API error — keep the address already on screen
    }
  }

  /// Persist [address] to secure storage and update reactive state.
  Future<void> selectAddress(UserAddressModel address) async {
    await _storage.saveSelectedAddress(jsonEncode(address.toJson()));
    state = address;
  }

  /// Clear selected address from storage and in-memory state.
  Future<void> clearAddress() async {
    await _storage.clearSelectedAddress();
    state = null;
  }
}

/// Global provider — accessible anywhere via `ref.watch/read`.
final selectedAddressProvider =
    NotifierProvider<SelectedAddressNotifier, UserAddressModel?>(
  SelectedAddressNotifier.new,
);

