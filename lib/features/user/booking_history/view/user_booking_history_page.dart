import 'dart:async';

import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/services/app_clock.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/features/user/booking_history/helper/reschedule_helper.dart';
import 'package:adhisaat_health_care/shared/widgets/common/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/message_service.dart';
import '../../../../di/locator.dart';
import '../../../../shared/widgets/buttons/custom_button.dart';
import '../../../../shared/widgets/common/app_cached_image.dart';
import '../../../../shared/widgets/shimmer/user_shimmers.dart';
import '../../../user/payment/view/booking_payment_page.dart';
import '../../../user/service_booking/bloc/service_request_bloc.dart';
import '../../../user/service_booking/data/service_request_repository.dart';
import '../../../user/service_booking/model/service_request_model.dart';
import '../helper/request_status_helper.dart';
import '../model/booking_detail_model.dart';
import '../widget/sub_block_detail_sheet.dart';

// ─── Tab model ────────────────────────────────────────────────────────────────

class _TabDef {
  final String label;
  final String? apiStatus;

  const _TabDef(this.label, this.apiStatus);
}

// ─── Tabs config ────────────────────────────────────────────────────────────
const _tabs = [
  _TabDef('Active', 'searching,accepted,in_progress,standby,partially_accepted'),
  _TabDef('Completed', 'completed'),
  _TabDef('Cancelled', 'cancelled,expired'),
];

// ─── Page ─────────────────────────────────────────────────────────────────────

class UserBookingHistoryPage extends StatefulWidget {
  final bool showBackButton;

  const UserBookingHistoryPage({super.key, this.showBackButton = true});

  @override
  State<UserBookingHistoryPage> createState() => _UserBookingHistoryPageState();
}

class _UserBookingHistoryPageState extends State<UserBookingHistoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhiteColor,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            // ── Fixed Header ──
            _buildHeader(context),

            // ── Tab Content ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _tabs.map((tab) => _TabLoader(tab: tab, searchQuery: _searchCtrl.text)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: kWhiteColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            backgroundColor: kWhiteColor,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: widget.showBackButton
                ? IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18.sp, color: kTextPrimaryColor),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null,
            title: Text('My Bookings', style: kTextBold().copyWith(fontSize: 20.sp)),
            centerTitle: true,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0.h, 16.w, 12.h),
            child: _SearchBar(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              onClear: () {
                _searchCtrl.clear();
                setState(() {});
              },
            ),
          ),
          _TabStrip(controller: _tabController, tabs: _tabs),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
        ],
      ),
    );
  }
}

// ─── Tab Loader ───────────────────────────────────────────────────────────────
// Isolates Bloc instance per tab to enable caching and prevent "shimmer flash" on tab switch.
class _TabLoader extends StatefulWidget {
  final _TabDef tab;
  final String searchQuery;

  const _TabLoader({required this.tab, required this.searchQuery});

  @override
  State<_TabLoader> createState() => _TabLoaderState();
}

class _TabLoaderState extends State<_TabLoader> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocProvider(
      key: ValueKey('tab_${widget.tab.label}'),
      create: (context) => ServiceRequestBloc(locator<ServiceRequestRepository>())
        ..add(
          LoadServiceRequests(
            status: widget.tab.apiStatus,
            search: widget.searchQuery.trim().isEmpty ? null : widget.searchQuery.trim(),
          ),
        ),
      child: _TabContent(tab: widget.tab, searchQuery: widget.searchQuery),
    );
  }
}

class _TabContent extends StatefulWidget {
  final _TabDef tab;
  final String searchQuery;

  const _TabContent({required this.tab, required this.searchQuery});

  @override
  State<_TabContent> createState() => _TabContentState();
}

class _TabContentState extends State<_TabContent> {
  @override
  void didUpdateWidget(covariant _TabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If search text changed in the parent, refresh this tab
    if (oldWidget.searchQuery != widget.searchQuery) {
      _reload();
    }
  }

  void _reload() {
    context.read<ServiceRequestBloc>().add(
      LoadServiceRequests(
        status: widget.tab.apiStatus,
        search: widget.searchQuery.trim().isEmpty ? null : widget.searchQuery.trim(),
        perPage: 10,
      ),
    );
  }

