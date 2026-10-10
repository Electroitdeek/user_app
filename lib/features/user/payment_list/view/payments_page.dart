import 'dart:async';

import 'package:adhisaat_health_care/core/theme/screen_dimensions.dart';
import 'package:adhisaat_health_care/features/user/payment_list/model/payment_model.dart';
import 'package:adhisaat_health_care/shared/widgets/inputs/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:open_filex/open_filex.dart';

import '../../../../core/services/file_downloading_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/number_utils.dart';
import '../../../../di/locator.dart';
import '../../../../shared/widgets/common/custom_error_view.dart';
import '../../payment/data/payment_repository.dart';
import '../../payment_list/bloc/payments_bloc.dart';
import 'transaction_detail_page.dart';

class UserPaymentsPage extends StatelessWidget {
  final bool showBackButton;

  const UserPaymentsPage({super.key, this.showBackButton = true});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PaymentsBloc(locator<PaymentRepository>())..add(LoadPayments()),
      child: _PaymentsView(showBackButton: showBackButton),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PaymentsView extends StatefulWidget {
  final bool showBackButton;

  const _PaymentsView({required this.showBackButton});

  @override
  State<_PaymentsView> createState() => _PaymentsViewState();
}

class _PaymentsViewState extends State<_PaymentsView> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  // local UI state for selected status filter ('' = all, no payment_type sent)
  String _selectedStatus = '';

  static const _statusOptions = [('All', ''), ('Paid', 'payment'), ('Refunds', 'refund'), ('Failed', 'failed')];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent * 0.85) {
      context.read<PaymentsBloc>().add(LoadMorePayments());
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _applyFilter(search: value);
    });
  }

  void _onStatusTap(String status) {
    setState(() => _selectedStatus = status);
    _applyFilter(status: status);
  }

  void _applyFilter({String? search, String? status}) {
    final bloc = context.read<PaymentsBloc>();
    final current = bloc.state is PaymentsLoaded ? (bloc.state as PaymentsLoaded).filter : const PaymentFilter();
    bloc.add(
      UpdatePaymentFilter(
        current.copyWith(search: search ?? _searchCtrl.text, paymentStatus: status ?? _selectedStatus),
      ),
    );
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
            // ── Header & Filter ──────────────────────────────────────
            _buildHeader(context),

            // ── Content ──────────────────────────────────────────────
            Expanded(
              child: BlocBuilder<PaymentsBloc, PaymentsState>(
                builder: (context, state) {
                  if (state is PaymentsLoading) {
                    return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                  }
                  if (state is PaymentsError) {
                    return CustomErrorView(
                      title: 'Something went wrong',
                      message: state.message,
                      onRetry: () => context.read<PaymentsBloc>().add(LoadPayments()),
                    );
                  }
                  if (state is PaymentsLoaded) {
                    return RefreshIndicator(
                      color: kPrimaryColor,
                      onRefresh: () async => context.read<PaymentsBloc>().add(LoadPayments(isRefresh: true)),
                      child: state.payments.isEmpty
                          ? Padding(
                              padding: EdgeInsets.only(top: 100.h),
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: _EmptyView(
                                  hasActiveFilter:
                                      state.filter.search.isNotEmpty || state.filter.paymentStatus.isNotEmpty,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scroll,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(8.w, 12.h, 8.w, 16.h),
                              itemCount: state.payments.length + 1,
                              itemBuilder: (context, i) {
                                if (i >= state.payments.length) {
                                  if (!state.hasReachedMax) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      child: Center(
                                        child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2),
                                      ),
                                    );
                                  }
                                  return SizedBox(height: 10.h);
                                }
                                return _PaymentCard(payment: state.payments[i]);
                              },
                            ),
                    );
                  }
                  return const SizedBox();
                },
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
            forceMaterialTransparency: true,
            backgroundColor: kWhiteColor,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: widget.showBackButton
                ? IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18.sp, color: kTextPrimaryColor),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null,
            title: Text('My Payments', style: kTextBold().copyWith(fontSize: 20.sp)),
            centerTitle: true,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, 10.h),
            child: Row(
              children: [
                Expanded(
                  child: _SearchBar(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    onClear: () {
                      _searchCtrl.clear();
                      _applyFilter(search: '');
                    },
                  ),
                ),
                SizedBox(width: 10.w),
                _FilterDropdown(value: _selectedStatus, options: _statusOptions, onChanged: _onStatusTap),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
        ],
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
    return CustomTextField(
      controller: controller,
      onChanged: onChanged,
      hintText: 'Search payment no., TXN...',
      prefixIcon: Icon(Icons.search_rounded, color: kPrimaryColor, size: 22.sp),
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
    );
  }
}

// ─── Filter Dropdown ──────────────────────────────────────────────────────────

