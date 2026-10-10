import 'dart:async';

import 'package:adhisaat_health_care/core/theme/screen_dimensions.dart';
import 'package:adhisaat_health_care/shared/widgets/buttons/custom_button.dart';
import 'package:adhisaat_health_care/shared/widgets/inputs/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/number_utils.dart';
import '../../../../di/locator.dart';
import '../../../../shared/widgets/common/app_bar_custom.dart';
import '../../../../shared/widgets/dialogs/dialog_helpers.dart';
import '../bloc/provider_wallet_bloc.dart';
import '../model/provider_wallet_model.dart';
import '../repository/provider_wallet_repository.dart';

class ProviderWalletPage extends StatelessWidget {
  const ProviderWalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ProviderWalletBloc(ProviderWalletRepository(locator<ApiClient>()))..add(ProviderWalletFetch()),
      child: const _ProviderWalletView(),
    );
  }
}

class _ProviderWalletView extends StatefulWidget {
  const _ProviderWalletView();

  @override
  State<_ProviderWalletView> createState() => _ProviderWalletViewState();
}

class _ProviderWalletViewState extends State<_ProviderWalletView> {
  @override
  Widget build(BuildContext context) {
    return BlocListener<ProviderWalletBloc, ProviderWalletState>(
      listenWhen: (prev, curr) =>
          prev.requestStatus != curr.requestStatus || prev.cancelStatus != curr.cancelStatus,
      listener: (context, state) {
        if (state.requestStatus == WithdrawalRequestStatus.success) {
          Navigator.pop(context); // Close bottom sheet
          DialogHelper.showSuccess(
            title: 'Success',
            message: state.requestMessage ?? 'Withdrawal request submitted',
          );
        } else if (state.requestStatus == WithdrawalRequestStatus.error) {
          DialogHelper.showError(title: 'Error', message: state.requestMessage ?? 'Something went wrong');
        }

        if (state.cancelStatus == WithdrawalRequestStatus.success) {
          Navigator.pop(context); // Close detail sheet
          DialogHelper.showSuccess(
            title: 'Cancelled',
            message: state.cancelMessage ?? 'Withdrawal request cancelled',
          );
        } else if (state.cancelStatus == WithdrawalRequestStatus.error) {
          DialogHelper.showError(title: 'Error', message: state.cancelMessage ?? 'Something went wrong');
        }
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F9FD),
          appBar: const CustomAppBar(title: 'My Wallet', centerTitle: true, backgroundColor: kScaffoldColor),
          body: SafeArea(
            top: false,
            child: BlocBuilder<ProviderWalletBloc, ProviderWalletState>(
              builder: (context, state) {
                if (state.status == ProviderWalletStatus.loading && state.walletData == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.status == ProviderWalletStatus.error && state.walletData == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, color: kErrorColor, size: 48.sp),
                        SizedBox(height: 16.h),
                        Text(
                          state.errorMessage ?? 'Something went wrong',
                          style: kTextMedium(color: kTextSecondaryColor),
                        ),
                        SizedBox(height: 16.h),
                        ElevatedButton(
                          onPressed: () => context.read<ProviderWalletBloc>().add(ProviderWalletFetch()),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<ProviderWalletBloc>().add(ProviderWalletRefresh());
                  },
                  notificationPredicate: (notification) => notification.depth == 2 || notification.depth == 0,
                  color: kPrimaryColor,
                  child: NestedScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    headerSliverBuilder: (context, innerBoxIsScrolled) {
                      return [
                        SliverToBoxAdapter(
                          child: _WalletHeader(walletData: state.walletData, withdrawals: state.withdrawals),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _SliverAppBarDelegate(
                            child: Container(
                              color: const Color(0xFFF8F9FD),
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                              child: Container(
                                padding: EdgeInsets.all(4.r),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(100.r),
                                ),
                                child: TabBar(
                                  labelColor: Colors.white,
                                  unselectedLabelColor: kTextSecondaryColor,
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  dividerColor: Colors.transparent,
                                  splashFactory: NoSplash.splashFactory,
                                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                                  indicator: BoxDecoration(
                                    color: kPrimaryColor,
                                    borderRadius: BorderRadius.circular(100.r),
                                    boxShadow: [
                                      BoxShadow(
                                        color: kPrimaryColor.withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  labelStyle: kTextSemiBold(color: Colors.white).copyWith(fontSize: 13.sp),
                                  unselectedLabelStyle: kTextMedium(
                                    color: kTextSecondaryColor,
                                  ).copyWith(fontSize: 13.sp),
                                  tabs: const [
                                    Tab(text: 'Transactions'),
                                    Tab(text: 'Withdrawals'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ];
                    },
                    body: TabBarView(
                      children: [
                        _TransactionList(state: state),
                        _WithdrawalList(state: state),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionList extends StatelessWidget {
  final ProviderWalletState state;

  const _TransactionList({required this.state});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const PageStorageKey<String>('transactions'),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Recent Activity',
              style: kTextBold1(color: kTextPrimaryColor).copyWith(fontSize: 16.sp),
            ),
          ),
        ),
        if (state.transactions.isEmpty && state.status == ProviderWalletStatus.loaded)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, color: kGreyColor, size: 64.sp),
                  SizedBox(height: 16.h),
                  Text('No transactions yet', style: kTextMedium(color: kTextSecondaryColor)),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index < state.transactions.length) {
                return _TransactionItem(transaction: state.transactions[index]);
              }
              if (state.hasMoreTransactions) {
                return _LoadMoreButton(
                  onTap: () => context.read<ProviderWalletBloc>().add(ProviderWalletLoadMoreTransactions()),
                  isLoading: state.isLoadingMore,
                );
              }
              return SizedBox(height: 40.h);
            }, childCount: state.transactions.length + 1),
          ),
      ],
    );
  }
}

class _WithdrawalList extends StatelessWidget {
  final ProviderWalletState state;

  const _WithdrawalList({required this.state});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const PageStorageKey<String>('withdrawals'),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Withdrawal Requests',
              style: kTextBold1(color: kTextPrimaryColor).copyWith(fontSize: 16.sp),
            ),
          ),
        ),
        if (state.withdrawals.isEmpty && state.status == ProviderWalletStatus.loaded)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_rounded, color: kGreyColor, size: 64.sp),
                  SizedBox(height: 16.h),
                  Text('No withdrawal requests', style: kTextMedium(color: kTextSecondaryColor)),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index < state.withdrawals.length) {
                return _WithdrawalItem(withdrawal: state.withdrawals[index]);
              }
              if (state.hasMoreWithdrawals) {
                return _LoadMoreButton(
                  onTap: () => context.read<ProviderWalletBloc>().add(ProviderWalletLoadMoreWithdrawals()),
                  isLoading: state.isLoadingMore,
                );
              }
              return SizedBox(height: 40.h);
            }, childCount: state.withdrawals.length + 1),
          ),
      ],
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLoading;

  const _LoadMoreButton({required this.onTap, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.r),
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.add_circle_outline_rounded, color: kPrimaryColor),
                label: Text('Load More', style: kTextSemiBold(color: kPrimaryColor)),
              ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SliverAppBarDelegate({required this.child});

  @override
  double get minExtent => 68.h;

  @override
  double get maxExtent => 68.h;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class _WalletHeader extends StatelessWidget {
  final ProviderWalletData? walletData;
  final List<ProviderWithdrawal> withdrawals;

  const _WalletHeader({this.walletData, this.withdrawals = const []});

  /// Amount locked in requests that are not yet completed/cancelled/rejected.
  double get _pendingWithdrawals => withdrawals
      .where((w) => !const ['completed', 'cancelled', 'rejected', 'failed'].contains(w.status.toLowerCase()))
      .fold(0.0, (sum, w) => sum + w.amount);

  /// Balance the provider can actually request, after pending requests.
  double get _availableForWithdrawal {
    final v = (walletData?.availableBalance ?? 0) - _pendingWithdrawals;
    return v < 0 ? 0 : v;
  }

  @override
  Widget build(BuildContext context) {
    if (walletData == null) return const SizedBox.shrink();

    final hasPending = _pendingWithdrawals > 0;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(16.r),
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kPrimaryColor, Color(0xFF6A5AE0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(color: kPrimaryColor.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Balance',
                      style: kTextMedium(color: Colors.white.withValues(alpha: 0.8)).copyWith(fontSize: 14.sp),
                    ),
                    SizedBox(height: 4.h),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        NumberUtils.formatCurrency(walletData!.availableBalance),
                        style: kTextBold(color: Colors.white).copyWith(fontSize: 32.sp),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _showWithdrawalBottomSheet(context, _availableForWithdrawal),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: kPrimaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100.r)),
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                ),
                child: Text(
                  'Withdraw',
                  style: kTextBold(color: kPrimaryColor).copyWith(fontSize: 14.sp),
                ),
              ),
            ],
          ),
          if (hasPending) ...[
            SizedBox(height: 20.h),
            Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
            SizedBox(height: 16.h),
            Row(
              children: [
                _BalanceSubItem(
                  label: 'Pending Requests',
                  amount: _pendingWithdrawals,
                  icon: Icons.hourglass_top_rounded,
                ),
                Container(width: 1, height: 32.h, color: Colors.white.withValues(alpha: 0.2)),
                SizedBox(width: 16.w),
                _BalanceSubItem(
                  label: 'Available to Withdraw',
                  amount: _availableForWithdrawal,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showWithdrawalBottomSheet(BuildContext context, double availableBalance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BlocProvider.value(
        value: context.read<ProviderWalletBloc>(),
        child: _WithdrawalRequestBottomSheet(availableBalance: availableBalance),
      ),
    );
  }
}

class _WithdrawalRequestBottomSheet extends StatefulWidget {
  final double availableBalance;

  const _WithdrawalRequestBottomSheet({required this.availableBalance});

  @override
  State<_WithdrawalRequestBottomSheet> createState() => _WithdrawalRequestBottomSheetState();
}

class _WithdrawalRequestBottomSheetState extends State<_WithdrawalRequestBottomSheet> {
  final _amountCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Timer? _debounce;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(color: kGreyColor5, borderRadius: BorderRadius.circular(100)),
                  ),
                ),
                SizedBox(height: 24.h),
                Text('Withdraw Funds', style: kTextBold1(color: kTextPrimaryColor)),
                SizedBox(height: 8.h),
                Text(
                  'Enter the amount you wish to withdraw to your linked bank account.',
                  style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 13.sp),
                ),
                SizedBox(height: 16.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: kPrimaryColor.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet_rounded, size: 18.sp, color: kPrimaryColor),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          'Available to withdraw',
                          style: kTextMedium(color: kTextSecondaryColor).copyWith(fontSize: 13.sp),
                        ),
                      ),
                      Text(
                        NumberUtils.formatCurrency(widget.availableBalance),
                        style: kTextBold1(color: kPrimaryColor).copyWith(fontSize: 15.sp),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
                CustomTextField(
                  controller: _amountCtrl,
                  labelText: 'Amount',
                  hintText: 'e.g. 500',
                  keyboardType: TextInputType.number,
                  isNumeric: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  prefixIcon: Icon(Icons.currency_rupee_rounded, color: kPrimaryColor, size: 20.sp),
                  onChanged: (v) {
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 500), () {
                      _formKey.currentState?.validate();
                    });
                  },
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter amount';
                    final amount = double.tryParse(v) ?? 0;
                    if (amount <= 0) return 'Amount must be greater than 0';
                    if (amount > widget.availableBalance) {
                      return 'Insufficient balance';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 32.h),
                BlocBuilder<ProviderWalletBloc, ProviderWalletState>(
                  builder: (context, state) {
                    return CustomButton(
                      title: 'Submit Request',
                      width: double.infinity,
                      height: AppButtonHeight.l,
                      isLoading: state.isRequesting,
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final amount = double.parse(_amountCtrl.text);
                          context.read<ProviderWalletBloc>().add(ProviderWalletRequestWithdrawal(amount));
                        }
                      },
                    );
                  },
                ),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BalanceSubItem extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;

  const _BalanceSubItem({required this.label, required this.amount, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 14.sp),
              SizedBox(width: 4.w),
              Flexible(
                child: Text(
                  label,
                  style: kTextNormal(color: Colors.white.withValues(alpha: 0.7)).copyWith(fontSize: 12.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            NumberUtils.formatCurrency(amount),
            style: kTextSemiBold(color: Colors.white).copyWith(fontSize: 16.sp),
          ),
        ],
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final ProviderTransaction transaction;

  const _TransactionItem({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final bool isCredit = transaction.amount > 0;
    final String formattedDate = _formatDate(transaction.createdAt);

    return InkWell(
      onTap: () => _showTransactionDetails(context, transaction),
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: (isCredit ? kSuccessColor : kErrorColor).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCredit ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                color: isCredit ? kSuccessColor : kErrorColor,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getTransactionTitle(transaction.transactionType, transaction.description),
                    style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    formattedDate,
                    style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? "+" : ""}${NumberUtils.formatCurrency(transaction.amount)}',
                  style: kTextBold(color: isCredit ? kSuccessColor : kErrorColor).copyWith(fontSize: 15.sp),
                ),
                SizedBox(height: 4.h),
                _StatusPill(status: transaction.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, ProviderTransaction tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TransactionDetailSheet(tx: tx),
    );
  }

  String _getTransactionTitle(String type, String description) {
    if (description.isNotEmpty) return description;
    switch (type) {
      case 'settlement_payout':
        return 'Settlement Payout';
      case 'manual_debit':
        return 'Manual Debit';
      case 'manual_credit':
        return 'Manual Credit';
      case 'commission':
        return 'Commission Deduction';
      default:
        return 'Transaction';
    }
  }

  String _formatDate(String dateStr) {
    try {
      final DateTime dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
  }
}

class _WithdrawalItem extends StatelessWidget {
  final ProviderWithdrawal withdrawal;

  const _WithdrawalItem({required this.withdrawal});

  @override
  Widget build(BuildContext context) {
    final String formattedDate = _formatDate(withdrawal.createdAt);

    return InkWell(
      onTap: () => _showWithdrawalDetails(context, withdrawal),
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.account_balance_rounded, color: kPrimaryColor, size: 24.sp),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Withdrawal Request',
                        style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        formattedDate,
                        style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      NumberUtils.formatCurrency(withdrawal.amount),
                      style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 15.sp),
                    ),
                    SizedBox(height: 4.h),
                    _StatusPill(status: withdrawal.status),
                  ],
                ),
              ],
            ),
            if (withdrawal.remark != null && withdrawal.remark!.isNotEmpty) ...[
              SizedBox(height: 12.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: kGreyColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14.sp, color: kTextSecondaryColor),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        withdrawal.remark!,
                        style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showWithdrawalDetails(BuildContext context, ProviderWithdrawal withdrawal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WithdrawalDetailSheet(withdrawal: withdrawal),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final DateTime dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'completed':
      case 'approved':
        color = kSuccessColor;
        break;
      case 'pending':
        color = kWarningColor;
        break;
      case 'failed':
      case 'rejected':
        color = kErrorColor;
        break;
      case 'cancelled':
        color = kTextSecondaryColor;
        break;
      default:
        color = kTextSecondaryColor;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12.r)),
      child: Text(
        status.toUpperCase(),
        style: kTextSemiBold(color: color).copyWith(fontSize: 10.sp),
      ),
    );
  }
}

