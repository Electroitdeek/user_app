import 'dart:ui';

import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/theme/screen_dimensions.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/user/address/bloc/selected_address_provider.dart';
import 'package:adhisaat_health_care/features/user/address/model/user_address_model.dart';
import 'package:adhisaat_health_care/features/user/address/view/address_selection_bottom_sheet.dart';
import 'package:adhisaat_health_care/features/user/family/bloc/family_bloc.dart';
import 'package:adhisaat_health_care/features/user/family/bloc/family_event.dart';
import 'package:adhisaat_health_care/features/user/family/bloc/family_state.dart';
import 'package:adhisaat_health_care/features/user/family/data/family_repository.dart';
import 'package:adhisaat_health_care/features/user/family/model/family_member_model.dart';
import 'package:adhisaat_health_care/features/user/service_booking/model/service_category_model.dart';
import 'package:adhisaat_health_care/features/user/service_booking/view/widgets/service_description_sheet.dart';
import 'package:adhisaat_health_care/shared/widgets/buttons/custom_button.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/utils/number_utils.dart';
import '../../../../data/providers/system_settings_provider.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../service_booking/bloc/service_request_bloc.dart';

class EmergencyBookingPreConfirmationPage extends HookConsumerWidget {
  final ServiceCategoryModel category;

  const EmergencyBookingPreConfirmationPage({super.key, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instructionsCtrl = useTextEditingController();
    final selectedFamily = useState<FamilyMemberModel?>(null);
    final isNavigating = useState(false);
    final selectedAddress = ref.watch(selectedAddressProvider);
    final freeDistance = ref.watch(freeServiceDistanceProvider);
    final rateCard = category.rateCards.isNotEmpty ? category.rateCards.first : null;
    final pricePerKm = rateCard?.pricePerKm ?? 0.0;

    ref.listen<UserAddressModel?>(selectedAddressProvider, (prev, next) {
      if (context.mounted &&
          next != null &&
          next.pinCode != null &&
          next.pinCode!.isNotEmpty &&
          (next.pinCode != prev?.pinCode || next.id != prev?.id)) {
        _checkServiceAvailability(next);
      }
    });

    // Setup animation for the locating overlay
    final pulseCtrl = useAnimationController(duration: const Duration(seconds: 1));

    useEffect(() {
      if (isNavigating.value) {
        pulseCtrl.repeat(reverse: true);
      } else {
        pulseCtrl.stop();
      }
      return null;
    }, [isNavigating.value]);

    return MultiBlocProvider(
      providers: [BlocProvider(create: (_) => FamilyBloc(locator<FamilyRepository>())..add(LoadFamilyMembers()))],
      child: Builder(
        builder: (context) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.userDashboard, (r) => false);
          },
          child: Stack(
            children: [
              Scaffold(
                backgroundColor: kScaffoldColor,
                appBar: const CustomAppBar(title: 'Confirm Details', backgroundColor: kScaffoldColor),
                body: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: AppPadding.symmetric(h: 16, v: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Service Header ---
                        _ServiceSummaryCard(category: category),
                        AppSpacing.xlVertical,

                        // --- Address Section ---
                        _SectionHeader(title: 'Emergency Location', icon: Icons.location_on_rounded, color: kPrimaryColor),
                        AppSpacing.xsVertical,
                        _AddressSelectorCard(
                          selectedAddress: selectedAddress?.id != null ? selectedAddress : null,
                          hasTempAddress: selectedAddress != null && selectedAddress.id == null,
                          onTap: () => AddressSelectionBottomSheet.show(context, parentRoute: AppRoutes.emergencyConfirm),
                        ),
                        AppSpacing.xlVertical,

                        // --- Patient Section ---
                        _SectionHeader(
                          title: 'Who needs help?',
                          icon: Icons.person_rounded,
                          color: kPrimaryColor,
                          trailing: GestureDetector(
                            onTap: () async {
                              await AppNavigator.to(AppRoutes.familyAddEdit);
                              if (context.mounted) {
                                context.read<FamilyBloc>().add(LoadFamilyMembers());
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                              decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20.r)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_circle_outline_rounded, size: 14.sp, color: kPrimaryColor),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'Add New',
                                    style: kTextSemiBold(color: kPrimaryColor).copyWith(fontSize: 11.sp),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        AppSpacing.xsVertical,
                        BlocBuilder<FamilyBloc, FamilyState>(
                          builder: (context, state) {
                            final members = state is FamilyLoaded ? state.members : <FamilyMemberModel>[];
                            return _PatientSelectorCard(
                              selected: selectedFamily.value,
                              members: members,
                              onChanged: (m) => selectedFamily.value = m,
                              isLoading: state is! FamilyLoaded,
                            );
                          },
                        ),
                        AppSpacing.xlVertical,

                        // --- Instructions Section ---
                        _SectionHeader(title: 'Additional Details', icon: Icons.description_rounded, color: kPrimaryColor),
                        AppSpacing.xsVertical,
                        _StyledInstructionsField(controller: instructionsCtrl),
                        AppSpacing.xlVertical,

                        // --- Price Summary Section ---
                        _SectionHeader(
                          title: 'Price Summary',
                          icon: Icons.receipt_long_rounded,
                          color: kPrimaryColor,

                          trailing: pricePerKm > 0
                              ? GestureDetector(
                                  onTap: () => _showPricingPolicySheet(context, freeDistance, pricePerKm),
                                  child: Icon(Icons.info_outline_rounded, size: 20.sp, color: kPrimaryColor),
                                )
                              : null,
                        ),
                        AppSpacing.xsVertical,
                        _PriceSummaryCard(category: category),
                        SizedBox(height: 40.h),

                        // --- Action Button ---
                        CustomButton(
                          title: 'Locate Nearest Partner',
                          height: 52.h,
                          width: double.infinity,
                          backgroundColor: kErrorColor,
                          iconData: Icons.emergency_rounded,
                          borderRadius: BorderRadius.circular(16.r),
                          onPressed: () async {
                            if (selectedAddress == null || selectedAddress.id == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a saved address first')));
                              AddressSelectionBottomSheet.show(context, parentRoute: AppRoutes.emergencyConfirm);
                              return;
                            }

                            isNavigating.value = true;
                            await Future.delayed(const Duration(milliseconds: 1800));

                            if (context.mounted) {
                              isNavigating.value = false;
                              Navigator.of(context).pushNamed(
                                AppRoutes.emergencyMap,
                                arguments: {
                                  'category': category,
                                  'instructions': instructionsCtrl.text.trim(),
                                  'familyMemberId': selectedFamily.value?.id,
                                  'familyMemberName': selectedFamily.value?.fullName,
                                  'addressId': selectedAddress.id,
                                  'latitude': selectedAddress.latitude,
                                  'longitude': selectedAddress.longitude,
                                },
                              );
                            }
                          },
                        ),
                        SizedBox(height: 30.h),
                      ],
                    ),
                  ),
                ),
              ),
              if (isNavigating.value) _ModernLocatingOverlay(pulseCtrl: pulseCtrl),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _ServiceSummaryCard extends StatelessWidget {
  final ServiceCategoryModel category;
  const _ServiceSummaryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final hasDescription = (category.description??'').isNotEmpty;
    return GestureDetector(
      onTap: hasDescription
          ? () => showServiceDescriptionSheet(
        context,
        name: category.categoryName,
        iconUrl: category.iconImageUrl,
        fallbackIcon:  Icons.emergency_rounded,
        htmlDescription: category.description,
      )
          : null,
      child: Container(
        padding: AppPadding.l,
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 4))],
          border: Border.all(color: kErrorColor.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 54.w,
              height: 54.w,
              decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14.r)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14.r),
                child: category.iconImageUrl != null
                    ? AppCachedImage(imageUrl: category.iconImageUrl!, fit: BoxFit.cover)
                    : const Icon(Icons.emergency_rounded, color: kErrorColor, size: 28),
              ),
            ),
            AppSpacing.lHorizontal,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.categoryName,
                    style: kTextBold2(color: kTextPrimaryColor).copyWith(fontSize: 16.sp),
                  ),
                  if (category.description?.isNotEmpty == true) ...[
                    SizedBox(height: 3.h),
                    Text(
                      _cleanDescription(category.description),
                      style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 11.5.sp),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Text(
                          'View details',
                          style: kTextSemiBold0(color: kPrimaryColor).copyWith(fontSize: 11.sp),
                        ),
                        Icon(Icons.chevron_right_rounded, color: kPrimaryColor, size: 14.sp),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget? trailing;

  const _SectionHeader({required this.title, required this.icon, required this.color, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18.sp, color: color),
        SizedBox(width: 8.w),
        Text(title, style: kTextSemiBold(color: kTextPrimaryColor)),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

Future<void> _checkServiceAvailability(UserAddressModel address) async {
  final pinCode = address.pinCode;
  if (pinCode == null || pinCode.isEmpty) return;

  final storage = locator<LocalStorageService>();
  final oldCityAdminId = storage.cityAdminId;

  try {
    final result = await locator<AuthRepository>().checkServiceAvailability(pinCode);
    final newCityAdminId = result.data?.cityAdmin?.id;

    if (oldCityAdminId != newCityAdminId) {
      // Exit entire booking flow via root navigator, then refresh home dashboard.
      // MessageService.showError('Service not available at this address. Redirecting to home.');
      // Exit entire booking flow via root navigator, then refresh home dashboard.
      AppNavigator.navigatorKey.currentState?.popUntil((route) => route.isFirst);
      final rootCtx = AppNavigator.navigatorKey.currentState?.overlay?.context;
      if (rootCtx != null) {
        if (!rootCtx.mounted) return;
        try {
          rootCtx.read<ServiceRequestBloc>().add(const LoadServiceRequests());
        } catch (_) {}
      }
    }
  } catch (_) {
    // Silently ignore — don't block the flow on availability check failure.
  }
}

class _AddressSelectorCard extends StatelessWidget {
  final UserAddressModel? selectedAddress;
  final bool hasTempAddress;
  final VoidCallback onTap;

  const _AddressSelectorCard({required this.selectedAddress, required this.hasTempAddress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool hasSaved = selectedAddress != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: AppPadding.l,
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: hasSaved ? kPrimaryColor.withValues(alpha: 0.3) : kBorderColor, width: hasSaved ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(color: (hasSaved ? kPrimaryColor : kGreyColor).withValues(alpha: 0.08), shape: BoxShape.circle),
              child: Icon(
                hasSaved ? Icons.home_rounded : Icons.add_location_alt_rounded,
                color: hasSaved ? kPrimaryColor : kTextHintColor,
                size: 20.sp,
              ),
            ),
            AppSpacing.lHorizontal,
            Expanded(
              child: hasSaved
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(selectedAddress!.shortLabel, style: kTextBold(color: kTextPrimaryColor)),
                        Text(
                          selectedAddress!.fullAddress,
                          style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    )
                  : Text(hasTempAddress ? 'Incomplete saved address' : 'Select Emergency Location', style: kTextSemiBold(color: kTextHintColor)),
            ),
            Icon(Icons.keyboard_arrow_right_rounded, color: kTextHintColor, size: 22.sp),
          ],
        ),
      ),
    );
  }
}