  void _loadMore(ServiceRequestListLoaded state) {
    final nextPage = (state.requests.length ~/ 10) + 1;
    context.read<ServiceRequestBloc>().add(
      LoadMoreServiceRequests(
        page: nextPage,
        status: widget.tab.apiStatus,
        search: widget.searchQuery.trim().isEmpty ? null : widget.searchQuery.trim(),
        perPage: 10,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomRefreshIndicator(
      onRefresh: () async => _reload(),
      child: BlocBuilder<ServiceRequestBloc, ServiceRequestState>(
        builder: (context, state) {
          if (state is ServiceRequestLoading) {
            return const BookingHistoryShimmer();
          }
          if (state is ServiceRequestError) {
            return _ErrorView(message: state.message, onRetry: _reload);
          }
          if (state is ServiceRequestListLoaded) {
            return _BookingList(
              items: state.requests,
              tabIndex: _tabs.indexOf(widget.tab),
              hasMore: state.hasMore,
              isLoadingMore: state.isLoadingMore,
              onLoadMore: () => _loadMore(state),
              onRefresh: _reload,
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ─── Search Bar ───────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({required this.controller, required this.onChanged, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kGreyColor1.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(28.r),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: kPrimaryColor,
        style: kTextNormal(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 11.h),
          hintText: 'Search bookings, services...',
          hintStyle: kTextNormal(color: kTextHintColor).copyWith(fontSize: 14.sp),
          prefixIcon: Icon(Icons.search_rounded, color: kPrimaryColor, size: 22.sp),
          prefixIconConstraints: BoxConstraints(minWidth: 44.w),
          fillColor: kGreyColor1,

          suffixIcon: ValueListenableBuilder(
            valueListenable: controller,
            builder: (ctx, v, _) => v.text.isNotEmpty
                ? Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: IconButton(
                      onPressed: onClear,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(Icons.close_rounded, size: 18.sp, color: kTextHintColor),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          suffixIconConstraints: BoxConstraints(minHeight: 20.h),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

// ─── Tab Strip ────────────────────────────────────────────────────────────────

class _TabStrip extends StatelessWidget {
  final TabController controller;
  final List<_TabDef> tabs;

  const _TabStrip({required this.controller, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48.h,
      decoration: BoxDecoration(color: kWhiteColor),
      child: TabBar(
        controller: controller,
        labelColor: kPrimaryColor,
        unselectedLabelColor: kTextSecondaryColor,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: kPrimaryColor, width: 3),
          insets: EdgeInsets.symmetric(horizontal: 16.w),
        ),
        labelStyle: kTextBold().copyWith(fontSize: 12.sp),
        unselectedLabelStyle: kTextMedium().copyWith(fontSize: 12.sp),
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        tabs: tabs.map((t) => Tab(height: 48.h, text: t.label)).toList(),
      ),
    );
  }
}

// ─── Booking List ─────────────────────────────────────────────────────────────

class _BookingList extends StatelessWidget {
  final List<ServiceRequestModel> items;
  final int tabIndex;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final VoidCallback onRefresh;

  const _BookingList({
    required this.items,
    required this.tabIndex,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return _EmptyState(tabIndex: tabIndex);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
      itemCount: items.length + 1,
      itemBuilder: (_, i) {
        if (i == items.length) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasMore)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: isLoadingMore
                      ? const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2))
                      : Center(
                          child: TextButton(
                            onPressed: onLoadMore,
                            child: Text('Load more', style: kTextSemiBold(color: kPrimaryColor)),
                          ),
                        ),
                ),
              SizedBox(height: 40.h),
            ],
          );
        }
        return Padding(
          padding: EdgeInsets.only(bottom: 4.h),
          child: _BookingCard(r: items[i], onRefresh: onRefresh),
        );
      },
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final int tabIndex;

  const _EmptyState({required this.tabIndex});

  static const _data = [
    (Icons.bolt_rounded, Color(0xFF8B5CF6), 'No Active Bookings', 'You have no bookings in progress right now.'),
    (
      Icons.check_circle_outline_rounded,
      Color(0xFF10B981),
      'No Completed Bookings',
      "You haven't completed any bookings yet.",
    ),
    (Icons.cancel_outlined, Color(0xFFEF4444), 'No Cancelled Bookings', 'No cancelled bookings found.'),
  ];

  @override
  Widget build(BuildContext context) {
    final idx = tabIndex.clamp(0, _data.length - 1);
    final (icon, color, title, subtitle) = _data[idx];

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: constraints.maxHeight,
          alignment: Alignment.center,
          padding: EdgeInsets.all(40.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, size: 28.sp, color: color.withValues(alpha: 0.6)),
              ),
              SizedBox(height: 16.h),
              Text(
                title,
                style: kTextBold().copyWith(fontSize: 18.sp),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6.h),
              Text(
                subtitle,
                style: kTextNormal(color: kTextSecondaryColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Card State ───────────────────────────────────────────────────────────────

enum _CardState { searching, paymentPending, confirmed, inProgress, completed, cancelled }

_CardState _classifyCardState(ServiceRequestModel r) {
  if (r.isCancelledOrExpired) return _CardState.cancelled;
  if (r.isCompleted) return _CardState.completed;
  // Searching has no provider yet — never treat as ongoing/active, even if a
  // pending session's scheduled time window has started (emergency case).
  if (r.status == 'searching') {
    if (r.isEmergency) {
      return _CardState.searching;
    } else if (r.needsPayment) {
      return _CardState.paymentPending;
    } else {
      return _CardState.confirmed;
    }
  }
  final now = DateTime.now();
  if (r.subBlocks.any((s) => s.isCurrentlyOngoing(now))) return _CardState.inProgress;
  if (r.status == 'in_progress') return _CardState.inProgress;
  if (r.needsPayment && !r.isCancelledOrExpired) return _CardState.paymentPending;
  return _CardState.confirmed;
}

String _smartStatusLabel(ServiceRequestModel r, _CardState cardState) {
  switch (cardState) {
    case _CardState.searching:
      return 'Searching Partner';
    case _CardState.paymentPending:
      return 'Payment Pending';
    case _CardState.inProgress:
      return 'Session Active';
    case _CardState.completed:
      return 'Completed';
    case _CardState.cancelled:
      return r.isExpired ? 'Expired' : 'Cancelled';
    case _CardState.confirmed:
      if (r.status == 'accepted' || r.status == 'searching' || r.status == 'standby') return 'Confirmed';
      final now = DateTime.now();
      if (r.subBlocks.any((s) => s.isFuture(now) && !s.isCancelled)) return 'Upcoming';
      return 'Confirmed';
  }
}

String? _bookingTypeBadge(ServiceRequestModel r) {
  if (r.isEmergency) return 'Emergency';
  switch (r.serviceType) {
    case 'long_duration':
      return 'Long Duration';
    case 'procedural':
      return 'Procedural';
    default:
      return null;
  }
}

Color _bookingTypeBadgeColor(ServiceRequestModel r) {
  if (r.isEmergency) return kErrorColor;
  if (r.serviceType == 'long_duration') return kInfoColor;
  return kSecondaryColor;
}

// ─── Booking Card ─────────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final ServiceRequestModel r;
  final VoidCallback onRefresh;

  const _BookingCard({required this.r, required this.onRefresh});

  Future<void> _toDetail(BuildContext context) async {
    final result = await AppNavigator.to(AppRoutes.serviceRequestDetail, arguments: r.id);
    if (result == true && context.mounted) onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final cardState = _classifyCardState(r);
    final statusColor = RequestStatusHelper.color(
      r.status,
      serviceType: r.serviceType,
      isEmergency: r.isEmergency,
      paymentStatus: r.paymentStatus,
    );
    final statusLabel = _smartStatusLabel(r, cardState);
    final isLive = cardState == _CardState.inProgress;

    return GestureDetector(
      onTap: () => _toDetail(context),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(8.r),
          boxShadow: [
            BoxShadow(
              color: isLive ? statusColor.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.05),
              blurRadius: isLive ? 20 : 10,
              offset: const Offset(0, 4),
              spreadRadius: isLive ? 1 : -2,
            ),
          ],
          border: Border.all(color: isLive ? statusColor.withValues(alpha: 0.3) : const Color(0xFFEDF0F7)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.r),
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
                // Card content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 8.h),
                        child: _ServiceRow(r: r, statusColor: statusColor, statusLabel: statusLabel),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 10.h),
                        child: _StateBody(r: r, cardState: cardState, statusColor: statusColor),
                      ),
                      _CardFooterRow(
                        r: r,
                        cardState: cardState,
                        onNavigate: () => _toDetail(context),
                        onRefresh: onRefresh,
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

// ─── Service Row ──────────────────────────────────────────────────────────────

class _ServiceRow extends StatelessWidget {
  final ServiceRequestModel r;
  final Color statusColor;
  final String statusLabel;

  const _ServiceRow({required this.r, required this.statusColor, required this.statusLabel});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44.r,
          height: 44.r,
          decoration: BoxDecoration(
            color: kAccentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: (r.serviceIconUrl ?? r.categoryIconUrl) != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: AppCachedImage(
                    imageUrl: r.serviceIconUrl ?? r.categoryIconUrl,
                    fit: BoxFit.cover,
                    errorWidgetBuilder: Icon(
                      r.isEmergency ? Icons.emergency_rounded : Icons.medical_services_rounded,
                      color: statusColor,
                      size: 20.sp,
                    ),
                  ),
                )
              : Icon(
                  r.isEmergency ? Icons.emergency_rounded : Icons.medical_services_rounded,
                  color: statusColor,
                  size: 20.sp,
                ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.serviceName ?? r.serviceCategoryName,
                style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 15.sp),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 5.h),
              Row(
                children: [
                  _StatusPill(label: statusLabel, color: statusColor),
                  Flexible(
                    child: Builder(
                      builder: (_) {
                        final badge = _bookingTypeBadge(r);
                        if (badge == null) return const SizedBox.shrink();
                        final badgeColor = _bookingTypeBadgeColor(r);
                        return Padding(
                          padding: EdgeInsets.only(left: 6.w),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(5.r),
                            ),
                            child: Text(
                              badge,
                              style: kTextNormal0(color: badgeColor).copyWith(fontSize: 9.sp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
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
    );
  }
}

// ─── Status Pill ──────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.r,
            height: 6.r,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 5.w),
          Text(label, style: kTextSemiBold0(color: color)),
        ],
      ),
    );
  }
}

// ─── Card Actions ─────────────────────────────────────────────────────────────

class _CardActions extends StatelessWidget {
  final ServiceRequestModel r;
  final VoidCallback onNavigate;
  final VoidCallback onRefresh;

  const _CardActions({required this.r, required this.onNavigate, required this.onRefresh});

  Future<void> _payNow(BuildContext context) async {
    // Block payment when the scheduled start has already passed.
    if (r.isStartInPast) {
      showPastBookingDialog(
        context,
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
    if (r.totalAmount == null) {
      onNavigate();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
    );

    try {
      final repo = locator<ServiceRequestRepository>();
      final response = await repo.getServiceRequestDetailsById(r.id);
      final model = BookingDetailModel.fromJson(response);
      final sr = model.serviceRequest;

      if (!context.mounted) return;
      Navigator.pop(context);

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
        context: context,
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
        onCancel: onRefresh,
        packageDiscountAmount:
            (sr.pricingBreakdown?.package?.actualPrice ?? 0.0) - (sr.pricingBreakdown?.package?.price ?? 0.0),
      );
      if (context.mounted) onRefresh();
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        MessageService.showError('Failed to load payment details. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 8.h),
      child: Row(
        children: [
          // ── Left: contextual primary action ──────────────────────
          if (r.isPending &&
              r.needsPayment &&
              !r.isEmergency &&
              (r.serviceType == 'procedural' || r.serviceType == 'long_duration'))
            _ActionChip(
              label: 'Complete Payment',
              icon: Icons.payment_rounded,
              color: kOrangeColor,
              filled: true,
              onTap: () => _payNow(context),
            )
          else if (r.needsPayment && r.totalAmount != null && !r.isCancelledOrExpired && !r.isCompleted)
            _ActionChip(
              label: 'Pay Now',
              icon: Icons.payment_rounded,
              color: const Color(0xFF10B981),
              filled: true,
              onTap: () => _payNow(context),
            )
          // else if (r.status == 'in_progress' && !r.isServiceEnded)
          //   _ActionChip(label: 'Extend', icon: Icons.add_alarm_rounded, color: const Color(0xFF8B5CF6), onTap: onNavigate)
          else if (r.isCompleted && r.hasRating)
            _RatingBadge(rating: r.ratingFeedback!.rating),

          const Spacer(),

          // Track — emergency service started only
          if (r.isEmergency && r.serviceStarted && !r.isServiceEnded)
            _IconAction(
              icon: Icons.location_on_rounded,
              color: kErrorColor,
              onTap: () => AppNavigator.to(AppRoutes.emergencyTracking, arguments: r.id),
            ),
        ],
      ),
    );
  }
}

// ─── Reusable action widgets ──────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _ActionChip({
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
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          gradient: filled
              ? LinearGradient(
                  colors: [color, Color.lerp(color, kBlackColor, 0.12)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: filled ? null : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12.r),
          border: filled ? null : Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: filled
              ? [BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 10, offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15.sp, color: fg),
            SizedBox(width: 6.w),
            Text(
              label,
              style: kTextBold(color: fg).copyWith(fontSize: 12.sp),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconAction({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10.r)),
      child: Icon(icon, size: 16.sp, color: color),
    ),
  );
}

class _RatingBadge extends StatelessWidget {
  final int rating;

  const _RatingBadge({required this.rating});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF9C3),
      borderRadius: BorderRadius.circular(10.r),
      border: Border.all(color: const Color(0xFFFDE047)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: 13.sp, color: const Color(0xFFF59E0B)),
        SizedBox(width: 4.w),
        Text('$rating / 5', style: kTextSemiBold0(color: const Color(0xFFB45309))),
      ],
    ),
  );
}

// ─── State Body ───────────────────────────────────────────────────────────────

class _StateBody extends StatelessWidget {
  final ServiceRequestModel r;
  final _CardState cardState;
  final Color statusColor;

  const _StateBody({required this.r, required this.cardState, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    if (r.isEmergency && cardState == _CardState.searching) {
      return _SearchingBody(r: r);
    }
    switch (cardState) {
      // return _SearchingBody(r: r);
      case _CardState.paymentPending:
        return _PaymentPendingBody(r: r);
      case _CardState.searching:
      case _CardState.confirmed:
        return _ConfirmedBody(r: r, statusColor: statusColor);
      case _CardState.inProgress:
        return _InProgressBody(r: r, statusColor: statusColor);
      case _CardState.completed:
        return _CompletedBody(r: r);
      case _CardState.cancelled:
        return _CancelledBody(r: r);
    }
  }
}

// ─── Searching Body ───────────────────────────────────────────────────────────

class _SearchingBody extends StatelessWidget {
  final ServiceRequestModel r;

  const _SearchingBody({required this.r});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(11.w),
      decoration: BoxDecoration(
        color: kWarningColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: kWarningColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.manage_search_rounded, size: 13.sp, color: kWarningColor),
              SizedBox(width: 6.w),
              Text('Finding Healthcare Partner', style: kTextSemiBold(color: kTextPrimaryColor)),
            ],
          ),
          SizedBox(height: 3.h),
          Text('We\'re matching the best professional nearby.', style: kTextNormal0(color: kTextSecondaryColor)),
          SizedBox(height: 6.h),
          _TimeAgoChip(createdAt: r.createdAt),
        ],
      ),
    );
  }
}

