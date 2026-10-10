import 'dart:async';

import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:adhisaat_health_care/core/services/launch_url_service.dart';
import 'package:adhisaat_health_care/core/services/location_service.dart';
import 'package:adhisaat_health_care/core/storage/local_storage_service.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/core/utils/message_service.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/data/providers/system_settings_provider.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/bloc/provider_request_detail_bloc/provider_request_detail_bloc.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/dialogs/complete_confirm_dialog.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/dialogs/complete_session_dialog.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/dialogs/date_conflict_dialog.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/dialogs/request_accepted_dialog.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/dialogs/request_conflict_dialog.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/dialogs/request_unavailable_dialog.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/widgets/customer_details_sheet.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/widgets/full_day_booking_sheet.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/widgets/full_schedule_sheet.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/widgets/request_schedule_bottom_sheet.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/widgets/session_dashboard.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/widgets/start_booking_popup.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/widgets/start_booking_sheet.dart';
import 'package:adhisaat_health_care/shared/widgets/buttons/custom_button.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_cached_image.dart';
import 'package:adhisaat_health_care/shared/widgets/common/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../di/locator.dart';
import '../../provider_home/data/models/service_request.dart';
import '../data/models/booking_model.dart';
import '../data/models/provider_service_request_model.dart';
import '../data/models/request_status.dart';
import '../data/models/sub_block_model.dart';

class ProviderRequestDetailPage extends StatefulWidget {
  final int? requestId;
  final int? bookingId;

  /// True when navigated from an incoming request notification — plays alert sound + haptics.
  final bool isIncomingAlert;

  const ProviderRequestDetailPage({super.key, this.requestId, this.bookingId, this.isIncomingAlert = false});

  /// Prevents duplicate navigation when multiple notifications arrive simultaneously.
  static bool _isNavigating = false;

  /// Navigate to this page for an incoming alert. Deduplicates concurrent calls.
  static void showIncomingRequest(int requestId) {
    if (_isNavigating) {
      debugPrint('ProviderRequestDetailPage: already navigating, skipping duplicate');
      return;
    }
    _isNavigating = true;
    final navState = AppNavigator.navigatorKey.currentState;
    if (navState == null) {
      _isNavigating = false;
      return;
    }
    // Defer to after the current frame: callers (e.g. dismissing the floating
    // overlay in onView) leave the Navigator locked, so a synchronous push
    // throws `!_debugLocked`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navState
          .pushNamed(AppRoutes.providerRequestDetail, arguments: {'requestId': requestId, 'isIncomingAlert': true})
          .whenComplete(() => _isNavigating = false);
    });
  }

  @override
  State<ProviderRequestDetailPage> createState() => _ProviderRequestDetailPageState();
}

