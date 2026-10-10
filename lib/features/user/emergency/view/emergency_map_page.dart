import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/providers/system_settings_provider.dart';
import '../../../../di/locator.dart';
import '../../../../shared/widgets/common/app_cached_image.dart';
import '../../../../shared/widgets/dialogs/dialog_helpers.dart';
import '../../address/bloc/selected_address_provider.dart';
import '../../service_booking/model/service_category_model.dart';
import '../bloc/emergency_map/emergency_map_bloc.dart';

class EmergencyMapPage extends ConsumerStatefulWidget {
  final ServiceCategoryModel category;
  final String? instructions;
  final int? familyMemberId;
  final String? familyMemberName;
  final String? latitude;
  final String? longitude;

  const EmergencyMapPage({
    super.key,
    required this.category,
    this.instructions,
    this.familyMemberId,
    this.familyMemberName,
    this.latitude,
    this.longitude,
  });

  @override
  ConsumerState<EmergencyMapPage> createState() => _EmergencyMapPageState();
}

class _EmergencyMapPageState extends ConsumerState<EmergencyMapPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  static const String _silverMapStyle = '''
[
  { "elementType": "geometry", "stylers": [ { "color": "#f8f9fa" } ] },
  { "elementType": "labels.icon", "stylers": [ { "visibility": "off" } ] },
  { "elementType": "labels.text.fill", "stylers": [ { "color": "#525f7f" } ] },
  { "elementType": "labels.text.stroke", "stylers": [ { "color": "#f8f9fa" } ] },
  { "featureType": "administrative.land_parcel", "elementType": "labels.text.fill", "stylers": [ { "color": "#adb5bd" } ] },
  { "featureType": "landscape.natural.terrain", "elementType": "geometry", "stylers": [ { "color": "#b8b8b8" }, { "visibility": "on" } ] },
  { "featureType": "poi", "elementType": "geometry", "stylers": [ { "color": "#f1f3f5" } ] },
  { "featureType": "poi.park", "elementType": "geometry", "stylers": [ { "color": "#e2f3e8" } ] },
  { "featureType": "road", "elementType": "geometry", "stylers": [ { "color": "#ffffff" } ] },
  { "featureType": "road.arterial", "elementType": "labels.text.fill", "stylers": [ { "color": "#8898aa" } ] },
  { "featureType": "road.highway", "elementType": "geometry", "stylers": [ { "color": "#e9ecef" } ] },
  { "featureType": "water", "elementType": "geometry", "stylers": [ { "color": "#c5e3ff" } ] },
  { "featureType": "water", "elementType": "labels.text.fill", "stylers": [ { "color": "#525f7f" } ] }
]
''';

  double _radiusKm = 5;

  // Timer
  int _totalWaitSeconds = 300;
  DateTime? _deadline;
  Timer? _timer;
  int? _secondsLeft;

  late AnimationController _pulseCtrl;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnimation;
  GoogleMapController? _mapController;

  // Pre-built marker cache
  BitmapDescriptor? _userMarkerIcon;
  final Map<String, BitmapDescriptor> _providerMarkerCache = {};
  bool _isExpanding = false;

  List<Map<String, dynamic>> _allProviders = [];
  Set<Marker> _cachedMarkers = {};
  double? _cachedLat;
  double? _cachedLng;
  bool _markersBuilding = false;
  int _lastExpandedAt = 300;
  bool _isShowingNoProviderDialog = false;
  bool _hasShownNoProviderDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _radiusKm = ref.read(radiusIncreaseStepProvider);

    _preloadUserMarker();

    _lastExpandedAt = 300;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSearch();
      locator<NotificationService>().registerBlocCallback(_handleNotification);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _deadline != null) {
      _syncTimerWithDeadline();
    }
  }

  void _syncTimerWithDeadline() {
    if (_deadline == null) return;
    final remaining = _deadline!.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) {
      _timer?.cancel();
      setState(() => _secondsLeft = 0);
      _onTimeExpired();
    } else {
      setState(() => _secondsLeft = remaining);
    }
  }

  void _startSearch() {
    final selectedAddress = ref.read(selectedAddressProvider);
    context.read<EmergencyMapBloc>().add(
      SearchNearbyProviders(
        serviceCategory: widget.category,
        radiusKm: _radiusKm,
        selectedAddressId: selectedAddress?.id,
        fullAddress: selectedAddress?.fullAddress,
        familyMemberId: widget.familyMemberId,
        familyMemberName: widget.familyMemberName,
        instructions: widget.instructions,
        latitude: widget.latitude,
        longitude: widget.longitude,
      ),
    );
  }

  void _startTimer({int? seconds}) {
    _timer?.cancel();
    final waitSeconds = seconds ?? _totalWaitSeconds;
    _totalWaitSeconds = waitSeconds;
    _deadline = DateTime.now().add(Duration(seconds: waitSeconds));
    setState(() => _secondsLeft = waitSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_deadline == null) {
        timer.cancel();
        return;
      }
      final remaining = _deadline!.difference(DateTime.now()).inSeconds;
      if (remaining > 0) {
        setState(() => _secondsLeft = remaining);
        if (remaining % 30 == 0) {
          context.read<EmergencyMapBloc>().add(CheckEmergencyBookingStatus());
        }
      } else {
        timer.cancel();
        setState(() => _secondsLeft = 0);
        _onTimeExpired();
      }
    });
  }

  void _onTimeExpired() {
    DialogHelper.showError(
      title: "No Partners Available",
      message: "Sorry, no partners are currently available in your area. Please try again in a few minutes.",
      buttonText: "Try Again",
      dismissText: "Home Page",
      onConfirm: () {
        // Close the dialog, then send the user back to the Confirm Emergency page to retry.
        Navigator.pop(context);
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.emergencyConfirm,
          arguments: widget.category,
        );
      },
      barrierDismissible: false,
      onDismiss: () {
        // context.read<EmergencyMapBloc>().add(CancelEmergencyRequest());
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.userDashboard, (r) => false);
      },
    );
  }

  void _showNoProviderFoundDialog() {
    if (_isShowingNoProviderDialog) return;
    _isShowingNoProviderDialog = true;

    final maxSearchRadius = ref.read(maxSearchRadiusProvider);
    final radiusIncreaseStep = ref.read(radiusIncreaseStepProvider);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'No Partner Found',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Container(
            width: 320.w,
            margin: EdgeInsets.symmetric(horizontal: 20.w),
            decoration: BoxDecoration(
              color: kWhiteColor,
              borderRadius: BorderRadius.circular(28.r),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.all(24.r),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 10.h),
                        Container(
                          padding: EdgeInsets.all(16.r),
                          decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: Icon(Icons.location_off_rounded, color: kErrorColor, size: 32.sp),
                        ),
                        SizedBox(height: 20.h),
                        Text(
                          'No Nearby Partner Found',
                          style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 18.sp),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'We couldn\'t find any partners within ${_radiusKm.toInt()} km radius. Please increase the search radius to continue.',
                          style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 14.sp),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 24.h),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              if (_isExpanding) return;
                              final newRadius = _radiusKm + radiusIncreaseStep;
                              if (newRadius <= maxSearchRadius) {
                                setState(() {
                                  _radiusKm = newRadius;
                                  _isExpanding = true;
                                  _lastExpandedAt = _secondsLeft ?? 300;
                                });
                                _startSearch();
                                Future.delayed(const Duration(seconds: 5), () {
                                  if (mounted) setState(() => _isExpanding = false);
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                              elevation: 0,
                            ),
                            child: Text('Increase Search Radius', style: kTextBold(color: kWhiteColor)),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'Distance charges may apply',
                          style: kTextNormal(color: kTextSecondaryColor.withValues(alpha: 0.6)).copyWith(fontSize: 10.sp),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12.r,
                    right: 12.r,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: kTextSecondaryColor, size: 20.sp),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutBack)),
            child: child,
          ),
        );
      },
    ).then((_) => _isShowingNoProviderDialog = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    locator<NotificationService>().unregisterBlocCallback(_handleNotification);
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    _timer?.cancel();
    final ctrl = _mapController;
    _mapController = null;
    try {
      ctrl?.dispose();
    } catch (_) {}
    super.dispose();
  }

  void _handleNotification(String type, Map<String, dynamic> data) {
    if (!mounted) return;
    final emergencyBloc = context.read<EmergencyMapBloc>();
    if (type == 'request_accepted' || type == 'provider_accepted') {
      emergencyBloc.add(
        BookingAcceptedNotificationReceived(
          providerName: data['provider_name']?.toString(),
          providerPhone: data['provider_mobile']?.toString(),
          providerRating: double.tryParse(data['provider_rating']?.toString() ?? ''),
        ),
      );
    } else if (type == 'all_providers_declined') {
      emergencyBloc.add(AllProvidersDeclinedNotificationReceived());
    } else if (type == 'booking_expired') {
      emergencyBloc.add(BookingExpiredNotificationReceived());
    }
  }

  Future<void> _preloadUserMarker() async {
    _userMarkerIcon = await _buildUserMarker();
    if (mounted) setState(() {});
  }

  Future<BitmapDescriptor> _buildUserMarker() async {
    const double size = 44.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Outer pulse-like glow
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2.2,
      Paint()
        ..color = kPrimaryColor.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Main marker shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(const Offset(size / 2, size / 2 + 1), size / 4, shadowPaint);

    // White outer border
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 4, Paint()..color = Colors.white);

    // Primary color circle
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 5,
      Paint()
        ..shader = const LinearGradient(
          colors: [kPrimaryColor, Color(0xFF5B8DEF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: const Offset(size / 2, size / 2), radius: size / 5)),
    );

    // Center dot
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 12, Paint()..color = Colors.white);

    final pic = recorder.endRecording();
    final img = await pic.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _getProviderMarkerIcon(String providerId, String name, String? imageUrl) async {
    if (_providerMarkerCache.containsKey(providerId)) {
      return _providerMarkerCache[providerId]!;
    }

    const double size = 64.0; // Increased from 48
    const double radius = 24.0; // Increased from 18
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Shadow - Premium Glow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(const Offset(size / 2, size / 2 + 1), radius, shadowPaint);

    // Primary Border (Gradient-like effect with layers)
    canvas.drawCircle(const Offset(size / 2, size / 2), radius + 1, Paint()..color = kPrimaryColor.withValues(alpha: 0.2));
    canvas.drawCircle(const Offset(size / 2, size / 2), radius, Paint()..color = Colors.white);

    // Avatar Circle (Clip)
    final avatarRect = Rect.fromCircle(center: Offset(size / 2, size / 2), radius: radius - 2.5);
    canvas.save();
    canvas.clipPath(Path()..addOval(avatarRect));

    bool imageLoaded = false;
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      try {
        final Completer<ui.Image> completer = Completer();
        final ImageStream stream = NetworkImage(imageUrl).resolve(ImageConfiguration.empty);
        final ImageStreamListener listener = ImageStreamListener(
          (ImageInfo info, bool _) {
            if (!completer.isCompleted) completer.complete(info.image);
          },
          onError: (dynamic exception, StackTrace? stackTrace) {
            if (!completer.isCompleted) completer.completeError(exception);
          },
        );
        stream.addListener(listener);

        // Increased timeout for better reliability on slower networks
        final ui.Image image = await completer.future.timeout(const Duration(milliseconds: 3000));
        paintImage(canvas: canvas, rect: avatarRect, image: image, fit: BoxFit.cover);
        imageLoaded = true;
      } catch (e) {
        debugPrint('Error loading marker image for $providerId: $e');
        imageLoaded = false;
      }
    }

    if (!imageLoaded) {
      // Fallback: Premium Initials Placeholder
      final initials = _getInitials(name);
      canvas.drawRect(avatarRect, Paint()..color = kPrimaryColor);

      final tp = TextPainter(
        text: TextSpan(
          text: initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16, // Increased from 13
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(size / 2 - tp.width / 2, size / 2 - tp.height / 2));
    }
    canvas.restore();

    // Tail / Pin point
    final ptr = Path()
      ..moveTo(size / 2 - 6, size / 2 + radius - 1)
      ..lineTo(size / 2, size / 2 + radius + 8)
      ..lineTo(size / 2 + 6, size / 2 + radius - 1)
      ..close();
    canvas.drawPath(ptr, Paint()..color = Colors.white);

    // Tiny dot on tail for premium feel
    canvas.drawCircle(Offset(size / 2, size / 2 + radius + 1), 1.5, Paint()..color = kPrimaryColor);

    final pic = recorder.endRecording();
    final img = await pic.toImage(size.toInt(), size.toInt() + 10);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
    _providerMarkerCache[providerId] = descriptor;
    return descriptor;
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'P';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      final first = parts[0].isNotEmpty ? parts[0][0] : '';
      final last = parts[parts.length - 1].isNotEmpty ? parts[parts.length - 1][0] : '';
      return (first + last).toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'P';
  }

  Future<void> _rebuildMarkers(double lat, double lng) async {
    if (_markersBuilding) return;
    _markersBuilding = true;

    final Set<Marker> markers = {};

    markers.add(
      Marker(
        markerId: const MarkerId('me'),
        position: LatLng(lat, lng),
        icon: _userMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 2,
      ),
    );

    final futures = <Future<Marker>>[];
    for (int i = 0; i < _allProviders.length; i++) {
      final provider = _allProviders[i];
      futures.add(_buildProviderMarker(provider, i, lat, lng));
    }
    final providerMarkers = await Future.wait(futures);
    markers.addAll(providerMarkers);

    _markersBuilding = false;
    _cachedLat = lat;
    _cachedLng = lng;

    if (mounted) {
      setState(() => _cachedMarkers = markers);
    }
  }

  Future<Marker> _buildProviderMarker(Map<String, dynamic> provider, int i, double userLat, double userLng) async {
    double pLat = userLat;
    double pLng = userLng;

    if (provider['current_latitude'] != null) {
      pLat = double.tryParse(provider['current_latitude'].toString()) ?? pLat;
    } else if (provider['latitude'] != null) {
      pLat = double.tryParse(provider['latitude'].toString()) ?? pLat;
    } else {
      pLat += (i + 1) * 0.003;
    }

    if (provider['current_longitude'] != null) {
      pLng = double.tryParse(provider['current_longitude'].toString()) ?? pLng;
    } else if (provider['longitude'] != null) {
      pLng = double.tryParse(provider['longitude'].toString()) ?? pLng;
    } else {
      pLng += (i + 1) * 0.003;
    }

    final String name = provider['provider_name']?.toString() ?? 'Partner';
    final String? imageUrl =
        provider['profile_image_url']?.toString() ??
        provider['provider_detatils']?['user']?['profile_image_url']?.toString() ??
        provider['provider_image']?['provider_detatils']?['user']?['profile_image_url']?.toString();
    final String providerId = provider['provider_id']?.toString() ?? i.toString();

    final icon = await _getProviderMarkerIcon(providerId, name, imageUrl);

    return Marker(
      markerId: MarkerId('p_${provider['provider_id'] ?? i}'),
      position: LatLng(pLat, pLng),
      icon: icon,
      anchor: const Offset(0.5, 1.0),
      zIndexInt: 1,
      infoWindow: InfoWindow(
        title: provider['provider_name']?.toString() ?? 'Partner',
        snippet: '${provider['distance_text'] ?? ''} • ${provider['arrival_text'] ?? ''} away',
      ),
    );
  }

  void _animateToProvider(Map<String, dynamic> provider, int index) {
    if (!mounted || _mapController == null) return;
    double? pLat, pLng;

    if (provider['current_latitude'] != null) {
      pLat = double.tryParse(provider['current_latitude'].toString());
    } else if (provider['latitude'] != null) {
      pLat = double.tryParse(provider['latitude'].toString());
    }

    if (provider['current_longitude'] != null) {
      pLng = double.tryParse(provider['current_longitude'].toString());
    } else if (provider['longitude'] != null) {
      pLng = double.tryParse(provider['longitude'].toString());
    }

    // Fallback if no lat/lng
    if (pLat == null || pLng == null) {
      if (_cachedLat != null && _cachedLng != null) {
        pLat = _cachedLat! + (index + 1) * 0.003;
        pLng = _cachedLng! + (index + 1) * 0.003;
      } else {
        return;
      }
    }

    try {
      _mapController?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(pLat, pLng), zoom: 14.5)));
    } catch (e) {
      debugPrint("Error animating to provider: $e");
    }
  }

  void _showCancelConfirmation() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = Curves.easeOutCubic.transform(anim1.value);
        return Transform.scale(
          scale: 0.9 + (curve * 0.1),
          child: Opacity(
            opacity: anim1.value,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Material(
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width - 48.w,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.white, Colors.grey.shade50], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(32.r),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 40, offset: const Offset(0, 20))],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 32.h),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [kErrorColor.withValues(alpha: 0.08), kErrorColor.withValues(alpha: 0.02)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 80.w,
                                height: 80.w,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [kErrorColor.withValues(alpha: 0.15), kErrorColor.withValues(alpha: 0.05)]),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.warning_amber_rounded, color: kErrorColor, size: 44.sp),
                              ),
                              SizedBox(height: 20.h),
                              Text(
                                'Cancel Request?',
                                style: kTextBold2(color: kTextPrimaryColor).copyWith(fontSize: 22.sp),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 32.h),
                          child: Column(
                            children: [
                              Text(
                                'This will stop our priority search for nearby medical partners. Are you sure you want to cancel?',
                                style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 15.sp, height: 1.5),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 32.h),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      style: OutlinedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(vertical: 16.h),
                                        side: BorderSide(color: kGreyColor, width: 1.5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                                        backgroundColor: Colors.white,
                                      ),
                                      child: Text('Go Back', style: kTextSemiBold(color: kTextSecondaryColor)),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        context.read<EmergencyMapBloc>().add(CancelEmergencyRequest());
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kErrorColor,
                                        foregroundColor: kWhiteColor,
                                        padding: EdgeInsets.symmetric(vertical: 16.h),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                                      ),
                                      child: Text('Cancel', style: kTextSemiBold(color: kWhiteColor)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxSearchRadius = ref.watch(maxSearchRadiusProvider);
    final radiusIncreaseStep = ref.watch(radiusIncreaseStepProvider);
    final minutes = _secondsLeft != null ? (_secondsLeft! ~/ 60).toString().padLeft(2, '0') : '';
    final seconds = _secondsLeft != null ? (_secondsLeft! % 60).toString().padLeft(2, '0') : '';
    final formatTime = _secondsLeft != null ? '$minutes:$seconds' : '';
    final timerProgress = _secondsLeft != null && _totalWaitSeconds > 0 ? _secondsLeft! / _totalWaitSeconds : 0.0;
    final isUrgent = _secondsLeft != null && _secondsLeft! < 60;

    return BlocConsumer<EmergencyMapBloc, EmergencyMapState>(
      listener: (context, state) {
        if (state is EmergencyMapCancelled) {
          if (mounted) {
            DialogHelper.showInfo(title: 'Cancelled', message: 'Your have cancel your request');
            Future.delayed(const Duration(seconds: 2), () {
              if (!context.mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.userDashboard, (r) => false);
            });
          }
        } else if (state is EmergencyMapBookingAccepted) {
          _timer?.cancel();
          Navigator.of(context).pushReplacementNamed(AppRoutes.serviceRequestDetail, arguments: state.bookingId);
        } else if (state is EmergencyMapError) {
          DialogHelper.showError(message: state.message, title: '');
        } else if (state is EmergencyMapProvidersFound) {
          bool newProvidersAdded = false;
          final existingIds = _allProviders.map((p) => p['provider_id']).toSet();
          for (final p in state.notifiedProviders) {
            if (!existingIds.contains(p['provider_id'])) {
              _allProviders.add(p);
              newProvidersAdded = true;
            }
          }

          final waitSec = state.waitingWindowSeconds ?? 300;
          if (_deadline == null) {
            _startTimer(seconds: waitSec);
            _lastExpandedAt = waitSec;
          }

          final posChanged = _cachedLat != state.latitude || _cachedLng != state.longitude;
          if (newProvidersAdded || posChanged) {
            _rebuildMarkers(state.latitude, state.longitude);
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _mapController == null) return;
            try {
              if (_allProviders.isNotEmpty) {
                _animateToProvider(_allProviders.first, 0);
              } else {
                _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(state.latitude, state.longitude), 13));
              }
            } catch (e) {
              debugPrint("Error in post-frame map animation: $e");
            }
          });
        } else if (state is EmergencyMapBookingExpired) {
          _timer?.cancel();
          DialogHelper.showError(title: "Timeout", message: "No provider accepted your request. Searching again...");
          setState(() {
            _allProviders = [];
            _cachedMarkers = {};
          });
          _startSearch();
        } else if (state is EmergencyMapNoProviders) {
          if (!_hasShownNoProviderDialog) {
            _showNoProviderFoundDialog();
            _hasShownNoProviderDialog = true;
          }
        }
      },
      builder: (context, state) {
        final bool searching =
            state is EmergencyMapSearching || state is EmergencyMapInitial || state is EmergencyMapProvidersFound || state is EmergencyMapNoProviders;
        final bool declining = state is EmergencyMapAllProvidersDeclined;
        final bool cancelling = state is EmergencyMapCancelling;
        final int foundCount = _allProviders.length;

        double? lat, lng;
        if (state is EmergencyMapProvidersFound) {
          lat = state.latitude;
          lng = state.longitude;
        } else if (state is EmergencyMapNoProviders) {
          lat = state.latitude;
          lng = state.longitude;
        }

        if (lat != null && lng != null && _cachedMarkers.isEmpty) {
          _rebuildMarkers(lat, lng);
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            context.read<EmergencyMapBloc>().add(CancelEmergencyRequest());
            Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.userDashboard, (r) => false);
          },
          child: Scaffold(
            backgroundColor: kScaffoldColor,
            body: Stack(
              children: [
                Positioned.fill(
                  child: lat != null && lng != null
                      ? GoogleMap(
                          initialCameraPosition: CameraPosition(target: LatLng(lat, lng), zoom: 14),
                          style: _silverMapStyle,
                          markers: _cachedMarkers,
                          circles: {
                            Circle(
                              circleId: const CircleId('radius'),
                              center: LatLng(lat, lng),
                              radius: _radiusKm * 1000,
                              fillColor: kPrimaryColor.withValues(alpha: 0.05),
                              strokeColor: kPrimaryColor.withValues(alpha: 0.2),
                              strokeWidth: 1,
                            ),
                          },
                          onMapCreated: (ctrl) {
                            _mapController = ctrl;
                            if (_cachedMarkers.isEmpty && lat != null && lng != null) {
                              _rebuildMarkers(lat, lng);
                            }
                          },
                          myLocationEnabled: false,
                          myLocationButtonEnabled: false,
                          mapToolbarEnabled: false,
                          zoomControlsEnabled: false,
                          compassEnabled: false,
                          padding: EdgeInsets.only(bottom: 320.h),
                        )
                      : _MapPlaceholder(radiusKm: _radiusKm, pulseCtrl: _pulseCtrl, glowAnimation: _glowAnimation, searching: searching),
                ),

                Positioned(
                  right: 20.w,
                  bottom: 340.h,
                  child: _GlassmorphicButton(
                    icon: Icons.my_location_rounded,
                    onTap: () {
                      if (lat != null && lng != null) {
                        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15));
                      }
                    },
                  ),
                ),

                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _GlassmorphicButton(icon: Icons.arrow_back_ios_new_rounded, onTap: _showCancelConfirmation),
                          // Container(
                          //   padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          //   decoration: BoxDecoration(color: kWhiteColor, borderRadius: BorderRadius.circular(12.r)),
                          //   child: Text('Emergency', style: kTextSemiBold(color: kPrimaryColor)),
                          // ),
                          if (_secondsLeft != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  child: _GlassmorphicBadge(
                                    icon: Icons.timer_outlined,
                                    label: formatTime,
                                    iconColor: isUrgent ? Colors.white : kTextPrimaryColor,
                                    textColor: isUrgent ? Colors.white : kTextPrimaryColor,
                                    bgColor: isUrgent ? kErrorColor : Colors.white,
                                    isUrgent: isUrgent,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _EmergencyControlSheet(
                    searching: searching,
                    declining: declining,
                    cancelling: cancelling,
                    foundCount: foundCount,
                    radiusKm: _radiusKm,
                    radiusStepKm: radiusIncreaseStep,
                    secondsLeft: _secondsLeft,
                    totalWaitSeconds: _totalWaitSeconds,
                    timerProgress: timerProgress,
                    formatTime: formatTime,
                    providers: _allProviders,
                    onCancel: _showCancelConfirmation,
                    onExpand: () {
                      if (_isExpanding) return;
                      final newRadius = _radiusKm + radiusIncreaseStep;
                      if (newRadius <= maxSearchRadius) {
                        setState(() {
                          _radiusKm = newRadius;
                          _isExpanding = true;
                          _lastExpandedAt = _secondsLeft ?? 300;
                        });
                        _startSearch();
                        Future.delayed(const Duration(seconds: 5), () {
                          if (mounted) setState(() => _isExpanding = false);
                        });
                      }
                    },
                    onRequestAgain: () {
                      setState(() {
                        _allProviders = [];
                        _cachedMarkers = {};
                      });
                      _startSearch();
                    },
                    maxSearchRadius: maxSearchRadius,
                    isExpanding: _isExpanding,
                    onTopProviderChanged: (index) {
                      if (index < _allProviders.length) {
                        _animateToProvider(_allProviders[index], index);
                      }
                    },
                    secondsElapsed: _lastExpandedAt - (_secondsLeft ?? _lastExpandedAt),
                    noProviderFound: state is EmergencyMapNoProviders,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GlassmorphicButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassmorphicButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white.withValues(alpha: 0.95), Colors.white.withValues(alpha: 0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Icon(icon, size: 18, color: kTextPrimaryColor),
      ),
    );
  }
}

class _GlassmorphicBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color textColor;
  final Color? bgColor;
  final bool isUrgent;

  const _GlassmorphicBadge({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.textColor,
    this.bgColor,
    this.isUrgent = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        gradient: bgColor != null
            ? null
            : LinearGradient(
                colors: [Colors.white.withValues(alpha: 0.95), Colors.white.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: bgColor,
        borderRadius: BorderRadius.circular(25.r),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
        border: isUrgent
            ? Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5)
            : Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 16.sp),
          SizedBox(width: 6.w),
          Text(label, style: kTextSemiBold(color: textColor)),
        ],
      ),
    );
  }
}

