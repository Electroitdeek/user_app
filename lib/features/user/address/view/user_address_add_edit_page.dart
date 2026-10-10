import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/theme/screen_dimensions.dart';
import 'package:adhisaat_health_care/features/user/address/view/location_picker_page.dart';
import 'package:adhisaat_health_care/features/user/home/view/search_address_page.dart' as adhisaat_search;
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:place_picker_google/place_picker_google.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_edge_insets.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../di/locator.dart';
import '../../../../shared/widgets/buttons/custom_button.dart';
import '../../../../shared/widgets/inputs/custom_text_field.dart';
import '../bloc/selected_address_provider.dart';
import '../bloc/user_address_bloc.dart';
import '../data/user_address_repository.dart';
import '../model/user_address_model.dart';

class UserAddressAddEditPage extends StatelessWidget {
  final UserAddressModel? existing;

  /// When true (address-book "Add New" flow), pop back to the My Addresses
  /// page on save instead of a single back() — clears intermediate
  /// search/location-picker routes from the stack.
  final bool fromAddressBook;

  const UserAddressAddEditPage({super.key, this.existing, this.fromAddressBook = false});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UserAddressBloc>(
      create: (_) => UserAddressBloc(locator<UserAddressRepository>()),
      child: _AddressAddEditView(existing: existing, fromAddressBook: fromAddressBook),
    );
  }
}

class _AddressAddEditView extends ConsumerStatefulWidget {
  final UserAddressModel? existing;
  final bool fromAddressBook;

  const _AddressAddEditView({this.existing, this.fromAddressBook = false});

  @override
  ConsumerState<_AddressAddEditView> createState() => _AddressAddEditViewState();
}

