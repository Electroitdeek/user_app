import 'dart:async';

import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/assets/app_assets.dart';
import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/services/location_service.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/theme/screen_dimensions.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/core/utils/message_service.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/core/widgets/location_permission_dialog.dart';
import 'package:adhisaat_health_care/data/providers/promo_codes_provider.dart';
import 'package:adhisaat_health_care/data/providers/system_settings_provider.dart';
import 'package:adhisaat_health_care/features/user/address/bloc/selected_address_provider.dart';
import 'package:adhisaat_health_care/features/user/booking_history/helper/request_status_helper.dart';
import 'package:adhisaat_health_care/features/user/booking_history/helper/reschedule_helper.dart';
import 'package:adhisaat_health_care/features/user/home/view/search_address_page.dart';
import 'package:adhisaat_health_care/features/user/payment/view/booking_payment_page.dart';
import 'package:adhisaat_health_care/features/user/service_booking/view/service_booking_flow.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/storage/local_storage_service.dart';
import '../../../../data/models/dropdown_response_model.dart';
import '../../../../data/models/user_profile_model.dart';
import '../../../../data/providers/service_availability_provider.dart';
import '../../../../data/providers/user_profile_provider.dart';
import '../../../../di/locator.dart';
import '../../../../features/user/profile/data/user_profile_repository.dart';
import '../../../../shared/widgets/common/no_service_view.dart';
import '../../../../shared/widgets/shimmer/user_shimmers.dart';
import '../../../auth/login/bloc/auth_bloc.dart';
import '../../booking_history/model/booking_detail_model.dart';
import '../../booking_history/widget/feedback_bottom_sheet.dart';
import '../../notification/bloc/notification_bloc.dart';
import '../../service_booking/bloc/service_category_bloc.dart';
import '../../service_booking/bloc/service_request_bloc.dart';
import '../../service_booking/data/service_request_repository.dart';
import '../../service_booking/model/service_category_model.dart';
import '../../service_booking/model/service_request_model.dart';

const _cOrange = kAccentColor;
const _cBlue = kPrimaryColor;

class UserHomePage extends ConsumerStatefulWidget {
  const UserHomePage({super.key});

  @override
  ConsumerState<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends ConsumerState<UserHomePage> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Future<void> _syncUserProfileSilently() async {
    try {
      final storage = locator<LocalStorageService>();

      // ── Step 1: Immediate Cache Load ───────────────────────────
      // Get the last-saved profile from local storage so the UI
      // doesn't show "User" placeholder while waiting for the network.
      final cachedJson = await storage.getUserProfile();
      if (cachedJson != null && mounted) {
        final cachedProfile = UserProfileModel.fromJson(cachedJson);
        ref.read(userProfileProvider.notifier).state = cachedProfile;
      }

      // ── Step 2: Fresh API Sync ─────────────────────────────────
      final token = await storage.token;
      if (!mounted) return;
      if (token == null || token.isEmpty) return;

      final profile = await locator<UserProfileRepository>().getProfile();
      if (!mounted) return;

      // Update source of truth (Riverpod + Local Cache)
      ref.read(userProfileProvider.notifier).state = profile;
      await storage.saveUserProfile(profile.toJson());
      if (!mounted) return;

      // Update BLoC for legacy consumers
      context.read<AuthBloc>().add(LoginSuccess(user: profile, token: token));
    } catch (e) {
      debugPrint('❌ [UserHome] Silent profile sync failed: $e');
    }
  }

  Future<void> _checkLocationPermission() async {
    if (!mounted) return;

    // If an address is already selected (e.g. entered manually or cached),
    // we don't need to nag for GPS permission immediately.
    final selectedAddress = ref.read(selectedAddressProvider);
    if (selectedAddress != null) return;

    final locationService = LocationService();
    final isGranted = await locationService.isLocationPermissionGranted();
    if (!mounted) return;
    if (isGranted) return;

    final permission = await locationService.getPermissionStatus();
    if (!mounted) return;
    final isPermanentlyDenied = permission == LocationPermission.deniedForever;

    await LocationPermissionDialog.show(context, isPermanentlyDenied: isPermanentlyDenied);

    // Dialog already requested the permission or redirected to settings
    // No more logic needed here.
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final isGuest = context.read<AuthBloc>().state is AuthGuest;
      if (!isGuest) {
        await _checkLocationPermission();
        if (!mounted) return;
        ref.read(selectedAddressProvider.notifier).loadForLoggedInUser();
      }
      if (mounted) _syncUserProfileSilently();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompactLandscape = _isCompactLandscape(context);
    final availabilityAsync = ref.watch(serviceAvailabilityProvider);
    // Use valueOrNull to keep the button visible during refresh if it was previously enabled.
    final isEmergencyEnabled = availabilityAsync.value?.data?.cityAdmin?.isEmergencyServiceEnabled == 1;

    return Scaffold(
      backgroundColor: kWhiteColor,
      body: Column(
        children: [
          // ── Fixed Top Header (Static Profile & Location) ──────────────
          _buildFixedHeader(context, isCompactLandscape: isCompactLandscape),

          // ── Scrollable Body ────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: _cBlue,
              onRefresh: () async {
                await _syncUserProfileSilently();
                if (!context.mounted) return;

                final authState = context.read<AuthBloc>().state;
                final isAuth = authState is AuthAuthenticated;

                context.read<ServiceCategoryBloc>().add(LoadServiceCategories(isSilent: true, isEmergency: false));

                // Use refresh instead of invalidate to maintain the previous state while loading
                await ref.refresh(serviceAvailabilityProvider.future).then((_) {});

                if (!context.mounted) return;
                if (isAuth) {
                  context.read<ServiceRequestBloc>().add(const LoadServiceRequests());
                  context.read<NotificationBloc>().add(FetchNotificationsEvent(isSilent: true));
                }

                // Refresh system settings
                await ref.refresh(systemSettingsProvider.future).then((_) {});

                // Refresh promo banners
                await ref.refresh(activePromoBannersProvider.future).then((_) {});

                await Future.delayed(const Duration(seconds: 1));
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Scrollable Search Bar ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
                      child: _buildSearchBar(context, isCompactLandscape: isCompactLandscape),
                    ),
                  ),

                  // ── Promo Banners ────────────────────────────────────────
                  const SliverToBoxAdapter(child: _PromoBannersSection()),

                  // ── Trust Badges Section ─────────────────────────────────
                  const SliverToBoxAdapter(child: _TrustBadgesSection()),

                  // ── Emergency banner (only when city_admin has emergency enabled) ──
                  if (isEmergencyEnabled)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16.w, isCompactLandscape ? 8.h : 6.h, 16.w, 0),
                        child: _EmergencyBanner(
                          pulseAnimation: _pulseAnimation,
                          isCompactLandscape: isCompactLandscape,
                          onTap: () {
                            Navigator.of(context).pushNamed(AppRoutes.emergency);
                          },
                        ),
                      ),
                    ),