// ─── Payment Pending Body ─────────────────────────────────────────────────────

class _PaymentPendingBody extends StatelessWidget {
  final ServiceRequestModel r;

  const _PaymentPendingBody({required this.r});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kOrangeColor.withValues(alpha: 0.10), kOrangeColor.withValues(alpha: 0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: kOrangeColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (r.startDateText != null) ...[
            _BInfoRow(
              icon: Icons.calendar_today_rounded,
              text: AppDateFormatter.dateRangeShort(r.startDateText, r.endDateText),
            ),
            SizedBox(height: 10.h),
          ],
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(5.w),
                decoration: BoxDecoration(color: kOrangeColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(Icons.priority_high_rounded, size: 12.sp, color: kOrangeColor),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Complete payment to confirm your booking',
                  style: kTextSemiBold0(color: const Color(0xFF92400E)).copyWith(fontSize: 12.sp),
                ),
              ),
            ],
          ),
          if (r.totalAmount != null) ...[
            SizedBox(height: 10.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: kWhiteColor,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: kOrangeColor.withValues(alpha: 0.20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Amount pending',
                      style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
                    ),
                  ),
                  Text(NumberUtils.formatCurrency(r.totalAmount), style: kTextBold1(color: kOrangeColor)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Confirmed Body ───────────────────────────────────────────────────────────

class _ConfirmedBody extends StatelessWidget {
  final ServiceRequestModel r;
  final Color statusColor;

  const _ConfirmedBody({required this.r, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    final completedCount = r.subBlocks.where((s) => s.isCompleted).length;
    final cancelledCount = r.subBlocks.where((s) => s.isCancelled).length;
    final expiredCount = r.subBlocks.where((s) => s.isExpired).length;
    final pendingCount = r.subBlocks.where((s) => s.isConfirmed).length;
    final totalCount = r.subBlocks.length;
    final isMultiSession = totalCount > 1;

    final now = locator.isRegistered<AppClock>() ? locator<AppClock>().now : DateTime.now();
    final futureSessions =
        (r.subBlocks.where((s) => s.isFuture(now) && !s.isCancelled && !s.isCompleted && !s.isExpired).toList()
          ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime)));
    final nextSession = futureSessions.isNotEmpty ? futureSessions.first : null;
    final afterThat = futureSessions.length >= 2 ? futureSessions[1] : null;

    // Duration label
    String? durationLabel;
    if (r.durationDays != null && r.durationDays! > 1) {
      durationLabel = '${r.durationDays} Days';
    } else if (r.durationHours != null && r.durationHours! > 0) {
      durationLabel = '${r.durationHours} hr';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date range + duration on same line
        Row(
          children: [
            if (r.startDateText != null)
              Flexible(
                child: _BInfoRow(
                  icon: Icons.calendar_today_rounded,
                  text: AppDateFormatter.dateRangeShort(r.startDateText, r.endDateText),
                ),
              ),
            if (durationLabel != null) ...[
              SizedBox(width: 10.w),
              _BInfoRow(icon: Icons.timelapse_rounded, text: durationLabel),
            ],
          ],
        ),
        // Session breakdown for multi-session bookings
        if (isMultiSession) ...[
          SizedBox(height: 8.h),
          _SessionBreakdown(
            completed: completedCount,
            pending: pendingCount,
            expired: expiredCount,
            cancelled: cancelledCount,
            total: totalCount,
            color: statusColor,
          ),
        ],
        // Next session
        if (nextSession != null) ...[
          SizedBox(height: 8.h),
          _NextSessionRow(session: nextSession, color: statusColor, label: 'Upcoming Session'),
        ],
        // After that
        if (afterThat != null) ...[
          SizedBox(height: 5.h),
          _NextSessionRow(session: afterThat, color: kTextSecondaryColor, label: 'After That'),
        ],
      ],
    );
  }
}

