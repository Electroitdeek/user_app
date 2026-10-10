import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/services/launch_url_service.dart';
import 'package:adhisaat_health_care/core/storage/local_storage_service.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_home/bloc/provider_dashboard_bloc/provider_dashboard_bloc.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_home/bloc/provider_dashboard_bloc/provider_dashboard_event.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/bloc/provider_request_list_bloc/provider_request_bloc.dart';
import 'package:adhisaat_health_care/shared/widgets/buttons/custom_button.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_cached_image.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_search_field.dart';
import 'package:adhisaat_health_care/shared/widgets/shimmer/provider_shimmers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../data/models/provider_service_request_model.dart';
import '../data/models/request_status.dart';
import '../data/models/sub_block_model.dart';
import '../dialogs/date_conflict_dialog.dart';
import '../widgets/full_day_booking_sheet.dart';
import '../widgets/request_schedule_bottom_sheet.dart';

const _cEmergencyBg = Color(0xFFFFF1F1);
const _cActiveBg = Color(0xFFF5F3FF);
const _cPageBg = kScaffoldColor;

class ProviderRequestsPage extends StatelessWidget {
  final bool showBackButton;
  final String initialStatus;

  const ProviderRequestsPage({super.key, this.showBackButton = true, this.initialStatus = 'new_request'});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProviderRequestBloc()..add(LoadRequest(status: initialStatus)),
      child: _RequestsView(showBackButton: showBackButton),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Root view
// ─────────────────────────────────────────────────────────────────
class _RequestsView extends StatefulWidget {
  final bool showBackButton;

  const _RequestsView({this.showBackButton = true});

