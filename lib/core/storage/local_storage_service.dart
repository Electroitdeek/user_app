import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

import '../../features/auth/auth_wrapper/data/role_enums.dart';
import 'hive_keys.dart';

class LocalStorageService {
  Box? _authBox;
  final _storage = const FlutterSecureStorage();

  /// Call once during app start
  Future<void> init() async {
    _authBox = await Hive.openBox(HiveKeys.authBox);
  }

  Box get _box {
    if (_authBox == null) {
      throw Exception("Hive box not initialized. Call LocalStorageService.init() first.");
    }
    return _authBox!;
  }

  // ----------------TOKEN---SECURE--STORAGE ----------------

  /// Save the token after successful login or OTP verification
  Future<void> saveToken(String token) async {
    await _storage.write(key: HiveKeys.token, value: token);
  }

  /// Retrieve the token for API requests (used in AuthInterceptor)
  // Future<String?> getToken() async {
  //   return await _storage.read(key: HiveKeys.token);
  // }

  Future<void> saveDeviceId(String id) async {
    await _storage.write(key: HiveKeys.deviceId, value: id);
  }

  Future<String?> getDeviceId() async {
    return await _storage.read(key: HiveKeys.deviceId);
  }

  Future<String?> get token async => await _storage.read(key: HiveKeys.token);

