import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../data/repositories/provider_repository.dart';
import '../../di/locator.dart';
import '../../features/service_provider/provider_home/data/models/service_request.dart';
import '../../features/service_provider/provider_requests/data/repositories/provider_request_repository.dart';
import '../api/api_client.dart';
import '../theme/app_colors.dart';
import 'location_service.dart';

// ═══════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════
abstract class IncomingRequestEvent extends Equatable {
  const IncomingRequestEvent();

  @override
  List<Object?> get props => [];
}

class InitializeRequest extends IncomingRequestEvent {
  final ServiceRequest request;

  const InitializeRequest(this.request);

  @override
  List<Object?> get props => [request];
}

class FetchRequestDetails extends IncomingRequestEvent {
  final int requestId;

  const FetchRequestDetails(this.requestId);

  @override
  List<Object?> get props => [requestId];
}

class UpdateProviderLocation extends IncomingRequestEvent {
  final LatLng location;

  const UpdateProviderLocation(this.location);

  @override
  List<Object?> get props => [location];
}

class AcceptRequest extends IncomingRequestEvent {
  final int requestId;

  const AcceptRequest(this.requestId);

  @override
  List<Object?> get props => [requestId];
}

class DeclineRequest extends IncomingRequestEvent {
  final int requestId;

  const DeclineRequest(this.requestId);

  @override
  List<Object?> get props => [requestId];
}

class RequestExpired extends IncomingRequestEvent {}

class ClearError extends IncomingRequestEvent {}

// ═══════════════════════════════════════════════════════════════
// STATES
// ═══════════════════════════════════════════════════════════════
class IncomingRequestState extends Equatable {
  final bool isLoadingDetails;
  final bool isAccepting;
  final bool isRejecting;
  final String? errorMessage;
  final String? successMessage;

  // Request data
  final String patientName;
  final String patientPhone;
  final String serviceType;
  final String address;
  final int age;
  final double payment;
  final double latitude;
  final double longitude;
  final String distance;
  final String? patientImageUrl;
  final String specialInstructions;

  // Map data
  final LatLng? providerLocation;
  final Set<Marker> markers;
  final Set<Polyline> polylines;

  // Status
  final RequestStatus status;

  final List<int> subBlockIds;

  const IncomingRequestState({
    this.isLoadingDetails = true,
    this.isAccepting = false,
    this.isRejecting = false,
    this.errorMessage,
    this.successMessage,
    this.patientName = '',
    this.patientPhone = '',
    this.serviceType = '',
    this.address = '',
    this.age = 0,
    this.payment = 0,
    this.latitude = 0,
    this.longitude = 0,
    this.distance = '',
    this.patientImageUrl,
    this.specialInstructions = '',
    this.providerLocation,
    this.markers = const {},
    this.polylines = const {},
    this.status = RequestStatus.idle,
    this.subBlockIds = const [],
  });

  IncomingRequestState copyWith({
    bool? isLoadingDetails,
    bool? isAccepting,
    bool? isRejecting,
    String? errorMessage,
    String? successMessage,
    String? patientName,
    String? patientPhone,
    String? serviceType,
    String? address,
    int? age,
    double? payment,
    double? latitude,
    double? longitude,
    String? distance,
    String? patientImageUrl,
    String? specialInstructions,
    LatLng? providerLocation,
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    RequestStatus? status,
    List<int>? subBlockIds,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return IncomingRequestState(
      isLoadingDetails: isLoadingDetails ?? this.isLoadingDetails,
      isAccepting: isAccepting ?? this.isAccepting,
      isRejecting: isRejecting ?? this.isRejecting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      patientName: patientName ?? this.patientName,
      patientPhone: patientPhone ?? this.patientPhone,
      serviceType: serviceType ?? this.serviceType,
      address: address ?? this.address,
      age: age ?? this.age,
      payment: payment ?? this.payment,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distance: distance ?? this.distance,
      patientImageUrl: patientImageUrl ?? this.patientImageUrl,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      providerLocation: providerLocation ?? this.providerLocation,
      markers: markers ?? this.markers,
      polylines: polylines ?? this.polylines,
      status: status ?? this.status,
      subBlockIds: subBlockIds ?? this.subBlockIds,
    );
  }

  @override
  List<Object?> get props => [
    isLoadingDetails,
    isAccepting,
    isRejecting,
    errorMessage,
    successMessage,
    patientName,
    patientPhone,
    serviceType,
    address,
    age,
    payment,
    latitude,
    longitude,
    distance,
    patientImageUrl,
    specialInstructions,
    providerLocation,
    markers,
    polylines,
    status,
    subBlockIds,
  ];
}

enum RequestStatus {
  idle,
  accepting,
  accepted,
  declining,
  declined,
  expired,
  requestNotAvailable, // Request already accepted by another provider or expired
}

// ═══════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════
class IncomingRequestBloc extends Bloc<IncomingRequestEvent, IncomingRequestState> {
  final ProviderRepository _repository;
  final ProviderRequestRepository _requestRepository;
  final LocationService _locationService;

