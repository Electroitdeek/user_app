import 'dart:async';
import 'dart:math' as math;

import 'package:adhisaat_health_care/core/assets/app_assets.dart';
import 'package:adhisaat_health_care/core/utils/message_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../features/service_provider/provider_home/data/models/service_request.dart';
import '../../shared/widgets/buttons/custom_button.dart';
import '../api/api_client.dart';
import '../navigation/app_navigator.dart';
import '../navigation/app_routes.dart';
import '../theme/screen_dimensions.dart';
import 'incoming_request_bloc.dart';

import '../../features/service_provider/provider_home/bloc/provider_dashboard_bloc/provider_dashboard_bloc.dart';
import '../../features/service_provider/provider_home/bloc/provider_dashboard_bloc/provider_dashboard_event.dart';

/// Uber Driver-style full-screen incoming emergency request overlay.
/// Features:
/// - Full screen Google Maps with route
/// - Bottom sheet with request details
/// - Countdown timer with animation
/// - Looping emergency alert sound
/// - Accept/Decline buttons
class IncomingRequestOverlay extends StatefulWidget {
  final ServiceRequest request;
  final int timeoutSeconds;

  const IncomingRequestOverlay({super.key, required this.request, this.timeoutSeconds = 30});

  /// Tracker for active overlay to prevent multiple overlaps
  static bool _isShowing = false;

  /// Show the overlay as a full-screen dialog
  static Future<dynamic> show(BuildContext context, ServiceRequest request) async {
    kPrint(request);
    if (_isShowing) {
      debugPrint('IncomingRequestOverlay already showing. Ignoring multiple request overlay for now.');
      return;
    }
    _isShowing = true;

    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (_, anim, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
      pageBuilder: (ctx, _, _) => PopScope(
        canPop: true,
        // When popping via back button, we want it to return true so the caller knows to refresh
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            // we can't easily change the result here since it's already popped, 
            // but the caller will handle any pop result as a trigger to refresh
          }
        },
        child: BlocProvider(
          create: (_) => IncomingRequestBloc()..add(InitializeRequest(request)),
          child: IncomingRequestOverlay(
            request: request,
            timeoutSeconds: 60, // Global timeout 60 sec as requested
          ),
        ),
      ),
    ).then((value) {
      _isShowing = false;
      try {
        if (context.mounted) {
          context.read<ProviderDashboardBloc>().add(RefreshDashboardEvent());
        }
      } catch (e) {
        debugPrint('ProviderDashboardBloc not found for refresh: $e');
      }
      return value;
    });
  }

  @override
  State<IncomingRequestOverlay> createState() => _IncomingRequestOverlayState();
}

class _IncomingRequestOverlayState extends State<IncomingRequestOverlay> with TickerProviderStateMixin {
  // Controllers (UI-specific, stay in widget)
  late AnimationController _timerController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  // Timer (UI-specific)
  late Timer _countdownTimer;
  int _secondsLeft = 0;

  // Audio (UI-specific)
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Map
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.timeoutSeconds;

