import 'dart:async';

import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/services/pending_notification_action.dart';
import 'package:adhisaat_health_care/core/storage/local_storage_service.dart';
import 'package:adhisaat_health_care/data/models/user_profile_model.dart';
import 'package:adhisaat_health_care/data/repositories/provider_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:geolocator/geolocator.dart';

import '../../../../../core/api/api_client.dart';
import '../../../../../core/services/location_service.dart';
import '../../../../../core/services/notification_service.dart';
import '../../../../../di/locator.dart';
import '../../../../auth/login/bloc/auth_bloc.dart';
import '../../../../service_provider/provider_requests/data/models/provider_service_request_model.dart';
import '../../../../service_provider/provider_requests/data/repositories/provider_request_repository.dart';
import '../../data/models/service_request.dart';
import 'provider_dashboard_event.dart';
import 'provider_dashboard_state.dart';

class ProviderDashboardBloc extends Bloc<ProviderDashboardEvent, ProviderDashboardState> {
  final ProviderRepository _repository;
  StreamSubscription<Position>? _locationStreamSub;

  ProviderDashboardBloc(this._repository) : super(ProviderDashboardInitial()) {
    on<LoadProviderDashboard>(_onLoadDashboard);
    on<UpdateProfileData>(_onUpdateProfileData);

    on<RefreshDashboardEvent>(_onRefreshDashboard);
    on<ToggleAvailabilityEvent>(_onToggleAvailability);

    on<NewRequestReceivedEvent>(_onNewRequestReceived);
    on<AcceptRequestEvent>(_onAcceptRequest);
    on<AcceptFromNotificationEvent>(_onAcceptFromNotification);
    on<RejectRequestEvent>(_onRejectRequest);
    on<WaitingPeriodEndedEvent>(_onWaitingPeriodEnded);
    on<SelectRequestEvent>(_onSelectRequest);
  }

  Future<void> _onLoadDashboard(LoadProviderDashboard event, Emitter<ProviderDashboardState> emit) async {
    final storage = locator<LocalStorageService>();
    final cachedProfileData = await storage.getUserProfile();
    UserProfileModel? cachedProfile;

    if (cachedProfileData != null) {
      cachedProfile = UserProfileModel.fromJson(cachedProfileData);
    }

    emit(ProviderDashboardLoading(cachedProfile: cachedProfile));

    try {
      // Always update location in background
      _updateLocationAndToken(emit);

      // Decide whether to fetch fresh profile data
      UserProfileModel profile;
      if (event.forceRefresh || cachedProfile == null) {
        // Fetch fresh profile from API
        profile = await _repository.getProfile();
        await storage.saveUserProfile(profile.toJson());
        await storage.saveProviderIsStandby(
            profile.serviceProviderProfile?.isStandby ?? false);
      } else {
        // Use cached profile
        profile = cachedProfile;
      }

      // Always fetch fresh dashboard data (it changes frequently)
      final dashboard = await _repository.getProviderDashboard();

      // Fetch latest 2 accepted requests for the dashboard (non-blocking)
      final requestRepo = locator<ProviderRequestRepository>();
      List<ProviderServiceRequestModel> recentRequests = [];
      try {
        final recentResponse = await requestRepo.getProviderServiceRequests(
          requestStatus: 'upcoming,searching,pending,accepted',
          page: 1,
          perPage: 5,
        );
        recentRequests = recentResponse.requests;
      } catch (_) {
        kPrint('Failed to load recent requests — showing empty list');
      }

      final isOnline = profile.serviceProviderProfile?.isAvailable ?? true;
      emit(
        ProviderDashboardLoaded(
          isOnline: isOnline,
          unreadNotifications: 0,
          upcomingServices: [],
          profile: profile,
          dashboard: dashboard,
          locationUpdated: true,
          recentRequests: recentRequests,
        ),
      );

      // Start distance-based stream if provider is online
      if (isOnline) { _startLocationStream(); } else { _stopLocationStream(); }

      // ── Drain any notification action that arrived before this bloc mounted ──
      final pending = await PendingNotificationAction.consume();
      if (pending != null) {
        kPrint('📥 Draining pending notification action — type: ${pending.type}  requestId: ${pending.requestId}');
        _handlePendingAction(pending);
      }
    } catch (e) {
      kPrintError(e.toString());
      // Try to get existing dashboard data if we are in an error/refresh state
      final prevLoadedData = _getDashboardData(state);
      emit(ProviderDashboardError(message: e.toString(), cachedProfile: cachedProfile, dashboardData: prevLoadedData));
    } finally {
      // ── Always drain any notification action, even if the load failed ──
      final pending = await PendingNotificationAction.consume();
      if (pending != null) {
        kPrint('📥 Draining pending notification action — type: ${pending.type}  requestId: ${pending.requestId}');
        _handlePendingAction(pending);
      }
    }
  }