  IncomingRequestBloc({
    ProviderRepository? repository,
    ProviderRequestRepository? requestRepository,
    LocationService? locationService,
  }) : _repository = repository ?? locator<ProviderRepository>(),
       _requestRepository = requestRepository ?? locator<ProviderRequestRepository>(),
       _locationService = locationService ?? locator<LocationService>(),
       super(const IncomingRequestState()) {
    on<InitializeRequest>(_onInitializeRequest);
    on<FetchRequestDetails>(_onFetchRequestDetails);
    on<UpdateProviderLocation>(_onUpdateProviderLocation);
    on<AcceptRequest>(_onAcceptRequest);
    on<DeclineRequest>(_onDeclineRequest);
    on<RequestExpired>(_onRequestExpired);
    on<ClearError>(_onClearError);
  }

  Future<void> _onInitializeRequest(InitializeRequest event, Emitter<IncomingRequestState> emit) async {
    kPrint('🔄 Initializing request overlay');

    // Initialize with notification data
    emit(
      state.copyWith(
        patientName: event.request.patientName,
        serviceType: event.request.serviceType,
        address: event.request.address,
        age: event.request.age,
        payment: event.request.payment,
        latitude: event.request.latitude,
        longitude: event.request.longitude,
        distance: event.request.distance,
        isLoadingDetails: true,
      ),
    );

    // Fetch provider location
    _fetchProviderLocation();

    // Fetch full request details
    final requestId = int.tryParse(event.request.id) ?? 0;

    if (requestId > 0) {
      add(FetchRequestDetails(requestId));
    } else {
      emit(state.copyWith(isLoadingDetails: false));
    }
  }

  Future<void> _fetchProviderLocation() async {
    try {
      final position = await _locationService.getLocationPosition();
      if (position != null) {
        add(UpdateProviderLocation(LatLng(position.latitude, position.longitude)));
      }
    } catch (e) {
      kPrint('❌ Location error: $e');
    }
  }

  Future<void> _onFetchRequestDetails(FetchRequestDetails event, Emitter<IncomingRequestState> emit) async {
    try {
      kPrint('📡 Fetching request details for ID: ${event.requestId}');
      final details = await _requestRepository.getRequestDetails(requestId: event.requestId);

      if (details != null) {
        final parsedSubBlockIds = details.subBlocks
            .map((b) => b.id)
            .where((id) => id > 0)
            .toList();
        emit(
          state.copyWith(
            patientName: details.customerName.isNotEmpty ? details.customerName : state.patientName,
            patientPhone: details.customerPhone ?? '',
            serviceType: details.serviceCategoryName.isNotEmpty ? details.serviceCategoryName : state.serviceType,
            payment: details.totalAmount ?? details.basePrice ?? state.payment,
            latitude: details.serviceLatitude != 0 ? details.serviceLatitude : state.latitude,
            longitude: details.serviceLongitude != 0 ? details.serviceLongitude : state.longitude,
            distance: details.distanceKm > 0 ? '${details.distanceKm.toStringAsFixed(1)} km' : state.distance,
            patientImageUrl: details.customerProfileImageUrl,
            specialInstructions: details.specialInstructions ?? '',
            isLoadingDetails: false,
            subBlockIds: parsedSubBlockIds,
          ),
        );

        // Update map with new coordinates
        _updateMapMarkers(emit);

        kPrint('✅ Request details loaded: ${details.customerName}, ${details.serviceCategoryName}');
      } else {
        emit(state.copyWith(isLoadingDetails: false));
      }
    } catch (e) {
      kPrint('❌ Error fetching request details: $e');

      // Check if the error is due to request not available (already accepted/expired)
      final errorMessage = e.toString();
      if (errorMessage.contains('already responded') ||
          errorMessage.contains('not found') ||
          errorMessage.contains('404')) {
        // Request is no longer available
        emit(
          state.copyWith(
            isLoadingDetails: false,
            status: RequestStatus.requestNotAvailable,
            errorMessage: 'This request has been accepted by another provider or has expired.',
          ),
        );
      } else {
        // Network or other error - still show overlay with notification data
        emit(state.copyWith(isLoadingDetails: false));
      }
    }
  }