// ─── In Progress Body ─────────────────────────────────────────────────────────

class _InProgressBody extends StatelessWidget {
  final ServiceRequestModel r;
  final Color statusColor;

  const _InProgressBody({required this.r, required this.statusColor});

  String _startedAtText(SubBlockSummary block) {
    return AppDateFormatter.formatSessionDateTime(
      actualDateTime: block.actualStartTime,
      scheduledDate: block.scheduledDateText.isNotEmpty ? block.scheduledDateText : block.scheduledDate,
      scheduledTime: block.scheduledStartTimeText.isNotEmpty
          ? block.scheduledStartTimeText
          : block.scheduledStartTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    SubBlockSummary? ongoing;
    for (final s in r.subBlocks) {
      if (s.isCurrentlyOngoing(now)) {
        ongoing = s;
        break;
      }
    }
    ongoing ??= r.subBlocks.isNotEmpty ? r.subBlocks.first : null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.withValues(alpha: 0.15), statusColor.withValues(alpha: 0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: statusColor.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 4)),
        ],
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
                    serviceRequestId: r.id,
                    requestNumber: r.requestNumber,
                    serviceName: r.service?.name ?? r.serviceTypeText,
                    hideProviderIfEmergency: r.isEmergency,
                    hideCancelIfEmergency: r.isEmergency,
                  );
                },
                borderRadius: BorderRadius.circular(10.r),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.7),
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