  void _onUpdateProfileData(UpdateProfileData event, Emitter<ProviderDashboardState> emit) async {
    final storage = locator<LocalStorageService>();
    // Update cache when profile is updated from settings
    await storage.saveUserProfile(event.profile.toJson());

    // Update current state
    if (state is ProviderDashboardLoaded) {
      final currentState = state as ProviderDashboardLoaded;
      emit(
        currentState.copyWith(
          isOnline: (event.profile.serviceProviderProfile?.isAvailable) ?? false,
          profile: event.profile,
        ),
      );
    }
  }

  /// Routes a pending [PendingAction] to the right handler.
  ///
  /// Request-type actions (service or emergency accepted while killed) →
  ///   `AcceptFromNotificationEvent` (calls API + navigates).
  ///
  /// Payout actions → navigate directly to the earnings page; no API call
  ///   is required and calling respondToRequest here would be a bug.
  void _handlePendingAction(PendingAction pending) {
    switch (pending.type) {
      case 'service_request':
      case 'emergency_request':
      case 'request_accepted':
        add(
          AcceptFromNotificationEvent(
            requestId: pending.requestId,
            isEmergency: pending.isEmergency,
            payload: pending.payload,
          ),
        );
        break;

      case 'provider_payout_completed':
        kPrint('📥 [Drain] provider_payout_completed — navigating to earnings');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AppNavigator.navigatorKey.currentState?.pushNamed(AppRoutes.providerEarningsList);
        });
        break;

