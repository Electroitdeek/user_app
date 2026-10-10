import 'dart:async';

import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/storage/local_storage_service.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/data/providers/service_availability_provider.dart';
import 'package:adhisaat_health_care/data/providers/system_settings_provider.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/auth/login/bloc/auth_bloc.dart';
import 'package:adhisaat_health_care/features/user/address/bloc/selected_address_provider.dart';
import 'package:adhisaat_health_care/features/user/home/view/search_address_page.dart';
import 'package:adhisaat_health_care/features/user/service_booking/data/service_category_repository.dart';
import 'package:adhisaat_health_care/features/user/service_booking/model/booking_model.dart';
import 'package:adhisaat_health_care/features/user/service_booking/model/procedure_model.dart';
import 'package:adhisaat_health_care/features/user/service_booking/model/service_category_model.dart';
import 'package:adhisaat_health_care/features/user/service_booking/view/service_booking_flow.dart';
import 'package:adhisaat_health_care/features/user/service_booking/view/widgets/booking_type_bottom_sheet.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_cached_image.dart';
import 'package:adhisaat_health_care/shared/widgets/common/no_service_view.dart' as shared;
import 'package:adhisaat_health_care/shared/widgets/inputs/common_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/navigation/app_routes.dart';

class SearchServicePage extends ConsumerStatefulWidget {
  const SearchServicePage({super.key});

  @override
  ConsumerState<SearchServicePage> createState() => _SearchServicePageState();
}

class _SearchServicePageState extends ConsumerState<SearchServicePage> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounce;
  bool _isLoading = false;
  List<ProcedureModel> _results = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.length >= 2) {
        _performSearch(query);
      } else {
        setState(() {
          _results = [];
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final results = await locator<ServiceCategoryRepository>().getProcedures(search: query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onProcedureSelected(ProcedureModel procedure) {
    if (context.read<AuthBloc>().state is AuthGuest) {
      AppNavigator.to(AppRoutes.login);
      return;
    }

    if (procedure.isEmergency) {
      Navigator.of(context).pushNamed(AppRoutes.emergency);
      return;
    }

    final rateCards = procedure.rateCards;
    if (rateCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This service is currently unavailable in your area.')));
      return;
    }

    String priceFrom = NumberUtils.formatCurrency(rateCards.first.basePrice, decimalDigits: 0);

    final serviceType = ServiceType(
      id: procedure.id.toString(),
      name: procedure.name,
      description: procedure.description ?? procedure.name,
      icon: Icons.health_and_safety_rounded,
      color: kPrimaryColor,
      priceFrom: priceFrom,
      rateCard: rateCards.isNotEmpty ? rateCards.first : null,
      iconUrl: procedure.iconImageUrl,
      gstPercentage: procedure.gstPercentage,
    );

    final bookingRequest = BookingRequest()..serviceType = serviceType;

    final bookingTypes = rateCards.map((rc) => rc.bookingType).toSet();
    if (bookingTypes.length == 1) {
      final bookingType = bookingTypes.first;
      bookingRequest.bookingType = bookingType;
      bookingRequest.mode = bookingType == 'long_duration' ? 'daily' : 'hourly';

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ServiceBookingFlow(initialRequest: bookingRequest, initialRoute: BookingRoutes.dateDuration),
        ),
      );
    } else if (bookingTypes.length > 1) {
      _showBookingTypeSheet(serviceType, rateCards);
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ServiceBookingFlow(initialRequest: bookingRequest)));
    }
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServiceBookingFlow(initialRequest: request, initialRoute: BookingRoutes.dateDuration),
      ),
    );
  }

  void _showBookingTypeSheet(ServiceType serviceType, List<RateCardModel> rateCards) {
    showModalBottomSheet(
      context: context,
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

  void _onChangeLocation() async {
    await Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const SearchAddressPage()));
    if (mounted) {
      // Refresh global providers to get latest city admin info and settings
      ref.invalidate(systemSettingsProvider);
      ref.invalidate(serviceAvailabilityProvider);

      setState(() {
        _results = [];
        _searchController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cityAdminId = locator<LocalStorageService>().cityAdminId;

    if (cityAdminId == null) {
      final addr = ref.watch(selectedAddressProvider);
      return Scaffold(
        backgroundColor: kWhiteColor,
        appBar: AppBar(
          backgroundColor: kWhiteColor,
          elevation: 0,
          forceMaterialTransparency: true,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: kTextPrimaryColor, size: 20.sp),
          ),
          title: Text('Search Service', style: kTextBold().copyWith(fontSize: 18.sp)),
          centerTitle: true,
        ),
        body: shared.NoServiceView(city: addr?.area ?? addr?.city, zipCode: addr?.pinCode, onChangeLocation: _onChangeLocation),
      );
    }

    return Scaffold(
      backgroundColor: kWhiteColor,
      appBar: AppBar(
        backgroundColor: kWhiteColor,
        elevation: 0,
        forceMaterialTransparency: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: kTextPrimaryColor, size: 20.sp),
        ),
        title: Text('Search Service', style: kTextBold().copyWith(fontSize: 18.sp)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 16.h),
              child: CommonSearchField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                hintText: 'Search for services...',
                onChanged: _onSearchChanged,
                onClear: () {
                  _searchController.clear();
                  setState(() => _results = []);
                },
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty && _searchController.text.length >= 2
                  ? _buildEmptyState()
                  : _buildResultsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 32.h),
      itemCount: _results.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: kGreyColor1),
      itemBuilder: (context, index) {
        final procedure = _results[index];
        return ListTile(
          onTap: () => _onProcedureSelected(procedure),
          contentPadding: EdgeInsets.symmetric(vertical: 8.h),
          leading: Container(
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(color: kAccentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12.r)),
            child: procedure.iconImageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: AppCachedImage(
                      imageUrl: procedure.iconImageUrl!,
                      fit: BoxFit.cover,
                      errorWidgetBuilder: Icon(Icons.medical_services_outlined, color: kPrimaryColor, size: 24.sp),
                    ),
                  )
                : Icon(Icons.medical_services_outlined, color: kPrimaryColor, size: 24.sp),
          ),
          title: Text(
            procedure.name,
            style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 15.sp),
          ),
          subtitle: Text(
            procedure.categoryName ?? 'Healthcare Service',
            style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: kGreyColor4, size: 24.sp),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64.sp, color: kGreyColor4),
          SizedBox(height: 16.h),
          Text(
            'No services found',
            style: kTextSemiBold(color: kTextSecondaryColor).copyWith(fontSize: 16.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            'Try searching for something else',
            style: kTextNormal(color: kTextHintColor).copyWith(fontSize: 14.sp),
          ),
        ],
      ),
    );
  }
}
