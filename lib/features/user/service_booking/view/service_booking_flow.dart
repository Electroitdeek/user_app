import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_edge_insets.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/common/app_bar_custom.dart';
import '../model/booking_model.dart';
import '../model/service_category_model.dart';
import 'steps/step1_select_service_page.dart';
import 'steps/step2_date_duration_page.dart';
import 'steps/step3_confirm_address_page.dart';

/// Centralized route constants for the booking flow
class BookingRoutes {
  static const String selectService = '/';
  static const String selectMode = '/mode';
  static const String dateDuration = '/date-duration';
  static const String address = '/address';
}

/// The main entry point for the service booking flow.
/// Orchestrates the navigation between steps and manages the shared [BookingRequest].
class ServiceBookingFlow extends StatefulWidget {
  final ServiceCategoryModel? initialMainCategory;
  final BookingRequest? initialRequest; // Allow passing a pre-filled request
  final String? initialRoute; // Allow starting at a specific step (e.g. dateDuration)
  final bool autofocusSearch;
  final bool isEmergency;

  const ServiceBookingFlow({
    super.key,
    this.initialMainCategory,
    this.initialRequest,
    this.initialRoute,
    this.autofocusSearch = false,
    this.isEmergency = false,
  });

  /// Static helper to create a route for this flow
  static Route route({
    ServiceCategoryModel? initialMainCategory,
    BookingRequest? initialRequest,
    String? initialRoute,
    bool autofocusSearch = false,
    bool isEmergency = false,
  }) {
    return MaterialPageRoute(
      builder: (_) => ServiceBookingFlow(
        initialMainCategory: initialMainCategory,
        initialRequest: initialRequest,
        initialRoute: initialRoute,
        autofocusSearch: autofocusSearch,
        isEmergency: isEmergency,
      ),
      settings: const RouteSettings(name: 'service_booking_flow'),
    );
  }

  @override
  State<ServiceBookingFlow> createState() => _ServiceBookingFlowState();
}

