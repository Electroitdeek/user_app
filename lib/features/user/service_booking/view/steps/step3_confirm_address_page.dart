import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_edge_insets.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/theme/screen_dimensions.dart';
import '../../../../../core/utils/message_service.dart';
import '../../../../../core/utils/number_utils.dart';
import '../../../../../data/repositories/auth_repository.dart';
import '../../../../../di/locator.dart';
import '../../../../../shared/widgets/buttons/custom_button.dart';
import '../../../address/bloc/selected_address_provider.dart';
import '../../../address/model/user_address_model.dart';
import '../../../address/view/address_selection_bottom_sheet.dart';
import '../../../family/bloc/family_bloc.dart';
import '../../../family/bloc/family_event.dart';
import '../../../family/bloc/family_state.dart';
import '../../../family/data/family_repository.dart';
import '../../../family/model/family_member_model.dart';
import '../../../family/view/family_add_edit_bottom_sheet.dart';
import '../../../payment/view/booking_payment_page.dart';
import '../../bloc/service_request_bloc.dart';
import '../../data/service_request_repository.dart';
import '../../model/booking_model.dart';
import '../../model/service_category_model.dart';
import '../service_booking_flow.dart';

class Step3ConfirmAddressPage extends StatelessWidget {
  final BookingRequest request;
  final ValueChanged<BookingRequest> onUpdate;

  const Step3ConfirmAddressPage({super.key, required this.request, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [BlocProvider(create: (_) => FamilyBloc(locator<FamilyRepository>())..add(LoadFamilyMembers()))],
      child: _Step3Body(request: request, onUpdate: onUpdate),
    );
  }
}

class _Step3Body extends ConsumerStatefulWidget {
  final BookingRequest request;
  final ValueChanged<BookingRequest> onUpdate;

  const _Step3Body({required this.request, required this.onUpdate});

  @override
  ConsumerState<_Step3Body> createState() => _Step3BodyState();
}

class _Step3BodyState extends ConsumerState<_Step3Body> {
  FamilyMemberModel? _selectedFamily;
  final _instructionsCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isMyself = true;
  List<FamilyMemberModel> _lastMembers = [];