                  // ── Book a service CTA ───────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16.w, isCompactLandscape ? 6.h : 12.h, 16.w, 0),
                      child: _BookServiceBanner(
                        isCompactLandscape: isCompactLandscape,
                        onTap: () {
                          Navigator.of(
                            context,
                          ).push(MaterialPageRoute(builder: (_) => const ServiceBookingFlow()));
                        },
                      ),
                    ),
                  ),

                  // ── Active / searching service ───────────────────────────
                  SliverToBoxAdapter(child: _buildActiveSection()),

                  // ── Upcoming bookings ────────────────────────────────────
                  SliverToBoxAdapter(child: _buildUpcomingSection()),

                  // ── Services grid ────────────────────────────────────────
                  SliverToBoxAdapter(child: _buildServicesSection()),

                  // ── Recent bookings ──────────────────────────────────────
                  // SliverToBoxAdapter(child: _buildRecentSection()),

                  // ── Login Prompt / Refer & Earn Banner ───────────────────────────────────
                  SliverToBoxAdapter(
                    child: BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, authState) {
                        return Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 0),
                          child: (authState is AuthGuest) ? const _GuestLoginBanner() : _ReferEarnBanner(ref: ref),
                        );
                      },
                    ),
                  ),

                  // ── Premium Vetted Trust Section ────────────────────────
                  SliverToBoxAdapter(child: const _VettedExpertsView()),
                  SliverToBoxAdapter(child: AppSpacing.xlVertical),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isCompactLandscape(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return context.isLandscape && mediaQuery.size.height <= 500;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIVE SERVICE SECTION
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildActiveSection() {
    return BlocBuilder<ServiceRequestBloc, ServiceRequestState>(
      builder: (context, state) {
        if (state is ServiceRequestLoading) {
          return const _HomeSection(title: 'Confirmed Booking', child: BookingCardShimmer());
        }
        if (state is! ServiceRequestListLoaded) return const SizedBox.shrink();
        // Confirmed Booking section is reserved for emergency bookings only —
        // regular bookings surface under "Upcoming Bookings" instead.
        final active = state.requests.where((r) {
          if (!r.isEmergency) return false;
          final s = r.status;
          return s == 'searching' ||
              s == 'accepted' ||
              s == 'standby' ||
              s == 'in_progress' ||
              s == 'partially_accepted';
        }).toList();
        if (active.isEmpty) return const SizedBox.shrink();
        final r = active.first;
        final isSearching = r.isPending; // status == 'searching'

        final sectionTitle = (r.isEmergency && r.status == 'searching')
            ? 'Finding Your Partner'
            : 'Confirmed Booking';

        return _HomeSection(
          title: sectionTitle,
          actionLabel: 'View All',
          onAction: () => AppNavigator.to(AppRoutes.bookingHistory),
          child: _ActiveBookingCard(
            r: r,
            isSearching: isSearching,
            pulseAnimation: _pulseAnimation,
            onAction: (action) => _handleBookingAction(context, action, r),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UPCOMING SECTION
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildUpcomingSection() {
    return BlocBuilder<ServiceRequestBloc, ServiceRequestState>(
      builder: (context, state) {
        if (state is ServiceRequestLoading) {
          return const _HomeSection(title: 'Upcoming Bookings', child: BookingCardShimmer());
        }
        if (state is! ServiceRequestListLoaded) return const SizedBox.shrink();
        final upcoming = state.requests
            .where((r) {
              // Emergency bookings live in the "Confirmed Booking" section.
              if (r.isEmergency) return false;
              final s = r.status;
              return s == 'searching' ||
                  s == 'accepted' ||
                  s == 'in_progress' ||
                  s == 'standby' ||
                  s == 'partially_accepted' ||
                  s == 'confirmed' ||
                  s == 'scheduled';
            })
            .take(2)
            .toList();
        if (upcoming.isEmpty) return const SizedBox.shrink();

        return _HomeSection(
          title: 'Upcoming Bookings',
          actionLabel: 'View All',
          onAction: () => AppNavigator.to(AppRoutes.bookingHistory),
          child: Column(
            children: upcoming
                .map(
                  (r) => _UpcomingCard(
                    r: r,
                    onTap: () async {
                      final result = await AppNavigator.to(AppRoutes.serviceRequestDetail, arguments: r.id);
                      if (result == true && context.mounted) {
                        context.read<ServiceRequestBloc>().add(const LoadServiceRequests());
                      }
                    },
                    onAction: (action) => _handleBookingAction(context, action, r),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SERVICES GRID
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildServicesSection() {
    final availabilityAsync = ref.watch(serviceAvailabilityProvider);

    return availabilityAsync.when(
      skipLoadingOnRefresh: true,
      loading: () => _HomeSection(title: 'Our Services', child: const ServicesGridShimmer()),
      error: (_, _) => _HomeSection(
        title: 'Our Services',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Text('Could not load services.', style: kTextNormal(color: kTextSecondaryColor)),
        ),
      ),
      data: (response) {
        if (response == null) {
          return _HomeSection(
            title: 'Our Services',
            child: NoServiceView(
              title: 'Select an address to see services',
              description: 'Please set your location to discover healthcare services available in your area.',
              actionLabel: 'Set Location',
              onChangeLocation: () async {
                await Navigator.of(
                  context,
                ).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const SearchAddressPage()));
                if (mounted) {
                  ref.invalidate(serviceAvailabilityProvider);
                  ref.invalidate(systemSettingsProvider);
                  context.read<ServiceCategoryBloc>().add(
                    LoadServiceCategories(isSilent: true, isEmergency: false),
                  );
                }
              },
            ),
          );
        }

        final isEmergencyEnabled = response.data?.cityAdmin?.isEmergencyServiceEnabled == 1;
        final allCats = (response.data?.serviceCategories ?? []).where((cat) {
          if (cat.isEmergency) return isEmergencyEnabled;
          return true;
        }).toList();

        if (allCats.isEmpty) {
          final addr = ref.watch(selectedAddressProvider);
          return _HomeSection(
            title: 'Our Services',
            child: NoServiceView(
              city: addr?.area ?? addr?.city,
              zipCode: addr?.pinCode,
              onChangeLocation: () async {
                await Navigator.of(
                  context,
                ).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const SearchAddressPage()));
                if (mounted) {
                  ref.invalidate(serviceAvailabilityProvider);
                  ref.invalidate(systemSettingsProvider);
                  context.read<ServiceCategoryBloc>().add(
                    LoadServiceCategories(isSilent: true, isEmergency: false),
                  );
                }
              },
            ),
          );
        }

        final displayCats = allCats;

        return _HomeSection(
          title: 'Our Services',
          child: GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayCats.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12.h,
              crossAxisSpacing: 12.w,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (_, i) {
              final cat = displayCats[i];
              return _ServiceCategoryCard(
                category: cat,
                onTap: () {
                  cat.isEmergency
                      ? Navigator.of(context).pushNamed(AppRoutes.emergency)
                      : Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ServiceBookingFlow(initialMainCategory: _toBookingModel(cat)),
                          ),
                        );
                },
              );
            },
          ),
        );
      },
    );
  }

  ServiceCategoryModel _toBookingModel(ServiceCategory cat) => ServiceCategoryModel(
    id: cat.id,
    categoryName: cat.categoryName,
    categorySlug: cat.categorySlug ?? '',
    iconUrl: cat.iconUrl,
    iconImageUrl: cat.iconImageUrl,
    isActive: cat.isActive,
    displayOrder: cat.displayOrder,
    fullCategoryName: cat.fullCategoryName ?? cat.categoryName,
    gstPercentage: double.tryParse(cat.gstPercentage) ?? 0.0,
  );

  // ─────────────────────────────────────────────────────────────────────────
  // RECENT BOOKINGS
  // ─────────────────────────────────────────────────────────────────────────
  // Widget _buildRecentSection() {
  //   return BlocBuilder<ServiceRequestBloc, ServiceRequestState>(
  //     builder: (context, state) {
  //       if (state is ServiceRequestLoading) {
  //         return const _HomeSection(title: 'Recent Bookings', child: BookingCardShimmer());
  //       }
  //       if (state is! ServiceRequestListLoaded) return const SizedBox.shrink();
  //       final recent = state.requests.where((r) => r.isCompleted || r.isCancelled || r.isExpired).take(3).toList();
  //       if (recent.isEmpty) return const SizedBox.shrink();
  //
  //       return _HomeSection(
  //         title: 'Recent Bookings',
  //         actionLabel: 'View All',
  //         onAction: () => AppNavigator.to(AppRoutes.bookingHistory),
  //         child: Container(
  //           decoration: BoxDecoration(
  //             color: kWhiteColor,
  //             borderRadius: BorderRadius.circular(14.r),
  //             border: Border.all(color: const Color(0xFFEEEFF1)),
  //           ),
  //           child: Column(
  //             children: List.generate(recent.length, (i) {
  //               final r = recent[i];
  //               return _RecentItem(
  //                 r: r,
  //                 isFirst: i == 0,
  //                 isLast: i == recent.length - 1,
  //                 onTap: () => AppNavigator.to(AppRoutes.serviceRequestDetail, arguments: r.id),
  //                 onAction: (action) => _handleBookingAction(context, action, r),
  //               );
  //             }),
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  // ─────────────────────────────────────────────────────────────────────────
  // BOOKING ACTION HANDLER — single place for all action routing
  // ─────────────────────────────────────────────────────────────────────────
  void _handleBookingAction(BuildContext ctx, _BookingAction action, ServiceRequestModel r) {
    switch (action) {
      case _BookingAction.track:
        AppNavigator.to(AppRoutes.emergencyTracking, arguments: r.id);
        break;
      case _BookingAction.details:
        () async {
          final result = await AppNavigator.to(AppRoutes.serviceRequestDetail, arguments: r.id);
          if (result == true && ctx.mounted) {
            ctx.read<ServiceRequestBloc>().add(const LoadServiceRequests());
          }
        }();
        break;
      case _BookingAction.pay:
        // Block payment when the scheduled start has already passed.
        if (r.isStartInPast) {
          showPastBookingDialog(
            ctx,
            RescheduleInfo(
              serviceRequestId: r.id,
              requestNumber: r.requestNumber ?? '',
              serviceName: r.serviceCategoryName,
              serviceCategoryId: r.service?.serviceCategoryId,
              serviceSubCategoryId: r.service?.id,
              bookingType: r.serviceType ?? '',
              isEmergency: r.isEmergency,
              startDateText: r.startDateText ?? r.startDate ?? '',
              startTimeText: r.startTimeText ?? '',
            ),
          );
          return;
        }
        if (r.totalAmount == null || !r.needsPayment) break;
        () async {
          void refresh() {
            if (ctx.mounted) {
              ctx.read<ServiceRequestBloc>().add(const LoadServiceRequests());
            }
          }

          showDialog(
            context: ctx,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
          );
          try {
            final response = await locator<ServiceRequestRepository>().getServiceRequestDetailsById(r.id);
            final sr = BookingDetailModel.fromJson(response).serviceRequest;

            if (!ctx.mounted) return;
            Navigator.pop(ctx);

            final installments = sr.paymentInstallments
                .map(
                  (i) => {
                    'id': i.id,
                    'installment_number': i.installmentNumber,
                    'amount': i.amount,
                    'percentage': i.percentage,
                    'due_date': i.dueDate,
                    'status': i.status,
                    'status_text': i.statusText,
                  },
                )
                .toList();

            await navigateToPaymentPage(
              context: ctx,
              serviceRequestId: sr.id,
              totalAmount: sr.totalAmount,
              basePrice: sr.basePrice,
              distanceCharge: sr.pricingBreakdown?.distanceCharge ?? r.distanceCharge,
              gstAmount: sr.pricingBreakdown?.gstAmount ?? r.gstAmount ?? 0,
              paymentInstallments: installments,
              serviceName: sr.service?.name ?? sr.serviceTypeText,
              serviceImageUrl: sr.service?.iconImageUrl,
              startDate: sr.startDateText,
              endDate: sr.endDateText,
              durationDays: sr.durationDays,
              durationHours: sr.durationHours?.toInt(),
              isEmergency: r.isEmergency,
              isNewBooking: false,
              onCancel: refresh,
              packageDiscountAmount:
                  (sr.pricingBreakdown?.package?.actualPrice ?? 0.0) -
                  (sr.pricingBreakdown?.package?.price ?? 0.0),
            );
            refresh();
          } catch (_) {
            if (ctx.mounted) Navigator.pop(ctx);
            MessageService.showError('Failed to load payment details. Please try again.');
          }
        }();
        break;
      case _BookingAction.rate:
        showFeedbackBottomSheet(
          context: ctx,
          bookingId: r.bookingId ?? r.id,
          bookingSubBlockId: r.subBlocks.isNotEmpty ? r.subBlocks.first.id : null,
          providerName: r.providerName,
          serviceName: r.serviceCategoryName,
          onSuccess: () {
            if (ctx.mounted) {
              ctx.read<ServiceRequestBloc>().add(const LoadServiceRequests());
            }
          },
        );
        break;
      case _BookingAction.extend:
        () async {
          final result = await AppNavigator.to(AppRoutes.serviceRequestDetail, arguments: r.id);
          if (result == true && ctx.mounted) {
            ctx.read<ServiceRequestBloc>().add(const LoadServiceRequests());
          }
        }();
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER BUILDER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFixedHeader(BuildContext context, {required bool isCompactLandscape}) {
    final userProfile = ref.watch(userProfileProvider);
    final authState = context.watch<AuthBloc>().state;

    final String name = userProfile?.displayName ?? (authState is AuthGuest ? 'Guest' : 'User');
    final String? imageUrl = userProfile?.profileImageUrl;
    final bool isGuest = authState is AuthGuest;

    return Container(
      color: kWhiteColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8.h),
              // ── Minimal Profile & Location Row ──
              Row(
                children: [
                  _buildProfileImage(name, imageUrl, isCompactLandscape: isCompactLandscape, isGuest: isGuest),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isGuest) ...[
                          GestureDetector(
                            onTap: () => AppNavigator.to(AppRoutes.login),
                            child: Text(
                              'Welcome to Adhisaat',
                              style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 17.sp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildMinimalLocation(context),
                        ] else ...[
                          GestureDetector(
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  fullscreenDialog: true,
                                  builder: (_) => const SearchAddressPage(),
                                ),
                              );
                              if (context.mounted) {
                                ref.invalidate(serviceAvailabilityProvider);
                                ref.invalidate(systemSettingsProvider);
                                context.read<ServiceCategoryBloc>().add(
                                  LoadServiceCategories(isSilent: true, isEmergency: false),
                                );
                              }
                            },
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: name,
                                    style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 18.sp),
                                  ),
                                  TextSpan(
                                    text: "👋",
                                    style: TextStyle(fontSize: 16.sp),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildMinimalLocation(context),
                        ],
                      ],
                    ),
                  ),
                  if (!isGuest) _buildWalletOption(context, isCompactLandscape: isCompactLandscape),
                  SizedBox(width: 10.w),
                  _buildNotificationBell(context, isCompactLandscape: isCompactLandscape),
                ],
              ),

              SizedBox(height: 10.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalLocation(BuildContext context) {
    final addr = ref.watch(selectedAddressProvider);
    final String addressLine;
    if (addr != null) {
      final String base = addr.area?.isNotEmpty == true
          ? addr.area!
          : (addr.city?.isNotEmpty == true ? addr.city! : 'Set Location');
      if (addr.pinCode?.isNotEmpty == true) {
        addressLine = '$base (${addr.pinCode})';
      } else {
        addressLine = base;
      }
    } else {
      addressLine = 'Set Location';
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const SearchAddressPage()));
        if (context.mounted) {
          ref.invalidate(serviceAvailabilityProvider);
          ref.invalidate(systemSettingsProvider);
          context.read<ServiceCategoryBloc>().add(LoadServiceCategories(isSilent: true, isEmergency: false));
        }
      },
      child: Container(
        margin: EdgeInsets.only(top: 4.h),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: _cBlue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on_rounded, color: _cOrange, size: 12.sp),
            SizedBox(width: 4.w),
            Flexible(
              child: Text(
                addressLine,
                style: kTextSemiBold0(color: _cBlue).copyWith(fontSize: 11.sp),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: _cBlue, size: 14.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage(
    String name,
    String? imageUrl, {
    required bool isCompactLandscape,
    required bool isGuest,
  }) {
    if (isGuest) {
      final logoSize = isCompactLandscape ? 48.w : 56.w;
      return GestureDetector(
        onTap: () => AppNavigator.to(AppRoutes.login),
        child: Image.asset(AppAssets.logoClear, width: logoSize, height: logoSize, fit: BoxFit.contain),
      );
    }

    final imageSize = isCompactLandscape ? 38.w : 45.w;
    return GestureDetector(
      onTap: () => AppNavigator.to(AppRoutes.userProfilePage),
      child: Container(
        width: imageSize,
        height: imageSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kWhiteColor,
          border: Border.all(color: _cBlue.withValues(alpha: 0.2), width: 2),
          boxShadow: [BoxShadow(color: _cBlue.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 3))],
        ),
        child: ClipOval(
          child: (imageUrl != null && imageUrl.isNotEmpty)
              ? AppCachedImage(imageUrl: imageUrl, width: imageSize, height: imageSize, fit: BoxFit.cover)
              : _buildInitials(name),
        ),
      ),
    );
  }

  Widget _buildInitials(String name) {
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (name.isNotEmpty ? name[0].toUpperCase() : 'U');
    return Center(
      child: Text(initials, style: kTextBold(color: _cBlue)),
    );
  }

  Widget _buildWalletOption(BuildContext context, {required bool isCompactLandscape}) {
    final userProfile = ref.watch(userProfileProvider);
    final wallet = double.tryParse(userProfile?.walletAmount ?? '0') ?? 0;
    final bonus = double.tryParse(userProfile?.bonusWalletAmount ?? '0') ?? 0;
    final currentTotal = wallet + bonus;

    final storage = locator<LocalStorageService>();
    final lastTotal = double.tryParse(storage.lastKnownWalletAmount ?? '0') ?? 0;
    // Show badge only if amount has increased
    final bool hasNewFunds = currentTotal > lastTotal;

    return GestureDetector(
      onTap: () {
        storage.saveLastKnownWalletAmount(currentTotal.toString());
        AppNavigator.to(AppRoutes.wallet);
      },
      child: Container(
        padding: EdgeInsets.all(isCompactLandscape ? 6.w : 7.w),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.all(Radius.circular(12.r)),
          border: Border.all(color: _cBlue.withValues(alpha: 0.15), width: 1.2),
          boxShadow: [BoxShadow(color: _cBlue.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: _cBlue, size: isCompactLandscape ? 18.sp : 20.sp),
            if (hasNewFunds)
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: 9.w,
                  height: 9.w,
                  decoration: BoxDecoration(
                    color: _cOrange,
                    shape: BoxShape.circle,
                    border: Border.all(color: kWhiteColor, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationBell(BuildContext context, {required bool isCompactLandscape}) {
    return GestureDetector(
      onTap: () async {
        await AppNavigator.to(AppRoutes.userNotificationPage);
        if (context.mounted) {
          context.read<NotificationBloc>().add(FetchNotificationsEvent(isSilent: true));
        }
      },
      child: Container(
        padding: EdgeInsets.all(isCompactLandscape ? 6.w : 7.w),
        decoration: BoxDecoration(
          color: kWhiteColor,
          shape: BoxShape.circle,
          border: Border.all(color: _cBlue.withValues(alpha: 0.15), width: 1.2),
          boxShadow: [BoxShadow(color: _cBlue.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: BlocBuilder<NotificationBloc, NotificationState>(
          builder: (context, state) {
            int unreadCount = 0;
            if (state is NotificationLoaded) {
              unreadCount = state.unreadCount;
            }

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.notifications_none_rounded, color: _cBlue, size: isCompactLandscape ? 18.sp : 20.sp),
                if (unreadCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: EdgeInsets.all(2.w),
                      decoration: BoxDecoration(
                        color: _cOrange,
                        shape: BoxShape.circle,
                        border: Border.all(color: kWhiteColor, width: 1.5),
                      ),
                      constraints: BoxConstraints(minWidth: 16.w, minHeight: 16.w),
                      child: Center(
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: kTextBold0(color: kWhiteColor).merge(TextStyle(fontSize: 9.sp)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, {required bool isCompactLandscape}) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.searchService),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: isCompactLandscape ? 10.h : 14.h),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: _cBlue.withValues(alpha: 0.15), width: 1.5),
          boxShadow: [
            BoxShadow(color: _cBlue.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: _cBlue, size: isCompactLandscape ? 18.sp : 22.sp),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                'Search for services',
                style: kTextMedium(color: kTextHintColor).copyWith(fontSize: 14.sp),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Booking action enum ──────────────────────────────────────────────────────

enum _BookingAction { track, details, pay, rate, extend }

// ─── Section wrapper ──────────────────────────────────────────────────────────

class _HomeSection extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  const _HomeSection({required this.title, required this.child, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title, style: kTextSemiBold(color: kTextSecondaryColor)),
              ),
              if (actionLabel != null && onAction != null)
                GestureDetector(
                  onTap: onAction,
                  child: Row(
                    children: [
                      Text(
                        actionLabel!,
                        style: kTextMedium(color: _cBlue).copyWith(fontSize: 12.sp),
                      ),
                      SizedBox(width: 2.w),
                      Icon(Icons.chevron_right_rounded, size: 16.sp, color: _cBlue),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }
}

// ─── Emergency Banner ─────────────────────────────────────────────────────────

  class _EmergencyBanner extends StatelessWidget {
  final Animation<double> pulseAnimation;
  final VoidCallback onTap;
  final bool isCompactLandscape;

  const _EmergencyBanner({required this.pulseAnimation, required this.onTap, required this.isCompactLandscape});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_cOrange.withValues(alpha: 0.05), _cOrange.withValues(alpha: 0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: _cOrange.withValues(alpha: 0.2), width: 1.5),
            boxShadow: [
              BoxShadow(color: _cOrange.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: _cOrange,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: _cOrange.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Center(
                  child: AnimatedBuilder(
                    animation: pulseAnimation,
                    builder: (_, _) => Transform.scale(
                      scale: pulseAnimation.value,
                      child: Icon(Icons.emergency_share_rounded, color: Colors.white, size: 22.sp),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Emergency Services',
                            style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 15.sp),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(color: _cOrange, borderRadius: BorderRadius.circular(6.r)),
                          child: Text(
                            '24/7',
                            style: kTextBold0(color: Colors.white).copyWith(fontSize: 8.sp),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Ambulance, Nursing care & more',
                      style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: _cOrange, size: 16.sp),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Book Service Banner ──────────────────────────────────────────────────────

class _BookServiceBanner extends StatelessWidget {
  final VoidCallback onTap;
  final bool isCompactLandscape;

  const _BookServiceBanner({required this.onTap, required this.isCompactLandscape});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_cBlue.withValues(alpha: 0.05), _cBlue.withValues(alpha: 0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: _cBlue.withValues(alpha: 0.2), width: 1.5),
            boxShadow: [
              BoxShadow(color: _cBlue.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: _cBlue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: _cBlue.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Icon(Icons.medical_services_rounded, color: Colors.white, size: 22.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Book a Service',
                      style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 15.sp),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Nurse, Caregiver, Physiotherapy & more',
                      style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: _cBlue, size: 16.sp),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Active Booking Card ──────────────────────────────────────────────────────

class _ActiveBookingCard extends StatelessWidget {
  final ServiceRequestModel r;
  final bool isSearching;
  final Animation<double> pulseAnimation;
  final void Function(_BookingAction) onAction;

  const _ActiveBookingCard({
    required this.r,
    required this.isSearching,
    required this.pulseAnimation,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isEmergency = r.isEmergency;

    final statusLabel = RequestStatusHelper.smartLabel(r);
    final statusColor = RequestStatusHelper.color(
      r.status,
      serviceType: r.serviceType,
      isEmergency: isEmergency,
      paymentStatus: r.paymentStatus,
    );

    return Container(
      // margin: EdgeInsets.fromLTRB(0.w, 12.h, 0.w, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: statusColor.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(color: statusColor.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          // ── Accent strip ──
          Container(
            height: 4.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [statusColor, statusColor.withValues(alpha: 0.4)]),
            ),
          ),

          // ── Header Row (Status & Profile) ──
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 10.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar / Status Icon with gradient ring
                Container(
                  width: 48.w,
                  height: 48.w,
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [statusColor.withValues(alpha: 0.35), statusColor.withValues(alpha: 0.12)],
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(color: kWhiteColor, shape: BoxShape.circle),
                    child: Center(
                      child: isEmergency && isSearching
                          ? Shimmer.fromColors(
                              baseColor: statusColor.withValues(alpha: 0.2),
                              highlightColor: statusColor.withValues(alpha: 0.6),
                              child: Icon(Icons.person_search_rounded, color: statusColor, size: 26.sp),
                            )
                          : (r.serviceIconUrl ?? r.categoryIconUrl) != null
                          ? ClipOval(
                              child: AppCachedImage(
                                imageUrl: r.serviceIconUrl ?? r.categoryIconUrl,
                                width: 44.w,
                                height: 44.w,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(
                              isEmergency ? Icons.emergency_rounded : Icons.medical_services_rounded,
                              color: statusColor,
                              size: 26.sp,
                            ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.serviceName ?? 'Service',
                        style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 15.sp),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        isSearching && isEmergency
                            ? 'Searching for Partner...'
                            : isSearching
                            ? (r.serviceName ?? r.serviceCategoryName)
                            : (r.providerName ?? 'Partner assigned'),
                        style: kTextSemiBold(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                // Status Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: pulseAnimation,
                        builder: (_, _) => Transform.scale(
                          scale: pulseAnimation.value,
                          child: Container(
                            width: 6.w,
                            height: 6.w,
                            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        statusLabel.toUpperCase(),
                        style: kTextBold(color: statusColor).copyWith(fontSize: 8.5.sp, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Info Row (Time/Location) ──
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: kGreyColor1.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time_filled_rounded, size: 14.sp, color: statusColor.withValues(alpha: 0.8)),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      [
                        if (r.startDateText != null) AppDateFormatter.dateFromApi(r.startDateText!),
                        if (r.startTimeText != null) AppDateFormatter.formatTimeString(r.startTimeText!),
                        if (!isEmergency) r.durationText,
                      ].where((s) => s.isNotEmpty && s != '—').join('  ·  '),
                      style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 12.sp),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Actions ──
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 14.h),
            child: Row(
              children: [
                if (isEmergency && r.subBlocks.any((s) => s.isAssigned) && !r.isServiceEnded) ...[
                  Expanded(
                    child: _ActiveCardBtn(
                      label: 'TRACK',
                      icon: Icons.my_location_rounded,
                      color: kErrorColor,
                      onTap: () => onAction(_BookingAction.track),
                    ),
                  ),
                  SizedBox(width: 10.w),
                ],
                // if (r.status == 'in_progress' && !isEmergency && !r.isServiceEnded) ...[
                //   Expanded(
                //     child: _ActiveCardBtn(
                //       label: 'EXTEND',
                //       icon: Icons.add_alarm_rounded,
                //       color: const Color(0xFF8B5CF6),
                //       onTap: () => onAction(_BookingAction.extend),
                //     ),
                //   ),
                //   SizedBox(width: 10.w),
                // ],
                Expanded(
                  child: _ActiveCardBtn(
                    label: isSearching ? 'VIEW REQUEST' : 'BOOKING DETAILS',
                    icon: Icons.arrow_forward_rounded,
                    color: _cBlue,
                    filled: true,
                    onTap: () => onAction(_BookingAction.details),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveCardBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _ActiveCardBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? kWhiteColor : color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 11.h),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: filled ? color : color.withValues(alpha: 0.2)),
          boxShadow: filled
              ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: kTextBold(color: fg).copyWith(fontSize: 11.sp),
            ),
            SizedBox(width: 6.w),
            Icon(icon, size: 14.sp, color: fg),
          ],
        ),
      ),
    );
  }
}

// ─── Upcoming Card ────────────────────────────────────────────────────────────

class _UpcomingCard extends StatelessWidget {
  final ServiceRequestModel r;
  final VoidCallback onTap;
  final void Function(_BookingAction) onAction;

  const _UpcomingCard({required this.r, required this.onTap, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final isEmergency = r.isEmergency;
    final statusColor = RequestStatusHelper.color(
      r.status,
      serviceType: r.serviceType,
      isEmergency: isEmergency,
      paymentStatus: r.paymentStatus,
    );
    final statusLabel = RequestStatusHelper.label(
      r.status,
      serviceType: r.serviceType,
      isEmergency: isEmergency,
      paymentStatus: r.paymentStatus,
    );

    // Real next session (assigned/upcoming, not completed/cancelled)
    final next = r.nextUpcomingSession;
    final dateStr = next != null
        ? AppDateFormatter.dateFromApi(next.scheduledDateText)
        : (r.startDateText != null
              ? AppDateFormatter.dateFromApi(r.startDateText!)
              : (r.startDate != null ? AppDateFormatter.dateFromApi(r.startDate!) : ''));
    final timeStr = next != null
        ? AppDateFormatter.formatTimeString(next.scheduledStartTimeText)
        : (r.startTimeText != null
              ? AppDateFormatter.formatTimeString(r.startTimeText!)
              : (r.startTime != null ? AppDateFormatter.formatTimeString(r.startTime!) : ''));
    final showPay =
        r.needsPayment &&
        r.totalAmount != null &&
        !r.isCancelledOrExpired &&
        (isEmergency ? r.status == 'accepted' : true);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: statusColor.withValues(alpha: 0.12), width: 1.2),
        boxShadow: [
          BoxShadow(color: statusColor.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.r),
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent strip
                Container(
                  width: 4.w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [statusColor, statusColor.withValues(alpha: 0.5)],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12.w, 12.h, 14.w, 12.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1 — icon + title + status pill
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: r.serviceIconUrl != null
                                  ? AppCachedImage(
                                      imageUrl: r.serviceIconUrl!,
                                      width: 22.w,
                                      height: 22.w,
                                      fit: BoxFit.contain,
                                    )
                                  : Icon(Icons.medical_services_rounded, color: statusColor, size: 20.sp),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                r.serviceCategoryName,
                                style: kTextSemiBold(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5.w,
                                    height: 5.w,
                                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(statusLabel, style: kTextSemiBold0(color: statusColor)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        // Row 2 — full-width session details + amount
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(Icons.event_rounded, size: 13.sp, color: statusColor),
                            SizedBox(width: 5.w),
                            Expanded(
                              child: Text(
                                [
                                  if (next != null) 'Next' else if (dateStr.isNotEmpty) 'Starts',
                                  if (dateStr.isNotEmpty) dateStr,
                                  if (timeStr.isNotEmpty) timeStr,
                                ].where((s) => s.isNotEmpty).join(' · '),
                                style: kTextNormal0(color: kTextSecondaryColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (r.totalAmount != null && r.statusLabel != 'Confirmed') ...[
                              SizedBox(width: 8.w),
                              Text(
                                NumberUtils.formatCurrency(r.totalAmount!, decimalDigits: 0),
                                style: kTextSemiBold(color: _cBlue),
                              ),
                            ],
                          ],
                        ),
                        if (r.durationText != '—' && r.durationText.isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              Icon(Icons.timelapse_rounded, size: 13.sp, color: kTextSecondaryColor),
                              SizedBox(width: 5.w),
                              Text(r.durationText, style: kTextNormal0(color: kTextSecondaryColor)),
                            ],
                          ),
                        ],
                        if (showPay) ...[
                          SizedBox(height: 10.h),
                          Divider(height: 1, color: const Color(0xFFF3F4F6)),
                          SizedBox(height: 10.h),
                          Row(
                            children: [
                              Expanded(
                                child: _CardBtn(
                                  label: 'Pay ${NumberUtils.formatCurrency(r.totalAmount)}',
                                  icon: Icons.payment_rounded,
                                  color: kOrangeColor,
                                  filled: true,
                                  expand: true,
                                  onTap: () => onAction(_BookingAction.pay),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              _CardBtn(
                                label: 'Details',
                                icon: Icons.chevron_right_rounded,
                                color: _cBlue,
                                onTap: onTap,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
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

// ─── Service Category Card (enhanced 2-col) ────────────────────────────────────

class _ServiceCategoryCard extends StatelessWidget {
  final ServiceCategory category;
  final VoidCallback onTap;

  const _ServiceCategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isEmergency = category.isEmergency;
    final accentColor = isEmergency ? _cOrange : kAccentColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: accentColor.withValues(alpha: 0.15), width: 1.5),
          boxShadow: [
            BoxShadow(color: accentColor.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon section
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
                    ),
                    child: Center(
                      child: category.iconImageUrl != null && category.iconImageUrl!.isNotEmpty
                          ? AppCachedImage(
                              imageUrl: category.iconImageUrl!,
                              width: 80.w,
                              height: 80.w,
                              fit: BoxFit.cover,
                            )
                          : Icon(
                              isEmergency ? Icons.emergency_rounded : Icons.medical_services_rounded,
                              color: accentColor,
                              size: 38.sp,
                            ),
                    ),
                  ),
                  if (isEmergency)
                    Positioned(
                      top: 8.h,
                      right: 8.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(color: _cOrange, borderRadius: BorderRadius.circular(8.r)),
                        child: Text(
                          'SOS',
                          style: kTextBold0(color: Colors.white).copyWith(fontSize: 9.sp),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info section
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category.categoryName,
                    style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 13.sp),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // if (serviceCount > 0) ...[
                  //   SizedBox(height: 3.h),
                  //   Row(
                  //     children: [
                  //       Icon(Icons.chevron_right_rounded, size: 12.sp, color: accentColor),
                  //       SizedBox(width: 2.w),
                  //       Text(
                  //         '$serviceCount ${serviceCount == 1 ? 'service' : 'services'}',
                  //         style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 10.sp),
                  //       ),
                  //     ],
                  //   ),
                  // ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── No Service Available Widget ──────────────────────────────────────────────

// class _NoServiceAvailableWidget extends StatelessWidget {
//   const _NoServiceAvailableWidget();
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.symmetric(vertical: 32.h, horizontal: 20.w),
//       decoration: BoxDecoration(
//         color: const Color(0xFFFFF3F3),
//         borderRadius: BorderRadius.circular(16.r),
//         border: Border.all(color: const Color(0xFFFFCDD2), width: 1),
//       ),
//       child: Column(
//         children: [
//           Container(
//             width: 56.w,
//             height: 56.w,
//             decoration: const BoxDecoration(color: Color(0xFFFFEBEE), shape: BoxShape.circle),
//             child: Icon(Icons.location_off_rounded, color: const Color(0xFFD32F2F), size: 28.sp),
//           ),
//           SizedBox(height: 16.h),
//           Text(
//             'Services not available in your area',
//             style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 15.sp),
//             textAlign: TextAlign.center,
//           ),
//           SizedBox(height: 8.h),
//           Text(
//             'We are expanding soon. Try a different address.',
//             style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }
// }

// ─── Recent Item ──────────────────────────────────────────────────────────────

// class _RecentItem extends StatelessWidget {
//   final ServiceRequestModel r;
//   final bool isFirst;
//   final bool isLast;
//   final VoidCallback onTap;
//   final void Function(_BookingAction) onAction;
//
//   const _RecentItem({
//     required this.r,
//     required this.isFirst,
//     required this.isLast,
//     required this.onTap,
//     required this.onAction,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final isCompleted = r.isCompleted;
//     final color = RequestStatusHelper.color(
//       r.status,
//       serviceType: r.serviceType,
//       isEmergency: r.isEmergency,
//       paymentStatus: r.paymentStatus,
//     );
//
//     return Column(
//       children: [
//         InkWell(
//           onTap: onTap,
//           borderRadius: BorderRadius.vertical(
//             top: isFirst ? Radius.circular(14.r) : Radius.zero,
//             bottom: isLast ? Radius.circular(14.r) : Radius.zero,
//           ),
//           child: Padding(
//             padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
//             child: Row(
//               children: [
//                 Container(
//                   padding: EdgeInsets.all(8.w),
//                   decoration: BoxDecoration(
//                     color: color.withValues(alpha: 0.1),
//                     borderRadius: BorderRadius.circular(8.r),
//                   ),
//                   child: r.categoryIconUrl != null
//                       ? AppCachedImage(
//                           imageUrl: r.categoryIconUrl!,
//                           width: 18.w,
//                           height: 18.w,
//                           fit: BoxFit.contain,
//                         )
//                       : Icon(Icons.medical_services_rounded, color: color, size: 16.sp),
//                 ),
//                 SizedBox(width: 12.w),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(r.serviceCategoryName, style: kTextSemiBold()),
//                       SizedBox(height: 2.h),
//                       Text(AppDateFormatter.dateFromApi(r.createdAt), style: kTextNormal0(color: kTextHintColor)),
//                     ],
//                   ),
//                 ),
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.end,
//                   children: [
//                     Container(
//                       padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
//                       decoration: BoxDecoration(
//                         color: color.withValues(alpha: 0.1),
//                         borderRadius: BorderRadius.circular(20.r),
//                       ),
//                       child: Text(
//                         RequestStatusHelper.label(
//                           r.status,
//                           serviceType: r.serviceType,
//                           isEmergency: r.isEmergency,
//                           paymentStatus: r.paymentStatus,
//                         ),
//                         style: kTextSemiBold0(color: color),
//                       ),
//                     ),
//                     if (r.totalAmount != null) ...[
//                       SizedBox(height: 3.h),
//                       Text(
//                         '₹${r.totalAmount!.toStringAsFixed(0)}',
//                         style: kTextSemiBold0(color: kTextSecondaryColor),
//                       ),
//                     ],
//
//                     // Rate CTA for completed unrated
//                     if (isCompleted && !r.hasRating) ...[
//                       SizedBox(height: 4.h),
//                       GestureDetector(
//                         onTap: () => onAction(_BookingAction.rate),
//                         child: Container(
//                           padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
//                           decoration: BoxDecoration(
//                             color: const Color(0xFFFEF3C7),
//                             borderRadius: BorderRadius.circular(6.r),
//                             border: Border.all(color: const Color(0xFFFCD34D)),
//                           ),
//                           child: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Icon(Icons.star_rounded, size: 11.sp, color: const Color(0xFFF59E0B)),
//                               SizedBox(width: 3.w),
//                               Text('Rate', style: kTextSemiBold0(color: const Color(0xFFB45309))),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ],
//
//                     // Rated badge
//                     if (isCompleted && r.hasRating) ...[
//                       SizedBox(height: 4.h),
//                       Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Icon(Icons.star_rounded, size: 11.sp, color: const Color(0xFFF59E0B)),
//                           SizedBox(width: 3.w),
//                           Text(
//                             '${r.ratingFeedback!.rating}/5',
//                             style: kTextNormal0(color: const Color(0xFFB45309)),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//         if (!isLast) Divider(height: 1, color: const Color(0xFFF3F4F6), indent: 14.w + 8.w + 18.w + 12.w),
//       ],
//     );
//   }
// }

// ─── Card button ──────────────────────────────────────────────────────────────

class _CardBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final bool expand;
  final VoidCallback onTap;

  const _CardBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = false,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13.sp, color: filled ? kWhiteColor : color),
            SizedBox(width: 5.w),
            Text(label, style: kTextSemiBold0(color: filled ? kWhiteColor : color)),
          ],
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}


// ─── Services shimmer ─────────────────────────────────────────────────────────

// class _ServicesShimmer extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return GridView.builder(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       itemCount: 8,
//       gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: 4,
//         mainAxisSpacing: 16.h,
//         crossAxisSpacing: 12.w,
//         childAspectRatio: 0.75,
//       ),
//       itemBuilder: (_, __) => Shimmer.fromColors(
//         baseColor: Colors.grey.shade200,
//         highlightColor: Colors.grey.shade100,
//         child: Column(
//           children: [
//             Container(
//               width: 60.w,
//               height: 60.w,
//               decoration: BoxDecoration(color: kWhiteColor, borderRadius: BorderRadius.circular(14.r)),
//             ),
//             SizedBox(height: 6.h),
//             Container(width: 48.w, height: 10.h, color: kWhiteColor),
//           ],
//         ),
//       ),
//     );
//   }
// }

// ─── Refer & Earn Banner ──────────────────────────────────────────────────────

class _ReferEarnBanner extends StatelessWidget {
  final WidgetRef ref;

  const _ReferEarnBanner({required this.ref});

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(systemSettingsProvider);

    return settingsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (settings) {
        final rewardSetting = settings.data.cast<dynamic>().firstWhere(
          (s) => s.settingKey == 'referral_reward_amount',
          orElse: () => null,
        );
        final rewardAmount = rewardSetting != null
            ? (int.tryParse(rewardSetting.settingValue.toString()) ?? 0)
            : 0;

        if (rewardAmount <= 0) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => AppNavigator.to(AppRoutes.referEarn),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20.w, 18.h, 12.w, 18.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_cBlue, Color(0xFF2E7CC2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(color: _cBlue.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              children: [
                // ── Left: Text + CTA ────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Refer & Earn', style: kTextBold1(color: Colors.white)),
                      SizedBox(height: 4.h),
                      RichText(
                        text: TextSpan(
                          style: kTextNormal0(color: Colors.white.withValues(alpha: 0.85)),
                          children: [
                            const TextSpan(text: 'Earn '),
                            TextSpan(
                              text: '₹$rewardAmount ',
                              style: kTextBold(color: const Color(0xFFFFD700)),
                            ),
                            const TextSpan(text: 'for every friend you refer!'),
                          ],
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8.r)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Refer Now', style: kTextSemiBold0(color: _cBlue)),
                            SizedBox(width: 4.w),
                            Icon(Icons.arrow_forward_rounded, size: 14.sp, color: _cBlue),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                // ── Right: Money illustration ───────────────
                Container(
                  width: 72.w,
                  height: 72.w,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer ring
                      Container(
                        width: 64.w,
                        height: 64.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5), width: 2),
                        ),
                      ),
                      // Inner coin
                      Container(
                        width: 48.w,
                        height: 48.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA726)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '₹',
                            style: TextStyle(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      // Small gift badge
                      Positioned(
                        right: 4.w,
                        bottom: 4.w,
                        child: Container(
                          width: 22.w,
                          height: 22.w,
                          decoration: BoxDecoration(
                            color: kSuccessColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 11.sp),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Guest Login Banner ────────────────────────────────────────────────────────

class _GuestLoginBanner extends StatelessWidget {
  const _GuestLoginBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => AppNavigator.to(AppRoutes.login),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20.w, 18.h, 12.w, 18.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_cBlue, _cOrange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [BoxShadow(color: _cBlue.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Login to unlock all features',
                    style: kTextBold1(color: Colors.white).copyWith(fontSize: 18.sp),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Join thousands of users managing their health effortlessly.',
                    style: kTextNormal0(color: Colors.white.withValues(alpha: 0.9)),
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.r)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Login / Sign Up', style: kTextSemiBold0(color: _cBlue)),
                        SizedBox(width: 6.w),
                        Icon(Icons.login_rounded, size: 14.sp, color: _cBlue),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(Icons.person_add_rounded, color: Colors.white, size: 32.sp),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Vetted Experts View ─────────────────────────────────────────────────────

class _VettedExpertsView extends StatelessWidget {
  const _VettedExpertsView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
      child: Column(
        children: [
          // ── Header Section ──
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: _cOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_rounded, color: _cOrange, size: 14.sp),
                SizedBox(width: 6.w),
                Text(
                  'QUALITY ASSURED',
                  style: kTextBold(color: _cOrange).copyWith(fontSize: 10.sp, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            'The Adhisaat Promise',
            style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 22.sp, letterSpacing: -0.5),
          ),
          SizedBox(height: 8.h),
          Text(
            'Premium healthcare quality at your fingertips',
            style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 13.sp, height: 1.4),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 24.h),

          // ── Feature Grid ──
          GridView.count(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12.h,
            crossAxisSpacing: 12.w,
            childAspectRatio: 1.15,

            children: const [
              _VettedItem(
                icon: Icons.access_time_rounded,
                title: '24/7 Dedicated',
                subtitle: 'Assistance',
                color: _cOrange,
              ),
              _VettedItem(
                icon: Icons.verified_user_rounded,
                title: 'Certified',
                subtitle: 'Medical Experts',
                color: _cBlue,
              ),
              _VettedItem(
                icon: Icons.local_offer_rounded,
                title: 'Best & Transparent',
                subtitle: 'Pricing',
                color: _cOrange,
              ),
              _VettedItem(
                icon: Icons.flash_on_rounded,
                title: 'Super Quick',
                subtitle: 'Medical Action',
                color: _cBlue,
              ),
            ],
          ),
          SizedBox(height: 32.h),

          // ── Footer Assurance ──
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_cBlue.withValues(alpha: 0.06), _cOrange.withValues(alpha: 0.06)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: _cBlue.withValues(alpha: 0.12), width: 1),
              boxShadow: [
                BoxShadow(color: _cBlue.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(color: _cBlue.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.shield_rounded, color: _cBlue, size: 18.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safe & Trusted',
                        style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 13.sp),
                      ),
                      Text(
                        'Every partner is background-verified and trained for your safety and peace of mind.',
                        style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 10.sp),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VettedItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _VettedItem({required this.icon, required this.title, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22.sp),
          ),
          SizedBox(height: 8.h),
          Flexible(
            child: Text(
              title,
              style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 12.sp, height: 1.1),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: 3.h),
          Flexible(
            child: Text(
              subtitle,
              style: kTextNormal(color: color).copyWith(fontSize: 10.sp, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// PROMO BANNERS SECTION
// ─────────────────────────────────────────────────────────────────────────
class _PromoBannersSection extends ConsumerStatefulWidget {
  const _PromoBannersSection();

  @override
  ConsumerState<_PromoBannersSection> createState() => _PromoBannersSectionState();
}

class _PromoBannersSectionState extends ConsumerState<_PromoBannersSection> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  void _startTimer(int pageCount) {
    _timer?.cancel();
    if (pageCount <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % pageCount;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final promosAsync = ref.watch(activePromoBannersProvider);

    return promosAsync.when(
      data: (promos) {
        if (promos.isEmpty) return const SizedBox.shrink();

        // Restart or update timer when page count changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startTimer(promos.length);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Padding(
            //   padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 8.h),
            //   child: Text('Exclusive Offers', style: kTextSemiBold(color: kTextSecondaryColor)),
            // ),
            AspectRatio(
              aspectRatio: 2.0,
              child: PageView.builder(
                controller: _pageController,
                itemCount: promos.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final promo = promos[index];
                  final imageUrl = promo.bannerImageUrl;

                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 16.w),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.m,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: AppRadius.m,
                      child: AppCachedImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholderPath: AppAssets.placeholder,
                        errorWidgetBuilder: Container(
                          color: kPrimaryColor.withValues(alpha: 0.1),
                          padding: EdgeInsets.all(16.w),
                          child: Row(
                            children: [
                              Icon(Icons.local_offer_outlined, color: kPrimaryColor, size: 36.sp),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      promo.title ?? promo.code,
                                      style: kTextBold2(color: kPrimaryColor),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (promo.description != null && promo.description!.isNotEmpty) ...[
                                      SizedBox(height: 4.h),
                                      Text(
                                        promo.description!,
                                        style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (promos.length > 1) ...[
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  promos.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(horizontal: 4.w),
                    width: _currentPage == index ? 16.w : 6.w,
                    height: 6.h,
                    decoration: BoxDecoration(
                      color: _currentPage == index ? kPrimaryColor : kBorderColor,
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 8.h),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(width: 120.w, height: 16.h, color: Colors.white),
            ),
          ),
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: AspectRatio(
              aspectRatio: 2.0,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.m),
              ),
            ),
          ),
        ],
      ),
      error: (err, stack) {
        kPrintError('Error loading promo codes: $err');
        return const SizedBox.shrink();
      },
    );
  }
}

// ─── Trust Badges Section ───────────────────────────────────────────────────

class _TrustBadgesSection extends StatelessWidget {
  const _TrustBadgesSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
      padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: kBorderColor.withValues(alpha: 0.8), width: 1.r),
      ),
      child: Row(
        children: [
          _buildBadge(
            icon: Icons.verified_user_rounded,
            iconColor: const Color(0xFF4CAF50),
            title: 'KYC Verified',
            subtitle: '100% Verified\nProfessionals',
          ),
          _buildDivider(),
          _buildBadge(
            icon: Icons.local_police_rounded,
            iconColor: kSecondaryColor,
            title: 'Police Verified',
            subtitle: 'Safety You\nCan Trust',
          ),
          _buildDivider(),
          _buildBadge(
            icon: Icons.card_membership_rounded,
            iconColor: const Color(0xFFFFA000),
            title: 'Trained & Certified',
            subtitle: 'Skilled. Trained.\nProfessional.',
          ),
          _buildDivider(),
          _buildBadge(
            icon: Icons.stars_rounded,
            iconColor: Colors.deepPurple,
            title: '4.8★ Rated',
            subtitle: 'Trusted by\nThousands',
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 18.sp),
          SizedBox(height: 3.h),
          Text(
            title,
            style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 8.5.sp),
            textAlign: TextAlign.center,
          ),
          Text(
            subtitle,
            style: kTextNormal(color: kTextHintColor).copyWith(fontSize: 6.5.sp, height: 1.2),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1.w, height: 24.h, color: kBorderColor.withValues(alpha: 0.8));
  }
}