class _EmergencyControlSheet extends StatelessWidget {
  final bool searching;
  final bool cancelling;
  final int foundCount;
  final double radiusKm;
  final double radiusStepKm;
  final int? secondsLeft;
  final int totalWaitSeconds;
  final double timerProgress;
  final String formatTime;
  final List<Map<String, dynamic>> providers;
  final VoidCallback onCancel;
  final VoidCallback onExpand;
  final VoidCallback onRequestAgain;
  final bool declining;
  final double maxSearchRadius;
  final bool isExpanding;
  final ValueChanged<int>? onTopProviderChanged;
  final int secondsElapsed;
  final bool noProviderFound;

  const _EmergencyControlSheet({
    required this.searching,
    required this.declining,
    required this.cancelling,
    required this.foundCount,
    required this.radiusKm,
    required this.radiusStepKm,
    required this.secondsLeft,
    required this.totalWaitSeconds,
    required this.timerProgress,
    required this.formatTime,
    required this.providers,
    required this.onCancel,
    required this.onExpand,
    required this.onRequestAgain,
    required this.maxSearchRadius,
    required this.isExpanding,
    required this.secondsElapsed,
    required this.noProviderFound,
    this.onTopProviderChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 40, offset: const Offset(0, -10)),
          BoxShadow(color: kPrimaryColor.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Enhanced drag handle
              Container(
                width: 44.w,
                height: 5.h,
                decoration: BoxDecoration(color: kGreyColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              ),
              SizedBox(height: 24.h),

              // Status Section
              if (declining) ...[
                _AllDeclinedCard(onRequestAgain: onRequestAgain),
              ] else if (searching && providers.isEmpty) ...[
                _SearchingCard(radiusKm: radiusKm, noProviderFound: noProviderFound),
              ] else ...[
                _StatusHeader(
                  foundCount: foundCount,
                  radiusKm: radiusKm,
                  secondsLeft: secondsLeft,
                  totalWaitSeconds: totalWaitSeconds,
                  timerProgress: timerProgress,
                  formatTime: formatTime,
                ),
                if (providers.isNotEmpty) ...[
                  SizedBox(height: 20.h),
                  _StackedProviderCards(providers: providers, onTopProviderChanged: onTopProviderChanged),
                ],
              ],

              SizedBox(height: 24.h),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: _CancelButton(cancelling: cancelling, onCancel: onCancel),
                  ),
                  SizedBox(width: 12.w),
                  _RadiusBadge(stepKm: radiusStepKm, searching: searching, onExpand: onExpand, secondsElapsed: secondsElapsed),
                ],
              ),
              SizedBox(height: 12.h),
              Text(
                'Distance charges may apply',
                style: kTextNormal(color: kTextSecondaryColor.withValues(alpha: 0.6)).copyWith(fontSize: 10.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Enhanced Searching Card
class _SearchingCard extends StatelessWidget {
  final double radiusKm;
  final bool noProviderFound;

  const _SearchingCard({required this.radiusKm, required this.noProviderFound});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryColor.withValues(alpha: 0.05), kPrimaryColor.withValues(alpha: 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: kPrimaryColor.withValues(alpha: 0.15), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [kPrimaryColor, kPrimaryColor.withValues(alpha: 0.7)]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: kPrimaryColor.withValues(alpha: 0.3), blurRadius: 12)],
                ),
                child: Icon(Icons.radar_rounded, color: Colors.white, size: 24.sp),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      noProviderFound ? 'No partner found within ${radiusKm.toInt()} km' : 'Searching nearby partners...',
                      style: kTextBold2(color: noProviderFound ? kErrorColor : kTextPrimaryColor),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      noProviderFound
                          ? 'Please increase search radius to find help.'
                          : 'Scanning within ${radiusKm.toInt()} km for emergency partners',
                      style: kTextNormal0(color: kTextSecondaryColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Hide the scanning loader once no partner was found.
          if (!noProviderFound) ...[
            SizedBox(height: 20.h),
            const _SegmentedUberLoader(),
          ],
        ],
      ),
    );
  }
}

