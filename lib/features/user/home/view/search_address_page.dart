import 'dart:async';
import 'dart:io';

import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/data/providers/service_availability_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:place_picker_google/place_picker_google.dart' as google_place_picker;

import '../../../../core/config/env_config.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/location_permission_dialog.dart';
import '../../../../di/locator.dart';
import '../../../../shared/widgets/inputs/common_inputs.dart';
import '../../../auth/login/bloc/auth_bloc.dart';
import '../../address/bloc/selected_address_provider.dart';
import '../../address/data/user_address_repository.dart';
import '../../address/model/user_address_model.dart';
import '../../address/view/location_picker_page.dart';
import '../../address/view/user_address_add_edit_page.dart';

class SearchAddressPage extends ConsumerStatefulWidget {
  final bool isFromPermissionGate;
  final bool hideSavedAddresses;
  final bool returnResult;

  /// When true (opened from My Addresses → Add New), a selected location opens
  /// the Add Address form instead of being set as the active address.
  final bool forAddressBook;

  const SearchAddressPage({
    super.key,
    this.isFromPermissionGate = false,
    this.hideSavedAddresses = false,
    this.returnResult = false,
    this.forAddressBook = false,
  });

  @override
  ConsumerState<SearchAddressPage> createState() => _SearchAddressPageState();
}