  @override
  State<_RequestsView> createState() => _RequestsViewState();
}

class _RequestsViewState extends State<_RequestsView> with WidgetsBindingObserver {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<ProviderRequestBloc>().add(const RefreshRequests());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProviderRequestBloc, ProviderRequestState>(
      listenWhen: (_, curr) => curr is ProviderRequestActionSuccess || curr is ProviderRequestActionFailure,
      listener: (context, state) {
        if (state is ProviderRequestActionFailure) {
          final isConflict = state.errorType == 'date_conflict';

          if (isConflict) {
            DateConflictDialog.show(
              context,
              conflictDates: state.conflictDates,
              message: state.message.isNotEmpty ? state.message : null,
            );
          } else {
            final message = state.message.isNotEmpty
                ? state.message
                : 'Request already accepted by another provider or no longer available.';
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dCtx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                contentPadding: EdgeInsets.all(24.w),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64.w,
                      height: 64.w,
                      decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(Icons.block_rounded, color: kErrorColor, size: 36.sp),
                    ),
                    SizedBox(height: 16.h),
                    Text('Request Unavailable', style: kTextBold2(), textAlign: TextAlign.center),
                    SizedBox(height: 8.h),
                    Text(
                      message,
                      style: kTextNormal(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dCtx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                        ),
                        child: Text('OK', style: kTextBold1(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return;
        }
        if (state is! ProviderRequestActionSuccess) return;
        try {
          context.read<ProviderDashboardBloc>().add(RefreshDashboardEvent());
        } catch (_) {}
        if (state.action == 'accepted') {
          // Show success dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dCtx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
              contentPadding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 20.h),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64.w,
                    height: 64.w,
                    decoration: BoxDecoration(color: kSuccessColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(Icons.check_circle_rounded, color: kSuccessColor, size: 36.sp),
                  ),
                  SizedBox(height: 16.h),
                  Text('Booking Accepted!', style: kTextBold2(), textAlign: TextAlign.center),
                  SizedBox(height: 8.h),
                  Text(
                    'You have successfully accepted this booking.',
                    style: kTextNormal(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dCtx);
                        AppNavigator.to(AppRoutes.providerRequestDetail, arguments: state.requestId).then((_) {
                          if (context.mounted) {
                            context.read<ProviderDashboardBloc>().add(RefreshDashboardEvent());
                            context.read<ProviderRequestBloc>().add(const RefreshRequests());
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kSuccessColor,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                        elevation: 0,
                      ),
                      child: Text('View Booking', style: kTextBold1(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: _cPageBg,
        appBar: CustomAppBar(
          title: 'Service Requests',
          showBack: widget.showBackButton,
          backgroundColor: kScaffoldColor,
        ),
        body: _Body(scrollCtrl: _scrollCtrl, searchCtrl: _searchCtrl),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Search bar
// ─────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;

  const _SearchBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kScaffoldColor,
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
      child: AppSearchField(
        controller: ctrl,
        hintText: 'Search by booking no, patient name...',
        onChanged: (v) => context.read<ProviderRequestBloc>().add(SearchChanged(query: v)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Filter bar — segmented control
// ─────────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  const _FilterBar();

  static const _tabs = [
    (Icons.inbox_rounded, 'New', 'new_request'),
    (Icons.play_circle_outline, 'Ongoing', 'ongoing'),
    (Icons.history_rounded, 'Past', 'past'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kScaffoldColor,
      padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 8.h),
      child: BlocBuilder<ProviderRequestBloc, ProviderRequestState>(
        builder: (ctx, state) {
          final selected = state.currentStatus;
          return Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(color: kGreyColor2, borderRadius: BorderRadius.circular(14.r)),
            child: Row(
              children: [
                for (final (icon, label, value) in _tabs)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => ctx.read<ProviderRequestBloc>().add(FilterChanged(status: value)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        decoration: BoxDecoration(
                          color: selected == value ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(11.r),
                          boxShadow: selected == value
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              size: 14.sp,
                              color: selected == value ? kPrimaryColor : Colors.grey.shade500,
                            ),
                            SizedBox(width: 5.w),
                            Text(
                              label,
                              style: selected == value
                                  ? kTextSemiBold0(color: kPrimaryColor)
                                  : kTextNormal0(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Body — list / states
// ─────────────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  final ScrollController scrollCtrl;
  final TextEditingController searchCtrl;

  const _Body({required this.scrollCtrl, required this.searchCtrl});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: kPrimaryColor,
      onRefresh: () async {
        final bloc = context.read<ProviderRequestBloc>();
        bloc.add(const RefreshRequests());
        await bloc.stream.firstWhere((s) => s is ProviderRequestLoaded || s is ProviderRequestError);
      },
      child: BlocBuilder<ProviderRequestBloc, ProviderRequestState>(
        buildWhen: (_, curr) => curr is! ProviderRequestActionSuccess,
        builder: (ctx, state) => NotificationListener<ScrollNotification>(
          onNotification: (info) {
            if (info.metrics.pixels > info.metrics.maxScrollExtent - 200) {
              ctx.read<ProviderRequestBloc>().add(const LoadMoreRequests());
            }
            return false;
          },
          child: CustomScrollView(
            controller: scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _SearchBar(ctrl: searchCtrl)),
              const SliverToBoxAdapter(child: _FilterBar()),
              _contentSliver(ctx, state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contentSliver(BuildContext ctx, ProviderRequestState state) {
    if (state is ProviderRequestInitial || state is ProviderRequestLoading) {
      return const SliverFillRemaining(child: _RequestsShimmer());
    }
    if (state is ProviderRequestError) {
      return SliverFillRemaining(child: _ErrorView(message: state.message));
    }
    if (state is ProviderRequestLoaded) {
      if (state.requests.isEmpty) {
        return SliverFillRemaining(hasScrollBody: false, child: _EmptyView(status: state.currentStatus));
      }
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 40.h),
        sliver: SliverList.builder(
          itemCount: state.requests.length + (state.isLoadingMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == state.requests.length) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: const Center(child: CircularProgressIndicator()),
              );
            }
            return _RequestCard(request: state.requests[i], isNewTab: state.currentStatus == 'new_request');
          },
        ),
      );
    }
    return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
  }
}

// ─────────────────────────────────────────────────────────────────
// Request card — premium operational design
// ─────────────────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final ProviderServiceRequestModel r;
  final bool isNewTab;

  const _RequestCard({required ProviderServiceRequestModel request, required this.isNewTab}) : r = request;

  bool get _isEmergency => r.isEmergency == 1;

  RequestStatus get _status => RequestStatus.fromString(r.requestStatus);

  bool get _isActive => _status.isActive;

  bool get _isNew => isNewTab;

  bool get _isLong => (r.durationDays ?? 0) > 1;

  Color get _accent {
    if (_isEmergency) return RequestStatus.cancelled.color;
    if (_isActive) return _status.color;
    return kPrimaryColor;
  }

  Color get _bgTint {
    if (_isEmergency) return _cEmergencyBg;
    if (_isActive) return _cActiveBg;
    return Colors.white;
  }

  // Provider-specific sub_blocks: filter by provider ID + only active statuses (assigned/in_progress)
  List<SubBlock> get _providerBlocks {
    final activeStatuses = {SubBlockStatus.assigned, SubBlockStatus.inProgress};
    if (r.bookings.isEmpty) {
      return r.subBlocks.where((b) => activeStatuses.contains(b.blockStatus)).toList()
        ..sort((a, b) => (a.parsedDate ?? DateTime(0)).compareTo(b.parsedDate ?? DateTime(0)));
    }
    final myId = locator<LocalStorageService>().serviceProvideUserId;
    final filtered = r.subBlocks
        .where((b) => b.serviceProviderId == myId && activeStatuses.contains(b.blockStatus))
        .toList();
    if (filtered.isEmpty) return [];
    return filtered..sort((a, b) => (a.parsedDate ?? DateTime(0)).compareTo(b.parsedDate ?? DateTime(0)));
  }

  // Next session on or after today
  SubBlock? get _nextBlock {
    final today = DateTime.now();
    final cut = DateTime(today.year, today.month, today.day);
    final blocks = _providerBlocks;
    try {
      return blocks.firstWhere(
        (b) => (b.parsedDate ?? DateTime(0)).isAfter(cut.subtract(const Duration(days: 1))),
      );
    } catch (_) {
      return blocks.isNotEmpty ? blocks.last : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final providerBlocks = _providerBlocks;
    final nextBlock = _nextBlock;

    return GestureDetector(
      onTap: () async {
        await AppNavigator.to(AppRoutes.providerRequestDetail, arguments: r.id);
        if (context.mounted) {
          context.read<ProviderDashboardBloc>().add(RefreshDashboardEvent());
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: _bgTint,
          borderRadius: BorderRadius.circular(16.r),
          border: Border(
            right: BorderSide(color: kBorderColor),
            top: BorderSide(color: kBorderColor),
            bottom: BorderSide(color: kBorderColor),
          ),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: (_isEmergency || _isActive) ? 0.10 : 0.05),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: AppPadding.m,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ServiceRow(r: r, accent: _accent),
              kSizedBox(height: 10),
              _ScheduleRow(r: r, isLong: _isLong, nextBlock: nextBlock, sessionCount: providerBlocks.length),
              kSizedBox(height: 10),
              _MetaRow(r: r, nextBlock: nextBlock),
              if (_isNew) ...[
                kSizedBox(height: 12),
                _AcceptDeclineActions(request: r),
              ] else if (_isActive) ...[
                kSizedBox(height: 12),
                _ActiveAction(r: r, nextBlock: nextBlock),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Service + badges row ─────────────────────────────────────────
class _ServiceRow extends StatelessWidget {
  final ProviderServiceRequestModel r;
  final Color accent;

  const _ServiceRow({required this.r, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon
        Container(
          width: 44.w,
          height: 44.w,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: r.categoryIconUrl != null && r.categoryIconUrl!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: Container(
                    color: kAccentColor.withValues(alpha: 0.15),
                    child: AppCachedImage(
                      imageUrl: r.categoryIconUrl!,
                      width: 44.w,
                      height: 44.w,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              : Icon(Icons.medical_services_rounded, color: accent, size: 22.sp),
        ),
        kSizedBox(width: 12),
        // Name + booking number
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.serviceCategoryName, style: kTextSemiBold1(), maxLines: 1, overflow: TextOverflow.ellipsis),
              kSizedBox(height: 3),
              Text(r.requestNumber, style: kTextNormal0(color: kTextSecondaryColor)),
            ],
          ),
        ),
        kSizedBox(width: 4),
        // Status + emergency badges
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _StatusBadge(request: r),
            if (r.isEmergency == 1) ...[kSizedBox(height: 4), _EmergencyTag()],
          ],
        ),
      ],
    );
  }
}

// ── Schedule row ─────────────────────────────────────────────────
class _ScheduleRow extends StatelessWidget {
  final ProviderServiceRequestModel r;
  final bool isLong;
  final SubBlock? nextBlock;
  final int sessionCount;

  const _ScheduleRow({required this.r, required this.isLong, this.nextBlock, this.sessionCount = 0});

  String _sessionLabel() {
    if (nextBlock == null) return '—';
    final today = DateTime.now();
    final d = nextBlock!.parsedDate;
    if (d != null && d.year == today.year && d.month == today.month && d.day == today.day) {
      return 'Today  •  ${AppDateFormatter.timeFromApi(nextBlock!.scheduledStartTime)}';
    }
    final dateStr = AppDateFormatter.dayMonthShort(nextBlock!.scheduledDate);
    final time = AppDateFormatter.timeFromApi(nextBlock!.scheduledStartTime);
    return time.isNotEmpty ? '$dateStr  •  $time' : dateStr;
  }

  @override
  Widget build(BuildContext context) {
    final hasNextBlock = nextBlock != null;
    final label = hasNextBlock
        ? _sessionLabel()
        : () {
            final time = AppDateFormatter.timeFromApi(r.startTime ?? '');
            final dateStr = AppDateFormatter.dateFromApi(r.startDate ?? '');
            return time.isNotEmpty ? '$dateStr  •  $time' : dateStr;
          }();

    final assignedDays = r.subBlocks.where((b) => b.bookingId != null).map((b) => b.scheduledDate).toSet().length;

    final myId = locator<LocalStorageService>().serviceProvideUserId;
    final partnerBlocksCount = myId != null ? r.subBlocks.where((b) => b.serviceProviderId == myId).length : 0;

    final countLabel = partnerBlocksCount > 0
        ? '$partnerBlocksCount Session${partnerBlocksCount == 1 ? '' : 's'}'
        : assignedDays > 0
        ? '$assignedDays Day${assignedDays == 1 ? '' : 's'}'
        : sessionCount > 1
        ? '$sessionCount Sessions'
        : isLong
        ? '${r.durationDays} Days'
        : null;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: kBorderColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(
            hasNextBlock ? Icons.event_rounded : Icons.calendar_today_rounded,
            size: 14.sp,
            color: kPrimaryColor,
          ),
          kSizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasNextBlock)
                  Text(
                    'Upcoming',
                    style: kTextNormal0(color: kPrimaryColor).copyWith(fontSize: 9.sp, letterSpacing: 0.3),
                  ),
                Text(
                  label,
                  style: kTextSemiBold0(color: kTextPrimaryColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (countLabel != null || r.shiftType != null) ...[
            Container(width: 1, height: 24.h, color: kBorderColor),
            kSizedBox(width: 10),
            if (countLabel != null) ...[
              Icon(Icons.date_range_rounded, size: 13.sp, color: kPrimaryColor),
              kSizedBox(width: 4),
              Text(countLabel, style: kTextSemiBold0(color: kTextPrimaryColor)),
            ] else ...[
              Icon(Icons.wb_sunny_outlined, size: 13.sp, color: kPrimaryColor),
              kSizedBox(width: 4),
              Text(r.formattedShiftType, style: kTextSemiBold0(color: kTextPrimaryColor)),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Customer + distance meta row ─────────────────────────────────
class _MetaRow extends StatelessWidget {
  final ProviderServiceRequestModel r;
  final SubBlock? nextBlock;

  const _MetaRow({required this.r, this.nextBlock});

  bool get _showCall {
    // final phone = r.customerPhone ?? '';
    final phone = AppConstants.partnerCustomerPhone;
    if (phone.isEmpty) return false;
    final sessionTime = nextBlock?.scheduledStartDateTime;
    if (sessionTime == null) return false;
    final minsUntil = sessionTime.difference(DateTime.now()).inMinutes;
    final notCompleted = nextBlock!.blockStatus != SubBlockStatus.completed;
    // Show from 30 min before session until session is completed
    return minsUntil <= 30 && notCompleted;
  }

  @override
  Widget build(BuildContext context) {
    final patientName = r.familyMember?.fullName ?? r.customerName;

    return Row(
      children: [
        if (patientName.isNotEmpty) ...[
          Icon(Icons.person_rounded, size: 14.sp, color: kTextSecondaryColor),
          kSizedBox(width: 4),
          Flexible(
            child: Text(
              patientName,
              style: kTextSemiBold0(color: kTextPrimaryColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_showCall) ...[
            kSizedBox(width: 6),
            GestureDetector(
              // onTap: () => LaunchUrlService.makePhoneCall(r.customerPhone!),
              onTap: () => LaunchUrlService.makePhoneCall(AppConstants.partnerCustomerPhone),
              child: Container(
                padding: EdgeInsets.all(5.w),
                decoration: BoxDecoration(color: kSuccessColor.withValues(alpha: 0.10), shape: BoxShape.circle),
                child: Icon(Icons.call_rounded, size: 11.sp, color: kSuccessColor),
              ),
            ),
          ],
        ],
        const Spacer(),
        if (r.distanceKm > 0) ...[
          Icon(Icons.near_me_rounded, size: 13.sp, color: kTextSecondaryColor),
          kSizedBox(width: 4),
          Text('${r.distanceKm.toStringAsFixed(1)} km', style: kTextNormal0(color: kTextSecondaryColor)),
        ],
      ],
    );
  }
}

// ── Accept / Decline actions ─────────────────────────────────────
class _AcceptDeclineActions extends StatelessWidget {
  final ProviderServiceRequestModel request;

  const _AcceptDeclineActions({required this.request});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CustomButton(
            onPressed: () => context.read<ProviderRequestBloc>().add(
              RespondToRequest(requestId: request.id, action: 'rejected'),
            ),
            title: 'Decline',
            iconData: Icons.close_rounded,
            iconSize: 18.sp,
            height: 46.h,
            backgroundColor: const Color(0xFFFFF1F2),
            textStyle: kTextSemiBold(color: kErrorColor),
            iconColor: kErrorColor,
            borderSide: const BorderSide(color: Color(0xFFFECACA)),
            borderRadius: BorderRadius.circular(10.r),
            shadowColor: kErrorColor.withValues(alpha: 0.08),
          ),
        ),
        kSizedBox(width: 10),
        Expanded(
          child: CustomButton(
            onPressed: () {
              if (request.subBlocks.isNotEmpty) {
                void onAccept(List<int> ids) => context.read<ProviderRequestBloc>().add(
                  RespondToRequest(requestId: request.id, action: 'accepted', subBlockIds: ids),
                );
                if (request.isFullDayShift) {
                  FullDayBookingSheet.show(context: context, request: request, onAccept: onAccept);
                } else {
                  RequestScheduleBottomSheet.show(context: context, request: request, onAccept: onAccept);
                }
              } else {
                context.read<ProviderRequestBloc>().add(
                  RespondToRequest(requestId: request.id, action: 'accepted'),
                );
              }
            },
            title: 'Accept',
            iconData: Icons.check_circle_rounded,
            iconSize: 18.sp,
            height: 46.h,
            backgroundColor: kSuccessColor.withValues(alpha: 0.12),
            textStyle: kTextSemiBold(color: kSuccessColor),
            iconColor: kSuccessColor,
            borderRadius: BorderRadius.circular(10.r),
            shadowColor: Colors.transparent,
          ),
        ),
      ],
    );
  }
}

// ── Active job CTA ────────────────────────────────────────────────
class _ActiveAction extends StatelessWidget {
  final ProviderServiceRequestModel r;
  final SubBlock? nextBlock;

  static const _orange = Color(0xFFD97706);
  static const _purple = Color(0xFF7C3AED);

  const _ActiveAction({required this.r, this.nextBlock});

  @override
  Widget build(BuildContext context) {
    final blockStatus = nextBlock?.blockStatus;
    final readyToStart = nextBlock?.isReadyToStart() ?? false;

    final bool showStart = blockStatus == SubBlockStatus.assigned && readyToStart;
    final bool showComplete = blockStatus == SubBlockStatus.inProgress;

    if (!showStart && !showComplete) return const SizedBox.shrink();

    final color = showComplete ? _purple : _orange;
    final label = showComplete ? 'Complete Service' : 'Start Service';
    final icon = showComplete ? Icons.task_alt_rounded : Icons.play_circle_rounded;

    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () async {
          await AppNavigator.to(AppRoutes.providerRequestDetail, arguments: r.id);
          if (context.mounted) {
            context.read<ProviderDashboardBloc>().add(RefreshDashboardEvent());
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10.r),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16.sp),
              kSizedBox(width: 7),
              Text(label, style: kTextSemiBold0(color: Colors.white)),
              kSizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, color: Colors.white.withValues(alpha: 0.70), size: 14.sp),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Status badge
// ─────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final ProviderServiceRequestModel request;

  const _StatusBadge({required this.request});

  String get _rawStatus =>
      request.bookings.isNotEmpty ? request.bookings.first.bookingStatus : request.requestStatus;

  RequestStatus get _status => RequestStatus.fromString(_rawStatus);

  bool get _isExpired => _status == RequestStatus.standby && !locator<LocalStorageService>().providerIsStandby;

  // Mirror the detail page: a searching (or partially-accepted) request with no
  // bookings yet is a fresh "New Request" — show that instead of "Searching".
  bool get _isNewRequest =>
      request.bookings.isEmpty && (_status == RequestStatus.searching || _status.isPartiallyAccepted);

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (_isExpired) {
      color = const Color(0xFFDC2626);
      label = 'Expired';
    } else if (_isNewRequest) {
      color = const Color(0xFF2563EB);
      label = 'New Request';
    } else {
      color = _status.color;
      label = _status.label;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(6.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          kSizedBox(width: 5),
          Text(label, style: kTextSemiBold0(color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Emergency tag
// ─────────────────────────────────────────────────────────────────
class _EmergencyTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
      decoration: BoxDecoration(color: RequestStatus.cancelled.color, borderRadius: BorderRadius.circular(5.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emergency_rounded, size: 10.sp, color: Colors.white),
          kSizedBox(width: 3),
          Text(
            'Emergency',
            style: kTextNormal0(color: Colors.white).copyWith(fontSize: 10.sp),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Shimmer
// ─────────────────────────────────────────────────────────────────
class _RequestsShimmer extends StatelessWidget {
  const _RequestsShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 32.h),
      itemCount: 5,
      itemBuilder: (_, i) => Padding(
        padding: EdgeInsets.only(bottom: 10.h),
        child: ShimmerBox(height: 165.h, borderRadius: 16),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final String status;

  const _EmptyView({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (status) {
      'new_request' => (Icons.inbox_rounded, 'No New Requests', 'New booking requests will appear here'),
      'ongoing' => (Icons.work_off_outlined, 'No Active Jobs', 'Accepted bookings will show here'),
      'past' => (Icons.history_rounded, 'No Past Jobs', 'Completed and cancelled jobs appear here'),
      _ => (Icons.assignment_outlined, 'No Requests', 'Nothing to show here'),
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 82.w,
            height: 82.w,
            decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.07), shape: BoxShape.circle),
            child: Icon(icon, size: 36.sp, color: kPrimaryColor.withValues(alpha: 0.4)),
          ),
          kSizedBox(height: 20),
          Text(title, style: kTextBold1()),
          kSizedBox(height: 6),
          Text(
            subtitle,
            style: kTextNormal(color: kTextSecondaryColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, color: kErrorColor.withValues(alpha: 0.5), size: 48.sp),
              kSizedBox(height: 16),
              Text('Could not load requests', style: kTextBold1()),
              kSizedBox(height: 8),
              Text(
                message,
                style: kTextNormal0(color: kTextSecondaryColor),
                textAlign: TextAlign.center,
              ),
              kSizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.read<ProviderRequestBloc>().add(const RefreshRequests()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
