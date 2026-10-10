import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/api/redirection_url.dart';
import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/services/launch_url_service.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/core/utils/message_service.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:adhisaat_health_care/shared/widgets/dialogs/custom_dialogs.dart';
import 'package:adhisaat_health_care/shared/widgets/dialogs/dialog_helpers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_edge_insets.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/repositories/system_settings_repository.dart';
import '../../../../di/locator.dart';
import '../../../auth/login/bloc/auth_bloc.dart';
import '../../wallet/data/wallet_repository.dart';
import '../bloc/payment_bloc.dart';
import '../data/payment_repository.dart';
import 'offers_bottom_sheet.dart';

Future<void> navigateToPaymentPage({
  required BuildContext context,
  required int serviceRequestId,
  required double totalAmount,
  required double basePrice,
  required double distanceCharge,
  required double gstAmount,
  String bookingType = 'service_booking',
  List<Map<String, dynamic>> paymentInstallments = const [],
  String? serviceName,
  String? serviceImageUrl,
  String? startDate,
  String? endDate,
  int? durationDays,
  int? durationHours,
  String? unitType,
  bool isEmergency = false,
  VoidCallback? onCancel,
  // Set true only when navigating from fresh booking flow (step4).
  // Enables the "Discard booking?" pop-confirm. False = installment payment.
  bool isNewBooking = false,
  double packageDiscountAmount = 0.0,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BlocProvider(
        create: (_) => PaymentBloc(
          locator<PaymentRepository>(),
          locator<LocalStorageService>(),
          locator<SystemSettingsRepository>(),
          locator<WalletRepository>(),
          container: ProviderScope.containerOf(context, listen: false),
        ),
        child: _BookingPaymentPage(
          serviceRequestId: serviceRequestId,
          totalAmount: totalAmount,
          basePrice: basePrice,
          distanceCharge: distanceCharge,
          gstAmount: gstAmount,
          bookingType: bookingType,
          paymentInstallments: paymentInstallments,
          serviceName: serviceName,
          serviceImageUrl: serviceImageUrl,
          startDate: startDate,
          endDate: endDate,
          durationDays: durationDays,
          durationHours: durationHours,
          unitType: unitType,
          isEmergency: isEmergency,
          onCancel: onCancel,
          isNewBooking: isNewBooking,
          packageDiscountAmount: packageDiscountAmount,
        ),
      ),
    ),
  );
}

class _BookingPaymentPage extends StatefulWidget {
  final int serviceRequestId;
  final double totalAmount;
  final double basePrice;
  final double distanceCharge;
  final double gstAmount;
  final String bookingType;
  final List<Map<String, dynamic>> paymentInstallments;
  final String? serviceName;
  final String? serviceImageUrl;
  final String? startDate;
  final String? endDate;
  final int? durationDays;
  final int? durationHours;
  final String? unitType;
  final bool isEmergency;
  final VoidCallback? onCancel;
  final bool isNewBooking;
  final double packageDiscountAmount;

  const _BookingPaymentPage({
    required this.serviceRequestId,
    required this.totalAmount,
    required this.basePrice,
    required this.distanceCharge,
    required this.gstAmount,
    required this.bookingType,
    this.paymentInstallments = const [],
    this.serviceName,
    this.serviceImageUrl,
    this.startDate,
    this.endDate,
    this.durationDays,
    this.durationHours,
    this.unitType,
    this.isEmergency = false,
    this.isNewBooking = false,
    this.onCancel,
    this.packageDiscountAmount = 0.0,
  });

  @override
  State<_BookingPaymentPage> createState() => _BookingPaymentPageState();
}

class _BookingPaymentPageState extends State<_BookingPaymentPage> {
  final _promoCtrl = TextEditingController();
  late final Razorpay _razorpay;
  bool _useBonusPoints = false;
  bool _useWallet = true;
  String _paymentMode = 'full'; // 'installment' | 'full'
  // Indices of installments selected for payment; index 0 is always included
  late Set<int> _checkedInstallmentIndices;

  PaymentBloc? _bloc;

  int get _customerProfileId => locator<LocalStorageService>().customerUserId ?? 0;

  bool get _hasInstallments => widget.paymentInstallments.length > 1;

  double get _selectedBaseAmount {
    if (!_hasInstallments || _paymentMode == 'full') return widget.totalAmount;
    double sum = 0;
    for (final i in _checkedInstallmentIndices) {
      if (i < widget.paymentInstallments.length) {
        sum += double.tryParse(widget.paymentInstallments[i]['amount']?.toString() ?? '') ?? 0;
      }
    }
    return sum > 0 ? sum : widget.totalAmount;
  }

  double get _payingNowBasePrice {
    if (!_hasInstallments || _paymentMode == 'full') return widget.basePrice;
    if (widget.totalAmount <= 0) return widget.basePrice;
    final fraction = _selectedBaseAmount / widget.totalAmount;
    return widget.basePrice * fraction;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bloc ??= context.read<PaymentBloc>();
  }

