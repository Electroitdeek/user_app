import 'package:adhisaat_health_care/core/storage/local_storage_service.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/theme/screen_dimensions.dart';
import 'package:adhisaat_health_care/shared/utils/consent_helper.dart';
import 'package:adhisaat_health_care/shared/widgets/dialogs/dialog_helpers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../../core/utils/number_utils.dart';
import '../../../../data/providers/user_profile_provider.dart';
import '../../../../di/locator.dart';
import '../../../../shared/widgets/common/app_bar_custom.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_state.dart';

class AddMoneyPage extends ConsumerStatefulWidget {
  const AddMoneyPage({super.key});

  @override
  ConsumerState<AddMoneyPage> createState() => _AddMoneyPageState();
}

class _AddMoneyPageState extends ConsumerState<AddMoneyPage> {
  final _amountCtrl = TextEditingController(text: '');
  late final Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletBloc>().add(const FetchWalletTransactionsEvent());
    });
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    context.read<WalletBloc>().add(
      WalletPaymentSuccessEvent(paymentId: response.paymentId ?? '', orderId: response.orderId ?? '', signature: response.signature ?? ''),
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (response.code == 2 || response.message?.toLowerCase().contains('cancelled') == true) {
      return;
    }
    context.read<WalletBloc>().add(WalletPaymentErrorEvent(response.message ?? 'Payment Failed'));
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  @override
  void dispose() {
    _razorpay.clear();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amountText = _amountCtrl.text.replaceAll(',', '');
    final amount = double.tryParse(amountText) ?? 0;
    final isAmountValid = amount >= 10 && amount <= 100000;
    final hasInput = amount > 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(title: 'Add Money', centerTitle: true, backgroundColor: kScaffoldColor),
      body: SafeArea(
        child: BlocListener<WalletBloc, WalletState>(
          listener: (context, state) {
            if (state is WalletInitiateSuccess) {
              _razorpay.open(state.razorpayOptions);
            } else if (state is WalletVerifySuccess) {
              // Update the global user profile to reflect the new balance
              ref.invalidate(userProfileFetchProvider);
              final storage = locator<LocalStorageService>();
              storage.saveLastKnownWalletAmount(((double.tryParse(storage.lastKnownWalletAmount ?? '0') ?? 0) + amount).toString());

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Money added successfully to your wallet.', style: kTextSemiBold0(color: Colors.white)),
                  backgroundColor: const Color(0xFF2E7D32),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
              Navigator.pop(context, true);
            }
          },
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    children: [
                      SizedBox(height: 48.h),

                      // ── Amount Input Section ──
                      Column(
                        children: [
                          Text(
                            'How much do you want to add?',
                            style: kTextSemiBold(color: kTextSecondaryColor).copyWith(fontSize: 15.sp),
                          ),
                          SizedBox(height: 24.h),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '₹',
                                style: kTextBold(color: hasInput ? kTextPrimaryColor : kTextHintColor).copyWith(fontSize: 28.sp),
                              ),
                              SizedBox(width: 8.w),
                              Flexible(
                                child: IntrinsicWidth(
                                  child: TextField(
                                    controller: _amountCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, _CurrencyInputFormatter()],
                                    textAlign: TextAlign.center,
                                    autofocus: true,
                                    cursorColor: kPrimaryColor,
                                    cursorWidth: 2.5,
                                    cursorHeight: 40.sp,
                                    style: kTextBold(color: hasInput ? kTextPrimaryColor : kTextHintColor).copyWith(fontSize: 48.sp, height: 1.1),
                                    maxLength: 10,
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      hintText: '0',
                                      counterText: '',
                                      hintStyle: TextStyle(color: kTextHintColor.withValues(alpha: 0.4)),
                                      contentPadding: EdgeInsets.zero,
                                      isDense: true,
                                    ),
                                    onChanged: (v) => setState(() {}),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (hasInput && amount < 10)
                            Padding(
                              padding: EdgeInsets.only(top: 12.h),
                              child: Text(
                                'Minimum amount is ₹10',
                                style: kTextSemiBold(color: kErrorColor).copyWith(fontSize: 12.sp),
                              ),
                            ),
                          if (amount > 100000)
                            Padding(
                              padding: EdgeInsets.only(top: 12.h),
                              child: Text(
                                'Maximum amount is ₹1,00,000',
                                style: kTextSemiBold(color: kErrorColor).copyWith(fontSize: 12.sp),
                              ),
                            ),
                        ],
                      ),
                      AppSpacing.xlVertical,

                      // ── Quick Select Pills ──
                      Wrap(
                        spacing: 12.w,
                        runSpacing: 12.h,
                        alignment: WrapAlignment.center,
                        children: [_buildQuickAmount('500'), _buildQuickAmount('1,000'), _buildQuickAmount('2,000'), _buildQuickAmount('5,000')],
                      ),

                      SizedBox(height: 40.h),

                      // ── Bonus Breakdown Section ──
                      if (isAmountValid)
                        BlocBuilder<WalletBloc, WalletState>(
                          builder: (context, state) {
                            if (state is WalletTransactionsLoading) {
                              return _buildShimmerCard(h: 100.h);
                            }
                            final bonusPercent = double.tryParse(context.read<WalletBloc>().bonusPercentage ?? '0') ?? 0;
                            final bonusAmt = (amount * bonusPercent) / 100;

                            return Container(
                              padding: EdgeInsets.all(20.sp),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(color: const Color(0xFFA5D6A7), width: 1),
                              ),
                              child: Column(
                                children: [
                                  _buildSummaryRow('Top-up Amount', '₹${_amountCtrl.text}'),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8.h),
                                    child: Divider(color: const Color(0xFFA5D6A7).withValues(alpha: 0.5)),
                                  ),
                                  _buildSummaryRow(
                                    'Bonus Added ($bonusPercent%)',
                                    NumberUtils.formatCurrency(bonusAmt, decimalDigits: 1),
                                    isBonus: true,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                      SizedBox(height: 24.h),

                      // ── Promo Card ──
                      BlocBuilder<WalletBloc, WalletState>(
                        builder: (context, state) {
                          if (state is WalletTransactionsLoading) {
                            return _buildShimmerCard(h: 80.h);
                          }
                          final bonusPercent = context.read<WalletBloc>().bonusPercentage ?? '0';
                          return Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(20.sp),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [const Color(0xFFF3F3FF), Colors.white],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22.r),
                              border: Border.all(color: kPrimaryColor.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Spark Offer ✨',
                                        style: kTextBold(color: kPrimaryColor).copyWith(fontSize: 12.sp),
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        'Get ${cleanDecimal(NumberUtils.toDouble(bonusPercent))}% extra bonus on every top-up.',
                                        style: kTextBold(color: const Color(0xFF37474F)).copyWith(fontSize: 14.sp, height: 1.3),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.stars_rounded, color: Colors.orangeAccent, size: 40.sp),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ── Reference Continue Button ──
              Padding(
                padding: EdgeInsets.all(24.w),
                child: BlocBuilder<WalletBloc, WalletState>(
                  builder: (context, state) {
                    final isLoading = state is WalletLoading;
                    return SizedBox(
                      width: double.infinity,
                      height: 56.h,
                      child: ElevatedButton(
                        onPressed: (isLoading || !isAmountValid) ? null : _proceedToPay,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAmountValid ? kPrimaryColor : kGreyColor,
                          shadowColor: kPrimaryColor.withValues(alpha: 0.3),
                          elevation: isAmountValid ? 8 : 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        ),
                        child: isLoading
                            ? SizedBox(
                                height: 24.h,
                                width: 24.h,
                                child: const CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                              )
                            : Text(
                                'Add ₹${_amountCtrl.text}',
                                style: kTextBold(color: Colors.white).copyWith(fontSize: 16.sp),
                              ),
                      ),
                    );
                  },
                ),
              ),

              // ── Consent note ──
              Padding(
                padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 16.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user_rounded, size: 13.sp, color: kTextHintColor),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: RichText(
                        textAlign: TextAlign.start,
                        text: TextSpan(
                          style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 11.sp, height: 1.4),
                          children: [
                            const TextSpan(text: 'By adding money, I agree to the '),
                            TextSpan(
                              text: 'Wallet Top-up Consent',
                              style: kTextSemiBold0(color: kPrimaryColor).copyWith(fontSize: 11.sp),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => ConsentHelper.show(
                                      context: context,
                                      consentType: 'add_money_to_wallet',
                                      viewOnly: true,
                                      fallbackToTermsOnEmpty: true,
                                    ),
                            ),
                            const TextSpan(text: '.'),
                          ],
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

  Widget _buildQuickAmount(String amount) {
    final isSelected = _amountCtrl.text == amount;
    return InkWell(
      onTap: () {
        _amountCtrl.text = amount;
        setState(() {});
      },
      borderRadius: BorderRadius.circular(10.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor : Colors.white,
          border: Border.all(color: isSelected ? kPrimaryColor : kGreyColor2, width: 1.2),
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: isSelected ? [BoxShadow(color: kPrimaryColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Text(
          '₹$amount',
          style: kTextBold(color: isSelected ? Colors.white : kTextSecondaryColor).copyWith(fontSize: 13.sp),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBonus = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: (isBonus ? kTextSemiBold : kTextNormal0)(color: kTextSecondaryColor)),
        Text(
          value,
          style: kTextBold(color: isBonus ? const Color(0xFF2E7D32) : kTextPrimaryColor).copyWith(fontSize: 16.sp),
        ),
      ],
    );
  }

  Widget _buildShimmerCard({required double h}) {
    return Container(
      width: double.infinity,
      height: h,
      decoration: BoxDecoration(color: kGreyColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20.r)),
      child: Stack(children: [Positioned.fill(child: _ShimmerOverlay())]),
    );
  }

  void _proceedToPay() {
    final amountText = _amountCtrl.text.replaceAll(',', '');
    final amt = double.tryParse(amountText) ?? 0;
    if (amt < 10) {
      DialogHelper.showError(title: 'Invalid Amount', message: 'Minimum amount to add is ₹10.');
      return;
    }
    if (amt > 100000) {
      DialogHelper.showError(title: 'Limit Exceeded', message: 'Maximum amount to add is ₹1,00,000.');
      return;
    }
    context.read<WalletBloc>().add(InitiateWalletTopUpEvent(amt));
  }
}

class _CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final double? value = double.tryParse(newValue.text);
    if (value == null) return oldValue;

    final String formatted = _format(newValue.text);

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _format(String value) {
    final text = value.replaceAll(',', '');
    if (text.isEmpty) return '';

    // Simple Indian number formatting (roughly) or standard international
    // For simplicity, we use standard groups of 3 for now.
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i != 0 && (text.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(text[i]);
    }
    return buffer.toString();
  }
}

class _ShimmerOverlay extends StatefulWidget {
  @override
  State<_ShimmerOverlay> createState() => _ShimmerOverlayState();
}

class _ShimmerOverlayState extends State<_ShimmerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _anim = Tween<double>(begin: -1, end: 2).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [(_anim.value - 0.4).clamp(0.0, 1.0), _anim.value.clamp(0.0, 1.0), (_anim.value + 0.4).clamp(0.0, 1.0)],
              colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.4), Colors.white.withValues(alpha: 0)],
            ),
          ),
        );
      },
    );
  }
}