class _ProviderRequestDetailPageState extends State<ProviderRequestDetailPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  static const _navy = Color(0xFF123B61);
  static const _blue = kPrimaryColor;
  static const _greyBg = Color(0xFFF7F8FC);
  static const _greyText = Color(0xFF6B7280);
  static const _greyBorder = Color(0xFFE5E7EB);
  static const _green = Color(0xFF22C55E);

  bool _isCancelledByUser = false;
  int _selectedHalf = 0; // stage2: 0=none 1=first 2=second
  final Set<int> _selectedBlockIds = {}; // stage3 multi-select

  // ── new request UI state ──
  GoogleMapController? _mapController;
  Timer? _newRequestCountdown;
  int _newRequestSecsLeft = 0;
  bool _countdownStarted = false;
  ProviderServiceRequestModel? _cachedRequest;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    NotificationService().registerBlocCallback(_handleNotification);
    // Ensure system settings are loaded so privacy-unlock threshold reflects server value.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ProviderScope.containerOf(context, listen: false)
          .read(systemSettingsProvider.future)
          .then((_) {
            if (mounted) setState(() {});
          })
          .catchError((_) {});
    });
  }

  void _handleNotification(String type, Map<String, dynamic> data) {
    if (!mounted) return;
    final notifRequestId = data['request_id']?.toString() ?? data['service_request_id']?.toString();
    final notifBookingId = data['booking_id']?.toString();
    final matchesRequest = notifRequestId != null && widget.requestId?.toString() == notifRequestId;
    final matchesBooking = notifBookingId != null && widget.bookingId?.toString() == notifBookingId;
    final matchesShared =
        (notifRequestId != null && widget.bookingId?.toString() == notifRequestId) ||
        (notifBookingId != null && widget.requestId?.toString() == notifBookingId);

    if (matchesRequest || matchesBooking || matchesShared) {
      if (type == 'booking_cancelled') {
        setState(() => _isCancelledByUser = true);
        MessageService.showError('User has cancelled this booking');
      }
      context.read<ProviderRequestDetailBloc>().add(RefreshProviderRequestDetail());
    } else if (type == 'booking_cancelled' ||
        type == 'booking_confirmed' ||
        type == 'request_accepted' ||
        type == 'booking_payment_confirmed' ||
        type == 'provider_waiting_for_payment') {
      context.read<ProviderRequestDetailBloc>().add(RefreshProviderRequestDetail());
    }
  }

  @override
  void dispose() {
    NotificationService().unregisterBlocCallback(_handleNotification);
    _pulseController.dispose();
    _newRequestCountdown?.cancel();
    _mapController?.dispose();
    _mapController = null;
    super.dispose();
  }

  // ─── helpers ───
  String _fmt(String? raw) => (raw == null || raw.isEmpty) ? '—' : AppDateFormatter.dateTimeShort(raw);

  String _fmtDate(String? raw) => (raw == null || raw.isEmpty) ? '—' : AppDateFormatter.dateShort(raw);

  String _fmtTime(String? raw) => (raw == null || raw.isEmpty) ? '—' : AppDateFormatter.formatTimeString(raw);

  // String _dow(String? raw) => AppDateFormatter.weekdayShort(raw);

  String _age(String? dob) => AppDateFormatter.ageYears(dob);

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  bool _isPrivacyUnlocked(ProviderServiceRequestModel r) {
    final now = DateTime.now();
    final reminderMinutes = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(bookingStartReminderMinutesProvider);
    final threshold = now.add(Duration(minutes: reminderMinutes));
    final allBlocks = r.bookings.isNotEmpty ? r.bookings.expand((b) => b.subBlocks).toList() : r.subBlocks;
    if (allBlocks.isNotEmpty) {
      // The next block that still needs attention — i.e. not finished yet.
      // A block that has already started (ready to start / overdue / ongoing)
      // must always unlock, even if it started more than the reminder window ago.
      final pending =
          allBlocks
              .where((b) => b.blockStatus != SubBlockStatus.completed && b.blockStatus != SubBlockStatus.cancelled)
              .toList()
            ..sort(
              (a, b) => (a.scheduledStartDateTime ?? DateTime(9999)).compareTo(
                b.scheduledStartDateTime ?? DateTime(9999),
              ),
            );
      if (pending.isNotEmpty) {
        final start = pending.first.scheduledStartDateTime;
        if (start == null) return true;
        if (!start.isAfter(now)) return true;
        return start.isBefore(threshold);
      }
      return true;
    }
    final startDate = r.startDate;
    final startTime = r.startTime;
    if (startDate != null && startDate.isNotEmpty) {
      try {
        final date = DateTime.parse(startDate);
        final parts = (startTime ?? '').split(':');
        final h = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
        final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
        return DateTime(date.year, date.month, date.day, h, m).isBefore(threshold);
      } catch (_) {}
    }
    return false;
  }

  /// Shown when a provider taps a privacy-locked action (View Profile, Call,
  /// Navigate). Message reflects the configurable reminder window.
  void _showPrivacyLockedInfo() {
    final mins = ProviderScope.containerOf(context, listen: false).read(bookingStartReminderMinutesProvider);
    final String label;
    if (mins % 60 == 0) {
      final h = mins ~/ 60;
      label = '$h hour${h == 1 ? '' : 's'}';
    } else {
      label = '$mins minutes';
    }
    MessageService.showInfo('Patient details will be available $label before your booking start time.');
  }

  List<SubBlock> _blocks(ProviderServiceRequestModel r) => r.subBlocks;

  int _stage(ProviderServiceRequestModel r) => r.requestStage;

  List<BookingModel> _bookings(ProviderServiceRequestModel r) => r.bookings;

  List<SubBlock> _bookingBlocks(List<BookingModel> bookings) => bookings.expand((b) => b.subBlocks).toList();

  double _totalPayout(List<SubBlock> blocks) => blocks.fold(0.0, (s, b) => s + b.providerPayout);

  /// Effective payout. Emergency requests aren't priced per-block until paid, so
  /// derive the partner payout from the pricing breakdown (total − commission).
  ({double total, double perShift}) _effectivePayout(ProviderServiceRequestModel r, List<SubBlock> blocks) {
    double total = _totalPayout(blocks);
    double perShift = blocks.isNotEmpty ? blocks.first.providerPayout : 0.0;
    if (r.isEmergency == 1 && r.paymentStatus == 'pending' && total <= 0) {
      final partner = (r.totalAmount ?? 0) - (r.companyCommission ?? 0);
      if (partner > 0) {
        total = partner;
        perShift = blocks.isNotEmpty ? partner / blocks.length : partner;
      }
    }
    return (total: total, perShift: perShift);
  }

  String _genderLabel(dynamic v) {
    switch (v?.toString().toLowerCase()) {
      case 'male':
        return 'Male Only';
      case 'female':
        return 'Female Only';
      default:
        return 'Any Gender';
    }
  }

  ServiceRequest _toServiceRequest(ProviderServiceRequestModel r) => ServiceRequest(
    id: r.id.toString(),
    patientName: r.customerName,
    age: 0,
    serviceType: r.serviceCategoryName,
    address: r.address,
    distance: '${r.distanceKm.toStringAsFixed(1)} km',
    time: r.startTimeText,
    date: r.startDateText,
    payment: r.totalAmount ?? r.basePrice ?? 0,
    latitude: r.serviceLatitude,
    longitude: r.serviceLongitude,
    isEmergency: r.isEmergency == 1,
    bookingId: r.id,
    patientPhone: r.customerPhone,
  );

  // ─── build ───
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProviderRequestDetailBloc, ProviderRequestDetailState>(
      listener: (context, state) {
        void refresh() => context.read<ProviderRequestDetailBloc>().add(RefreshProviderRequestDetail());
        if (state is ProviderRequestDetailAccepted) {
          _showAcceptedDialog(context, state.requestId, state.message);
        }
        if (state is ProviderRequestDetailDateConflict) {
          DateConflictDialog.show(
            context,
            conflictDates: state.conflictDates,
            message: state.message,
            onDismissed: refresh,
          );
        }
        if (state is ProviderRequestDetailConflict) {
          _showConflictDialog(context, state.message, state.invalidIds, onDismissed: refresh);
        }
        if (state is ProviderRequestDetailUnavailable) {
          _showUnavailableDialog(context);
        }
        if (state is ProviderRequestDetailError) {
          MessageService.showError(state.message);
        }
      },
      builder: (context, state) {
        ProviderServiceRequestModel? r;
        if (state is ProviderRequestDetailLoaded) {
          _cachedRequest = state.request;
          r = state.request;
        } else {
          r = _cachedRequest;
        }
        final reqStatus = RequestStatus.fromString(r?.requestStatus);

        if (r != null && reqStatus == RequestStatus.searching && _bookings(r).isEmpty) {
          return _buildNewRequestScaffold(r);
        }

        // partially_accepted with no bookings yet — behave like searching
        if (r != null && reqStatus.isPartiallyAccepted && _bookings(r).isEmpty) {
          return _buildNewRequestScaffold(r);
        }

        // accepted/in_progress with bookings → operational session dashboard
        final isAccepted =
            reqStatus == RequestStatus.accepted ||
            reqStatus == RequestStatus.partiallyAccepted ||
            reqStatus == RequestStatus.standby ||
            reqStatus == RequestStatus.completed;
        final isInProgress = reqStatus.isActive;
        final hasBookings = r != null && r.bookings.isNotEmpty;

        if (r != null && (isAccepted || isInProgress) && hasBookings) {
          return _buildSessionDashboardScaffold(r);
        }

        return Scaffold(
          backgroundColor: _greyBg,
          appBar: CustomAppBar(title: 'Request Details'),
          bottomNavigationBar: (r != null && isInProgress) ? _buildBottomBar(r, false) : null,
          body: SafeArea(child: _buildBody(state)),
        );
      },
    );
  }

  // ─── Session dashboard scaffold ───────────────────────────────────────────

  Widget _buildSessionDashboardScaffold(ProviderServiceRequestModel r) {
    return Scaffold(
      backgroundColor: _greyBg,
      appBar: CustomAppBar(title: 'Booking Details'),
      body: SafeArea(
        child: RefreshIndicator(
          color: _blue,
          onRefresh: () async => context.read<ProviderRequestDetailBloc>().add(RefreshProviderRequestDetail()),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBookingHeaderCard(r),
                SizedBox(height: 16.h),
                SessionDashboard(
                  request: r,
                  onStartBooking: (block) => _showStartBookingSheet(r, block),
                  onCompleteBooking: (block) => _showCompleteSessionDialog(r, block),
                ),
                // SizedBox(height: 16.h),
                _buildPatientCard(r),
                SizedBox(height: 14.h),
                _buildAddressCard(r),
                if ((r.specialInstructions ?? '').isNotEmpty) ...[
                  SizedBox(height: 14.h),
                  _buildInstructionsCard(r),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Session-view header (accepted/in-progress bookings) ─────────────────

  Widget _buildBookingHeaderCard(ProviderServiceRequestModel r) {
    final allBlocks = r.bookings.expand((b) => b.subBlocks).toList();
    final totalSessions = allBlocks.length;

    final now = DateTime.now();
    final upcoming =
        allBlocks.where((b) {
          final dt = b.scheduledStartDateTime;
          return dt != null && dt.isAfter(now.subtract(const Duration(hours: 1)));
        }).toList()..sort(
          (a, b) =>
              (a.scheduledStartDateTime ?? DateTime(9999)).compareTo(b.scheduledStartDateTime ?? DateTime(9999)),
        );
    final nextBlock = upcoming.isNotEmpty ? upcoming.first : (allBlocks.isNotEmpty ? allBlocks.last : null);

    final bookingStatus = r.bookings.isNotEmpty ? r.bookings.first.bookingStatus : r.requestStatus;

    final shiftIcon = r.shiftType == 'night'
        ? Icons.nightlight_outlined
        : r.shiftType == '24_hours'
        ? Icons.brightness_4_rounded
        : Icons.wb_sunny_outlined;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kPrimaryColor, kSecondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [BoxShadow(color: _navy.withValues(alpha: 0.30), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: request number + status ──
          Row(
            children: [
              Expanded(
                child: Text(
                  r.requestNumber,
                  style: kTextNormal(color: Colors.white.withValues(alpha: 0.55)).copyWith(fontSize: 10.sp),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8.w),
              _statusChip(bookingStatus),
            ],
          ),
          SizedBox(height: 6.h),

          // ── Row 2: service name ──
          Text(
            r.serviceCategoryName,
            style: kTextBold2(color: Colors.white).copyWith(fontSize: 17.sp),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 10.h),

          // ── Row 3: info chips (inline, compact) ──
          Row(
            children: [
              Icon(Icons.home_outlined, size: 11.sp, color: Colors.white.withValues(alpha: 0.7)),
              SizedBox(width: 3.w),
              Text(
                r.serviceModeText,
                style: kTextNormal(color: Colors.white.withValues(alpha: 0.7)).copyWith(fontSize: 11.sp),
              ),
              SizedBox(width: 10.w),
              Container(width: 1, height: 10.h, color: Colors.white.withValues(alpha: 0.25)),
              SizedBox(width: 10.w),
              if (r.shiftType != null) ...[
                Icon(shiftIcon, size: 11.sp, color: Colors.white.withValues(alpha: 0.7)),
                SizedBox(width: 3.w),
                Text(
                  r.formattedShiftType,
                  style: kTextNormal(color: Colors.white.withValues(alpha: 0.7)).copyWith(fontSize: 11.sp),
                ),
                SizedBox(width: 10.w),
                Container(width: 1, height: 10.h, color: Colors.white.withValues(alpha: 0.25)),
                SizedBox(width: 10.w),
              ],
              Icon(Icons.event_repeat_outlined, size: 11.sp, color: Colors.white.withValues(alpha: 0.7)),
              SizedBox(width: 3.w),
              Flexible(
                child: Text(
                  r.serviceTypeText.replaceAll('_', ' '),
                  style: kTextNormal(color: Colors.white.withValues(alpha: 0.7)).copyWith(fontSize: 11.sp),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
          SizedBox(height: 12.h),

          // ── Row 4: sessions + next session + km ──
          Row(
            children: [
              // Sessions count
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 12.sp, color: Colors.white),
                    SizedBox(width: 4.w),
                    Text(
                      '$totalSessions Sessions',
                      style: kTextSemiBold(color: Colors.white).copyWith(fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              // Next session
              if (nextBlock != null)
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 11.sp, color: Colors.white.withValues(alpha: 0.65)),
                      SizedBox(width: 3.w),
                      Flexible(
                        child: Text(
                          '${_fmtDate(nextBlock.scheduledDate)}  ·  ${nextBlock.startLabel}',
                          style: kTextNormal(color: Colors.white.withValues(alpha: 0.8)).copyWith(fontSize: 11.sp),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(width: 6.w),
              // Distance
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on_outlined, size: 11.sp, color: Colors.white.withValues(alpha: 0.65)),
                  SizedBox(width: 2.w),
                  Text(
                    '${r.distanceKm.toStringAsFixed(1)} km',
                    style: kTextNormal(color: Colors.white.withValues(alpha: 0.75)).copyWith(fontSize: 11.sp),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAcceptedDialog(BuildContext context, int requestId, String message) {
    void refresh() => context.read<ProviderRequestDetailBloc>().add(RefreshProviderRequestDetail());
    RequestAcceptedDialog.show(
      context,
      requestId: requestId,
      message: message,
      onViewBooking: refresh,
      onDismissed: refresh,
    );
  }

  void _showConflictDialog(
    BuildContext context,
    String message,
    List<int> invalidIds, {
    VoidCallback? onDismissed,
  }) {
    RequestConflictDialog.show(context, message: message, invalidIds: invalidIds, onDismissed: onDismissed);
  }

  void _showUnavailableDialog(BuildContext context) {
    RequestUnavailableDialog.show(context);
  }

  void _showAcceptSheet(BuildContext context, ProviderServiceRequestModel r) {
    void onAccept(List<int> ids) =>
        context.read<ProviderRequestDetailBloc>().add(AcceptProviderRequest(requestId: r.id, subBlockIds: ids));

    final reqStatus = RequestStatus.fromString(r.requestStatus);
    final stage = r.requestStage;

    if (stage == 4) {
      if (reqStatus == RequestStatus.standby || reqStatus == RequestStatus.searching) {
        // Standby or Searching: same accept flow as stage 3
        if (r.isFullDayShift) {
          FullDayBookingSheet.show(context: context, request: r, onAccept: onAccept, stage: 3);
        } else {
          RequestScheduleBottomSheet.show(context: context, request: r, onAccept: onAccept, overrideStage: 3);
        }
      } else {
        _showRequestExpired(context);
      }
      return;
    }

    // Stage 2: full-day → FullDayBookingSheet with half options; non-full-day → existing halves UI
    if (stage == 2) {
      if (r.isFullDayShift) {
        FullDayBookingSheet.show(context: context, request: r, onAccept: onAccept, stage: 2);
      } else {
        RequestScheduleBottomSheet.show(context: context, request: r, onAccept: onAccept);
      }
      return;
    }

    if (r.isFullDayShift) {
      FullDayBookingSheet.show(context: context, request: r, onAccept: onAccept, stage: stage);
    } else {
      RequestScheduleBottomSheet.show(context: context, request: r, onAccept: onAccept);
    }
  }

  void _showRequestExpired(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        contentPadding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 16.h),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_off_rounded, color: kErrorColor, size: 48.sp),
            SizedBox(height: 14.h),
            Text('Request Expired', style: kTextBold2(), textAlign: TextAlign.center),
            SizedBox(height: 8.h),
            Text(
              'This opportunity is no longer available. The acceptance window has passed.',
              style: kTextNormal(color: const Color(0xFF6B7280)).copyWith(height: 1.4),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              height: 44.h,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  elevation: 0,
                ),
                child: Text('Got it', style: kTextSemiBold1(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── bottom bar ───
  Widget _buildBottomBar(ProviderServiceRequestModel r, bool isSearching) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: AppPadding.symmetric(h: 16, v: 12),
          child: isSearching ? _buildSearchActions(r) : _buildInProgressActions(r),
        ),
      ),
    );
  }

  Widget _buildSearchActions(ProviderServiceRequestModel r) {
    final stage = _stage(r);
    bool canAccept;
    String acceptLabel;

    if (stage == 1) {
      canAccept = true;
      acceptLabel = 'Accept Full Booking';
    } else if (stage == 2) {
      canAccept = _selectedHalf != 0;
      acceptLabel = _selectedHalf == 1
          ? 'Accept First Half'
          : _selectedHalf == 2
          ? 'Accept Second Half'
          : 'Select a Period First';
    } else {
      canAccept = _selectedBlockIds.isNotEmpty;
      acceptLabel = _selectedBlockIds.isNotEmpty
          ? 'Accept (${_selectedBlockIds.length} days)'
          : 'Select Days First';
    }

    return Row(
      children: [
        Expanded(
          child: CustomButton(
            onPressed: canAccept ? () => _showAcceptSheet(context, r) : null,
            title: acceptLabel,
            iconData: Icons.check_circle_outline,
            backgroundColor: canAccept ? _green : Colors.grey.shade300,
            textStyle: kTextSemiBold(color: Colors.white),
            iconColor: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            height: 52.h,
          ),
        ),
        SizedBox(width: 10.w),
        CustomButton(
          onPressed: () => context.read<ProviderRequestDetailBloc>().add(RejectProviderRequest(requestId: r.id)),
          title: 'Reject',
          iconData: Icons.cancel_outlined,
          backgroundColor: Colors.red.shade400,
          textStyle: kTextSemiBold(color: Colors.white),
          iconColor: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          height: 52.h,
          width: 110.w,
        ),
      ],
    );
  }

  Widget _buildInProgressActions(ProviderServiceRequestModel r) {
    final isWaitingForPayment =
        r.isEmergency == 1 &&
        r.requestStatus.toLowerCase() == 'accepted' &&
        r.paymentStatus.toLowerCase() == 'pending';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (r.serviceStarted && r.serviceStartedAt != null)
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_outlined, size: 14.sp, color: _blue),
                SizedBox(width: 6.w),
                Text(
                  'Started: ${_fmt(r.serviceStartedAt)}',
                  style: kTextMedium(color: _blue).copyWith(fontSize: 12.sp),
                ),
              ],
            ),
          ),
        if (r.serviceStarted)
          Row(
            children: [
              if (r.isEmergency == 1) ...[
                Expanded(
                  child: CustomButton(
                    onPressed: () =>
                        AppNavigator.to(AppRoutes.providerActiveService, arguments: _toServiceRequest(r)),
                    title: 'Navigate',
                    iconData: Icons.navigation_rounded,
                    backgroundColor: _green,
                    textStyle: kTextSemiBold(color: Colors.white),
                    iconColor: Colors.white,
                    borderRadius: BorderRadius.circular(14.r),
                    height: 52.h,
                  ),
                ),
                SizedBox(width: 10.w),
              ],
              Expanded(
                child: CustomButton(
                  onPressed: () {
                    final block = r.bookings
                        .expand((bk) => bk.subBlocks)
                        .where((b) => b.status.toLowerCase() == 'in_progress')
                        .cast<SubBlock?>()
                        .firstWhere((_) => true, orElse: () => null);
                    if (block != null) {
                      _showCompleteSessionDialog(r, block);
                    } else {
                      _showCompleteConfirmDialog(r);
                    }
                  },
                  title: 'Complete',
                  iconData: Icons.verified_rounded,
                  backgroundColor: _blue,
                  textStyle: kTextSemiBold(color: Colors.white),
                  iconColor: Colors.white,
                  borderRadius: BorderRadius.circular(14.r),
                  height: 52.h,
                ),
              ),
            ],
          )
        else
          CustomButton(
            isEnable: !isWaitingForPayment,
            onPressed: () {
              final block =
                  r.bookings
                      .expand((bk) => bk.subBlocks)
                      .where((b) => b.status.toLowerCase() == 'assigned')
                      .cast<SubBlock?>()
                      .firstWhere((_) => true, orElse: () => null) ??
                  r.subBlocks
                      .where((b) => b.status.toLowerCase() == 'assigned')
                      .cast<SubBlock?>()
                      .firstWhere((_) => true, orElse: () => null);
              if (block != null) {
                _showStartBookingSheet(r, block);
              } else {
                _showStartBookingPopup(r);
              }
            },
            title: isWaitingForPayment ? 'Waiting for customer payment' : 'Start Session',
            iconData: isWaitingForPayment ? Icons.hourglass_empty_rounded : Icons.play_circle_outline_rounded,
            width: double.infinity,
            backgroundColor: isWaitingForPayment ? Colors.grey.shade400 : _blue,
            textStyle: kTextSemiBold(color: isWaitingForPayment ? Colors.grey.shade100 : Colors.white),
            iconColor: isWaitingForPayment ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            height: 52.h,
          ),
      ],
    );
  }

  // ─── body ───
  Widget _buildBody(ProviderRequestDetailState state) {
    if (state is ProviderRequestDetailLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is ProviderRequestDetailError) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 80.sp, color: _blue.withValues(alpha: 0.4)),
              SizedBox(height: 16.h),
              Text('Request Not Found', style: kTextBold1().copyWith(fontSize: 20.sp)),
              SizedBox(height: 8.h),
              Text(
                'This request may have been moved or cancelled.',
                style: kTextNormal(color: _greyText),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: TextButton.styleFrom(foregroundColor: _blue),
              ),
            ],
          ),
        ),
      );
    }
    if (state is! ProviderRequestDetailLoaded) return const SizedBox.shrink();

    final r = state.request;
    final blocks = r.bookings.isNotEmpty ? r.bookings.expand((b) => b.subBlocks).toList() : _blocks(r);
    final stage = _stage(r);
    final reqStatus = RequestStatus.fromString(r.requestStatus);
    final isSearching = reqStatus == RequestStatus.searching;
    final isPartiallyAccepted = reqStatus.isPartiallyAccepted;
    final bookings = isPartiallyAccepted ? _bookings(r) : <BookingModel>[];

    return CustomRefreshIndicator(
      onRefresh: () async => context.read<ProviderRequestDetailBloc>().add(RefreshProviderRequestDetail()),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPaymentNotice(r),
            _buildHeaderCard(r),
            SizedBox(height: 14.h),
            if (isPartiallyAccepted && bookings.isNotEmpty) ...[
              _buildAssignedSessionsCard(_bookingBlocks(bookings), bookings),
              SizedBox(height: 14.h),
            ] else ...[
              _buildSchedulePreview(blocks),
              SizedBox(height: 14.h),
            ],
            if (isSearching) ...[_buildAvailabilitySection(r, stage, blocks), SizedBox(height: 14.h)],
            if ((r.specialInstructions ?? '').isNotEmpty) ...[_buildInstructionsCard(r), SizedBox(height: 14.h)],
            _buildPatientCard(r),
            SizedBox(height: 14.h),
            _buildAddressCard(r),
            SizedBox(height: 14.h),
            _buildEarningsCard(r, blocks),
          ],
        ),
      ),
    );
  }

  // ─── payment notice ───
  Widget _buildPaymentNotice(ProviderServiceRequestModel r) {
    final rs = RequestStatus.fromString(r.requestStatus);

    if (rs.isActive) {
      return _noticeBanner(
        Icons.check_circle_rounded,
        Colors.green,
        'Payment Successful! ',
        'The service is now active.',
      );
    }
    if (rs == RequestStatus.cancelled || _isCancelledByUser) {
      return _noticeBanner(
        Icons.cancel_rounded,
        Colors.red,
        'Booking Cancelled! ',
        'The user has cancelled this booking.',
      );
    }
    if (rs == RequestStatus.accepted && !r.isPaymentDone && r.isEmergency == 1) {
      return Padding(
        padding: EdgeInsets.only(bottom: 16.h),
        child: Row(
          children: [
            ScaleTransition(
              scale: Tween<double>(
                begin: 0.9,
                end: 1.1,
              ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
              child: Icon(Icons.privacy_tip_rounded, color: Colors.green, size: 20.sp),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Waiting for payment... ',
                      style: kTextSemiBold(color: Colors.green.shade700),
                    ),
                    TextSpan(
                      text: 'Contact revealed after confirmation.',
                      style: kTextNormal0(color: _greyText),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 10.w),
            SizedBox(
              width: 14.sp,
              height: 14.sp,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.green.withValues(alpha: 0.4)),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _noticeBanner(IconData icon, Color color, String bold, String normal) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: bold,
                    style: kTextSemiBold(color: color),
                  ),
                  TextSpan(
                    text: normal,
                    style: kTextNormal0(color: _greyText),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── premium header card ───
  Widget _buildHeaderCard(ProviderServiceRequestModel r) {
    final startDate = r.startDate;
    final endDate = r.endDate;
    final startTime = r.startTime;
    final endTime = r.endTime;
    final isCancelled = RequestStatus.fromString(r.requestStatus) == RequestStatus.cancelled;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2F4E), Color(0xFF123B61), Color(0xFF1F63A2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [BoxShadow(color: _navy.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      padding: AppPadding.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // request number + status
          Row(
            children: [
              Expanded(
                child: Text(
                  r.requestNumber,
                  style: kTextNormal(color: Colors.white.withValues(alpha: 0.6)).copyWith(fontSize: 11.sp),
                ),
              ),
              _statusChip(
                _isCancelledByUser
                    ? 'cancelled'
                    : r.bookings.isNotEmpty
                    ? r.bookings.first.bookingStatus
                    : r.requestStatus,
              ),
            ],
          ),
          SizedBox(height: 10.h),

          // emergency tag
          if (r.isEmergency == 1)
            Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: AppPadding.symmetric(h: 8, v: 4),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6.r)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emergency, size: 12.sp, color: Colors.white),
                  SizedBox(width: 4.w),
                  Text(
                    'EMERGENCY',
                    style: kTextBold().copyWith(fontSize: 10.sp, color: Colors.white),
                  ),
                ],
              ),
            ),

          // service name — prefer service.name from API, fall back to category name
          Text(
            r.serviceCategoryName,
            style: kTextBold2(color: Colors.white).copyWith(fontSize: 20.sp),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 12.h),

          // chips row
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children: [
              if (r.isEmergency != 1) _headerChip(Icons.home_outlined, r.serviceModeText),
              if (r.shiftType != null && r.isEmergency != 1)
                _headerChip(
                  r.shiftType == 'night' ? Icons.nightlight_outlined : Icons.wb_sunny_outlined,
                  '${r.formattedShiftType} Shift',
                ),
              if (r.isEmergency != 1)
                _headerChip(Icons.event_repeat_outlined, r.serviceTypeText.replaceAll('_', ' ')),
            ],
          ),
          SizedBox(height: 16.h),
          Divider(color: Colors.white.withValues(alpha: 0.18)),
          SizedBox(height: 14.h),

          // date range row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'START',
                      style: kTextNormal(
                        color: Colors.white.withValues(alpha: 0.55),
                      ).copyWith(fontSize: 10.sp, letterSpacing: 0.8),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _fmtDate(startDate),
                      style: kTextSemiBold(color: Colors.white).copyWith(fontSize: 14.sp),
                    ),
                    Text(
                      _fmtTime(startTime),
                      style: kTextNormal(color: Colors.white.withValues(alpha: 0.75)).copyWith(fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
              if (r.isEmergency != 1) ...[
                Column(
                  children: [
                    Icon(Icons.arrow_forward_rounded, color: Colors.white.withValues(alpha: 0.5), size: 16.sp),
                    SizedBox(height: 6.h),
                    if (r.durationDays != null)
                      Container(
                        padding: AppPadding.symmetric(h: 10, v: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          '${r.durationDays} Days',
                          style: kTextBold().copyWith(fontSize: 11.sp, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'END',
                        style: kTextNormal(
                          color: Colors.white.withValues(alpha: 0.55),
                        ).copyWith(fontSize: 10.sp, letterSpacing: 0.8),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        _fmtDate(endDate),
                        style: kTextSemiBold(color: Colors.white).copyWith(fontSize: 14.sp),
                        textAlign: TextAlign.end,
                      ),
                      Text(
                        _fmtTime(endTime),
                        style: kTextNormal(color: Colors.white.withValues(alpha: 0.75)).copyWith(fontSize: 12.sp),
                        textAlign: TextAlign.end,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 14.h),
          Divider(color: Colors.white.withValues(alpha: 0.18)),
          SizedBox(height: 10.h),

          if (!isCancelled) ...[
            // distance + gender pref
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 13.sp, color: Colors.white.withValues(alpha: 0.65)),
                SizedBox(width: 4.w),
                Text(
                  '${r.distanceKm.toStringAsFixed(2)} km away',
                  style: kTextNormal(color: Colors.white.withValues(alpha: 0.75)).copyWith(fontSize: 12.sp),
                ),
                const Spacer(),
                // Icon(Icons.person_search_outlined, size: 13.sp, color: Colors.white.withValues(alpha: 0.65)),
                // SizedBox(width: 4.w),
                // Text(
                //   _genderLabel(r.genderPreference),
                //   style: kTextNormal(color: Colors.white.withValues(alpha: 0.75)).copyWith(fontSize: 12.sp),
                // ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: Colors.white),
          SizedBox(width: 5.w),
          Text(
            label,
            style: kTextMedium(color: Colors.white).copyWith(fontSize: 11.sp),
          ),
        ],
      ),
    );
  }

  // ─── earnings card ───
  Widget _buildEarningsCard(ProviderServiceRequestModel r, List<SubBlock> blocks) {
    final eff = _effectivePayout(r, blocks);
    final perDay = eff.perShift;
    final total = eff.total;
    final rs = RequestStatus.fromString(r.requestStatus);
    final earningsLabel = rs == RequestStatus.cancelled
        ? 'Potential Earnings (Cancelled)'
        : rs == RequestStatus.completed
        ? 'Total Earned'
        : 'Expected Earnings';

    return Container(
      padding: AppPadding.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF9EE), Color(0xFFF1FAF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFA8D5B4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: AppPadding.all(7),
                decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(10.r)),
                child: Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 16.sp),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  earningsLabel,
                  style: kTextSemiBold1(color: Colors.green.shade800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              _earningTile('Per Session', NumberUtils.formatCurrency(perDay), false),
              Container(width: 1, height: 36.h, color: Colors.green.shade200),
              _earningTile('Total Payout', NumberUtils.formatCurrency(total), false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _earningTile(String label, String value, bool isDeduction) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: kTextBold(
              color: isDeduction ? Colors.orange.shade800 : Colors.green.shade900,
            ).copyWith(fontSize: 13.sp),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 3.h),
          Text(
            label,
            style: kTextNormal(color: Colors.green.shade700).copyWith(fontSize: 10.sp),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── schedule preview ───
  Widget _buildSchedulePreview(List<SubBlock> blocks) {
    final preview = blocks.take(3).toList();
    final completedCount = blocks.where((b) => b.blockStatus == SubBlockStatus.completed).length;
    final progressPct = blocks.isEmpty ? 0.0 : completedCount / blocks.length;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(7.w),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9.r),
                ),
                child: Icon(Icons.calendar_month_rounded, color: _blue, size: 16.sp),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text('Schedule', style: kTextSemiBold1(), overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  '${blocks.length} sessions',
                  style: kTextSemiBold0(color: _blue).copyWith(fontSize: 11.sp),
                ),
              ),
            ],
          ),
          if (completedCount > 0) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: LinearProgressIndicator(
                      value: progressPct,
                      backgroundColor: _greyBorder,
                      valueColor: AlwaysStoppedAnimation(kSuccessColor),
                      minHeight: 5.h,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  '$completedCount/${blocks.length}',
                  style: kTextSemiBold0(color: _greyText).copyWith(fontSize: 11.sp),
                ),
              ],
            ),
          ],
          SizedBox(height: 14.h),
          ...preview.map(_schedTile),
          if (blocks.length > 3) ...[
            SizedBox(height: 6.h),
            InkWell(
              onTap: () => _openScheduleSheet(blocks),
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 11.h),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: _blue.withValues(alpha: 0.18)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.list_alt_rounded, size: 14.sp, color: _blue),
                    SizedBox(width: 7.w),
                    Flexible(
                      child: Text(
                        'View Full Schedule  (+${blocks.length - 3} more)',
                        style: kTextSemiBold(color: _blue).copyWith(fontSize: 13.sp),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Icon(Icons.chevron_right_rounded, size: 16.sp, color: _blue),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _schedTile(SubBlock b) {
    final rs = RequestStatus.fromString(b.status);
    final accentColor = rs.color;

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: _greyBorder),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4.w,
              height: 60.h,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(12.r), bottomLeft: Radius.circular(12.r)),
              ),
            ),
            SizedBox(width: 10.w),
            Container(
              width: 42.w,
              padding: EdgeInsets.symmetric(vertical: 6.h),
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                children: [
                  Text(
                    b.dayAbbr,
                    style: kTextBold().copyWith(fontSize: 9.sp, color: _blue),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    AppDateFormatter.dayNum(b.scheduledDate),
                    style: kTextBold(color: _blue).copyWith(fontSize: 15.sp),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_fmtDate(b.scheduledDate), style: kTextSemiBold().copyWith(fontSize: 12.sp)),
                  SizedBox(height: 3.h),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 11.sp, color: _greyText),
                      SizedBox(width: 3.w),
                      Flexible(
                        child: Text(
                          b.timeRange,
                          style: kTextNormal(color: _greyText).copyWith(fontSize: 11.sp),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: 12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    NumberUtils.formatCurrency(b.providerPayout),
                    style: kTextSemiBold(color: Colors.green.shade700).copyWith(fontSize: 12.sp),
                  ),
                  // SizedBox(height: 4.h),
                  // Container(
                  //   padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                  //   decoration: BoxDecoration(color: rs.bgColor, borderRadius: BorderRadius.circular(20.r)),
                  //   child: Text(
                  //     rs.label,
                  //     style: kTextSemiBold0(color: accentColor).copyWith(fontSize: 9.sp),
                  //   ),
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openScheduleSheet(List<SubBlock> blocks) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: FullScheduleSheet(blocks: blocks),
      ),
    );
  }

  // ─── stage-based availability section ───
  Widget _buildAvailabilitySection(ProviderServiceRequestModel r, int stage, List<SubBlock> blocks) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_turned_in_outlined, color: _blue, size: 18.sp),
              SizedBox(width: 8.w),
              Text('Booking Availability', style: kTextSemiBold1()),
              SizedBox(width: 8.w),
              Container(
                padding: AppPadding.symmetric(h: 8, v: 3),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  'Stage $stage',
                  style: kTextSemiBold(color: _blue).copyWith(fontSize: 11.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          if (stage == 1) _stage1Banner(),
          if (stage == 2) _stage2(blocks),
          if (stage == 3) _stage3(blocks),
        ],
      ),
    );
  }

  Widget _stage1Banner() {
    return Container(
      padding: AppPadding.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: _blue, size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Full Booking Commitment Required', style: kTextSemiBold(color: _navy)),
                SizedBox(height: 4.h),
                Text(
                  'This booking requires commitment to the complete schedule. Individual day or half-period selection is not available for this request.',
                  style: kTextNormal(color: const Color(0xFF1E40AF)).copyWith(fontSize: 12.sp, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stage2(List<SubBlock> blocks) {
    final mid = blocks.length ~/ 2;
    final first = blocks.sublist(0, mid);
    final second = blocks.sublist(mid);

    final firstPayout = _totalPayout(first);
    final secondPayout = _totalPayout(second);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select the period you are available for:',
          style: kTextNormal(color: _greyText).copyWith(fontSize: 12.sp),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(child: _halfCard('First Half', first, firstPayout, 1)),
            SizedBox(width: 10.w),
            Expanded(child: _halfCard('Second Half', second, secondPayout, 2)),
          ],
        ),
      ],
    );
  }

  Widget _halfCard(String title, List<SubBlock> blks, double payout, int halfNum) {
    final selected = _selectedHalf == halfNum;
    final startDate = blks.isNotEmpty ? blks.first.scheduledDate : null;
    final endDate = blks.isNotEmpty ? blks.last.scheduledDate : null;

    return GestureDetector(
      onTap: () => setState(() => _selectedHalf = selected ? 0 : halfNum),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: AppPadding.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: selected ? _blue : _greyBorder, width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: kTextSemiBold(color: selected ? _blue : Colors.black87)),
                ),
                if (selected) Icon(Icons.check_circle, color: _blue, size: 16.sp),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              '${blks.length} Days',
              style: kTextBold(color: selected ? _navy : _greyText).copyWith(fontSize: 13.sp),
            ),
            SizedBox(height: 4.h),
            Text(
              '${_fmtDate(startDate)} →',
              style: kTextNormal(color: _greyText).copyWith(fontSize: 10.sp),
            ),
            Text(
              _fmtDate(endDate),
              style: kTextNormal(color: _greyText).copyWith(fontSize: 10.sp),
            ),
            SizedBox(height: 8.h),
            Container(
              padding: AppPadding.symmetric(h: 8, v: 4),
              decoration: BoxDecoration(
                color: selected ? _blue.withValues(alpha: 0.1) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                NumberUtils.formatCurrency(payout),
                style: kTextBold(color: selected ? _blue : _greyText).copyWith(fontSize: 12.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stage3(List<SubBlock> blocks) {
    final selPayout = _totalPayout(blocks.where((b) => _selectedBlockIds.contains(b.id)).toList());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Select days you can work:',
                style: kTextNormal(color: _greyText).copyWith(fontSize: 12.sp),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                if (_selectedBlockIds.length == blocks.length) {
                  _selectedBlockIds.clear();
                } else {
                  _selectedBlockIds
                    ..clear()
                    ..addAll(blocks.map((b) => b.id));
                }
              }),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              child: Text(
                _selectedBlockIds.length == blocks.length ? 'Deselect All' : 'Select All',
                style: kTextSemiBold(color: _blue).copyWith(fontSize: 12.sp),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: blocks.map((b) {
            final id = b.id;
            final date = b.scheduledDate;
            final booked = b.isAssigned;
            final selected = _selectedBlockIds.contains(id);

            return GestureDetector(
              onTap: booked
                  ? null
                  : () => setState(() {
                      selected ? _selectedBlockIds.remove(id) : _selectedBlockIds.add(id);
                    }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 50.w,
                padding: EdgeInsets.symmetric(vertical: 8.h),
                decoration: BoxDecoration(
                  color: booked
                      ? Colors.grey.shade100
                      : selected
                      ? _blue
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: booked
                        ? Colors.grey.shade300
                        : selected
                        ? _blue
                        : _greyBorder,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      b.dayAbbr,
                      style: kTextBold().copyWith(
                        fontSize: 9.sp,
                        color: booked
                            ? Colors.grey
                            : selected
                            ? Colors.white
                            : _greyText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      AppDateFormatter.dayMonthNewline(date),
                      textAlign: TextAlign.center,
                      style: kTextSemiBold().copyWith(
                        fontSize: 11.sp,
                        height: 1.2,
                        color: booked
                            ? Colors.grey
                            : selected
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    if (booked) ...[
                      SizedBox(height: 2.h),
                      Icon(Icons.lock_outline, size: 9.sp, color: Colors.grey),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (_selectedBlockIds.isNotEmpty) ...[
          SizedBox(height: 12.h),
          Container(
            padding: AppPadding.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: _blue, size: 16.sp),
                SizedBox(width: 8.w),
                Text(
                  '${_selectedBlockIds.length} days selected',
                  style: kTextSemiBold(color: _navy).copyWith(fontSize: 13.sp),
                ),
                const Spacer(),
                Text(
                  NumberUtils.formatCurrency(selPayout),
                  style: kTextBold(color: Colors.green.shade700).copyWith(fontSize: 13.sp),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─── patient card ───
  Widget _buildPatientCard(ProviderServiceRequestModel r) {
    final fm = r.familyMember;
    final user = r.customerProfile?.user;
    final gender = fm?.gender ?? user?.gender;
    final dob = fm?.dateOfBirth ?? user?.dateOfBirth;
    final rs = RequestStatus.fromString(r.requestStatus);
    final inProg =
        rs != RequestStatus.cancelled &&
        (rs == RequestStatus.accepted ||
            rs == RequestStatus.partiallyAccepted ||
            rs == RequestStatus.inProgress ||
            r.bookings.any((b) => b.bookingStatus == 'in_progress' || b.bookingStatus == 'confirmed'));
    final showFullDetails = inProg && _isPrivacyUnlocked(r);

    final callPhone = AppConstants.partnerCustomerPhone;
    final hasPhone = callPhone.isNotEmpty;

    // Display name: family member name if present, else customer name
    final displayName = (fm?.fullName.isNotEmpty == true)
        ? fm!.fullName
        : (r.customerName.isNotEmpty ? r.customerName : 'Patient');

    // Gender + age subtitle
    final genderText = gender != null ? _cap(gender) : null;
    final ageText = dob != null ? _age(dob) : null;
    final subtitleParts = [?genderText, ?ageText];
    final subtitle = subtitleParts.isNotEmpty ? subtitleParts.join('  ·  ') : null;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(7.w),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.people_alt_rounded, color: _blue, size: 16.sp),
              ),
              SizedBox(width: 10.w),
              Expanded(child: Text('Patient Details', style: kTextSemiBold())),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Container(
                width: 50.h,
                height: 50.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_blue.withValues(alpha: 0.15), _blue.withValues(alpha: 0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: _blue.withValues(alpha: 0.3), width: 2),
                ),
                child: r.customerProfileImageUrl != null
                    ? ClipOval(child: AppCachedImage(imageUrl: r.customerProfileImageUrl, isOval: true))
                    : Center(
                        child: Text(
                          r.customerName.isNotEmpty ? r.customerName[0].toUpperCase() : '?',
                          style: kTextBold2(color: _blue),
                        ),
                      ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: kTextSemiBold1(), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (subtitle != null && showFullDetails) ...[
                      SizedBox(height: 3.h),
                      Text(
                        subtitle,
                        style: kTextNormal0(color: _greyText).copyWith(fontSize: 12.sp),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: 6.h),
                    // View Profile button
                    GestureDetector(
                      onTap: showFullDetails
                          ? () => _showCustomerDetailsBottomSheet(r)
                          : inProg
                          ? _showPrivacyLockedInfo
                          : null,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: showFullDetails ? _blue.withValues(alpha: 0.07) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: showFullDetails ? _blue.withValues(alpha: 0.2) : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          'View Profile',
                          style: kTextMedium(
                            color: showFullDetails ? _blue : Colors.grey.shade400,
                          ).copyWith(fontSize: 11.sp),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasPhone) ...[
                SizedBox(width: 8.w),
                GestureDetector(
                  onTap: showFullDetails
                      ? () => LaunchUrlService.makePhoneCall(callPhone)
                      : inProg
                      ? _showPrivacyLockedInfo
                      : null,
                  child: Container(
                    padding: EdgeInsets.all(9.w),
                    decoration: BoxDecoration(
                      color: showFullDetails ? _green.withValues(alpha: 0.10) : _greyBorder,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.call_rounded,
                      color: showFullDetails ? _green : Colors.grey.shade400,
                      size: 16.sp,
                    ),
                  ),
                ),
              ],
            ],
          ),
          // if (showRecords) ...[
          //   SizedBox(height: 12.h),
          //   GestureDetector(
          //     onTap: () => _showHealthRecordsBottomSheet(r),
          //     child: Container(
          //       width: double.infinity,
          //       padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
          //       decoration: BoxDecoration(
          //         color: _blue.withValues(alpha: 0.05),
          //         borderRadius: BorderRadius.circular(12.r),
          //         border: Border.all(color: _blue.withValues(alpha: 0.18)),
          //       ),
          //       child: Row(
          //         children: [
          //           Container(
          //             padding: EdgeInsets.all(7.w),
          //             decoration: BoxDecoration(color: _blue.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8.r)),
          //             child: Icon(Icons.medical_information_rounded, size: 15.sp, color: _blue),
          //           ),
          //           SizedBox(width: 10.w),
          //           Expanded(
          //             child: Column(
          //               crossAxisAlignment: CrossAxisAlignment.start,
          //               children: [
          //                 Text(
          //                   'View Health Records',
          //                   style: kTextSemiBold(color: _blue).copyWith(fontSize: 13.sp),
          //                 ),
          //                 Text(
          //                   'Medical history & reports',
          //                   style: kTextNormal0(color: _greyText).copyWith(fontSize: 11.sp),
          //                 ),
          //               ],
          //             ),
          //           ),
          //           Icon(Icons.arrow_forward_ios_rounded, size: 12.sp, color: _blue.withValues(alpha: 0.5)),
          //         ],
          //       ),
          //     ),
          //   ),
          // ],
        ],
      ),
    );
  }

  // ─── address card ───
  Widget _buildAddressCard(ProviderServiceRequestModel r) {
    final addr = r.customerAddress;
    final area = addr?.area ?? '';
    final city = addr?.city ?? r.city;
    final state = addr?.state ?? '';
    final pin = addr?.pinCode ?? '';
    final locality = [area, city, state].where((s) => s.isNotEmpty).join(', ') + (pin.isNotEmpty ? ' – $pin' : '');
    final isCancelled = RequestStatus.fromString(r.requestStatus) == RequestStatus.cancelled;
    final inProg =
        !isCancelled &&
        (r.requestStatus.toLowerCase() == 'accepted' ||
            r.requestStatus.toLowerCase() == 'partially_accepted' ||
            r.requestStatus.toLowerCase() == 'in_progress' ||
            r.bookings.any((b) => b.bookingStatus == 'in_progress' || b.bookingStatus == 'confirmed'));
    final canNavigate = inProg && _isPrivacyUnlocked(r);
    void onNavigate() async {
      if (!canNavigate) {
        if (inProg) _showPrivacyLockedInfo();
        return;
      }
      if (r.isEmergency == 1) {
        AppNavigator.to(AppRoutes.providerActiveService, arguments: _toServiceRequest(r));
        return;
      }
      if (r.serviceLatitude == 0 && r.serviceLongitude == 0) {
        MessageService.showWarning('Service location not available');
        return;
      }
      await LaunchUrlService.launchGoogleMaps(r.serviceLatitude, r.serviceLongitude);
    }

    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(7.w),
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(Icons.location_on_rounded, color: _blue, size: 16.sp),
                ),
                SizedBox(width: 10.w),
                Expanded(child: Text('Service Location', style: kTextSemiBold1())),
                if (r.distanceKm > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.near_me_rounded, size: 11.sp, color: _blue),
                        SizedBox(width: 3.w),
                        Text(
                          '${r.distanceKm.toStringAsFixed(1)} km away',
                          style: kTextSemiBold0(color: _blue).copyWith(fontSize: 11.sp),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          // ── Address row ──
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: GestureDetector(
              onTap: onNavigate,
              child: Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: _blue.withValues(alpha: 0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(Icons.home_rounded, color: _blue, size: 17.sp),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            canNavigate ? r.address : locality,
                            style: kTextSemiBold().copyWith(fontSize: 13.sp, height: 1.4),
                          ),
                          // if (!isCancelled && locality.isNotEmpty) ...[
                          //   SizedBox(height: 3.h),
                          //   Text(
                          //     locality,
                          //     style: kTextNormal(color: _greyText).copyWith(fontSize: 12.sp),
                          //   ),
                          // ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          // ── Navigate CTA ──
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
            child: GestureDetector(
              onTap: onNavigate,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 13.h),
                decoration: BoxDecoration(
                  gradient: canNavigate
                      ? const LinearGradient(
                          colors: [Color(0xFF2D62ED), Color(0xFF123B61)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  color: canNavigate ? null : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: canNavigate
                      ? [
                          BoxShadow(
                            color: _blue.withValues(alpha: 0.30),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.navigation_rounded,
                      size: 18.sp,
                      color: canNavigate ? Colors.white : Colors.grey.shade500,
                    ),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: Text(
                        'Navigate to Location',
                        style: kTextSemiBold(color: canNavigate ? Colors.white : Colors.grey.shade500),
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
    );
  }

  // ─── instructions card ───
  Widget _buildInstructionsCard(ProviderServiceRequestModel r) {
    return Container(
      padding: AppPadding.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700, size: 18.sp),
              SizedBox(width: 8.w),
              Text('Important Instructions', style: kTextSemiBold1(color: Colors.amber.shade800)),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            width: double.infinity,
            padding: AppPadding.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Text(
              r.specialInstructions ?? '',
              style: kTextNormal(color: const Color(0xFF92400E)).copyWith(fontSize: 13.sp, height: 1.5),
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Icon(Icons.person_search_outlined, size: 13.sp, color: Colors.amber.shade700),
              SizedBox(width: 5.w),
              Text(
                'Gender Preference: ${_genderLabel(r.genderPreference)}',
                style: kTextMedium(color: Colors.amber.shade800).copyWith(fontSize: 12.sp),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── status chip ───
  Widget _statusChip(String status) {
    final rs = RequestStatus.fromString(status);
    final isStandbyAndNotProviderStandby =
        rs == RequestStatus.standby && !locator<LocalStorageService>().providerIsStandby;

    final bgColor = isStandbyAndNotProviderStandby ? const Color(0xFFFEF2F2) : rs.bgColor;
    final color = isStandbyAndNotProviderStandby ? const Color(0xFFDC2626) : rs.color;
    final label = isStandbyAndNotProviderStandby ? 'Expired' : rs.label;

    return Container(
      padding: AppPadding.symmetric(h: 10, v: 5),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20.r)),
      child: Text(
        label,
        style: kTextSemiBold(color: color).copyWith(fontSize: 11.sp),
      ),
    );
  }

  // ─── dialogs / sheets ───
  void _showCustomerDetailsBottomSheet(ProviderServiceRequestModel r) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomerDetailsSheet(request: r),
    );
  }

  // void _showHealthRecordsBottomSheet(ProviderServiceRequestModel r) {
  //   showModalBottomSheet(
  //     context: context,
  //     useSafeArea: true,
  //     isScrollControlled: true,
  //     backgroundColor: Colors.transparent,
  //     builder: (_) => HealthRecordsSheet(customerProfileId: r.customerProfileId, familyMemberId: r.familyMemberId),
  //   );
  // }

  void _showStartBookingPopup(ProviderServiceRequestModel r) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dCtx) => StartBookingPopup(
        request: r,
        onStart: (navigate) async {
          final position = await LocationService().getLocationPosition();
          if (position == null) {
            MessageService.showWarning('Location permission is required to start the booking.');
            return;
          }
          if (!mounted) return;
          context.read<ProviderRequestDetailBloc>().add(
            StartServiceRequest(
              requestId: r.id,
              checkinLatitude: position.latitude,
              checkinLongitude: position.longitude,
            ),
          );
          if (navigate) {
            if (r.isEmergency == 1) {
              AppNavigator.to(AppRoutes.providerActiveService, arguments: _toServiceRequest(r));
            } else {
              await LaunchUrlService.launchGoogleMaps(r.serviceLatitude, r.serviceLongitude);
            }
          }
        },
      ),
    );
  }

  void _showStartBookingSheet(ProviderServiceRequestModel r, SubBlock block) {
    final phone = r.customerPhone ?? '';
    if (phone.isEmpty) {
      MessageService.showError('Patient phone number not available.');
      return;
    }
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StartBookingSheet(
        request: r,
        block: block,
        mobileNumber: phone,
        onSuccess: () => context.read<ProviderRequestDetailBloc>().add(RefreshProviderRequestDetail()),
      ),
    );
  }

  void _showCompleteSessionDialog(ProviderServiceRequestModel r, SubBlock block) {
    CompleteSessionDialog.show(
      context,
      request: r,
      block: block,
      onSuccess: () => context.read<ProviderRequestDetailBloc>().add(RefreshProviderRequestDetail()),
    );
  }

  void _showCompleteConfirmDialog(ProviderServiceRequestModel r) {
    CompleteConfirmDialog.show(context, r);
  }

  // ━━━━━━━━━━━━━━━━━━ NEW PREMIUM REQUEST UI ━━━━━━━━━━━━━━━━━━━━━

  void _initCountdown(ProviderServiceRequestModel r) {
    if (_countdownStarted) return;
    _countdownStarted = true;

    final waitingStartedAt = r.waitingStartedAt;
    final waitingWindowMins = r.waitingWindowMinutes;
    if (waitingStartedAt == null) return;
    try {
      final started = AppDateFormatter.dateFromString(waitingStartedAt);
      final timeout = started.add(Duration(minutes: waitingWindowMins));
      final remaining = timeout.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) return;
      setState(() => _newRequestSecsLeft = remaining);
      _newRequestCountdown = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          _newRequestSecsLeft--;
          if (_newRequestSecsLeft <= 0) t.cancel();
        });
      });
    } catch (_) {}
  }

  Widget _buildAssignedSessionsCard(List<SubBlock> assignedBlocks, List<BookingModel> bookings) {
    final providerName = bookings.isNotEmpty ? (bookings.first.providerName ?? '') : '';

    final firstDate = assignedBlocks.isNotEmpty
        ? AppDateFormatter.dayMonthShort(assignedBlocks.first.scheduledDate)
        : '—';
    final lastDate = assignedBlocks.isNotEmpty
        ? AppDateFormatter.dayMonthShort(assignedBlocks.last.scheduledDate)
        : '—';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(7.w),
                decoration: BoxDecoration(color: kSuccessColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(Icons.check_circle_rounded, color: kSuccessColor, size: 16.sp),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Assigned Sessions', style: kTextSemiBold1()),
                    Text(
                      '${assignedBlocks.length} sessions confirmed',
                      style: kTextNormal0(color: kSuccessColor).copyWith(fontSize: 11.sp),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: kSuccessColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  'Confirmed',
                  style: kTextSemiBold0(color: kSuccessColor).copyWith(fontSize: 10.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          // Date range
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: kSuccessColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: kSuccessColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.date_range_rounded, size: 14.sp, color: kSuccessColor),
                SizedBox(width: 8.w),
                Text('$firstDate → $lastDate', style: kTextSemiBold0(color: kSuccessColor)),
                const Spacer(),
                Text(
                  '${assignedBlocks.length} sessions',
                  style: kTextNormal0(color: kSuccessColor).copyWith(fontSize: 11.sp),
                ),
              ],
            ),
          ),
          if (providerName.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(Icons.person_rounded, size: 14.sp, color: Colors.grey.shade500),
                SizedBox(width: 6.w),
                Text('Provider: ', style: kTextNormal0(color: _greyText)),
                Expanded(
                  child: Text(
                    providerName,
                    style: kTextSemiBold0(color: kTextPrimaryColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNewRequestScaffold(ProviderServiceRequestModel r) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCountdown(r));
    final blocks = _blocks(r);
    final stage = _stage(r);
    final hasCoords = r.serviceLatitude != 0 && r.serviceLongitude != 0;

    return Scaffold(
      backgroundColor: _greyBg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── MAP HEADER ──
              SliverAppBar(
                expandedHeight: 260.h,
                floating: false,
                pinned: false,
                snap: false,
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(background: _buildMapHeader(r, hasCoords)),
              ),
              // ── CONTENT ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 120.h),
                  child: Column(
                    children: [
                      _buildNewRequestPriorityCard(r, stage),
                      SizedBox(height: 14.h),
                      _buildNewCustomerPatientCard(r),
                      SizedBox(height: 14.h),
                      _buildNewServiceDetailsCard(r),
                      SizedBox(height: 14.h),
                      _buildNewEarningsCard(r, blocks),
                      SizedBox(height: 14.h),
                      _buildNewLocationCard(r),
                      if ((r.specialInstructions ?? '').isNotEmpty) ...[
                        SizedBox(height: 14.h),
                        _buildInstructionsCard(r),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Floating back + request number bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8.h,
            left: 12.w,
            right: 12.w,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    final nav = Navigator.of(context);
                    if (!nav.canPop()) return;
                    // Defer to dodge `!_debugLocked` if a navigation/overlay
                    // transaction is still settling from the incoming-alert flow.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) nav.maybePop();
                    });
                  },
                  child: Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
                    ),
                    child: Icon(Icons.arrow_back, size: 20.sp, color: _navy),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                    ),
                    child: Text(
                      r.requestNumber,
                      style: kTextMedium0(color: _greyText),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Sticky action bar
          Positioned(left: 0, right: 0, bottom: 0, child: _buildNewStickyActionBar(r, blocks, stage)),
        ],
      ),
    );
  }

  Widget _buildMapHeader(ProviderServiceRequestModel r, bool hasCoords) {
    return Stack(
      children: [
        if (hasCoords)
          GoogleMap(
            initialCameraPosition: CameraPosition(target: LatLng(r.serviceLatitude, r.serviceLongitude), zoom: 15),
            onMapCreated: (ctrl) => _mapController = ctrl,
            markers: {
              Marker(
                markerId: const MarkerId('patient'),
                position: LatLng(r.serviceLatitude, r.serviceLongitude),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(title: r.customerName.isNotEmpty ? r.customerName : 'Patient Location'),
              ),
            },
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            tiltGesturesEnabled: false,
            rotateGesturesEnabled: false,
          )
        else
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2F4E), Color(0xFF123B61), Color(0xFF1A4E87)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_city, size: 48.sp, color: Colors.white.withValues(alpha: 0.5)),
                  SizedBox(height: 8.h),
                  Text(r.city.isNotEmpty ? r.city : 'Location', style: kTextBold2(color: Colors.white)),
                ],
              ),
            ),
          ),
        // Gradient fade to background
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 80.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [_greyBg, _greyBg.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
        // Distance chip
        if (r.distanceKm > 0)
          Positioned(
            bottom: 28.h,
            right: 16.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.navigation_rounded, size: 14.sp, color: _blue),
                  SizedBox(width: 5.w),
                  Text(
                    '${r.distanceKm.toStringAsFixed(2)} km away',
                    style: kTextSemiBold(color: _navy).copyWith(fontSize: 12.sp),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Priority card ────────────────────────────────────────────────────────

  Widget _buildNewRequestPriorityCard(ProviderServiceRequestModel r, int stage) {
    final blocks = _blocks(r);
    final eff = _effectivePayout(r, blocks);
    final totalPayout = eff.total;
    final perDay = eff.perShift;
    final stageColors = _stageColors(stage);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryColor, const Color(0xFF1A5EA8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(color: kPrimaryColor.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circle
          Positioned(
            right: -20.w,
            top: -20.h,
            child: Container(
              width: 100.w,
              height: 100.w,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(18.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: NEW REQUEST badge + timer
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6.w,
                            height: 6.w,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4ADE80)),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'NEW REQUEST',
                            style: kTextBold0(color: Colors.white).copyWith(letterSpacing: 0.8, fontSize: 10.sp),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                SizedBox(height: 14.h),
                // Service name
                Text(
                  r.serviceCategoryName,
                  style: kTextBold2(color: Colors.white).copyWith(fontSize: 20.sp),
                ),
                SizedBox(height: 6.h),
                // Chips row
                Wrap(
                  spacing: 8.w,
                  runSpacing: 6.h,
                  children: [
                    _whiteChip(r.serviceTypeText.replaceAll('_', ' ')),
                    if (r.shiftType != null)
                      _whiteChip(
                        r.shiftType == 'night'
                            ? '🌙 Night Shift'
                            : r.shiftType == '24_hours'
                            ? '🕒 Full Day'
                            : '☀️ Day Shift',
                      ),
                    _whiteChip('${r.durationDays ?? blocks.length} Days'),
                  ],
                ),
                SizedBox(height: 16.h),
                Divider(color: Colors.white.withValues(alpha: 0.18)),
                SizedBox(height: 14.h),
                // Earnings row
                Row(
                  children: [
                    Expanded(child: _payoutStat('Your Payout', '₹${totalPayout.toInt()}', Colors.white)),
                    Container(width: 1, height: 36.h, color: Colors.white.withValues(alpha: 0.2)),
                    Expanded(child: _payoutStat('Per Day', '₹${perDay.toInt()}', const Color(0xFF86EFAC))),
                    if ((r.durationDays ?? blocks.length) > 1) ...[
                      Container(width: 1, height: 36.h, color: Colors.white.withValues(alpha: 0.2)),
                      Expanded(child: _stageBadge(stage, stageColors)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _whiteChip(String label) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20.r),
      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
    ),
    child: Text(
      label,
      style: kTextMedium(color: Colors.white).copyWith(fontSize: 11.sp),
    ),
  );

  Widget _payoutStat(String label, String value, Color valueColor) => Column(
    children: [
      Text(
        value,
        style: kTextBold1(color: valueColor).copyWith(fontSize: 15.sp),
        textAlign: TextAlign.center,
      ),
      SizedBox(height: 2.h),
      Text(
        label,
        style: kTextNormal0(color: Colors.white60).copyWith(fontSize: 10.sp),
        textAlign: TextAlign.center,
      ),
    ],
  );

  Widget _stageBadge(int stage, Map<String, Color> colors) {
    final labels = {1: 'Full\nBooking', 2: 'Split\nBooking', 3: 'Flexible\nDates', 4: 'Last\nSlots'};
    return Column(
      children: [
        Text(
          labels[stage] ?? 'Stage $stage',
          style: kTextBold0(color: colors['fg']!).copyWith(fontSize: 11.sp),
          textAlign: TextAlign.center,
        ),
        // SizedBox(height: 2.h),
        // Text('Stage $stage',
        //     style: kTextNormal0(color: Colors.white60).copyWith(fontSize: 10.sp),
        //     textAlign: TextAlign.center),
      ],
    );
  }

  Map<String, Color> _stageColors(int stage) {
    switch (stage) {
      case 1:
        return {'fg': const Color(0xFF86EFAC), 'bg': const Color(0xFF16A34A)};
      case 2:
        return {'fg': const Color(0xFF93C5FD), 'bg': const Color(0xFF1D4ED8)};
      case 3:
        return {'fg': const Color(0xFFC4B5FD), 'bg': const Color(0xFF7C3AED)};
      case 4:
        return {'fg': const Color(0xFFFDBA74), 'bg': kAccentColor};
      default:
        return {'fg': Colors.white, 'bg': kPrimaryColor};
    }
  }

  // ── Customer + Patient card ──────────────────────────────────────────────

  Widget _buildNewCustomerPatientCard(ProviderServiceRequestModel r) {
    if (!_isPrivacyUnlocked(r)) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
        ),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people_rounded, color: _blue, size: 18.sp),
                SizedBox(width: 8.w),
                Text('Patient Detail', style: kTextSemiBold1()),
              ],
            ),
            SizedBox(height: 14.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                children: [
                  Icon(Icons.lock_rounded, size: 28.sp, color: const Color(0xFF94A3B8)),
                  SizedBox(height: 8.h),
                  Text('Patient Details Locked', style: kTextSemiBold(color: const Color(0xFF475569))),
                  SizedBox(height: 6.h),
                  Text(
                    'Patient information will be available 3 hours before the session start time.',
                    style: kTextNormal0(color: const Color(0xFF94A3B8)).copyWith(fontSize: 12.sp, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final fm = r.familyMember;
    final user = r.customerProfile?.user;

    final customerName = r.customerName;
    final customerImageUrl = r.customerProfileImageUrl;
    final patientName = fm?.fullName;
    final relationship = fm?.relationship;
    final gender = fm?.gender ?? user?.gender;
    final dob = fm?.dateOfBirth ?? user?.dateOfBirth;
    final bloodGroup = fm?.bloodGroup ?? user?.bloodGroup;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_rounded, color: _blue, size: 18.sp),
              SizedBox(width: 8.w),
              Text('Patient Detail', style: kTextSemiBold1()),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              // Avatar
              Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _blue.withValues(alpha: 0.3), width: 2),
                  color: _blue.withValues(alpha: 0.08),
                ),
                child: customerImageUrl != null
                    ? ClipOval(child: AppCachedImage(imageUrl: customerImageUrl, isOval: true))
                    : Center(
                        child: Text(
                          customerName.isNotEmpty ? customerName[0].toUpperCase() : '?',
                          style: kTextBold2(color: _blue),
                        ),
                      ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customerName.isNotEmpty ? customerName : 'Patient', style: kTextSemiBold2()),
                    if (patientName != null) ...[
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          Icon(Icons.person_pin_outlined, size: 13.sp, color: _greyText),
                          SizedBox(width: 4.w),
                          Text(
                            'Patient: $patientName${relationship != null ? ' (${_cap(relationship)})' : ''}',
                            style: kTextNormal(color: _greyText).copyWith(fontSize: 12.sp),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (gender != null || dob != null || bloodGroup != null) ...[
            SizedBox(height: 14.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(color: _greyBg, borderRadius: BorderRadius.circular(12.r)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (gender != null)
                    _patientStat(
                      gender.toLowerCase() == 'male' ? Icons.man_rounded : Icons.woman_rounded,
                      _cap(gender),
                      const Color(0xFF7E22CE),
                    ),
                  if (dob != null) _patientStat(Icons.calendar_month_rounded, _age(dob), const Color(0xFFB45309)),
                  if (bloodGroup != null) _patientStat(Icons.bloodtype_rounded, bloodGroup, kErrorColor),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _patientStat(IconData icon, String value, Color color) => Column(
    children: [
      Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, size: 16.sp, color: color),
      ),
      SizedBox(height: 4.h),
      Text(
        value,
        style: kTextSemiBold(color: color).copyWith(fontSize: 12.sp),
      ),
    ],
  );

  // ── Service details card ─────────────────────────────────────────────────

  Widget _buildNewServiceDetailsCard(ProviderServiceRequestModel r) {
    final serviceName = r.serviceCategoryName;
    final serviceImageUrl = r.categoryIconUrl;
    final startDate = r.startDate;
    final endDate = r.endDate;
    final startTime = r.startTime;
    final endTime = r.endTime;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: kPrimaryColor.withValues(alpha: 0.15)),
                ),
                child: serviceImageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: AppCachedImage(imageUrl: serviceImageUrl),
                      )
                    : Icon(Icons.medical_services_outlined, color: kPrimaryColor, size: 22.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(serviceName, style: kTextSemiBold2()),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        _miniChip(Icons.home_outlined, r.serviceModeText, const Color(0xFF1D4ED8)),
                        SizedBox(width: 6.w),
                        if (r.shiftType != null)
                          _miniChip(
                            r.shiftType == 'night' ? Icons.nightlight_outlined : Icons.wb_sunny_outlined,
                            '${r.formattedShiftType} Shift',
                            r.shiftType == 'night' ? const Color(0xFF6D28D9) : const Color(0xFFB45309),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          // Date + time row
          Row(
            children: [
              Expanded(child: _dateTimeBox('Start', _fmtDate(startDate), _fmtTime(startTime), kSuccessColor)),
              SizedBox(width: 10.w),
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(color: _greyBg, shape: BoxShape.circle),
                child: Icon(Icons.arrow_forward_rounded, size: 16.sp, color: _greyText),
              ),
              SizedBox(width: 10.w),
              Expanded(child: _dateTimeBox('End', _fmtDate(endDate), _fmtTime(endTime), kErrorColor)),
            ],
          ),
          SizedBox(height: 10.h),
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: kPrimaryColor.withValues(alpha: 0.2)),
              ),
              child: Text(
                '${r.durationDays ?? _blocks(r).length} Days Total',
                style: kTextSemiBold(color: kPrimaryColor).copyWith(fontSize: 13.sp),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(IconData icon, String label, Color color) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20.r)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10.sp, color: color),
        SizedBox(width: 4.w),
        Text(
          label,
          style: kTextNormal0(color: color).copyWith(fontSize: 10.sp),
        ),
      ],
    ),
  );

  Widget _dateTimeBox(String label, String date, String time, Color color) => Container(
    padding: EdgeInsets.all(12.w),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: kTextNormal0(color: color).copyWith(fontSize: 9.sp, letterSpacing: 0.8),
        ),
        SizedBox(height: 4.h),
        Text(date, style: kTextSemiBold().copyWith(fontSize: 13.sp)),
        Text(time, style: kTextNormal0(color: _greyText)),
      ],
    ),
  );

  // ── Premium earnings card ────────────────────────────────────────────────

  Widget _buildNewEarningsCard(ProviderServiceRequestModel r, List<SubBlock> blocks) {
    final eff = _effectivePayout(r, blocks);
    final totalPayout = eff.total;
    final perDay = eff.perShift;
    // final paidAmount = r.paidAmount ?? 0;
    // final remainingAmount = r.remainingAmount ?? 0;
    // final paymentStatus = r.paymentStatus;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0FFF4), Color(0xFFFCFFF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFBBF7D0)),
        boxShadow: [
          BoxShadow(color: kSuccessColor.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(color: kSuccessColor, borderRadius: BorderRadius.circular(10.r)),
                child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18.sp),
              ),
              SizedBox(width: 10.w),
              Text('Your Earnings', style: kTextSemiBold1(color: const Color(0xFF15803D))),
            ],
          ),
          SizedBox(height: 20.h),
          // Hero payout number
          Center(
            child: Column(
              children: [
                Text(
                  NumberUtils.formatCurrency(totalPayout),
                  style: kTextBold3(color: const Color(0xFF15803D)).copyWith(fontSize: 36.sp),
                ),
                Text(
                  'Total Partner Payout',
                  style: kTextNormal(color: const Color(0xFF16A34A)).copyWith(fontSize: 12.sp),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          // Per-day row
          Row(
            children: [
              _earningsStatBox(NumberUtils.formatCurrency(perDay), 'Per Shift', const Color(0xFF16A34A)),
              SizedBox(width: 10.w),
              _earningsStatBox('${blocks.length}', 'Shifts', kPrimaryColor),
              // SizedBox(width: 10.w),
              // _earningsStatBox(NumberUtils.formatCurrency(perDay * 30), 'Est. Monthly', const Color(0xFF0891B2)),
            ],
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  Widget _earningsStatBox(String value, String label, Color color) => Expanded(
    child: Container(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(value, style: kTextBold1(color: color)),
          SizedBox(height: 2.h),
          Text(
            label,
            style: kTextNormal0(color: color).copyWith(fontSize: 10.sp),
          ),
        ],
      ),
    ),
  );

  // ── Location card ────────────────────────────────────────────────────────

  Widget _buildNewLocationCard(ProviderServiceRequestModel r) {
    final area = r.customerAddress?.area ?? '';
    final city = r.customerAddress?.city ?? r.city;

    if (!_isPrivacyUnlocked(r)) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
        ),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_rounded, color: kErrorColor, size: 18.sp),
                SizedBox(width: 8.w),
                Text('Service Location', style: kTextSemiBold1()),
                if (r.distanceKm > 0) ...[
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.near_me_rounded, size: 11.sp, color: _blue),
                        SizedBox(width: 3.w),
                        Text(
                          '${r.distanceKm.toStringAsFixed(1)} km',
                          style: kTextSemiBold0(color: _blue).copyWith(fontSize: 11.sp),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 14.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                children: [
                  Icon(Icons.location_off_rounded, size: 28.sp, color: const Color(0xFF94A3B8)),
                  SizedBox(height: 8.h),
                  Text('Location Available Soon', style: kTextSemiBold(color: const Color(0xFF475569))),
                  SizedBox(height: 6.h),
                  Text(
                    'Exact service location will be available 3 hours before the session start time.',
                    style: kTextNormal0(color: const Color(0xFF94A3B8)).copyWith(fontSize: 12.sp, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  if (city.isNotEmpty) ...[
                    SizedBox(height: 10.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_city_rounded, size: 13.sp, color: const Color(0xFF64748B)),
                        SizedBox(width: 4.w),
                        Text(
                          city,
                          style: kTextMedium(color: const Color(0xFF64748B)).copyWith(fontSize: 12.sp),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_rounded, color: kErrorColor, size: 18.sp),
              SizedBox(width: 8.w),
              Text('Service Location', style: kTextSemiBold1()),
            ],
          ),
          SizedBox(height: 12.h),
          // Address block
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                Icon(Icons.home_outlined, color: kErrorColor, size: 20.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.address, style: kTextSemiBold().copyWith(fontSize: 13.sp, height: 1.4)),
                      if (area.isNotEmpty || city.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Text(
                          [area, city].where((s) => s.isNotEmpty).join(', '),
                          style: kTextNormal0(color: _greyText),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async =>
                  await LaunchUrlService.launchGoogleMaps(r.serviceLatitude, r.serviceLongitude),
              icon: Icon(Icons.navigation_rounded, size: 14.sp, color: Colors.white),
              label: Text(
                'Navigate',
                style: kTextSemiBold(color: Colors.white).copyWith(fontSize: 12.sp),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 10.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sticky action bar ────────────────────────────────────────────────────

  Widget _buildNewStickyActionBar(ProviderServiceRequestModel r, List<SubBlock> blocks, int stageRaw) {
    final availableCount = blocks.where((b) => !b.isAssigned).length;
    final stage = (stageRaw == 2 || stageRaw == 3) && availableCount <= 1 ? 1 : stageRaw;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
          child: Row(
            children: [
              // Decline
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 52.h,
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      context.read<ProviderRequestDetailBloc>().add(RejectProviderRequest(requestId: r.id));
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kErrorColor,
                      side: BorderSide(color: kErrorColor, width: 1.5),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close_rounded, size: 16.sp),
                        SizedBox(width: 4.w),
                        Text('Decline', style: kTextSemiBold0(color: kErrorColor)),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              // View Schedule (shown for stages 2/3/4 or all)
              if (stage > 1 || blocks.length > 1) ...[
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: 52.h,
                    child: OutlinedButton(
                      onPressed: () => _showAcceptSheet(context, r),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimaryColor,
                        side: BorderSide(color: kPrimaryColor, width: 1.5),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_view_month_rounded, size: 16.sp),
                          SizedBox(width: 4.w),
                          Text('Schedule', style: kTextSemiBold0(color: kPrimaryColor)),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
              ],
              // Accept
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 52.h,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      _showAcceptSheet(context, r);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSuccessColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                      elevation: 3,
                      shadowColor: kSuccessColor.withValues(alpha: 0.4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 18.sp, color: Colors.white),
                        SizedBox(width: 6.w),
                        Text(
                          'Accept',
                          style: kTextSemiBold1(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
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

// ━━━━━━━━━━━━━━━━━━ SHARED CARD WIDGET ━━━━━━━━━━━━━━━━━━

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _Card({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? AppPadding.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: child,
    );
  }
}