    _initAnimations();
    _startCountdown();
    _playAlertSound();
  }

  void _initAnimations() {
    // Timer countdown animation
    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.timeoutSeconds),
    )..forward();

    // Pulse animation for emergency badge
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    // Slide up animation for bottom sheet
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    // Delay slide animation slightly
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _slideController.forward();
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsLeft--);

      if (_secondsLeft <= 0) {
        timer.cancel();
        _autoExpire();
      }
    });
  }

  Future<void> _playAlertSound() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource(AppAssets.emergencySound));
    } catch (e) {
      kPrint('Audio error: $e');
      // Fallback to system sound
    }
  }

  Future<void> _stopAlertSound() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      kPrint('Audio stop error: $e');
    }
  }

  void _fitMapToBounds(LatLng providerLocation, LatLng patientLocation) {
    if (_mapController == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(providerLocation.latitude, patientLocation.latitude),
        math.min(providerLocation.longitude, patientLocation.longitude),
      ),
      northeast: LatLng(
        math.max(providerLocation.latitude, patientLocation.latitude),
        math.max(providerLocation.longitude, patientLocation.longitude),
      ),
    );

    // 1) Fit both markers with more padding so the camera is slightly zoomed out.
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 140), // was 80
    );

    // 2) Nudge the camera down so route + patient pin move up above the bottom sheet.
    Future.delayed(const Duration(milliseconds: 450), () async {
      // Check if widget is still mounted before using map controller
      if (!mounted || _mapController == null) return;

      try {
        final visibleRegion = await _mapController!.getVisibleRegion();
        final centerLat = (visibleRegion.northeast.latitude + visibleRegion.southwest.latitude) / 2;
        final centerLng = (visibleRegion.northeast.longitude + visibleRegion.southwest.longitude) / 2;

        final latSpan = (visibleRegion.northeast.latitude - visibleRegion.southwest.latitude).abs();

        // Shift the center by ~35% of the visible height.
        // This keeps the route away from the bottom sheet on most devices.
        final double latOffset = -latSpan * 0.30;
        final adjustedCenter = LatLng(centerLat + latOffset, centerLng);

        // Check mounted again before animating
        if (!mounted) return;
        _mapController!.animateCamera(CameraUpdate.newLatLng(adjustedCenter));
      } catch (e) {
        // Ignore errors if controller is disposed
        kPrint('Map camera adjustment skipped (widget disposed): $e');
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    _timerController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _stopAlertSound();
    _audioPlayer.dispose();
    _mapController?.dispose();
    _mapController = null;
    super.dispose();
  }

  void _autoExpire() {
    if (!mounted) return;
    _stopAlertSound();
    context.read<IncomingRequestBloc>().add(RequestExpired());
  }

  Future<void> _accept() async {
    final bloc = context.read<IncomingRequestBloc>();
    if (bloc.state.isAccepting) return;

    _stopAlertSound();
    _countdownTimer.cancel();
    _timerController.stop();
    HapticFeedback.heavyImpact();

    final requestId = widget.request.bookingId > 0
        ? widget.request.bookingId
        : int.tryParse(widget.request.id) ?? 0;

    kPrint('📞 Dispatching AcceptRequest event: $requestId');
    bloc.add(AcceptRequest(requestId));
  }

  Future<void> _decline() async {
    final bloc = context.read<IncomingRequestBloc>();
    if (bloc.state.isAccepting) return;

    _stopAlertSound();
    _countdownTimer.cancel();
    _timerController.stop();
    HapticFeedback.mediumImpact();

    final requestId = widget.request.bookingId > 0
        ? widget.request.bookingId
        : int.tryParse(widget.request.id) ?? 0;

    kPrint('📞 Dispatching DeclineRequest event: $requestId');
    bloc.add(DeclineRequest(requestId));
  }

  Color get _timerColor {
    if (_secondsLeft > 20) return kSuccessColor;
    if (_secondsLeft > 10) return kWarningColor;
    return kErrorColor;
  }

  String get _formattedTime {
    int displaySeconds = _secondsLeft;

    // For normal requests, show timer starting from 2 hours
    if (!widget.request.isEmergency) {
      // Calculate how much time has passed from the actual 30s timeout
      int elapsed = widget.timeoutSeconds - _secondsLeft;
      // Show 2 hours (7200s) minus the elapsed time
      displaySeconds = 7200 - elapsed;
    }

    final hours = displaySeconds ~/ 3600;
    final minutes = (displaySeconds % 3600) ~/ 60;
    final seconds = displaySeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<IncomingRequestBloc, IncomingRequestState>(
      listener: (context, state) {
        // Handle request not available (already accepted by another provider or expired)
        if (state.status == RequestStatus.requestNotAvailable) {
          _stopAlertSound();
          Navigator.of(context).pop();
          MessageService.showInfo(state.errorMessage ?? 'This request is no longer available');
          return;
        }

        // Handle accept success
        if (state.status == RequestStatus.accepted) {
          Navigator.of(context).pop();
          MessageService.showSuccess(state.successMessage ?? 'Request accepted successfully');

          // Navigate to request detail page
          Future.delayed(const Duration(milliseconds: 300), () {
            final ctx = AppNavigator.navigatorKey.currentContext;
            if (ctx != null) {
              final requestId = widget.request.bookingId > 0
                  ? widget.request.bookingId
                  : int.tryParse(widget.request.id) ?? 0;

              AppNavigator.to(AppRoutes.providerRequestDetail, arguments: requestId);
            }
          });
        }

        // Handle decline success
        if (state.status == RequestStatus.declined) {
          Navigator.of(context).pop();
        }

        // Handle expired
        if (state.status == RequestStatus.expired) {
          Navigator.of(context).pop();
          final message = 'Please check bookings page for further details (Providers)';
          if (widget.request.isEmergency) {
            MessageService.showWarning(message);
          } else {
            MessageService.showInfo(message);
          }
        }

        // Resume alert sound on error
        if (state.errorMessage != null && state.status == RequestStatus.idle) {
          _playAlertSound();
        }

        // Fit map bounds when provider location updates
        if (state.providerLocation != null && state.latitude != 0) {
          _fitMapToBounds(state.providerLocation!, LatLng(state.latitude, state.longitude));
        }
      },
      builder: (context, state) {
        return Scaffold(
          body: Stack(
            children: [
              // ═══════════════════════════════════════════════════════════
              // BACKGROUND: Google Maps
              // ═══════════════════════════════════════════════════════════
              _buildMap(state),

              // ═══════════════════════════════════════════════════════════
              // BOTTOM SHEET: Request Details
              // ═══════════════════════════════════════════════════════════
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SlideTransition(position: _slideAnimation, child: _buildBottomSheet(state)),
              ),

              // ═══════════════════════════════════════════════════════════
              // TOP: Distance Badge
              // ═══════════════════════════════════════════════════════════
              if (state.distance.isNotEmpty)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  right: 16,
                  child: _buildDistanceBadge(state),
                ),

              // Loading indicator for API details
              if (state.isLoadingDetails)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14.w,
                          height: 14.w,
                          child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor),
                        ),
                        SizedBox(width: 8.w),
                        Text('Loading details...', style: kTextNormal0()),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMap(IncomingRequestState state) {
    final patientLocation = LatLng(
      state.latitude != 0 ? state.latitude : 26.9124,
      state.longitude != 0 ? state.longitude : 75.7873,
    );

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: patientLocation, zoom: 14),
      onMapCreated: (controller) {
        _mapController = controller;
        // Fit bounds if we have provider location
        if (state.providerLocation != null && state.latitude != 0) {
          _fitMapToBounds(state.providerLocation!, patientLocation);
        }
      },
      markers: state.markers,
      polylines: state.polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
    );
  }

  Widget _buildDistanceBadge(IncomingRequestState state) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_car, size: 18.sp, color: kPrimaryColor),
          SizedBox(width: 8.w),
          Text(state.distance, style: kTextBold1(color: kPrimaryColor)),
          Text(' away', style: kTextNormal0(color: kGreyColor6)),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(IncomingRequestState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 12.h, bottom: 16.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2.r)),
              ),

              // Emergency Banner with Timer
              _buildEmergencyBanner(),
              SizedBox(height: 20.h),

              // Patient Info Card
              _buildPatientCard(state),
              SizedBox(height: 16.h),

              // Service Details
              _buildServiceDetails(state),
              SizedBox(height: 16.h),

              // Location
              _buildLocationRow(state),
              SizedBox(height: 20.h),

              // Error message
              if (state.errorMessage != null) ...[_buildErrorMessage(state), SizedBox(height: 12.h)],

              // Action Buttons
              _buildActionButtons(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyBanner() {
    return ScaleTransition(
      scale: widget.request.isEmergency ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.request.isEmergency
                ? [const Color(0xFFDC2626), const Color(0xFFB91C1C)]
                : [kPrimaryColor, const Color(0xFF1E40AF)],
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: (widget.request.isEmergency ? kErrorColor : kPrimaryColor).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Emergency icon
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                widget.request.isEmergency ? Icons.emergency : Icons.notifications_active,
                color: Colors.white,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 12.w),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.request.isEmergency ? '🚨 EMERGENCY REQUEST' : '🔔 NEW REQUEST',
                    style: kTextBold1(color: Colors.white),
                  ),
                  SizedBox(height: 2.h),
                  Text('Respond within', style: kTextNormal0(color: Colors.white70)),
                ],
              ),
            ),

            // Timer
            _buildTimer(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimer() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated timer icon
          AnimatedBuilder(
            animation: _timerController,
            builder: (_, _) => Icon(Icons.timer, size: 18.sp, color: _timerColor),
          ),
          SizedBox(width: 6.w),
          // Time text
          Text(
            _formattedTime,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: _timerColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(IncomingRequestState state) {
    return Row(
      children: [
        // Avatar - show image if available, otherwise initials
        Container(
          width: 60.w,
          height: 60.w,
          decoration: BoxDecoration(
            gradient: state.patientImageUrl == null
                ? LinearGradient(
                    colors: widget.request.isEmergency
                        ? [kErrorColor, const Color(0xFFB91C1C)]
                        : [kPrimaryColor, kSecondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: (widget.request.isEmergency ? kErrorColor : kPrimaryColor).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            image: state.patientImageUrl != null
                ? DecorationImage(image: NetworkImage(state.patientImageUrl!), fit: BoxFit.cover)
                : null,
          ),
          child: state.patientImageUrl == null
              ? Center(
                  child: Text(
                    _getInitials(state.patientName),
                    style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                )
              : null,
        ),
        SizedBox(width: 16.w),

        // Name and Age
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person, size: 16.sp, color: kGreyColor6),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      state.patientName.isNotEmpty ? state.patientName : 'Patient',
                      style: kTextBold2(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (state.age > 0) ...[
                SizedBox(height: 4.h),
                Text('${state.age} years old', style: kTextNormal0(color: kGreyColor6)),
              ],
            ],
          ),
        ),

        // Payment badge
        if (state.payment > 0)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: kSuccessColor,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(color: kSuccessColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Text('₹${state.payment.toInt()}', style: kTextBold1(color: Colors.white)),
          ),
      ],
    );
  }

  Widget _buildServiceDetails(IncomingRequestState state) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: (widget.request.isEmergency ? kErrorColor : kPrimaryColor).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: (widget.request.isEmergency ? kErrorColor : kPrimaryColor).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: (widget.request.isEmergency ? kErrorColor : kPrimaryColor).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.medical_services,
              color: widget.request.isEmergency ? kErrorColor : kPrimaryColor,
              size: 22.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Service Required', style: kTextNormal0(color: kGreyColor6)),
                SizedBox(height: 2.h),
                Text(
                  state.serviceType.isNotEmpty ? state.serviceType : 'Emergency Service',
                  style: kTextSemiBold1(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(IncomingRequestState state) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: kInfoColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: kInfoColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: kInfoColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(Icons.location_on, color: kInfoColor, size: 22.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pickup Location', style: kTextNormal0(color: kGreyColor6)),
                    SizedBox(height: 2.h),
                    Text(
                      state.address.isNotEmpty ? state.address : 'Location will be shared',
                      style: kTextSemiBold(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Special instructions if available
          if (state.specialInstructions.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: kWarningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes, size: 16.sp, color: kWarningColor),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      state.specialInstructions,
                      style: kTextNormal0(color: kGreyColor6),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorMessage(IncomingRequestState state) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: kErrorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: kErrorColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: kErrorColor, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(state.errorMessage!, style: kTextNormal0(color: kErrorColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(IncomingRequestState state) {
    return Row(
      children: [
        // DECLINE Button
        Expanded(
          flex: 2,
          child: CustomButton(
            title: 'DECLINE',
            onPressed: _decline,
            isLoading: state.isRejecting,
            backgroundColor: kWhiteColor,
            textStyle: kTextBold(color: kErrorColor),
            borderSide: BorderSide(color: kErrorColor, width: 1.5),
            borderRadius: BorderRadius.circular(16.r),
            height: AppButtonHeight.s,
            innerPadding: EdgeInsets.symmetric(horizontal: 16.w),
            iconData: Icons.close,
            iconColor: kErrorColor,
          ),
        ),
        SizedBox(width: 12.w),

        // ACCEPT Button
        Expanded(
          flex: 3,
          child: CustomButton(
            title: 'ACCEPT',
            onPressed: _accept,
            isLoading: state.isAccepting,
            backgroundColor: kSuccessColor,
            textStyle: kTextBold(color: Colors.white),
            height: AppButtonHeight.s,
            borderRadius: BorderRadius.circular(16.r),
            innerPadding: EdgeInsets.symmetric(horizontal: 20.w),
            iconData: Icons.check_circle,
            iconColor: Colors.white,
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'P';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}