// ─── Completed Body ───────────────────────────────────────────────────────────

class _CompletedBody extends StatelessWidget {
  final ServiceRequestModel r;

  const _CompletedBody({required this.r});

  @override
  Widget build(BuildContext context) {
    final completedCount = r.subBlocks.where((s) => s.isCompleted).length;
    final cancelledCount = r.subBlocks.where((s) => s.isCancelled).length;
    final expiredCount = r.subBlocks.where((s) => s.isExpired).length;
    final totalCount = r.subBlocks.length;
    final isMultiSession = totalCount > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BInfoRow(
          icon: Icons.task_alt_rounded,
          text: 'Completed · ${r.endDateText ?? r.startDateText ?? ''}',
          color: kSuccessColor,
        ),
        if (isMultiSession) ...[
          SizedBox(height: 6.h),
          Row(
            children: [
              _SessionStat(count: completedCount, label: 'Done', color: kSuccessColor),
              if (expiredCount > 0) ...[
                SizedBox(width: 12.w),
                _SessionStat(count: expiredCount, label: 'Expired', color: kTextSecondaryColor),
              ],
              if (cancelledCount > 0) ...[
                SizedBox(width: 12.w),
                _SessionStat(count: cancelledCount, label: 'Cancelled', color: kErrorColor),
              ],
            ],
          ),
        ] else ...[
          SizedBox(height: 4.h),
          _BInfoRow(
            icon: Icons.grid_view_rounded,
            text: '${totalCount == 1 ? '1 Session' : '$totalCount Sessions'} Completed',
          ),
        ],
      ],
    );
  }
}

