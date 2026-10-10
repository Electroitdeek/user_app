import 'package:adhisaat_health_care/core/widgets/location_permission_dialog.dart';
import 'package:adhisaat_health_care/core/widgets/login_required_dialog.dart';
import 'package:adhisaat_health_care/data/providers/service_availability_provider.dart';
import 'package:adhisaat_health_care/data/providers/system_settings_provider.dart';
import 'package:adhisaat_health_care/features/auth/login/bloc/auth_bloc.dart';
import 'package:adhisaat_health_care/features/user/home/view/search_address_page.dart';
import 'package:adhisaat_health_care/features/user/address/model/user_address_model.dart';
import 'package:adhisaat_health_care/core/services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/navigation/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_edge_insets.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/theme/screen_dimensions.dart';
import '../../../../../core/utils/number_utils.dart';
import '../../../../../di/locator.dart';
import '../../../../../shared/widgets/common/app_cached_image.dart';
import '../../../../../shared/widgets/common/custom_error_view.dart';
import '../../../../../shared/widgets/shimmer/provider_shimmers.dart';
import '../../../../../shared/widgets/common/no_service_view.dart' as shared;
import '../../../../../shared/widgets/inputs/common_inputs.dart';
import '../../../address/bloc/selected_address_provider.dart';
import '../../bloc/service_category_bloc.dart';
import '../../bloc/sub_category_bloc.dart';
import '../../data/service_category_repository.dart';
import '../../model/booking_model.dart';
import '../../model/service_category_model.dart';
import '../service_booking_flow.dart';
import '../widgets/booking_type_bottom_sheet.dart';

class Step1SelectServicePage extends StatelessWidget {
  final BookingRequest request;
  final ValueChanged<BookingRequest> onUpdate;
  final ServiceCategoryModel? initialMainCategory;
  final bool autofocusSearch;
  final bool isEmergency;

  const Step1SelectServicePage({
    super.key,
    required this.request,
    required this.onUpdate,
    this.initialMainCategory,
    this.autofocusSearch = false,
    this.isEmergency = false,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ServiceCategoryBloc>(create: (_) => ServiceCategoryBloc(locator<ServiceCategoryRepository>())),
        BlocProvider<SubCategoryBloc>(create: (_) => locator<SubCategoryBloc>()),
      ],
      child: _Step1Body(
        request: request,
        onUpdate: onUpdate,
        initialMainCategory: initialMainCategory,
        autofocusSearch: autofocusSearch,
        isEmergency: isEmergency,
      ),
    );
  }
}

class _Step1Body extends ConsumerStatefulWidget {
  final BookingRequest request;
  final ValueChanged<BookingRequest> onUpdate;
  final ServiceCategoryModel? initialMainCategory;
  final bool autofocusSearch;
  final bool isEmergency;

  const _Step1Body({
    required this.request,
    required this.onUpdate,
    this.initialMainCategory,
    required this.autofocusSearch,
    required this.isEmergency,
  });

  @override
  ConsumerState<_Step1Body> createState() => _Step1BodyState();
}

