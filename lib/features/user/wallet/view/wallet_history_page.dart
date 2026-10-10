import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/features/auth/login/bloc/auth_bloc.dart';
import 'package:adhisaat_health_care/features/user/wallet/bloc/wallet_bloc.dart';
import 'package:adhisaat_health_care/features/user/wallet/bloc/wallet_state.dart';
import 'package:adhisaat_health_care/features/user/wallet/view/transaction_detail_bottom_sheet.dart';
import 'package:adhisaat_health_care/shared/widgets/shimmer/user_shimmers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/screen_dimensions.dart';
import '../../../../shared/widgets/common/app_bar_custom.dart';
import '../../../../shared/widgets/common/custom_refresh_indicator.dart';

class WalletHistoryPage extends StatefulWidget {
  const WalletHistoryPage({super.key});

  @override
  State<WalletHistoryPage> createState() => _WalletHistoryPageState();
}

class _WalletHistoryPageState extends State<WalletHistoryPage> {
  @override
  void initState() {
    super.initState();
    // Refresh profile to get latest wallet balance and bonus points
    context.read<AuthBloc>().add(RefreshProfile());
    // Also ensure transactions are fetched (though usually handled by route provider)
    context.read<WalletBloc>().add(const FetchWalletTransactionsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhiteColor,
      appBar: CustomAppBar(title: 'Wallet'),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            final user = state.user;
            final walletState = context.watch<WalletBloc>().state;

            double walletBalance = double.tryParse(user.walletAmount?.toString() ?? '0') ?? 0;
            double bonusBalance = double.tryParse(user.bonusWalletAmount?.toString() ?? '0') ?? 0;

            if (walletState is WalletTransactionsLoaded) {
              walletBalance = walletState.walletAmount.toDouble();
              bonusBalance = walletState.bonusWalletAmount.toDouble();
            }

            if (walletState is WalletTransactionsLoading || walletState is WalletInitial) {
              return const WalletShimmer();
            }
            final totalBalance = walletBalance + bonusBalance;
            return CustomRefreshIndicator(
              onRefresh: () async {
                context.read<AuthBloc>().add(RefreshProfile());
                context.read<WalletBloc>().add(const FetchWalletTransactionsEvent());
                await Future.delayed(const Duration(milliseconds: 800));
              },
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: AppPadding.symmetric(h: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSpacing.mVertical,

                      // ── Available Balance (Premium Design) ──
                      Center(
                        child: Container(
                          width: double.infinity,
                          padding: AppPadding.symmetric(v: 25),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [kPrimaryColor.withValues(alpha: 0.05), kPrimaryColor.withValues(alpha: 0.02)],
                            ),
                            borderRadius: AppRadius.l,
                            border: Border.all(color: kPrimaryColor.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: AppPadding.all(6),
                                    decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                                    child: Icon(Icons.account_balance_wallet_rounded, color: kPrimaryColor, size: 16.sp),
                                  ),
                                  AppSpacing.sHorizontal,
                                  Text(
                                    'Available Balance',
                                    style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 14.sp, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              AppSpacing.sVertical,
                              Text(
                                NumberUtils.formatCurrency(totalBalance, decimalDigits: 2),
                                style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 34.sp, letterSpacing: -1.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AppSpacing.lVertical,

                      // ── Cash & Bonus Cards ──
                      Row(
                        children: [
                          Expanded(
                            child: _SmallBalanceCard(
                              label: 'Wallet',
                              amount: NumberUtils.formatCurrency(walletBalance, decimalDigits: 2),
                              icon: Icons.account_balance_wallet_rounded,
                              iconColor: const Color(0xFF2E7D32),
                              bgColor: const Color(0xFFE8F5E9).withValues(alpha: 0.4),
                            ),
                          ),
                          AppSpacing.mHorizontal,
                          Expanded(
                            child: _SmallBalanceCard(
                              label: 'Bonus',
                              amount: NumberUtils.formatCurrency(bonusBalance, decimalDigits: 2),
                              icon: Icons.card_giftcard_rounded,
                              iconColor: const Color(0xFF7B1FA2),
                              bgColor: const Color(0xFFF3E5F5).withValues(alpha: 0.4),
                              infoWidget: Tooltip(
                                message: 'Bonus points can be used as a discount on your future bookings.',
                                triggerMode: TooltipTriggerMode.tap,
                                preferBelow: false,
                                verticalOffset: 15,
                                padding: AppPadding.symmetric(h: 12, v: 8),
                                margin: AppPadding.symmetric(h: 20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF212121).withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                textStyle: kTextNormal(color: kWhiteColor).copyWith(fontSize: 12.sp),
                                child: Padding(
                                  padding: EdgeInsets.only(left: 8.w, bottom: 8.h),
                                  child: Icon(Icons.info_outline_rounded, size: 16.sp, color: kTextHintColor),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.mVertical,

                      GestureDetector(
                        onTap: () => AppNavigator.to(AppRoutes.referEarn),
                        child: Container(
                          padding: AppPadding.m,
                          decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: AppRadius.m),
                          child: Row(
                            children: [
                              Container(
                                padding: AppPadding.all(6),
                                decoration: const BoxDecoration(color: Color(0xFFDCF6E6), shape: BoxShape.circle),
                                child: Icon(Icons.card_giftcard_rounded, color: const Color(0xFF2E7D32), size: 18.sp),
                              ),
                              AppSpacing.mHorizontal,
                              Expanded(
                                child: Text('Refer & Earn', style: kTextSemiBold(color: kTextPrimaryColor)),
                              ),
                              Icon(Icons.chevron_right_rounded, color: kTextHintColor.withValues(alpha: 0.5), size: 16.sp),
                            ],
                          ),
                        ),
                      ),
                      AppSpacing.lVertical,

                      SizedBox(
                        width: double.infinity,
                        height: 52.h,
                        child: ElevatedButton(
                          onPressed: () async {
                            final res = await AppNavigator.to(AppRoutes.addMoney);
                            if (res == true && context.mounted) {
                              context.read<AuthBloc>().add(RefreshProfile());
                              context.read<WalletBloc>().add(const FetchWalletTransactionsEvent());
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            shape: RoundedRectangleBorder(borderRadius: AppRadius.m),
                            elevation: 0,
                          ),
                          child: Text('Add money', style: kTextBold1(color: kWhiteColor)),
                        ),
                      ),
                      AppSpacing.xlVertical,

                      // ── Transactions Header ──
                      Text(
                        'Recent Transactions',
                        style: kTextBold1(color: kTextPrimaryColor).copyWith(fontSize: 18.sp),
                      ),
                      AppSpacing.mVertical,

                      // ── Transactions List or Empty State ──
                      BlocBuilder<WalletBloc, WalletState>(
                        builder: (context, state) {
                          if (state is WalletTransactionsLoaded) {
                            if (state.transactions.isEmpty) {
                              return _EmptyTransactionsView();
                            }

                            // Group transactions by date
                            final grouped = _groupTransactions(state.transactions);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: grouped.entries.map((entry) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12.h),
                                      child: Text(
                                        entry.key.toUpperCase(),
                                        style: kTextBold(color: kTextHintColor).copyWith(fontSize: 11.sp, letterSpacing: 1),
                                      ),
                                    ),
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: entry.value.length,
                                      itemBuilder: (context, index) {
                                        final tx = entry.value[index];
                                        return _TransactionListItem(tx: tx, isLast: index == entry.value.length - 1);
                                      },
                                    ),
                                  ],
                                );
                              }).toList(),
                            );
                          }
                          if (state is! WalletTransactionsLoading) {
                            return _EmptyTransactionsView();
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      AppSpacing.xlVertical,
                    ],
                  ),
                ),
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Map<String, List<dynamic>> _groupTransactions(List<dynamic> transactions) {
    final grouped = <String, List<dynamic>>{};
    for (final tx in transactions) {
      final dateStr = tx['created_at_formatted'] ?? '';
      final header = AppDateFormatter.smartDate(dateStr);
      grouped.putIfAbsent(header, () => []).add(tx);
    }
    return grouped;
  }
}

class _SmallBalanceCard extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Widget? infoWidget;

  const _SmallBalanceCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    this.infoWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppPadding.all(16),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: AppRadius.m,
        border: Border.all(color: kGreyColor.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: kBlackColor.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: AppPadding.all(6),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8.r)),
                child: Icon(icon, color: iconColor, size: 16.sp),
              ),
              AppSpacing.sHorizontal,
              Text(
                label,
                style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 13.sp, fontWeight: FontWeight.w500),
              ),
              if (infoWidget != null) ...[const Spacer(), infoWidget!],
            ],
          ),
          AppSpacing.mVertical,
          Text(
            amount,
            style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 20.sp, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }
}

