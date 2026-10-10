import 'package:adhisaat_health_care/data/repositories/auth_repository.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/user/address/bloc/selected_address_provider.dart';
import 'package:adhisaat_health_care/features/user/address/model/user_address_model.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_edge_insets.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/screen_dimensions.dart';
import '../../../../core/widgets/login_required_dialog.dart';
import '../../../../shared/widgets/buttons/custom_button.dart';
import '../../../auth/login/bloc/auth_bloc.dart';
import '../../home/view/search_address_page.dart';
import '../../service_booking/model/service_category_model.dart';
import '../bloc/emergency_service/emergency_service_bloc.dart';

class EmergencyPage extends ConsumerStatefulWidget {
  const EmergencyPage({super.key});

  @override
  ConsumerState<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends ConsumerState<EmergencyPage> with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _fillCtrl;
  int? _selectedIndex;
  bool _isTriggered = false;
  final String sosContact = "7023221110";

  static const _categoryColors = [
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
    Color(0xFF10B981),
    Color(0xFFEC4899),
  ];

  @override
  void initState() {
    super.initState();
    // Subtle pulse for the shadow/glow
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);

    // 2-second hold duration for SOS trigger
    _fillCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1));

    _fillCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isTriggered) {
        _handleSOS();
      }
    });

    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fillCtrl.dispose();
    super.dispose();
  }

  void _handleSOS() async {
    if (_isTriggered) return;

    HapticFeedback.heavyImpact();
    setState(() => _isTriggered = true);

    final Uri callUri = Uri.parse('tel:$sosContact');

    try {
      // Use externalApplication mode to ensure it opens the dialer/phone app
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri, mode: LaunchMode.externalApplication);
        setState(() => _isTriggered = false);
      } else {
        if (mounted) {
          setState(() => _isTriggered = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Could not launch dialer for $sosContact")));
        }
      }
    } catch (e) {
      setState(() => _isTriggered = false);
      debugPrint("Error launching call: $e");
    }
  }

  Future<void> _proceed(List<ServiceCategoryModel> services) async {
    if (_selectedIndex == null) return;

    if (context.read<AuthBloc>().state is AuthGuest) {
      LoginRequiredDialog.show(context);
      return;
    }

    HapticFeedback.mediumImpact();

    Navigator.of(context).pushNamed(AppRoutes.emergencyConfirm, arguments: services[_selectedIndex!]);
  }

  Future<void> _checkServiceAvailability(UserAddressModel address) async {
    final pinCode = address.pinCode;
    if (pinCode == null || pinCode.isEmpty) return;

    try {
      final result = await locator<AuthRepository>().checkServiceAvailability(pinCode);
      if (!mounted) return;

      final cityAdmin = result.data?.cityAdmin;
      // No service provider city mapped to this area.
      if (!result.status || cityAdmin == null) {
        _showServiceUnavailableDialog(
          result.message.isNotEmpty ? result.message : 'Services are not available in this area.',
        );
      } else if (cityAdmin.isEmergencyServiceEnabled != 1) {
        // Area is served, but emergency service is switched off here.
        _showServiceUnavailableDialog('Emergency services are not available in this area.');
      }
    } catch (_) {
      // Silently ignore — don't block the flow on availability check failure.
    }
  }

  void _showServiceUnavailableDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        backgroundColor: kWhiteColor,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xl),
        insetPadding: AppPadding.symmetric(h: 28, v: 24),
        child: PopScope(
          canPop: false,
          child: Padding(
            padding: AppPadding.l,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: AppPadding.l,
                  decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.location_off_rounded, color: kErrorColor, size: 38.sp),
                ),
                AppSpacing.lVertical,
                Text('Service Unavailable', style: kTextBold2(), textAlign: TextAlign.center),
                AppSpacing.sVertical,
                Text(message, style: kTextNormal(color: kTextSecondaryColor), textAlign: TextAlign.center),
                AppSpacing.xlVertical,
                CustomButton(
                  width: double.infinity,
                  height: AppButtonHeight.m,
                  title: 'Change Location',
                  iconData: Icons.edit_location_alt_rounded,
                  borderRadius: AppRadius.l,
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const SearchAddressPage()),
                    );
                  },
                ),
                AppSpacing.sVertical,
                CustomButton(
                  width: double.infinity,
                  height: AppButtonHeight.m,
                  title: 'Go Back',
                  backgroundColor: kWhiteColor,
                  textColor: kPrimaryColor,
                  borderSide: BorderSide(color: kPrimaryColor),
                  borderRadius: AppRadius.l,
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for location changes to reload services
    ref.listen<UserAddressModel?>(selectedAddressProvider, (previous, next) {
      // if (next?.city != null && next?.city != previous?.city) {
      //   context.read<EmergencyServiceBloc>().add(LoadEmergencyServices(city: next!.city!.toLowerCase()));
      // }
      // Re-check service + emergency availability whenever the address changes.
      // A newly added address may share a pinCode, so compare id too.
      if (next != null && next.id != null && (next.id != previous?.id || next.pinCode != previous?.pinCode)) {
        _checkServiceAvailability(next);
      }
    });

    final currentCity = ref.watch(selectedAddressProvider)?.city ?? "Your Area";

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5),
      appBar: CustomAppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: kTextPrimaryColor, size: 24.sp),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: 'Emergency',
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: AppPadding.mHorizontal.copyWith(top: 8, bottom: 20),
                    child: AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (context, child) => Container(
                        padding: AppPadding.l,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color.lerp(const Color(0xFFEF4444), const Color(0xFFFF6B6B), _pulseCtrl.value)!,
                              const Color(0xFFDC2626),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: AppRadius.xl,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.3 + _pulseCtrl.value * 0.2),
                              blurRadius: 24,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: AppPadding.m,
                              decoration: BoxDecoration(
                                color: kWhiteColor.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.emergency_rounded, color: kWhiteColor, size: 32.sp),
                            ),
                            AppSpacing.lHorizontal,
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Emergency Help', style: kTextBold2(color: kWhiteColor)),
                                      AppSpacing.xsVertical,
                                      Text(
                                        'Select a category. A provider will be dispatched immediately.',
                                        style: kTextNormal0(color: kWhiteColor.withValues(alpha: 0.85)),
                                        maxLines: 2,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // ── Section Label ──────────────────────────────────────────
                  Padding(
                    padding: AppPadding.only(left: 20, right: 20, bottom: 10),
                    child: Row(
                      children: [
                        Text('Choose Service Type', style: kTextSemiBold2(color: kTextPrimaryColor)),
                        AppSpacing.sHorizontal,
                        Container(
                          width: 6.w,
                          height: 6.w,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: kErrorColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Services List ──────────────────────────────────────────
            Expanded(
              child: BlocBuilder<EmergencyServiceBloc, EmergencyServiceState>(
                builder: (context, state) {
                  if (state is EmergencyServiceLoading) {
                    return const Center(child: CircularProgressIndicator(color: kErrorColor));
                  } else if (state is EmergencyServiceLoaded) {
                    if (state.services.isEmpty) {
                      return _NoServiceView(
                        city: currentCity,
                        onChangeLocation: () {
                          // Open search directly
                          Navigator.of(context).push(
                            MaterialPageRoute(fullscreenDialog: true, builder: (_) => const SearchAddressPage()),
                          );
                        },
                        onCallSOS: _handleSOS,
                      );
                    }
                    return ListView.separated(
                      padding: AppPadding.only(left: 20, right: 20, bottom: 16),
                      itemCount: state.services.length,
                      separatorBuilder: (_, _) => AppSpacing.mVertical,
                      itemBuilder: (_, i) {
                        final category = state.services[i];
                        final selected = _selectedIndex == i;
                        final color = _categoryColors[i % _categoryColors.length];
                        final basePrice = category.rateCards.isNotEmpty ? category.rateCards.first.basePrice : 0.0;

                        return _ServiceListTile(
                          category: category,
                          color: color,
                          selected: selected,
                          basePrice: basePrice,
                          onTap: () {
                            setState(() => _selectedIndex = i);
                            HapticFeedback.selectionClick();
                          },
                        );
                      },
                    );
                  } else if (state is EmergencyServiceError) {
                    return _NoServiceView(
                      city: currentCity,
                      onChangeLocation: () => Navigator.of(context).pop(), // Go back to change
                      onCallSOS: _handleSOS,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BlocBuilder<EmergencyServiceBloc, EmergencyServiceState>(
        builder: (context, state) {
          final services = state is EmergencyServiceLoaded ? state.services : <ServiceCategoryModel>[];
          bool isEnabled = _selectedIndex != null && services.isNotEmpty;
          return Container(
            color: kWhiteColor,
            padding: AppPadding.only(left: 20, right: 20, top: 14, bottom: 24),
            child: SafeArea(
              top: false,
              child: CustomButton(
                isEnable: isEnabled,
                title: 'Get Emergency Help Now',
                iconData: Icons.emergency_rounded,
                backgroundColor: isEnabled ? const Color(0xFFEF4444) : Colors.red.shade200,
                borderRadius: AppRadius.l,
                height: AppButtonHeight.l,
                width: double.infinity,
                isLoading: false,
                onPressed: isEnabled ? () => _proceed(services) : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── No Service Available View ──────────────────────────────────────────────

class _NoServiceView extends StatelessWidget {
  final String city;
  final VoidCallback onChangeLocation;
  final VoidCallback onCallSOS;

  const _NoServiceView({required this.city, required this.onChangeLocation, required this.onCallSOS});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppPadding.xl,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 140.w,
                height: 140.w,
                decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.08), shape: BoxShape.circle),
                child: Icon(Icons.location_off_rounded, size: 70.sp, color: kErrorColor),
              ),
              AppSpacing.xlVertical,
              Text(
                'No Emergency Coverage',
                style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 22.sp),
                textAlign: TextAlign.center,
              ),
              AppSpacing.mVertical,
              Text(
                'It seems we don\'t have emergency services available in $city at the moment.',
                style: kTextNormal(color: kTextSecondaryColor),
                textAlign: TextAlign.center,
              ),
              AppSpacing.xlVertical,
              CustomButton(
                title: 'Change Location',
                onPressed: onChangeLocation,
                borderRadius: AppRadius.l,
                height: AppButtonHeight.m,
                width: 220.w,
                backgroundColor: kPrimaryColor,
              ),
              AppSpacing.mVertical,
              TextButton.icon(
                onPressed: onCallSOS,
                icon: Icon(Icons.phone_in_talk_rounded, size: 18.sp, color: kErrorColor),
                label: Text('Call Emergency Hotline', style: kTextSemiBold(color: kErrorColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Service List Tile ────────────────────────────────────────────────────────

class _ServiceListTile extends StatelessWidget {
  final ServiceCategoryModel category;
  final Color color;
  final bool selected;
  final double basePrice;
  final VoidCallback onTap;

  const _ServiceListTile({
    required this.category,
    required this.color,
    required this.selected,
    required this.basePrice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: AppPadding.l,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.06) : kWhiteColor,
          borderRadius: AppRadius.l,
          border: Border.all(color: selected ? color : kBorderColor, width: selected ? 2 : 1),
          boxShadow: [
            if (selected)
              BoxShadow(color: color.withValues(alpha: 0.20), blurRadius: 16, offset: const Offset(0, 6))
            else
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56.w,
              height: 56.w,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: AppRadius.m),
              clipBehavior: Clip.antiAlias,
              child: category.iconImageUrl != null && category.iconImageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: category.iconImageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Icon(Icons.medical_services_rounded, color: color, size: 28.sp),
                    )
                  : Icon(Icons.medical_services_rounded, color: color, size: 28.sp),
            ),
            AppSpacing.lHorizontal,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.categoryName,
                    style: kTextSemiBold2(color: selected ? color : kTextPrimaryColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (category.description != null && category.description!.isNotEmpty) ...[
                    AppSpacing.xsVertical,
                    Text(
                      category.description!,
                      style: kTextNormal0(color: kTextSecondaryColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (context.read<AuthBloc>().state is! AuthGuest) ...[
                    AppSpacing.sVertical,
                    Container(
                      padding: AppPadding.symmetric(h: 10, v: 4),
                      decoration: BoxDecoration(
                        color: kSuccessColor.withValues(alpha: 0.08),
                        borderRadius: AppRadius.xs,
                      ),
                      child: Text('₹${basePrice.toStringAsFixed(0)}', style: kTextSemiBold0(color: kSuccessColor)),
                    ),
                  ],
                ],
              ),
            ),
            AppSpacing.mHorizontal,
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26.w,
              height: 26.w,
              decoration: BoxDecoration(
                color: selected ? color : kTransparentColor,
                shape: BoxShape.circle,
                border: Border.all(color: selected ? color : kBorderColor, width: 2),
              ),
              child: selected ? Icon(Icons.check_rounded, color: kWhiteColor, size: 14.sp) : null,
            ),
          ],
        ),
      ),
    );
  }
}
