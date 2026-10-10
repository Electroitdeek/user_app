import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_edge_insets.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/buttons/custom_button.dart';
import '../../../../shared/widgets/common/app_bar_custom.dart';
import '../../../../shared/widgets/common/app_cached_image.dart';
import '../bloc/extend_booking_bloc.dart';
import '../data/extend_booking_repository.dart';
import '../../../../core/utils/message_service.dart';

class ExtendBookingPage extends StatefulWidget {
  /// All booking context passed in from the detail page
  final int serviceRequestId;
  final int bookingId;
  final String serviceType;       // 'daily' | 'hourly'
  final String currentEndDate;    // "2026-03-17"
  final String serviceName;
  final String? providerName;
  final String? categoryIconUrl;
  final double currentTotalAmount;

  const ExtendBookingPage({
    super.key,
    required this.serviceRequestId,
    required this.bookingId,
    required this.serviceType,
    required this.currentEndDate,
    required this.serviceName,
    this.providerName,
    this.categoryIconUrl,
    this.currentTotalAmount = 0,
  });

  @override
  State<ExtendBookingPage> createState() => _ExtendBookingPageState();
}

class _ExtendBookingPageState extends State<ExtendBookingPage> {
  late final Razorpay _razorpay;
  ExtendBookingBloc? _bloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bloc ??= context.read<ExtendBookingBloc>();
  }

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      _bloc?.add(ExtendRazorpaySuccess(
        paymentId: r.paymentId ?? '',
        orderId: r.orderId ?? '',
        signature: r.signature ?? '',
      ));
    });
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      if (r.code == 2 || r.message?.toLowerCase().contains('cancelled') == true) return;
      _bloc?.add(ExtendRazorpayFailure(r.message));
    });
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    if (error) {
      MessageService.showError(msg);
    } else {
      MessageService.showSuccess(msg);
    }
  }

  // ── Date picker (daily only) ──────────────────────────────────────────────
  Future<void> _pickDate(BuildContext ctx) async {
    final minDate = _parseDate(widget.currentEndDate).add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: ctx,
      initialDate: minDate,
      firstDate: minDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select New End Date',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: kPrimaryColor),
        ),
        child: child!,
      ),
    );
    if (picked != null && ctx.mounted) {
      ctx.read<ExtendBookingBloc>().add(ExtendDateChanged(picked));
    }
  }

  // ── Price confirmation dialog ─────────────────────────────────────────────
  void _showPriceDialog(BuildContext ctx, ExtendPriceResult price) {
    final state = ctx.read<ExtendBookingBloc>().state as ExtendBookingData;
    final isHourly = widget.serviceType == 'hourly';
    final hours = state.selectedHours ?? 0;
    final diffDays = isHourly
        ? 0
        : (state.extendEndDate?.difference(_parseDate(widget.currentEndDate)).inDays ?? 0);

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _PriceConfirmDialog(
        price: price,
        diffDays: diffDays,
        diffHours: isHourly ? hours : 0,
        serviceType: widget.serviceType,
        onConfirm: () {
          Navigator.of(ctx).pop();
          ctx.read<ExtendBookingBloc>().add(const ExtendSubmitOrder());
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHourly = widget.serviceType == 'hourly';
    return Scaffold(
      backgroundColor: kScaffoldColor,
      appBar: CustomAppBar(title: 'Extend Booking', centerTitle: true),
      body: BlocConsumer<ExtendBookingBloc, ExtendBookingState>(
        listenWhen: (_, next) =>
        next is ExtendOpenRazorpay ||
            next is ExtendPaymentSuccess ||
            next is ExtendSnackBar ||
            next is ExtendShowPriceDialog,
        listener: (ctx, state) {
          if (state is ExtendOpenRazorpay) {
            _razorpay.open(state.options);
          } else if (state is ExtendPaymentSuccess) {
            _snack('✅ Booking extended successfully!');
            Navigator.of(ctx).pop(true);
          } else if (state is ExtendSnackBar) {
            _snack(state.message, error: state.isError);
          } else if (state is ExtendShowPriceDialog) {
            final price = state.data.priceResult;
            if (price != null) _showPriceDialog(ctx, price);
          }
        },
        buildWhen: (_, next) => next is ExtendBookingData,
        builder: (ctx, state) {
          final data = state as ExtendBookingData;
          final hasSelection = isHourly
              ? (data.selectedHours != null && data.selectedHours! > 0)
              : data.extendEndDate != null;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Booking info card ──────────────────────────────
                      _BookingInfoCard(
                        serviceName: widget.serviceName,
                        providerName: widget.providerName,
                        categoryIconUrl: widget.categoryIconUrl,
                        serviceType: widget.serviceType,
                        currentEndDate: widget.currentEndDate,
                        currentTotalAmount: widget.currentTotalAmount,
                      ),
                      SizedBox(height: 20.h),

                      // ── Section title ──────────────────────────────────
                      Row(children: [
                        Container(
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            color: kPrimaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(
                            isHourly ? Icons.access_time_rounded : Icons.date_range_rounded,
                            size: 15.sp,
                            color: kPrimaryColor,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          isHourly ? 'Select Extra Hours' : 'Select New End Date',
                          style: kTextSemiBold2(),
                        ),
                      ]),
                      SizedBox(height: 12.h),

                      // ── Hourly chooser OR date picker ──────────────────
                      if (isHourly) ...[
                        _HourChooser(
                          selectedHours: data.selectedHours ?? 0,
                          onChanged: (h) => ctx
                              .read<ExtendBookingBloc>()
                              .add(ExtendHoursChanged(h)),
                        ),
                      ] else ...[
                        _DatePickerTile(
                          selectedDate: data.extendEndDate,
                          currentEndDate: widget.currentEndDate,
                          onTap: () => _pickDate(ctx),
                        ),
                      ],

                      // ── Summary banner ─────────────────────────────────
                      if (hasSelection) ...[
                        SizedBox(height: 12.h),
                        _SelectionSummary(
                          isHourly: isHourly,
                          selectedHours: data.selectedHours ?? 0,
                          extendEndDate: data.extendEndDate,
                          currentEndDate: widget.currentEndDate,
                        ),
                      ],

                      // ── Error banner ───────────────────────────────────
                      if (data.calculateError != null) ...[
                        SizedBox(height: 12.h),
                        _ErrorBanner(message: data.calculateError!),
                      ],

                      SizedBox(height: 20.h),

                      // ── How it works info ──────────────────────────────
                      _InfoBox(isHourly: isHourly),
                    ],
                  ),
                ),
              ),

              // ── Sticky bottom CTA ──────────────────────────────────────
              _BottomCta(
                canCalculate: hasSelection && !data.isCalculating,
                isCalculating: data.isCalculating,
                isSubmitting: data.isSubmitting || data.isVerifying,
                onCalculate: () =>
                    ctx.read<ExtendBookingBloc>().add(const ExtendCalculatePrice()),
              ),
            ],
          );
        },
      ),
    );
  }

  DateTime _parseDate(String s) {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }
}