  void _onUpdateProviderLocation(UpdateProviderLocation event, Emitter<IncomingRequestState> emit) {
    emit(state.copyWith(providerLocation: event.location));
    _updateMapMarkers(emit);
  }

  void _updateMapMarkers(Emitter<IncomingRequestState> emit) {
    final patientLocation = LatLng(state.latitude, state.longitude);
    final providerLoc = state.providerLocation;

    final markers = <Marker>{
      // Provider marker (blue)
      if (providerLoc != null)
        Marker(
          markerId: const MarkerId('provider'),
          position: providerLoc,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'You'),
        ),
      // Patient marker (red)
      if (state.latitude != 0)
        Marker(
          markerId: const MarkerId('patient'),
          position: patientLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: state.patientName),
        ),
    };

    // Draw route line
    final polylines = <Polyline>{};
    if (providerLoc != null && state.latitude != 0) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [providerLoc, patientLocation],
          color: kPrimaryColor,
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    }

    emit(state.copyWith(markers: markers, polylines: polylines));
  }

  Future<void> _onAcceptRequest(AcceptRequest event, Emitter<IncomingRequestState> emit) async {
    if (state.isAccepting) return;
    if (state.isRejecting) return;

    emit(state.copyWith(isAccepting: true, status: RequestStatus.accepting, clearError: true));

    try {
      kPrint('📞 Accepting request: ${event.requestId}');
      final result = await _repository.respondToRequest(
        requestId: event.requestId,
        accepted: true,
        subBlockIds: state.subBlockIds,
      );

      if (result.success) {
        emit(
          state.copyWith(
            isAccepting: false,
            status: RequestStatus.accepted,
            successMessage: '✅ Request accepted! Head to the patient location.',
          ),
        );
      }
    } catch (e) {
      kPrintError('Accept error: $e');

      final errorMessage = e.toString();
      // Detect if request is no longer available (already accepted by other provider or expired/deleted)
      if (errorMessage.contains('already accepted') ||
          errorMessage.contains('already responded') ||
          errorMessage.contains('no longer available') ||
          errorMessage.contains('Conflict') ||
          errorMessage.contains('409')) {
        emit(
          state.copyWith(
            isAccepting: false,
            status: RequestStatus.requestNotAvailable,
            errorMessage: errorMessage.replaceAll('Exception: ', '').replaceAll('AppException: ', ''),
          ),
        );
      } else {
        emit(
          state.copyWith(
            isAccepting: false,
            isRejecting: false,
            status: RequestStatus.idle,
            errorMessage: errorMessage.replaceAll('Exception: ', '').replaceAll('AppException: ', ''),
          ),
        );
      }
    }
  }

  Future<void> _onDeclineRequest(DeclineRequest event, Emitter<IncomingRequestState> emit) async {
    if (state.isAccepting) return;
    if (state.isRejecting) return;

    emit(state.copyWith(isRejecting: true, status: RequestStatus.declining));

    try {
      await _repository.respondToRequest(requestId: event.requestId, accepted: false);

      emit(state.copyWith(isRejecting: false, status: RequestStatus.declined));
    } catch (e) {
      kPrintError('Decline error: $e');
      // Even on error, mark as declined to close the overlay
      emit(state.copyWith(isRejecting: false, status: RequestStatus.declined));
    }
  }

  void _onRequestExpired(RequestExpired event, Emitter<IncomingRequestState> emit) {
    emit(
      state.copyWith(status: RequestStatus.expired, successMessage: 'Request expired – passed to next provider'),
    );
  }

  void _onClearError(ClearError event, Emitter<IncomingRequestState> emit) {
    emit(state.copyWith(clearError: true, clearSuccess: true));
  }
}