class _AddressAddEditViewState extends ConsumerState<_AddressAddEditView> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _fullAddressCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pinCodeCtrl = TextEditingController();

  String _addressType = 'home';
  bool _isDefault = false;
  bool _isLoading = false;

  // Coordinates
  String? _selectedLat;
  String? _selectedLng;
  UserAddressModel? _lastCreatedAddress;

  // Edit only when an existing *saved* address (with id) is passed. A pre-filled
  // address without an id (e.g. from the location picker) is still a new add.
  bool get _isEdit => widget.existing?.id != null;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _fullAddressCtrl.text = e.fullAddress;
      _areaCtrl.text = e.area ?? '';
      _cityCtrl.text = e.city ?? '';
      _stateCtrl.text = e.state ?? '';
      _pinCodeCtrl.text = e.pinCode ?? '';
      // Only Home/Work/Other are valid labels; anything else (e.g. 'current'
      // from the current-location flow) falls back to Home.
      _addressType = const ['home', 'work', 'other'].contains(e.addressType) ? e.addressType! : 'home';
      _isDefault = e.isDefault;
      _selectedLat = e.latitude;
      _selectedLng = e.longitude;
    }

    // Automatic location picking removed to prevent redundant navigation.
    // Users will now either arrive with a location from LocationPickerPage
    // or select one manually using the SELECT button.
  }

  @override
  void dispose() {
    _fullAddressCtrl.dispose();
    _areaCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pinCodeCtrl.dispose();
    super.dispose();
  }

  bool _isFetchingLocation = false;

  Future<void> _pickLocation() async {
    setState(() => _isFetchingLocation = true);
    LatLng? initLatLng;
    if (_selectedLat != null) {
      double? latitude = double.tryParse(_selectedLat!.trim());
      double? longitude = double.tryParse(_selectedLng!.trim());
      if (latitude != null && longitude != null) {
        initLatLng = LatLng(latitude, longitude);
      }
    }

    try {
      final dynamic result = await AppNavigator.push(
        LocationPickerPage(initialLocation: initLatLng, returnResult: true),
      );

      if (result == true) {
        // User clicked the search bar in LocationPickerPage
        final searchResult = await AppNavigator.push(
          const adhisaat_search.SearchAddressPage(returnResult: true, forAddressBook: true),
        );

        if (searchResult is UserAddressModel) {
          setState(() {
            _selectedLat = searchResult.latitude;
            _selectedLng = searchResult.longitude;
            _fullAddressCtrl.text = searchResult.fullAddress;
            if (searchResult.area != null) _areaCtrl.text = searchResult.area!;
          });
        }
        return;
      }

      if (result is LocationResult) {
        debugPrint("📍 Selected LatLng: ${result.latLng}");
        debugPrint("📍 Selected Address: ${result.formattedAddress}");
      }

      if (result is LocationResult && result.latLng != null) {
        setState(() {
          _selectedLat = result.latLng!.latitude.toString();
          _selectedLng = result.latLng!.longitude.toString();

          // Fill address fields
          _fullAddressCtrl.text = result.formattedAddress ?? '';

          if (result.administrativeAreaLevel3 != null) {
            _cityCtrl.text = result.administrativeAreaLevel3!.longName ?? '';
          } else if (result.locality != null) {
            _cityCtrl.text = result.locality!.longName ?? '';
          }

          if (result.administrativeAreaLevel1 != null) {
            _stateCtrl.text = result.administrativeAreaLevel1!.longName ?? '';
          }

          if (result.postalCode != null) {
            _pinCodeCtrl.text = result.postalCode!.shortName ?? '';
          }

          String? area;
          if (result.subLocalityLevel1 != null &&
              result.subLocalityLevel1!.shortName != null &&
              result.subLocalityLevel1!.shortName!.isNotEmpty) {
            area = result.subLocalityLevel1!.shortName;
          } else if (result.subLocalityLevel2 != null &&
              result.subLocalityLevel2!.shortName != null &&
              result.subLocalityLevel2!.shortName!.isNotEmpty) {
            area = result.subLocalityLevel2!.shortName;
          } else if (result.locality != null &&
              result.locality!.longName != null &&
              result.locality!.longName!.isNotEmpty) {
            area = result.locality!.longName;
          } else if (result.locality != null &&
              result.locality!.shortName != null &&
              result.locality!.shortName!.isNotEmpty) {
            area = result.locality!.shortName;
          }

          if (area != null) {
            _areaCtrl.text = area;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location picked successfully!'),
              backgroundColor: kSuccessColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick location: $e'),
            backgroundColor: kErrorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // Require user to select coordinates
    if (_selectedLat == null || _selectedLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please pick a location from the map'),
          backgroundColor: kErrorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final address = UserAddressModel(
      id: widget.existing?.id,
      addressType: _addressType,
      fullAddress: _fullAddressCtrl.text.trim(),
      area: _areaCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      state: _stateCtrl.text.trim(),
      pinCode: _pinCodeCtrl.text.trim(),
      isDefault: _isDefault,
      latitude: _selectedLat,
      longitude: _selectedLng,
    );

    _lastCreatedAddress = address;

    if (_isEdit) {
      context.read<UserAddressBloc>().add(UpdateAddress(address));
    } else {
      context.read<UserAddressBloc>().add(AddAddress(address));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserAddressBloc, UserAddressState>(
      listener: (context, state) {
        if (state is UserAddressLoading) setState(() => _isLoading = true);
        if (state is! UserAddressLoading) setState(() => _isLoading = false);

        if (state is UserAddressActionSuccess) {
          if (_lastCreatedAddress != null) {
            ref.read(selectedAddressProvider.notifier).selectAddress(_lastCreatedAddress!);
          }
          if (widget.fromAddressBook) {
            // Came via Add New → Search → (picker) → form. Drop the intermediate
            // routes and land back on the My Addresses list.
            Navigator.of(context).popUntil(
              (route) =>
                  route.settings.name == AppRoutes.userAddressList ||
                  route.settings.name == AppRoutes.addressSelectionSheet ||
                  route.settings.name == AppRoutes.serviceBookingFlow ||
                  route.settings.name == AppRoutes.emergency ||
                  route.settings.name == 'service_booking_flow' ||
                  route.isFirst,
            );
          } else {
            AppNavigator.back();
          }
        }
        if (state is UserAddressError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: kErrorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: kScaffoldColor,
        appBar: CustomAppBar(title: _isEdit ? 'Edit Address' : 'Add New Address', centerTitle: false),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: AppPadding.all(20),
                  children: [
                    // Compact Location Picker Card
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                      decoration: BoxDecoration(
                        color: kWhiteColor,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: _selectedLat == null ? kErrorColor : const Color(0xFFF0F1F3),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: kPrimaryColor.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.gps_fixed_rounded, color: kPrimaryColor, size: 18.sp),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _areaCtrl.text.isNotEmpty ? _areaCtrl.text : 'Select Location',
                                  style: kTextBold(
                                    color: _selectedLat == null ? kErrorColor : kTextPrimaryColor,
                                  ).copyWith(fontSize: 14.sp),
                                ),
                                if (_fullAddressCtrl.text.isNotEmpty)
                                  Text(
                                    _fullAddressCtrl.text,
                                    style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 10.sp),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),
                          GestureDetector(
                            onTap: _isFetchingLocation ? null : _pickLocation,
                            child: Text(
                              _selectedLat != null ? 'CHANGE' : 'SELECT',
                              style: kTextBold(color: kPrimaryColor).copyWith(fontSize: 11.sp),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.lVertical,

                    // Address type chips
                    Row(
                      children: [
                        Text(
                          'Save as',
                          style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 13.sp),
                        ),
                        const Spacer(),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    _AddressTypeSelector(
                      selected: _addressType,
                      onSelect: (t) => setState(() => _addressType = t),
                    ),
                    AppSpacing.lVertical,

                    // Address Details Group Card
                    CustomTextField(
                      controller: _fullAddressCtrl,
                      labelText: 'Full Address',
                      isRequired: true,
                      hintText: 'House no., floor, building name…',
                      prefixIcon: const Icon(Icons.location_on_rounded, color: kPrimaryColor, size: 18),
                      maxLines: 2,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    AppSpacing.lVertical,
                    CustomTextField(
                      controller: _areaCtrl,
                      labelText: 'Area / Locality',
                      hintText: 'e.g. Gopal Pura Mode',
                      prefixIcon: const Icon(Icons.map_rounded, color: kPrimaryColor, size: 18),
                    ),
                    AppSpacing.lVertical,

                    // City & State in a row
                    // Row(
                    //   crossAxisAlignment: CrossAxisAlignment.start,
                    //   children: [
                    //     Expanded(
                    //       child: CustomTextField(
                    //         controller: _cityCtrl,
                    //         labelText: 'City',
                    //         isRequired: true,
                    //         hintText: 'City',
                    //         prefixIcon: const Icon(
                    //           Icons.location_city_rounded,
                    //           color: kPrimaryColor,
                    //           size: 20,
                    //         ),
                    //         validator: (v) => v == null || v.trim().isEmpty
                    //             ? 'Required'
                    //             : null,
                    //       ),
                    //     ),
                    //     AppSpacing.mHorizontal,
                    //     Expanded(
                    //       child: CustomTextField(
                    //         controller: _stateCtrl,
                    //         labelText: 'State',
                    //         hintText: 'State',
                    //         prefixIcon: const Icon(
                    //           Icons.flag_rounded,
                    //           color: kPrimaryColor,
                    //           size: 20,
                    //         ),
                    //       ),
                    //     ),
                    //   ],
                    // ),
                    // AppSpacing.lVertical,

                    // PIN Code
                    // CustomTextField(
                    //   controller: _pinCodeCtrl,
                    //   labelText: 'PIN Code',
                    //   hintText: '6-digit PIN code',
                    //   prefixIcon: const Icon(
                    //     Icons.pin_drop_rounded,
                    //     color: kPrimaryColor,
                    //     size: 20,
                    //   ),
                    //   keyboardType: TextInputType.number,
                    //   maxLength: 6,
                    //   isNumeric: true,
                    // ),
                    // AppSpacing.lVertical,

                    // Default toggle Card
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: kWhiteColor,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: _isDefault
                                  ? kSuccessColor.withValues(alpha: 0.1)
                                  : kGreyColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.star_rounded,
                              color: _isDefault ? kSuccessColor : kTextHintColor,
                              size: 16.sp,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Set as Default',
                                  style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 13.sp),
                                ),
                                Text(
                                  'Quick auto-fill for future bookings',
                                  style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 10.sp),
                                ),
                              ],
                            ),
                          ),
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: _isDefault,
                              onChanged: (v) => setState(() => _isDefault = v),
                              activeThumbColor: kPrimaryColor,
                              activeTrackColor: kPrimaryColor.withValues(alpha: 0.2),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.lVertical,
                  ],
                ),
              ),

              // Save button
              Container(
                decoration: BoxDecoration(
                  color: kWhiteColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                padding: AppPadding.only(left: 20, right: 20, top: 16, bottom: 24),
                child: SafeArea(
                  top: false,
                  child: CustomButton(
                    onPressed: _submit,
                    title: _isEdit ? 'Update Address' : 'Save Address',
                    isLoading: _isLoading,
                    width: double.infinity,
                    height: 52,
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────
//  Address type chip selector
// ───────────────────────────────────────────────────────
class _AddressTypeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _AddressTypeSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const types = [
      {'key': 'home', 'label': 'Home', 'icon': Icons.home_rounded},
      {'key': 'work', 'label': 'Work', 'icon': Icons.work_rounded},
      {'key': 'other', 'label': 'Other', 'icon': Icons.place_rounded},
    ];

    return Row(
      children: types.map((t) {
        final sel = selected == t['key'];
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(t['key'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: t['key'] == 'other' ? 0 : 8.w),
              padding: EdgeInsets.symmetric(vertical: 10.h),
              decoration: BoxDecoration(
                color: sel ? kPrimaryColor : kWhiteColor,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: sel ? kPrimaryColor : const Color(0xFFF3F4F6), width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(t['icon'] as IconData, color: sel ? kWhiteColor : kTextSecondaryColor, size: 16.sp),
                  SizedBox(width: 6.w),
                  Text(
                    t['label'] as String,
                    style: kTextSemiBold(color: sel ? kWhiteColor : kTextSecondaryColor).copyWith(fontSize: 12.sp),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