class _SearchAddressPageState extends ConsumerState<SearchAddressPage> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  List<UserAddressModel> _savedAddresses = [];
  bool _loadingSavedAddresses = false;
  bool _loadingCurrentLocation = false;
  List<Prediction> _predictions = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();

    super.dispose();
  }

  void _handleExit([dynamic result]) {
    if (!mounted) return;
    if (widget.returnResult) {
      Navigator.pop(context, result);
      return;
    }

    if (widget.isFromPermissionGate) {
      Navigator.pop(context);
    } else {
      // If we can pop (e.g. came from a booking flow or search page), just pop.
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context);
        return;
      }

      final authState = context.read<AuthBloc>().state;
      final route = (authState is AuthAuthenticated) ? AppRoutes.userDashboard : AppRoutes.userHome;
      // Use rootNavigator: true to escape any nested wizards (like ServiceBookingFlow)
      // and reach the global AppRoutes handler.
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(route, (route) => false);
    }
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  Future<void> _loadSavedAddresses() async {
    if (widget.hideSavedAddresses) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    setState(() => _loadingSavedAddresses = true);
    try {
      final addresses = await locator<UserAddressRepository>().getAddresses();
      if (mounted) setState(() => _savedAddresses = addresses);
    } catch (_) {
      // silently ignore — saved addresses are optional
    } finally {
      if (mounted) setState(() => _loadingSavedAddresses = false);
    }
  }

  // ── Selection handlers ──────────────────────────────────────────────────────

  /// Opens the Add Address form pre-filled with [address] (address-book flow).
  /// The form pops back to My Addresses on save.
  Future<void> _openAddressForm(UserAddressModel address) {
    return AppNavigator.push(UserAddressAddEditPage(existing: address, fromAddressBook: true));
  }

  UserAddressModel _addressFromPicker(google_place_picker.LocationResult r) {
    return UserAddressModel(
      fullAddress: r.formattedAddress ?? '',
      area: r.subLocalityLevel1?.longName ?? r.subLocalityLevel2?.longName ?? r.locality?.longName,
      city: r.locality?.longName,
      state: r.administrativeAreaLevel1?.longName,
      pinCode: r.postalCode?.longName,
      latitude: r.latLng?.latitude.toString(),
      longitude: r.latLng?.longitude.toString(),
    );
  }

  Future<void> _onUseCurrentLocation() async {
    // Check permission status first
    final status = await Permission.location.status;
    if (!mounted) return;
    if (!status.isGranted && !status.isLimited) {
      final result = await LocationPermissionDialog.show(context);
      if (!mounted) return;
      if (result != true) return; // User denied or closed the dialog
    }

    setState(() => _loadingCurrentLocation = true);
    try {
      final locationService = locator<LocationService>();
      final result = await locationService.getCurrentLocation();
      if (!mounted) return;
      if (!result.isSuccess || result.position == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message), backgroundColor: kErrorColor));
        return;
      }

      final pos = result.position!;
      final addressResult = await locationService.getAddressFromCoordinates(latitude: pos.latitude, longitude: pos.longitude);
      if (!mounted) return;

      final place = addressResult.placemark;
      final address = UserAddressModel(
        addressType: 'current',
        fullAddress: addressResult.formattedAddress ?? '',
        area: place?.subLocality?.isNotEmpty == true ? place!.subLocality : place?.locality,
        city: place?.locality,
        state: place?.administrativeArea,
        pinCode: place?.postalCode,
        latitude: pos.latitude.toString(),
        longitude: pos.longitude.toString(),
      );

      if (widget.returnResult) {
        _handleExit(address);
      } else if (widget.forAddressBook) {
        await _openAddressForm(address);
      } else {
        await ref.read(selectedAddressProvider.notifier).selectAddress(address);
        if (!mounted) return;
        // Force immediate availability check to update city admin in storage
        await ref.read(serviceAvailabilityProvider.future);
        _handleExit();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not get location. Please try again.'), backgroundColor: kErrorColor));
      }
    } finally {
      if (mounted) setState(() => _loadingCurrentLocation = false);
    }
  }

  Future<void> _onSavedAddressSelected(UserAddressModel address) async {
    if (widget.returnResult) {
      _handleExit(address);
    } else {
      if (!mounted) return;
      await ref.read(selectedAddressProvider.notifier).selectAddress(address);
      if (!mounted) return;
      // Force immediate availability check to update city admin in storage
      await ref.read(serviceAvailabilityProvider.future);
      _handleExit();
    }
  }

  // ── Search Logic ───────────────────────────────────────────────────────────

  Future<void> _getPredictions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _predictions = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final mapsApiKey = Platform.isAndroid ? EnvConfig.googleMapsApiKeyAndroid : EnvConfig.googleMapsApiKeyIOS;

      final url =
          "https://maps.googleapis.com/maps/api/place/autocomplete/json"
          "?input=$query"
          "&key=$mapsApiKey"
          "&components=country:in";

      final response = await Dio().get(url);

      if (response.statusCode == 200 && mounted) {
        final predictionsJson = response.data['predictions'] as List;
        setState(() {
          _predictions = predictionsJson.map((p) => Prediction.fromJson(p)).toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching predictions: $e");
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _getPredictions(query);
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isLoggedIn = authState is AuthAuthenticated;

    return Scaffold(
      backgroundColor: kWhiteColor,
      appBar: AppBar(
        backgroundColor: kWhiteColor,
        elevation: 0,
        forceMaterialTransparency: true,
        leading: IconButton(
          onPressed: _handleExit,
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: kTextPrimaryColor, size: 20.sp),
        ),
        title: Text('Search Location', style: kTextBold().copyWith(fontSize: 18.sp)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              // ── Premium Search Bar ──────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 16.h),
                child: CommonSearchField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  hintText: 'Search city, area or landmark',
                  onChanged: _onSearchChanged,
                ),
              ),

              // ── Scrollable Body ──────────────────────────────────────────────────
              Expanded(
                child: ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 32.h),
                  children: [
                    // Compact action row
                    Row(
                      children: [
                        _buildCompactActionCard(
                          onTap: _loadingCurrentLocation ? null : _onUseCurrentLocation,
                          icon: Icons.my_location_rounded,
                          title: 'Current Location',
                          color: kPrimaryColor,
                          showLoader: _loadingCurrentLocation,
                        ),
                        if (isLoggedIn && !widget.returnResult) ...[
                          SizedBox(width: 12.w),
                          _buildCompactActionCard(
                            color: kAccentColor,
                            onTap: () async {
                              final result = await AppNavigator.push(
                                LocationPickerPage(returnResult: widget.returnResult, forAddressBook: widget.forAddressBook),
                                fullscreenDialog: true,
                              );
                              if (result is google_place_picker.LocationResult && widget.forAddressBook && mounted) {
                                await _openAddressForm(_addressFromPicker(result));
                              } else if (result is bool && result == true && mounted) {
                                _searchFocusNode.requestFocus();
                              } else if (result != null && widget.returnResult) {
                                _handleExit(result);
                              }
                            },
                            icon: Icons.add_location_alt_rounded,
                            title: 'Pick Location',
                          ),
                        ],
                      ],
                    ),

                    SizedBox(height: 24.h),

                    // ── Conditional Body: Search Results OR Saved Addresses ────────
                    if (_searchController.text.isNotEmpty) ...[
                      if (_isSearching && _predictions.isEmpty)
                        const Center(
                          child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
                        )
                      else if (_predictions.isNotEmpty) ...[
                        _buildSectionHeader('Search Results'),
                        SizedBox(height: 8.h),
                        ..._predictions.map((p) => _buildPredictionItem(p)),
                      ] else if (!_isSearching)
                        Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Text("No results found", style: kTextNormal(color: kTextHintColor)),
                          ),
                        ),
                    ] else ...[
                      // Saved addresses section
                      if (isLoggedIn && !widget.hideSavedAddresses) ...[
                        if (_loadingSavedAddresses)
                          const Center(
                            child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
                          )
                        else if (_savedAddresses.isNotEmpty) ...[
                          _buildSectionHeader('Saved Addresses'),
                          SizedBox(height: 12.h),
                          ..._savedAddresses.map(_buildSavedAddressCard),
                        ],
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: 4.h),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 16.h,
            decoration: BoxDecoration(color: kAccentColor, borderRadius: BorderRadius.circular(2.r)),
          ),
          SizedBox(width: 8.w),
          Text(
            title,
            style: kTextBold().copyWith(fontSize: 15.sp, color: kTextPrimaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactActionCard({
    required VoidCallback? onTap,
    required IconData icon,
    required String title,
    Color color = kPrimaryColor,
    bool showLoader = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10.r)),
                child: showLoader
                    ? Padding(
                        padding: EdgeInsets.all(7.w),
                        child: CircularProgressIndicator(strokeWidth: 2, color: color),
                      )
                    : Icon(icon, color: color, size: 18.sp),
              ),
              SizedBox(width: 8.w),
              Flexible(
                child: Text(
                  title,
                  style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 11.5.sp),
                  textAlign: TextAlign.start,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedAddressCard(UserAddressModel address) {
    final type = address.addressType?.toLowerCase() ?? 'other';
    final icon = switch (type) {
      'home' => Icons.home_rounded,
      'work' => Icons.work_rounded,
      _ => Icons.location_on_rounded,
    };

    final Color color = switch (type) {
      'home' => kPrimaryColor,
      'work' => kAccentColor,
      _ => kSecondaryColor,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: InkWell(
        onTap: () => _onSavedAddressSelected(address),
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: kWhiteColor,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: color.withValues(alpha: 0.18), width: 1.2),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14.r)),
                child: Icon(icon, color: color, size: 22.sp),
              ),
              SizedBox(width: 14.w),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (address.addressType ?? 'OTHER').toUpperCase(),
                      style: kTextBold(color: color).copyWith(fontSize: 10.sp, letterSpacing: 0.5),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${address.area ?? ''}${address.area != null && address.city != null ? ", " : ""}${address.city ?? ''}',
                      style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 15.sp),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      address.fullAddress,
                      style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Trailing
              Icon(Icons.chevron_right_rounded, color: kGreyColor4.withValues(alpha: 0.8), size: 20.sp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionItem(Prediction prediction) {
    final title = prediction.structuredFormatting?.mainText ?? (prediction.description?.split(',').first.trim() ?? '');
    final subtitle =
        prediction.structuredFormatting?.secondaryText ??
        (prediction.description?.contains(',') == true ? prediction.description!.split(',').sublist(1).join(',').trim() : '');

    return ListTile(
      onTap: () async {
        // Fetch details for the selected place to get lat/lng
        final mapsApiKey = Platform.isAndroid ? EnvConfig.googleMapsApiKeyAndroid : EnvConfig.googleMapsApiKeyIOS;
        final url =
            "https://maps.googleapis.com/maps/api/place/details/json"
            "?place_id=${prediction.placeId}"
            "&key=$mapsApiKey";

        try {
          final response = await Dio().get(url);
          if (response.statusCode == 200) {
            final result = response.data['result'];
            final lat = result['geometry']['location']['lat'] as double;
            final lng = result['geometry']['location']['lng'] as double;

            if (mounted) {
              // Navigate to Location Picker instead of direct selection
              final pickerResult = await AppNavigator.push(
                LocationPickerPage(initialLocation: LatLng(lat, lng), returnResult: widget.returnResult, forAddressBook: widget.forAddressBook),
                fullscreenDialog: true,
              );
              if (!mounted) return;

              if (pickerResult is google_place_picker.LocationResult) {
                final address = _addressFromPicker(pickerResult);
                kPrint("SearchAddressPage: Picking from map result: ${address.fullAddress}");
                if (widget.returnResult) {
                  Navigator.of(context).pop(address);
                } else if (widget.forAddressBook) {
                  await _openAddressForm(address);
                } else {
                  await ref.read(selectedAddressProvider.notifier).selectAddress(address);
                  if (!mounted) return;
                  await ref.read(serviceAvailabilityProvider.future);
                  _handleExit();
                }
              } else if (pickerResult == true) {
                _searchFocusNode.requestFocus();
              } else if (pickerResult != null && widget.returnResult) {
                _handleExit(pickerResult);
              }
            }
          }
        } catch (e) {
          debugPrint("Error fetching place details: $e");
        }
      },
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      leading: Container(
        width: 44.w,
        height: 44.w,
        decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12.r)),
        child: Icon(Icons.location_on_outlined, color: kPrimaryColor, size: 20.sp),
      ),
      title: Text(
        title,
        style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 15.sp),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: kTextNormal(color: kTextHintColor).copyWith(fontSize: 12.sp),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Icon(Icons.chevron_right_rounded, color: kGreyColor4, size: 20.sp),
    );
  }
}
