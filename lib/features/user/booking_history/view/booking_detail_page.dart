import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/api/redirection_url.dart';
import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/services/app_clock.dart';
import 'package:adhisaat_health_care/core/services/launch_url_service.dart';
import 'package:adhisaat_health_care/core/storage/local_storage_service.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/user/booking_history/bloc/booking_detail_bloc.dart';
import 'package:adhisaat_health_care/features/user/booking_history/helper/booking_action_resolver.dart';
import 'package:adhisaat_health_care/features/user/booking_history/helper/booking_status_mapper.dart';
import 'package:adhisaat_health_care/features/user/booking_history/helper/payment_status_mapper.dart';
import 'package:adhisaat_health_care/features/user/booking_history/helper/request_status_helper.dart';
import 'package:adhisaat_health_care/features/user/booking_history/helper/sub_block_status_mapper.dart';
import 'package:adhisaat_health_care/features/user/booking_history/model/booking_detail_model.dart';
import 'package:adhisaat_health_care/features/user/family/model/family_member_model.dart';
import 'package:adhisaat_health_care/features/user/booking_history/widget/feedback_bottom_sheet.dart';
import 'package:adhisaat_health_care/features/user/booking_history/widget/payment_breakdown_sheet.dart';
import 'package:adhisaat_health_care/features/user/booking_history/widget/session_schedule_sheet.dart';
import 'package:adhisaat_health_care/features/user/booking_history/widget/sub_block_detail_sheet.dart';
import 'package:adhisaat_health_care/features/user/payment/data/payment_repository.dart';
import 'package:adhisaat_health_care/features/user/payment/view/booking_payment_page.dart';
import 'package:adhisaat_health_care/features/user/booking_history/helper/reschedule_helper.dart';
import 'package:adhisaat_health_care/features/user/service_booking/data/service_request_repository.dart';
import 'package:adhisaat_health_care/features/user/service_booking/view/widgets/service_description_sheet.dart';
import 'package:adhisaat_health_care/shared/widgets/buttons/custom_button.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_cached_image.dart';
import 'package:adhisaat_health_care/shared/widgets/common/custom_error_view.dart';
import 'package:adhisaat_health_care/shared/widgets/common/custom_refresh_indicator.dart';
import 'package:adhisaat_health_care/shared/widgets/dialogs/custom_dialogs.dart';
import 'package:adhisaat_health_care/shared/widgets/dialogs/dialog_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry Point
// ─────────────────────────────────────────────────────────────────────────────

class BookingDetailPage extends StatelessWidget {
  final int requestId;

  /// When set (e.g. from a "booking start reminder" notification), the matching
  /// session/sub-block detail sheet is auto-opened once the booking loads.
  final int? initialSubBlockId;

  const BookingDetailPage({super.key, required this.requestId, this.initialSubBlockId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          BookingDetailBloc(locator<ServiceRequestRepository>(), locator<PaymentRepository>())
            ..add(LoadBookingDetail(requestId)),
      child: _BookingDetailScaffold(initialSubBlockId: initialSubBlockId),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Root Scaffold
// ─────────────────────────────────────────────────────────────────────────────

class _BookingDetailScaffold extends StatefulWidget {
  final int? initialSubBlockId;

  const _BookingDetailScaffold({this.initialSubBlockId});

  @override
  State<_BookingDetailScaffold> createState() => _BookingDetailScaffoldState();
}

class _BookingDetailScaffoldState extends State<_BookingDetailScaffold> {
  bool _subBlockSheetOpened = false;

  void _maybeOpenSubBlockSheet(BookingDetailModel model) {
    if (_subBlockSheetOpened || widget.initialSubBlockId == null) return;
    _subBlockSheetOpened = true;
    final sr = model.serviceRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SubBlockDetailSheet.show(
        context,
        subBlockId: widget.initialSubBlockId!,
        serviceRequestId: sr.id,
        requestNumber: sr.requestNumber,
        serviceName: sr.service?.name ?? sr.serviceTypeText,
        hideProviderIfEmergency: sr.isEmergency,
        hideCancelIfEmergency: sr.isEmergency,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: BlocConsumer<BookingDetailBloc, BookingDetailState>(
        listener: (context, state) {
          if (state is BookingDetailLoaded) {
            _maybeOpenSubBlockSheet(state.model);
          }
          if (state is BookingDetailCancelled) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => SuccessDialog(
                title: 'Booking Cancelled',
                message: 'Your booking has been successfully cancelled.',
                buttonText: 'Done',
                onConfirm: () {
                  Navigator.pop(context); // pop SuccessDialog
                  Navigator.pop(context, true); // pop BookingDetailPage
                },
              ),
            );
          } else if (state is BookingDetailSubBlocksCancelled) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => SuccessDialog(
                title: 'Session Cancelled',
                message: 'Your session has been successfully cancelled.',
                buttonText: 'Done',
                onConfirm: () => Navigator.pop(context), // pop SuccessDialog
              ),
            );
          }
        },
        builder: (context, state) {
          final BookingDetailModel? model = switch (state) {
            BookingDetailLoaded() => state.model,
            BookingDetailRefreshing() => state.model,
            BookingDetailCancelling() => state.model,
            _ => null,
          };

          // Derive resolved state for action bar
          BookingStatus? status;
          BookingType? type;
          PaymentStatus? payStatus;

          if (model != null) {
            final sr = model.serviceRequest;
            status = BookingStatusMapper.fromString(sr.requestStatus);
            type = BookingStatusMapper.typeFromString(sr.serviceType);
            payStatus = PaymentStatusMapper.fromString(sr.paymentStatus);
          }

          return Scaffold(
            backgroundColor: const Color(0xFFF1F4F9),
            appBar: _BookingAppBar(isRefreshing: state is BookingDetailRefreshing),
            body: _buildBody(context, state, model, status, type, payStatus),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    BookingDetailState state,
    BookingDetailModel? model,
    BookingStatus? status,
    BookingType? type,
    PaymentStatus? payStatus,
  ) {
    if (state is BookingDetailLoading) {
      return const _LoadingSkeleton();
    }

    if (state is BookingDetailError) {
      return CustomErrorView(
        message: state.message,
        onRetry: () => context.read<BookingDetailBloc>().add(RefreshBookingDetail()),
      );
    }

    if (model == null) return const SizedBox.shrink();

    final canPayNow =
        status != null &&
        type != null &&
        payStatus != null &&
        BookingActionResolver.showPayNow(type: type, status: status, paymentStatus: payStatus);
    final canCancel =
        status != null && BookingActionResolver.showCancel(status, type: type, paymentStatus: payStatus);

    final showInlineCancel = canCancel && !canPayNow;
    final showStickyBar = canPayNow;

    final scrollBody = _BookingScrollBody(
      model: model,
      showInlineCancel: showInlineCancel,
      cancelPayStatus: payStatus,
      hasStickyBar: showStickyBar,
    );

    final content = (showStickyBar)
        ? Column(
            children: [
              Expanded(child: scrollBody),
              _BottomActionBar(sr: model.serviceRequest, status: status, type: type, payStatus: payStatus),
            ],
          )
        : scrollBody;

    // Overlay spinner while cancel in flight — covers action bar too
    if (state is BookingDetailCancelling) {
      return Stack(
        children: [
          content,
          Container(
            color: Colors.black.withValues(alpha: 0.35),
            child: const Center(child: CircularProgressIndicator(color: kWhiteColor)),
          ),
        ],
      );
    }

    return content;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App Bar
// ─────────────────────────────────────────────────────────────────────────────

class _BookingAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isRefreshing;

  const _BookingAppBar({required this.isRefreshing});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: kWhiteColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      shadowColor: kBorderColor,
      automaticallyImplyLeading: false,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: EdgeInsets.all(10.w),
          decoration: BoxDecoration(color: const Color(0xFFF1F4F9), borderRadius: BorderRadius.circular(10.r)),
          child: Icon(Icons.arrow_back_ios_new_rounded, size: 16.sp, color: kTextPrimaryColor),
        ),
      ),
      title: Text('Booking Detail', style: kTextBold1(color: kTextPrimaryColor)),
      bottom: isRefreshing
          ? PreferredSize(
              preferredSize: const Size.fromHeight(2),
              child: LinearProgressIndicator(minHeight: 2, color: kSecondaryColor, backgroundColor: kBorderColor),
            )
          : null,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (isRefreshing ? 2 : 0));
}

// ─────────────────────────────────────────────────────────────────────────────
// Scroll Body
// ─────────────────────────────────────────────────────────────────────────────

class _BookingScrollBody extends StatelessWidget {
  final BookingDetailModel model;
  final bool showInlineCancel;
  final PaymentStatus? cancelPayStatus;