      case 'service_status_changed':
      case 'broadcast':
        kPrint('📥 [Drain] ${pending.type} — navigating to profile');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AppNavigator.navigatorKey.currentState?.pushNamed(AppRoutes.providerProfilePage);
        });
        break;

      default:
        kPrint('📥 [Drain] Unknown pending type: ${pending.type} — ignoring');
    }
  }

  // ── Distance-based location stream ───────────────────────────
  // Fires silently every time the provider moves ≥150 m while the app is
  // in the foreground. With "When In Use" permission the OS auto-pauses
  // the stream when backgrounded, so no manual lifecycle handling is needed.
  void _startLocationStream() {
    if (_locationStreamSub != null) return; // already running
    _locationStreamSub = LocationService()
        .getLocationStream(accuracy: LocationAccuracy.medium, distanceFilter: 150)
        .listen(
      (position) async {
        try {
          await _repository.updateCurrentLocation(
            latitude: position.latitude,
            longitude: position.longitude,
          );
          kPrint('📍 Location auto-updated: ${position.latitude}, ${position.longitude}');
        } catch (_) {}
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void _stopLocationStream() {
    _locationStreamSub?.cancel();
    _locationStreamSub = null;
  }

  @override
  Future<void> close() {
    _stopLocationStream();
    return super.close();
  }

  Future<void> _updateLocationAndToken(Emitter<ProviderDashboardState> emit) async {
    try {
      // 1. Update FCM Token
      final fcmToken = await locator<NotificationService>().getFCMToken();
      if (fcmToken != null) {
        final authBloc = AppNavigator.navigatorKey.currentContext?.read<AuthBloc>();
        if (authBloc != null) {
          authBloc.add(UpdateFcmTokenEvent(fcmToken));
        }
      }

      // 2. Update Location
      LocationService locationService = LocationService();
      // Don't request permission automatically here — if it's denied/not granted,
      // just skip background location update.
      final position = await locationService.getLocationPosition(requestPermission: false);
      if (position != null) {
        await _repository.updateCurrentLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }
    } catch (e) {
      kPrint('Location or token update failed: $e');
    }
  }

  Future<void> _onRefreshDashboard(RefreshDashboardEvent event, Emitter<ProviderDashboardState> emit) async {
    try {
      // Push latest location to backend on every refresh (covers app resume).
      // Fire-and-forget — don't block the UI refresh.
      _updateLocationAndToken(emit);

      final user = await _repository.getProfile();
      final dashboard = await _repository.getProviderDashboard();

      final storage = locator<LocalStorageService>();
      await storage.saveUserProfile(user.toJson());
      await storage.saveProviderIsStandby(
          user.serviceProviderProfile?.isStandby ?? false);

      // Fetch latest 2 accepted requests (non-blocking)
      final requestRepo = locator<ProviderRequestRepository>();
      List<ProviderServiceRequestModel> recentRequests = [];
      try {
        final recentResponse = await requestRepo.getProviderServiceRequests(
          requestStatus: 'upcoming,searching,pending,accepted',
          page: 1,
          perPage: 5,
        );
        recentRequests = recentResponse.requests;
      } catch (_) {
        kPrint('Failed to load recent requests on refresh');
      }

      if (state is ProviderDashboardLoaded) {
        final currentState = state as ProviderDashboardLoaded;
        emit(
          currentState.copyWith(
            isOnline: (user.serviceProviderProfile?.isAvailable) ?? false,
            profile: user,
            dashboard: dashboard,
            recentRequests: recentRequests,
          ),
        );
      } else {
        emit(
          ProviderDashboardLoaded(
            isOnline: (user.serviceProviderProfile?.isAvailable) ?? true,
            unreadNotifications: 0,
            upcomingServices: [],
            profile: user,
            dashboard: dashboard,
            locationUpdated: true,
            recentRequests: recentRequests,
          ),
        );
      }
    } catch (e) {
      kPrintError("Error on refresh dashboard: $e");
    }
  }

  Future<void> _onToggleAvailability(ToggleAvailabilityEvent event, Emitter<ProviderDashboardState> emit) async {
    if (state is ProviderDashboardLoaded) {
      final currentState = state as ProviderDashboardLoaded;

      // If GOING ONLINE, we need location to be available in the backend
      if (event.isOnline) {
        final position = await LocationService().getLocationPosition(requestPermission: true);
        if (position == null) {
          // If they still haven't granted location, don't allow going online
          // as the dispatch system requires GPS for providers.
          return;
        }
        await _repository.updateCurrentLocation(latitude: position.latitude, longitude: position.longitude);
      }

      final result = await _repository.updateIsAvailable(event.isOnline);
      if (result) {
        emit(currentState.copyWith(isOnline: event.isOnline));
        if (event.isOnline) { _startLocationStream(); } else { _stopLocationStream(); }
        add(RefreshDashboardEvent());
      }
    }
  }

  // When new request arrives
  Future<void> _onNewRequestReceived(NewRequestReceivedEvent event, Emitter<ProviderDashboardState> emit) async {
    final current = state is ProviderDashboardLoaded ? state as ProviderDashboardLoaded : null;
    final request = ServiceRequest.fromJson(event.requestData);
    emit(NewRequestReceived(request: request, dashboardData: current));
  }


  Future<void> _onRequestExpired(RequestExpiredEvent event, Emitter<ProviderDashboardState> emit) async {
    final current = _getDashboardData(state);
    emit(RequestExpired(requestId: event.requestId, dashboardData: current));
  }


  Future<void> _onAcceptRequest(AcceptRequestEvent event, Emitter<ProviderDashboardState> emit) async {
    final prevLoadedData = _getDashboardData(state);
    try {
      final result = await _repository.respondToRequest(
        requestId: int.tryParse(event.requestId) ?? event.request.bookingId,
        accepted: true,
        subBlockIds: event.request.subBlockIds,
      );
      if (result.success) {
        emit(RequestAccepted(requestId: event.requestId, request: event.request, dashboardData: prevLoadedData));
      } else if (result.isDateConflict) {
        emit(AcceptDateConflict(message: result.message, conflictDates: result.conflictDates, dashboardData: prevLoadedData));
      } else {
        _onRequestExpired(RequestExpiredEvent(requestId: event.requestId), emit);
      }
    } catch (e) {
      kPrintError('AcceptRequest error: $e');
      emit(ProviderDashboardError(message: e.toString(), dashboardData: prevLoadedData));
    }
  }


  /// Handles ACCEPT tapped directly on the system notification.
  Future<void> _onAcceptFromNotification(
    AcceptFromNotificationEvent event,
    Emitter<ProviderDashboardState> emit,
  ) async {
    final prevLoadedData = _getDashboardData(state);
    try {
      final requestId = int.tryParse(event.requestId) ?? 0;

      // 1. Fetch full request details to get sub_blocks and navigation data
      final request = await _repository.getServiceRequestById(requestId);

      // 2. Call respond API with sub_blocks
      final result = await _repository.respondToRequest(
        requestId: requestId,
        accepted: true,
        subBlockIds: request.subBlockIds,
      );

      if (!result.success) {
        _onRequestExpired(RequestExpiredEvent(requestId: event.requestId), emit);
        return;
      }

      final fullRequest = ServiceRequest(
        id: request.id,
        patientName: request.patientName,
        age: request.age,
        serviceType: request.serviceType,
        address: request.address,
        distance: request.distance,
        time: request.time,
        date: request.date,
        payment: request.payment,
        latitude: request.latitude,
        longitude: request.longitude,
        isEmergency: event.isEmergency,
        bookingId: request.bookingId,
      );

      emit(RequestAccepted(requestId: event.requestId, request: fullRequest, dashboardData: prevLoadedData));
    } catch (e) {
      kPrintError('AcceptFromNotification error: $e');
      final fallback = ServiceRequest(
        id: event.requestId,
        patientName: event.payload['provider_name'] ?? 'Patient',
        age: 0,
        serviceType: 'Service',
        address: '',
        distance: '',
        time: '',
        date: '',
        payment: 0,
        latitude: 0,
        longitude: 0,
        isEmergency: event.isEmergency,
        bookingId: int.tryParse(event.requestId) ?? 0,
      );
      emit(RequestAccepted(requestId: event.requestId, request: fallback, dashboardData: prevLoadedData));
    }
  }


  Future<void> _onRejectRequest(RejectRequestEvent event, Emitter<ProviderDashboardState> emit) async {
    try {
      await _repository.respondToRequest(requestId: int.tryParse(event.requestId) ?? 0, accepted: false);
    } catch (e) {
      kPrintError('RejectRequest error: $e');
    }

    if (state is ProviderDashboardLoaded) {
      emit((state as ProviderDashboardLoaded).copyWith(clearIncomingRequest: true));
      add(RefreshDashboardEvent());
    } else {
      add(LoadProviderDashboard());
    }
  }

  // After 3 minutes waiting period with multiple accepted requests
  Future<void> _onWaitingPeriodEnded(WaitingPeriodEndedEvent event, Emitter<ProviderDashboardState> emit) async {
    if (state is ProviderDashboardLoaded) {
      final currentState = state as ProviderDashboardLoaded;

      emit(currentState.copyWith(multipleRequests: event.acceptedRequests, clearIncomingRequest: true));
    }
  }

  Future<void> _onSelectRequest(SelectRequestEvent event, Emitter<ProviderDashboardState> emit) async {
    if (state is ProviderDashboardLoaded) {
      final currentState = state as ProviderDashboardLoaded;

      final selectedRequest = currentState.multipleRequests?.firstWhere((req) => req.id == event.requestId);

      if (selectedRequest != null) {
        final updatedUpcoming = [...currentState.upcomingServices, selectedRequest];

        emit(currentState.copyWith(upcomingServices: updatedUpcoming, clearMultipleRequests: true));
      }
    }
  }

  ProviderDashboardLoaded? _getDashboardData(ProviderDashboardState state) {
    if (state is ProviderDashboardLoaded) return state;
    if (state is RequestAccepted) return state.dashboardData;
    if (state is RequestExpired) return state.dashboardData;
    if (state is NewRequestReceived) return state.dashboardData;
    if (state is ProviderDashboardError) return state.dashboardData;
    return null;
  }
}
