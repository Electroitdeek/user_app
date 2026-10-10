import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/services/file_downloading_service.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/shimmer/provider_shimmers.dart';
import '../../earnings/bloc/earnings_bloc.dart';
import '../../earnings/model/payout_model.dart';
import '../../earnings/repository/earnings_repository.dart';

class ProviderEarningsPage extends StatelessWidget {
  final bool showBackButton;
  const ProviderEarningsPage({super.key, this.showBackButton = true});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        EarningsBloc(EarningsRepository(locator<ApiClient>()))
          ..add(EarningsLoad()),
    child: _EarningsView(showBackButton: showBackButton),
  );
}

// ════════════════════════════════════════════════════════════════
// Main view
// ════════════════════════════════════════════════════════════════
class _EarningsView extends StatefulWidget {
  final bool showBackButton;
  const _EarningsView({required this.showBackButton});
  @override
  State<_EarningsView> createState() => _EarningsViewState();
}

class _EarningsViewState extends State<_EarningsView> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 250) {
      context.read<EarningsBloc>().add(EarningsLoadMore());
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScaffoldColor,
      appBar: CustomAppBar(
        title: "Earnings",
        showBack: widget.showBackButton,
        backgroundColor: kScaffoldColor,
      ),
      body: SafeArea(
        top: false,
        child: BlocBuilder<EarningsBloc, EarningsState>(
          builder: (context, state) {
            // First load skeleton
            if (state.status == EarningsStatus.loading &&
                state.payouts.isEmpty) {
              return const EarningsListShimmer();
            }
            // Error with nothing loaded
            if (state.status == EarningsStatus.error && state.payouts.isEmpty) {
              return _ErrorView(
                message: state.errorMessage ?? 'Something went wrong',
                onRetry: () => context.read<EarningsBloc>().add(EarningsLoad()),
              );
            }

            return RefreshIndicator(
              color: kPrimaryColor,
              displacement: 20,
              onRefresh: () async =>
                  context.read<EarningsBloc>().add(EarningsRefresh()),
              child: CustomScrollView(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // 1. Summary Banner at the top of the scroll list
                  SliverToBoxAdapter(
                    child: _SearchBar(
                      searchCtrl: _searchCtrl,
                      showBackButton: widget.showBackButton,
                    ),
                  ),
                  SliverToBoxAdapter(child: _SummaryBanner(state: state)),

                  // 2. Filter Chips sticky header pinned at the top
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyFilterChipsDelegate(
                      child: _FilterChipsRow(filters: state.filters),
                    ),
                  ),

                  // 3. Body content (either the Empty View or the Payout Card List)
                  if (state.payouts.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyView(),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 16.h),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((ctx, i) {
                          if (i < state.payouts.length) {
                            return _PayoutCard(
                              payout: state.payouts[i],
                              onTap: () => _showDetail(ctx, state.payouts[i]),
                            );
                          }
                          // Load-more spinner / end-of-list
                          if (state.isLoadingMore) {
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 18.h),
                              child: Center(
                                child: SizedBox(
                                  width: 22.w,
                                  height: 22.w,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: kPrimaryColor,
                                  ),
                                ),
                              ),
                            );
                          }
                          if (!state.hasMore) {
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 20.h),
                              child: Center(
                                child: Text(
                                  'All payouts loaded',
                                  style: kTextNormal0(color: kTextHintColor),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }, childCount: state.payouts.length + 1),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showDetail(BuildContext ctx, PayoutModel payout) {
    showModalBottomSheet(
      context: ctx,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PayoutDetailSheet(payout: payout),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// AppBar — search + sort + clear-filter
// ─────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController searchCtrl;
  final bool showBackButton;
  const _SearchBar({required this.searchCtrl, required this.showBackButton});

  @override
  Size get preferredSize => Size.fromHeight(118.h);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kScaffoldColor,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(14.w, 6.h, 14.w, 10.h),
            child: Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    controller: searchCtrl,
                    onChanged: (v) => context.read<EarningsBloc>().add(
                      EarningsSearchChanged(v),
                    ),
                    hintText: 'Search payout number, booking…',
                  ),
                ),
                BlocBuilder<EarningsBloc, EarningsState>(
                  builder: (ctx, state) => IconButton(
                    icon: Icon(
                      Icons.swap_vert_rounded,
                      color: kPrimaryColor,
                      size: 24.sp,
                    ),
                    tooltip: 'Sort',
                    onPressed: () => _showSortSheet(ctx, state.filters),
                  ),
                ),
                // Clear-filter button
                BlocBuilder<EarningsBloc, EarningsState>(
                  builder: (ctx, state) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: state.filters.isFiltered
                        ? IconButton(
                            key: const ValueKey('clear'),
                            icon: Icon(
                              Icons.filter_alt_off_rounded,
                              color: kErrorColor,
                              size: 22.sp,
                            ),
                            tooltip: 'Clear Filters',
                            onPressed: () {
                              searchCtrl.clear();
                              ctx.read<EarningsBloc>().add(
                                EarningsResetFilters(),
                              );
                            },
                          )
                        : SizedBox(key: const ValueKey('none'), width: 0),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSortSheet(BuildContext ctx, EarningFilters filters) {
    showModalBottomSheet(
      context: ctx,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: ctx.read<EarningsBloc>(),
        child: _SortSheet(filters: filters),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Status filter chips
// ─────────────────────────────────────────────────────────────────
class _FilterChipsRow extends StatelessWidget {
  final EarningFilters filters;
  const _FilterChipsRow({required this.filters});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: kScaffoldColor,
    padding: EdgeInsets.fromLTRB(12.w, 2.h, 12.w, 10.h),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(
          children: PayoutStatusFilter.values.map((s) {
            final isActive = filters.status == s;
            final color = _color(s.value);
            return GestureDetector(
              onTap: () => context.read<EarningsBloc>().add(
                EarningsStatusFilterChanged(s),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.only(right: 8.w),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: isActive
                      ? color.withValues(alpha: 0.1)
                      : kScaffoldColor,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: isActive
                        ? color.withValues(alpha: 0.5)
                        : kBorderColor,
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  s.label,
                  style: isActive
                      ? kTextSemiBold0(color: color)
                      : kTextNormal0(color: kTextSecondaryColor),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ),
  );

  Color _color(String s) => switch (s) {
    'completed' => kSuccessColor,
    'pending' => kWarningColor,
    'processing' => kInfoColor,
    'failed' => kErrorColor,
    'cancelled' => kTextSecondaryColor,
    _ => kPrimaryColor,
  };
}

class _StickyFilterChipsDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _StickyFilterChipsDelegate({required this.child});

  @override
  double get minExtent => 48.h;

  @override
  double get maxExtent => 48.h;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: 48.h,
      child: Container(color: Colors.white, child: child),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyFilterChipsDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}

// ─────────────────────────────────────────────────────────────────
// Summary banner — gig-economy income dashboard header
// ─────────────────────────────────────────────────────────────────
class _SummaryBanner extends StatelessWidget {
  final EarningsState state;
  const _SummaryBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final summary = state.summary;
    final totalAmount = summary.totalAmount;
    final pendingAmount = summary.pendingAmount;
    final completedAmount = summary.completedAmount;
    final count = summary.totalPayouts;
    final pendingPayouts = summary.pendingPayouts;
    final completedPayouts = summary.completedPayouts;

    return Container(
      margin: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 6.h),
      padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 18.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2D54), Color(0xFF1B4E8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero amount
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Earnings',
                      style: kTextNormal0(
                        color: Colors.white.withValues(alpha: 0.65),
                      ).copyWith(fontSize: 12.sp),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      NumberUtils.formatCurrency(totalAmount),
                      style: kTextBold3(
                        color: Colors.white,
                      ).copyWith(fontSize: 32.sp),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  '$count payout${count == 1 ? '' : 's'}',
                  style: kTextSemiBold0(
                    color: Colors.white,
                  ).copyWith(fontSize: 11.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Pending / Settled pills
          Row(
            children: [
              _HeaderPill(
                icon: Icons.access_time_rounded,
                label: 'Pending',
                value: NumberUtils.formatCurrency(pendingAmount),
                color: const Color(0xFFFFAB00),
              ),
              SizedBox(width: 8.w),
              _HeaderPill(
                icon: Icons.check_circle_outline_rounded,
                label: 'Settled',
                value: NumberUtils.formatCurrency(completedAmount),
                color: const Color(0xFF4CAF50),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Divider
          Container(height: 1, color: Colors.white.withValues(alpha: 0.12)),
          SizedBox(height: 14.h),

          // Bottom stats
          Row(
            children: [
              _MiniStat('Payouts', '$count'),
              _vline(),
              _MiniStat('Pending', '$pendingPayouts'),
              _vline(),
              _MiniStat('Settled', '$completedPayouts'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vline() => Container(
    width: 1,
    height: 28.h,
    margin: EdgeInsets.symmetric(horizontal: 12.w),
    color: Colors.white.withValues(alpha: 0.2),
  );
}

class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _HeaderPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13.sp, color: color),
          SizedBox(width: 6.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: kTextNormal0(
                    color: Colors.white.withValues(alpha: 0.65),
                  ).copyWith(fontSize: 10.sp),
                ),
                Text(
                  value,
                  style: kTextSemiBold1(
                    color: Colors.white,
                  ).copyWith(fontSize: 13.sp),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: kTextNormal0(
            color: Colors.white.withValues(alpha: 0.55),
          ).copyWith(fontSize: 10.sp),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: kTextSemiBold(color: Colors.white).copyWith(fontSize: 12.sp),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
// Payout card
// ─────────────────────────────────────────────────────────────────
class _PayoutCard extends StatelessWidget {
  final PayoutModel payout;
  final VoidCallback onTap;
  const _PayoutCard({required this.payout, required this.onTap});

  static const _greyText = Color(0xFF6B7280);

  String get _formattedDate {
    try {
      return DateFormat('d MMM yyyy').format(DateTime.parse(payout.createdAt));
    } catch (_) {
      return payout.createdAt;
    }
  }

  IconData get _methodIcon => switch (payout.payoutMethod) {
    'bank_transfer' => Icons.account_balance_outlined,
    'upi' => Icons.phone_android_rounded,
    'cash' => Icons.payments_outlined,
    _ => Icons.account_balance_wallet_outlined,
  };

  String get _methodLabel => switch (payout.payoutMethod) {
    'bank_transfer' => 'Bank Transfer',
    'upi' => 'UPI',
    'cash' => 'Cash',
    _ => 'Wallet',
  };

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header: payout number + status + date ──
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 12.w, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payout.payoutNumber,
                        style: kTextSemiBold(
                          color: kPrimaryColor,
                        ).copyWith(fontSize: 13.sp),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 3.h),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 10.sp,
                            color: _greyText,
                          ),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Text(
                              '$_formattedDate  ·  ${payout.bookingNumber ?? 'Booking #${payout.bookingId}'}',
                              style: kTextNormal0(
                                color: _greyText,
                              ).copyWith(fontSize: 11.sp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                _StatusPill(
                  status: payout.payoutStatus == 'manual_completed'
                      ? 'completed'
                      : payout.payoutStatus,
                  label: payout.payoutStatus == 'manual_completed'
                      ? 'Completed'
                      : payout.payoutStatusText,
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),

          // ── Earnings hero card ──
          Container(
            margin: EdgeInsets.symmetric(horizontal: 12.w),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: kSuccessColor.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: kSuccessColor.withValues(alpha: 0.14)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 18.sp,
                  color: kSuccessColor.withValues(alpha: 0.7),
                ),
                SizedBox(width: 10.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Earnings',
                      style: kTextNormal0(
                        color: _greyText,
                      ).copyWith(fontSize: 11.sp),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      NumberUtils.formatCurrency(payout.netAmount),
                      style: kTextBold2(
                        color: kSuccessColor,
                      ).copyWith(fontSize: 22.sp),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),

          // ── Footer: method + details ──
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Payout method shown only for completed payouts.
                      if (payout.payoutStatus == 'completed' ||
                          payout.payoutStatus == 'manual_completed')
                        Flexible(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 5.h,
                          ),
                          decoration: BoxDecoration(
                            color: kPrimaryColor.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _methodIcon,
                                size: 11.sp,
                                color: kPrimaryColor,
                              ),
                              SizedBox(width: 4.w),
                              Flexible(
                                child: Text(
                                  _methodLabel,
                                  style: kTextNormal0(
                                    color: kPrimaryColor,
                                  ).copyWith(fontSize: 11.sp),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (payout.settlementReceiptUrl != null &&
                          payout.settlementReceiptUrl!.isNotEmpty) ...[
                        SizedBox(width: 6.w),
                        Flexible(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 5.h,
                            ),
                            decoration: BoxDecoration(
                              color: kSuccessColor.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.receipt_rounded,
                                  size: 11.sp,
                                  color: kSuccessColor,
                                ),
                                SizedBox(width: 4.w),
                                Flexible(
                                  child: Text(
                                    'Receipt',
                                    style: kTextNormal0(
                                      color: kSuccessColor,
                                    ).copyWith(fontSize: 11.sp),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  'View Details',
                  style: kTextSemiBold0(
                    color: kPrimaryColor,
                  ).copyWith(fontSize: 12.sp),
                ),
                SizedBox(width: 2.w),
                Icon(
                  Icons.chevron_right_rounded,
                  color: kPrimaryColor,
                  size: 16.sp,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  final String status, label;
  const _StatusPill({required this.status, required this.label});

  Color get _color => switch (status) {
    'completed' || 'manual_completed' => kSuccessColor,
    'pending' => kWarningColor,
    'processing' => kInfoColor,
    'failed' => kErrorColor,
    _ => kTextSecondaryColor,
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
    decoration: BoxDecoration(
      color: _color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20.r),
      border: Border.all(color: _color.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5.w,
          height: 5.w,
          decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
        ),
        SizedBox(width: 4.w),
        Text(label, style: kTextSemiBold0(color: _color)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
// Sort sheet
// ─────────────────────────────────────────────────────────────────
class _SortSheet extends StatelessWidget {
  final EarningFilters filters;
  const _SortSheet({required this.filters});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 16.h),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: kBorderColor,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 16.h),
          Text('Sort & Order', style: kTextBold1()),
          SizedBox(height: 6.h),
          Text('Sort Field', style: kTextSemiBold0(color: kTextSecondaryColor)),
          SizedBox(height: 8.h),
          ...EarningSortField.values.map(
            (f) => _SortOption(
              label: f.label,
              selected: filters.sortField == f,
              onTap: () {
                context.read<EarningsBloc>().add(
                  EarningsSortChanged(f, filters.sortDirection),
                );
                Navigator.pop(context);
              },
            ),
          ),
          Divider(color: kDividerColor, height: 20.h),
          Text('Direction', style: kTextSemiBold0(color: kTextSecondaryColor)),
          SizedBox(height: 8.h),
          ...EarningSortDirection.values.map(
            (d) => _SortOption(
              label: d.label,
              icon: d == EarningSortDirection.desc
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              selected: filters.sortDirection == d,
              onTap: () {
                context.read<EarningsBloc>().add(
                  EarningsSortChanged(filters.sortField, d),
                );
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _SortOption extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const _SortOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
        margin: EdgeInsets.only(bottom: 4.h),
        decoration: BoxDecoration(
          color: selected
              ? kPrimaryColor.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: selected
                ? kPrimaryColor.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16.sp,
                color: selected ? kPrimaryColor : kTextSecondaryColor,
              ),
              SizedBox(width: 10.w),
            ],
            Text(
              label,
              style: kTextSemiBold(
                color: selected ? kPrimaryColor : kTextPrimaryColor,
              ),
            ),
            const Spacer(),
            if (selected)
              Icon(
                Icons.check_circle_rounded,
                color: kPrimaryColor,
                size: 18.sp,
              ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
// Payout detail bottom sheet
// ─────────────────────────────────────────────────────────────────
class _PayoutDetailSheet extends StatelessWidget {
  final PayoutModel p;
  const _PayoutDetailSheet({required PayoutModel payout}) : p = payout;

  Color get _statusColor => switch (p.payoutStatus) {
    'completed' || 'manual_completed' => kSuccessColor,
    'pending' => kWarningColor,
    'processing' => kInfoColor,
    'failed' => kErrorColor,
    _ => kTextSecondaryColor,
  };

  String _fmt(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      return DateFormat('d MMM yyyy, h:mm a').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  String _method(String m) => switch (m) {
    'bank_transfer' => 'Bank Transfer',
    'upi' => 'UPI',
    'cash' => 'Cash',
    _ => 'Wallet',
  };
  String _settlement(String s) => switch (s) {
    'not_applicable' => 'Not Applicable',
    'pending' => 'Pending',
    'completed' => 'Completed',
    _ => s,
  };

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.78,
    minChildSize: 0.5,
    maxChildSize: 0.94,
    expand: false,
    builder: (_, ctrl) => Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
        children: [
          // Drag handle
          Padding(
            padding: EdgeInsets.only(top: 10.h, bottom: 2.h),
            child: Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: kBorderColor,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          // Sheet header
          Padding(
            padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w, 4.h),
            child: Row(
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: _statusColor,
                    size: 22.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Payout Details', style: kTextBold1()),
                      SizedBox(height: 2.h),
                      Text(
                        p.payoutNumber,
                        style: kTextNormal0(color: kPrimaryColor),
                      ),
                    ],
                  ),
                ),
                _StatusPill(
                  status: p.payoutStatus == 'manual_completed'
                      ? 'completed'
                      : p.payoutStatus,
                  label: p.payoutStatus == 'manual_completed'
                      ? 'Completed'
                      : p.payoutStatusText,
                ),
              ],
            ),
          ),
          Divider(color: kDividerColor, height: 16.h),

          // Scrollable content
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 40.h),
              children: [
                // ── Amount breakdown ─────────────────────────────
                _SheetSection(
                  title: 'Amount Breakdown',
                  children: [
                    _SheetRow(
                      'Net Amount',
                      NumberUtils.formatCurrency(p.netAmount),
                      valueColor: kSuccessColor,
                      bold: true,
                    ),
                  ],
                ),
                SizedBox(height: 14.h),

                // ── Cash info (only if relevant) ─────────────────
                if (p.cashCollected > 0 || p.cashToRemit > 0) ...[
                  _SheetSection(
                    title: 'Cash Handling',
                    children: [
                      _SheetRow(
                        'Cash Collected',
                        NumberUtils.formatCurrency(p.cashCollected),
                      ),
                      _SheetRow(
                        'Cash to Remit',
                        NumberUtils.formatCurrency(p.cashToRemit),
                        valueColor: p.cashToRemit > 0 ? kWarningColor : null,
                      ),
                      _SheetRow(
                        'Settlement Status',
                        _settlement(p.cashSettlementStatus),
                      ),
                      if (p.cashSettlementDueDate != null)
                        _SheetRow('Due Date', _fmt(p.cashSettlementDueDate)),
                    ],
                  ),
                  SizedBox(height: 14.h),
                ],

                // ── Payout info ──────────────────────────────────
                _SheetSection(
                  title: 'Payout Info',
                  children: [
                    if (p.bookingNumber != null && p.bookingNumber!.isNotEmpty)
                      _SheetRow('Booking', p.bookingNumber!),
                    if (p.payoutMethod != 'bank_transfer' ||
                        (p.payoutStatus == 'completed' ||
                            p.payoutStatus == 'manual_completed'))
                      _SheetRow('Method', _method(p.payoutMethod)),

                    if (p.transactionReference != null &&
                        p.transactionReference!.isNotEmpty)
                      _SheetRow('Transaction Ref', p.transactionReference!),
                    if (p.processedAt != null)
                      _SheetRow('Processed At', _fmt(p.processedAt)),
                    _SheetRow('Created', _fmt(p.createdAt)),
                    if (p.payoutStatus == 'pending' &&
                        p.nextSettlementDate != null &&
                        p.nextSettlementDate!.isNotEmpty)
                      _SheetRow('Next Settlement', p.nextSettlementDate!,
                          valueColor: kPrimaryColor),
                  ],
                ),
                SizedBox(height: 14.h),

                if (p.settlementReceiptUrl != null &&
                    p.settlementReceiptUrl!.isNotEmpty) ...[
                  _SheetSection(
                    title: 'Settlement Receipt',
                    children: [
                      kSizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            FileDownloadService().downloadAndViewFile(
                              url: p.settlementReceiptUrl!,
                              originalName: '${p.payoutNumber}_receipt',
                            );
                          },
                          icon: Icon(Icons.visibility_rounded, size: 18.sp),
                          label: const Text('View Receipt'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kPrimaryColor,
                            side: BorderSide(color: kPrimaryColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 11.h),
                          ),
                        ),
                      ),
                      kSizedBox(height: 6),
                    ],
                  ),
                ],

                // ── See booking detail ───────────────────────────
                if (p.bookingId > 0) ...[
                  SizedBox(height: 6.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        AppNavigator.to(
                          AppRoutes.providerRequestDetail,
                          arguments: {'requestId': p.bookingId},
                        );
                      },
                      icon: Icon(Icons.receipt_long_rounded, size: 18.sp),
                      label: const Text('See Booking Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                        padding: EdgeInsets.symmetric(vertical: 13.h),
                        textStyle: kTextSemiBold(color: Colors.white),
                      ),
                    ),
                  ),
                ],

                // ── Need help ─────────────────────────────────────
                SizedBox(height: 10.h),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      AppNavigator.to(AppRoutes.needHelp, arguments: 'Payout ${p.payoutNumber}');
                    },
                    icon: Icon(Icons.headset_mic_outlined, size: 18.sp),
                    label: const Text('Need Help?'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimaryColor,
                      side: BorderSide(color: kPrimaryColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      padding: EdgeInsets.symmetric(vertical: 13.h),
                      textStyle: kTextSemiBold(color: kPrimaryColor),
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
  );
}

class _SheetSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SheetSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title.toUpperCase(),
        style: appTextStyle(
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w700,
          color: kTextSecondaryColor,
        ),
      ),
      SizedBox(height: 6.h),
      Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: kBorderColor),
        ),
        child: Column(children: children),
      ),
    ],
  );
}

class _SheetRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final bool bold;
  const _SheetRow(this.label, this.value, {this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 6.h),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: kTextNormal(color: kTextSecondaryColor)),

        Flexible(
          child: Text(
            value,
            style: bold
                ? kTextBold(color: valueColor ?? kTextPrimaryColor)
                : kTextSemiBold(color: valueColor ?? kTextPrimaryColor),
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
// Empty / Error views
// ─────────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90.w,
              height: 90.w,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kSuccessColor.withValues(alpha: 0.12),
                    kPrimaryColor.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 38.sp,
                color: kSuccessColor.withValues(alpha: 0.5),
              ),
            ),
            SizedBox(height: 24.h),
            Text('Start Earning Today', style: kTextBold2()),
            SizedBox(height: 10.h),
            Text(
              'Complete your first booking to start\nbuilding your earnings dashboard.',
              style: kTextNormal(
                color: kTextSecondaryColor,
              ).copyWith(height: 1.6),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(28.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 48.sp,
            color: kErrorColor.withValues(alpha: 0.4),
          ),
          SizedBox(height: 16.h),
          Text('Failed to load', style: kTextBold1()),
          SizedBox(height: 8.h),
          Text(
            message,
            style: kTextNormal(color: kTextSecondaryColor),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