  /// True when a sticky bottom bar is shown below this scroll view. The bar
  /// owns the bottom safe-area inset, so the scroll must not also add it
  /// (otherwise an empty band of scaffold bg appears above the bar).
  final bool hasStickyBar;

  const _BookingScrollBody({
    required this.model,
    this.showInlineCancel = false,
    this.cancelPayStatus,
    this.hasStickyBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final sr = model.serviceRequest;
    final status = BookingStatusMapper.fromString(sr.requestStatus);
    final type = BookingStatusMapper.typeFromString(sr.serviceType);
    final payStatus = PaymentStatusMapper.fromString(sr.paymentStatus);
    final bookingConfig = BookingStatusMapper.getConfig(status, type, sr.paymentStatus);

    return CustomRefreshIndicator(
      onRefresh: () async {
        context.read<BookingDetailBloc>().add(RefreshBookingDetail());
        await Future.delayed(const Duration(milliseconds: 600));
      },
      child: SafeArea(
        bottom: !hasStickyBar,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(12.w, 16.h, 12.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero card
              _HeroCard(sr: sr, config: bookingConfig),
              SizedBox(height: 10.h),

              // Session In Progress (mirrors My Bookings list card)
              if (sr.isInProgress || sr.subBlocks.any((b) => b.isOngoing)) ...[
                _SessionInProgressCard(sr: sr),
                SizedBox(height: 10.h),
              ],

              // Schedule
              _ScheduleSection(sr: sr, showInlineCancel: showInlineCancel, cancelPayStatus: cancelPayStatus),
              SizedBox(height: 10.h),

              if (sr.familyMember != null) ...[
                _PatientDetailsSection(member: sr.familyMember!),
                SizedBox(height: 10.h),
              ],

              // Rate last completed session — only when a completed session exists
              _RateLastSessionSection(sr: sr),

              // Sessions
              if (BookingActionResolver.showSessions(sr)) ...[_SessionsSection(sr: sr), SizedBox(height: 10.h)],

              // Payment
              if (sr.totalAmount > 0) ...[
                _PaymentSection(sr: sr, payStatus: payStatus, payConfig: PaymentStatusMapper.getConfig(payStatus)),
                SizedBox(height: 10.h),
              ],

              // Location
              _LocationSection(sr: sr),
              SizedBox(height: 10.h),

              // Special instructions
              if (sr.specialInstructions != null && sr.specialInstructions!.trim().isNotEmpty) ...[
                _InstructionsSection(instructions: sr.specialInstructions!),
                SizedBox(height: 10.h),
              ],

              // Need Help card — always at bottom of scroll
              _NeedHelpCard(
                requestId: sr.id,
                requestNumber: sr.requestNumber,
                serviceName: sr.service?.name ?? sr.serviceTypeText,
                isEmergency: sr.isEmergency,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Card + Header primitives
// ─────────────────────────────────────────────────────────────────────────────

class _SCard extends StatelessWidget {
  final Widget child;

  const _SCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2B4A).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SCardHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;

  const _SCardHeader({required this.icon, required this.iconColor, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 12.w, 12.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(7.w),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: iconColor, size: 15.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(title, style: kTextSemiBold1(color: kTextPrimaryColor)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

Divider get _cardDivider => Divider(height: 1, thickness: 1, color: const Color(0xFFF0F3F8));

// ─────────────────────────────────────────────────────────────────────────────
// Hero Card
// ─────────────────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final ServiceRequestDetail sr;
  final BookingDisplayConfig config;

  const _HeroCard({required this.sr, required this.config});

  @override
  Widget build(BuildContext context) {
    return _SCard(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ServiceIcon(iconUrl: sr.service?.iconImageUrl),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sr.service?.name ?? sr.serviceTypeText,
                        style: kTextBold1(color: kTextPrimaryColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 10.h),
                      _StatusBadge(config: config),
                      if (sr.isEmergency) ...[
                        SizedBox(height: 6.h),
                        _Tag(label: 'Emergency', icon: Icons.bolt_rounded, color: kErrorColor),
                      ],
                    ],
                  ),
                ),
                if (sr.service?.description != null && sr.service!.description!.trim().isNotEmpty)
                  GestureDetector(
                    onTap: () => showServiceDescriptionSheet(
                      context,
                      name: sr.service?.name ?? sr.serviceTypeText,
                      iconUrl: sr.service?.iconImageUrl,
                      htmlDescription: sr.service?.description,
                    ),
                    child: Container(
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.info_outline_rounded, color: kPrimaryColor, size: 16.sp),
                    ),
                  ),
              ],
            ),
          ),
          _cardDivider,
          _BookingIdRow(requestNumber: sr.requestNumber),
        ],
      ),
    );
  }
}

// Mirrors the "Session In Progress" block on the My Bookings list card.
class _SessionInProgressCard extends StatelessWidget {
  final ServiceRequestDetail sr;

  const _SessionInProgressCard({required this.sr});

  // Actual check-in time with date if available & parseable, else scheduled start date and time.
  String _startedAtText(SubBlock block) {
    return AppDateFormatter.formatSessionDateTime(
      actualDateTime: block.actualStartTime,
      actualDate: block.actualStartDateText,
      scheduledDate: block.scheduledDateText.isNotEmpty ? block.scheduledDateText : block.scheduledDate,
      scheduledTime: block.scheduledStartTimeText.isNotEmpty ? block.scheduledStartTimeText : block.scheduledStartTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    SubBlock? ongoing;
    for (final s in sr.subBlocks) {
      if (s.isCurrentlyOngoing(now)) {
        ongoing = s;
        break;
      }
    }
    ongoing ??= sr.subBlocks.isNotEmpty ? sr.subBlocks.first : null;

    final statusColor = RequestStatusHelper.color(
      sr.requestStatus,
      serviceType: sr.serviceType,
      isEmergency: sr.isEmergency,
      paymentStatus: sr.paymentStatus,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.withValues(alpha: 0.15), statusColor.withValues(alpha: 0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.radio_button_checked_rounded, size: 16.sp, color: statusColor),
              SizedBox(width: 8.w),
              Text('Session In Progress', style: kTextBold(color: statusColor)),
            ],
          ),
          if (ongoing != null) ...[
            SizedBox(height: 12.h),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  SubBlockDetailSheet.show(
                    context,
                    subBlockId: ongoing!.id,
                    serviceRequestId: sr.id,
                    requestNumber: sr.requestNumber,
                    serviceName: sr.service?.name ?? sr.serviceTypeText,
                    hideProviderIfEmergency: sr.isEmergency,
                    hideCancelIfEmergency: sr.isEmergency,
                  );
                },
                borderRadius: BorderRadius.circular(10.r),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: kWhiteColor.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: statusColor.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: kSuccessColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.play_arrow_rounded, color: kSuccessColor, size: 18.sp),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Started At', style: kTextNormal0(color: kTextSecondaryColor)),
                            SizedBox(height: 2.h),
                            Text(_startedAtText(ongoing), style: kTextBold(color: kTextPrimaryColor)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: kTextSecondaryColor, size: 20.sp),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ServiceIcon extends StatelessWidget {
  final String? iconUrl;

  const _ServiceIcon({this.iconUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48.r,
      height: 48.r,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kAccentColor.withValues(alpha: 0.08), kAccentColor.withValues(alpha: 0.14)],
        ),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: iconUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(18.r),
              child: AppCachedImage(imageUrl: iconUrl!, fit: BoxFit.cover),
            )
          : Icon(Icons.medical_services_rounded, color: kPrimaryColor, size: 24.sp),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final BookingDisplayConfig config;