// ─── Cancelled Body ───────────────────────────────────────────────────────────

class _CancelledBody extends StatelessWidget {
  final ServiceRequestModel r;

  const _CancelledBody({required this.r});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BInfoRow(
          icon: Icons.cancel_rounded,
          text: r.cancelledAt != null
              ? 'Cancelled · ${AppDateFormatter.dateShort(r.cancelledAt!)}'
              : r.isExpired
              ? 'Booking Expired'
              : 'Booking Cancelled',
          color: kErrorColor,
        ),
        if (r.startDateText != null) ...[
          SizedBox(height: 4.h),
          _BInfoRow(
            icon: Icons.calendar_today_rounded,
            text: AppDateFormatter.dateRangeShort(r.startDateText, r.endDateText),
          ),
        ],
      ],
    );
  }
}

// ─── Session Breakdown ────────────────────────────────────────────────────────

class _SessionBreakdown extends StatelessWidget {
  final int completed;
  final int pending;
  final int expired;
  final int cancelled;
  final int total;
  final Color color;

  const _SessionBreakdown({
    required this.completed,
    required this.pending,
    this.expired = 0,
    required this.cancelled,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        Stack(
          children: [
            Container(
              height: 4.h,
              decoration: BoxDecoration(color: const Color(0xFFEDF0F7), borderRadius: BorderRadius.circular(2.r)),
            ),
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: 4.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.6)]),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        // Stats row
        Row(
          children: [
            _SessionStat(count: completed, label: 'Done', color: kSuccessColor),
            if (pending > 0 || (expired == 0 && cancelled == 0)) ...[
              SizedBox(width: 12.w),
              _SessionStat(count: pending, label: 'Pending', color: color),
            ],
            if (expired > 0) ...[
              SizedBox(width: 12.w),
              _SessionStat(count: expired, label: 'Expired', color: kTextSecondaryColor),
            ],
            if (cancelled > 0) ...[
              SizedBox(width: 12.w),
              _SessionStat(count: cancelled, label: 'Cancelled', color: kErrorColor),
            ],
          ],
        ),
      ],
    );
  }
}