// ─── Booking Info Card ────────────────────────────────────────────────────────

class _BookingInfoCard extends StatelessWidget {
  final String serviceName;
  final String? providerName;
  final String? categoryIconUrl;
  final String serviceType;
  final String currentEndDate;
  final double currentTotalAmount;

  const _BookingInfoCard({
    required this.serviceName,
    this.providerName,
    this.categoryIconUrl,
    required this.serviceType,
    required this.currentEndDate,
    required this.currentTotalAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppPadding.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryColor, kSecondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(
              color: categoryIconUrl != null ? kWhiteColor : kWhiteColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: categoryIconUrl != null
                ? ClipOval(
              child: AppCachedImage(
                imageUrl: categoryIconUrl,
                width: 52.w,
                height: 52.w,
                fit: BoxFit.cover,
              ),
            )
                : Icon(Icons.medical_services_rounded, color: kWhiteColor, size: 26.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(serviceName, style: kTextBold1(color: kWhiteColor)),
                if (providerName != null) ...[
                  SizedBox(height: 3.h),
                  Row(children: [
                    Icon(Icons.person_rounded, size: 12.sp, color: kWhiteColor.withValues(alpha: 0.8)),
                    SizedBox(width: 4.w),
                    Text(providerName!, style: kTextNormal0(color: kWhiteColor.withValues(alpha: 0.85))),
                  ]),
                ],
                SizedBox(height: 6.h),
                Row(children: [
                  _Pill(icon: Icons.calendar_today_rounded, label: 'Ends: $currentEndDate'),
                  SizedBox(width: 8.w),
                  _Pill(
                    icon: Icons.repeat_rounded,
                    label: serviceType == 'daily' ? 'Daily' : 'Hourly',
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Pill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
    decoration: BoxDecoration(
      color: kWhiteColor.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20.r),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10.sp, color: kWhiteColor),
      SizedBox(width: 4.w),
      Text(label, style: kTextNormal0(color: kWhiteColor)),
    ]),
  );
}

// ─── Date Picker Tile (daily only) ───────────────────────────────────────────

class _DatePickerTile extends StatelessWidget {
  final DateTime? selectedDate;
  final String currentEndDate;
  final VoidCallback onTap;

  const _DatePickerTile({
    required this.selectedDate,
    required this.currentEndDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDate = selectedDate != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: hasDate ? kPrimaryColor.withValues(alpha: 0.5) : kBorderColor,
            width: hasDate ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: hasDate
                    ? kPrimaryColor.withValues(alpha: 0.1)
                    : kScaffoldColor,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                size: 20.sp,
                color: hasDate ? kPrimaryColor : kTextHintColor,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasDate ? 'New End Date' : 'Tap to select new end date',
                    style: kTextNormal0(color: kTextSecondaryColor),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    hasDate
                        ? AppDateFormatter.dateFromApi(
                        '${selectedDate!.year}-'
                            '${selectedDate!.month.toString().padLeft(2, '0')}-'
                            '${selectedDate!.day.toString().padLeft(2, '0')}')
                        : 'Must be after $currentEndDate',
                    style: hasDate
                        ? kTextSemiBold1(color: kPrimaryColor)
                        : kTextNormal0(color: kTextHintColor),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14.sp,
              color: kTextHintColor,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hour Chooser (hourly bookings) ──────────────────────────────────────────

class _HourChooser extends StatelessWidget {
  final int selectedHours;
  final ValueChanged<int> onChanged;

  // Quick-select presets
  static const _presets = [1, 2, 3, 4, 6, 8, 12, 24];

  const _HourChooser({required this.selectedHours, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: selectedHours > 0 ? kPrimaryColor.withValues(alpha: 0.5) : kBorderColor,
          width: selectedHours > 0 ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stepper row ──────────────────────────────────────────────
          Row(
            children: [
              // Decrement
              _StepBtn(
                icon: Icons.remove_rounded,
                enabled: selectedHours > 1,
                onTap: () => onChanged(selectedHours - 1),
              ),
              // Current value display
              Expanded(
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Text(
                        selectedHours > 0 ? '$selectedHours' : '—',
                        key: ValueKey(selectedHours),
                        style: kTextBold3(
                          color: selectedHours > 0 ? kPrimaryColor : kTextHintColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Text(
                      selectedHours == 1 ? 'hour' : 'hours',
                      style: kTextNormal0(color: kTextSecondaryColor),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Increment
              _StepBtn(
                icon: Icons.add_rounded,
                enabled: selectedHours < 72,
                onTap: () => onChanged(selectedHours < 1 ? 1 : selectedHours + 1),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Divider(height: 1, color: kDividerColor),
          SizedBox(height: 12.h),

          // ── Quick-select preset chips ────────────────────────────────
          Text('Quick select', style: kTextNormal0(color: kTextSecondaryColor)),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: _presets.map((h) {
              final isSelected = selectedHours == h;
              return GestureDetector(
                onTap: () => onChanged(h),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                  decoration: BoxDecoration(
                    color: isSelected ? kPrimaryColor : kScaffoldColor,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: isSelected ? kPrimaryColor : kBorderColor,
                    ),
                  ),
                  child: Text(
                    h == 24 ? '1 day' : '${h}h',
                    style: kTextSemiBold0(
                      color: isSelected ? kWhiteColor : kTextSecondaryColor,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44.w,
        height: 44.w,
        decoration: BoxDecoration(
          color: enabled
              ? kPrimaryColor.withValues(alpha: 0.1)
              : kScaffoldColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled
                ? kPrimaryColor.withValues(alpha: 0.3)
                : kDividerColor,
          ),
        ),
        child: Icon(
          icon,
          size: 20.sp,
          color: enabled ? kPrimaryColor : kTextHintColor,
        ),
      ),
    );
  }
}

// ─── Selection Summary ────────────────────────────────────────────────────────

class _SelectionSummary extends StatelessWidget {
  final bool isHourly;
  final int selectedHours;
  final DateTime? extendEndDate;
  final String currentEndDate;

  const _SelectionSummary({
    required this.isHourly,
    required this.selectedHours,
    required this.extendEndDate,
    required this.currentEndDate,
  });

  @override
  Widget build(BuildContext context) {
    final String extendingLabel;
    final String newEndLabel;

    if (isHourly) {
      extendingLabel = '$selectedHours ${selectedHours == 1 ? 'hour' : 'hours'}';
      if (extendEndDate != null) {
        newEndLabel = AppDateFormatter.dateFromApi(
          '${extendEndDate!.year}-'
              '${extendEndDate!.month.toString().padLeft(2, '0')}-'
              '${extendEndDate!.day.toString().padLeft(2, '0')}',
        );
      } else {
        newEndLabel = '—';
      }
    } else {
      final current = _parseDate(currentEndDate);
      final diffDays = extendEndDate?.difference(current).inDays ?? 0;
      extendingLabel = '$diffDays day${diffDays != 1 ? 's' : ''}';
      newEndLabel = extendEndDate != null
          ? AppDateFormatter.dateFromApi(
        '${extendEndDate!.year}-'
            '${extendEndDate!.month.toString().padLeft(2, '0')}-'
            '${extendEndDate!.day.toString().padLeft(2, '0')}',
      )
          : '—';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: kSuccessColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: kSuccessColor.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(Icons.add_circle_outline_rounded, size: 16.sp, color: kSuccessColor),
        SizedBox(width: 10.w),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: kTextNormal(color: kTextSecondaryColor),
              children: [
                const TextSpan(text: 'Extending by '),
                TextSpan(
                  text: extendingLabel,
                  style: kTextSemiBold(color: kSuccessColor),
                ),
                const TextSpan(text: ' — new end date will be '),
                TextSpan(
                  text: newEndLabel,
                  style: kTextSemiBold(color: kPrimaryColor),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  DateTime _parseDate(String s) {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }
}

// ─── Info Box ─────────────────────────────────────────────────────────────────

class _InfoBox extends StatelessWidget {
  final bool isHourly;
  const _InfoBox({this.isHourly = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppPadding.all(14),
      decoration: BoxDecoration(
        color: kInfoColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: kInfoColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline_rounded, size: 15.sp, color: kInfoColor),
            SizedBox(width: 8.w),
            Text('How Extend Works', style: kTextSemiBold(color: kInfoColor)),
          ]),
          SizedBox(height: 10.h),
          _Step(n: '1', text: isHourly
              ? 'Choose the number of extra hours using the stepper or quick-select chips'
              : 'Select your new end date above'),
          SizedBox(height: 6.h),
          _Step(n: '2', text: 'Tap "Get Price Quote" to see the extension cost'),
          SizedBox(height: 6.h),
          _Step(n: '3', text: 'Confirm the price and complete payment via Razorpay'),
          SizedBox(height: 6.h),
          _Step(n: '4', text: 'Your booking is automatically extended upon success'),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 20.w,
        height: 20.w,
        decoration: BoxDecoration(
          color: kPrimaryColor.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Center(child: Text(n, style: kTextBold0(color: kPrimaryColor))),
      ),
      SizedBox(width: 10.w),
      Expanded(child: Text(text, style: kTextNormal0(color: kTextSecondaryColor))),
    ],
  );
}

// ─── Error Banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
    decoration: BoxDecoration(
      color: kErrorColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10.r),
      border: Border.all(color: kErrorColor.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      Icon(Icons.error_outline_rounded, size: 16.sp, color: kErrorColor),
      SizedBox(width: 8.w),
      Expanded(child: Text(message, style: kTextNormal0(color: kErrorColor))),
    ]),
  );
}

// ─── Bottom CTA ───────────────────────────────────────────────────────────────

class _BottomCta extends StatelessWidget {
  final bool canCalculate;
  final bool isCalculating;
  final bool isSubmitting;
  final VoidCallback onCalculate;

  const _BottomCta({
    required this.canCalculate,
    required this.isCalculating,
    required this.isSubmitting,
    required this.onCalculate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        border: Border(top: BorderSide(color: kDividerColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h + MediaQuery.of(context).padding.bottom),
      child: CustomButton(
        onPressed: (canCalculate && !isSubmitting) ? onCalculate : null,
        title: isCalculating
            ? 'Calculating...'
            : isSubmitting
            ? 'Processing Payment...'
            : 'Get Price Quote',
        iconData: isCalculating || isSubmitting ? null : Icons.calculate_rounded,
        isLoading: isCalculating || isSubmitting,
        backgroundColor: canCalculate ? kPrimaryColor : kButtonDisabledColor,
        textColor: kWhiteColor,
        width: double.infinity,
      ),
    );
  }
}

// ─── Price Confirmation Dialog ────────────────────────────────────────────────

class _PriceConfirmDialog extends StatelessWidget {
  final ExtendPriceResult price;
  final int diffDays;
  final int diffHours;
  final String serviceType;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _PriceConfirmDialog({
    required this.price,
    required this.diffDays,
    required this.diffHours,
    required this.serviceType,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isHourly = serviceType == 'hourly';
    final subtitle = isHourly
        ? '$diffHours ${diffHours == 1 ? 'hour' : 'hours'} extension'
        : '$diffDays day${diffDays != 1 ? 's' : ''} extension';
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────
            Row(children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.receipt_long_rounded, color: kPrimaryColor, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(child: Text('Extension Quote', style: kTextBold2())),
              GestureDetector(
                onTap: onCancel,
                child: Icon(Icons.close_rounded, size: 20.sp, color: kTextSecondaryColor),
              ),
            ]),
            SizedBox(height: 4.h),
            Text(subtitle, style: kTextNormal(color: kTextSecondaryColor)),
            SizedBox(height: 18.h),

            // ── Price breakdown ─────────────────────────────────────
            Container(
              padding: AppPadding.all(14),
              decoration: BoxDecoration(
                color: kScaffoldColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: kDividerColor),
              ),
              child: Column(children: [
                _PriceRow(label: 'Base Price', value: '₹${price.basePrice.toStringAsFixed(2)}'),
                SizedBox(height: 6.h),
                Divider(height: 1, color: kDividerColor),
                SizedBox(height: 6.h),
                _PriceRow(label: 'Distance Charge', value: '₹${price.distanceCharge.toStringAsFixed(2)}'),
                SizedBox(height: 6.h),
                Divider(height: 1, color: kDividerColor),
                SizedBox(height: 6.h),
                _PriceRow(
                  label: 'GST (${price.gstPercentage.toStringAsFixed(0)}%)',
                  value: '₹${price.gstAmount.toStringAsFixed(2)}',
                ),
                SizedBox(height: 10.h),
                Divider(height: 1, color: kBorderColor),
                SizedBox(height: 10.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Payable', style: kTextBold1()),
                    Text(
                      '₹${price.totalAmount.toStringAsFixed(2)}',
                      style: kTextBold2(color: kPrimaryColor),
                    ),
                  ],
                ),
              ]),
            ),
            SizedBox(height: 20.h),

            // ── Actions ─────────────────────────────────────────────
            Row(children: [
              Expanded(
                child: CustomButton(
                  onPressed: onCancel,
                  title: 'Cancel',
                  backgroundColor: kScaffoldColor,
                  textColor: kTextSecondaryColor,
                  borderSide: BorderSide(color: kBorderColor),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: CustomButton(
                  onPressed: onConfirm,
                  title: 'Pay Now',
                  backgroundColor: kPrimaryColor,
                  textColor: kWhiteColor,
                  iconData: Icons.lock_rounded,
                  iconColor: kWhiteColor,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  const _PriceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: kTextNormal(color: kTextSecondaryColor)),
      Text(value, style: kTextSemiBold()),
    ],
  );
}