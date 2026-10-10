import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/storage/local_storage_service.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_edge_insets.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/screen_dimensions.dart';
import '../../../../shared/widgets/buttons/custom_button.dart';
import '../bloc/emergency_tracking/emergency_tracking_bloc.dart';
import '../services/emergency_tracking_service.dart';

class EmergencyTrackingPage extends StatefulWidget {
  final int requestId;

  const EmergencyTrackingPage({super.key, required this.requestId});

  @override
  State<EmergencyTrackingPage> createState() => _EmergencyTrackingPageState();
}

class _EmergencyTrackingPageState extends State<EmergencyTrackingPage> with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  late AnimationController _pulseCtrl;

  // Smooth marker interpolation
  LatLng? _smoothProviderPos;
  Timer? _smoothTimer;

  late EmergencyTrackingBloc _trackingBloc;

  // Route & Markers
  Set<Polyline> _polylines = {};
  BitmapDescriptor? _userIcon;
  BitmapDescriptor? _providerIcon;
  bool _isFetchingRoute = false;
  LatLng? _lastRoutePos;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);

    _trackingBloc = context.read<EmergencyTrackingBloc>();
    _trackingBloc.add(StartTracking(requestId: widget.requestId));
    _loadCustomMarkers();
  }

  // ─── Data Extraction Helpers ───────────────────────────────────────────────

  double _getUserLat(Map<String, dynamic> data) =>
      (double.tryParse(data['service_latitude']?.toString() ?? '')) ?? (data['latitude'] as num?)?.toDouble() ?? 0.0;

  double _getUserLng(Map<String, dynamic> data) =>
      (double.tryParse(data['service_longitude']?.toString() ?? '')) ?? (data['longitude'] as num?)?.toDouble() ?? 0.0;

  Map<String, dynamic>? _getProviderProfile(Map<String, dynamic> data) {
    final dynamic profileData = data['service_provider_profile'];
    if (profileData is Map<String, dynamic>) {
      return profileData;
    }

    final dynamic assignments = data['assignments'];
    if (assignments is List && assignments.isNotEmpty) {
      final first = assignments.first;
      if (first is Map<String, dynamic>) {
        final dynamic pProfile = first['provider_profile'];
        if (pProfile is Map<String, dynamic>) {
          return pProfile;
        }
      }
    }
    return null;
  }

  String _getProviderName(Map<String, dynamic> data) => _getProviderProfile(data)?['full_name']?.toString() ?? 'Partner';

  int _getJobsDone(Map<String, dynamic> data) {
    final profile = _getProviderProfile(data);
    return profile?['total_jobs_completed'] ?? 0;
  }

  String _getExperience(Map<String, dynamic> data) {
    final profile = _getProviderProfile(data);
    return profile?['total_experience_text'] ?? '—';
  }

  String? _getProviderPhone(Map<String, dynamic> data) {
    final profile = _getProviderProfile(data);
    if (profile == null) return null;
    final dynamic userData = profile['user'];
    final Map<String, dynamic>? user = userData is Map<String, dynamic> ? userData : null;
    return profile['mobile_number']?.toString() ?? user?['mobile_number']?.toString();
  }

  double? _getProviderRating(Map<String, dynamic> data) {
    final profile = _getProviderProfile(data);
    if (profile == null) return 0.0;
    return (double.tryParse(profile['rating']?.toString() ?? '')) ?? 0.0;
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _smoothTimer?.cancel();
    _mapController?.dispose();
    _mapController = null; // Important to avoid memory leaks or calls to disposed controller
    _trackingBloc.add(StopTracking());
    super.dispose();
  }

  // ─── Location Logic ──────────────────────────────────────────────────────────

  bool _showTrackingErrorShown = false;

  void _onLocationReceived(ProviderLocation location, double userLat, double userLng) {
    if (location.latitude == 0 && location.longitude == 0) {
      _handleNullLocation();
      return;
    }

    final newPos = LatLng(location.latitude, location.longitude);

    // 1. Fetch directions if needed (Throttled)
    _fetchDirections(newPos, LatLng(userLat, userLng));

    // 2. Animate camera to keep both pins visible
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(_boundsFromLatLngs(LatLng(userLat, userLng), newPos), 120));
    }

    setState(() => _smoothProviderPos = newPos);
  }

  void _handleNullLocation() {
    if (_showTrackingErrorShown) return;
    _showTrackingErrorShown = true;

    // Use current state to get phone
    final state = context.read<EmergencyTrackingBloc>().state;
    String? phone;
    if (state is EmergencyTrackingActive) phone = _getProviderPhone(state.data);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            Icon(Icons.location_off_rounded, color: kErrorColor, size: 24.sp),
            SizedBox(width: 12.w),
            const Text('Tracking Unavailable'),
          ],
        ),
        content: const Text('Partner is unable to share live location at the moment. You can call the partner directly for updates.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Dismiss', style: kTextMedium(color: kTextSecondaryColor)),
          ),
          if (phone != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _callProvider(phone!);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kSuccessColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: Text('Call Partner', style: kTextMedium(color: kWhiteColor)),
            ),
        ],
      ),
    );
  }

  LatLngBounds _boundsFromLatLngs(LatLng a, LatLng b) {
    return LatLngBounds(
      southwest: LatLng(a.latitude < b.latitude ? a.latitude : b.latitude, a.longitude < b.longitude ? a.longitude : b.longitude),
      northeast: LatLng(a.latitude > b.latitude ? a.latitude : b.latitude, a.longitude > b.longitude ? a.longitude : b.longitude),
    );
  }

  Future<void> _callProvider(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ─── Route Finding ─────────────────────────────────────────────────────────

  Future<void> _fetchDirections(LatLng provider, LatLng user) async {
    if (_isFetchingRoute) return;

    // Throttle route fetches: skip if provider hasn't moved much (~30m)
    if (_lastRoutePos != null) {
      final dx = (provider.latitude - _lastRoutePos!.latitude);
      final dy = (provider.longitude - _lastRoutePos!.longitude);
      final distApprox = math.sqrt(dx * dx + dy * dy) * 111000;
      if (distApprox < 30) return;
    }

    _isFetchingRoute = true;
    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY_ANDROID'] ?? dotenv.env['GOOGLE_MAPS_API_KEY_IOS'] ?? '';
      if (apiKey.isEmpty) return;

      final url =
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${provider.latitude},${provider.longitude}'
          '&destination=${user.latitude},${user.longitude}'
          '&key=$apiKey';

      final response = await Dio().get(url);

      if (response.data['status'] == 'OK' && response.data['routes'].isNotEmpty) {
        final overviewPolyline = response.data['routes'][0]['overview_polyline']['points'];
        final points = _decodePolyline(overviewPolyline);

        _lastRoutePos = provider;
        if (mounted) {
          setState(() {
            _polylines = {
              Polyline(
                polylineId: const PolylineId('route_glow'),
                points: points,
                color: kPrimaryColor.withValues(alpha: 0.15),
                width: 12,
                jointType: JointType.round,
              ),
              Polyline(
                polylineId: const PolylineId('route'),
                points: points,
                color: kPrimaryColor,
                width: 5,
                jointType: JointType.round,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
            };
          });
        }
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

  // ─── Custom Markers ─────────────────────────────────────────────────────────

  Future<void> _loadCustomMarkers() async {
    // 1. User Marker (Me)
    final storage = locator<LocalStorageService>();
    final profile = await storage.getUserProfile();
    final userImg = profile?['profile_image_url'] ?? profile?['profile_photo_path'];
    final userInitials = _getInitials(storage.username ?? 'U');

    final uIcon = await _createCircularMarker(userImg, userInitials, kErrorColor);
    if (mounted) setState(() => _userIcon = uIcon);

    // 2. Provider Marker (Them)
    // We wait for the bloc state to get provider image
    _trackingBloc.stream.listen((state) async {
      if (state is EmergencyTrackingActive && mounted && _providerIcon == null) {
        final profile = _getProviderProfile(state.data);
        final pImg = profile?['profile_image_url'] ?? profile?['profile_photo_path'];
        final pName = profile?['full_name']?.toString() ?? 'P';

        final icon = await _createCircularMarker(pImg, _getInitials(pName), kPrimaryColor);
        if (mounted) setState(() => _providerIcon = icon);
      }
    });
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

    // Draw circular border
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

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EmergencyTrackingBloc, EmergencyTrackingState>(
      listener: (context, state) {
        if (state is EmergencyTrackingActive) {
          if (state.providerLocation != null) {
            _onLocationReceived(state.providerLocation!, _getUserLat(state.data), _getUserLng(state.data));
          }
        }
        if (state is EmergencyTrackingError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
        }
        if (state is EmergencyTrackingCompleted) {
          Navigator.of(context).pushReplacementNamed('/rating', arguments: widget.requestId);
        }
      },
      builder: (context, state) {
        if (state is EmergencyTrackingInitial) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: kPrimaryColor)),
          );
        }
        if (state is EmergencyTrackingError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.message, style: kTextNormal(color: kTextSecondaryColor)),
                  SizedBox(height: 16.h),
                  CustomButton(
                    onPressed: () => _trackingBloc.add(StartTracking(requestId: widget.requestId)),
                    title: 'Retry',
                  ),
                ],
              ),
            ),
          );
        }

        final active = state is EmergencyTrackingActive ? state : null;
        if (active == null) return const SizedBox.shrink();

        final data = active.data;
        kPrint(data.toString());
        final userLat = _getUserLat(data);
        final userLng = _getUserLng(data);
        final providerName = _getProviderName(data);

        // Build markers
        final markers = <Marker>{
          Marker(
            markerId: const MarkerId('user'),
            position: LatLng(userLat, userLng),
            icon: _userIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(title: 'Your Location'),
            anchor: const Offset(0.5, 0.5),
            zIndexInt: 2,
          ),
          // Provider — custom image marker
          if (_smoothProviderPos != null)
            Marker(
              markerId: const MarkerId('provider'),
              position: _smoothProviderPos!,
              icon: _providerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              infoWindow: InfoWindow(title: providerName, snippet: 'Partner'),
              anchor: const Offset(0.5, 0.5),
              zIndexInt: 3,
            ),
        };

        return Scaffold(
          backgroundColor: kScaffoldColor,
          body: SafeArea(
            top: false,
            child: Column(
            children: [
              // ── Map (expanded) ─────────────────────────────────────
              Expanded(
                child: Stack(
                  children: [
                    // Google Map
                    Positioned.fill(
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(target: LatLng(userLat, userLng), zoom: 15),
                        markers: markers,
                        polylines: _polylines,
                        onMapCreated: (ctrl) => _mapController = ctrl,
                        myLocationEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        compassEnabled: false,
                        mapType: MapType.normal,
                      ),
                    ),

                    // Top bar
                    SafeArea(
                      child: Padding(
                        padding: AppPadding.all(16),
                        child: Row(
                          children: [
                            _CircleButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Navigator.of(context).pop()),
                            const Spacer(),
                            _LiveBadge(pulseCtrl: _pulseCtrl, isCompleted: state is EmergencyTrackingCompleted),
                          ],
                        ),
                      ),
                    ),

                    // No location yet overlay
                    if (_smoothProviderPos == null)
                      Positioned(
                        top: 100.h,
                        left: 0,
                        right: 0,
                        child: Center(child: _WaitingBadge(pulseCtrl: _pulseCtrl)),
                      ),
                  ],
                ),
              ),

              // ── Bottom Panel ────────────────────────────────────────
              _TrackingBottomPanel(
                providerName: providerName,
                providerPhone: _getProviderPhone(data),
                providerRating: _getProviderRating(data),
                jobsDone: _getJobsDone(data),
                experience: _getExperience(data),
                onCall: _getProviderPhone(data) != null ? () => _callProvider(_getProviderPhone(data)!) : null,
                onRateNow: state is EmergencyTrackingCompleted
                    ? () => Navigator.of(context).pushReplacementNamed('/rating', arguments: widget.requestId)
                    : null,
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}

// ─── Bottom Panel ─────────────────────────────────────────────────────────────

class _TrackingBottomPanel extends StatelessWidget {
  final String providerName;
  final String? providerPhone;
  final double? providerRating;
  final int jobsDone;
  final String experience;
  final VoidCallback? onCall;
  final VoidCallback? onRateNow;

  const _TrackingBottomPanel({
    required this.providerName,
    required this.providerPhone,
    required this.providerRating,
    required this.jobsDone,
    required this.experience,
    required this.onCall,
    required this.onRateNow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: AppRadius.topOnly(32),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, -5))],
      ),
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44.w,
                height: 5.h,
                decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            SizedBox(height: 20.h),

            // Provider Core Profile
            Row(
              children: [
                // Avatar with premium border
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: kPrimaryColor.withValues(alpha: 0.2), width: 2),
                  ),
                  child: Container(
                    width: 60.w,
                    height: 60.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [kPrimaryColor, kSecondaryColor.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        providerName.isNotEmpty ? providerName[0].toUpperCase() : 'P',
                        style: kTextBold2(color: kWhiteColor).copyWith(fontSize: 22.sp),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                // Name & Rating
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(providerName, style: kTextBold1()),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(4.w),
                            decoration: BoxDecoration(color: kWarningColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                            child: Icon(Icons.star_rounded, color: kWarningColor, size: 12.sp),
                          ),
                          SizedBox(width: 6.w),
                          Text(providerRating?.toStringAsFixed(1) ?? '0.0', style: kTextSemiBold(color: kTextPrimaryColor)),
                          SizedBox(width: 8.w),
                          Container(
                            width: 4.w,
                            height: 4.w,
                            decoration: const BoxDecoration(color: kTextHintColor, shape: BoxShape.circle),
                          ),
                          SizedBox(width: 8.w),
                          Text('Professional Partner', style: kTextNormal0(color: kTextSecondaryColor)),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                if (onCall != null) _ActionButton(icon: Icons.phone_rounded, color: kSuccessColor, onTap: onCall!),
              ],
            ),

            SizedBox(height: 24.h),

            // Statistics Row
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: kScaffoldColor,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: kBorderColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  _StatItem(label: 'Experience', value: experience, icon: Icons.work_history_rounded),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Container(width: 1, height: 30.h, color: kDividerColor),
                  ),
                  _StatItem(label: 'Jobs Done', value: '$jobsDone+', icon: Icons.check_circle_rounded),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // Main CTA
            if (onRateNow != null)
              CustomButton(
                onPressed: onRateNow,
                title: 'Review Experience',
                iconData: Icons.star_rounded,
                backgroundColor: kPrimaryColor,
                textColor: kWhiteColor,
              )
            else
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16.r)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // SizedBox(width: 16.w, height: 16.w, child: const CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor)),
                    // SizedBox(width: 12.w),
                    Text('Partner is on the way...', style: kTextSemiBold(color: kPrimaryColor)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48.w,
        height: 48.w,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: color, size: 22.sp),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18.sp, color: kPrimaryColor.withValues(alpha: 0.6)),
          SizedBox(width: 10.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: kTextNormal0(color: kTextHintColor)),
              Text(
                value,
                style: kTextBold2(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final AnimationController pulseCtrl;
  final bool isCompleted;

  const _LiveBadge({required this.pulseCtrl, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (_, _) => Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8.w,
              height: 8.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? kSuccessColor : Color.lerp(kPrimaryColor, kPrimaryColor.withValues(alpha: 0.1), pulseCtrl.value),
              ),
            ),
            SizedBox(width: 8.w),
            Text(isCompleted ? 'Service Completed' : 'Live Tracking', style: kTextSemiBold(color: kTextPrimaryColor)),
          ],
        ),
      ),
    );
  }
}

class _WaitingBadge extends StatelessWidget {
  final AnimationController pulseCtrl;

  const _WaitingBadge({required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (_, _) => Container(
        padding: AppPadding.symmetric(h: 16, v: 8),
        decoration: BoxDecoration(
          color: Color.lerp(kPrimaryColor, kSecondaryColor, pulseCtrl.value),
          borderRadius: AppRadius.l,
          boxShadow: [
            BoxShadow(
              color: kPrimaryColor.withValues(alpha: 0.3 + pulseCtrl.value * 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14.w,
              height: 14.w,
              child: const CircularProgressIndicator(color: kWhiteColor, strokeWidth: 2),
            ),
            AppSpacing.sHorizontal,
            Text('Waiting for provider location…', style: kTextSemiBold0(color: kWhiteColor)),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42.w,
      height: 42.w,
      decoration: BoxDecoration(
        color: kWhiteColor,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10)],
      ),
      child: Icon(icon, size: 18.sp, color: kTextPrimaryColor),
    ),
  );
}