class _EmptyTransactionsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppPadding.symmetric(v: 40),
      child: Column(
        children: [
          // Using a set of layered icon/shapes to mimic the complex illustration in the screenshot
          Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _EmptyCardIcon(icon: Icons.arrow_downward_rounded, angle: -0.2),
                  SizedBox(width: 20.w),
                  _EmptyCardIcon(icon: Icons.arrow_upward_rounded, angle: 0.2),
                ],
              ),
              Container(
                margin: EdgeInsets.only(bottom: 20.h),
                padding: AppPadding.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: AppRadius.m,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                ),
                child: Icon(Icons.priority_high_rounded, color: const Color(0xFFEF5350), size: 32.sp),
              ),
            ],
          ),
          AppSpacing.lVertical,
          Text(
            'No transactions yet',
            style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 17.sp),
          ),
          AppSpacing.sVertical,
          Text(
            'Your recent transaction activity will appear here.',
            style: kTextNormal(color: kTextHintColor).copyWith(fontSize: 13.sp),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyCardIcon extends StatelessWidget {
  final IconData icon;
  final double angle;

  const _EmptyCardIcon({required this.icon, required this.angle});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: AppPadding.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.s,
          border: Border.all(color: const Color(0xFFEEEEEE)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
        ),
        child: Icon(icon, color: const Color(0xFFBDBDBD), size: 24.sp),
      ),
    );
  }
}

