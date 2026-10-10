import 'dart:io' show Platform;

import 'package:adhisaat_health_care/core/config/env_config.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/features/user/address/bloc/selected_address_provider.dart';
import 'package:adhisaat_health_care/shared/widgets/inputs/common_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:place_picker_google/place_picker_google.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../di/locator.dart';
import '../../../../shared/widgets/buttons/custom_button.dart';
import '../../../auth/login/bloc/auth_bloc.dart';
import '../model/user_address_model.dart';

class LocationPickerPage extends ConsumerStatefulWidget {
  final String? addressData;
  final LatLng? initialLocation;
  final bool willPop;
  final bool returnResult;

  /// When true, confirming returns the picked [LocationResult] to the caller
  /// (the address-book search page) instead of replacing itself with the
  /// add/edit form.
  final bool forAddressBook;

  const LocationPickerPage({
    super.key,
    this.addressData,
    this.initialLocation,
    this.willPop = false,
    this.returnResult = false,
    this.forAddressBook = false,
  });

  @override
  ConsumerState<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends ConsumerState<LocationPickerPage> {
  GoogleMapController? mapController;
  LatLng? latLng;
  bool _isLoading = false;
  bool _isLocating = false;

  @override
  void initState() {
    latLng = widget.initialLocation;
    if (latLng == null) {
      _isLoading = true;
      _getCurrentLocation();
    }
    super.initState();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() {
            latLng = LatLng(position.latitude, position.longitude);
          });
          if (mapController != null) {
            mapController!.animateCamera(CameraUpdate.newLatLngZoom(latLng!, 15));
          }
        }
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String mapsApiKey = Platform.isAndroid
        ? EnvConfig.googleMapsApiKeyAndroid
        : EnvConfig.googleMapsApiKeyIOS;