class _TransactionDetailSheet extends StatelessWidget {
  final ProviderTransaction tx;

  const _TransactionDetailSheet({required this.tx});

  @override
  Widget build(BuildContext context) {
    final bool isCredit = tx.amount > 0;
    final Color statusColor = isCredit ? kSuccessColor : kErrorColor;

    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 32.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(color: kGreyColor3, borderRadius: BorderRadius.circular(2.r)),
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaction Detail',
                  style: kTextBold1(color: kTextPrimaryColor).copyWith(fontSize: 18.sp),
                ),
                _StatusPill(status: tx.status),
              ],
            ),
            SizedBox(height: 24.h),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 64.w,
                    height: 64.w,
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(
                      isCredit ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                      color: statusColor,
                      size: 32.sp,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    '${isCredit ? '+' : ''}${NumberUtils.formatCurrency(tx.amount)}',
                    style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 32.sp, letterSpacing: -1),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    tx.description,
                    textAlign: TextAlign.center,
                    style: kTextMedium(color: kTextSecondaryColor).copyWith(fontSize: 14.sp),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32.h),
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: kGreyColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Column(
                children: [
                  _DetailRow(label: 'Date & Time', value: _formatFullDate(tx.createdAt)),
                  SizedBox(height: 14.h),
                  _DetailRow(label: 'Type', value: tx.transactionType.replaceAll('_', ' ').toUpperCase()),
                  SizedBox(height: 14.h),
                  _DetailRow(label: 'Status', value: tx.status.toUpperCase()),
                ],
              ),
            ),
            SizedBox(height: 32.h),
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: CustomButton(title: 'Close', onPressed: () => Navigator.pop(context)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFullDate(String dateStr) {
    try {
      final DateTime dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
  }
}

class _WithdrawalDetailSheet extends StatelessWidget {
  final ProviderWithdrawal withdrawal;

  const _WithdrawalDetailSheet({required this.withdrawal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 32.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(color: kGreyColor3, borderRadius: BorderRadius.circular(2.r)),
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Withdrawal Detail',
                  style: kTextBold1(color: kTextPrimaryColor).copyWith(fontSize: 18.sp),
                ),
                _StatusPill(status: withdrawal.status),
              ],
            ),
            SizedBox(height: 24.h),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 64.w,
                    height: 64.w,
                    decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(Icons.account_balance_rounded, color: kPrimaryColor, size: 32.sp),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    NumberUtils.formatCurrency(withdrawal.amount),
                    style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 32.sp, letterSpacing: -1),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Withdrawal Request',
                    textAlign: TextAlign.center,
                    style: kTextMedium(color: kTextSecondaryColor).copyWith(fontSize: 14.sp),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32.h),
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: kGreyColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Column(
                children: [
                  _DetailRow(label: 'Date & Time', value: _formatFullDate(withdrawal.createdAt)),
                  if (withdrawal.transactionNumber != null) ...[
                    SizedBox(height: 14.h),
                    _DetailRow(label: 'Transaction ID', value: withdrawal.transactionNumber!),
                  ],
                  SizedBox(height: 14.h),
                  _DetailRow(label: 'Status', value: withdrawal.status.toUpperCase()),
                  if (withdrawal.remark != null && withdrawal.remark!.isNotEmpty) ...[
                    SizedBox(height: 14.h),
                    _DetailRow(label: 'Admin Remark', value: withdrawal.remark!),
                  ],
                ],
              ),
            ),
            SizedBox(height: 32.h),
            if (withdrawal.status.toLowerCase() == 'pending') ...[
              BlocBuilder<ProviderWalletBloc, ProviderWalletState>(
                builder: (context, state) {
                  return CustomButton(
                    title: 'Cancel Request',
                    backgroundColor: kErrorColor,
                    isLoading: state.isCanceling,
                    onPressed: () {
                      DialogHelper.showConfirmation(
                        title: 'Cancel Request',
                        message: 'Are you sure you want to cancel this withdrawal request?',
                        confirmText: 'Yes, Cancel',
                        onConfirm: () {
                          context.read<ProviderWalletBloc>().add(ProviderWalletCancelWithdrawal(withdrawal.id));
                        },
                      );
                    },
                  );
                },
              ),
              SizedBox(height: 12.h),
            ],
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: CustomButton(title: 'Close', onPressed: () => Navigator.pop(context)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFullDate(String dateStr) {
    try {
      final DateTime dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: kTextMedium(color: kTextSecondaryColor).copyWith(fontSize: 13.sp),
        ),
        Flexible(
          child: Text(
            value,
            style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 13.sp),
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