class _TransactionListItem extends StatelessWidget {
  final Map<String, dynamic> tx;
  final bool isLast;

  const _TransactionListItem({required this.tx, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final cr = double.tryParse(tx['cr']?.toString() ?? '0') ?? 0;
    final dr = double.tryParse(tx['dr']?.toString() ?? '0') ?? 0;
    final bool isCredit = cr > 0;
    final amountText = NumberUtils.formatCurrency(isCredit ? cr : dr, decimalDigits: 2);

    // Determine status and style
    final String description = tx['description']?.toString() ?? 'Transaction';
    final bool isPending = description.toLowerCase().contains('pending');

    return InkWell(
      onTap: () => _showTransactionDetails(context, tx),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon with soft background
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: (isPending ? Colors.orange : (isCredit ? Colors.green : Colors.grey)).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPending ? Icons.schedule_rounded : (isCredit ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded),
                    color: isPending ? Colors.orange : (isCredit ? Colors.green : kTextSecondaryColor),
                    size: 20.sp,
                  ),
                ),
                AppSpacing.mHorizontal,
                // Description and Time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description,
                        style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 15.sp),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        _formatTime(tx['created_at_formatted'] ?? ''),
                        style: kTextNormal(color: kTextHintColor).copyWith(fontSize: 12.sp),
                      ),
                    ],
                  ),
                ),
                // Amount and Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isCredit ? '+' : '-'} $amountText',
                      style: kTextBold(color: isPending ? Colors.orange : (isCredit ? Colors.green : kTextPrimaryColor)).copyWith(fontSize: 16.sp),
                    ),
                    if (isPending) ...[
                      SizedBox(height: 2.h),
                      Text(
                        'Processing',
                        style: kTextMedium(color: Colors.orange).copyWith(fontSize: 11.sp),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!isLast)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              child: Divider(height: 1, color: kGreyColor3),
            ),
        ],
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, Map<String, dynamic> tx) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionDetailsSheet(tx: tx),
    );
  }

  String _formatTime(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final parts = dateStr.trim().split(RegExp(r'\s+'));
      if (parts.length > 1) {
        final timePart = parts[1]; // HH:mm:ss or hh:mm
        final timeParts = timePart.split(':');
        if (timeParts.length >= 2) {
          int hour = int.parse(timeParts[0]);
          int min = int.parse(timeParts[1]);
          String ampm;

          if (parts.length >= 3 &&
              (parts[2].toUpperCase() == 'AM' || parts[2].toUpperCase() == 'PM')) {
            ampm = parts[2].toUpperCase();
          } else {
            ampm = hour >= 12 ? 'PM' : 'AM';
            hour = hour % 12;
            if (hour == 0) hour = 12;
          }

          return '$hour:${min.toString().padLeft(2, '0')} $ampm';
        }
      }
      return dateStr;
    } catch (_) {
      return dateStr;
    }
  }
}