class _PatientSelectorCard extends StatelessWidget {
  final FamilyMemberModel? selected;
  final List<FamilyMemberModel> members;
  final ValueChanged<FamilyMemberModel?> onChanged;
  final bool isLoading;

  const _PatientSelectorCard({required this.selected, required this.members, required this.onChanged, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : () => _showPatientSheet(context),
      child: Container(
        padding: AppPadding.l,
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: kBorderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: Icon(selected == null ? Icons.person_rounded : Icons.group_rounded, color: kPrimaryColor, size: 20.sp),
            ),
            AppSpacing.lHorizontal,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(selected == null ? 'Myself' : selected!.fullName, style: kTextBold(color: kTextPrimaryColor)),
                  Text(
                    selected == null ? 'Emergency for self' : 'Patient: ${selected!.fullName}',
                    style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                  ),
                ],
              ),
            ),
            if (isLoading)
              SizedBox(
                width: 20.w,
                height: 20.w,
                child: const CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor),
              )
            else
              Icon(Icons.keyboard_arrow_down_rounded, color: kTextHintColor, size: 22.sp),
          ],
        ),
      ),
    );
  }

  void _showPatientSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: kWhiteColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(10)),
              ),
              AppSpacing.lVertical,
              Text('Select Patient', style: kTextBold2()),
              AppSpacing.mVertical,
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _PatientListTile(
                      title: 'Myself',
                      subtitle: 'For personal emergency',
                      isSelected: selected == null,
                      icon: Icons.person_rounded,
                      onTap: () {
                        onChanged(null);
                        Navigator.pop(context);
                      },
                    ),
                    ...members.map(
                      (m) => _PatientListTile(
                        title: m.fullName,
                        subtitle: 'Family Member',
                        isSelected: selected?.id == m.id,
                        icon: Icons.group_rounded,
                        onTap: () {
                          onChanged(m);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  const _PatientListTile({required this.title, required this.subtitle, required this.isSelected, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(vertical: 4.h),
      leading: Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(color: (isSelected ? kPrimaryColor : kGreyColor).withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: isSelected ? kPrimaryColor : kTextHintColor, size: 22.sp),
      ),
      title: Text(title, style: kTextSemiBold(color: isSelected ? kPrimaryColor : kTextPrimaryColor)),
      subtitle: Text(
        subtitle,
        style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
      ),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: kPrimaryColor) : null,
    );
  }
}