class _Step1BodyState extends ConsumerState<_Step1Body> {
  int? _selectedCategoryId;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  Future<void> _autoResolveLocation() async {
    try {
      final locationService = locator<LocationService>();
      final result = await locationService.getCurrentLocation();
      if (!result.isSuccess || result.position == null) return;

      final pos = result.position!;
      final addressResult = await locationService.getAddressFromCoordinates(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );

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

      if (mounted) {
        await ref.read(selectedAddressProvider.notifier).selectAddress(address);
        // Force immediate availability check to update city admin in storage
        await ref.read(serviceAvailabilityProvider.future);
        // Reload local service categories
        if (mounted) {
          context.read<ServiceCategoryBloc>().add(LoadServiceCategories(isEmergency: widget.isEmergency));
        }
      }
    } catch (e) {
      debugPrint("Error auto-resolving location: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    if (widget.autofocusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1. Try loading default address for logged-in user
      await ref.read(selectedAddressProvider.notifier).loadForLoggedInUser();
      
      if (!mounted) return;

      // 2. If an address is already selected, don't ask for permission and trigger categories load.
      final selectedAddress = ref.read(selectedAddressProvider);
      if (selectedAddress != null) {
        context.read<ServiceCategoryBloc>().add(LoadServiceCategories(isSilent: true, isEmergency: widget.isEmergency));
        return;
      }

      // 3. Check permission status
      final locationService = locator<LocationService>();
      final isGranted = await locationService.isLocationPermissionGranted();
      if (isGranted) {
        await _autoResolveLocation();
      } else {
        final permission = await locationService.getPermissionStatus();
        final isPermanentlyDenied = permission == LocationPermission.deniedForever;
        
        if (!mounted) return;
        final result = await LocationPermissionDialog.show(context, isPermanentlyDenied: isPermanentlyDenied);
        if (result == true && mounted) {
          await _autoResolveLocation();
        } else if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    });

    if (widget.initialMainCategory != null) {
      _selectedCategoryId = widget.initialMainCategory!.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SubCategoryBloc>().add(LoadSubCategories(widget.initialMainCategory!.id));
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  void _onCategoryTap(ServiceCategoryModel cat) {
    if (_selectedCategoryId == cat.id) return;
    setState(() => _selectedCategoryId = cat.id);
    context.read<SubCategoryBloc>().add(LoadSubCategories(cat.id));
  }

  void _onChangeLocation() async {
    await Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const SearchAddressPage()));
    if (mounted) {
      // Refresh global providers
      ref.invalidate(serviceAvailabilityProvider);
      ref.invalidate(systemSettingsProvider);
      // Reload local service categories
      context.read<ServiceCategoryBloc>().add(LoadServiceCategories(isEmergency: widget.isEmergency));
    }
  }

  void _nextService({
    required int id,
    required String name,
    String? description,
    String? iconImageUrl,
    required List<RateCardModel> rateCards,
    double gstPercentage = 0,
  }) {
    if (context.read<AuthBloc>().state is AuthGuest) {
      LoginRequiredDialog.show(context);
      return;
    }

    if (widget.isEmergency) {
      final category = ServiceCategoryModel(
        id: id,
        categoryName: name,
        categorySlug: '',
        isActive: true,
        displayOrder: 0,
        fullCategoryName: name,
        description: description,
        iconImageUrl: iconImageUrl,
        rateCards: rateCards,
        gstPercentage: gstPercentage,
      );
      Navigator.of(context, rootNavigator: true).pushNamed(AppRoutes.emergencyConfirm, arguments: category);
      return;
    }
    String priceFrom = '';
    if (rateCards.isNotEmpty) {
      priceFrom = NumberUtils.formatCurrency(rateCards.first.basePrice, decimalDigits: 0);
    }
    final serviceType = ServiceType(
      id: id.toString(),
      name: name,
      description: description ?? name,
      icon: Icons.health_and_safety_rounded,
      color: kPrimaryColor,
      priceFrom: priceFrom,
      rateCard: rateCards.isNotEmpty ? rateCards.first : null,
      iconUrl: iconImageUrl,
      gstPercentage: gstPercentage,
    );

    // Check booking types from rate cards
    final bookingTypes = _getUniqueBookingTypes(rateCards);

    if (bookingTypes.length == 2) {
      // Show bottom sheet to select booking type
      _showBookingTypeSheet(serviceType, rateCards);
    } else if (bookingTypes.length == 1) {
      // Navigate directly to step3, setting booking type and service type
      final bookingType = bookingTypes.first;
      final mode = bookingType == 'long_duration' ? 'daily' : 'hourly';
      widget.request.resetModeSpecificFields();
      widget.onUpdate(widget.request.copyWith(serviceType: serviceType, bookingType: bookingType, mode: mode));
      Navigator.of(context).pushNamed(BookingRoutes.dateDuration);
    } else {
      // Fallback: navigate to step2
      // widget.onUpdate(widget.request.copyWith(serviceType: serviceType));
      // Navigator.of(context).pushNamed(BookingRoutes.selectMode);
    }
  }

  Set<String> _getUniqueBookingTypes(List<RateCardModel> rateCards) {
    return rateCards.map((rc) => rc.bookingType).toSet();
  }

  void _navigateToBookingFlow(ServiceType serviceType, List<RateCardModel> rateCards, {required String bookingType, required String mode}) {
    Navigator.pop(context);
    final matchedRateCard = rateCards.firstWhere((rc) => rc.bookingType == bookingType, orElse: () => rateCards.first);
    final updatedServiceType = ServiceType(
      id: serviceType.id,
      name: serviceType.name,
      description: serviceType.description,
      icon: serviceType.icon,
      color: serviceType.color,
      priceFrom: NumberUtils.formatCurrency(matchedRateCard.basePrice, decimalDigits: 0),
      iconUrl: serviceType.iconUrl,
      rateCard: matchedRateCard,
      gstPercentage: serviceType.gstPercentage,
      cityAdminId: serviceType.cityAdminId,
    );
    final request = BookingRequest()..serviceType = updatedServiceType;
    request.resetModeSpecificFields();
    request.bookingType = bookingType;
    request.mode = mode;
    widget.request.resetModeSpecificFields();
    widget.onUpdate(request);

    Navigator.of(context).pushNamed(BookingRoutes.dateDuration);
  }

  void _showBookingTypeSheet(ServiceType serviceType, List<RateCardModel> rateCards) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: kWhiteColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20.r), topRight: Radius.circular(20.r)),
      ),
      builder: (_) => BookingTypeBottomSheet(
        onOneDay: () => _navigateToBookingFlow(serviceType, rateCards, bookingType: 'procedural', mode: 'hourly'),
        onLongBooking: () => _navigateToBookingFlow(serviceType, rateCards, bookingType: 'long_duration', mode: 'daily'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to service availability changes
    ref.listen(serviceAvailabilityProvider, (previous, next) {
      if (next is! AsyncLoading) {
        context.read<ServiceCategoryBloc>().add(LoadServiceCategories(isEmergency: widget.isEmergency));
      }
    });

    // Also trigger initial load if already data/error is present (e.g. returning to this page)
    final availability = ref.read(serviceAvailabilityProvider);
    if (availability is! AsyncLoading && context.read<ServiceCategoryBloc>().state is ServiceCategoryInitial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ServiceCategoryBloc>().add(LoadServiceCategories(isEmergency: widget.isEmergency));
        }
      });
    }

    return BookingStepScaffold(
      title: 'Select Service',
      currentStep: 1,
      totalSteps: 4,
      onBack: () => Navigator.of(context, rootNavigator: true).pop(),
      body: BlocListener<ServiceCategoryBloc, ServiceCategoryState>(
        listener: (context, state) {
          // Auto-select first category if none selected
          if (state is ServiceCategoryLoaded && _selectedCategoryId == null && widget.initialMainCategory == null) {
            if (state.categories.isNotEmpty) {
              _onCategoryTap(state.categories.first);
            }
          }
        },
        child: BlocBuilder<ServiceCategoryBloc, ServiceCategoryState>(
          builder: (context, catState) {
            if (catState is ServiceCategoryLoading || catState is ServiceCategoryInitial) {
              return const _FullLoadingShimmer();
            }
            if (catState is ServiceCategoryError) {
              if (catState.message == 'city_admin_id_required') {
                final addr = ref.watch(selectedAddressProvider);
                return shared.NoServiceView(city: addr?.area ?? addr?.city, zipCode: addr?.pinCode, onChangeLocation: _onChangeLocation);
              }
              return CustomErrorView(
                title: 'Could not load services',
                message: catState.message,
                onRetry: () => context.read<ServiceCategoryBloc>().add(LoadServiceCategories(isEmergency: widget.isEmergency)),
              );
            }

            final categories = (catState as ServiceCategoryLoaded).categories;
            if (categories.isEmpty) {
              final addr = ref.watch(selectedAddressProvider);
              return shared.NoServiceView(city: addr?.area ?? addr?.city, zipCode: addr?.pinCode, onChangeLocation: _onChangeLocation);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: AppPadding.only(left: 20, right: 20, top: 20, bottom: 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What care do you need?', style: kHeadingSmall()),
                      AppSpacing.xsVertical,
                      Text('Trusted healthcare at your doorstep', style: kTextNormal(color: kTextSecondaryColor)),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context, rootNavigator: true).pushNamed(AppRoutes.searchService),
                    child: CommonSearchField(
                      ontap: () => Navigator.of(context, rootNavigator: true).pushNamed(AppRoutes.searchService),
                      readOnly: true,
                    ),
                  ),
                ),

                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Left Sidebar (Level 1 Categories) ---
                      _CategorySidebar(categories: categories, selectedId: _selectedCategoryId, onTap: _onCategoryTap),

                      // --- Right Content (Level 2+3 Services) ---
                      Expanded(
                        child: Container(
                          color: kGreyColor1.withValues(alpha: 0.3),
                          child: BlocBuilder<SubCategoryBloc, SubCategoryState>(
                            builder: (context, subState) {
                              if (subState is SubCategoryInitial) {
                                return _SelectCategoryPrompt();
                              }
                              if (subState is SubCategoryLoading) {
                                return const _ServiceListShimmer();
                              }
                              if (subState is SubCategoryError) {
                                return CustomErrorView(
                                  title: 'Could not load services',
                                  message: subState.message,
                                  onRetry: () {
                                    if (_selectedCategoryId != null) {
                                      context.read<SubCategoryBloc>().add(LoadSubCategories(_selectedCategoryId!));
                                    }
                                  },
                                );
                              }
                              if (subState is SubCategoryLoaded) {
                                if (subState.items.isEmpty) {
                                  final addr = ref.watch(selectedAddressProvider);
                                  return shared.NoServiceView(
                                    city: addr?.area ?? addr?.city,
                                    zipCode: addr?.pinCode,
                                    onChangeLocation: _onChangeLocation,
                                  );
                                }

                                // Filter results if search query is present
                                var displayItems = subState.items;
                                if (_searchQuery.isNotEmpty) {
                                  displayItems = subState.items.where((item) {
                                    final matchesName = item.name.toLowerCase().contains(_searchQuery);
                                    final matchesServices = item.services.any((s) => s.name.toLowerCase().contains(_searchQuery));
                                    return matchesName || matchesServices;
                                  }).toList();
                                }

                                if (displayItems.isEmpty && _searchQuery.isNotEmpty) {
                                  return _NoSearchResultsView(query: _searchQuery);
                                }

                                return _SubCategoryList(items: displayItems, onServiceTap: _nextService, searchQuery: _searchQuery);
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Level-1 Category Vertical Sidebar
// ─────────────────────────────────────────────────────────
class _CategorySidebar extends StatelessWidget {
  final List<ServiceCategoryModel> categories;
  final int? selectedId;
  final ValueChanged<ServiceCategoryModel> onTap;

  const _CategorySidebar({required this.categories, required this.selectedId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 105.w,
      decoration: BoxDecoration(
        color: kWhiteColor,
        border: Border(right: BorderSide(color: kDividerColor, width: 1)),
      ),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final cat = categories[i];
          final selected = selectedId == cat.id;

          return GestureDetector(
            onTap: () => onTap(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              constraints: BoxConstraints(minHeight: 90.h),
              decoration: BoxDecoration(
                color: selected ? kPrimaryColor.withValues(alpha: 0.08) : Colors.transparent,
                border: Border(
                  right: BorderSide(color: selected ? kPrimaryColor : Colors.transparent, width: 3.w),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 12.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 50.w,
                      height: 50.w,
                      decoration: BoxDecoration(
                        color: selected ? kAccentColor.withValues(alpha: 0.25) : kAccentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: cat.iconImageUrl != null
                            ? AppCachedImage(
                                imageUrl: cat.iconImageUrl,
                                fit: BoxFit.cover,
                                errorWidgetBuilder: Icon(Icons.medical_services_rounded, size: 20.sp, color: selected ? kWhiteColor : kTextHintColor),
                              )
                            : Icon(Icons.medical_services_rounded, size: 20.sp, color: selected ? kWhiteColor : kTextHintColor),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      cat.categoryName,
                      textAlign: TextAlign.center,
                      style: (selected ? kTextBold() : kTextMedium()).copyWith(
                        fontSize: 10.5.sp,
                        color: selected ? kPrimaryColor : kTextSecondaryColor,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Level-2+3 Subcategory List
// ─────────────────────────────────────────────────────────
typedef _OnServiceTap =
    void Function({
      required int id,
      required String name,
      String? description,
      String? iconImageUrl,
      required List<RateCardModel> rateCards,
      double gstPercentage,
    });

class _SubCategoryList extends StatelessWidget {
  final List<SubCategoryDataModel> items;
  final _OnServiceTap onServiceTap;
  final String searchQuery;

  const _SubCategoryList({required this.items, required this.onServiceTap, this.searchQuery = ''});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: AppPadding.only(top: 12, bottom: 24),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final sub = items[i];

        // Auto-expand if searching and matches sub-items
        final bool shouldExpand = searchQuery.isNotEmpty && sub.services.any((s) => s.name.toLowerCase().contains(searchQuery));

        if (sub.hasServices) {
          return _SubCategoryAccordion(sub: sub, onServiceTap: onServiceTap, initiallyExpanded: shouldExpand);
        }
        return Padding(
          padding: AppPadding.only(left: 16, right: 16, bottom: 12),
          child: _DirectServiceCard(
            sub: sub,
            onTap: () => onServiceTap(
              id: sub.id,
              name: sub.name,
              description: sub.description,
              iconImageUrl: sub.iconImageUrl,
              rateCards: sub.rateCards,
              gstPercentage: sub.gstPercentage,
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Level-2 Accordion (subcategory with children)
// ─────────────────────────────────────────────────────────
class _SubCategoryAccordion extends StatefulWidget {
  final SubCategoryDataModel sub;
  final _OnServiceTap onServiceTap;
  final bool initiallyExpanded;

  const _SubCategoryAccordion({required this.sub, required this.onServiceTap, this.initiallyExpanded = false});

  @override
  State<_SubCategoryAccordion> createState() => _SubCategoryAccordionState();
}

class _SubCategoryAccordionState extends State<_SubCategoryAccordion> with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _ctrl;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250), value: _expanded ? 1.0 : 0.0);
    _heightFactor = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(_SubCategoryAccordion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded != oldWidget.initiallyExpanded) {
      if (widget.initiallyExpanded && !_expanded) {
        _toggle();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.sub;
    return Padding(
      padding: AppPadding.only(left: 14, right: 14, bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
          border: Border.all(
            color: _expanded ? kPrimaryColor.withValues(alpha: 0.4) : kBorderColor.withValues(alpha: 0.8),
            width: _expanded ? 1.2 : 1,
          ),
        ),
        child: Column(
          children: [
            // Header
            InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(16.r),
              child: Padding(
                padding: EdgeInsets.all(14.w),
                child: Row(
                  children: [
                    Container(
                      width: 42.w,
                      height: 42.w,
                      decoration: BoxDecoration(color: kAccentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12.r)),
                      child: sub.iconImageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12.r),
                              child: AppCachedImage(
                                imageUrl: sub.iconImageUrl,
                                fit: BoxFit.cover,
                                errorWidgetBuilder: Icon(Icons.medical_services_outlined, color: kPrimaryColor, size: 20.sp),
                              ),
                            )
                          : Icon(Icons.medical_services_outlined, color: kPrimaryColor, size: 20.sp),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub.name,
                            style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 15.sp),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            '${sub.services.length} ${sub.services.length == 1 ? 'service' : 'services'} available',
                            style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                          ),
                        ],
                      ),
                    ),
                    Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: kPrimaryColor, size: 24.sp),
                  ],
                ),
              ),
            ),
            // Expandable service items
            ClipRect(
              child: AnimatedBuilder(
                animation: _heightFactor,
                builder: (context, child) => Align(alignment: Alignment.topCenter, heightFactor: _heightFactor.value, child: child),
                child: Column(
                  children: [
                    Container(height: 1, color: kDividerColor),
                    ...sub.services.map(
                      (svc) => _ServiceItemCard(
                        service: svc,
                        onTap: () => widget.onServiceTap(
                          id: svc.id,
                          name: svc.name,
                          description: svc.description,
                          iconImageUrl: svc.iconImageUrl,
                          rateCards: svc.rateCards,
                          gstPercentage: svc.gstPercentage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Level-3 Service Item Card (inside accordion)
// ─────────────────────────────────────────────────────────
class _ServiceItemCard extends StatelessWidget {
  final ServiceItemModel service;
  final VoidCallback onTap;

  const _ServiceItemCard({required this.service, required this.onTap});

  String _priceText() {
    final rc = service.rateCards;
    if (rc.isEmpty) return '';

    double? minPrice;

    for (final card in rc) {
      if (card.basePrice > 0) {
        final price = card.basePrice + card.pricePerHour;
        if (minPrice == null || price < minPrice) minPrice = price;
      } else if (card.pricePerHour > 0) {
        if (minPrice == null || card.pricePerHour < minPrice) minPrice = card.pricePerHour;
      }
      if (card.pricePerDay > 0 && (minPrice == null || card.pricePerDay < minPrice)) minPrice = card.pricePerDay;
      if (card.pricePerNight > 0 && (minPrice == null || card.pricePerNight < minPrice)) minPrice = card.pricePerNight;
      if (card.pricePerFullDay > 0 && (minPrice == null || card.pricePerFullDay < minPrice)) minPrice = card.pricePerFullDay;
      for (final pkg in card.packages) {
        if (pkg.price > 0 && (minPrice == null || pkg.price < minPrice)) minPrice = pkg.price;
      }
    }

    return (minPrice != null && minPrice > 0)
        ? NumberUtils.formatCurrency(minPrice, decimalDigits: 0)
        : '';
  }

  String _cleanDescription(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final desc = _cleanDescription(service.description);
    final price = _priceText();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(color: kAccentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10.r)),
              child: service.iconImageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: AppCachedImage(
                        imageUrl: service.iconImageUrl,
                        fit: BoxFit.cover,
                        errorWidgetBuilder: Icon(Icons.health_and_safety_outlined, color: kPrimaryColor, size: 18.sp),
                      ),
                    )
                  : Icon(Icons.health_and_safety_outlined, color: kPrimaryColor, size: 18.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ServiceTitle(
                    rawName: service.name,
                    style: kTextSemiBold1(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
                  ),
                  if (desc.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      desc,
                      style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 11.5.sp),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (price.isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    _PriceTag(price: price),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Icon(Icons.arrow_forward_ios_rounded, size: 14.sp, color: kPrimaryColor.withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Direct Service Card (Level-2 item with no children)
// ─────────────────────────────────────────────────────────
class _DirectServiceCard extends StatelessWidget {
  final SubCategoryDataModel sub;
  final VoidCallback onTap;

  const _DirectServiceCard({required this.sub, required this.onTap});

  String _priceText() {
    final rc = sub.rateCards;
    if (rc.isEmpty) return '';

    double? minPrice;

    for (final card in rc) {
      // 1. Procedural/Base price + hour price
      if (card.basePrice > 0) {
        final price = card.basePrice + card.pricePerHour;
        if (minPrice == null || price < minPrice) {
          minPrice = price;
        }
      } else {
        if (card.pricePerHour > 0) {
          if (minPrice == null || card.pricePerHour < minPrice) {
            minPrice = card.pricePerHour;
          }
        }
      }

      // 2. pricePerDay
      if (card.pricePerDay > 0) {
        if (minPrice == null || card.pricePerDay < minPrice) {
          minPrice = card.pricePerDay;
        }
      }

      // 3. pricePerNight
      if (card.pricePerNight > 0) {
        if (minPrice == null || card.pricePerNight < minPrice) {
          minPrice = card.pricePerNight;
        }
      }

      // 4. pricePerFullDay
      if (card.pricePerFullDay > 0) {
        if (minPrice == null || card.pricePerFullDay < minPrice) {
          minPrice = card.pricePerFullDay;
        }
      }

      // 5. Packages
      if (card.packages.isNotEmpty) {
        for (final pkg in card.packages) {
          if (pkg.price > 0) {
            if (minPrice == null || pkg.price < minPrice) {
              minPrice = pkg.price;
            }
          }
        }
      }
    }

    if (minPrice != null && minPrice > 0) {
      return NumberUtils.formatCurrency(minPrice, decimalDigits: 0);
    }

    return '';
  }

  String _cleanDescription(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final desc = _cleanDescription(sub.description);
    final price = _priceText();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: kBorderColor.withValues(alpha: 0.8)),
        ),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Row(
            children: [
              Container(
                width: 50.w,
                height: 50.w,
                decoration: BoxDecoration(color: kAccentColor.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12.r)),
                child: sub.iconImageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: AppCachedImage(
                          imageUrl: sub.iconImageUrl,
                          fit: BoxFit.cover,
                          errorWidgetBuilder: Icon(Icons.health_and_safety_rounded, color: kPrimaryColor, size: 24.sp),
                        ),
                      )
                    : Icon(Icons.health_and_safety_rounded, color: kPrimaryColor, size: 24.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ServiceTitle(
                      rawName: sub.name,
                      style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 15.sp),
                    ),
                    if (desc.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        desc,
                        style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 11.5.sp),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (price.isNotEmpty) ...[
                      SizedBox(height: 8.h),
                      _PriceTag(price: price),
                    ],
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14.sp, color: kPrimaryColor.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Select Category Prompt
// ─────────────────────────────────────────────────────────
class _SelectCategoryPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_rounded, size: 52.sp, color: kPrimaryColor.withValues(alpha: 0.3)),
          AppSpacing.mVertical,
          Text('Select a category above', style: kTextSemiBold2(color: kTextSecondaryColor)),
          AppSpacing.xsVertical,
          Text('Services will appear here', style: kTextNormal(color: kTextHintColor)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Modern Search Bar Widget
// ─────────────────────────────────────────────────────────
// class _SearchBar extends StatelessWidget {
//   final TextEditingController controller;
//   final FocusNode focusNode;
//   final VoidCallback onClear;
//
//   const _SearchBar({required this.controller, required this.focusNode, required this.onClear});
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
//       child: Container(
//         decoration: BoxDecoration(
//           color: kWhiteColor,
//           borderRadius: BorderRadius.circular(12.r),
//           boxShadow: [
//             BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
//           ],
//         ),
//         child: TextField(
//           controller: controller,
//           focusNode: focusNode,
//           style: kTextMedium().copyWith(fontSize: 14.sp),
//           decoration: InputDecoration(
//             hintText: 'Search for services...',
//             hintStyle: kTextNormal(color: kTextHintColor).copyWith(fontSize: 14.sp),
//             prefixIcon: Icon(Icons.search_rounded, color: kPrimaryColor, size: 20.sp),
//             suffixIcon: controller.text.isNotEmpty
//                 ? IconButton(
//                     icon: Icon(Icons.close_rounded, color: kTextHintColor, size: 20.sp),
//                     onPressed: onClear,
//                   )
//                 : null,
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12.r),
//               borderSide: BorderSide(color: kBorderColor.withValues(alpha: 0.5)),
//             ),
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12.r),
//               borderSide: BorderSide(color: kBorderColor.withValues(alpha: 0.5)),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12.r),
//               borderSide: BorderSide(color: kPrimaryColor.withValues(alpha: 0.5)),
//             ),
//             contentPadding: EdgeInsets.symmetric(vertical: 12.h),
//           ),
//         ),
//       ),
//     );
//   }
// }

// ─────────────────────────────────────────────────────────
//  No Search Results View
// ─────────────────────────────────────────────────────────
class _NoSearchResultsView extends StatelessWidget {
  final String query;

  const _NoSearchResultsView({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48.sp, color: kTextHintColor.withValues(alpha: 0.5)),
            SizedBox(height: 16.h),
            Text(
              'No results for "$query"',
              style: kTextSemiBold2(color: kTextSecondaryColor),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              'Try searching for something else within this category.',
              style: kTextNormal0(color: kTextHintColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Price Tag — clean single-line "From ₹799" (or login prompt)
// ─────────────────────────────────────────────────────────
class _PriceTag extends StatelessWidget {
  final String price;

  const _PriceTag({required this.price});

  @override
  Widget build(BuildContext context) {
    if (context.read<AuthBloc>().state is AuthGuest) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 12.sp, color: kTextHintColor),
          SizedBox(width: 4.w),
          Flexible(
            child: Text(
              'Login to view price',
              style: kTextSemiBold(color: kTextHintColor).copyWith(fontSize: 11.sp),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(' Starting from ', style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 11.sp)),
        Flexible(
          child: Text(
            price,
            style: kTextBold(color: kPrimaryColor).copyWith(fontSize: 15.sp),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Service Title — splits "Name (VARIANT)" into title + chip
// ─────────────────────────────────────────────────────────
({String base, List<String> variants}) _splitServiceName(String raw) {
  final name = raw.trim();
  final variants = <String>[];
  for (final m in RegExp(r'\(([^)]+)\)').allMatches(name)) {
    final v = m.group(1)!.trim();
    if (v.isNotEmpty) variants.add(v);
  }
  final base = name.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
  return (base: base.isEmpty ? name : base, variants: variants);
}

class _ServiceTitle extends StatelessWidget {
  final String rawName;
  final TextStyle style;

  const _ServiceTitle({required this.rawName, required this.style});

  @override
  Widget build(BuildContext context) {
    final parsed = _splitServiceName(rawName);
    final title = Text(parsed.base, style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
    if (parsed.variants.isEmpty) return title;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          SizedBox(height: 5.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 4.h,
            children: parsed.variants.map((v) => _VariantChip(label: v, maxWidth: constraints.maxWidth)).toList(),
          ),
        ],
      ),
    );
  }
}

class _VariantChip extends StatelessWidget {
  final String label;
  final double maxWidth;

  const _VariantChip({required this.label, required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final upper = label.toUpperCase();
    final isFemale = upper.contains('FEMALE');
    final isMale = !isFemale && upper.contains('MALE');
    final IconData? genderIcon = isFemale
        ? Icons.female_rounded
        : isMale
        ? Icons.male_rounded
        : null;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: kSecondaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(color: kSecondaryColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (genderIcon != null) ...[
              Icon(genderIcon, size: 11.sp, color: kSecondaryColor),
              SizedBox(width: 3.w),
            ],
            Flexible(
              child: Text(
                upper,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kTextBold(color: kSecondaryColor).copyWith(fontSize: 9.sp, letterSpacing: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Loading Shimmers
// ─────────────────────────────────────────────────────────
class _FullLoadingShimmer extends StatelessWidget {
  const _FullLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: AppPadding.only(left: 20, right: 20, top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 220.w, height: 24.h),
              SizedBox(height: 10.h),
              ShimmerBox(width: 160.w, height: 14.h),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: ShimmerBox(height: 52.h, borderRadius: 14),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SidebarShimmer(),
              Expanded(
                child: Container(
                  color: kGreyColor1.withValues(alpha: 0.3),
                  child: const _ServiceListShimmer(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarShimmer extends StatelessWidget {
  const _SidebarShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 105.w,
      decoration: BoxDecoration(
        color: kWhiteColor,
        border: Border(right: BorderSide(color: kDividerColor, width: 1)),
      ),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        itemCount: 6,
        itemBuilder: (_, _) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 12.h),
          child: Column(
            children: [
              ShimmerBox(width: 50.w, height: 50.w, borderRadius: 12),
              SizedBox(height: 8.h),
              ShimmerBox(width: 60.w, height: 10.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceListShimmer extends StatelessWidget {
  const _ServiceListShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: AppPadding.only(left: 14, right: 14, top: 12, bottom: 24),
      itemCount: 5,
      itemBuilder: (_, _) => Container(
        margin: EdgeInsets.only(bottom: 14.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: kBorderColor.withValues(alpha: 0.8)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(width: 50.w, height: 50.w, borderRadius: 12),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 160.w, height: 14.h),
                  SizedBox(height: 8.h),
                  ShimmerBox(height: 10.h),
                  SizedBox(height: 6.h),
                  ShimmerBox(width: 120.w, height: 10.h),
                  SizedBox(height: 10.h),
                  ShimmerBox(width: 90.w, height: 28.h, borderRadius: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
