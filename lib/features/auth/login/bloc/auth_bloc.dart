import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/data/models/user_profile_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_flavor/flutter_flavor.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/device_service.dart';
import '../../../../core/services/network_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/provider_repository.dart';
import '../../../../di/locator.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository repository;
  final LocalStorageService storage;

  final NetworkService networkService;

  AuthBloc({required this.repository, required this.storage, required this.networkService})
    : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<LoginSuccess>(_onLoginSuccess);
    on<LogoutRequested>(_onLogoutRequested);
    on<RetryAuthCheck>(_onRetryAuthCheck);

    on<SendOtpEvent>(_onOtpSend);
    on<LoginWithPasswordEvent>(_onLoginWithPassword);
    on<UpdateFcmTokenEvent>(_onUpdateFcmToken);
    on<LoginAsGuest>(_onLoginAsGuest);
    on<RefreshProfile>(_onRefreshProfile);
    on<ResetToGuest>(_onResetToGuest);
  }

  Future<void> _onRefreshProfile(RefreshProfile event, Emitter<AuthState> emit) async {
    // We only refresh if we are already authenticated.
    if (state is AuthAuthenticated) {
      try {
        final repository = locator<ProviderRepository>();
        final user = await repository.getProfile();

        // ── Ensure we are getting fresh data from API ───────────────────────
        kPrint("Refreshing profile — Received Wallet: ${user.walletAmount}, Bonus: ${user.bonusWalletAmount}");

        // Update local cache
        await storage.saveUserProfile(user.toJson());

        // Emit new state with the fresh user object
        emit(AuthAuthenticated(user: user, isOfflineMode: false));
      } catch (e) {
        kPrintError('Manual profile refresh failed: $e');
      }
    }
  }

  Future<void> _onUpdateFcmToken(UpdateFcmTokenEvent event, Emitter<AuthState> emit) async {
    try {
      // ── Skip if token hasn't changed since last successful send ──────────
      // FCM tokens are long-lived; rotating only on reinstall / token
      // invalidation. Calling saveDeviceToken on every app start is wasteful.
      final cached = storage.lastFcmToken;
      if (cached != null && cached == event.token) {
        kPrint('FCM token unchanged — skipping saveDeviceToken API call');
        return;
      }

      emit(UpdateFcmTokenLoading());
      final String deviceId = await DeviceService.getPersistentDeviceId();
      final String deviceType = Platform.isIOS ? 'ios' : 'android';
      final String finalId = "${deviceType == 'android' ? 'AND' : 'IOS'}-$deviceId";

      final response = await repository.saveDeviceToken(
        fcmToken: event.token,
        deviceId: finalId,
        deviceType: deviceType,
      );

      if (response['status'] == true) {
        // Persist the token so we can skip redundant calls next time
        await storage.saveLastFcmToken(event.token);

        // ── SAVE FIREBASE AUTH TOKEN ───────────────────────────────────
        final String? firebaseToken = response['firebase_token'];
        if (firebaseToken != null) {
          final trimmed = firebaseToken.trim();
          kPrint("Firebase token parts: ${trimmed.split('.').length} | prefix: ${trimmed.length > 60 ? trimmed.substring(0, 60) : trimmed}");
          await storage.saveFirebaseAuthToken(trimmed);
          await _signInFirebaseWithToken(trimmed);
        }

        kPrint('FCM token saved successfully.');
      }
    } catch (e) {
      emit(UpdateFcmTokenError("Failed to save fcm token"));
    }
  }

  Future<void> _onLoginWithPassword(LoginWithPasswordEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await repository.loginWithPassword(identifier: event.identifier, password: event.password);
      await storage.saveUserProfile(user.toJson());
      emit(AuthAuthenticated(user: user));
      locator<AnalyticsService>().logEvent(name: 'login', parameters: {'method': 'password'});
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '').replaceAll('AppException: ', '')));
    }
  }

  Future<void> _onOtpSend(SendOtpEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await repository.sendOtp(mobile: event.mobile, isResend: event.isResend);
      kPrint("Send OTP API response for ${event.mobile} : $response");

      final bool isBlocked =
          response['is_blocked'] == true ||
          response['is_blocked'] == 'true' ||
          response['is_blocked'] == 1 ||
          (response['message']?.toString().toLowerCase().contains('blocked') ?? false);

      final bool isExplicitFailure =
          response['success'] == false ||
          response['success'] == 'false' ||
          response['status'] == false ||
          response['status'] == 'false' ||
          isBlocked;

      final bool isSuccess =
          (response['success'] == true ||
              response['success'] == 'true' ||
              response['status'] == true ||
              response['status'] == 'true') &&
          !isExplicitFailure;

      if (isSuccess) {
        // Extract user data from send-OTP response (null for new/unregistered users)
        final Map<String, dynamic>? userData =
            (response['data'] as Map<String, dynamic>?)?['user'] as Map<String, dynamic>?;
        emit(AuthOtpSent(event.mobile, userData: userData));
      } else {
        // Show the message from API for blocked account or other failures
        String apiMessage = response['message']?.toString() ?? "Failed to send OTP. Please try again.";

        // Handle 404 (Route not found) framework error
        if (apiMessage.toLowerCase().contains('could not be found') ||
            apiMessage.toLowerCase().contains('not found')) {
          apiMessage = "Failed to send OTP. Please try again.";
        }

        emit(AuthError(apiMessage, isBlocked: isBlocked));
      }
    } catch (e) {
      kPrintError("Error in SendOtp: $e");
      emit(AuthError("Failed to send OTP. Please try again."));
    }
  }

  Future<void> _onCheckAuthStatus(CheckAuthStatus event, Emitter<AuthState> emit) async {
    emit(AuthInitializeLoading());

    try {
      final isLoggedIn = await storage.isLoggedIn;
      // Check network status
      if (networkService.isOffline) {
        // Try to load from cache even if offline
        final cachedUser = await storage.getUserProfile();

        if (cachedUser != null && isLoggedIn) {
          final user = UserProfileModel.fromJson(cachedUser);
          emit(AuthAuthenticated(user: user, isOfflineMode: true));
          return;
        }

        // No cache and offline - show error
        emit(AuthNetworkError('No internet connection. Please check and try again.'));
        return;
      }

      // Check if token exists
      if (!isLoggedIn) {
        // No token - user not logged in.
        if (AppConstants.isProviderApp) {
          emit(AuthUnauthenticated());
        } else {
          // For User app, if onboarding is complete, we land as guest by default.
          // This skips the login page after splash.
          final role = FlavorConfig.instance.variables['role'] ?? 'user';
          if (storage.isOnboardingComplete(role)) {
            emit(AuthGuest());
          } else {
            emit(AuthUnauthenticated());
          }
        }
        return;
      }

      // Token exists - verify it's valid and load user data
      final cachedUser = await storage.getUserProfile();

      if (cachedUser != null) {
        // Valid session with cached data
        final user = UserProfileModel.fromJson(cachedUser);
        _setAnalyticsUserData(user);
        emit(AuthAuthenticated(user: user));

        // ── SYNC FIREBASE AUTH ───────────────────────────────────
        // Firebase persists its own session — only sign in if no current user.
        try {
          if (FirebaseAuth.instance.currentUser == null) {
            final fbToken = await storage.firebaseAuthToken;
            if (fbToken != null) {
              await _signInFirebaseWithToken(fbToken);
            }
          }
        } catch (e) {
          kPrintError('Firebase auth sync failed on startup: $e');
        }

        // ── SYNC FCM TOKEN ───────────────────────────────────────
        // Critical: refresh the backend's token for this device.
        try {
          final fcmToken = await locator<NotificationService>().getFCMToken();
          if (fcmToken != null) {
            add(UpdateFcmTokenEvent(fcmToken));
          }
        } catch (e) {
          kPrintError('FCM sync failed on startup: $e');
        }
      } else {
        // Token exists but no cached user - fetch from API
        try {
          final repository = locator<ProviderRepository>();
          final user = await repository.getProfile();

          // Cache the user data
          await storage.saveUserProfile(user.toJson());

          emit(AuthAuthenticated(user: user));

          // ── SYNC FIREBASE AUTH ───────────────────────────────────
          try {
            if (FirebaseAuth.instance.currentUser == null) {
              final fbToken = await storage.firebaseAuthToken;
              if (fbToken != null) {
                await _signInFirebaseWithToken(fbToken);
              }
            }
          } catch (e) {
            kPrintError('Firebase auth sync failed after profile fetch: $e');
          }

          // ── SYNC FCM TOKEN ───────────────────────────────────────
          try {
            final fcmToken = await locator<NotificationService>().getFCMToken();
            if (fcmToken != null) {
              add(UpdateFcmTokenEvent(fcmToken));
            }
          } catch (e) {
            kPrintError('FCM sync failed after profile fetch: $e');
          }
        } catch (e) {
          // Token invalid or API error - logout
          await storage.clearAll();
          emit(AuthUnauthenticated());
        }
      }
    } catch (e) {
      emit(AuthError(e.toString(), isGlobal: true));
    }
  }

  Future<void> _onLoginSuccess(LoginSuccess event, Emitter<AuthState> emit) async {
    // Save token and user data
    await storage.saveToken(event.token);
    await storage.saveUserProfile(event.user.toJson());

    // Analytics Tracking
    _setAnalyticsUserData(event.user);
    locator<AnalyticsService>().logEvent(
      name: 'login',
      parameters: {'method': 'phone_otp'},
    );

    emit(AuthAuthenticated(user: event.user));
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    // Clear all data
    emit(AuthLoggingOut());
    await Future.delayed(const Duration(milliseconds: 500)); // Optional smooth transition

    try {
      await locator<AnalyticsService>().clearUser();
      await FirebaseAuth.instance.signOut();
      await repository.logout();
      await storage.clearAll();
      emit(AuthUnauthenticated());
    } catch (e) {
      kPrint("Getting error on logout $e");
      await storage.clearAll();
    } finally {
      AppNavigator.removeAndGo(AppRoutes.login);
    }
  }

  void _setAnalyticsUserData(UserProfileModel user) {
    final analytics = locator<AnalyticsService>();
    final userId = user.id.toString();
    if (userId.isNotEmpty) {
      analytics.setUserId(userId);
    }
    analytics.setUserProperty(
      name: 'user_role',
      value: AppConstants.isProviderApp ? 'provider' : 'user',
    );
  }

  Future<void> _onRetryAuthCheck(RetryAuthCheck event, Emitter<AuthState> emit) async {
    // Wait for network if offline
    if (networkService.isOffline) {
      emit(AuthInitializeLoading());
      try {
        await networkService.waitForConnection(timeout: const Duration(seconds: 10));
      } catch (e) {
        emit(AuthNetworkError('Still no internet connection. Please try again.'));
        return;
      }
    }

    // Retry check
    add(CheckAuthStatus());
  }

  Future<void> _onLoginAsGuest(LoginAsGuest event, Emitter<AuthState> emit) async {
    if (AppConstants.isProviderApp) {
      emit(AuthError("Providers must login to continue"));
      return;
    }
    emit(AuthLoading());
    // Clear any leftover data just in case
    await storage.clearAll();

    // Set onboarding as complete if they reached login
    final role = FlavorConfig.instance.variables['role'] ?? 'user';
    await storage.setOnboardingComplete(role);

    emit(AuthGuest());
  }

  Future<void> _onResetToGuest(ResetToGuest event, Emitter<AuthState> emit) async {
    // Only reset if we are in a mid-login transient state (OTP sent but not verified).
    // Never downgrade an already-authenticated session.
    if (state is AuthAuthenticated) return;
    if (AppConstants.isProviderApp) {
      emit(AuthUnauthenticated());
    } else {
      emit(AuthGuest());
    }
  }

  // ── FIREBASE AUTH HELPER ──────────────────────────────────────────────────
  Future<void> _signInFirebaseWithToken(String token) async {
    try {
      kPrint("Attempting Firebase custom token sign-in...");
      final credential = await FirebaseAuth.instance.signInWithCustomToken(token);
      kPrint("Firebase signed in successfully: ${credential.user?.uid}");
    } catch (e) {
      kPrintError("Firebase custom token sign-in failed: $e");
    }
  }
}