  const _StatusBadge({required this.config});

  @override
  Widget build(BuildContext context) {
    if (config.isPulsing) return _PulsingBadge(config: config);
    return _StaticBadge(config: config);
  }
}

class _StaticBadge extends StatelessWidget {
  final BookingDisplayConfig config;

  const _StaticBadge({required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(color: config.bgColor, borderRadius: BorderRadius.circular(20.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, color: config.primaryColor, size: 13.sp),
          SizedBox(width: 5.w),
          Text(config.label, style: kTextSemiBold0(color: config.primaryColor)),
        ],
      ),
    );
  }
}

class _PulsingBadge extends StatefulWidget {
  final BookingDisplayConfig config;

  const _PulsingBadge({required this.config});

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, scrollCtrl) => Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: widget.config.primaryColor.withValues(alpha: 0.06 + _anim.value * 0.1),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: widget.config.primaryColor.withValues(alpha: 0.3 + _anim.value * 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6.r,
              height: 6.r,
              decoration: BoxDecoration(
                color: widget.config.primaryColor.withValues(alpha: 0.5 + _anim.value * 0.5),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 6.w),
            Text(widget.config.label, style: kTextSemiBold0(color: widget.config.primaryColor)),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _Tag({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11.sp),
          SizedBox(width: 3.w),
          Text(label, style: kTextBold0(color: color)),
        ],
      ),
    );
  }
}

class _BookingIdRow extends StatelessWidget {
  final String requestNumber;

  const _BookingIdRow({required this.requestNumber});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: requestNumber));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Booking ID copied'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(5.w),
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Icon(Icons.tag_rounded, color: kPrimaryColor, size: 11.sp),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                requestNumber,
                style: kTextNormal0(color: kTextSecondaryColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.copy_all_rounded, color: kTextSecondaryColor, size: 15.sp),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Schedule Section
// ─────────────────────────────────────────────────────────────────────────────

class _ScheduleSection extends StatelessWidget {
  final ServiceRequestDetail sr;
  final bool showInlineCancel;
  final PaymentStatus? cancelPayStatus;

  const _ScheduleSection({required this.sr, this.showInlineCancel = false, this.cancelPayStatus});

  @override
  Widget build(BuildContext context) {
    final showScheduleBtn = BookingActionResolver.showViewSchedule(sr);

    return _SCard(
      child: Column(
        children: [
          _SCardHeader(
            icon: Icons.calendar_month_rounded,
            iconColor: kPrimaryColor,
            title: 'Service Schedule',
            trailing: showScheduleBtn
                ? _ViewMoreBtn(label: 'Full Schedule', onTap: () => _showScheduleSheet(context, sr))
                : null,
          ),
          _cardDivider,
          Padding(
            padding: AppPadding.m,
            child: Column(
              children: [
                _DateRangeBanner(sr: sr),
                SizedBox(height: 12.h),
                _scheduleInfoGrid(sr),
                if (showInlineCancel && cancelPayStatus != null) ...[
                  SizedBox(height: 12.h),
                  CustomButton(
                    onPressed: () => _handleCancel(context, sr, cancelPayStatus!),
                    title: 'Cancel Booking',
                    backgroundColor: Colors.transparent,
                    textColor: kErrorColor,
                    borderSide: BorderSide(color: kErrorColor.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(12.r),
                    height: 42.h,
                    width: double.infinity,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduleInfoGrid(ServiceRequestDetail sr) {
    final isProcedural = sr.serviceType == 'procedural';
    final isProceduralSingleDay = isProcedural && (sr.durationDays ?? 0) <= 1;

    String durationValue;
    if (isProceduralSingleDay && sr.durationHours != null) {
      final unitType = sr.pricingBreakdown?.unitType ?? 'Hours';
      durationValue = '${sr.durationHours!.toStringAsFixed(0)} $unitType';
    } else {
      durationValue = sr.durationDays != null
          ? '${sr.durationDays} ${(sr.durationDays ?? 0) > 1 ? 'Days' : 'Day'}'
          : sr.durationHours != null
          ? '${sr.durationHours!.toStringAsFixed(0)} Hours'
          : '-';
    }

    final items = [
      _InfoCell(
        icon: Icons.hourglass_bottom_rounded,
        color: const Color(0xFF7C3AED),
        label: 'Duration',
        value: durationValue,
      ),
      isProcedural
          ? _InfoCell(
              icon: Icons.access_time_rounded,
              color: kAccentColor,
              label: 'Time',
              value: '${sr.startTimeText} – ${sr.endTimeText}',
            )
          : _InfoCell(
              icon: Icons.wb_sunny_outlined,
              color: kAccentColor,
              label: 'Shift',
              value: _shiftLabel(sr.shiftType?.replaceAll('_', ' ').trim()),
            ),
      _InfoCell(icon: Icons.home_rounded, color: kSuccessColor, label: 'Mode', value: sr.serviceModeText),
      _InfoCell(
        icon: Icons.medical_services_outlined,
        color: kSecondaryColor,
        label: 'Type',
        value: sr.serviceTypeText,
      ),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _InfoCellTile(cell: items[0])),
            SizedBox(width: 8.w),
            Expanded(child: _InfoCellTile(cell: items[1])),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(child: _InfoCellTile(cell: items[2])),
            SizedBox(width: 8.w),
            Expanded(child: _InfoCellTile(cell: items[3])),
          ],
        ),
      ],
    );
  }

  static String _shiftLabel(String? s) {
    switch (s?.toLowerCase()) {
      case 'day':
        return 'Day';
      case 'night':
        return 'Night';
      case 'full_day':
        return 'Full Day';
      default:
        return s ?? '-';
    }
  }

  static void _showScheduleSheet(BuildContext context, ServiceRequestDetail sr) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        snap: true,
        snapSizes: const [0.72, 0.95],
        builder: (_, ctrl) => SessionScheduleSheet(controller: ctrl, sr: sr),
      ),
    );
  }
}

class _DateRangeBanner extends StatelessWidget {
  final ServiceRequestDetail sr;

  const _DateRangeBanner({required this.sr});

  @override
  Widget build(BuildContext context) {
    final sameDay = sr.startDate == sr.endDate;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryColor.withValues(alpha: 0.04), kSecondaryColor.withValues(alpha: 0.07)],
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: kPrimaryColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          _DatePoint(label: 'Start', date: sr.startDateText, time: sr.startTimeText, color: kSuccessColor),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _DivLine()),
                      Container(
                        padding: EdgeInsets.all(5.w),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_forward_rounded, size: 10.sp, color: kPrimaryColor),
                      ),
                      Expanded(child: _DivLine()),
                    ],
                  ),
                  if (sameDay) ...[
                    SizedBox(height: 4.h),
                    Text('Same Day', style: kTextNormal0(color: kTextSecondaryColor)),
                  ],
                ],
              ),
            ),
          ),
          _DatePoint(label: 'End', date: sr.endDateText, time: sr.endTimeText, color: kErrorColor),
        ],
      ),
    );
  }
}

class _DivLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(height: 1.5, color: kBorderColor);
}

class _DatePoint extends StatelessWidget {
  final String label;
  final String date;
  final String? time;
  final Color color;

  const _DatePoint({required this.label, required this.date, this.time, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5.r)),
          child: Text(label, style: kTextBold0(color: color)),
        ),
        SizedBox(height: 5.h),
        Text(date, style: kTextSemiBold(color: kTextPrimaryColor)),
        if (time != null) ...[SizedBox(height: 2.h), Text(time!, style: kTextNormal0(color: kTextSecondaryColor))],
      ],
    );
  }
}

