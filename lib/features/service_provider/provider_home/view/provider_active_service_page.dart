import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/launch_url_service.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_edge_insets.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/screen_dimensions.dart';
import '../../../../di/locator.dart';
import '../../../../shared/widgets/buttons/custom_button.dart' as custom_btn;
import '../../../../shared/widgets/common/app_cached_image.dart';
import '../../provider_requests/data/repositories/provider_request_repository.dart';
import '../bloc/provider_tracking_bloc/provider_tracking_bloc.dart';
import '../data/models/service_request.dart';

/// Shown to the PROVIDER after they accept an emergency/service request.
///
/// Professional Uber/Ola-style active service page with:
///   - Live Google Maps with route polyline
///   - Navigate button to open Google Maps directions
///   - Patient info card with enriched data from API
///   - Status stepper to update service progress
///   - Call / Navigate quick actions
class ProviderActiveServicePage extends StatefulWidget {
  final ServiceRequest request;

  const ProviderActiveServicePage({super.key, required this.request});

  @override
  State<ProviderActiveServicePage> createState() => _ProviderActiveServicePageState();
}

class _ProviderActiveServicePageState extends State<ProviderActiveServicePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  GoogleMapController? _mapController;
  late AnimationController _pulseCtrl;

  // ── Enriched data (filled from request, optionally from API) ──
  String _patientName = '';
  String _patientPhone = '';
  String _serviceType = '';
  String _address = '';
  String _distance = '';
  double _payment = 0;
  double _patientLat = 0;
  double _patientLng = 0;
  String? _patientImageUrl;

  // ── Route ──
  Set<Polyline> _polylines = {};
  bool _hasFitBounds = false;
  List<LatLng> _routePoints = [];
  String _mapInstruction = 'Calculating route...';
  String _instructionIcon = 'navigation';
  String _mapEta = '';
  String _mapDistance = '';
  String _nextStepDistance = '';
  bool _isFetchingRoute = false;
  bool _isFollowingUser = true;
  bool _isNavigationEnabled = false;
  Timer? _recenterTimer;
  LatLng? _currentProviderPos;
  double _currentHeading = 0;
  LatLng? _lastFetchedPos;
  bool _isWrongWay = false;

  // ── Custom Markers ──
  BitmapDescriptor? _patientIcon;
  BitmapDescriptor? _providerIcon;

  EdgeInsets _mapPadding = EdgeInsets.zero;
  String? _navigationMapStyle;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);

    _initFromRequest();
    _startTracking();
    _fetchDetailsIfNeeded();
    _loadCustomMarkers();
    WidgetsBinding.instance.addObserver(this);
  }

  // ─────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────
  void _initFromRequest() {
    _patientName = widget.request.patientName;
    _patientPhone = widget.request.patientPhone ?? '';
    _serviceType = widget.request.serviceType;
    _address = widget.request.address;
    _distance = widget.request.distance;
    _payment = widget.request.payment;
    _patientLat = widget.request.latitude;
    _patientLng = widget.request.longitude;
  }

  bool get _hasEnoughData =>
      _patientName.isNotEmpty && _address.isNotEmpty && _patientLat != 0 && _patientLng != 0;

  void _startTracking() {
    final storage = locator<LocalStorageService>();
    final providerId = storage.serviceProvideUserId ?? 0;
    final providerName = storage.username ?? 'Partner';

    context.read<ProviderTrackingBloc>().add(
      StartProviderTracking(
        bookingId: widget.request.bookingId,
        providerId: providerId,
        providerName: providerName,
      ),
    );
  }

  Future<void> _fetchDetailsIfNeeded() async {
    if (_hasEnoughData) return;

    try {
      final repo = locator<ProviderRequestRepository>();
      final requestId = widget.request.bookingId > 0
          ? widget.request.bookingId
          : int.tryParse(widget.request.id) ?? 0;

      if (requestId <= 0) return;

      final d = await repo.getRequestDetails(requestId: requestId);
      if (d != null && mounted) {
        setState(() {
          if (d.customerName.isNotEmpty) _patientName = d.customerName;
          // _patientPhone = d.customerPhone ?? '';
          _patientPhone = AppConstants.partnerCustomerPhone;
          if (d.serviceCategoryName.isNotEmpty) _serviceType = d.serviceCategoryName;
          if (d.serviceLatitude != 0) _patientLat = d.serviceLatitude;
          if (d.serviceLongitude != 0) _patientLng = d.serviceLongitude;
          if (d.distanceKm > 0) _distance = '${d.distanceKm.toStringAsFixed(1)} km';
          _payment = d.totalAmount ?? d.basePrice ?? _payment;
          _patientImageUrl = d.customerProfileImageUrl;
          if (d.address.isNotEmpty) _address = d.address;
        });
        _loadCustomMarkers();
      }
    } catch (e) {
      debugPrint('Error fetching request details: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // DISPOSE
  // ─────────────────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;

    if (state == AppLifecycleState.paused) {
      context.read<ProviderTrackingBloc>().add(PauseProviderTracking());
    } else if (state == AppLifecycleState.resumed) {
      context.read<ProviderTrackingBloc>().add(ResumeProviderTracking());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseCtrl.dispose();
    _mapController?.dispose();
    _mapController = null;
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────────────────────

  Future<void> _callPatient() async {
    if (_patientPhone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Patient phone number not available'),
          backgroundColor: kWarningColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.m),
        ),
      );
      return;
    }
    final uri = Uri.parse('tel:$_patientPhone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _loadMapStyle() {
    _navigationMapStyle = '''
[
  {
    "featureType": "poi",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "road",
    "elementType": "labels.icon",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.fill",
    "stylers": [{"color": "#fcd34d"}]
  },
  {
    "featureType": "transit",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "water",
    "stylers": [{"color": "#0284c7"}]
  }
]
''';
  }

  // ─────────────────────────────────────────────────────────────
  // DIRECTIONS API
  // ─────────────────────────────────────────────────────────────

  Future<void> _fetchDirections(LatLng origin, LatLng destination) async {
    if (_isFetchingRoute) return;
    _isFetchingRoute = true;

    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY_ANDROID'] ?? dotenv.env['GOOGLE_MAPS_API_KEY_IOS'] ?? '';
      if (apiKey.isEmpty) return;

      final url =
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&key=$apiKey';

      final response = await Dio().get(url);

      if (response.data['status'] == 'OK') {
        final route = response.data['routes'][0];
        final leg = route['legs'][0];
        final overviewPolyline = route['overview_polyline']['points'];

        if (leg['steps'] != null && (leg['steps'] as List).isNotEmpty) {
          final steps = leg['steps'] as List;
          var activeStep = steps[0];

          // Look ahead: If first step is a generic orientation (e.g., "Head north..."), show the second step (the turn)
          if (steps.length > 1) {
            final firstInstr = _stripHtml(activeStep['html_instructions']).toLowerCase();
            if (firstInstr.startsWith('head ') || firstInstr.startsWith('proceed ')) {
              activeStep = steps[1];
            }
          }

          final rawInstruction = _stripHtml(activeStep['html_instructions']);
          final stepDistance = activeStep['distance']['text'] ?? '';
          final maneuver = _extractManeuver(activeStep['maneuver'] ?? '', rawInstruction);

          debugPrint('📍 NAV STEP: $rawInstruction [Maneuver: $maneuver]');

          setState(() {
            _routePoints = _decodePolyline(overviewPolyline);
            _mapEta = leg['duration']['text'];
            _mapDistance = leg['distance']['text'];
            _mapInstruction = rawInstruction;
            _instructionIcon = maneuver;
            _nextStepDistance = stepDistance;
            _rebuildPolylines();
          });
        }

        if (!_hasFitBounds && _mapController != null) {
          _hasFitBounds = true;
          _fitMapBounds(origin, destination);
        }
      } else {
        debugPrint(
          '⛔ DIRECTIONS API STATUS NOT OK: ${response.data['status']} - ${response.data['error_message'] ?? 'Check API key or billing.'}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching directions: $e');
    } finally {
      _isFetchingRoute = false;
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polyline;
  }

  String _stripHtml(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '').trim();
  }

  String _extractManeuver(String maneuver, String instruction) {
    if (maneuver.isNotEmpty) return maneuver;
    final lower = instruction.toLowerCase();
    if (lower.contains('turn left')) return 'turn-left';
    if (lower.contains('turn right')) return 'turn-right';
    if (lower.contains('u-turn') || lower.contains('u turn') || lower.contains('uturn')) return 'uturn-left';
    if (lower.contains('keep left')) return 'keep-left';
    if (lower.contains('keep right')) return 'keep-right';
    if (lower.contains('merge')) return 'merge';
    if (lower.contains('exit')) return 'exit-right';
    if (lower.contains('roundabout')) return 'roundabout-right';
    return 'navigation';
  }

  // ─────────────────────────────────────────────────────────────
  // WRONG WAY DETECTION MATH
  // ─────────────────────────────────────────────────────────────
  bool _detectWrongWay(LatLng pos, double heading) {
    // 0. Suppress if the current instruction IS a U-turn (planned)
    if (_instructionIcon.contains('uturn')) return false;

    double minDistance = double.infinity;
    double segmentHeading = 0;

    // We only check segments near the user to avoid checking the whole route
    for (int i = 0; i < math.min(_routePoints.length - 1, 15); i++) {
      final A = _routePoints[i];
      final B = _routePoints[i + 1];

      final dist = _distanceToSegment(pos, A, B);
      if (dist < minDistance) {
        minDistance = dist;
        segmentHeading = _calculateHeading(A, B);
      }
    }

    // 1. Off Route check (distance > 55 meters)
    if (minDistance > 55) return true;

    // 2. Wrong Direction check
    // If we are relatively on the route, check if heading is opposite
    if (minDistance < 30) {
      double diff = (heading - segmentHeading).abs();
      if (diff > 180) diff = 360 - diff;
      if (diff > 135) return true; // Opposite direction
    }

    return false;
  }

  double _distanceToSegment(LatLng p, LatLng a, LatLng b) {
    double latMid = (a.latitude + b.latitude) / 2 * math.pi / 180;
    double mLat = 111319.9;
    double mLon = 111319.9 * math.cos(latMid);

    double bx = (b.longitude - a.longitude) * mLon;
    double by = (b.latitude - a.latitude) * mLat;
    double px = (p.longitude - a.longitude) * mLon;
    double py = (p.latitude - a.latitude) * mLat;

    double l2 = bx * bx + by * by;
    if (l2 == 0) return math.sqrt(px * px + py * py);
    double t = (px * bx + py * by) / l2;
    t = math.max(0, math.min(1, t));
    double dx = px - (t * bx);
    double dy = py - (t * by);
    return math.sqrt(dx * dx + dy * dy);
  }

  double _calculateHeading(LatLng a, LatLng b) {
    double latMid = (a.latitude + b.latitude) / 2 * math.pi / 180;
    double mLon = math.cos(latMid);
    double dy = b.latitude - a.latitude;
    double dx = (b.longitude - a.longitude) * mLon;
    double angle = math.atan2(dx, dy) * 180 / math.pi;
    return (angle + 360) % 360;
  }

  void _rebuildPolylines() {
    if (_routePoints.isEmpty) return;
    final color = _isWrongWay ? kErrorColor : kPrimaryColor;

    _polylines = {
      // Shadow/Glow effect
      Polyline(
        polylineId: const PolylineId('route_glow'),
        points: _routePoints,
        color: color.withValues(alpha: 0.2),
        width: 12,
        jointType: JointType.round,
      ),
      // Primary Route
      Polyline(
        polylineId: const PolylineId('route'),
        points: _routePoints,
        color: color,
        width: 6,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  // ─────────────────────────────────────────────────────────────
  // ROUTE / MAP HELPERS
  // ─────────────────────────────────────────────────────────────
  void _updateRoutePolyline(LatLng providerPos, {double heading = 0}) {
    _currentProviderPos = providerPos;
    _currentHeading = heading;

    // Detect Wrong Way / Off Route
    final wrongWay = _detectWrongWay(providerPos, heading);
    if (wrongWay != _isWrongWay) {
      _isWrongWay = wrongWay;
      if (_isWrongWay) HapticFeedback.vibrate();
      _rebuildPolylines();
    }

    // 1. Follow camera logic — ALWAYS execute if follow is on
    if (_isFollowingUser && _mapController != null) {
      _animateMapToProvider();
    }

    // 2. Fetch Directions (Throttled)
    if (_patientLat != 0 && _patientLng != 0) {
      bool needsNewDirections = false;
      if (_lastFetchedPos == null) {
        needsNewDirections = true;
      } else {
        final dx = (providerPos.latitude - _lastFetchedPos!.latitude);
        final dy = (providerPos.longitude - _lastFetchedPos!.longitude);
        final distApprox = math.sqrt(dx * dx + dy * dy) * 111000;
        if (distApprox >= 30) {
          needsNewDirections = true;
        }
      }

      if (needsNewDirections) {
        _lastFetchedPos = providerPos;
        _fetchDirections(providerPos, LatLng(_patientLat, _patientLng));
      }
    }

    // 3. UI Adjustments
    if (_isNavigationEnabled) {
      _mapPadding = EdgeInsets.only(top: 160.h, bottom: 80.h);
    } else {
      _mapPadding = EdgeInsets.zero;
    }

    // Ensure marker/padding updates are reflected
    if (mounted) setState(() {});
  }

  void _animateMapToProvider() {
    if (_mapController == null || _currentProviderPos == null) return;

    if (_isNavigationEnabled) {
      // Perspective Navigation: Place marker in lower 3/5 of screen like Google Maps
      const zoom = 18.8;
      // Calculate a latitude offset based on zoom level to position marker down
      final latOffset = 0.00030 * (math.pow(2, 18.0 - zoom));

      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              _currentProviderPos!.latitude + (math.cos(_currentHeading * math.pi / 180) * latOffset),
              _currentProviderPos!.longitude + (math.sin(_currentHeading * math.pi / 180) * latOffset),
            ),
            zoom: zoom,
            tilt: 65,
            bearing: _currentHeading,
          ),
        ),
      );
    } else {
      _mapController!.animateCamera(CameraUpdate.newLatLng(_currentProviderPos!));
    }
  }

  void _handleRecenter() {
    if (!mounted) return;
    setState(() {
      _isFollowingUser = true;
      _recenterTimer?.cancel();
    });
    _animateMapToProvider();
  }

  void _startNavigation() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isFollowingUser = true;
      _isNavigationEnabled = true;
    });

    if (_currentProviderPos != null) {
      _mapPadding = EdgeInsets.only(top: 180.h, bottom: 80.h);
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentProviderPos!, zoom: 18.8, tilt: 65, bearing: _currentHeading),
        ),
      );
    }
  }

  void _fitMapBounds(LatLng a, LatLng b) {
    if (_mapController == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(math.min(a.latitude, b.latitude), math.min(a.longitude, b.longitude)),
      northeast: LatLng(math.max(a.latitude, b.latitude), math.max(a.longitude, b.longitude)),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 140)); // More padding

    // Nudge camera up so route stays above bottom sheet
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (!mounted || _mapController == null) return;
      try {
        final region = await _mapController!.getVisibleRegion();
        final cLat = (region.northeast.latitude + region.southwest.latitude) / 2;
        final cLng = (region.northeast.longitude + region.southwest.longitude) / 2;
        final latSpan = (region.northeast.latitude - region.southwest.latitude).abs();
        if (mounted) {
          _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(cLat - latSpan * 0.20, cLng)));
        }
      } catch (_) {}
    });
  }

  // ─────────────────────────────────────────────────────────────
  // EXIT DIALOG
  // ─────────────────────────────────────────────────────────────
  Future<void> _loadCustomMarkers() async {
    // 1. Patient Marker
    final pIcon = await _createCircularMarker(
      _patientImageUrl,
      _getInitials(_patientName),
      widget.request.isEmergency ? kErrorColor : kPrimaryColor,
    );
    if (mounted) setState(() => _patientIcon = pIcon);

    // 2. Provider Marker
    final storage = locator<LocalStorageService>();
    final profile = await storage.getUserProfile();
    final providerImg = profile?['profile_image_url'] ?? profile?['profile_photo_path'];
    final providerName = storage.username ?? 'You';

    final meIcon = await _createCircularMarker(providerImg, _getInitials(providerName), kPrimaryColor);
    if (mounted) setState(() => _providerIcon = meIcon);
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '??';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Future<BitmapDescriptor> _createCircularMarker(String? url, String initials, Color color) async {
    const double size = 120.0;
    const double border = 10.0;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint()..isAntiAlias = true;

    // Draw circular border/background
    paint.color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);

    paint.color = color;
    canvas.drawCircle(const Offset(size / 2, size / 2), (size / 2) - (border / 2), paint);

    // Try to load image
    ui.Image? img;
    if (url != null && url.isNotEmpty) {
      try {
        final response = await Dio().get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
        final Uint8List bytes = Uint8List.fromList(response.data!);
        final Completer<ui.Image> completer = Completer();
        ui.decodeImageFromList(bytes, (ui.Image result) => completer.complete(result));
        img = await completer.future;
      } catch (e) {
        debugPrint('Error loading marker image: $e');
      }
    }

    if (img != null) {
      // Draw clipped image
      final Path path = Path()..addOval(Rect.fromLTWH(border, border, size - border * 2, size - border * 2));
      canvas.clipPath(path);

      final double scale = (size - border * 2) / (img.width < img.height ? img.width : img.height);
      final double dx = (size - img.width * scale) / 2;
      final double dy = (size - img.height * scale) / 2;

      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(dx, dy, img.width * scale, img.height * scale),
        paint,
      );
    } else {
      // Draw Initials
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: initials,
          style: TextStyle(color: Colors.white, fontSize: size * 0.4, fontWeight: FontWeight.bold),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
    }

    final ui.Image finalImg = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await finalImg.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  void _confirmExit(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: AppPadding.all(24),
          decoration: BoxDecoration(
            color: kWhiteColor,
            borderRadius: AppRadius.xl,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(Icons.exit_to_app_rounded, color: kErrorColor, size: 32.sp),
              ),
              AppSpacing.lVertical,

              // Title
              Text(
                'Leave Current Service?',
                textAlign: TextAlign.center,
                style: kTextBold().copyWith(fontSize: 20.sp),
              ),
              AppSpacing.mVertical,

              // Content
              Text(
                'By leaving, GPS tracking will immediately stop. The patient will no longer be able to track your arrival.',
                textAlign: TextAlign.center,
                style: kTextNormal(color: kTextSecondaryColor).copyWith(height: 1.5),
              ),
              AppSpacing.xlVertical,

              // Actions
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        height: 52.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: kScaffoldColor,
                          borderRadius: AppRadius.l,
                          border: Border.all(color: kBorderColor),
                        ),
                        child: Text('Keep Tracking', style: kTextSemiBold(color: kTextPrimaryColor)),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        ctx.read<ProviderTrackingBloc>().add(StopProviderTracking());
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        height: 52.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: kErrorColor,
                          borderRadius: AppRadius.l,
                          boxShadow: [
                            BoxShadow(
                              color: kErrorColor.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text('Stop', style: kTextBold().copyWith(color: kWhiteColor)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProviderTrackingBloc, ProviderTrackingState>(
      listener: (context, state) {
        if (state is ProviderTrackingCompleted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/provider_dashboard', (r) => false);
        }
        if (state is ProviderTrackingError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: kErrorColor));
        }
        if (state is ProviderTrackingActive) {
          _updateRoutePolyline(LatLng(state.lat, state.lng), heading: state.heading);
        }
      },
      builder: (context, state) {
        final active = state is ProviderTrackingActive ? state : null;
        final statusStr = active?.status ?? 'on_the_way';

        return Scaffold(
          backgroundColor: kScaffoldColor,
          body: Column(
            children: [
              // ═══════════════ MAP (expandable) ═══════════════
              Expanded(
                child: RepaintBoundary(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Listener(
                          onPointerDown: (_) {
                            if (_isFollowingUser) {
                              setState(() => _isFollowingUser = false);
                              // Start auto-recenter timer: 6 seconds of inactivity
                              _recenterTimer?.cancel();
                              _recenterTimer = Timer(const Duration(seconds: 6), () {
                                if (mounted && _isNavigationEnabled) {
                                  _handleRecenter();
                                }
                              });
                            }
                          },
                          child: _buildMap(active),
                        ),
                      ),

                      // Top bar overlay
                      _buildTopBar(context, active, statusStr),

                      // Directions Overlay (Google Maps Style)
                      if (active != null) _buildDirectionsOverlay(),

                      // ═══════════════ NAVIGATION CONTROLS ═══════════════
                      // 1. Recenter Button (Google Maps Style)
                      if (!_isFollowingUser)
                        _isNavigationEnabled
                            ? Positioned(
                                bottom: 110.h,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: GestureDetector(
                                    onTap: _handleRecenter,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                                      decoration: BoxDecoration(
                                        color: kPrimaryColor,
                                        borderRadius: BorderRadius.circular(100.r),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.navigation_rounded, color: Colors.white, size: 18.sp),
                                          SizedBox(width: 8.w),
                                          Text(
                                            'RECENTER',
                                            style: kTextBold().copyWith(
                                              color: Colors.white,
                                              fontSize: 14.sp,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Positioned(
                                right: 16.w,
                                bottom: 260.h,
                                child: FloatingActionButton(
                                  onPressed: _handleRecenter,
                                  backgroundColor: Colors.white,
                                  elevation: 6,
                                  mini: true,
                                  heroTag: 'recenter_btn',
                                  child: Icon(Icons.my_location, color: kPrimaryColor, size: 20.sp),
                                ),
                              ),

                      // 2. Navigation Toggle (Visible only when not in nav mode)
                      if (!_isNavigationEnabled)
                        Positioned(
                          right: 16.w,
                          bottom: 315.h,
                          child: FloatingActionButton(
                            onPressed: _startNavigation,
                            backgroundColor: Colors.white,
                            elevation: 6,
                            mini: true,
                            heroTag: 'nav_btn',
                            child: Icon(Icons.navigation_rounded, color: kPrimaryColor, size: 20.sp),
                          ),
                        ),

                      // ETA chip overlay (if directions not yet loaded but basic distance is)
                      if (_mapEta.isEmpty && _distance.isNotEmpty && statusStr == 'on_the_way')
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 64.h,
                          left: 0,
                          right: 0,
                          child: Center(child: _buildETAChip()),
                        ),
                    ],
                  ),
                ),
              ),

              RepaintBoundary(child: _isNavigationEnabled ? _buildDriveDashboard() : _buildBottomSheet(statusStr)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDriveDashboard() {
    // Calculate arrival time: Now + _mapEta
    String arrivalTime = '---';
    try {
      if (_mapEta.isNotEmpty) {
        // Simple heuristic: "15 mins" -> extract 15
        final mins = int.tryParse(_mapEta.split(' ')[0]) ?? 0;
        final arrival = DateTime.now().add(Duration(minutes: mins));
        arrivalTime =
            "${arrival.hour % 12 == 0 ? 12 : arrival.hour % 12}:${arrival.minute.toString().padLeft(2, '0')} ${arrival.hour >= 12 ? 'PM' : 'AM'}";
      }
    } catch (_) {}

    return Container(
      padding: EdgeInsets.only(
        top: 24.h,
        left: 24.w,
        right: 24.w,
        bottom: MediaQuery.of(context).padding.bottom + 20.h,
      ),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: AppRadius.topOnly(32.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, -10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _mapEta.toUpperCase(),
                    style: kTextBold().copyWith(fontSize: 28.sp, color: kPrimaryColor, letterSpacing: -0.5),
                  ),
                  Row(
                    children: [
                      Text(_mapDistance, style: kTextSemiBold(color: kGreyColor7)),
                      Text(' • Arrival $arrivalTime', style: kTextNormal(color: kGreyColor7)),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              custom_btn.CustomButton(
                onPressed: () => setState(() => _isNavigationEnabled = false),
                title: 'EXIT',
                width: 80.w,
                height: 48.h,
                backgroundColor: kErrorColor.withValues(alpha: 0.1),
                textColor: kErrorColor,
                borderRadius: BorderRadius.circular(16.r),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MAP
  // ─────────────────────────────────────────────────────────────
  Widget _buildMap(ProviderTrackingActive? active) {
    final patientPos = LatLng(_patientLat != 0 ? _patientLat : 26.9124, _patientLng != 0 ? _patientLng : 75.7873);

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: patientPos, zoom: 15),
      style: _navigationMapStyle,
      markers: {
        if (_patientLat != 0)
          Marker(
            markerId: const MarkerId('patient'),
            position: patientPos,
            icon: _patientIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: _patientName, snippet: _address),
            anchor: const Offset(0.5, 0.5),
          ),
        if (active != null)
          Marker(
            markerId: const MarkerId('me'),
            position: LatLng(active.lat, active.lng),
            icon: _providerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: const InfoWindow(title: 'You'),
            zIndexInt: 5,
            anchor: const Offset(0.5, 0.5),
            flat: true,
            rotation: _isNavigationEnabled ? 0 : active.heading,
          ),
      },
      circles: {
        if (active != null)
          Circle(
            circleId: const CircleId('pulse'),
            center: LatLng(active.lat, active.lng),
            radius: 15,
            fillColor: kPrimaryColor.withValues(alpha: 0.15),
            strokeColor: kPrimaryColor.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
      },
      polylines: _polylines,
      myLocationEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      padding: _mapPadding,
      onMapCreated: (c) {
        _mapController = c;
        if (active != null) _updateRoutePolyline(LatLng(active.lat, active.lng));
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TOP BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext ctx, ProviderTrackingActive? active, String status) {
    return SafeArea(
      child: Padding(
        padding: AppPadding.only(left: 16, right: 16, top: 8),
        child: Row(
          children: [
            _CircleIconBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: () => _confirmExit(ctx)),
            AppSpacing.mHorizontal,
            Expanded(
              child: _LiveStatusBadge(pulseCtrl: _pulseCtrl, isActive: active != null, status: status),
            ),
            AppSpacing.mHorizontal,

            _CircleIconBtn(
              icon: Icons.navigation_rounded,
              color: kPrimaryColor,
              onTap: () => LaunchUrlService.launchGoogleMaps(_patientLat, _patientLng),
              colorIcon: kWhiteColor,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ETA CHIP
  // ─────────────────────────────────────────────────────────────
  Widget _buildETAChip() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: AppRadius.xxl,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_car_rounded, size: 18.sp, color: kPrimaryColor),
          SizedBox(width: 8.w),
          Text(_distance, style: kTextBold().copyWith(color: kPrimaryColor)),
          Text(' away', style: kTextNormal().copyWith(color: kPrimaryColor)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BOTTOM SHEET
  // ─────────────────────────────────────────────────────────────
  Widget _buildBottomSheet(String status) {
    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: AppRadius.topOnly(32.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, -10)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Static Handle Decoration
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 20.h),
                  decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(100)),
                ),
              ),

              // Rich Patient Info Row
              Row(
                children: [
                  _PulseAvatar(
                    url: _patientImageUrl,
                    pulseCtrl: _pulseCtrl,
                    isEmergency: widget.request.isEmergency,
                    initials: _getInitials(_patientName),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_patientName, style: kTextBold().copyWith(fontSize: 18.sp)),
                        SizedBox(height: 2.h),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _serviceType,
                              style: kTextSemiBold(color: kPrimaryColor).copyWith(fontSize: 13.sp),
                            ),
                            if (_distance.isNotEmpty) ...[
                              Text(
                                _distance,
                                style: kTextSemiBold(color: kBlackColor).copyWith(fontSize: 13.sp),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  _CircleIconBtn(
                    icon: Icons.phone_rounded,
                    color: kSuccessColor,
                    colorIcon: kWhiteColor,
                    onTap: _callPatient,
                  ),
                ],
              ),

              SizedBox(height: 20.h),

              // Address Section
              Container(
                padding: AppPadding.all(12),
                decoration: BoxDecoration(
                  color: kScaffoldColor,
                  borderRadius: AppRadius.m,
                  border: Border.all(color: kBorderColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on_rounded, size: 20.sp, color: kPrimaryColor),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FULL ADDRESS',
                            style: kTextBold().copyWith(fontSize: 10.sp, color: kPrimaryColor, letterSpacing: 1.2),
                          ),
                          SizedBox(height: 4.h),
                          Text(_address, style: kTextNormal().copyWith(fontSize: 14.sp, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              AppSpacing.lVertical,
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DIRECTIONS OVERLAY (Google Maps Style)
  // ─────────────────────────────────────────────────────────────
  Widget _buildDirectionsOverlay() {
    if (!_isNavigationEnabled) return const SizedBox.shrink();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12.h,
      left: 12.w,
      right: 12.w,
      child: Container(
        padding: AppPadding.all(16),
        decoration: BoxDecoration(
          color: _isWrongWay ? kErrorColor : const Color(0xFF1E8E3E), // Red if wrong way, else Google Green
          borderRadius: AppRadius.xl,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52.w,
              height: 52.w,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: Icon(
                _isWrongWay ? Icons.u_turn_left_rounded : _getNavIcon(_instructionIcon),
                color: Colors.white,
                size: 32.sp,
              ),
            ),
            AppSpacing.mHorizontal,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isWrongWay ? 'WRONG WAY' : _nextStepDistance.toUpperCase(),
                    style: kTextBold().copyWith(
                      color: _isWrongWay ? Colors.white : Colors.white70,
                      fontSize: 12.sp,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    _isWrongWay ? 'MAKE A U-TURN' : _mapInstruction,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: kTextBold().copyWith(color: Colors.white, fontSize: 18.sp, height: 1.1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getNavIcon(String maneuver) {
    switch (maneuver) {
      case 'turn-left':
        return Icons.turn_left_rounded;
      case 'turn-right':
        return Icons.turn_right_rounded;
      case 'uturn-left':
        return Icons.u_turn_left_rounded;
      case 'uturn-right':
        return Icons.u_turn_right_rounded;
      case 'keep-left':
        return Icons.turn_slight_left_rounded;
      case 'keep-right':
        return Icons.turn_slight_right_rounded;
      case 'roundabout-left':
      case 'roundabout-right':
        return Icons.roundabout_right_rounded;
      default:
        return Icons.navigation_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// COMPONENTS
// ─────────────────────────────────────────────────────────────

class _LiveStatusBadge extends StatelessWidget {
  final AnimationController pulseCtrl;
  final bool isActive;
  final String status;

  const _LiveStatusBadge({required this.pulseCtrl, required this.isActive, required this.status});

  @override
  Widget build(BuildContext context) {
    final statusText = status.replaceAll('_', ' ').toUpperCase();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(color: kWhiteColor, borderRadius: AppRadius.xxl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8.w,
            height: 8.w,
            decoration: const BoxDecoration(color: kPrimaryColor, shape: BoxShape.circle),
          ),
          SizedBox(width: 8.w),
          Flexible(
            child: Text(
              statusText,
              style: kTextBold().copyWith(color: kPrimaryColor, fontSize: 11.sp, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final Color? colorIcon;

  const _CircleIconBtn({required this.icon, required this.onTap, this.color, this.colorIcon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48.w,
        height: 48.w,
        decoration: BoxDecoration(
          color: color ?? kWhiteColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Icon(icon, color: colorIcon ?? kPrimaryColor, size: 22.sp),
      ),
    );
  }
}

class _PulseAvatar extends StatelessWidget {
  final String? url;
  final AnimationController pulseCtrl;
  final bool isEmergency;
  final String initials;

  const _PulseAvatar({this.url, required this.pulseCtrl, required this.isEmergency, required this.initials});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (isEmergency)
          ScaleTransition(
            scale: Tween(
              begin: 1.0,
              end: 1.3,
            ).animate(CurvedAnimation(parent: pulseCtrl, curve: Curves.easeInOut)),
            child: Container(
              width: 54.w,
              height: 54.w,
              decoration: BoxDecoration(shape: BoxShape.circle, color: kErrorColor.withValues(alpha: 0.2)),
            ),
          ),
        Container(
          width: 58.w,
          height: 58.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: isEmergency ? kErrorColor : kPrimaryColor, width: 2),
          ),
          child: AppCachedImage(
            imageUrl: url ?? '',
            fit: BoxFit.cover,
            isOval: true,
            errorWidgetBuilder: Container(
              color: kPrimaryColor.withValues(alpha: 0.1),
              child: Center(
                child: Text(initials, style: kTextBold().copyWith(color: kPrimaryColor)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