class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final selected = options.firstWhere((o) => o.$2 == value, orElse: () => options.first);
    final isFiltered = value.isNotEmpty;

    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      offset: Offset(0, 48.h),
      color: kWhiteColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
      itemBuilder: (context) => options
          .map(
            (o) => PopupMenuItem<String>(
              value: o.$2,
              height: 44.h,
              child: Row(
                children: [
                  Icon(
                    o.$2 == value ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 18.sp,
                    color: o.$2 == value ? kPrimaryColor : kTextHintColor,
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    o.$1,
                    style:
                        (o.$2 == value
                                ? kTextSemiBold(color: kPrimaryColor)
                                : kTextMedium(color: kTextPrimaryColor))
                            .copyWith(fontSize: 13.sp),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        height: 46.h,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: isFiltered ? kPrimaryColor.withValues(alpha: 0.06) : kWhiteColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: isFiltered ? kPrimaryColor.withValues(alpha: 0.4) : kBorderColor, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded, size: 17.sp, color: isFiltered ? kPrimaryColor : kTextSecondaryColor),
            SizedBox(width: 6.w),
            Text(
              selected.$1,
              style: kTextSemiBold(
                color: isFiltered ? kPrimaryColor : kTextSecondaryColor,
              ).copyWith(fontSize: 13.sp),
            ),
            SizedBox(width: 2.w),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 20.sp,
              color: isFiltered ? kPrimaryColor : kTextSecondaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Payment Card ─────────────────────────────────────────────────────────────

class _PaymentCard extends StatefulWidget {
  final PaymentModel payment;

  const _PaymentCard({required this.payment});

  @override
  State<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<_PaymentCard> {
  bool _isDownloading = false;

  Future<void> _downloadInvoice() async {
    if (_isDownloading) return;

    setState(() => _isDownloading = true);

    try {
      final pathOrUrl = await locator<PaymentRepository>().downloadInvoice(
        widget.payment.id,
        widget.payment.paymentNumber,
      );

      if (pathOrUrl != null && mounted) {
        if (pathOrUrl.startsWith('http')) {
          await FileDownloadService().downloadAndViewFile(
            url: pathOrUrl,
            originalName: '${widget.payment.paymentNumber}_invoice',
          );
        } else {
          // It's a local path
          await OpenFilex.open(pathOrUrl, type: 'application/pdf');
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to get invoice download link. Please try again later.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final payment = widget.payment;
    final bool isRefund = payment.paymentType == 'refund';
    final String rawStatus = isRefund ? (payment.refundStatus ?? 'pending') : payment.status;
    final String s = rawStatus.toLowerCase();
    // Surface only failures — completed/success cards stay clean.
    final bool isFailedStatus = s == 'failed' || s == 'cancelled' || s == 'expired';

    final typeColor = isRefund ? kSuccessColor : kPrimaryColor;

    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: kGreyColor1, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Type accent bar
                Container(width: 5.w, color: typeColor),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(14.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38.w,
                              height: 38.w,
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Icon(
                                isRefund ? Icons.south_west_rounded : _methodIcon(payment.paymentMethod),
                                color: typeColor,
                                size: 18.sp,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    payment.serviceCategoryName ?? 'Payment',
                                    style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (isFailedStatus || isRefund) ...[
                                    SizedBox(height: 3.h),
                                    _TypeBadge(
                                      label: isFailedStatus ? 'FAILED' : 'REFUND',
                                      color: isFailedStatus ? kErrorColor : kSuccessColor,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${isRefund ? '+ ' : ''}${NumberUtils.formatCurrency(payment.subtotal)}',
                                  style: kTextBold(
                                    color: isRefund ? kSuccessColor : kPrimaryColor,
                                  ).copyWith(fontSize: 16.sp),
                                ),
                                if (!isFailedStatus) ...[
                                  SizedBox(height: 3.h),
                                  Text(
                                    isRefund ? 'Credited' : 'Paid',
                                    style: kTextMedium(color: kTextHintColor).copyWith(fontSize: 9.5.sp),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        Divider(height: 1, color: kGreyColor1),
                        SizedBox(height: 8.h),
                        // Footer: id · date+time (id hidden on failure)
                        Row(
                          children: [
                            if (!isFailedStatus) ...[
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.receipt_long_rounded, size: 12.sp, color: kTextHintColor),
                                    SizedBox(width: 4.w),
                                    Flexible(
                                      child: Text(
                                        payment.paymentNumber,
                                        style: kTextMedium(color: kTextHintColor).copyWith(fontSize: 10.sp),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AppSpacing.sHorizontal,
                            ],
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 11.sp, color: kTextSecondaryColor),
                                  SizedBox(width: 4.w),
                                  Flexible(
                                    child: Text(
                                      AppDateFormatter.timelineDateTime(payment.paidAt ?? payment.createdAt),
                                      style: kTextMedium(color: kTextSecondaryColor).copyWith(fontSize: 10.5.sp),
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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

  void _showDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionDetailPage(payment: widget.payment, onDownload: _downloadInvoice),
      ),
    );
  }

  IconData _methodIcon(String? method) {
    switch (method) {
      case 'upi':
        return Icons.qr_code_rounded;
      case 'card':
        return Icons.credit_card_rounded;
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      case 'netbanking':
        return Icons.account_balance_rounded;
      case 'cash':
        return Icons.money_rounded;
      default:
        return Icons.payments_rounded;
    }
  }
}

// ─── Reusable local widgets ──────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(5.r)),
      child: Text(
        label.toUpperCase(),
        style: kTextBold(color: color).copyWith(fontSize: 9.sp, letterSpacing: 0.5),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final bool hasActiveFilter;

  const _EmptyView({required this.hasActiveFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(color: kGreyColor1, shape: BoxShape.circle),
              child: Icon(Icons.receipt_long_rounded, size: 28.sp, color: kGreyColor6),
            ),
            SizedBox(height: 16.h),
            Text(
              hasActiveFilter ? 'No matching payments' : 'No payments yet',
              style: kTextBold().copyWith(fontSize: 18.sp),
            ),
            SizedBox(height: 6.h),
            Text(
              hasActiveFilter
                  ? 'Try clearing or changing your filters.'
                  : 'Your payment history will appear here once you make a transaction.',
              textAlign: TextAlign.center,
              style: kTextNormal(color: kTextSecondaryColor),
            ),
          ],
        ),
      ),
    );
  }
}