  @override
  void initState() {
    super.initState();
    if (widget.request.instructions != null) {
      _instructionsCtrl.text = widget.request.instructions!;
    }
    _isMyself = widget.request.familyMemberId == null;

    final familyState = context.read<FamilyBloc>().state;
    if (familyState is FamilyLoaded) {
      _lastMembers = familyState.members;
    } else if (familyState is FamilyActionSuccess) {
      _lastMembers = familyState.members;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedAddressProvider.notifier).loadForLoggedInUser(force: true);
    });
  }

  @override
  void dispose() {
    _instructionsCtrl.dispose();
    super.dispose();
  }

  String get _estimatedPriceFormatted {
    final price = widget.request.estimatedPrice ?? 0;
    return price > 0 ? NumberUtils.formatCurrency(price) : '';
  }

  bool get _canProceed {
    final addr = ref.read(selectedAddressProvider);
    return addr != null && addr.displayAddress.isNotEmpty;
  }

  Future<void> _onSelectAnyoneElse() async {
    final familyState = context.read<FamilyBloc>().state;
    List<FamilyMemberModel> members = [];
    if (familyState is FamilyLoaded) {
      members = familyState.members;
    } else if (familyState is FamilyActionSuccess) {
      members = familyState.members;
    }

    setState(() {
      _isMyself = false;
      if (_selectedFamily == null && members.isNotEmpty) {
        _selectedFamily = members.first;
      }
    });

    if (members.isEmpty) {
      final added = await FamilyAddEditBottomSheet.show(context);
      if (added == true && mounted) {
        context.read<FamilyBloc>().add(LoadFamilyMembers());
      }
    }
  }

  Future<void> _proceed() async {
    if (!_isMyself && _selectedFamily == null) {
      MessageService.showError('Please select or add a family member');
      return;
    }

    if (!_canProceed) {
      _openAddressSheet(context);
      return;
    }
    final selectedAddress = ref.read(selectedAddressProvider)!;

    // Verify the service is available at this address before creating the request.
    setState(() => _isLoading = true);
    final isAvailable = await _checkServiceAvailability(selectedAddress);
    if (!mounted) return;
    if (!isAvailable) {
      setState(() => _isLoading = false);
      return;
    }

    final double? latitude = selectedAddress.latitude != null ? double.tryParse(selectedAddress.latitude!) : null;
    final double? longitude = selectedAddress.longitude != null
        ? double.tryParse(selectedAddress.longitude!)
        : null;

    final updatedRequest = widget.request.copyWith(
      address: selectedAddress.displayAddress,
      addressId: selectedAddress.id,
      landmark: selectedAddress.area,
      latitude: latitude,
      longitude: longitude,
      city: selectedAddress.city,
      pinCode: selectedAddress.pinCode,
      familyMemberId: _isMyself ? null : _selectedFamily?.id,
      familyMemberName: _isMyself ? null : _selectedFamily?.fullName,
      instructions: _instructionsCtrl.text.trim(),
    );

    widget.onUpdate(updatedRequest);

    try {
      final res = await locator<ServiceRequestRepository>().createServiceRequest(updatedRequest);
      if (!mounted) return;

      final isSuccess = res['success'] == true || res['status'] == true;
      if (isSuccess) {
        // Handle both {data: {service_request: {...}}} and flat {data: {...}}
        final resData = res['data'] as Map?;
        final srMap = (resData != null && resData.containsKey('service_request'))
            ? resData['service_request'] as Map?
            : resData;

        // Extract installments and API-computed amounts
        final paymentInstallments = ((resData?['payment_installments']) as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final apiTotal = double.tryParse(resData?['total_amount']?.toString() ?? '') ?? 0;
        final apiBase = double.tryParse(resData?['base_price']?.toString() ?? '') ?? 0;
        final apiGst = double.tryParse(resData?['gst_amount']?.toString() ?? '') ?? 0;
        final apiDistance = double.tryParse(resData?['distance_charge']?.toString() ?? '') ?? 0;

        final finalRequest = updatedRequest.copyWith(
          serviceRequestId: srMap?['id'] is int
              ? srMap!['id'] as int
              : int.tryParse(srMap?['id']?.toString() ?? ''),
          requestNumber: srMap?['request_number']?.toString(),
          waitingWindowMinutes: srMap?['waiting_window_minutes'] is int
              ? srMap!['waiting_window_minutes'] as int
              : int.tryParse(srMap?['waiting_window_minutes']?.toString() ?? ''),
          waitingStartedAt: srMap?['waiting_started_at'] != null
              ? DateTime.tryParse(srMap!['waiting_started_at'].toString())
              : null,
        );
        widget.onUpdate(finalRequest);

        final basePrice = apiBase > 0 ? apiBase : (finalRequest.estimatedPrice ?? 0);
        final totalAmount = apiTotal > 0 ? apiTotal : basePrice;

        final isProcedural = finalRequest.bookingType == 'procedural';
        final pkgId = finalRequest.selectedPackageId;
        final pkgs = finalRequest.serviceType?.rateCard?.packages ?? [];
        RateCardPackageModel? pkg;
        if (pkgId != null) {
          for (final p in pkgs) {
            if (p.id == pkgId) {
              pkg = p;
              break;
            }
          }
        }
        final double discountPct = isProcedural
            ? (finalRequest.serviceType?.rateCard?.proceduralDiscountPercentage ?? 0)
            : (pkg?.discountPercentage ?? 0);
        final double originalPrice = discountPct > 0 ? basePrice / (1 - discountPct / 100) : basePrice;
        final double computedDiscountAmt = discountPct > 0 ? (originalPrice - basePrice) : 0;

        await navigateToPaymentPage(
          context: context,
          serviceRequestId: finalRequest.serviceRequestId ?? 0,
          totalAmount: totalAmount,
          basePrice: basePrice,
          distanceCharge: apiDistance,
          gstAmount: apiGst,
          paymentInstallments: paymentInstallments,
          bookingType: 'service_booking',
          serviceName: finalRequest.serviceType?.name,
          serviceImageUrl: finalRequest.serviceType?.iconUrl,
          startDate: finalRequest.startDate != null
              ? DateFormat('EEE, dd MMM yyyy').format(finalRequest.startDate!)
              : null,
          endDate: finalRequest.endDate != null
              ? DateFormat('EEE, dd MMM yyyy').format(finalRequest.endDate!)
              : null,
          durationDays: finalRequest.scheduledDates?.isNotEmpty == true
              ? finalRequest.scheduledDates!.length
              : finalRequest.durationDays,
          durationHours: finalRequest.durationHours,
          unitType: finalRequest.serviceType?.rateCard?.unitType,
          isNewBooking: true,
          packageDiscountAmount: computedDiscountAmt,
        );
      } else {
        MessageService.showError(res['message']?.toString() ?? 'Failed to create request');
      }
    } catch (e) {
      if (mounted) {
        MessageService.showError('Error: ${e.toString().replaceAll("Exception:", "").trim()}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedAddress = ref.watch(selectedAddressProvider);

    ref.listen<UserAddressModel?>(selectedAddressProvider, (prev, next) {
      // Re-check whenever the selected address changes — a newly added address
      // may share a pinCode with the previous one, so compare id too.
      if (next != null && next.id != null && (next.id != prev?.id || next.pinCode != prev?.pinCode)) {
        _checkServiceAvailability(next);
      }
    });

    return BlocListener<FamilyBloc, FamilyState>(
      listener: (context, state) {
        if (state is FamilyLoaded) {
          _lastMembers = state.members;
        } else if (state is FamilyActionSuccess) {
          final currentMembers = state.members;
          if (currentMembers.isNotEmpty) {
            FamilyMemberModel? newMember;
            for (final m in currentMembers) {
              if (!_lastMembers.any((old) => old.id == m.id)) {
                newMember = m;
                break;
              }
            }

            if (newMember != null) {
              setState(() {
                _selectedFamily = newMember;
              });
            } else if (_selectedFamily != null) {
              final updated = currentMembers.firstWhere(
                (m) => m.id == _selectedFamily!.id,
                orElse: () => currentMembers.last,
              );
              setState(() {
                _selectedFamily = updated;
              });
            } else {
              setState(() {
                _selectedFamily = currentMembers.last;
              });
            }
          }
          _lastMembers = currentMembers;
        }
      },
      child: BookingStepScaffold(
        title: 'Service Details',
        currentStep: 3,
        totalSteps: 4,
        body: SingleChildScrollView(
          padding: AppPadding.only(left: 12, right: 12, top: 16, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Almost done!', style: kTextBold1()),
              AppSpacing.xsVertical,
              Text('Confirm your address and patient details', style: kTextNormal(color: kTextSecondaryColor)),
              AppSpacing.lVertical,
  
              // ── Address ──────────────────────────────────────────────
              _SectionLabel(label: 'Service Address'),
              AppSpacing.sVertical,
              _AddressCard(
                selectedAddress: selectedAddress != null && selectedAddress.displayAddress.isNotEmpty
                    ? selectedAddress
                    : null,
                hasTempAddress: false,
                onTap: () => _openAddressSheet(context),
              ),
              AppSpacing.xlVertical,
  
              // ── Patient (family member) ──────────────────────────────
              _SectionLabel(label: 'Patient Details'),
              AppSpacing.sVertical,
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isMyself = true;
                          _selectedFamily = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(12.r),
                      child: Container(
                        padding: AppPadding.symmetric(h: 16, v: 12),
                        decoration: BoxDecoration(
                          color: _isMyself ? kPrimaryColor.withValues(alpha: 0.05) : kWhiteColor,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: _isMyself ? kPrimaryColor : kBorderColor,
                            width: _isMyself ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isMyself ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              color: _isMyself ? kPrimaryColor : kTextHintColor,
                              size: 20.sp,
                            ),
                            AppSpacing.mHorizontal,
                            Flexible(
                              child: Text(
                                'Myself',
                                style: kTextMedium(color: _isMyself ? kPrimaryColor : kTextPrimaryColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: InkWell(
                      onTap: _onSelectAnyoneElse,
                      borderRadius: BorderRadius.circular(12.r),
                      child: Container(
                        padding: AppPadding.symmetric(h: 16, v: 12),
                        decoration: BoxDecoration(
                          color: !_isMyself ? kPrimaryColor.withValues(alpha: 0.05) : kWhiteColor,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: !_isMyself ? kPrimaryColor : kBorderColor,
                            width: !_isMyself ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              !_isMyself ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              color: !_isMyself ? kPrimaryColor : kTextHintColor,
                              size: 20.sp,
                            ),
                            AppSpacing.mHorizontal,
                            Flexible(
                              child: Text(
                                'Anyone else',
                                style: kTextMedium(color: !_isMyself ? kPrimaryColor : kTextPrimaryColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
  
              if (!_isMyself) ...[
                AppSpacing.sVertical,
                BlocBuilder<FamilyBloc, FamilyState>(
                  builder: (context, state) {
                    List<FamilyMemberModel> members = [];
                    if (state is FamilyLoaded) {
                      members = state.members;
                    } else if (state is FamilyActionSuccess) {
                      members = state.members;
                    } else if (state is FamilyLoading) {
                      return _LoadingSkeleton();
                    } else {
                      return _LoadingSkeleton();
                    }
  
                    if (_selectedFamily == null && widget.request.familyMemberId != null) {
                      try {
                        _selectedFamily = members.firstWhere((m) => m.id == widget.request.familyMemberId);
                      } catch (_) {}
                    }

                    if (_selectedFamily == null && members.isNotEmpty) {
                      _selectedFamily = members.first;
                    }
  
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final added = await FamilyAddEditBottomSheet.show(context);
                              if (added == true && context.mounted) {
                                context.read<FamilyBloc>().add(LoadFamilyMembers());
                              }
                            },
                            child: Container(
                              margin: EdgeInsets.only(right: 10.w),
                              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                              decoration: BoxDecoration(
                                color: kScaffoldColor,
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: kBorderColor.withValues(alpha: 0.6),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 32.r,
                                    height: 32.r,
                                    decoration: BoxDecoration(
                                      color: kPrimaryColor.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(Icons.add_rounded, color: kPrimaryColor, size: 20.sp),
                                  ),
                                  SizedBox(width: 10.w),
                                  Text(
                                    'Add Member',
                                    style: kTextSemiBold(color: kPrimaryColor).copyWith(fontSize: 13.sp),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ...members.map((member) {
                            final bool isSelected = _selectedFamily?.id == member.id;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedFamily = member;
                                });
                              },
                              child: Container(
                                margin: EdgeInsets.only(right: 10.w),
                                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                                decoration: BoxDecoration(
                                  color: isSelected ? kPrimaryColor.withValues(alpha: 0.05) : kWhiteColor,
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                    color: isSelected ? kPrimaryColor : kBorderColor.withValues(alpha: 0.6),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: kPrimaryColor.withValues(alpha: 0.1),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.02),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 32.r,
                                      height: 32.r,
                                      decoration: BoxDecoration(
                                        color: isSelected ? kPrimaryColor : kGreyColor2,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : 'M',
                                        style: kTextBold(color: isSelected ? kWhiteColor : kTextPrimaryColor).copyWith(fontSize: 14.sp),
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Text(
                                      member.fullName,
                                      style: kTextSemiBold(color: isSelected ? kPrimaryColor : kTextPrimaryColor).copyWith(fontSize: 13.sp),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ],
              AppSpacing.xlVertical,
  
              // ── Special Instructions ─────────────────────────────────
              _SectionLabel(label: 'Patient medical history / Patient condition (optional)'),
              AppSpacing.sVertical,
              _InstructionsField(controller: _instructionsCtrl),
              AppSpacing.xlVertical,
  
              // ── BOOKING SUMMARY CARD ─────────────────────────────────
              _BookingSummaryCard(request: widget.request, estimatedPrice: _estimatedPriceFormatted),
              AppSpacing.xlVertical,
  
              // ── PROCEED (Find Provider) ───────────────────────────
              _FooterProceed(
                request: widget.request,
                onTap: _isLoading ? null : () => _proceed(),
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddressSheet(BuildContext context) {
    AddressSelectionBottomSheet.show(context, parentRoute: AppRoutes.serviceBookingFlow);
  }

  /// Returns `true` when the service is available at [address] (or when the
  /// check cannot be performed), `false` when it is unavailable — in which
  /// case the unavailable dialog is shown.
  Future<bool> _checkServiceAvailability(UserAddressModel address) async {
    final pinCode = address.pinCode;
    if (pinCode == null || pinCode.isEmpty) return true;

    try {
      final result = await locator<AuthRepository>().checkServiceAvailability(pinCode);
      if (!mounted) return true;

      // API returns status:false (e.g. error_type "no_city_admin") when no
      // service provider city is mapped to this area.
      if (!result.status || result.data?.cityAdmin == null) {
        _showServiceUnavailableDialog(
          result.message.isNotEmpty ? result.message : 'Services are not available in this area.',
        );
        return false;
      }
      return true;
    } catch (_) {
      // Silently ignore — don't block the flow on availability check failure.
      return true;
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
                Text(
                  message,
                  style: kTextNormal(color: kTextSecondaryColor),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.xlVertical,
                CustomButton(
                  width: double.infinity,
                  height: AppButtonHeight.m,
                  title: 'Change Location',
                  iconData: Icons.edit_location_alt_rounded,
                  borderRadius: AppRadius.l,
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    _openAddressSheet(context);
                  },
                ),
                AppSpacing.sVertical,
                CustomButton(
                  width: double.infinity,
                  height: AppButtonHeight.m,
                  title: 'Go to Home',
                  backgroundColor: kWhiteColor,
                  textColor: kPrimaryColor,
                  borderSide: BorderSide(color: kPrimaryColor),
                  borderRadius: AppRadius.l,
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    // Exit entire booking flow via root navigator, then refresh home.
                    AppNavigator.navigatorKey.currentState?.popUntil((route) => route.isFirst);
                    final rootCtx = AppNavigator.navigatorKey.currentState?.overlay?.context;
                    if (rootCtx != null) {
                      try {
                        rootCtx.read<ServiceRequestBloc>().add(const LoadServiceRequests());
                      } catch (_) {}
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  BOOKING SUMMARY CARD
// ─────────────────────────────────────────────────────────
class _BookingSummaryCard extends StatelessWidget {
  final BookingRequest request;
  final String estimatedPrice;

  const _BookingSummaryCard({required this.request, required this.estimatedPrice});

  bool get _isProcedural => request.bookingType == 'procedural';

  RateCardPackageModel? get _selectedPackage {
    if (request.selectedPackageId == null) return null;
    final pkgs = request.serviceType?.rateCard?.packages ?? [];
    try {
      return pkgs.firstWhere((p) => p.id == request.selectedPackageId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pkg = _selectedPackage;
    final basePriceValue = request.estimatedPrice ?? 0;
    final gstPercent = request.serviceType?.gstPercentage ?? 0;

    final double discountPct = _isProcedural
        ? (request.serviceType?.rateCard?.proceduralDiscountPercentage ?? 0)
        : (pkg?.discountPercentage ?? 0);
    // Back-compute original price from discounted estimatedPrice and discountPct.
    final double originalPrice = discountPct > 0 ? basePriceValue / (1 - discountPct / 100) : basePriceValue;
    final double discountAmt = discountPct > 0 ? (originalPrice - basePriceValue) : 0;
    final double gstAmount = basePriceValue * (gstPercent / 100);

    return Container(
      padding: AppPadding.l,
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: AppRadius.xl,
        border: Border.all(color: kBorderColor.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Container(
                padding: AppPadding.s,
                decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.1), borderRadius: AppRadius.m),
                child: Icon(Icons.receipt_long_rounded, color: kPrimaryColor, size: 22.sp),
              ),
              AppSpacing.lHorizontal,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Booking Summary', style: kTextBold1()),
                    Text('Verify your service details', style: kTextNormal0(color: kTextSecondaryColor)),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.lVertical,
          const Divider(height: 1, thickness: 0.8),
          AppSpacing.lVertical,

          // ── Service & Care Mode ──
          if (request.serviceType != null) ...[
            _SummaryRow(icon: Icons.health_and_safety_rounded, label: 'Service', value: request.serviceType!.name),
            AppSpacing.mVertical,
          ],
          _SummaryRow(
            icon: Icons.local_hospital_rounded,
            label: 'Care Mode',
            value: _isProcedural ? 'Procedure' : 'Long Duration',
          ),
          AppSpacing.lVertical,

          // ── Schedule (branched by booking type) ──
          if (_isProcedural) _ProceduralSchedule(request: request) else _LongDurationSchedule(request: request),

          // ── Package chip ──
          if (pkg != null) ...[AppSpacing.mVertical, _PackageAppliedChip(package: pkg)],

          AppSpacing.lVertical,
          const Divider(height: 1, thickness: 0.8),
          AppSpacing.lVertical,

          // ── Price breakdown ──
          if (discountPct > 0) ...[
            _PriceRow(
              label: 'Original Price',
              value: NumberUtils.formatCurrency(originalPrice),
              strikethrough: true,
              labelColor: kTextHintColor,
              valueColor: kTextHintColor,
            ),
            AppSpacing.sVertical,
            _PriceRow(
              label: 'Discount (${cleanDecimal(discountPct)}%)',
              value: '− ${NumberUtils.formatCurrency(discountAmt)}',
              valueColor: kSuccessColor,
            ),
            AppSpacing.sVertical,
            _PriceRow(
              label: _isProcedural ? 'Service Price' : 'Package Price',
              value: NumberUtils.formatCurrency(basePriceValue),
            ),
          ] else
            _PriceRow(label: 'Service Price', value: NumberUtils.formatCurrency(basePriceValue)),

          if (gstPercent > 0) ...[
            AppSpacing.sVertical,
            _PriceRow(label: 'GST (${gstPercent.toInt()}%)', value: NumberUtils.formatCurrency(gstAmount)),
          ],

          AppSpacing.lVertical,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Procedural Schedule (single-day + multi-day hourly)
// ─────────────────────────────────────────────────────────
class _ProceduralSchedule extends StatelessWidget {
  final BookingRequest request;

  const _ProceduralSchedule({required this.request});

  bool get _isMultiDay => request.serviceMode == 'hourly_multi_day' || (request.durationDays ?? 0) > 1;

  String _fmtDate(DateTime? d) => d == null ? '—' : DateFormat('dd MMM yyyy').format(d);

  String _fmtTime(String? t) {
    if (t == null) return '';
    try {
      final parts = t.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return DateFormat.jm().format(DateTime(2000, 1, 1, h, m));
    } catch (_) {
      return t;
    }
  }

  int? _minutesOf(String? t) {
    if (t == null) return null;
    try {
      final p = t.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    } catch (_) {
      return null;
    }
  }

  String _fmtDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '$h hr${h > 1 ? 's' : ''}';
    return '$h hr${h > 1 ? 's' : ''} $m min';
  }

  /// Actual session length from start/end times; falls back to durationHours.
  String? _sessionLabel(int? hrs) {
    final start = _minutesOf(request.startTime);
    final end = _minutesOf(request.endTime);
    if (start != null && end != null && end > start) {
      return _fmtDuration(end - start);
    }
    return hrs != null ? '$hrs hr${hrs > 1 ? 's' : ''}' : null;
  }

  @override
  Widget build(BuildContext context) {
    final hrs = request.durationHours;
    final days = (request.scheduledDates?.isNotEmpty ?? false)
        ? request.scheduledDates!.length
        : request.durationDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 16.sp, color: kPrimaryColor.withValues(alpha: 0.6)),
            AppSpacing.sHorizontal,
            Text('Schedule', style: kTextNormal0(color: kTextSecondaryColor)),
            if (_isMultiDay && hrs != null) ...[
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.08), borderRadius: AppRadius.s),
                child: Text(() {
                  final ut = request.serviceType?.rateCard?.unitType;
                  return ut != null ? '$hrs $ut / day' : '$hrs hr${hrs > 1 ? 's' : ''} / day';
                }(), style: kTextMedium0(color: kPrimaryColor)),
              ),
            ],
          ],
        ),
        AppSpacing.sVertical,

        if (_isMultiDay) ...[
          _DateTimeBlock(
            label: 'Starts on',
            dateTime: () {
              final date = _fmtDate(request.startDate);
              if (request.startTime != null && request.endTime != null) {
                return '$date  ·  ${_fmtTime(request.startTime)} - ${_fmtTime(request.endTime)}';
              }
              return request.startTime != null ? '$date  ·  ${_fmtTime(request.startTime)}' : date;
            }(),
          ),
          AppSpacing.sVertical,
          _DateTimeBlock(
            label: 'Ends on',
            dateTime: () {
              final date = _fmtDate(request.endDate ?? request.startDate);
              if (request.startTime != null && request.endTime != null) {
                return '$date  ·  ${_fmtTime(request.startTime)} - ${_fmtTime(request.endTime)}';
              }
              return request.endTime != null ? '$date  ·  ${_fmtTime(request.endTime)}' : date;
            }(),
          ),
          if (days != null && hrs != null) ...[
            AppSpacing.sVertical,
            Text(() {
              final ut = request.serviceType?.rateCard?.unitType;
              final unitLabel = ut != null ? '$hrs $ut' : '$hrs hr${hrs > 1 ? 's' : ''}';
              return '$days day${days > 1 ? 's' : ''} · $unitLabel ${days > 1 ? 'each day' : ''}';
            }(), style: kTextNormal0(color: kTextSecondaryColor)),
          ],
        ] else ...[
          _DateTimeBlock(label: 'DATE', dateTime: _fmtDate(request.startDate)),
          if (request.startTime != null) ...[
            AppSpacing.sVertical,
            Row(
              children: [
                Expanded(
                  child: _DateTimeBlock(label: 'Starts', dateTime: _fmtTime(request.startTime)),
                ),
                AppSpacing.sHorizontal,
                Expanded(
                  child: _DateTimeBlock(
                    label: 'Ends',
                    dateTime: request.endTime != null
                        ? _fmtTime(request.endTime)
                        : (hrs != null ? '+${hrs}h' : '—'),
                  ),
                ),
              ],
            ),
          ],
          if (_sessionLabel(hrs) != null) ...[
            AppSpacing.sVertical,
            Text('${_sessionLabel(hrs)} session', style: kTextNormal0(color: kTextSecondaryColor)),
          ],
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Long Duration Schedule (shift-based day-care)
// ─────────────────────────────────────────────────────────
class _LongDurationSchedule extends StatelessWidget {
  final BookingRequest request;

  const _LongDurationSchedule({required this.request});

  String _fmtDate(DateTime? d) => d == null ? '—' : DateFormat('dd MMM yyyy').format(d);

  String _fmtTime(String? t) {
    if (t == null) return '';
    try {
      final parts = t.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return DateFormat.jm().format(DateTime(2000, 1, 1, h, m));
    } catch (_) {
      return t;
    }
  }

  String get _shiftLabel {
    switch (request.shiftType) {
      case 'day':
        return 'Day Shift';
      case 'night':
        return 'Night Shift';
      case '24_hours':
        return '24 Hours';
      default:
        return request.shiftType ?? 'Standard';
    }
  }

  IconData get _shiftIcon {
    switch (request.shiftType) {
      case 'night':
        return Icons.nightlight_round;
      case '24_hours':
        return Icons.av_timer_rounded;
      default:
        return Icons.wb_sunny_rounded;
    }
  }

  Color get _shiftColor {
    switch (request.shiftType) {
      case 'night':
        return const Color(0xFF5C6BC0);
      case '24_hours':
        return kPrimaryColor;
      default:
        return const Color(0xFFF57C00);
    }
  }

  DateTime _adjustedEndDate() {
    if (request.endDate == null && request.startDate == null) return DateTime.now();
    DateTime d = request.endDate ?? request.startDate!;
    if (request.shiftType == 'night' || request.shiftType == '24_hours') {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final shiftTimeLabel = (request.startTime != null && request.endTime != null)
        ? '${_fmtTime(request.startTime)} – ${_fmtTime(request.endTime)}'
        : null;
    final days = request.durationDays;
    final color = _shiftColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 16.sp, color: kPrimaryColor.withValues(alpha: 0.6)),
            AppSpacing.sHorizontal,
            Text('Schedule', style: kTextNormal0(color: kTextSecondaryColor)),
            const Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppRadius.s,
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_shiftIcon, size: 12.sp, color: color),
                  SizedBox(width: 4.w),
                  Text(_shiftLabel, style: kTextMedium0(color: color)),
                ],
              ),
            ),
          ],
        ),
        AppSpacing.sVertical,

        if (shiftTimeLabel != null) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: AppRadius.m),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time_rounded, size: 14.sp, color: color),
                SizedBox(width: 6.w),
                Text(shiftTimeLabel, style: kTextMedium(color: color)),
              ],
            ),
          ),
          AppSpacing.sVertical,
        ],

        _DateTimeBlock(
          label: 'Starts on',
          dateTime:
              '${_fmtDate(request.startDate)}${request.startTime != null ? '  ·  ${_fmtTime(request.startTime)}' : ''}',
        ),
        AppSpacing.sVertical,
        _DateTimeBlock(
          label: 'Ends on',
          dateTime:
              '${_fmtDate(_adjustedEndDate())}${request.endTime != null ? '  ·  ${_fmtTime(request.endTime)}' : ''}',
        ),

        () {
          // Prefer scheduledDates.length (actual service days, respects alternate/weekly plan)
          // over durationDays (calendar range which can be 2× for alternate).
          final actualDays = request.scheduledDates?.length ?? days;
          if (actualDays == null) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSpacing.sVertical,
              Text(
                '$actualDays day${actualDays > 1 ? 's' : ''} of service',
                style: kTextNormal0(color: kTextSecondaryColor),
              ),
            ],
          );
        }(),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Package Applied Chip
// ─────────────────────────────────────────────────────────
class _PackageAppliedChip extends StatelessWidget {
  final RateCardPackageModel package;

  const _PackageAppliedChip({required this.package});

  @override
  Widget build(BuildContext context) {
    final description = package.description?.isNotEmpty == true ? package.description! : null;
    final label = '${package.duration} ${package.durationType == 'days' ? 'Day' : 'Hour'} Package';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: kSuccessColor.withValues(alpha: 0.08),
        borderRadius: AppRadius.m,
        border: Border.all(color: kSuccessColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_offer_rounded, size: 14.sp, color: kSuccessColor),
              SizedBox(width: 6.w),
              Flexible(
                child: Text(
                  '$label Applied',
                  style: kTextMedium0(color: kSuccessColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          if (description != null)
            Padding(
              padding: AppPadding.xsVertical,
              child: Text(
                description,
                style: kTextMedium0(color: kTextSecondaryColor),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class _DateTimeBlock extends StatelessWidget {
  final String label;
  final String dateTime;

  const _DateTimeBlock({required this.label, required this.dateTime});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppPadding.symmetric(h: 12, v: 8),
      decoration: BoxDecoration(
        color: kScaffoldColor,
        borderRadius: AppRadius.m,
        border: Border.all(color: kBorderColor.withValues(alpha: 0.5)),
      ),
      child: RichText(
        text: TextSpan(
          style: kTextNormal0(color: kTextSecondaryColor),
          children: [
            TextSpan(
              text: '$label:  ',
              style: kTextBold0(color: kTextHintColor),
            ),
            TextSpan(
              text: dateTime,
              style: kTextMedium0(color: kTextPrimaryColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool strikethrough;
  final Color? labelColor;
  final Color? valueColor;

  const _PriceRow({
    required this.label,
    required this.value,
    this.strikethrough = false,
    this.labelColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(label, style: kTextNormal(color: labelColor ?? kTextSecondaryColor)),
        ),
        SizedBox(width: 12.w),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kTextSemiBold(color: valueColor ?? kTextPrimaryColor).copyWith(
              decoration: strikethrough ? TextDecoration.lineThrough : null,
              decorationColor: kTextHintColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16.sp, color: kPrimaryColor.withValues(alpha: 0.8)),
        AppSpacing.sHorizontal,
        Text(label, style: kTextNormal0(color: kTextSecondaryColor)),
        AppSpacing.xsHorizontal,
        Expanded(
          child: Text(
            value,
            style: kTextMedium(color: kTextPrimaryColor),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Address Card
// ─────────────────────────────────────────────────────────
class _AddressCard extends StatelessWidget {
  /// Non-null only when a saved address (with id) is selected.
  final UserAddressModel? selectedAddress;

  /// True when a temporary/searched address is selected but has no saved id.
  final bool hasTempAddress;

  final VoidCallback onTap;

  const _AddressCard({required this.selectedAddress, required this.hasTempAddress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Determine visual state
    final bool hasSaved = selectedAddress != null;
    final Color borderColor = hasSaved
        ? kPrimaryColor
        : hasTempAddress
        ? kWarningColor
        : kBorderColor;
    final double borderWidth = (hasSaved || hasTempAddress) ? 1.5 : 1;
    final Color bgColor = hasSaved
        ? kPrimaryColor.withValues(alpha: 0.04)
        : hasTempAddress
        ? kWarningColor.withValues(alpha: 0.04)
        : kWhiteColor;
    final Color iconColor = hasSaved
        ? kPrimaryColor
        : hasTempAddress
        ? kWarningColor
        : kTextHintColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: AppPadding.l,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: AppRadius.l,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Row(
          children: [
            Container(
              padding: AppPadding.s,
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: AppRadius.s),
              child: Icon(Icons.location_on_rounded, color: iconColor, size: 20.sp),
            ),
            AppSpacing.lHorizontal,
            Expanded(
              child: hasSaved
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedAddress!.shortLabel.isNotEmpty
                              ? selectedAddress!.shortLabel
                              : (selectedAddress!.addressType ?? 'Home'),
                          style: kTextSemiBold(),
                        ),
                        AppSpacing.xsVertical,
                        Text(
                          selectedAddress!.displayAddress,
                          style: kTextNormal0(color: kTextSecondaryColor),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose address',
                          style: kTextSemiBold(color: hasTempAddress ? kWarningColor : kTextHintColor),
                        ),
                        if (hasTempAddress) ...[
                          AppSpacing.xsVertical,
                          Text(
                            'Your current location can\'t be used for booking. Please select a saved address.',
                            style: kTextNormal0(color: kWarningColor.withValues(alpha: 0.85)),
                            maxLines: 2,
                          ),
                        ],
                      ],
                    ),
            ),
            Icon(Icons.chevron_right_rounded, color: kTextSecondaryColor),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Family Member Selector
// ─────────────────────────────────────────────────────────
// class _FamilySelector extends StatelessWidget {
//   final List<FamilyMemberModel> members;
//   final FamilyMemberModel? selected;
//   final ValueChanged<FamilyMemberModel?> onChanged;
//
//   const _FamilySelector({required this.members, this.selected, required this.onChanged});
//
//   @override
//   Widget build(BuildContext context) {
//     // Ensure selected is actually in members list
//     final bool isSelectedInList = selected != null && members.any((m) => m.id == selected!.id);
//     final effectiveValue = isSelectedInList ? selected : (members.isNotEmpty ? members.first : null);
//
//     return Container(
//       padding: AppPadding.symmetric(h: 12, v: 4),
//       decoration: BoxDecoration(
//         color: kWhiteColor,
//         borderRadius: AppRadius.l,
//         border: Border.all(color: kBorderColor),
//         boxShadow: [
//           BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
//         ],
//       ),
//       child: DropdownButtonHideUnderline(
//         child: DropdownButton<FamilyMemberModel?>(
//           value: effectiveValue,
//           isExpanded: true,
//           icon: Icon(Icons.keyboard_arrow_down_rounded, color: kTextSecondaryColor),
//           dropdownColor: kWhiteColor,
//           items: members.map((m) {
//             return DropdownMenuItem<FamilyMemberModel?>(
//               value: m,
//               child: Row(
//                 children: [
//                   Container(
//                     padding: AppPadding.xs,
//                     decoration: BoxDecoration(
//                       color: kPrimaryColor.withValues(alpha: 0.08),
//                       shape: BoxShape.circle,
//                     ),
//                     child: Icon(
//                       Icons.group_rounded,
//                       size: 18.sp,
//                       color: kPrimaryColor,
//                     ),
//                   ),
//                   AppSpacing.mHorizontal,
//                   Text(m.fullName, style: kTextMedium(color: kTextPrimaryColor)),
//                 ],
//               ),
//             );
//           }).toList(),
//           onChanged: onChanged,
//         ),
//       ),
//     );
//   }
// }

// ─────────────────────────────────────────────────────────
//  Instructions Field
// ─────────────────────────────────────────────────────────
class _InstructionsField extends StatelessWidget {
  final TextEditingController controller;

  const _InstructionsField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: AppRadius.l,
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: 4,
        style: kTextNormal(),
        decoration: InputDecoration(
          hintText: 'Any special care notes, medication details, allergies…',
          hintStyle: kTextNormal(color: kTextHintColor),
          border: InputBorder.none,
          contentPadding: AppPadding.l,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Proceed Footer (Find Provider)
// ─────────────────────────────────────────────────────────
class _FooterProceed extends StatelessWidget {
  final BookingRequest request;
  final VoidCallback? onTap;
  final bool isLoading;

  const _FooterProceed({required this.request, required this.onTap, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppButtonHeight.m,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isLoading ? kPrimaryColor.withValues(alpha: 0.7) : kPrimaryColor,
          foregroundColor: kWhiteColor,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.l),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              SizedBox(
                width: 20.sp,
                height: 20.sp,
                child: CircularProgressIndicator(color: kWhiteColor, strokeWidth: 2),
              ),
              SizedBox(width: 8.w),
            ],
            Text(
              isLoading ? 'Creating Request…' : 'Continue & Apply Promo',
              style: kTextBold1(color: kWhiteColor),
            ),
            if (!isLoading) ...[
              SizedBox(width: 8.w),
              Icon(Icons.arrow_forward_rounded, color: kWhiteColor, size: 18.sp),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final Widget? trailing;

  const _SectionLabel({required this.label}) : trailing = null;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: Text(label, style: kTextSemiBold(color: kTextPrimaryColor)),
      ),
      ?trailing,
    ],
  );
}

class _LoadingSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48.h,
      decoration: BoxDecoration(color: kShimmerBaseColor, borderRadius: AppRadius.l),
    );
  }
}