class _SessionStat extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _SessionStat({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6.r,
          height: 6.r,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 4.w),
        Text('$count $label', style: kTextNormal0(color: kTextSecondaryColor)),
      ],
    );
  }
}

// ─── Next Session Row ─────────────────────────────────────────────────────────

class _NextSessionRow extends StatelessWidget {
  final SubBlockSummary session;
  final Color color;
  final String label;

  const _NextSessionRow({required this.session, required this.color, this.label = 'Next'});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sDt = session.startDateTime;
    final sessionDate = DateTime(sDt.year, sDt.month, sDt.day);
    final isToday = sessionDate == today;
    final isTomorrow = sessionDate == today.add(const Duration(days: 1));
    final dateStr = isToday
        ? 'Today'
        : isTomorrow
        ? 'Tomorrow'
        : AppDateFormatter.dateShort(session.scheduledDateText);
    final timeStr = AppDateFormatter.formatTimeString(session.scheduledStartTimeText);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_rounded, size: 11.sp, color: color),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: kTextNormal0(color: color).copyWith(fontSize: 9.sp),
              ),
              Text('$dateStr · $timeStr', style: kTextSemiBold0(color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Shared info row ──────────────────────────────────────────────────────────

class _BInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _BInfoRow({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? kTextSecondaryColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11.sp, color: c),
        SizedBox(width: 5.w),
        Flexible(
          child: Text(
            text,
            style: kTextNormal0(color: c),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Time Ago Chip ────────────────────────────────────────────────────────────

class _TimeAgoChip extends StatelessWidget {
  final String createdAt;

  const _TimeAgoChip({required this.createdAt});

  String _ago() {
    try {
      final dt = DateTime.parse(createdAt.replaceAll(' ', 'T'));
      final d = DateTime.now().difference(dt);
      if (d.inSeconds < 60) return 'just now';
      if (d.inMinutes < 60) return '${d.inMinutes} min ago';
      if (d.inHours < 24) return '${d.inHours} hr ago';
      return '${d.inDays} day${d.inDays > 1 ? 's' : ''} ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ago = _ago();
    if (ago.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.access_time_rounded, size: 10.sp, color: kTextHintColor),
        SizedBox(width: 4.w),
        Text('Requested $ago', style: kTextNormal0(color: kTextHintColor)),
      ],
    );
  }
}

// ─── Card Footer Row ──────────────────────────────────────────────────────────

class _CardFooterRow extends StatelessWidget {
  final ServiceRequestModel r;
  final _CardState cardState;
  final VoidCallback onNavigate;
  final VoidCallback onRefresh;

  const _CardFooterRow({
    required this.r,
    required this.cardState,
    required this.onNavigate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // Payment pending — delegate to existing _CardActions (has full payment dialog logic)
    if (cardState == _CardState.paymentPending) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          _CardActions(r: r, onNavigate: onNavigate, onRefresh: onRefresh),
        ],
      );
    }

    Widget? leftAction;

    if (r.isEmergency && r.serviceStarted && !r.isServiceEnded) {
      leftAction = _ActionChip(
        label: 'Track',
        icon: Icons.location_on_rounded,
        color: kErrorColor,
        onTap: () => AppNavigator.to(AppRoutes.emergencyTracking, arguments: r.id),
      );
    }
    /*else if (cardState == _CardState.inProgress && !r.isServiceEnded) {
      leftAction = _ActionChip(
        label: 'View Session',
        icon: Icons.play_circle_outline_rounded,
        color: kPrimaryColor,
        onTap: onNavigate,
      );
    } */
    else if (cardState == _CardState.completed) {
      if (r.hasRating) {
        leftAction = _RatingBadge(rating: r.ratingFeedback!.rating);
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 2.h, 12.w, 10.h),
      child: Row(
        children: [
          if (leftAction != null) ...[leftAction, const Spacer()],
          if (leftAction == null) const Spacer(),
          _ViewDetailsBtn(onTap: onNavigate),
        ],
      ),
    );
  }
}

// ─── View Details Button ──────────────────────────────────────────────────────

class _ViewDetailsBtn extends StatelessWidget {
  final VoidCallback onTap;

  const _ViewDetailsBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'View Details',
            style: kTextSemiBold(color: kPrimaryColor).copyWith(fontSize: 12.sp),
          ),
          SizedBox(width: 3.w),
          Icon(Icons.arrow_forward_rounded, size: 12.sp, color: kPrimaryColor),
        ],
      ),
    );
  }
}

