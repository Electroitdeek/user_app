import 'package:adhisaat_health_care/core/assets/app_assets.dart';
import 'package:adhisaat_health_care/core/constants/app_helpers.dart';
import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_home/bloc/provider_dashboard_bloc/provider_dashboard_bloc.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_home/bloc/provider_dashboard_bloc/provider_dashboard_event.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_home/bloc/provider_dashboard_bloc/provider_dashboard_state.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_home/data/models/provider_dashboard.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_home/data/models/service_request.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/models/provider_service_request_model.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/constants/error_constants.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/message_service.dart';
import '../../../../core/widgets/location_permission_dialog.dart';
import '../../../../data/models/dropdown_response_model.dart';
import '../../../../data/models/provider_models/bank_detail_model.dart';
import '../../document/view/add_provider_document_page.dart';
import '../../../../data/providers/user_profile_provider.dart';
import '../../../../data/repositories/provider_repository.dart';
import '../../../../di/locator.dart';
import '../../../../shared/widgets/shimmer/provider_shimmers.dart';
import '../../../user/address/bloc/selected_address_provider.dart';
import '../../notification/bloc/provider_notification_bloc.dart';
import '../../registration_payment/bloc/registration_fee_payment_bloc.dart';

class ProviderHomePageUI extends HookConsumerWidget {
  const ProviderHomePageUI({super.key});

  // ── Design Tokens ──
  static const _primaryBlue = kPrimaryColor;
  static const _greenOnline = kSuccessColor;
  static const _greyBg = kWhiteColor;
  static const _greyText = kTextSecondaryColor;
  static const _greyBorder = kBorderColor;
  static const _orange = kAccentColor;
  static const _red = kErrorColor;
  static const _teal = Color(0xFF14B8A6);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final razorpay = useMemoized(() => Razorpay());
    final registrationPaymentBloc = useMemoized(() => RegistrationFeePaymentBloc(locator<ProviderRepository>()));

    // ── Location State ──
    final manualAddress = ref.watch(selectedAddressProvider);
    final displayAddress = useState<String>('');
    final isGpsLocation = useState<bool>(false);
    final isLocating = useState<bool>(true);
    final isVerificationExpanded = useState<bool>(false);
    final isKycExpanded = useState<bool>(false);
    final isHoldExpanded = useState<bool>(true);