    return Scaffold(
      backgroundColor: kWhiteColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 3, color: kPrimaryColor))
          : Stack(
              children: [
                // ── Map Section (Full Screen) ──
                Positioned.fill(
                  child: Theme(
                    data: Theme.of(context).copyWith(canvasColor: Colors.white),
                    child: PlacePicker(
                      usePinPointingSearch: true,
                      apiKey: mapsApiKey,
                      selectedPlaceWidgetBuilder: _buildBottomCard,
                      onPlacePicked: (LocationResult result) {
                        Navigator.of(context).pop(result);
                      },
                      enableNearbyPlaces: false,
                      showSearchInput: false,
                      initialLocation: latLng,
                      myLocationEnabled: true,
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      onMapCreated: (controller) {
                        mapController = controller;
                        // ignore: deprecated_member_use
                        controller.setMapStyle(_silverMapStyle);
                      },
                    ),
                  ),
                ),

                // ── Current Location FAB ──
                Positioned(
                  bottom: 240.h,
                  right: 16.w,
                  child: GestureDetector(
                    onTap: _isLocating ? null : _getCurrentLocation,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: kWhiteColor,
                        borderRadius: BorderRadius.circular(30.r),
                        boxShadow: [
                          BoxShadow(
                            color: kBlackColor.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isLocating) ...[
                            SizedBox(
                              width: 14.sp,
                              height: 14.sp,
                              child: const CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              "Locating...",
                              style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 12.sp),
                            ),
                          ] else ...[
                            Icon(Icons.my_location_rounded, color: kPrimaryColor, size: 17.sp),
                            SizedBox(width: 6.w),
                            Text(
                              "Current Location",
                              style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 12.sp),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Floating Header Section (Back button + Search Bar) ──
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12.h,
                  left: 16.w,
                  right: 16.w,
                  child: Row(
                    children: [
                      // Floating Back Button
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 48.w,
                          height: 48.w,
                          decoration: CommonDecoration.searchField(radius: 12.r),
                          child: Icon(Icons.arrow_back_rounded, color: kTextPrimaryColor, size: 20.sp),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // Floating Search Bar
                      Expanded(
                        child: Container(
                          height: 48.w,
                          decoration: BoxDecoration(
                            color: kWhiteColor,
                            borderRadius: BorderRadius.circular(12.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            readOnly: true,
                            onTap: () {
                              Navigator.of(context).pop(true);
                            },
                            decoration: InputDecoration(
                              hintText: "Search an area or address",
                              hintStyle: kTextNormal(color: kTextHintColor).copyWith(fontSize: 14.sp),
                              prefixIcon: Icon(Icons.search_rounded, color: kTextHintColor, size: 20.sp),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 13.h),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // Silver Map Style JSON
  final String _silverMapStyle = '''
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

  // ─────────────────────────────────────────────────────────────────
  //  Bottom address card — Compact Pink Style
  // ─────────────────────────────────────────────────────────────────
  Widget _buildBottomCard(BuildContext context, SearchingState state, LocationResult? selectedPlace) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [
          BoxShadow(color: kBlackColor.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Address Section (Always visible, loading in background) ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on_rounded, color: kPrimaryColor, size: 22.sp),
                    SizedBox(width: 8.w),
                    Text(
                      _getLocationHeading(selectedPlace),
                      style: kTextBold(color: kPrimaryColor).copyWith(fontSize: 16.sp),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  selectedPlace?.formattedAddress ?? "Move pin to your exact location",
                  style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 13.sp),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (selectedPlace != null &&
                    (selectedPlace.postalCode == null ||
                        selectedPlace.postalCode!.longName == null ||
                        selectedPlace.postalCode!.longName!.isEmpty)) ...[
                  SizedBox(height: 6.h),
                  Text(
                    "Zoom in to place the point to correct location",
                    style: kTextMedium(color: kErrorColor).copyWith(fontSize: 11.sp),
                  ),
                ],
              ],
            ),

            SizedBox(height: 20.h),

            // ── Confirm button ──
            SafeArea(
              top: false,
              child: CustomButton(
                title: "Confirm Location",
                width: double.infinity,
                height: 50.h,
                backgroundColor: kPrimaryColor,
                borderRadius: BorderRadius.circular(20),
                isEnable:
                    selectedPlace != null &&
                    selectedPlace.postalCode != null &&
                    selectedPlace.postalCode!.longName != null &&
                    selectedPlace.postalCode!.longName!.isNotEmpty,
                onPressed: () async {
                  if (selectedPlace == null) return;

                  // returnResult (e.g. registration) or address-book flow: just
                  // return the picked place to the caller.
                  if (widget.returnResult || widget.forAddressBook) {
                    Navigator.of(context).pop(selectedPlace);
                    return;
                  }

                  final authState = context.read<AuthBloc>().state;

                  if (authState is AuthAuthenticated) {
                    // Authenticated user -> Go to Add/Edit Address Page
                    final address = UserAddressModel(
                      fullAddress: selectedPlace.formattedAddress ?? '',
                      area:
                          selectedPlace.subLocalityLevel1?.longName ??
                          selectedPlace.subLocalityLevel2?.longName ??
                          selectedPlace.locality?.longName,
                      city: selectedPlace.locality?.longName,
                      state: selectedPlace.administrativeAreaLevel1?.longName,
                      pinCode: selectedPlace.postalCode?.longName,
                      latitude: selectedPlace.latLng?.latitude.toString(),
                      longitude: selectedPlace.latLng?.longitude.toString(),
                    );

                    AppNavigator.replaceWith(AppRoutes.userAddressAddEdit, args: address);
                  } else {
                    // Guest -> Save zip code in cache and update provider
                    final zipCode = selectedPlace.postalCode?.longName;
                    if (zipCode != null) {
                      await locator<LocalStorageService>().saveString(AppConstants.cachedZipCode, zipCode);

                      final address = UserAddressModel(
                        fullAddress: selectedPlace.formattedAddress ?? '',
                        area:
                            selectedPlace.subLocalityLevel1?.longName ??
                            selectedPlace.subLocalityLevel2?.longName ??
                            selectedPlace.locality?.longName,
                        city: selectedPlace.locality?.longName,
                        state: selectedPlace.administrativeAreaLevel1?.longName,
                        pinCode: zipCode,
                        latitude: selectedPlace.latLng?.latitude.toString(),
                        longitude: selectedPlace.latLng?.longitude.toString(),
                      );

                      // Update the reactive state
                      await ref.read(selectedAddressProvider.notifier).selectAddress(address);
                    }

                    if (!context.mounted) return;
                    Navigator.of(context).pop(selectedPlace);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Helpers
  // ─────────────────────────────────────────────────────────────────
  String _getLocationHeading(LocationResult? selectedPlace) {
    if (selectedPlace != null) {
      if (selectedPlace.subLocalityLevel2 != null && selectedPlace.subLocalityLevel2!.shortName != null) {
        return selectedPlace.subLocalityLevel2!.shortName ?? selectedPlace.subLocalityLevel2!.longName ?? '';
      } else if (selectedPlace.subLocalityLevel1 != null && selectedPlace.subLocalityLevel1!.shortName != null) {
        return selectedPlace.subLocalityLevel1!.shortName ?? selectedPlace.subLocalityLevel1!.longName ?? '';
      } else if (selectedPlace.locality != null) {
        return selectedPlace.locality!.shortName ?? selectedPlace.locality!.longName ?? '';
      }
    }
    return "Select a location";
  }

  void setLoading(bool b) => setState(() => _isLoading = b);
}