  // User Profile Cache
  Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    // kPrint("saveUserProfile calling with profile: $profile");
    await _storage.write(key: HiveKeys.userProfile, value: json.encode(profile));
    await saveUser(profile);
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final data = await _storage.read(key: HiveKeys.userProfile);
    if (data != null) {
      return json.decode(data);
    }
    return null;
  }

  // Selected Address
  Future<void> saveSelectedAddress(String addressJson) async {
    await _storage.write(key: 'selected_user_address', value: addressJson);
  }

  // Service Categories Cache
  Future<void> saveServiceCategories(List<dynamic> categoriesJson) async {
    await _storage.write(key: 'cached_service_categories', value: json.encode(categoriesJson));
  }

  Future<List<dynamic>?> getServiceCategories() async {
    final data = await _storage.read(key: 'cached_service_categories');
    if (data != null) {
      return json.decode(data);
    }
    return null;
  }

  Future<String?> getSelectedAddress() async {
    return await _storage.read(key: 'selected_user_address');
  }

  Future<void> clearSelectedAddress() async {
    await _storage.delete(key: 'selected_user_address');
  }

  //----------------------------------------------------------------------------------

  // ---------------- USER ----------------

  Future<void> saveUser(Map userData) async {
    if (userData.isEmpty) return;

    // kPrint("LocalStorageService: Saving user data... (Keys: ${userData.keys.toList()})");

    int userId = userData['id'] is int ? userData['id'] : int.tryParse(userData['id']?.toString() ?? '0') ?? 0;
    String userType = userData['user_type']?.toString() ?? '';
    String name = userData['name']?.toString() ?? '';
    String? email = userData['email']?.toString();

    // Flexible extraction for Provider ID
    int? serviceProviderId;
    int? cityAdminIdVal;
    final spProfile = userData['service_provider_profile'] ?? userData['service_provider'];
    if (spProfile != null && spProfile is Map) {
      serviceProviderId = spProfile['id'] is int
          ? spProfile['id']
          : int.tryParse(spProfile['id']?.toString() ?? '');
      cityAdminIdVal = spProfile['city_admin_id'] is int
          ? spProfile['city_admin_id']
          : int.tryParse(spProfile['city_admin_id']?.toString() ?? '');
    } else if (userData['service_provider_id'] != null) {
      serviceProviderId = userData['service_provider_id'] is int
          ? userData['service_provider_id']
          : int.tryParse(userData['service_provider_id'].toString());
    }

    // Flexible extraction for Customer ID
    int? customerId;
    final cProfile = userData['customer_profile'] ?? userData['customer'];
    if (cProfile != null && cProfile is Map) {
      customerId = cProfile['id'] is int ? cProfile['id'] : int.tryParse(cProfile['id']?.toString() ?? '');
    } else if (userData['customer_id'] != null) {
      customerId = userData['customer_id'] is int
          ? userData['customer_id']
          : int.tryParse(userData['customer_id'].toString());
    }

    // kPrint("LocalStorageService: Extracted IDs -> User: $userId, Provider: $serviceProviderId, Customer: $customerId");

    await _box.put(HiveKeys.userId, userId);
    await _box.put(HiveKeys.serviceProviderId, serviceProviderId);
    await _box.put(HiveKeys.customerId, customerId);
    await _box.put(HiveKeys.userType, userType);
    await _box.put(HiveKeys.email, email);
    await _box.put(HiveKeys.username, name);
    if (cityAdminIdVal != null) {
      await _box.put(HiveKeys.cityAdminId, cityAdminIdVal);
    }
  }

  int? get userId => _box.get(HiveKeys.userId);

  int? get serviceProvideUserId => _box.get(HiveKeys.serviceProviderId);

  int? get customerUserId => _box.get(HiveKeys.customerId);

  String? get userType => _box.get(HiveKeys.userType);

  String? get email => _box.get(HiveKeys.email);

  String? get username => _box.get(HiveKeys.username);

  String? get organizationName => _box.get(HiveKeys.organizationName) ?? username;

  // ---------------- AUTH HELPERS ----------------

  Future<bool> get isLoggedIn async => (await token) != null && (await token)!.isNotEmpty;

  Future<void> _clearAuthBox() async {
    final keysToKeep = {HiveKeys.onboardingUserComplete, HiveKeys.onboardingProviderComplete};

    final allKeys = _box.keys.toList();
    for (final key in allKeys) {
      if (!keysToKeep.contains(key)) {
        await _box.delete(key);
      }
    }
  }

  Future<void> clearAll() async {
    await _storage.delete(key: HiveKeys.token);
    await _storage.delete(key: HiveKeys.userProfile);
    await _storage.delete(key: HiveKeys.firebaseAuthToken);
    await _storage.delete(key: 'selected_user_address');
    await _clearAuthBox();
  }

  UserRole get getUserRole => userType == "service_provider" ? UserRole.provider : UserRole.patient;

  // Onboarding status
  Future<void> setOnboardingComplete(String role) async {
    final key = role == 'provider' ? HiveKeys.onboardingProviderComplete : HiveKeys.onboardingUserComplete;
    await _box.put(key, true);
  }

  bool isOnboardingComplete(String role) {
    final key = role == 'provider' ? HiveKeys.onboardingProviderComplete : HiveKeys.onboardingUserComplete;
    return _box.get(key, defaultValue: false);
  }

  // ── FCM TOKEN DEDUP ─────────────────────────────────────────────────────────
  // Store the last FCM token that was successfully sent to the backend.
  // AuthBloc compares against this before calling saveDeviceToken so the
  // API is only hit when the token genuinely changes (rotation / reinstall).

  String? get lastFcmToken => _box.get(HiveKeys.lastFcmToken);

  Future<void> saveLastFcmToken(String token) async {
    await _box.put(HiveKeys.lastFcmToken, token);
  }

  // ── WALLET TRACKING ─────────────────────────────────────────────────────────
  String? get lastKnownWalletAmount => _box.get(HiveKeys.lastKnownWalletAmount);

  Future<void> saveLastKnownWalletAmount(String amount) async {
    await _box.put(HiveKeys.lastKnownWalletAmount, amount);
  }

  // ── CITY ADMIN ID ───────────────────────────────────────────────────────────
  int? get cityAdminId => _box.get(HiveKeys.cityAdminId);

  Future<void> saveCityAdminId(int? id) async {
    await _box.put(HiveKeys.cityAdminId, id);
  }

  // ── EMERGENCY CONTACT NUMBER ─────────────────────────────────────────────────
  String? get emergencyContactNumber => _box.get(HiveKeys.emergencyContactNumber);

  Future<void> saveEmergencyContactNumber(String? number) async {
    if (number == null || number.isEmpty) {
      await _box.delete(HiveKeys.emergencyContactNumber);
    } else {
      await _box.put(HiveKeys.emergencyContactNumber, number);
    }
  }

  // ── PROVIDER STANDBY ────────────────────────────────────────────────────────
  bool get providerIsStandby => _box.get(HiveKeys.providerIsStandby, defaultValue: false) as bool;

  Future<void> saveProviderIsStandby(bool value) async {
    await _box.put(HiveKeys.providerIsStandby, value);
  }

  // ── FIREBASE TOKEN (SECURE) ──────────────────────────────────────────────────

  Future<void> saveFirebaseAuthToken(String token) async {
    await _storage.write(key: HiveKeys.firebaseAuthToken, value: token);
  }

  Future<String?> get firebaseAuthToken async => await _storage.read(key: HiveKeys.firebaseAuthToken);

  // ── Generic Storage ────────────────────────────────────────────────────────
  Future<void> saveString(String key, String value) async {
    await _box.put(key, value);
  }

  String? getString(String key) {
    return _box.get(key);
  }
}