// All Declined Card
class _AllDeclinedCard extends StatelessWidget {
  final VoidCallback onRequestAgain;

  const _AllDeclinedCard({required this.onRequestAgain});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kErrorColor.withValues(alpha: 0.08), kErrorColor.withValues(alpha: 0.03)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(color: kErrorColor.withValues(alpha: 0.2), width: 1.5),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: Icon(Icons.sentiment_dissatisfied_rounded, color: kErrorColor, size: 28.sp),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('No Providers Available', style: kTextBold2(color: kErrorColor)),
                            SizedBox(height: 4.h),
                            Text('All nearby providers declined your request. Please try again.', style: kTextNormal0(color: kTextSecondaryColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onRequestAgain,
                      icon: Icon(Icons.refresh_rounded, size: 20.sp),
                      label: Text('Request Again', style: kTextSemiBold()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Status Header
class _StatusHeader extends StatelessWidget {
  final int foundCount;
  final double radiusKm;
  final int? secondsLeft;
  final int totalWaitSeconds;
  final double timerProgress;
  final String formatTime;

  const _StatusHeader({
    required this.foundCount,
    required this.radiusKm,
    required this.secondsLeft,
    required this.totalWaitSeconds,
    required this.timerProgress,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final isUrgent = secondsLeft != null && secondsLeft! < 60;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 4.w,
                  height: 18.h,
                  decoration: BoxDecoration(color: kPrimaryColor, borderRadius: BorderRadius.circular(2)),
                ),
                SizedBox(width: 10.w),
                Text(
                  'Finding Nearest Help',
                  style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 16.sp),
                ),
              ],
            ),
            if (secondsLeft != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isUrgent ? kErrorColor : kPrimaryColor,
                  borderRadius: BorderRadius.circular(25.r),
                  boxShadow: [
                    BoxShadow(color: (isUrgent ? kErrorColor : kPrimaryColor).withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(isUrgent ? Icons.timer_off_rounded : Icons.timer_outlined, color: Colors.white, size: 16.sp),
                    SizedBox(width: 6.w),
                    Text(
                      formatTime,
                      style: kTextBold(color: Colors.white).copyWith(fontSize: 13.sp),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (secondsLeft != null) ...[
          SizedBox(height: 16.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: LinearProgressIndicator(
              value: timerProgress,
              color: isUrgent ? kErrorColor : kPrimaryColor,
              backgroundColor: (isUrgent ? kErrorColor : kPrimaryColor).withValues(alpha: 0.1),
              minHeight: 8.h,
            ),
          ),
        ],
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: Text(
                'Searching partner in ${radiusKm.toInt()} km radius • $foundCount nearby',
                style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10.r)),
              child: Text(
                'Emergency',
                style: kTextBold(color: kPrimaryColor).copyWith(fontSize: 11.sp),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Enhanced Segmented Loader
class _SegmentedUberLoader extends StatefulWidget {
  const _SegmentedUberLoader();

  @override
  State<_SegmentedUberLoader> createState() => _SegmentedUberLoaderState();
}

class _SegmentedUberLoaderState extends State<_SegmentedUberLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // Static background segments
            Row(
              children: List.generate(
                4,
                (index) => Expanded(
                  child: Container(
                    height: 8.h,
                    margin: EdgeInsets.symmetric(horizontal: 4.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [kPrimaryColor.withValues(alpha: 0.08), kPrimaryColor.withValues(alpha: 0.04)]),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
            ),
            // Moving beam
            Positioned.fill(
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (rect) {
                  final double val = _controller.value;
                  return LinearGradient(
                    colors: [Colors.transparent, kPrimaryColor, Colors.transparent],
                    stops: [val - 0.25, val, val + 0.25],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ).createShader(rect);
                },
                child: Row(
                  children: List.generate(
                    4,
                    (index) => Expanded(
                      child: Container(
                        height: 8.h,
                        margin: EdgeInsets.symmetric(horizontal: 4.w),
                        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Enhanced Stacked Provider Cards
class _StackedProviderCards extends StatefulWidget {
  final List<Map<String, dynamic>> providers;
  final ValueChanged<int>? onTopProviderChanged;
  const _StackedProviderCards({required this.providers, this.onTopProviderChanged});

  @override
  State<_StackedProviderCards> createState() => _StackedProviderCardsState();
}

class _StackedProviderCardsState extends State<_StackedProviderCards> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _topIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _topIndex = (_topIndex + 1) % widget.providers.length;
          });
          widget.onTopProviderChanged?.call(_topIndex);
          _controller.forward(from: 0.0);
        }
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.providers.isEmpty) return const SizedBox.shrink();
    final int count = widget.providers.length;
    if (count == 1) {
      return Center(child: _ProviderCard(provider: widget.providers[0], isStacked: true));
    }

    return SizedBox(
      height: 160.h,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final double val = _controller.value;
          double t = 0.0;
          if (val > 0.6) {
            t = (val - 0.6) / 0.4;
            t = Curves.easeOutCubic.transform(t);
          }

          final int nextIndex = (_topIndex + 1) % count;
          final int afterNextIndex = (_topIndex + 2) % count;

          return Stack(
            alignment: Alignment.center,
            children: [
              // 3. Back Card (Deep stack)
              if (count > 2)
                Transform.translate(
                  offset: Offset(0, 20.h * (1 - t)),
                  child: Transform.scale(
                    scale: 0.82 + (t * 0.08),
                    child: Opacity(
                      opacity: (0.1 + (t * 0.2)).clamp(0.0, 1.0),
                      child: _ProviderCard(provider: widget.providers[afterNextIndex], isStacked: true),
                    ),
                  ),
                ),
              // 2. Middle Card (becomes Front)
              Transform.translate(
                offset: Offset(0, 10.h * (1 - t)),
                child: Transform.scale(
                  scale: 0.90 + (t * 0.10),
                  child: Opacity(
                    opacity: (0.3 + (t * 0.7)).clamp(0.0, 1.0),
                    child: _ProviderCard(provider: widget.providers[nextIndex], isStacked: true),
                  ),
                ),
              ),
              // 1. Front Card (Sliding out)
              Transform.translate(
                offset: Offset(-t * 220.w, -t * 35.h),
                child: Transform.rotate(
                  angle: -t * 0.18,
                  child: Opacity(
                    opacity: (1.0 - (t * 1.6)).clamp(0.0, 1.0),
                    child: _ProviderCard(provider: widget.providers[_topIndex], isStacked: true),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Enhanced Provider Card (Premium Edition)
class _ProviderCard extends StatelessWidget {
  final Map<String, dynamic> provider;
  final bool isStacked;

  const _ProviderCard({required this.provider, this.isStacked = false});

  @override
  Widget build(BuildContext context) {
    final name = provider['provider_name']?.toString() ?? 'Partner';
    final rating = provider['rating']?.toString() ?? '0.0';
    final distance = provider['distance_text']?.toString() ?? 'Calculating...';
    final eta = provider['arrival_text']?.toString() ?? '...';
    final String? imageUrl =
        provider['profile_image_url']?.toString() ??
        provider['provider_detatils']?['user']?['profile_image_url']?.toString() ??
        provider['provider_image']?['provider_detatils']?['user']?['profile_image_url']?.toString();
    final double imageSize = 68.r;

    return Container(
      width: isStacked ? 340.w : 240.w,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(30.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, 15)),
          BoxShadow(color: kPrimaryColor.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, -5)),
        ],
        border: Border.all(color: kBorderColor.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        children: [
          // Premium Avatar with verified badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: EdgeInsets.all(3.r),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kPrimaryColor.withValues(alpha: 0.1), width: 2),
                ),
                child: AppCachedImage(imageUrl: imageUrl, width: imageSize, height: imageSize, fit: BoxFit.cover, isOval: true),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                    border: Border.all(color: kSuccessColor.withValues(alpha: 0.2), width: 1.5),
                  ),
                  child: Icon(Icons.verified_rounded, color: kSuccessColor, size: 14.sp),
                ),
              ),
            ],
          ),
          SizedBox(width: 18.w),
          // Provider Info
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: kTextBold2(color: kTextPrimaryColor).copyWith(fontSize: 16.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 10.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if ((double.tryParse(rating) ?? 0) > 0) ...[
                      _CompactBadge(
                        icon: Icons.star_rounded,
                        label: rating,
                        color: const Color(0xFFFFA000),
                        backgroundColor: const Color(0xFFFFF8E1),
                      ),
                      SizedBox(width: 8.w),
                    ],
                    _CompactBadge(
                      icon: Icons.near_me_rounded,
                      label: distance,
                      color: kTextSecondaryColor,
                      backgroundColor: kGreyColor.withValues(alpha: 0.1),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: kTextSecondaryColor, size: 14.sp),
                    SizedBox(width: 4.w),
                    Text(
                      "Nearby •",
                      style: kTextSemiBold(color: kTextSecondaryColor).copyWith(fontSize: 14.sp),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      eta,
                      style: kTextSemiBold(color: kTextSecondaryColor).copyWith(fontSize: 14.sp),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'away',
                      style: kTextSemiBold(color: kTextSecondaryColor).copyWith(fontSize: 14.sp),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? backgroundColor;

  const _CompactBadge({required this.icon, required this.label, required this.color, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(color: backgroundColor ?? color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            label,
            style: kTextSemiBold(color: color).copyWith(fontSize: 11.sp),
          ),
        ],
      ),
    );
  }
}

// Enhanced Cancel Button
class _CancelButton extends StatelessWidget {
  final bool cancelling;
  final VoidCallback onCancel;

  const _CancelButton({required this.cancelling, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: cancelling ? null : onCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54.h,
        decoration: BoxDecoration(
          color: kErrorColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: kErrorColor.withValues(alpha: 0.15), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (cancelling)
              SizedBox(
                width: 18.sp,
                height: 18.sp,
                child: const CircularProgressIndicator(color: kErrorColor, strokeWidth: 2),
              )
            else
              Icon(Icons.close_rounded, size: 20.sp, color: kErrorColor),
            SizedBox(width: 10.w),
            Text(
              cancelling ? 'Cancelling...' : 'Cancel',
              style: kTextBold(color: kErrorColor).copyWith(fontSize: 15.sp),
            ),
          ],
        ),
      ),
    );
  }
}

// Enhanced Map Placeholder
class _MapPlaceholder extends StatelessWidget {
  final double radiusKm;
  final AnimationController pulseCtrl;
  final Animation<double> glowAnimation;
  final bool searching;

  const _MapPlaceholder({required this.radiusKm, required this.pulseCtrl, required this.glowAnimation, required this.searching});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFFE8EEF2), const Color(0xFFDCE3E8)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: AnimatedBuilder(
        animation: pulseCtrl,
        builder: (_, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(size: Size.infinite, painter: _GridPainter()),
              // Animated search rings
              ...List.generate(3, (i) {
                final scale = (pulseCtrl.value + i * 0.33) % 1.0;
                return Opacity(
                  opacity: searching ? (1 - scale) * 0.5 : 0,
                  child: Transform.scale(
                    scale: 0.2 + scale * 0.8,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.7,
                      height: MediaQuery.of(context).size.width * 0.7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: kErrorColor.withValues(alpha: 0.4), width: 2),
                      ),
                    ),
                  ),
                );
              }),
              // Animated glow effect
              AnimatedBuilder(
                animation: glowAnimation,
                builder: (context, child) {
                  return Container(
                    width: MediaQuery.of(context).size.width * 0.3,
                    height: MediaQuery.of(context).size.width * 0.3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          kErrorColor.withValues(alpha: glowAnimation.value),
                          Colors.transparent,
                        ],
                        stops: const [0.3, 1.0],
                      ),
                    ),
                  );
                },
              ),
              // User pin
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [kPrimaryColor, kPrimaryColor.withValues(alpha: 0.8)]),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12)],
                    ),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
                  ),
                  Container(width: 2, height: 10, color: kPrimaryColor),
                  Container(
                    width: 8,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [kPrimaryColor.withValues(alpha: 0.4), kPrimaryColor.withValues(alpha: 0.2)]),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueGrey.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _RadiusBadge extends StatelessWidget {
  final double stepKm;
  final bool searching;
  final VoidCallback onExpand;
  final int secondsElapsed;

  const _RadiusBadge({required this.stepKm, required this.searching, required this.onExpand, this.secondsElapsed = 0});

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = secondsElapsed >= 30;
    final double progress = (secondsElapsed / 30).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: isEnabled ? onExpand : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 54.h,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isEnabled ? kWhiteColor : kGreyColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: isEnabled ? kPrimaryColor.withValues(alpha: 0.3) : kGreyColor.withValues(alpha: 0.1), width: 1.5),
          boxShadow: isEnabled ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))] : [],
        ),
        child: Stack(
          children: [
            if (searching && secondsElapsed < 30)
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.08))),
                ),
              ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: isEnabled ? kPrimaryColor.withValues(alpha: 0.1) : kGreyColor.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add_rounded, size: 16.sp, color: isEnabled ? kPrimaryColor : kTextHintColor),
                  ),
                  SizedBox(width: 12.w),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INCREASE',
                        style: kTextBold(color: isEnabled ? kPrimaryColor : kTextHintColor).copyWith(fontSize: 9.sp, letterSpacing: 1.2),
                      ),
                      Text(
                        '${stepKm.toInt()} km',
                        style: kTextBold(color: isEnabled ? kTextPrimaryColor : kTextHintColor).copyWith(fontSize: 16.sp),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