class _InfoCell {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _InfoCell({required this.icon, required this.color, required this.label, required this.value});
}

class _InfoCellTile extends StatelessWidget {
  final _InfoCell cell;

  const _InfoCellTile({required this.cell});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFEDF0F7)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: cell.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7.r),
            ),
            child: Icon(cell.icon, color: cell.color, size: 12.sp),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cell.label, style: kTextNormal0(color: kTextSecondaryColor)),
                SizedBox(height: 1.h),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(cell.value, style: kTextSemiBold(color: kTextPrimaryColor), maxLines: 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewMoreBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ViewMoreBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: kPrimaryColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: kTextSemiBold0(color: kPrimaryColor)),
            SizedBox(width: 3.w),
            Icon(Icons.chevron_right_rounded, color: kPrimaryColor, size: 14.sp),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment Section
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentSection extends StatelessWidget {
  final ServiceRequestDetail sr;
  final PaymentStatus payStatus;
  final PaymentDisplayConfig payConfig;

  const _PaymentSection({required this.sr, required this.payStatus, required this.payConfig});

  @override
  Widget build(BuildContext context) {
    final pct = sr.totalAmount > 0 ? (sr.paidAmount / sr.totalAmount).clamp(0.0, 1.0) : 0.0;

    return _SCard(
      child: Column(
        children: [
          _SCardHeader(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: const Color(0xFF7C3AED),
            title: 'Payment Summary',
            trailing: _ViewMoreBtn(label: 'Breakdown', onTap: () => _showPaymentSheet(context, sr)),
          ),
          _cardDivider,
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Amount', style: kTextNormal0(color: kTextSecondaryColor)),
                          SizedBox(height: 3.h),
                          Text(
                            NumberUtils.formatCurrency(sr.totalAmount),
                            style: kTextBold3(color: kTextPrimaryColor),
                          ),
                        ],
                      ),
                    ),
                    _PayStatusChip(config: payConfig),
                  ],
                ),
                SizedBox(height: 14.h),
                _ProgressBar(value: pct, color: payStatus == PaymentStatus.paid ? kSuccessColor : kSecondaryColor),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: _AmountTile(
                        label: 'Paid',
                        amount: sr.paidAmount,
                        color: kSuccessColor,
                        icon: Icons.check_circle_rounded,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _AmountTile(
                        label: 'Remaining',
                        amount: sr.remainingAmount,
                        color: sr.remainingAmount > 0 ? kAccentColor : kSuccessColor,
                        icon: sr.remainingAmount > 0 ? Icons.pending_rounded : Icons.check_circle_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _showPaymentSheet(BuildContext context, ServiceRequestDetail sr) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        snap: true,
        snapSizes: const [0.65, 0.95],
        builder: (_, ctrl) => PaymentBreakdownSheet(controller: ctrl, sr: sr),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  final Color color;

  const _ProgressBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 7.h,
          decoration: BoxDecoration(color: const Color(0xFFEDF0F7), borderRadius: BorderRadius.circular(4.r)),
        ),
        FractionallySizedBox(
          widthFactor: value,
          child: Container(
            height: 7.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
        ),
      ],
    );
  }
}

class _PayStatusChip extends StatelessWidget {
  final PaymentDisplayConfig config;

  const _PayStatusChip({required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: config.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, color: config.color, size: 12.sp),
          SizedBox(width: 4.w),
          Text(config.label, style: kTextSemiBold0(color: config.color)),
        ],
      ),
    );
  }
}