    // ── Location Fetching Logic ──
    final fetchLocation = useCallback(({bool requestPermission = false}) async {
      if (requestPermission) {
        final granted = await LocationPermissionDialog.show(context);
        if (granted != true) return false;
      }

      displayAddress.value = '';
      isLocating.value = true;

      final locationService = LocationService();

      String getArea(AddressResult res) {
        if (res.placemark != null) {
          final p = res.placemark!;
          final parts = <String>[];
          if (p.subLocality?.isNotEmpty ?? false) parts.add(p.subLocality!);
          if (p.locality?.isNotEmpty ?? false) parts.add(p.locality!);
          if (parts.isNotEmpty) return parts.join(', ');
        }
        return res.formattedAddress ?? '';
      }

      // Fast path: use OS-level last known position
      if (displayAddress.value.isEmpty) {
        try {
          final osPos = await Geolocator.getLastKnownPosition();
          if (osPos != null) {
            final addrResult = await locationService.getAddressFromCoordinates(
              latitude: osPos.latitude,
              longitude: osPos.longitude,
            );
            if (addrResult.isSuccess && addrResult.formattedAddress != null) {
              displayAddress.value = getArea(addrResult);
              isGpsLocation.value = true;
            }
          }
        } catch (_) {}
      }

      // Then fetch a fresh accurate position
      final positionResult = await locationService.getCurrentLocation(requestPermission: requestPermission);
      if (positionResult.isSuccess && positionResult.position != null) {
        final addressResult = await locationService.getAddressFromCoordinates(
          latitude: positionResult.position!.latitude,
          longitude: positionResult.position!.longitude,
        );
        if (addressResult.isSuccess && addressResult.formattedAddress != null) {
          displayAddress.value = getArea(addressResult);
          isGpsLocation.value = true;
          isLocating.value = false;
          return true;
        }
      }

      // Fallback to manual address
      if (manualAddress != null) {
        displayAddress.value = [
          manualAddress.area,
          manualAddress.city,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
        if (displayAddress.value.isEmpty) displayAddress.value = manualAddress.fullAddress;
        isGpsLocation.value = false;
      } else if (displayAddress.value.isEmpty) {
        displayAddress.value = 'Location not set';
        isGpsLocation.value = false;
      }
      isLocating.value = false;
      return false;
    }, [manualAddress]);

    useEffect(() {
      // Immediately show manual address if GPS not yet resolved — no async needed
      if (manualAddress != null && displayAddress.value.isEmpty) {
        displayAddress.value = [
          manualAddress.area,
          manualAddress.city,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
        if (displayAddress.value.isEmpty) displayAddress.value = manualAddress.fullAddress;
        isGpsLocation.value = false;
        isLocating.value = false;
      }
      fetchLocation(requestPermission: false);
      return null;
    }, [manualAddress]);

    useEffect(() {
      Future.microtask(() async {
        final status = await Permission.location.status;
        if (!status.isGranted && !status.isLimited) {
          if (context.mounted) {
            context.read<ProviderDashboardBloc>().add(ToggleAvailabilityEvent(isOnline: false));
          }
        }
      });
      return null;
    }, []);
    useEffect(() {
      razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
        registrationPaymentBloc.add(
          RazorpayRegistrationSuccessEvent(
            paymentId: r.paymentId ?? '',
            orderId: r.orderId ?? '',
            signature: r.signature ?? '',
          ),
        );
      });
      razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
        if (r.code == 2 || r.message?.toLowerCase().contains('cancelled') == true) return;
        kPrint(r.toString());
        kPrint(r.message);
        registrationPaymentBloc.add(RazorpayRegistrationFailureEvent(r.message));
      });
      razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {});

      return () => razorpay.clear();
    }, [razorpay]);

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => locator<ProviderNotificationBloc>()..add(FetchProviderNotifications())),
        BlocProvider.value(value: registrationPaymentBloc),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<RegistrationFeePaymentBloc, RegistrationFeePaymentState>(
            listener: (context, state) {
              if (state is RegistrationFeePaymentInitiated) {
                razorpay.open(state.razorpayOptions);
              } else if (state is RegistrationFeePaymentSuccess) {
                MessageService.showSuccess('Registration fee paid successfully!');
                context.read<ProviderDashboardBloc>().add(RefreshDashboardEvent());
              } else if (state is RegistrationFeePaymentError) {
                MessageService.showError(state.message);
              }
            },
          ),
          BlocListener<ProviderDashboardBloc, ProviderDashboardState>(
            listener: (context, state) {
              if (state is ProviderDashboardLoaded) {
                final profile = state.profile.serviceProviderProfile;
                if (profile != null && !profile.isRegistrationFeePaid) {
                  final fee = NumberUtils.toDouble(profile.registrationFee);
                  if (fee > 0) {
                    _showRegistrationFeeDialog(context, fee);
                  }
                }
              }
            },
          ),
        ],
        child: Scaffold(
          backgroundColor: kWhiteColor,
          body: BlocConsumer<ProviderDashboardBloc, ProviderDashboardState>(
            listener: _blocListener,
            builder: (context, state) {
              if (state is ProviderDashboardInitial || state is ProviderDashboardLoading) {
                return const SafeArea(child: DashboardShimmer());
              }

              // Extract dashboard data
              final ProviderDashboardLoaded? dashboardState = state is ProviderDashboardLoaded
                  ? state
                  : state is RequestAccepted
                  ? state.dashboardData
                  : state is RequestExpired
                  ? state.dashboardData
                  : state is NewRequestReceived
                  ? state.dashboardData
                  : state is ProviderDashboardError
                  ? state.dashboardData
                  : null;

              if (dashboardState != null) {
                return Column(
                  children: [
                    _buildFixedHeader(
                      context,
                      dashboardState,
                      displayAddress.value,
                      isGpsLocation.value,
                      isLocating.value,
                      () => fetchLocation(requestPermission: true),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        color: _primaryBlue,
                        onRefresh: () async {
                          context.read<ProviderDashboardBloc>().add(RefreshDashboardEvent());
                          context.read<ProviderNotificationBloc>().add(FetchProviderNotifications());
                        },
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverPadding(
                              padding: AppPadding.symmetric(h: 16, v: 16),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate([
                                  _buildRegistrationFeeNotice(context, dashboardState),

                                  _buildHeroCard(
                                    context,
                                    dashboardState,
                                    isLocationEnabled: isGpsLocation.value,
                                    isLocating: isLocating.value,
                                    onFetchLocation: fetchLocation,
                                  ),
                                  SizedBox(height: 20.h),
                                  _buildKycPendingBanner(
                                    context,
                                    dashboardState,
                                    isVerificationExpanded: isVerificationExpanded,
                                    isKycExpanded: isKycExpanded,
                                    isHoldExpanded: isHoldExpanded,
                                  ),
                                  _buildQuickActions(context),
                                  SizedBox(height: 20.h),
                                  _buildEarningsRow(dashboardState.dashboard.earnings),
                                  kSizedBox(height: 20),
                                  _buildBookingOverview(dashboardState.dashboard.booking),
                                  kSizedBox(height: 20),
                                  _buildRecentRequestsSection(context, dashboardState),
                                  kSizedBox(height: 10),
                                ]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              if (state is ProviderDashboardError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      kSizedBox(height: 16),
                      Text(state.message, style: kTextMedium(), textAlign: TextAlign.center),
                      kSizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () =>
                            context.read<ProviderDashboardBloc>().add(LoadProviderDashboard(forceRefresh: true)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              // Handle transient states (RequestExpired, etc.) when dashboard data is not yet available
              if (state is RequestExpired || state is RequestAccepted || state is NewRequestReceived) {
                return const SafeArea(child: DashboardShimmer());
              }

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info_outline, color: _primaryBlue, size: 48),
                    kSizedBox(height: 16),
                    Text('Setting things up...', style: kTextMedium()),
                    kSizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () =>
                          context.read<ProviderDashboardBloc>().add(LoadProviderDashboard(forceRefresh: true)),
                      child: const Text('Reload Dashboard'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ──────────────────── REGISTRATION DIALOG ────────────────────
  static bool _sessionDismissed = false;

  void _showRegistrationFeeDialog(BuildContext context, double fee) {
    if (_sessionDismissed) return;
    _sessionDismissed = true;

    // We must provide the Bloc to the dialog since showDialog uses a new route/context
    final registrationPaymentBloc = context.read<RegistrationFeePaymentBloc>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BlocProvider.value(
        value: registrationPaymentBloc,
        child: RegistrationFeeDialog(fee: fee),
      ),
    );
  }

  // ──────────────────── BLOC LISTENER ────────────────────
  void _blocListener(BuildContext context, ProviderDashboardState state) {
    kPrint(state);
    if (state is ProviderDashboardLoaded) {
      // Sync profile with Riverpod userProfileProvider
      final ref = ProviderScope.containerOf(context, listen: false);
      ref.read(userProfileProvider.notifier).state = state.profile;
    }
    if (state is RequestExpired) {
      MessageService.showWarning('Request expired');
    } else if (state is RequestAccepted) {
      final requestId = int.tryParse(state.requestId) ?? state.request.bookingId;
      if (state.request.isEmergency) {
        Navigator.of(context).pushNamed(AppRoutes.providerRequestDetail, arguments: requestId);
      } else {
        MessageService.showSuccess('✅ Request accepted!');
        // Navigate even for normal requests as requested "always navigate it to request detail page"
        Navigator.of(context).pushNamed(AppRoutes.providerRequestDetail, arguments: requestId);
        context.read<ProviderDashboardBloc>().add(RefreshDashboardEvent());
      }
    } else if (state is ProviderDashboardError) {
      // Suppress the hard error toast for transient connectivity failures
      // (e.g. the brief network blip when the app returns from background).
      // The OfflineBanner already surfaces connectivity state to the user.
      final isConnectivityError = state.message == ErrorConstants.networkError ||
          state.message == ErrorConstants.timeoutError;
      if (!isConnectivityError) {
        MessageService.showError('❌ ${state.message}');
      }
    }
  }

  // ── REDESIGNED FIXED HEADER ──
  Widget _buildFixedHeader(
    BuildContext context,
    ProviderDashboardLoaded state,
    String location,
    bool isGps,
    bool isLocating,
    VoidCallback onEnableGps,
  ) {
    return Container(
      color: kWhiteColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                AppAssets.logoLandscape,
                height: 32.h,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Text(
                  'Adhisaat',
                  style: kTextBold(color: kPrimaryColor).copyWith(fontSize: 20.sp),
                ),
              ),
              SizedBox(width: 12.w),

              // Location Dropdown (Mini)
              GestureDetector(
                onTap: isGps ? null : onEnableGps,
                child: Container(
                  constraints: BoxConstraints(maxWidth: 160.w),
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(color: kGreyColor, borderRadius: BorderRadius.circular(20.r)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_rounded, color: isGps ? kPrimaryColor : _red, size: 12.sp),
                      SizedBox(width: 4.w),
                      Flexible(
                        child: Text(
                          isLocating && location.isEmpty ? 'Detecting...' : (isGps ? location : 'Manual'),
                          style: kTextSemiBold(color: isGps ? kTextPrimaryColor : _red).copyWith(fontSize: 10.sp),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),

              // Notifications
              BlocBuilder<ProviderNotificationBloc, ProviderNotificationState>(
                builder: (context, notificationState) {
                  int unreadCount = 0;
                  if (notificationState is ProviderNotificationLoaded) {
                    unreadCount = notificationState.unreadCount;
                  }
                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kGreyColor,
                          border: Border.all(color: kBorderColor.withValues(alpha: 0.5)),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.notifications_outlined, color: kTextPrimaryColor, size: 20.sp),
                          onPressed: () async {
                            await AppNavigator.to(AppRoutes.providerNotification);
                            if (context.mounted) {
                              context.read<ProviderNotificationBloc>().add(FetchProviderNotifications());
                            }
                          },
                        ),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            width: 8.w,
                            height: 8.w,
                            decoration: const BoxDecoration(color: kErrorColor, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────── REGISTRATION FEE NOTICE ────────────────────
  Widget _buildRegistrationFeeNotice(BuildContext context, ProviderDashboardLoaded state) {
    final profile = state.profile.serviceProviderProfile;
    if (profile == null) return const SizedBox.shrink();

    final fee = NumberUtils.toDouble(profile.registrationFee);
    final isPaid = profile.isRegistrationFeePaid;

    // Condition: fee > 0 OR not paid
    // But if it is paid, we don't show the notice even if fee > 0.
    // So logic is: if (!isPaid)
    if (!isPaid && fee <= 0) return const SizedBox.shrink();
    if (isPaid) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: AppPadding.all(16),
      decoration: BoxDecoration(
        color: _red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _red.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment_rounded, color: _red, size: 20.sp),
              kSizedBox(width: 10),
              Expanded(
                child: Text('Complete Your Registration', style: kTextSemiBold1(color: _red)),
              ),
            ],
          ),
          kSizedBox(height: 8),
          Text(
            fee > 0
                ? 'A registration fee of ${NumberUtils.formatCurrency(fee)} is required to activate your account. Please pay to continue.'
                : 'Your registration is incomplete. Please pay the registration fee to complete your profile.',
            style: kTextNormal0(color: _red.withValues(alpha: 0.8)),
          ),
          kSizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40.h,
            child: BlocBuilder<RegistrationFeePaymentBloc, RegistrationFeePaymentState>(
              builder: (context, payState) {
                return ElevatedButton(
                  onPressed: payState is RegistrationFeePaymentLoading
                      ? null
                      : () {
                          _sessionDismissed = false;
                          _showRegistrationFeeDialog(context, fee);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: payState is RegistrationFeePaymentLoading
                      ? SizedBox(
                          height: 18.w,
                          width: 18.w,
                          child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Pay Registration Fee', style: kTextSemiBold0(color: Colors.white)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────── KYC PENDING BANNER ────────────────────
  Widget _buildKycPendingBanner(
    BuildContext context,
    ProviderDashboardLoaded dashboardState, {
    required ValueNotifier<bool> isVerificationExpanded,
    required ValueNotifier<bool> isKycExpanded,
    required ValueNotifier<bool> isHoldExpanded,
  }) {
    final profile = dashboardState.profile;
    final sp = profile.serviceProviderProfile;
    final dashboard = dashboardState.dashboard;

    final aadharStatus = profile.aadharVerified;
    final panStatus = profile.panVerified;
    final aadharBad = aadharStatus == 'pending' || aadharStatus == 'rejected';
    final panBad = panStatus == 'pending' || panStatus == 'rejected';

    final verStatus = sp?.verificationStatus;
    final profileRejected = verStatus == 'rejected';
    final profileOnHold = verStatus == 'hold';
    final adminRemarks = sp?.adminRemarks;
    final hasRemarks = adminRemarks != null && adminRemarks.isNotEmpty;

    final requiredNotUploaded = dashboard.documentsNotUploaded.where((doc) => doc.isRequired).toList();
    final hasNoBankDetail = dashboard.bankDetail == null || dashboard.bankDetail!.accountNumber.trim().isEmpty;

    final showKyc = aadharBad || panBad;
    final showPending = requiredNotUploaded.isNotEmpty || hasNoBankDetail;

    if (!showKyc && !showPending && !profileRejected && !profileOnHold) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Column(
        children: [
          // Profile verification rejected banner
          if (profileRejected) ...[
            _buildAlertCard(
              context,
              title: 'Verification Rejected',
              subtitle: hasRemarks ? 'Reason: $adminRemarks' : 'Your profile verification was not successful.',
              icon: Icons.error_outline_rounded,
              color: kErrorColor,
              actionLabel: 'Update Profile',
              onTap: () => _navigateToEdit(context),
              isExpanded: isVerificationExpanded.value,
              onToggle: () => isVerificationExpanded.value = !isVerificationExpanded.value,
            ),
            if (profileOnHold || showPending || showKyc) SizedBox(height: 12.h),
          ],

          // Hold banner
          if (profileOnHold) ...[
            _buildAlertCard(
              context,
              title: 'Profile On Hold',
              subtitle: hasRemarks ? adminRemarks : 'Your account is currently under review.',
              icon: Icons.pause_circle_outline_rounded,
              color: kAccentColor,
              actionLabel: 'Contact Support',
              onTap: () => AppNavigator.to(AppRoutes.needHelp),
              isExpanded: isHoldExpanded.value,
              onToggle: () => isHoldExpanded.value = !isHoldExpanded.value,
            ),
            if (showPending || showKyc) SizedBox(height: 12.h),
          ],

          // New Pending Details Card (Required docs not uploaded & missing bank details)
          if (showPending) ...[
            _buildPendingDetailsCard(
              context,
              requiredNotUploaded: requiredNotUploaded,
              hasNoBankDetail: hasNoBankDetail,
              bankDetail: dashboard.bankDetail,
            ),
            if (showKyc) SizedBox(height: 12.h),
          ],

          // KYC doc status banner (Aadhaar & PAN status only)
          if (showKyc) ...[
            _buildKycStatusCard(
              context,
              aadharStatus: aadharStatus,
              panStatus: panStatus,
              aadharBad: aadharBad,
              panBad: panBad,
              isExpanded: isKycExpanded.value,
              onToggle: () => isKycExpanded.value = !isKycExpanded.value,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? actionLabel,
    VoidCallback? onTap,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            borderRadius: BorderRadius.circular(16.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 18.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      title,
                      style: kTextBold(color: color).copyWith(fontSize: 14.sp),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: color, size: 18.sp),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 30.w + 6.r), // Reduced offset
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subtitle,
                                style: kTextNormal(
                                  color: color.withValues(alpha: 0.8),
                                ).copyWith(fontSize: 12.sp, height: 1.3),
                              ),
                              if (actionLabel != null) ...[
                                SizedBox(height: 10.h),
                                InkWell(
                                  onTap: onTap,
                                  borderRadius: BorderRadius.circular(6.r),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(6.r),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          actionLabel,
                                          style: kTextSemiBold(color: Colors.white).copyWith(fontSize: 11.sp),
                                        ),
                                        SizedBox(width: 4.w),
                                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 12.sp),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingDetailsCard(
    BuildContext context, {
    required List<DynamicDocumentType> requiredNotUploaded,
    required bool hasNoBankDetail,
    BankDetail? bankDetail,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: kAccentColor.withValues(alpha: 0.15), width: 1),
        boxShadow: [BoxShadow(color: kAccentColor.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pending_actions_rounded,
                  color: kAccentColor,
                  size: 18.sp,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Pending Document Uploads',
                    style: kTextBold(color: kAccentColor).copyWith(fontSize: 14.sp),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              'Please update these details to complete your account verification.',
              style: kTextNormal0(color: Colors.orange[850]).copyWith(fontSize: 12.sp, height: 1.3),
            ),
            SizedBox(height: 12.h),
            Divider(color: kAccentColor.withValues(alpha: 0.1), height: 1),
            SizedBox(height: 8.h),

            // Dynamic documents that are required and not uploaded
            for (int i = 0; i < requiredNotUploaded.length; i++) ...[
              _kycActionRow(
                context,
                requiredNotUploaded[i].name,
                () {
                  AppNavigator.push(
                    AddProviderDocumentPage(
                      dynamicDocumentTypes: requiredNotUploaded,
                      initialSelectedType: requiredNotUploaded[i].key,
                    ),
                  ).then((result) {
                    if (result == true && context.mounted) {
                      context.read<ProviderDashboardBloc>().add(RefreshDashboardEvent());
                    }
                  });
                },
              ),
              if (i < requiredNotUploaded.length - 1 || hasNoBankDetail)
                SizedBox(height: 6.h),
            ],

            // Bank details
            if (hasNoBankDetail) ...[
              _kycActionRow(
                context,
                'Bank Account Detail',
                () {
                  AppNavigator.to(
                    AppRoutes.providerBankDetailAddEdit,
                    arguments: bankDetail,
                  ).then((_) {
                    if (context.mounted) {
                      context.read<ProviderDashboardBloc>().add(RefreshDashboardEvent());
                    }
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKycStatusCard(
    BuildContext context, {
    String? aadharStatus,
    String? panStatus,
    required bool aadharBad,
    required bool panBad,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    final isRejected = aadharStatus == 'rejected' || panStatus == 'rejected';
    final color = isRejected ? kErrorColor : kAccentColor;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            borderRadius: BorderRadius.circular(16.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              child: Row(
                children: [
                  Icon(
                    isRejected ? Icons.warning_amber_rounded : Icons.hourglass_empty_rounded,
                    color: color,
                    size: 18.sp,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'KYC Document Status',
                      style: kTextBold(color: color).copyWith(fontSize: 14.sp),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: color, size: 18.sp),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (aadharBad) _kycDocRow('Aadhaar', aadharStatus),
                        if (aadharBad && panBad) SizedBox(height: 6.h),
                        if (panBad) _kycDocRow('PAN', panStatus),
                        if (isRejected) ...[
                          SizedBox(height: 12.h),
                          Divider(color: color.withValues(alpha: 0.1), height: 1),
                          SizedBox(height: 10.h),
                          GestureDetector(
                            onTap: () => _navigateToEdit(context),
                            child: Row(
                              children: [
                                Text(
                                  'Resolve Documents',
                                  style: kTextSemiBold(color: color).copyWith(fontSize: 12.sp),
                                ),
                                SizedBox(width: 4.w),
                                Icon(Icons.arrow_forward_rounded, color: color, size: 12.sp),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }

  Widget _kycActionRow(
    BuildContext context,
    String name,
    VoidCallback onAdd,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(
            Icons.add_circle_outline_rounded,
            color: kErrorColor.withValues(alpha: 0.7),
            size: 16.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              name,
              style: kTextMedium().copyWith(fontSize: 13.sp, color: Colors.grey[800]),
            ),
          ),
          SizedBox(
            height: 28.h,
            child: ElevatedButton(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6.r),
                ),
              ),
              child: Text(
                'Add',
                style: kTextBold0(color: Colors.white).copyWith(fontSize: 11.sp),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kycDocRow(String docName, String? status) {
    final isRejected = status == 'rejected';
    final color = isRejected ? kErrorColor : kAccentColor;
    final label = isRejected ? 'Rejected – Action required' : 'Pending';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8.r)),
      child: Row(
        children: [
          Icon(isRejected ? Icons.cancel_outlined : Icons.schedule_rounded, size: 12.sp, color: color),
          SizedBox(width: 6.w),
          Text(
            '$docName: ',
            style: kTextSemiBold(color: color).copyWith(fontSize: 11.sp),
          ),
          Expanded(
            child: Text(
              label,
              style: kTextNormal(color: color.withValues(alpha: 0.9)).copyWith(fontSize: 12.sp),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToEdit(BuildContext context) {
    AppNavigator.to(AppRoutes.providerEditProfile).then((result) {
      if (result == true && context.mounted) {
        context.read<ProviderDashboardBloc>().add(RefreshDashboardEvent());
      }
    });
  }

  // ──────────────────── HERO CARD & QUICK ACTIONS ────────────────────
  Widget _buildHeroCard(
    BuildContext context,
    ProviderDashboardLoaded state, {
    required bool isLocationEnabled,
    required bool isLocating,
    required Future<bool> Function({bool requestPermission}) onFetchLocation,
  }) {
    if (isLocating) {
      return ShimmerBox(height: 120.h, borderRadius: 24.r);
    }
    final profile = state.profile.serviceProviderProfile;
    if (profile == null) return const SizedBox.shrink();

    final isOnline = state.isOnline;
    final isActive = profile.isActive;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryColor, const Color(0xFF1E40AF), const Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(color: kPrimaryColor.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: Stack(
          children: [
            Positioned(
              right: -30.w,
              top: -40.h,
              child: Container(
                width: 140.w,
                height: 140.w,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            Positioned(
              left: -40.w,
              bottom: -20.h,
              child: Container(
                width: 120.w,
                height: 120.w,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 56.w,
                        height: 56.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: ClipOval(
                          child: state.profile.profileImageUrl != null
                              ? AppCachedImage(imageUrl: state.profile.profileImageUrl, fit: BoxFit.cover)
                              : Center(
                                  child: Text(
                                    Helpers.initials(state.profile.name),
                                    style: kTextBold(color: kPrimaryColor).copyWith(fontSize: 18.sp),
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.profile.name,
                              style: kTextBold(color: Colors.white).copyWith(fontSize: 18.sp),
                            ),
                            SizedBox(height: 4.h),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12.w,
                              runSpacing: 4.h,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_rounded, color: const Color(0xFFFFC107), size: 16.sp),
                                    SizedBox(width: 4.w),
                                    Text(
                                      (NumberUtils.toDouble(profile.rating) > 0)
                                          ? NumberUtils.toDouble(profile.rating).toStringAsFixed(1)
                                          : 'No rating',
                                      style: kTextSemiBold(color: Colors.white).copyWith(fontSize: 14.sp),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isActive ? Icons.verified_rounded : Icons.pending_rounded,
                                        color: Colors.white,
                                        size: 12.sp,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        isActive ? 'Verified' : 'Unverified',
                                        style: kTextSemiBold(color: Colors.white).copyWith(fontSize: 10.sp),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12.r,
                          height: 12.r,
                          decoration: BoxDecoration(
                            color: isOnline && isActive ? _greenOnline : Colors.grey[400],
                            shape: BoxShape.circle,
                            boxShadow: [
                              if (isOnline && isActive)
                                BoxShadow(
                                  color: _greenOnline.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                !isActive ? 'Account Inactive' : (isOnline ? 'You are Online' : 'You are Offline'),
                                style: kTextBold(
                                  color: !isActive ? _red : kTextPrimaryColor,
                                ).copyWith(fontSize: 14.sp),
                              ),
                              Text(
                                !isActive
                                    ? 'Contact support'
                                    : (isOnline ? 'Receiving new requests' : 'Go online to get requests'),
                                style: kTextMedium(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: isOnline && isActive,
                          activeThumbColor: _greenOnline,
                          activeTrackColor: _greenOnline.withValues(alpha: 0.2),
                          onChanged: !isActive
                              ? null
                              : (value) async {
                                  if (value) {
                                    final success = await onFetchLocation(requestPermission: !isLocationEnabled);
                                    if (!success) return;
                                    if (!context.mounted) return;
                                  }
                                  context.read<ProviderDashboardBloc>().add(
                                    ToggleAvailabilityEvent(isOnline: value),
                                  );
                                },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: kTextBold1()),
        SizedBox(height: 12.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _QuickActionBtn(
              icon: Icons.list_alt_rounded,
              label: 'Requests',
              color: _primaryBlue,
              onTap: () => AppNavigator.to(AppRoutes.providerRequestList, arguments: 'new_request'),
            ),
            _QuickActionBtn(
              icon: Icons.calendar_month_rounded,
              label: 'Schedule',
              color: _teal,
              onTap: () =>
                  AppNavigator.to(AppRoutes.providerSchedule), // Navigate to same for now, or specific tab
            ),
            _QuickActionBtn(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Earnings',
              color: _orange,
              onTap: () => AppNavigator.to(AppRoutes.providerEarningsList),
            ),
            _QuickActionBtn(
              icon: Icons.help_outline_rounded,
              label: 'Support',
              color: kTextSecondaryColor,
              onTap: () => AppNavigator.to(AppRoutes.needHelp),
            ),
          ],
        ),
      ],
    );
  }

  // ──────────────────── EARNINGS ROW ────────────────────
  Widget _buildEarningsRow(DashboardEarnings earnings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Earnings Overview', style: kTextBold1()),
        kSizedBox(height: 12),
        GestureDetector(
          onTap: () => AppNavigator.to(AppRoutes.providerEarningsList),
          child: Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: _greyBorder.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: _greenOnline.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.account_balance_wallet_rounded, color: _greenOnline, size: 28.sp),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Today\'s Earnings',
                            style: kTextMedium(color: _greyText).copyWith(fontSize: 12.sp),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            NumberUtils.formatCurrency(earnings.today),
                            style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 24.sp),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, color: _greyText, size: 16.sp),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: Divider(color: _greyBorder.withValues(alpha: 0.5), height: 1),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'This Week',
                            style: kTextMedium(color: _greyText).copyWith(fontSize: 11.sp),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            NumberUtils.formatCurrency(earnings.weekly),
                            style: kTextBold(color: _primaryBlue).copyWith(fontSize: 14.sp),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 30.h, color: _greyBorder.withValues(alpha: 0.5)),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: 16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'This Month',
                              style: kTextMedium(color: _greyText).copyWith(fontSize: 11.sp),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              NumberUtils.formatCurrency(earnings.monthly),
                              style: kTextBold(color: _orange).copyWith(fontSize: 14.sp),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ──────────────────── BOOKING OVERVIEW ────────────────────
  Widget _buildBookingOverview(BookingStats booking) {
    final total = booking.completed + booking.inProgress + booking.upcoming;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text('Job Summary', style: kTextBold1())),
            Text(
              '$total Total Jobs',
              style: kTextSemiBold(color: _primaryBlue).copyWith(fontSize: 12.sp),
            ),
          ],
        ),
        kSizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PerformanceStat(
                label: 'Completed',
                count: booking.completed,
                color: _greenOnline,
                icon: Icons.done_all_rounded,
                onTap: () => AppNavigator.to(AppRoutes.providerRequestList, arguments: 'past'),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _PerformanceStat(
                label: 'In Progress',
                count: booking.inProgress,
                color: _orange,
                icon: Icons.sync_rounded,
                onTap: () => AppNavigator.to(AppRoutes.providerRequestList, arguments: 'ongoing'),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _PerformanceStat(
                label: 'Upcoming',
                count: booking.upcoming,
                color: _teal,
                icon: Icons.event_available_rounded,
                onTap: () => AppNavigator.to(AppRoutes.providerRequestList, arguments: 'ongoing'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ──────────────────── RECENT REQUESTS ────────────────────
  Widget _buildRecentRequestsSection(BuildContext context, ProviderDashboardLoaded state) {
    final requests = state.recentRequests;
    if (requests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        kSizedBox(height: 16),
        Text('Recent Service Requests', style: kTextBold1()),
        kSizedBox(height: 12),
        ...requests.map((req) => _buildRecentRequestCard(context, req)),
      ],
    );
  }

  Widget _buildRecentRequestCard(BuildContext context, ProviderServiceRequestModel request) {
    bool isPending =
        request.requestStatus.toLowerCase() == 'searching' || request.requestStatus.toLowerCase() == 'pending';
    final statusColor = _getStatusColor(request.requestStatus);

    return GestureDetector(
      onTap: () async {
        await AppNavigator.to(AppRoutes.providerRequestDetail, arguments: request.id);
        if (context.mounted) {
          context.read<ProviderDashboardBloc>().add(RefreshDashboardEvent());
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: _greyBorder.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            // Header with Service Name & Status
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48.h,
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: (request.isEmergency == 1 ? _red : _primaryBlue).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Icon(
                      request.isEmergency == 1 ? Icons.emergency_rounded : Icons.medical_services_rounded,
                      color: request.isEmergency == 1 ? _red : _primaryBlue,
                      size: 24.sp,
                    ),
                  ),
                  kSizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.serviceCategoryName,
                          style: kTextBold1(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        kSizedBox(height: 2),
                        Text(
                          request.customerName.isNotEmpty ? request.customerName : 'ID: ${request.requestNumber}',
                          style: kTextNormal0(color: _greyText),
                        ),
                      ],
                    ),
                  ),
                  kSizedBox(width: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(_getStatusLabel(request.requestStatus), style: kTextSemiBold0(color: statusColor)),
                  ),
                ],
              ),
            ),

            // Date, Time & Distance Info
            Container(
              margin: EdgeInsets.symmetric(horizontal: 12.w),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: _greyBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  _buildIconInfo(Icons.calendar_today_rounded, request.startDateText),
                  kSizedBox(width: 16),
                  _buildIconInfo(Icons.access_time_filled_rounded, request.startTimeText),
                  const Spacer(),
                  if (request.distanceKm > 0)
                    _buildIconInfo(Icons.location_on_rounded, '${request.distanceKm.toStringAsFixed(1)} km'),
                ],
              ),
            ),

            // Emergency Badge & Bottom Actions
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                children: [
                  if (request.isEmergency == 1) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      margin: EdgeInsets.only(bottom: 12.h),
                      decoration: BoxDecoration(
                        color: _red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: _red.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warning_rounded, color: _red, size: 16.sp),
                          kSizedBox(width: 8),
                          Text('HIGH PRIORITY EMERGENCY', style: kTextBold0(color: _red)),
                        ],
                      ),
                    ),
                  ],

                  if (isPending)
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              context.read<ProviderDashboardBloc>().add(
                                RejectRequestEvent(requestId: request.id.toString()),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: _red,
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                side: BorderSide(color: _red.withValues(alpha: 0.2)),
                              ),
                            ),
                            child: Text('Decline', style: kTextSemiBold1()),
                          ),
                        ),
                        kSizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final serviceReq = ServiceRequest.fromProviderRequest(request);
                              context.read<ProviderDashboardBloc>().add(
                                AcceptRequestEvent(requestId: request.id.toString(), request: serviceReq),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _greenOnline,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                              elevation: 0,
                            ),
                            child: Text('Accept Request', style: kTextBold1()),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('View Details', style: kTextMedium0(color: _primaryBlue)),
                        kSizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded, size: 12.sp, color: _primaryBlue),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconInfo(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.sp, color: _greyText),
        kSizedBox(width: 6),
        Text(label, style: kTextMedium0(color: const Color(0xFF374151))),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'searching':
      case 'pending':
      case 'upcoming':
        return _primaryBlue;
      case 'accepted':
      case 'completed':
        return _greenOnline;
      case 'in_progress':
        return _orange;
      case 'cancelled':
        return _red;
      default:
        return _greyText;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'searching':
      case 'pending':
        return 'New Request';
      case 'upcoming':
        return 'Upcoming';
      case 'accepted':
        return 'Accepted';
      case 'in_progress':
        return 'Ongoing';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.replaceAll('_', ' ');
    }
  }
}

class RegistrationFeeDialog extends StatelessWidget {
  final double fee;

  const RegistrationFeeDialog({super.key, required this.fee});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28.r),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.15), offset: const Offset(0, 10), blurRadius: 30),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28.r),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Gradient
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 24.h),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2D62ED), Color(0xFF1A3FA0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                        ),
                        child: Icon(Icons.currency_rupee, color: Colors.white, size: 38.sp),
                      ),
                      SizedBox(height: 12.h),
                      Text('Payment Required', style: kTextBold2(color: Colors.white)),
                    ],
                  ),
                ),

                Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 32.h),
                  child: Column(
                    children: [
                      Text(
                        'To complete your registration and start receiving service requests, a one-time registration fee is required.',
                        style: kTextNormal1(color: const Color(0xFF4B5563)),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24.h),

                      Container(
                        padding: EdgeInsets.all(20.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(18.r),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('One-time Fee', style: kTextNormal0(color: const Color(0xFF6B7280))),
                                  SizedBox(height: 4.h),
                                  Text('Payment Amount', style: kTextSemiBold1(color: const Color(0xFF1F2937))),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              NumberUtils.formatCurrency(fee),
                              style: kTextBold3(color: const Color(0xFF2D62ED)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 32.h),

                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                ProviderHomePageUI._sessionDismissed = false;
                                Navigator.pop(context);
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 14.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                                ),
                              ),
                              child: Text('Later', style: kTextMedium1(color: const Color(0xFF6B7280))),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: BlocBuilder<RegistrationFeePaymentBloc, RegistrationFeePaymentState>(
                              builder: (context, state) {
                                return ElevatedButton(
                                  onPressed: state is RegistrationFeePaymentLoading
                                      ? null
                                      : () {
                                          ProviderHomePageUI._sessionDismissed = true;
                                          context.read<RegistrationFeePaymentBloc>().add(
                                            InitiateRegistrationFeePaymentEvent(fee),
                                          );
                                          Navigator.pop(context);
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2D62ED),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 14.h),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                  ),
                                  child: state is RegistrationFeePaymentLoading
                                      ? SizedBox(
                                          height: 20.w,
                                          width: 20.w,
                                          child: const CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text('Pay Now', style: kTextBold1(color: Colors.white)),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: kTextMedium(color: kTextPrimaryColor).copyWith(fontSize: 11.sp),
          ),
        ],
      ),
    );
  }
}

class _PerformanceStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _PerformanceStat({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: kBorderColor.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22.sp),
            SizedBox(height: 8.h),
            Text(
              count.toString(),
              style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 18.sp),
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: kTextMedium(color: kTextSecondaryColor).copyWith(fontSize: 10.sp),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