class _StyledInstructionsField extends StatelessWidget {
  final TextEditingController controller;
  const _StyledInstructionsField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 3,
      style: kTextMedium(color: kTextPrimaryColor),
      decoration: InputDecoration(
        hintText: 'Describe the emergency (e.g. Sharp chest pain)',
        hintStyle: kTextNormal(color: kTextHintColor),
        filled: true,
        fillColor: kWhiteColor,
        contentPadding: EdgeInsets.all(16.w),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: kBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: kBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
        ),
      ),
    );
  }
}

class _ModernLocatingOverlay extends StatelessWidget {
  final AnimationController pulseCtrl;

  const _ModernLocatingOverlay({required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.45),
      body: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Center(
          child: Container(
            width: 320.w,
            padding: EdgeInsets.fromLTRB(24.w, 32.h, 24.w, 32.h),
            decoration: BoxDecoration(
              color: kWhiteColor,
              borderRadius: BorderRadius.circular(32.r),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Premium Pulse Animation
                SizedBox(
                  width: 140.w,
                  height: 140.w,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ...List.generate(2, (i) {
                        return AnimatedBuilder(
                          animation: pulseCtrl,
                          builder: (context, child) {
                            final delay = i * 0.5;
                            final value = (pulseCtrl.value + delay) % 1.0;
                            return Opacity(
                              opacity: (1 - value).clamp(0, 1) * 0.4,
                              child: Transform.scale(
                                scale: 1 + (value * 0.8),
                                child: Container(
                                  width: 80.w,
                                  height: 80.w,
                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFEBEE)),
                                ),
                              ),
                            );
                          },
                        );
                      }),
                      Container(
                        width: 80.w,
                        height: 80.w,
                        decoration: BoxDecoration(
                          color: kErrorColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: kErrorColor.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Icon(Icons.emergency_rounded, color: kWhiteColor, size: 40.sp),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  'Locating Nearest Help',
                  style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 20.sp),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                Text(
                  'We are currently identifying the priority partners closest to your location...',
                  style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 14.sp, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: LinearProgressIndicator(color: kErrorColor, backgroundColor: kErrorColor.withValues(alpha: 0.1), minHeight: 6.h),
                ),
                SizedBox(height: 16.h),
                Text(
                  'SEARCHING IN REAL-TIME',
                  style: kTextBold(color: kErrorColor).copyWith(fontSize: 10.sp, letterSpacing: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceSummaryCard extends StatelessWidget {
  final ServiceCategoryModel category;
  const _PriceSummaryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final rateCard = category.rateCards.isNotEmpty ? category.rateCards.first : null;
    final basePrice = rateCard?.basePrice ?? 0.0;
    final gst = basePrice * (category.gstPercentage) / 100;
    final total = basePrice + gst;

    return Container(
      padding: AppPadding.l,
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PriceRow(label: 'Service Fee', value: basePrice),
          if (category.gstPercentage > 0) AppSpacing.sVertical,
          if (category.gstPercentage > 0) _PriceRow(label: 'GST (${category.gstPercentage.toStringAsFixed(0)}%)', value: gst),
          const Divider(height: 24),
          _PriceRow(label: 'Total Amount', value: total, isTotal: true),

          AppSpacing.mVertical,
          RichText(
            text: TextSpan(
              style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 11.sp, height: 1.4),
              children: [const TextSpan(text: 'Distance charges will be calculated after partner acceptance.')],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isTotal;

  const _PriceRow({required this.label, required this.value, this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: isTotal ? kTextBold2() : kTextNormal(color: kTextSecondaryColor)),
        Text(
          NumberUtils.formatCurrency(value),
          style: isTotal ? kTextBold2(color: kPrimaryColor) : kTextSemiBold(color: kTextPrimaryColor),
        ),
      ],
    );
  }
}

void _showPricingPolicySheet(BuildContext context, double freeKm, double rate) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: kWhiteColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
    builder: (context) => _PricingPolicyBottomSheet(freeKm: freeKm, rate: rate),
  );
}

class _PricingPolicyBottomSheet extends StatelessWidget {
  final double freeKm;
  final double rate;
  const _PricingPolicyBottomSheet({required this.freeKm, required this.rate});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 44.w,
                height: 4.h,
                decoration: BoxDecoration(color: kGreyColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              ),
              AppSpacing.lVertical,

              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12.r)),
                    child: Icon(Icons.info_outline_rounded, color: kPrimaryColor, size: 22.sp),
                  ),
                  AppSpacing.mHorizontal,
                  Text(
                    'Distance Charges',
                    style: kTextBold2(color: kTextPrimaryColor).copyWith(fontSize: 18.sp),
                  ),
                ],
              ),
              AppSpacing.lVertical,