  @override
  void initState() {
    super.initState();
    _paymentMode = _hasInstallments ? 'installment' : 'full';
    _checkedInstallmentIndices = {0}; // first installment always required

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onRazorpaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onRazorpayError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bloc?.add(FetchAvailablePromosEvent(serviceRequestId: widget.serviceRequestId));
      context.read<AuthBloc>().add(RefreshProfile());
    });
  }

  @override
  void dispose() {
    _razorpay.clear();
    _promoCtrl.dispose();
    super.dispose();
  }

  void _onRazorpaySuccess(PaymentSuccessResponse r) {
    _bloc?.add(
      RazorpaySuccessEvent(paymentId: r.paymentId ?? '', orderId: r.orderId ?? '', signature: r.signature ?? ''),
    );
  }

  void _onRazorpayError(PaymentFailureResponse r) {
    kPrint('EVENT_PAYMENT_ERROR code=${r.code} msg=${r.message}');
    if (r.code == Razorpay.PAYMENT_CANCELLED || r.message?.toLowerCase().contains('cancelled') == true) return;
    _bloc?.add(RazorpayFailureEvent(r.message));
  }

  void _onExternalWallet(ExternalWalletResponse r) {}

  void _showSnackBar(String msg, {bool error = false}) {
    if (!mounted) return;
    if (error) {
      MessageService.showError(msg);
    } else {
      MessageService.showSuccess(msg);
    }
  }

  List<int> get _selectedInstallmentIds {
    final ids = <int>[];
    if (_hasInstallments && _paymentMode == 'full') {
      for (final inst in widget.paymentInstallments) {
        if (inst['status']?.toString() != 'paid') {
          final id = inst['id'];
          if (id != null) {
            ids.add(id is int ? id : int.tryParse(id.toString()) ?? 0);
          }
        }
      }
      return ids;
    }

    for (final i in _checkedInstallmentIndices) {
      if (i < widget.paymentInstallments.length) {
        final id = widget.paymentInstallments[i]['id'];
        if (id != null) {
          ids.add(id is int ? id : int.tryParse(id.toString()) ?? 0);
        }
      }
    }
    return ids;
  }

  Future<void> _handlePay(
    BuildContext ctx,
    PaymentSheetData data,
    double finalPayable,
    double walletUsed,
    double bonusUsed,
  ) async {
    var method = 'UPI';
    var gatewayRef = '';
    if (finalPayable > 0) {
      final choice = await showDialog<({String method, String gatewayRef})>(
        context: ctx,
        builder: (_) => const _PaymentMethodDialog(),
      );
      if (choice == null || !ctx.mounted) return;
      method = choice.method;
      gatewayRef = choice.gatewayRef;
    }
    ctx.read<PaymentBloc>().add(
      InitiatePaymentEvent(
        serviceRequestId: widget.serviceRequestId,
        customerProfileId: _customerProfileId,
        payableAmount: finalPayable,
        totalAmount: _selectedBaseAmount,
        basePrice: _payingNowBasePrice,
        distanceCharge: widget.distanceCharge,
        gstAmount: widget.gstAmount,
        discountAmount: data.discountAmount,
        appliedCode: data.appliedCode,
        promoCodeId: data.promoCodeId,
        bookingType: widget.bookingType,
        walletAmountUsed: walletUsed,
        bonusAmountUsed: bonusUsed,
        paymentInstallmentIds: _selectedInstallmentIds,
        method: method,
        gatewayRef: gatewayRef,
      ),
    );
  }

  void _handleApplyPromo(BuildContext ctx, String code) {
    FocusScope.of(ctx).unfocus();
    ctx.read<PaymentBloc>().add(
      ApplyPromoEvent(
        code: code,
        totalAmount: _selectedBaseAmount,
        customerProfileId: _customerProfileId,
        serviceRequestId: widget.serviceRequestId,
      ),
    );
  }

  void _showOffersBottomSheet(BuildContext context, PaymentSheetData data) {
    context.read<PaymentBloc>().add(FetchAvailablePromosEvent(serviceRequestId: widget.serviceRequestId));
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BlocProvider.value(
        value: context.read<PaymentBloc>(),
        child: BlocListener<PaymentBloc, PaymentState>(
          listenWhen: (_, next) => next is PaymentSnackBarState,
          listener: (listenCtx, state) {
            if (state is PaymentSnackBarState && state.isError) {
              DialogHelper.showError(
                title: 'Not Applicable',
                message: 'This promo code is not applicable for your current booking.',
              );
            }
          },
          child: OffersBottomSheet(
            currentAmount: _selectedBaseAmount,
            onSelect: (code) {
              _promoCtrl.text = code;
              context.read<PaymentBloc>().add(
                ApplyPromoEvent(
                  code: code,
                  totalAmount: _selectedBaseAmount,
                  customerProfileId: _customerProfileId,
                  serviceRequestId: widget.serviceRequestId,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (prev, curr) {
        if (curr is AuthAuthenticated && prev is AuthAuthenticated) {
          return curr.user.walletAmount != prev.user.walletAmount ||
              curr.user.bonusWalletAmount != prev.user.bonusWalletAmount;
        }
        return curr is AuthAuthenticated;
      },
      builder: (context, authState) {
        return BlocConsumer<PaymentBloc, PaymentState>(
          buildWhen: (_, next) => next is PaymentSheetData,
          listenWhen: (_, next) =>
              next is PaymentOpenRazorpayState ||
              next is PaymentSuccessState ||
              next is PaymentSnackBarState ||
              next is PaymentCancelledState ||
              next is PaymentErrorDialogState ||
              next is PromoAppliedState,
          listener: (ctx, state) {
            if (state is PaymentOpenRazorpayState) {
              _razorpay.open(state.razorpayOptions);
            } else if (state is PaymentSuccessState) {
              AppNavigator.replaceWith(
                AppRoutes.paymentSuccess,
                args: {'serviceRequestId': widget.serviceRequestId, 'unitType': widget.unitType},
              );
            } else if (state is PaymentCancelledState) {
              final nav = Navigator.of(ctx);
              nav.pop();
              if (widget.isNewBooking) {
                nav.pop();
              }
              DialogHelper.showSuccess(title: 'Cancelled', message: 'Booking cancelled successfully');
              widget.onCancel?.call();
            } else if (state is PaymentErrorDialogState) {
              final msg = state.message;
              showDialog(
                context: ctx,
                barrierDismissible: false,
                builder: (dCtx) => AppDialog(
                  accentColor: kErrorColor,
                  iconBg: const Color(0xFFFEF2F2),
                  icon: Icons.error_outline_rounded,
                  iconColor: kErrorColor,
                  title: 'Payment Unavailable',
                  message: msg,
                  primaryLabel: 'Go to Home',
                  primaryColor: kPrimaryColor,
                  onPrimary: () {
                    Navigator.pop(dCtx);
                    AppNavigator.popToRoot(ctx);
                  },
                  ghostLabel: 'Dismiss',
                  onGhost: () => Navigator.pop(dCtx),
                ),
              );
            } else if (state is PromoAppliedState) {
              _promoCtrl.clear();
              FocusScope.of(ctx).unfocus();
              showDialog(
                context: ctx,
                barrierDismissible: true,
                builder: (dCtx) => _PromoSuccessDialog(code: state.code, discount: state.discountAmount),
              );
            } else if (state is PaymentSnackBarState) {
              if (!state.isError && state.data.appliedCode != null) {
                _promoCtrl.clear();
              }
              _showSnackBar(state.message, error: state.isError);
            }
          },
          builder: (ctx, state) {
            final data = state as PaymentSheetData;

            final double availableBonus = data.bonusBalance;
            final double availableWallet = data.walletBalance;
            final double totalAmount = _selectedBaseAmount;
            final double discountAmount = data.discountAmount;
            final double finalBasePrice = totalAmount - discountAmount;

            final double adjustmentPct = data.bonusAdjustmentPercentage;
            final double basePriceForBonus = (_payingNowBasePrice - discountAmount).clamp(0.0, double.infinity);
            final double maxBonusAllowed = basePriceForBonus * (adjustmentPct / 100.0);
            double bonusAmountUsed = 0.0;
            if (_useBonusPoints) {
              bonusAmountUsed = availableBonus >= maxBonusAllowed ? maxBonusAllowed : availableBonus;
            }

            final double payableAfterBonus = finalBasePrice - bonusAmountUsed;
            double walletAmountUsed = 0.0;
            if (_useWallet) {
              walletAmountUsed = availableWallet >= payableAfterBonus ? payableAfterBonus : availableWallet;
            }

            final double finalPayableAmount = (payableAfterBonus - walletAmountUsed).clamp(0.0, double.infinity);

            return PopScope(
              canPop: !widget.isNewBooking,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop && widget.isNewBooking) _confirmDiscard(context);
              },
              child: Scaffold(
                backgroundColor: kScaffoldColor,
                appBar: CustomAppBar(
                  title: 'Confirm Booking',
                  leading: IconButton(
                    icon: Icon(
                      widget.isNewBooking ? Icons.close : Icons.arrow_back_ios_new_rounded,
                      color: const Color(0xFF212121),
                    ),
                    onPressed: widget.isNewBooking
                        ? () => _confirmDiscard(context)
                        : () => Navigator.of(context).pop(),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child: Divider(height: 1, color: kBorderColor),
                  ),
                ),
                body: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              // ── Service Summary ──
                              if (widget.serviceName != null)
                                _Section(
                                  child: _ServiceSummaryCard(
                                    serviceName: widget.serviceName!,
                                    serviceImageUrl: widget.serviceImageUrl,
                                    startDate: widget.startDate,
                                    endDate: widget.endDate,
                                    durationDays: widget.durationDays,
                                    durationHours: widget.durationHours,
                                    unitType: widget.unitType,
                                    isEmergency: widget.isEmergency,
                                  ),
                                ),

                              // ── Payment Mode Selection (Installment / Full) ──
                              if (_hasInstallments && widget.paymentInstallments.length > 1)
                                _Section(
                                  child: _PaymentOptionsSection(
                                    installments: widget.paymentInstallments,
                                    totalAmount: widget.totalAmount,
                                    selectedMode: _paymentMode,
                                    checkedIndices: _checkedInstallmentIndices,
                                    onModeChanged: (mode) {
                                      setState(() {
                                        _paymentMode = mode;
                                        // Reset to only first installment when switching back
                                        if (mode == 'installment') {
                                          _checkedInstallmentIndices = {0};
                                        }
                                      });
                                      if (data.appliedCode != null && data.appliedCode!.isNotEmpty) {
                                        ctx.read<PaymentBloc>().add(const RemovePromoEvent());
                                      }
                                    },
                                    onInstallmentToggle: (index, checked) {
                                      if (index == 0) return; // first is locked
                                      setState(() {
                                        if (checked) {
                                          // Select this + all previous
                                          for (int k = 0; k <= index; k++) {
                                            _checkedInstallmentIndices.add(k);
                                          }
                                        } else {
                                          // Deselect this + all subsequent (keep first)
                                          for (int k = index; k < widget.paymentInstallments.length; k++) {
                                            _checkedInstallmentIndices.remove(k);
                                          }
                                        }
                                      });
                                      if (data.appliedCode != null && data.appliedCode!.isNotEmpty) {
                                        ctx.read<PaymentBloc>().add(const RemovePromoEvent());
                                      }
                                    },
                                  ),
                                ),

                              // ── Promo Code ──
                              _Section(
                                child: _PromoRow(
                                  controller: _promoCtrl,
                                  appliedCode: data.appliedCode,
                                  discountAmount: data.discountAmount,
                                  isLoading: data.promoLoading,
                                  error: data.promoError,
                                  onApply: () {
                                    final code = _promoCtrl.text.trim();
                                    if (code.isEmpty) return;
                                    _handleApplyPromo(context, code);
                                  },
                                  onRemove: () => ctx.read<PaymentBloc>().add(const RemovePromoEvent()),
                                  onViewOffers: () => _showOffersBottomSheet(context, data),
                                ),
                              ),

                              // ── Wallet & Bonus ──
                              if (data.promosLoading)
                                _Section(
                                  child: Shimmer.fromColors(
                                    baseColor: const Color(0xFFE8EAF0),
                                    highlightColor: const Color(0xFFF5F6FA),
                                    child: Column(
                                      children: [
                                        _ShimmerBalanceRow(),
                                        Divider(height: 16, color: kBorderColor.withValues(alpha: 0.3)),
                                        _ShimmerBalanceRow(),
                                      ],
                                    ),
                                  ),
                                )
                              else if (availableWallet > 0 || availableBonus > 0)
                                _Section(
                                  child: Column(
                                    children: [
                                      if (availableBonus > 0)
                                        _BalanceToggleRow(
                                          icon: Icons.card_giftcard_rounded,
                                          iconColor: kAccentColor,
                                          iconBg: kAccentColor.withValues(alpha: 0.12),
                                          title: 'Bonus Points',
                                          subtitle:
                                              'Available: ${NumberUtils.formatCurrency(availableBonus)} · Max ${adjustmentPct.toInt()}% usable',
                                          value: _useBonusPoints,
                                          savings: bonusAmountUsed > 0
                                              ? '- ${NumberUtils.formatCurrency(bonusAmountUsed)}'
                                              : null,
                                          onChanged: (val) => setState(() => _useBonusPoints = val),
                                        ),

                                      if (availableWallet > 0 && availableBonus > 0)
                                        Divider(height: 16, color: kBorderColor.withValues(alpha: 0.5)),
                                      if (availableWallet > 0)
                                        _BalanceToggleRow(
                                          icon: Icons.account_balance_wallet_rounded,
                                          iconColor: kPrimaryColor,
                                          iconBg: kPrimaryColor.withValues(alpha: 0.10),
                                          title: 'Wallet Balance',
                                          subtitle: 'Available: ${NumberUtils.formatCurrency(availableWallet)}',
                                          value: _useWallet,
                                          savings: walletAmountUsed > 0
                                              ? '- ${NumberUtils.formatCurrency(walletAmountUsed)}'
                                              : null,
                                          onChanged: (val) => setState(() => _useWallet = val),
                                        ),
                                    ],
                                  ),
                                ),

                              // ── Bill Summary ──
                              _Section(
                                child: _BillBreakdown(
                                  selectedAmount: totalAmount,
                                  fullAmount: widget.totalAmount,
                                  paymentMode: _paymentMode,
                                  hasInstallments: _hasInstallments,
                                  discountAmount: discountAmount,
                                  bonusAmountUsed: bonusAmountUsed,
                                  walletAmountUsed: walletAmountUsed,
                                  payableAmount: finalPayableAmount,
                                  packageDiscountAmount: widget.packageDiscountAmount,
                                ),
                              ),

                              // ── Consent note ──
                              Padding(
                                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                                  decoration: BoxDecoration(
                                    color: kPrimaryColor.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(color: kPrimaryColor.withValues(alpha: 0.12)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: AppPadding.all(7),
                                        decoration: BoxDecoration(
                                          color: kPrimaryColor.withValues(alpha: 0.10),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.verified_user_rounded,
                                          size: 15.sp,
                                          color: kPrimaryColor,
                                        ),
                                      ),
                                      SizedBox(width: 10.w),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: kTextNormal0(
                                              color: kTextSecondaryColor,
                                            ).copyWith(fontSize: 11.5.sp, height: 1.4),
                                            children: [
                                              const TextSpan(text: 'By proceeding, I agree to the '),
                                              TextSpan(
                                                text: 'Terms & Conditions',
                                                style: kTextSemiBold0(
                                                  color: kPrimaryColor,
                                                ).copyWith(fontSize: 11.5.sp),
                                                recognizer: TapGestureRecognizer()
                                                  ..onTap = () => LaunchUrlService.launchInAppWebUrl(
                                                    RedirectionUrl.userTermsConditions,
                                                  ),
                                              ),
                                              const TextSpan(text: ', '),
                                              TextSpan(
                                                text: 'Privacy Policy',
                                                style: kTextSemiBold0(
                                                  color: kPrimaryColor,
                                                ).copyWith(fontSize: 11.5.sp),
                                                recognizer: TapGestureRecognizer()
                                                  ..onTap = () => LaunchUrlService.launchInAppWebUrl(
                                                    RedirectionUrl.privacyPolicy,
                                                  ),
                                              ),
                                              const TextSpan(text: ', and '),
                                              TextSpan(
                                                text: 'Cancellation & Policy',
                                                style: kTextSemiBold0(
                                                  color: kPrimaryColor,
                                                ).copyWith(fontSize: 11.5.sp),
                                                recognizer: TapGestureRecognizer()
                                                  ..onTap = () => LaunchUrlService.launchInAppWebUrl(
                                                    RedirectionUrl.cancellationPolicy,
                                                  ),
                                              ),
                                              const TextSpan(text: ' and '),
                                              TextSpan(
                                                text: 'consent',
                                                style: kTextSemiBold0(
                                                  color: kPrimaryColor,
                                                ).copyWith(fontSize: 11.5.sp),
                                                recognizer: TapGestureRecognizer()
                                                  ..onTap = () => LaunchUrlService.launchInAppWebUrl(
                                                    RedirectionUrl.patientConsent,
                                                  ),
                                              ),
                                              const TextSpan(
                                                text:
                                                    ' to the processing of my information for service fulfillment.',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Sticky Bottom Bar ──
                      Container(
                        decoration: BoxDecoration(
                          color: kWhiteColor,
                          boxShadow: [
                            BoxShadow(
                              color: kBlackColor.withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
                        child: SafeArea(
                          top: false,
                          child: SizedBox(
                            width: double.infinity,
                            height: 54.h,
                            child: ElevatedButton(
                              onPressed: data.paymentLoading
                                  ? null
                                  : () => _handlePay(
                                      context,
                                      data,
                                      finalPayableAmount,
                                      walletAmountUsed,
                                      bonusAmountUsed,
                                    ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryColor,
                                disabledBackgroundColor: kPrimaryColor.withValues(alpha: 0.6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                                elevation: 0,
                              ),
                              child: data.paymentLoading
                                  ? SizedBox(
                                      width: 22.sp,
                                      height: 22.sp,
                                      child: CircularProgressIndicator(color: kWhiteColor, strokeWidth: 2.5),
                                    )
                                  : AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
                                      child: Row(
                                        key: ValueKey(finalPayableAmount),
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.lock_rounded,
                                            size: 15.sp,
                                            color: kWhiteColor.withValues(alpha: 0.75),
                                          ),
                                          SizedBox(width: 8.w),
                                          Flexible(
                                            child: Text(
                                              finalPayableAmount > 0
                                                  ? 'Pay ${NumberUtils.formatCurrency(finalPayableAmount)}'
                                                  : 'Confirm Booking',
                                              style: kTextBold1(color: kWhiteColor).copyWith(fontSize: 16.sp),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ); // PopScope + Scaffold
          },
        );
      },
    );
  }

  Future<void> _confirmDiscard(BuildContext context) async {
    final nav = Navigator.of(context);
    final confirmed = await showLeavePaymentDialog(context);

    if (confirmed && mounted) {
      // Fire-and-forget cancel — don't block the user
      locator<PaymentRepository>().cancelUnpaidBooking(widget.serviceRequestId);
      if (mounted) {
        nav.pop(); // Pop _BookingPaymentPage → back to step3 (confirm address)
      }
    }
  }
}

// ─── Service Summary Card ────────────────────────────────────────────────────

class _ServiceSummaryCard extends StatelessWidget {
  final String serviceName;
  final String? serviceImageUrl;
  final String? startDate;
  final String? endDate;
  final int? durationDays;
  final int? durationHours;
  final String? unitType;
  final bool isEmergency;

  const _ServiceSummaryCard({
    required this.serviceName,
    this.serviceImageUrl,
    this.startDate,
    this.endDate,
    this.durationDays,
    this.durationHours,
    this.unitType,
    this.isEmergency = false,
  });

  @override
  Widget build(BuildContext context) {
    final String? durationLabel = durationDays != null
        ? (durationHours != null && unitType != null
              ? '$durationDays ${durationDays == 1 ? 'Day' : 'Days'} · $durationHours $unitType / day'
              : '$durationDays ${durationDays == 1 ? 'Day' : 'Days'}')
        : durationHours != null
        ? '$durationHours ${durationHours == 1 ? 'Hour' : 'Hours'}'
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44.w,
          height: 44.w,
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10.r),
          ),
          clipBehavior: Clip.antiAlias,
          child: (serviceImageUrl != null && serviceImageUrl!.isNotEmpty)
              ? CachedNetworkImage(
                  imageUrl: serviceImageUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) =>
                      Icon(Icons.medical_services_rounded, size: 20.sp, color: kPrimaryColor),
                )
              : Icon(Icons.medical_services_rounded, size: 20.sp, color: kPrimaryColor),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(serviceName, style: kTextBold1()),
              if (startDate != null) ...[
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 13.sp, color: kTextHintColor),
                    SizedBox(width: 5.w),
                    Expanded(
                      child: Text(
                        endDate != null && endDate != startDate
                            ? '${AppDateFormatter.dateFromApi(startDate!)} → ${AppDateFormatter.dateFromApi(endDate!)}'
                            : AppDateFormatter.dateFromApi(startDate!),
                        style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                      ),
                    ),
                  ],
                ),
              ],
              // Emergency bookings are immediate — no duration to show.
              if (!isEmergency && durationLabel != null) ...[
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(Icons.timelapse_rounded, size: 13.sp, color: kTextHintColor),
                    SizedBox(width: 5.w),
                    Text(
                      durationLabel,
                      style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Promo Applied Success Dialog (Swiggy / Zomato style) ────────────────────

class _PromoSuccessDialog extends StatelessWidget {
  final String code;
  final double discount;

  const _PromoSuccessDialog({required this.code, required this.discount});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF1BA672);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Container(
        decoration: BoxDecoration(color: kWhiteColor, borderRadius: BorderRadius.circular(20.r)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top celebratory banner
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 26.h),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1BA672), Color(0xFF13C08B)],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64.w,
                    height: 64.w,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: Center(
                      child: Container(
                        width: 46.w,
                        height: 46.w,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Icon(Icons.celebration_rounded, color: green, size: 26.sp),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text("'$code' applied", style: kTextBold1(color: Colors.white)),
                ],
              ),
            ),
            // Body
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 18.h),
              child: Column(
                children: [
                  Text('You saved', style: kTextNormal0(color: kTextSecondaryColor)),
                  SizedBox(height: 4.h),
                  Text(
                    NumberUtils.formatCurrency(discount, decimalDigits: 0),
                    style: kTextBold2(color: green).copyWith(fontSize: 30.sp, height: 1),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'with this promo code on your booking',
                    style: kTextNormal0(color: kTextSecondaryColor),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20.h),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        decoration: BoxDecoration(
                          color: green,
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: [
                            BoxShadow(
                              color: green.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          'Yay! Continue',
                          textAlign: TextAlign.center,
                          style: kTextBold1(color: Colors.white),
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
    );
  }
}

// ─── Section wrapper ────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final Widget child;

  const _Section({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      color: kWhiteColor,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: child,
    );
  }
}

// ─── Payment Options Section ────────────────────────────────────────────────

class _PaymentOptionsSection extends StatelessWidget {
  final List<Map<String, dynamic>> installments;
  final double totalAmount;
  final String selectedMode;
  final Set<int> checkedIndices;
  final ValueChanged<String> onModeChanged;
  final void Function(int index, bool checked) onInstallmentToggle;

  const _PaymentOptionsSection({
    required this.installments,
    required this.totalAmount,
    required this.selectedMode,
    required this.checkedIndices,
    required this.onModeChanged,
    required this.onInstallmentToggle,
  });

  Map<String, dynamic>? get _firstPending {
    try {
      return installments.firstWhere((i) => i['status']?.toString() == 'pending');
    } catch (_) {
      return installments.isNotEmpty ? installments.first : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final inst = _firstPending;
    if (inst == null) return const SizedBox.shrink();

    double instAmount = 0;
    int instPct = 0;
    for (final i in checkedIndices) {
      if (i < installments.length) {
        instAmount += double.tryParse(installments[i]['amount']?.toString() ?? '') ?? 0;
        instPct += installments[i]['percentage'] is int
            ? installments[i]['percentage'] as int
            : int.tryParse(installments[i]['percentage']?.toString() ?? '') ?? 0;
      }
    }
    if (instAmount <= 0) {
      instAmount = double.tryParse(inst['amount']?.toString() ?? '') ?? 0;
      instPct = inst['percentage'] is int
          ? inst['percentage'] as int
          : int.tryParse(inst['percentage']?.toString() ?? '') ?? 0;
    }

    final bool allSelected = checkedIndices.length == installments.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment Options', style: kTextSemiBold1()),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _PaymentOptionCard(
                title: allSelected ? 'Pay Full Amount' : 'Pay Partial Amount',
                subtitle: allSelected ? '100% upfront' : '$instPct% now, rest later',
                amount: NumberUtils.formatCurrency(instAmount),
                badge: allSelected ? 'COMPLETE' : 'FLEXIBLE',
                badgeColor: allSelected ? kPrimaryColor : const Color(0xFF2E7D32),
                isSelected: selectedMode == 'installment',
                onTap: () => onModeChanged('installment'),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _PaymentOptionCard(
                title: 'Pay Full Amount',
                subtitle: '100% upfront',
                amount: NumberUtils.formatCurrency(totalAmount),
                badge: 'COMPLETE',
                badgeColor: kPrimaryColor,
                isSelected: selectedMode == 'full',
                onTap: () => onModeChanged('full'),
              ),
            ),
          ],
        ),
        // Only show installment schedule when in installment mode
        if (selectedMode == 'installment' && installments.length > 1) ...[
          SizedBox(height: 12.h),
          _InstallmentSchedule(
            installments: installments,
            checkedIndices: checkedIndices,
            onToggle: onInstallmentToggle,
          ),
        ],
      ],
    );
  }
}

class _PaymentOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final String badge;
  final Color badgeColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentOptionCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.badge,
    required this.badgeColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor.withValues(alpha: 0.04) : kScaffoldColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: isSelected ? kPrimaryColor : kBorderColor, width: isSelected ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 16.w,
                  height: 16.w,
                  decoration: BoxDecoration(
                    color: isSelected ? kPrimaryColor : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isSelected ? null : Border.all(color: kBorderColor, width: 1.5),
                  ),
                  child: isSelected ? Icon(Icons.check, color: kWhiteColor, size: 10.sp) : null,
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    badge,
                    style: kTextBold0(color: badgeColor).copyWith(fontSize: 8.sp),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              amount,
              style: kTextBold(color: isSelected ? kPrimaryColor : kTextPrimaryColor).copyWith(fontSize: 16.sp),
            ),
            SizedBox(height: 3.h),
            Text(
              title,
              style: kTextMedium0(color: kTextPrimaryColor).copyWith(fontSize: 12.sp),
            ),
            SizedBox(height: 2.h),
            Text(
              subtitle,
              style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstallmentSchedule extends StatelessWidget {
  final List<Map<String, dynamic>> installments;
  final Set<int> checkedIndices;
  final void Function(int index, bool checked) onToggle;

  const _InstallmentSchedule({required this.installments, required this.checkedIndices, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(color: kScaffoldColor, borderRadius: BorderRadius.circular(10.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Installments to Pay',
            style: kTextMedium0(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
          ),
          SizedBox(height: 8.h),
          ...installments.asMap().entries.map((entry) {
            final idx = entry.key;
            final i = entry.value;
            final isLast = idx == installments.length - 1;
            final isPaid = i['status']?.toString() == 'paid';
            final isFirst = idx == 0;
            final isChecked = checkedIndices.contains(idx) || isPaid;
            final amount = double.tryParse(i['amount']?.toString() ?? '') ?? 0;
            final num = i['installment_number'] is int
                ? i['installment_number'] as int
                : int.tryParse(i['installment_number']?.toString() ?? '') ?? (idx + 1);
            final rawDue = i['due_date']?.toString() ?? '';
            final due = rawDue.isNotEmpty
                ? () {
                    try {
                      return DateFormat('EEE, dd MMM yyyy').format(DateTime.parse(rawDue));
                    } catch (_) {
                      return rawDue;
                    }
                  }()
                : '';

            return Column(
              children: [
                GestureDetector(
                  onTap: (isPaid || isFirst) ? null : () => onToggle(idx, !isChecked),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24.w,
                        height: 24.w,
                        child: isPaid
                            ? Container(
                                decoration: BoxDecoration(color: kSuccessColor, shape: BoxShape.circle),
                                child: Icon(Icons.check, size: 14.sp, color: kWhiteColor),
                              )
                            : Checkbox(
                                value: isChecked,
                                onChanged: isFirst
                                    ? null // first is locked
                                    : (val) => onToggle(idx, val ?? false),
                                activeColor: kPrimaryColor,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                              ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Installment $num',
                              style: kTextMedium0(color: kTextPrimaryColor).copyWith(fontSize: 12.sp),
                            ),
                            if (isFirst)
                              Text(
                                'Required',
                                style: kTextNormal0(color: kTextHintColor).copyWith(fontSize: 10.sp),
                              )
                            else if (due.isNotEmpty)
                              Text(
                                'Due: $due',
                                style: kTextNormal0(color: kTextHintColor).copyWith(fontSize: 10.sp),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        NumberUtils.formatCurrency(amount),
                        style: kTextSemiBold(
                          color: isPaid ? kSuccessColor : kTextPrimaryColor,
                        ).copyWith(fontSize: 12.sp),
                      ),
                    ],
                  ),
                ),
                if (!isLast) ...[
                  SizedBox(height: 4.h),
                  Padding(
                    padding: EdgeInsets.only(left: 11.w),
                    child: Container(width: 1, height: 10.h, color: kBorderColor),
                  ),
                  SizedBox(height: 4.h),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ─── Promo Row ───────────────────────────────────────────────────────────────

class _PromoRow extends StatelessWidget {
  final TextEditingController controller;
  final String? appliedCode;
  final double discountAmount;
  final bool isLoading;
  final String? error;
  final VoidCallback onApply;
  final VoidCallback onRemove;
  final VoidCallback onViewOffers;

  const _PromoRow({
    required this.controller,
    required this.appliedCode,
    required this.discountAmount,
    required this.isLoading,
    required this.onApply,
    required this.onRemove,
    required this.onViewOffers,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final isApplied = appliedCode != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header row ──
        Row(
          children: [
            Icon(Icons.local_offer_rounded, size: 16.sp, color: kPrimaryColor),
            SizedBox(width: 8.w),
            Expanded(child: Text('Promo Codes', style: kTextSemiBold1())),
            if (!isApplied)
              GestureDetector(
                onTap: onViewOffers,
                child: Text(
                  'View All',
                  style: kTextSemiBold0(color: kPrimaryColor).copyWith(fontSize: 13.sp),
                ),
              ),
          ],
        ),
        SizedBox(height: 12.h),

        // ── Applied state ──
        if (isApplied)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kSuccessColor.withValues(alpha: 0.10), kSuccessColor.withValues(alpha: 0.03)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: kSuccessColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                // Coupon ticket accent
                Container(
                  width: 44.w,
                  height: 56.h,
                  decoration: BoxDecoration(
                    color: kSuccessColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14.r),
                      bottomLeft: Radius.circular(14.r),
                    ),
                  ),
                  child: Icon(Icons.local_offer_rounded, size: 20.sp, color: kSuccessColor),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            appliedCode!,
                            style: kTextBold(
                              color: kTextPrimaryColor,
                            ).copyWith(fontSize: 14.sp, letterSpacing: 0.3),
                          ),
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                            decoration: BoxDecoration(
                              color: kSuccessColor,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              'APPLIED',
                              style: kTextBold(color: kWhiteColor).copyWith(fontSize: 8.sp, letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        'You saved ${NumberUtils.formatCurrency(discountAmount)}',
                        style: kTextSemiBold0(color: kSuccessColor).copyWith(fontSize: 11.sp),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onRemove,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                    child: Container(
                      padding: AppPadding.all(5),
                      decoration: BoxDecoration(
                        color: kErrorColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded, size: 14.sp, color: kErrorColor),
                    ),
                  ),
                ),
              ],
            ),
          )
        // ── Input state ──
        else ...[
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: error != null ? kErrorColor.withValues(alpha: 0.6) : kBorderColor),
            ),
            child: Row(
              children: [
                SizedBox(width: 14.w),
                Icon(Icons.discount_outlined, size: 16.sp, color: kTextHintColor),
                SizedBox(width: 8.w),
                Expanded(
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => onApply(),
                    style: kTextMedium(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
                    decoration: InputDecoration(
                      hintText: 'Enter promo code',
                      hintStyle: kTextNormal(color: kTextHintColor).copyWith(fontSize: 14.sp),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.all(6.w),
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onApply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      disabledBackgroundColor: kPrimaryColor.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                      elevation: 0,
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 14.sp,
                            height: 14.sp,
                            child: CircularProgressIndicator(color: kWhiteColor, strokeWidth: 2),
                          )
                        : Text(
                            'Apply',
                            style: kTextSemiBold(color: kWhiteColor).copyWith(fontSize: 13.sp),
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (error != null)
            Padding(
              padding: EdgeInsets.only(top: 8.h, left: 4.w),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 13.sp, color: kErrorColor),
                  SizedBox(width: 5.w),
                  Expanded(
                    child: Text(error!, style: kTextNormal0(color: kErrorColor)),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

// ─── Balance Toggle Row ──────────────────────────────────────────────────────

class _BalanceToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final bool value;
  final String? savings;
  final ValueChanged<bool> onChanged;

  const _BalanceToggleRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.savings,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: AppPadding.all(8),
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, size: 16.sp, color: iconColor),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: kTextMedium(color: kTextPrimaryColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (savings != null && value) ...[
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                      decoration: BoxDecoration(
                        color: kSuccessColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        savings!,
                        style: kTextBold0(color: kSuccessColor).copyWith(fontSize: 10.sp),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 2.h),
              Text(
                subtitle,
                style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: kPrimaryColor,
          activeTrackColor: kPrimaryColor.withValues(alpha: 0.4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}

// ─── Bill Breakdown ───────────────────────────────────────────────────────────

class _BillBreakdown extends StatelessWidget {
  final double selectedAmount;
  final double fullAmount;
  final String paymentMode;
  final bool hasInstallments;
  final double discountAmount;
  final double bonusAmountUsed;
  final double walletAmountUsed;
  final double payableAmount;
  final double packageDiscountAmount;

  const _BillBreakdown({
    required this.selectedAmount,
    required this.fullAmount,
    required this.paymentMode,
    required this.hasInstallments,
    required this.discountAmount,
    required this.bonusAmountUsed,
    required this.walletAmountUsed,
    required this.payableAmount,
    required this.packageDiscountAmount,
  });

  @override
  Widget build(BuildContext context) {
    final isInstallment = hasInstallments && paymentMode == 'installment';
    final totalSaved = packageDiscountAmount + discountAmount + bonusAmountUsed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Payment Summary', style: kTextSemiBold1()),
            if (isInstallment) ...[
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  selectedAmount >= fullAmount ? 'Full Payment' : 'Partial Payment',
                  style: kTextNormal0(color: kPrimaryColor).copyWith(fontSize: 10.sp),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 14.h),
        if (isInstallment) ...[
          _BillLine(
            label: 'Total Booking Value',
            value: NumberUtils.formatCurrency(fullAmount),
            labelColor: kTextHintColor,
            valueColor: kTextHintColor,
          ),
          _BillLine(label: 'Paying Now', value: NumberUtils.formatCurrency(selectedAmount)),
        ] else
          _BillLine(label: 'Package Price', value: NumberUtils.formatCurrency(selectedAmount)),
        if (discountAmount > 0)
          _BillLine(
            label: 'Promo Discount',
            value: '- ${NumberUtils.formatCurrency(discountAmount)}',
            valueColor: kSuccessColor,
          ),
        if (bonusAmountUsed > 0)
          _BillLine(
            label: 'Bonus Points',
            value: '- ${NumberUtils.formatCurrency(bonusAmountUsed)}',
            valueColor: kSuccessColor,
          ),
        if (walletAmountUsed > 0)
          _BillLine(
            label: 'Wallet',
            value: '- ${NumberUtils.formatCurrency(walletAmountUsed)}',
            valueColor: kSuccessColor,
          ),
        SizedBox(height: 10.h),
        Divider(height: 1, color: kDividerColor),
        SizedBox(height: 10.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total Payable', style: kTextBold1()),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                NumberUtils.formatCurrency(payableAmount),
                key: ValueKey(payableAmount),
                style: kTextBold1(color: kPrimaryColor).copyWith(fontSize: 17.sp),
              ),
            ),
          ],
        ),
        if (totalSaved > 0) ...[
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: kSuccessColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: kSuccessColor.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.local_offer_rounded, color: kSuccessColor, size: 18.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Total You Saved',
                    style: kTextSemiBold(color: kSuccessColor),
                  ),
                ),
                Text(
                  NumberUtils.formatCurrency(totalSaved),
                  style: kTextBold1(color: kSuccessColor),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BillLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? labelColor;
  final Color? valueColor;

  const _BillLine({required this.label, required this.value, this.labelColor, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: kTextNormal(color: labelColor ?? kTextSecondaryColor)),
          Text(value, style: kTextSemiBold(color: valueColor ?? kTextPrimaryColor)),
        ],
      ),
    );
  }
}

// ─── Shimmer placeholder for wallet/bonus row ─────────────────────────────────

class _ShimmerBalanceRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 12.h,
                width: 100.w,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
              ),
              SizedBox(height: 6.h),
              Container(
                height: 10.h,
                width: 140.w,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
              ),
            ],
          ),
        ),
        Container(
          width: 44.w,
          height: 24.h,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r)),
        ),
      ],
    );
  }
}

class _PaymentMethodDialog extends StatefulWidget {
  const _PaymentMethodDialog();

  @override
  State<_PaymentMethodDialog> createState() => _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends State<_PaymentMethodDialog> {
  String _method = 'UPI';
  final _referenceCtrl = TextEditingController();

  static const _methods = <String, String>{
    'UPI': 'UPI',
    'CARD': 'Card',
    'NET_BANKING': 'Net banking',
    'CASH': 'Cash',
  };

  @override
  void dispose() {
    _referenceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsReference = _method != 'CASH';
    return AlertDialog(
      title: const Text('Record payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Method'),
            items: _methods.entries
                .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _method = value);
            },
          ),
          if (needsReference) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _referenceCtrl,
              decoration: const InputDecoration(
                labelText: 'UPI / gateway reference',
                hintText: 'Optional. Leave blank to mark pending',
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, (method: _method, gatewayRef: _referenceCtrl.text.trim())),
          child: const Text('Pay'),
        ),
      ],
    );
  }
}