class _AmountTile extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _AmountTile({required this.label, required this.amount, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(11.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 15.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: kTextNormal0(color: kTextSecondaryColor)),
                SizedBox(height: 2.h),
                Text(
                  NumberUtils.formatCurrency(amount),
                  style: kTextBold(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rate Last Completed Session — shown only when a completed session exists
// ─────────────────────────────────────────────────────────────────────────────

class _RateLastSessionSection extends StatelessWidget {
  final ServiceRequestDetail sr;

  const _RateLastSessionSection({required this.sr});

  @override
  Widget build(BuildContext context) {
    // Completed sessions that haven't been rated yet
    final completed = sr.subBlocks.where((b) => b.isCompleted && !b.hasRating).toList();
    if (completed.isEmpty) return const SizedBox.shrink();

    // Most recent completed session by scheduled date (then start time)
    completed.sort((a, b) {
      final d = b.scheduledDate.compareTo(a.scheduledDate);
      return d != 0 ? d : b.scheduledStartTime.compareTo(a.scheduledStartTime);
    });
    final last = completed.first;
    final bookingId = last.bookingId;
    if (bookingId == null) return const SizedBox.shrink();

    final dateStr = AppDateFormatter.dateFromApi(last.scheduledDateText);
    final timeStr = AppDateFormatter.shiftTimeRange(last.scheduledStartTime, last.scheduledEndTime);
    final serviceName = sr.service?.name ?? sr.serviceTypeText;

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: _SCard(
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(9.w),
                    decoration: BoxDecoration(
                      color: kWarningColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(Icons.star_rounded, color: kWarningColor, size: 20.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rate your last session', style: kTextBold1(color: kTextPrimaryColor)),
                        SizedBox(height: 3.h),
                        Text(
                          '$dateStr  ·  $timeStr',
                          style: kTextNormal0(color: kTextSecondaryColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              GestureDetector(
                onTap: () async {
                  await showFeedbackBottomSheet(
                    context: context,
                    bookingId: bookingId,
                    bookingSubBlockId: last.id,
                    serviceName: serviceName,
                    onSuccess: () => context.read<BookingDetailBloc>().add(RefreshBookingDetail()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 46.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: kWarningColor.withValues(alpha: 0.30),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star_rounded, color: kWhiteColor, size: 19.sp),
                      SizedBox(width: 8.w),
                      Text('Rate Now', style: kTextBold1(color: kWhiteColor)),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Sessions Section
// ─────────────────────────────────────────────────────────────────────────────

class _SessionsSection extends StatefulWidget {
  final ServiceRequestDetail sr;

  const _SessionsSection({required this.sr});

  @override
  State<_SessionsSection> createState() => _SessionsSectionState();
}

class _SessionsSectionState extends State<_SessionsSection> {
  static const int _collapsedDateLimit = 4;
  bool _expanded = false;

  // null = show all; otherwise 'completed' | 'confirmed' | 'cancelled'
  String? _filter;

  void _toggleFilter(String key) {
    setState(() {
      _filter = _filter == key ? null : key;
      _expanded = false;
    });
  }

  bool _matchesFilter(SubBlock b) {
    switch (_filter) {
      case 'completed':
        return b.isCompleted;
      case 'confirmed':
        return b.isConfirmed;
      case 'cancelled':
        return b.isCancelled;
      case 'expired':
        return b.isExpired;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocks = widget.sr.subBlocks;
    final done = blocks.where((s) => s.isCompleted).length;
    final pending = blocks.where((s) => s.isConfirmed).length;
    final cancelled = blocks.where((s) => s.isCancelled).length;
    final expired = blocks.where((s) => s.isExpired).length;

    // Sort by date then start time, apply filter, then group by date
    final sorted = [...blocks.where(_matchesFilter)]
      ..sort((a, b) {
        final d = a.scheduledDate.compareTo(b.scheduledDate);
        return d != 0 ? d : a.scheduledStartTime.compareTo(b.scheduledStartTime);
      });
    final grouped = <String, List<SubBlock>>{};
    for (final b in sorted) {
      (grouped[b.scheduledDate] ??= []).add(b);
    }
    final dateKeys = grouped.keys.toList();

    final hasMore = dateKeys.length > _collapsedDateLimit;
    final visibleKeys = _expanded || !hasMore ? dateKeys : dateKeys.take(_collapsedDateLimit).toList();
    final hiddenDateCount = dateKeys.length - _collapsedDateLimit;

    final serviceName = widget.sr.service?.name ?? widget.sr.serviceTypeText;
    final paymentPending = widget.sr.paymentStatus == 'pending' && widget.sr.requestStatus == 'accepted';
    final lockedCancelIds = lockedCancelSubBlockIds(widget.sr);

    return _SCard(
      child: Column(
        children: [
          _SCardHeader(
            icon: Icons.view_timeline_rounded,
            iconColor: kInfoColor,
            title: 'Sessions',
            trailing: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: kInfoColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                '${blocks.length} ${blocks.length == 1 ? 'session' : 'sessions'}',
                style: kTextSemiBold0(color: kInfoColor),
              ),
            ),
          ),
          _cardDivider,
          Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              children: [
                // Stats row — tap a chip to filter the list
                Row(
                  children: [
                    _SessionStatChip(
                      count: done,
                      label: 'Completed',
                      color: kSuccessColor,
                      selected: _filter == 'completed',
                      onTap: () => _toggleFilter('completed'),
                    ),
                    SizedBox(width: 8.w),
                    _SessionStatChip(
                      count: pending,
                      label: 'Confirmed',
                      color: kSecondaryColor,
                      selected: _filter == 'confirmed',
                      onTap: () => _toggleFilter('confirmed'),
                    ),
                    if (expired > 0) ...[
                      SizedBox(width: 8.w),
                      _SessionStatChip(
                        count: expired,
                        label: 'Expired',
                        color: kTextSecondaryColor,
                        selected: _filter == 'expired',
                        onTap: () => _toggleFilter('expired'),
                      ),
                    ],
                    SizedBox(width: 8.w),
                    _SessionStatChip(
                      count: cancelled,
                      label: 'Cancelled',
                      color: kErrorColor,
                      selected: _filter == 'cancelled',
                      onTap: () => _toggleFilter('cancelled'),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                if (_filter != null) ...[
                  Row(
                    children: [
                      Icon(Icons.filter_alt_rounded, size: 13.sp, color: kInfoColor),
                      SizedBox(width: 5.w),
                      Expanded(
                        child: Text(
                          'Showing ${sorted.length} ${_filter == 'confirmed' ? 'confirmed' : _filter} ${sorted.length == 1 ? 'session' : 'sessions'}',
                          style: kTextSemiBold0(color: kInfoColor),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _filter = null),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: kInfoColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text('Clear', style: kTextSemiBold0(color: kInfoColor)),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                ],
                // Empty state when a filter matches nothing
                if (sorted.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    child: Column(
                      children: [
                        Icon(Icons.event_busy_rounded, size: 28.sp, color: kTextSecondaryColor),
                        SizedBox(height: 8.h),
                        Text('No sessions in this category', style: kTextNormal0(color: kTextSecondaryColor)),
                      ],
                    ),
                  ),
                // Grouped by date
                Column(
                  children: [
                    for (int i = 0; i < visibleKeys.length; i++) ...[
                      if (i > 0) Divider(color: kBorderColor, height: 1),
                      _DateGroupRow(
                        dateKey: visibleKeys[i],
                        sessions: grouped[visibleKeys[i]]!,
                        requestId: widget.sr.id,
                        requestNumber: widget.sr.requestNumber,
                        serviceName: serviceName,
                        isEmergency: widget.sr.isEmergency,
                        paymentPending: paymentPending,
                        lockedCancelIds: lockedCancelIds,
                        onCancelBlock: (b) => _handleCancelBlock(context, b),
                      ),
                    ],
                  ],
                ),
                if (hasMore) ...[
                  SizedBox(height: 10.h),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      decoration: BoxDecoration(
                        color: kInfoColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: kInfoColor.withValues(alpha: 0.18)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _expanded ? 'Show less' : 'Show $hiddenDateCount more dates',
                            style: kTextSemiBold(color: kInfoColor),
                          ),
                          SizedBox(width: 4.w),
                          Icon(
                            _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            color: kInfoColor,
                            size: 16.sp,
                          ),
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
    );
  }

  Future<void> _handleCancelBlock(BuildContext context, SubBlock block) async {
    if (!context.mounted) return;

    final now = locator<AppClock>().now;
    if (!block.startDateTime.isAfter(now)) {
      DialogHelper.showInfo(
        title: 'Cancel Session',
        message: 'Cannot cancel a session whose scheduled start time has passed.',
        buttonText: 'OK',
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Container(
        color: Colors.transparent,
        child: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      ),
    );

    try {
      final previewRes = await locator<ServiceRequestRepository>().getCancellationPreview(
        widget.sr.id,
        subBlockIds: [block.id],
      );

      if (!context.mounted) return;
      Navigator.pop(context); // dismiss loading

      if (previewRes['status'] != true || previewRes['data'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(previewRes['message'] as String? ?? 'Failed to load preview'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final preview = CancellationPreviewModel.fromJson(previewRes['data'] as Map<String, dynamic>);
      final bloc = context.read<BookingDetailBloc>();

      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _CancellationPreviewSheet(
          preview: preview,
          subBlocks: [block],
          onConfirm: (reason) {
            Navigator.pop(context);
            bloc.add(CancelWithSubBlocks(subBlockIds: [block.id], reason: reason));
          },
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      Navigator.pop(context); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load cancellation preview'), behavior: SnackBarBehavior.floating),
      );
    }
  }
}

class _SessionStatChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  const _SessionStatChip({
    required this.count,
    required this.label,
    required this.color,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.16 : 0.06),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: color.withValues(alpha: selected ? 0.7 : 0.18),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text('$count', style: kTextBold1(color: color)),
              SizedBox(height: 2.h),
              Text(
                label,
                style: (selected ? kTextSemiBold0(color: color) : kTextNormal0(color: kTextSecondaryColor)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cancellation lock window (long-duration bookings)
// ─────────────────────────────────────────────────────────────────────────────

/// Sub-block ids that are NOT cancellable for a long-duration booking.
///
/// Rule: the paid percentage of installments determines how much of the booking
/// is cancellable. Ordering sessions earliest-first, the first
/// `round(totalSessions × paidPercentage)` sessions are cancellable and the
/// remaining (unpaid) tail is locked. When every installment is paid the booking
/// is fully cancellable (empty set). Returns an empty set when nothing is locked.
Set<int> lockedCancelSubBlockIds(ServiceRequestDetail sr) {
  final installments = sr.paymentInstallments;
  if (installments.isEmpty) return const {};

  // All installments paid → fully cancellable.
  if (installments.every((i) => i.isPaid)) return const {};

  // Paid percentage of installments → cancellable portion (from start).
  final paidPercent = installments
      .where((i) => i.isPaid)
      .fold<int>(0, (sum, i) => sum + i.percentage);
  if (paidPercent <= 0) return const {};

  final blocks = [...sr.subBlocks]
    ..sort((a, b) {
      final d = a.scheduledDate.compareTo(b.scheduledDate);
      return d != 0 ? d : a.scheduledStartTime.compareTo(b.scheduledStartTime);
    });
  final total = blocks.length;
  if (total == 0) return const {};

  final cancellableCount = (total * paidPercent / 100).round();
  if (cancellableCount >= total) return const {};

  final locked = <int>{};
  for (int i = cancellableCount; i < total; i++) {
    locked.add(blocks[i].id);
  }
  return locked;
}

// ─────────────────────────────────────────────────────────────────────────────
// Date-grouped session row
// ─────────────────────────────────────────────────────────────────────────────
class _DateGroupRow extends StatelessWidget {
  final String dateKey; // ISO date "2026-06-01"
  final List<SubBlock> sessions;
  final int requestId;
  final String requestNumber;
  final String serviceName;
  final bool isEmergency;
  final bool paymentPending;
  final Set<int> lockedCancelIds;
  final void Function(SubBlock) onCancelBlock;

  const _DateGroupRow({
    required this.dateKey,
    required this.sessions,
    required this.requestId,
    required this.requestNumber,
    required this.serviceName,
    this.isEmergency = false,
    this.paymentPending = false,
    this.lockedCancelIds = const {},
    required this.onCancelBlock,
  });

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(dateKey);
    final dateStr = dt != null ? DateFormat('EEE, dd MMM').format(dt) : dateKey;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header pill
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(7.r),
            ),
            child: Text(dateStr, style: kTextBold(color: kPrimaryColor)),
          ),
          SizedBox(height: 8.h),
          ...sessions.map((block) {
            final config = SubBlockStatusMapper.getConfig(
              SubBlockStatusMapper.fromString(block.status, isExpired: block.isExpired),
            );
            final color = config.primaryColor;
            final startTime = AppDateFormatter.formatTimeString(block.scheduledStartTimeText);
            final endTime = AppDateFormatter.formatTimeString(block.scheduledEndTimeText);

            return Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10.r),
                child: InkWell(
                  onTap: () => SubBlockDetailSheet.show(
                    context,
                    subBlockId: block.id,
                    serviceRequestId: requestId,
                    requestNumber: requestNumber,
                    serviceName: serviceName,
                    hideProviderIfEmergency: isEmergency && paymentPending,
                    hideCancelIfEmergency: isEmergency,
                    lockCancel: lockedCancelIds.contains(block.id),
                    onCancelRequest: () => onCancelBlock(block),
                  ),
                  borderRadius: BorderRadius.circular(10.r),
                  splashColor: color.withValues(alpha: 0.1),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: color.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      children: [
                        // Left accent bar
                        Container(
                          width: 3.w,
                          height: 34.h,
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2.r)),
                        ),
                        SizedBox(width: 10.w),
                        // Time + status
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.access_time_rounded, size: 11.sp, color: color),
                                  SizedBox(width: 4.w),
                                  Flexible(
                                    child: Text(
                                      '$startTime  –  $endTime',
                                      style: kTextSemiBold(color: kTextPrimaryColor),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4.h),
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Text(
                                      config.label,
                                      style: kTextSemiBold0(color: color).copyWith(fontSize: 10.sp),
                                    ),
                                  ),
                                  if (block.isCompleted) ...[
                                    SizedBox(width: 6.w),
                                    _SessionRatingTag(
                                      block: block,
                                      requestId: requestId,
                                      serviceName: serviceName,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Details pill button (fixed color, independent of status)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
                          decoration: BoxDecoration(
                            color: kPrimaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(7.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Details', style: kTextSemiBold0(color: kPrimaryColor)),
                              SizedBox(width: 3.w),
                              Icon(Icons.arrow_forward_rounded, size: 11.sp, color: kPrimaryColor),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-session rating tag — read-only star when rated, "Rate" chip otherwise
// ─────────────────────────────────────────────────────────────────────────────

class _SessionRatingTag extends StatelessWidget {
  final SubBlock block;
  final int requestId;
  final String serviceName;

  const _SessionRatingTag({required this.block, required this.requestId, required this.serviceName});

  @override
  Widget build(BuildContext context) {
    // Already rated → compact read-only badge "★ N"
    if (block.hasRating) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: kWarningColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 11.sp, color: kWarningColor),
            SizedBox(width: 2.w),
            Text(
              '${block.rating ?? '-'}',
              style: kTextBold0(color: kWarningColor).copyWith(fontSize: 10.sp),
            ),
          ],
        ),
      );
    }

    // Completed but not rated → tappable "Rate" chip
    final bookingId = block.bookingId;
    if (bookingId == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () async {
        await showFeedbackBottomSheet(
          context: context,
          bookingId: bookingId,
          bookingSubBlockId: block.id,
          serviceName: serviceName,
          onSuccess: () => context.read<BookingDetailBloc>().add(RefreshBookingDetail()),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: kWarningColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4.r),
          border: Border.all(color: kWarningColor.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_outline_rounded, size: 11.sp, color: kWarningColor),
            SizedBox(width: 2.w),
            Text(
              'Rate',
              style: kTextBold0(color: kWarningColor).copyWith(fontSize: 10.sp),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Location Section
// ─────────────────────────────────────────────────────────────────────────────

class _LocationSection extends StatelessWidget {
  final ServiceRequestDetail sr;

  const _LocationSection({required this.sr});

  @override
  Widget build(BuildContext context) {
    return _SCard(
      child: Column(
        children: [
          _SCardHeader(icon: Icons.location_on_rounded, iconColor: kErrorColor, title: 'Service Location'),
          _cardDivider,
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: kErrorColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(Icons.location_pin, color: kErrorColor, size: 16.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sr.fullAddress, style: kTextNormal(color: kTextPrimaryColor).copyWith(height: 1.45)),
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 6.w,
                        runSpacing: 4.h,
                        children: [_LocTag(icon: Icons.location_city_rounded, label: sr.city)],
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

class _LocTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _LocTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(6.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: kSecondaryColor, size: 11.sp),
          SizedBox(width: 4.w),
          Text(label, style: kTextSemiBold0(color: kSecondaryColor)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Instructions Section
// ─────────────────────────────────────────────────────────────────────────────

class _InstructionsSection extends StatelessWidget {
  final String instructions;

  const _InstructionsSection({required this.instructions});

  @override
  Widget build(BuildContext context) {
    return _SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SCardHeader(icon: Icons.sticky_note_2_rounded, iconColor: kWarningColor, title: 'Patient medical history/Patient condition(optional)'),
          _cardDivider,
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Text(instructions, style: kTextNormal(color: kTextPrimaryColor).copyWith(height: 1.5)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky Bottom Action Bar
// ─────────────────────────────────────────────────────────────────────────────

class _BottomActionBar extends StatelessWidget {
  final ServiceRequestDetail sr;
  final BookingStatus status;
  final BookingType type;
  final PaymentStatus payStatus;

  const _BottomActionBar({required this.sr, required this.status, required this.type, required this.payStatus});

  @override
  Widget build(BuildContext context) {
    final canPayNow = BookingActionResolver.showPayNow(type: type, status: status, paymentStatus: payStatus);
    final canCancel = BookingActionResolver.showCancel(status, type: type, paymentStatus: payStatus);

    return Material(
      color: kWhiteColor,
      elevation: 10,
      shadowColor: kPrimaryColor.withValues(alpha: 0.1),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
          child: Row(
            children: [
              if (canCancel) ...[
                Expanded(
                  child: CustomButton(
                    onPressed: () => _onCancel(context),
                    title: 'Cancel',
                    backgroundColor: Colors.transparent,
                    textColor: kErrorColor,
                    borderSide: BorderSide(color: kErrorColor.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(12.r),
                    height: 48.h,
                  ),
                ),
                if (canPayNow) SizedBox(width: 10.w),
              ],
              if (canPayNow)
                Expanded(
                  flex: canCancel ? 2 : 1,
                  child: CustomButton(
                    onPressed: () => _onPayNow(context),
                    title: 'Pay Now',
                    backgroundColor: kPrimaryColor,
                    borderRadius: BorderRadius.circular(12.r),
                    height: 48.h,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onPayNow(BuildContext context) {
    // Block payment when the scheduled start has already passed.
    if (sr.isStartInPast) {
      showPastBookingDialog(
        context,
        RescheduleInfo(
          serviceRequestId: sr.id,
          requestNumber: sr.requestNumber,
          serviceName: sr.service?.name ?? sr.serviceTypeText,
          serviceCategoryId: sr.service?.serviceCategoryId,
          serviceSubCategoryId: sr.service?.id,
          bookingType: sr.serviceType,
          isEmergency: sr.isEmergency,
          startDateText: sr.startDateText,
          startTimeText: sr.startTimeText,
        ),
      );
      return;
    }
    final bd = sr.pricingBreakdown;
    navigateToPaymentPage(
      context: context,
      serviceRequestId: sr.id,
      totalAmount: sr.totalAmount,
      basePrice: sr.basePrice,
      distanceCharge: bd?.distanceCharge ?? 0,
      gstAmount: bd?.gstAmount ?? 0,
      paymentInstallments: sr.paymentInstallments
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
          .toList(),
      serviceName: sr.service?.name ?? sr.serviceTypeText,
      serviceImageUrl: sr.service?.iconImageUrl,
      startDate: sr.startDateText,
      endDate: sr.endDateText,
      durationDays: sr.durationDays,
      durationHours: sr.durationHours?.toInt(),
      isEmergency: sr.isEmergency,
      isNewBooking: false,
      packageDiscountAmount: (sr.pricingBreakdown?.package?.actualPrice ?? 0.0) -
          (sr.pricingBreakdown?.package?.price ?? 0.0),
    );
  }

  Future<void> _onCancel(BuildContext context) => _handleCancel(context, sr, payStatus);
}

Future<void> _handleCancel(BuildContext context, ServiceRequestDetail sr, PaymentStatus payStatus) async {
  final now = locator<AppClock>().now;
  kPrint(now);
  // return;
  // Unpaid booking — direct cancel via unpaid endpoint
  if (payStatus == PaymentStatus.pending) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => _CancelConfirmDialog(
        requestId: sr.id,
        onConfirm: () {
          Navigator.pop(context);
          context.read<BookingDetailBloc>().add(CancelUnpaidBookingDetail());
        },
      ),
    );
    return;
  }

  // final now = locator<AppClock>().now;

  // Get cancellable sub-block IDs (pending + assigned only, excluding expired and slots whose scheduled start time has passed)
  final cancellableIds = sr.subBlocks
      .where((b) =>
          (b.status == 'pending' || b.status == 'assigned') &&
          !b.isExpired &&
          b.startDateTime.isAfter(now))
      .map((b) => b.id)
      .toList();

  if (cancellableIds.isEmpty) {
    if (!context.mounted) return;
    DialogHelper.showInfo(
      title: 'Cancel Booking',
      message: 'There are no active slots to cancel.',
      buttonText: 'OK',
    );
    return;
  }

  // Show loading while fetching preview
  if (!context.mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Container(
      color: Colors.transparent,
      child: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
    ),
  );

  try {
    final previewRes = await locator<ServiceRequestRepository>().getCancellationPreview(
      sr.id,
      subBlockIds: cancellableIds,
    );

    if (!context.mounted) return;
    Navigator.pop(context); // dismiss loading

    if (previewRes['status'] != true || previewRes['data'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(previewRes['message'] as String? ?? 'Failed to load preview'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final preview = CancellationPreviewModel.fromJson(previewRes['data'] as Map<String, dynamic>);
    final cancellableBlocks = sr.subBlocks.where((b) => cancellableIds.contains(b.id)).toList();

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CancellationPreviewSheet(
        preview: preview,
        subBlocks: cancellableBlocks,
        onConfirm: (reason) {
          Navigator.pop(context);
          context.read<BookingDetailBloc>().add(CancelWithSubBlocks(subBlockIds: cancellableIds, reason: reason));
        },
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    Navigator.pop(context); // dismiss loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('Failed to load cancellation preview'), behavior: SnackBarBehavior.floating),
    );
  }
}

class _NeedHelpCard extends StatelessWidget {
  final int requestId;
  final String requestNumber;
  final String serviceName;
  final bool isEmergency;

  const _NeedHelpCard({
    required this.requestId,
    required this.requestNumber,
    required this.serviceName,
    required this.isEmergency,
  });

  @override
  Widget build(BuildContext context) {
    final sosNumber = locator<LocalStorageService>().emergencyContactNumber;
    final showSos = isEmergency && sosNumber != null && sosNumber.isNotEmpty;
    return _SCard(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(Icons.support_agent_rounded, color: kPrimaryColor, size: 16.sp),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Need Help?', style: kTextSemiBold1(color: kTextPrimaryColor)),
                      Text('We\'re available 24/7 for you', style: kTextNormal0(color: kTextSecondaryColor)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: _SupportBtn(
                    icon: Icons.phone_rounded,
                    label: 'Call Support',
                    color: kSuccessColor,
                    onTap: () async => LaunchUrlService.makePhoneCall(AppConstants.supportPhone),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _SupportBtn(
                    icon: Icons.headset_mic_rounded,
                    label: 'Raise Issue',
                    color: kPrimaryColor,
                    onTap: () => AppNavigator.to(
                      AppRoutes.createSupportTicket,
                      arguments: {
                        'requestId': requestId.toString(),
                        'requestNumber': requestNumber,
                        'serviceName': serviceName,
                      },
                    ),
                  ),
                ),
                if (showSos) ...[
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _SupportBtn(
                      icon: Icons.emergency_rounded,
                      label: 'SOS',
                      color: kErrorColor,
                      onTap: () async => LaunchUrlService.makePhoneCall(sosNumber),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SupportBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18.sp),
            SizedBox(height: 4.h),
            Text(
              label,
              style: kTextSemiBold0(color: color),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cancel Confirm Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _CancelConfirmDialog extends StatelessWidget {
  final int requestId;
  final VoidCallback onConfirm;

  const _CancelConfirmDialog({required this.requestId, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Container(
        padding: EdgeInsets.all(28.r),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(28.r),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 24, offset: const Offset(0, 12)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.cancel_outlined, color: kErrorColor, size: 32.sp),
            ),
            SizedBox(height: 24.h),
            Text(
              'Cancel Booking?',
              style: kTextBold1(color: kTextPrimaryColor).copyWith(fontSize: 18.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              'Are you sure you want to cancel this booking? This action may be irreversible.',
              style: kTextNormal(color: kTextSecondaryColor).copyWith(height: 1.4, fontSize: 14.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    onPressed: () => Navigator.pop(context),
                    title: 'Keep it',
                    backgroundColor: Colors.transparent,
                    textColor: kTextSecondaryColor,
                    borderSide: BorderSide(color: kBorderColor, width: 1.5),
                    borderRadius: BorderRadius.circular(16.r),
                    height: 50.h,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: CustomButton(
                    onPressed: onConfirm,
                    title: 'Cancel',
                    backgroundColor: kErrorColor,
                    borderRadius: BorderRadius.circular(16.r),
                    height: 50.h,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading Skeleton (shimmer)
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8ECF2),
      highlightColor: const Color(0xFFF6F8FC),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            // Hero card skeleton
            _ShimBox(height: 130.h, radius: 20.r),
            SizedBox(height: 10.h),
            // Schedule card
            _ShimBox(height: 230.h, radius: 20.r),
            SizedBox(height: 10.h),
            // Payment card
            _ShimBox(height: 180.h, radius: 20.r),
            SizedBox(height: 10.h),
            // Sessions card
            _ShimBox(height: 150.h, radius: 20.r),
            SizedBox(height: 10.h),
            // Location card
            _ShimBox(height: 110.h, radius: 20.r),
          ],
        ),
      ),
    );
  }
}

class _ShimBox extends StatelessWidget {
  final double height;
  final double radius;

  const _ShimBox({required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cancellation Preview Sheet
// ─────────────────────────────────────────────────────────────────────────────

const List<String> _kCancelReasons = [
  'Change of plans',
  'Partner not needed anymore',
  'Found alternative service',
  'Medical condition changed',
  'Emergency',
  'Others',
];

class _CancellationPreviewSheet extends StatefulWidget {
  final CancellationPreviewModel preview;
  final List<SubBlock> subBlocks;
  final void Function(String? reason) onConfirm;

  const _CancellationPreviewSheet({required this.preview, required this.subBlocks, required this.onConfirm});

  @override
  State<_CancellationPreviewSheet> createState() => _CancellationPreviewSheetState();
}

class _CancellationPreviewSheetState extends State<_CancellationPreviewSheet> {
  String? _selectedReason;
  bool _confirming = false;
  bool _reasonError = false;

  void _pickReason() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 10.h, bottom: 4.h),
              child: Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(2.r)),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 8.h),
              child: Text('Select a reason', style: kTextSemiBold1(color: kTextPrimaryColor)),
            ),
            Divider(height: 1, color: kBorderColor),
            ..._kCancelReasons.map((r) {
              final selected = _selectedReason == r;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedReason = r;
                    _reasonError = false;
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                  decoration: BoxDecoration(
                    color: selected ? kPrimaryColor.withValues(alpha: 0.06) : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(r, style: kTextNormal(color: selected ? kPrimaryColor : kTextPrimaryColor)),
                      ),
                      if (selected) Icon(Icons.check_rounded, color: kPrimaryColor, size: 16.sp),
                    ],
                  ),
                ),
              );
            }),
            SafeArea(top: false, child: SizedBox(height: 8.h)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.preview;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SingleChildScrollView(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Padding(
                  padding: EdgeInsets.only(top: 10.h, bottom: 6.h),
                  child: Center(
                    child: Container(
                      width: 36.w,
                      height: 4.h,
                      decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(2.r)),
                    ),
                  ),
                ),
                // Title
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 2.h, 16.w, 12.h),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: kErrorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(Icons.cancel_outlined, color: kErrorColor, size: 16.sp),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text('Cancellation Preview', style: kTextBold1(color: kTextPrimaryColor)),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(color: const Color(0xFFF1F4F9), shape: BoxShape.circle),
                          child: Icon(Icons.close_rounded, size: 16.sp, color: kTextSecondaryColor),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: kBorderColor),

                // Content
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Calculation summary card ────────────────────────
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [kSuccessColor.withValues(alpha: 0.05), kPrimaryColor.withValues(alpha: 0.04)],
                          ),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: kSuccessColor.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CalcRow(
                              label: 'Total Paid Value',
                              amount: NumberUtils.formatCurrency(p.totalPaidValue),
                              color: kTextPrimaryColor,
                            ),
                            SizedBox(height: 8.h),
                            _CalcRow(
                              label: 'Cancellation Fee',
                              amount: '− ${NumberUtils.formatCurrency(p.cancellationFee)}',
                              color: kErrorColor,
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              child: Divider(height: 1, color: kBorderColor),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Refund Amount', style: kTextSemiBold(color: kTextSecondaryColor)),
                                Text(
                                  NumberUtils.formatCurrency(p.refundAmount),
                                  style: kTextBold2(color: p.refundAmount > 0 ? kSuccessColor : kErrorColor),
                                ),
                              ],
                            ),
                            if (p.refundAmount > 0) ...[
                              SizedBox(height: 8.h),
                              Row(
                                children: [
                                  Icon(Icons.account_balance_wallet_rounded, color: kSuccessColor, size: 12.sp),
                                  SizedBox(width: 5.w),
                                  Expanded(
                                    child: Text(
                                      '${NumberUtils.formatCurrency(p.refundAmount)} will be credited to your original payment source.',
                                      style: kTextNormal0(color: kSuccessColor).copyWith(fontSize: 11.sp),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (p.cancellationFee > 0) ...[
                              SizedBox(height: 10.h),
                              Container(
                                padding: EdgeInsets.all(10.w),
                                decoration: BoxDecoration(
                                  color: kWarningColor.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(color: kWarningColor.withValues(alpha: 0.15)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded, color: kWarningColor, size: 13.sp),
                                    SizedBox(width: 6.w),
                                    Expanded(
                                      child: Text(
                                        'A cancellation fee of ${NumberUtils.formatCurrency(p.cancellationFee)} will be deducted.',
                                        style: kTextNormal0(color: kTextPrimaryColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // ── Custom reason picker ────────────────────────────
                      Row(
                        children: [
                          Text('Reason for cancellation', style: kTextSemiBold(color: kTextPrimaryColor)),
                          SizedBox(width: 4.w),
                          Text('*', style: kTextSemiBold(color: kErrorColor)),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      GestureDetector(
                        onTap: _pickReason,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                          decoration: BoxDecoration(
                            color: _reasonError ? kErrorColor.withValues(alpha: 0.04) : const Color(0xFFF8FAFD),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: _reasonError
                                  ? kErrorColor.withValues(alpha: 0.5)
                                  : _selectedReason == null
                                  ? kBorderColor
                                  : kPrimaryColor.withValues(alpha: 0.4),
                              width: _reasonError ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedReason ?? 'Select a reason',
                                  style: kTextNormal(
                                    color: _selectedReason == null ? kTextSecondaryColor : kTextPrimaryColor,
                                  ),
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down_rounded, color: kTextSecondaryColor, size: 20.sp),
                            ],
                          ),
                        ),
                      ),
                      if (_reasonError) ...[
                        SizedBox(height: 5.h),
                        Row(
                          children: [
                            Icon(Icons.error_outline_rounded, size: 12.sp, color: kErrorColor),
                            SizedBox(width: 4.w),
                            Text(
                              'Please select a reason to proceed',
                              style: kTextNormal0(color: kErrorColor).copyWith(fontSize: 11.sp),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: 18.h),

                      // ── Confirm button — requires a reason ──────────────
                      CustomButton(
                        onPressed: _confirming
                            ? null
                            : () {
                                if (_selectedReason == null) {
                                  setState(() => _reasonError = true);
                                  return;
                                }
                                setState(() => _confirming = true);
                                widget.onConfirm(_selectedReason);
                              },
                        title: 'Confirm Cancellation',
                        isLoading: _confirming,
                        backgroundColor: kErrorColor,
                        borderRadius: BorderRadius.circular(12.r),
                        height: 50.h,
                        width: double.infinity,
                      ),
                      SizedBox(height: 16.h),
                      Center(
                        child: GestureDetector(
                          onTap: () => LaunchUrlService.launchInAppWebUrl(RedirectionUrl.cancellationPolicy),
                          child: Text(
                            'View Cancellation Policy',
                            style: kTextSemiBold(color: kPrimaryColor).copyWith(
                              fontSize: 13.sp,
                              decoration: TextDecoration.underline,
                              decorationColor: kPrimaryColor,
                            ),
                          ),
                        ),
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

class _CalcRow extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;

  const _CalcRow({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: kTextNormal(color: kTextSecondaryColor)),
        Text(amount, style: kTextSemiBold(color: color)),
      ],
    );
  }
}

class _PatientDetailsSection extends StatelessWidget {
  final FamilyMemberModel member;

  const _PatientDetailsSection({required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_rounded, color: kPrimaryColor, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Patient Details',
                style: kTextBold1(color: kTextPrimaryColor).copyWith(fontSize: 16.sp),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1),
          Row(
            children: [
              Container(
                width: 44.r,
                height: 44.r,
                decoration: const BoxDecoration(
                  color: kPrimaryColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : 'P',
                  style: kTextBold(color: kWhiteColor).copyWith(fontSize: 18.sp),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.fullName,
                      style: kTextBold1(color: kTextPrimaryColor).copyWith(fontSize: 15.sp),
                    ),
                    SizedBox(height: 4.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        member.relationship,
                        style: kTextSemiBold(color: kPrimaryColor).copyWith(fontSize: 10.sp),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildInfoRow(Icons.cake_outlined, 'Date of Birth', AppDateFormatter.dateFromApi(member.dateOfBirth)),
          _buildInfoRow(
            member.gender.toLowerCase() == 'female'
                ? Icons.female_rounded
                : (member.gender.toLowerCase() == 'male' ? Icons.male_rounded : Icons.transgender_rounded),
            'Gender',
            member.gender.isEmpty
                ? ''
                : (member.gender.substring(0, 1).toUpperCase() + member.gender.substring(1)),
          ),
          if (member.mobileNumber != null && member.mobileNumber!.isNotEmpty)
            _buildInfoRow(Icons.phone_iphone_rounded, 'Mobile Number', member.mobileNumber!),
          if (member.bloodGroup != null && member.bloodGroup!.isNotEmpty)
            _buildInfoRow(Icons.water_drop_outlined, 'Blood Group', member.bloodGroup!),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Icon(icon, color: kTextSecondaryColor, size: 16.sp),
          SizedBox(width: 10.w),
          Text(
            '$label: ',
            style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 13.sp),
          ),
          Text(
            value,
            style: kTextMedium(color: kTextPrimaryColor).copyWith(fontSize: 13.sp),
          ),
        ],
      ),
    );
  }
}