              // Modern Policy Cards
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(color: kBorderColor.withValues(alpha: 0.6)),
                        ),
                        child: Column(
                          children: [
                            _PolicyRow(
                              icon: Icons.verified_rounded,
                              title: 'Free Distance',
                              value: 'Up to ${freeKm.toInt()} km',
                              subtitle: 'No charge within this distance.',
                              color: kSuccessColor,
                              isLast: false,
                            ),
                            _PolicyRow(
                              icon: Icons.payments_rounded,
                              title: 'After ${freeKm.toInt()} km',
                              value: '${NumberUtils.formatCurrency(rate)}/km',
                              subtitle: 'Charged per km the partner travels to reach you.',
                              color: kPrimaryColor,
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              AppSpacing.xlVertical,
              CustomButton(title: 'Got It', width: double.infinity, onPressed: () => Navigator.pop(context), backgroundColor: kPrimaryColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final bool isLast;

  const _PolicyRow({required this.icon, required this.title, required this.value, required this.subtitle, required this.color, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: kBorderColor.withValues(alpha: 0.4))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12.r)),
            child: Icon(icon, color: color, size: 20.sp),
          ),
          AppSpacing.lHorizontal,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8.r)),
                      child: Text(
                        value,
                        style: kTextBold(color: color).copyWith(fontSize: 13.sp),
                      ),
                    ),
                  ],
                ),
                AppSpacing.xsVertical,
                Text(
                  subtitle,
                  style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