class _ServiceBookingFlowState extends State<ServiceBookingFlow> {
  late BookingRequest _request;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Initialize with the provided request or a fresh one
    _request = widget.initialRequest ?? BookingRequest();
  }

  /// Updates the internal request state with fresh data from a step
  void _updateRequest(BookingRequest updated) {
    setState(() {
      // Direct field-by-field copy is technically safer than a deep clone for this simple state
      _request.serviceType = updated.serviceType;
      _request.mode = updated.mode;
      _request.bookingType = updated.bookingType;
      _request.careModeName = updated.careModeName;
      _request.startDate = updated.startDate;
      _request.endDate = updated.endDate;
      _request.startTime = updated.startTime;
      _request.endTime = updated.endTime;
      _request.durationHours = updated.durationHours;
      _request.durationDays = updated.durationDays;
      _request.estimatedPrice = updated.estimatedPrice;
      _request.address = updated.address;
      _request.landmark = updated.landmark;
      _request.addressId = updated.addressId;
      _request.familyMemberId = updated.familyMemberId;
      _request.familyMemberName = updated.familyMemberName;
      _request.instructions = updated.instructions;
      _request.latitude = updated.latitude;
      _request.longitude = updated.longitude;
      _request.city = updated.city;
      _request.selectedProvider = updated.selectedProvider;
      _request.selectedProviderIds = updated.selectedProviderIds;
      _request.selectedProviderNames = updated.selectedProviderNames;
      _request.serviceRequestId = updated.serviceRequestId;
      _request.requestNumber = updated.requestNumber;
      _request.waitingWindowMinutes = updated.waitingWindowMinutes;
      _request.waitingStartedAt = updated.waitingStartedAt;
      _request.notifiedProviders = updated.notifiedProviders;
      _request.shiftType = updated.shiftType;
      _request.serviceStartShift = updated.serviceStartShift;
      _request.serviceMode = updated.serviceMode;
      _request.selectedPackageId = updated.selectedPackageId;
      _request.gstPercentage = updated.gstPercentage;
      _request.alternateDays = updated.alternateDays;
      _request.scheduledDates = updated.scheduledDates;
      _request.pinCode = updated.pinCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final canPopInternal = _navigatorKey.currentState?.canPop() ?? false;
        if (canPopInternal) {
          // Use maybePop so child PopScope widgets (e.g. payment page) can
          // intercept and show their own confirmation dialogs before popping.
          _navigatorKey.currentState?.maybePop();
        } else {
          // If we can't pop internally, we exit the whole flow
          Navigator.of(context).pop();
        }
      },
      child: Navigator(
        key: _navigatorKey,
        initialRoute: widget.initialRoute ?? BookingRoutes.selectService,
        onGenerateInitialRoutes: (navigator, initialRouteName) {
          return [
            navigator.widget.onGenerateRoute!(
              RouteSettings(name: initialRouteName),
            )!,
          ];
        },
        onGenerateRoute: (settings) {
          Widget page;
          switch (settings.name) {
            case BookingRoutes.selectService:
              page = Step1SelectServicePage(
                request: _request,
                onUpdate: _updateRequest,
                initialMainCategory: widget.initialMainCategory,
                autofocusSearch: widget.autofocusSearch,
                isEmergency: widget.isEmergency,
              );
              break;
            // case BookingRoutes.selectMode:
            //   page = Step2SelectModePage(request: _request, onUpdate: _updateRequest);
            //   break;
            case BookingRoutes.dateDuration:
              page = Step2DateDurationPage(request: _request, onUpdate: _updateRequest);
              break;
            case BookingRoutes.address:
              page = Step3ConfirmAddressPage(request: _request, onUpdate: _updateRequest);
              break;
            default:
              page = const Scaffold(body: Center(child: Text('Step Not Found')));
          }

          return MaterialPageRoute(builder: (_) => page, settings: settings);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Dynamic Booking Step Scaffold
// ─────────────────────────────────────────────────────

class BookingStepScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int currentStep;
  final int totalSteps;
  final Widget body;
  final Widget? bottomBar;
  final bool showProgress;
  final VoidCallback? onBack;

  const BookingStepScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.currentStep,
    required this.totalSteps,
    required this.body,
    this.bottomBar,
    this.showProgress = true,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScaffoldColor,
      appBar: CustomAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: kTextPrimaryColor,
          onPressed: () {
            if (onBack != null) {
              onBack!();
            } else {
              final nav = Navigator.of(context);
              if (nav.canPop()) {
                nav.maybePop();
              } else {
                Navigator.of(context, rootNavigator: true).maybePop();
              }
            }
          },
        ),
        title: title,
        centerTitle: true,
        bottom: showProgress
            ? PreferredSize(
                preferredSize: const Size.fromHeight(6),
                child: _StepProgressBar(current: currentStep, total: totalSteps),
              )
            : null,
      ),
      body: SafeArea(
        child: subtitle != null
            ? Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 6.h),
                    color: kScaffoldColor,
                    child: Text(
                      subtitle!,
                      style: kTextSemiBold0(color: kPrimaryColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Divider(height: 1, color: kBorderColor),
                  Expanded(child: body),
                ],
              )
            : body,
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}

class _StepProgressBar extends StatelessWidget {
  final int current;
  final int total;

  const _StepProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final filled = i < current;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: filled ? kPrimaryColor : kBorderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class BookingBottomBar extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  const BookingBottomBar({super.key, required this.label, required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kWhiteColor,
      padding: AppPadding.only(left: 20, right: 20, top: 12, bottom: 24),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48, // Standard primary button height
          child: ElevatedButton(
            onPressed: isLoading ? null : onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              disabledBackgroundColor: kButtonDisabledColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: kWhiteColor, strokeWidth: 2),
                  )
                : Text(label, style: kTextSemiBold2(color: kWhiteColor)),
          ),
        ),
      ),
    );
  }
}