// ─── Session Chip (legacy — unused, kept for reference) ───────────────────────

// class _SessionChip extends StatelessWidget {
//   final SubBlockSummary session;
//   final bool isOngoing;
//
//   const _SessionChip({required this.session, required this.isOngoing});
//
//   @override
//   Widget build(BuildContext context) {
//     if (isOngoing) {
//       return Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 6.w,
//             height: 6.w,
//             decoration: const BoxDecoration(color: kSuccessColor, shape: BoxShape.circle),
//           ),
//           SizedBox(width: 4.w),
//           Text(
//             'Ongoing · ${AppDateFormatter.formatTimeString(session.scheduledStartTimeText)} – ${AppDateFormatter.formatTimeString(session.scheduledEndTimeText)}',
//             style: kTextSemiBold(color: kSuccessColor).copyWith(fontSize: 10.sp),
//           ),
//         ],
//       );
//     }
//     final now = DateTime.now();
//     final today = DateTime(now.year, now.month, now.day);
//     final sDt = session.startDateTime;
//     final sessionDate = DateTime(sDt.year, sDt.month, sDt.day);
//
//     if (sessionDate.isBefore(today)) return const SizedBox.shrink();
//
//     final isToday = sessionDate == today;
//     final dateLabel = isToday ? 'Today' : 'Upcoming · ${AppDateFormatter.dateShort(session.scheduledDateText)}';
//
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Icon(Icons.event_rounded, size: 11.sp, color: kSecondaryColor),
//         SizedBox(width: 4.w),
//         Text(
//           '$dateLabel · ${AppDateFormatter.formatTimeString(session.scheduledStartTimeText)}',
//           style: kTextSemiBold(color: kSecondaryColor).copyWith(fontSize: 10.sp),
//         ),
//       ],
//     );
//   }
// }

// ─── Error View ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: constraints.maxHeight,
          alignment: Alignment.center,
          padding: EdgeInsets.all(36.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68.w,
                height: 68.w,
                decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.08), shape: BoxShape.circle),
                child: Icon(Icons.wifi_off_rounded, size: 30.sp, color: kErrorColor.withValues(alpha: 0.5)),
              ),
              SizedBox(height: 18.h),
              Text('Connection Problem', style: kTextBold2()),
              SizedBox(height: 6.h),
              Text(
                message,
                style: kTextNormal(color: kTextSecondaryColor),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20.h),
              CustomButton(
                onPressed: onRetry,
                title: 'Try Again',
                iconData: Icons.refresh_rounded,
                backgroundColor: kPrimaryColor,
                textColor: kWhiteColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
