import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../bloc/payment_bloc.dart';
import '../data/payment_repository.dart';

class OffersBottomSheet extends StatelessWidget {
  final double currentAmount;
  final Function(String) onSelect;

  const OffersBottomSheet({super.key, required this.currentAmount, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────────────────────────
          Container(
            width: 40.w,
            height: 4.h,
            margin: EdgeInsets.symmetric(vertical: 14.h),
            decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(2.r)),
          ),

          // ── Header ───────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 0, 12.w, 14.h),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10.r)),
                  child: Icon(Icons.local_offer_rounded, size: 18.sp, color: kPrimaryColor),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Promo Codes', style: kTextBold1()),
                      Text('Tap a promo to apply', style: kTextNormal0(color: kTextHintColor)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(color: kScaffoldColor, shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, size: 18.sp, color: kTextSecondaryColor),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: kDividerColor),

          // ── List ─────────────────────────────────────────────────────────
          Flexible(
            child: SafeArea(
              child: BlocBuilder<PaymentBloc, PaymentState>(
                builder: (context, state) {
                  final data = state as PaymentSheetData;

                  if (data.promosLoading) {
                    return _PromoShimmer();
                  }

                  if (data.availablePromos.isEmpty) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 48.h, horizontal: 24.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.all(22.w),
                            decoration: BoxDecoration(
                              color: kScaffoldColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: kBorderColor),
                            ),
                            child: Icon(Icons.local_offer_outlined, size: 38.sp, color: kTextHintColor),
                          ),
                          SizedBox(height: 18.h),
                          Text('No promos available', style: kTextSemiBold1(color: kTextPrimaryColor)),
                          SizedBox(height: 4.h),
                          Text(
                            'Check back later for new promos',
                            style: kTextNormal0(color: kTextHintColor),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  // Active promos first, expired last
                  final sorted = [...data.availablePromos]
                    ..sort((a, b) {
                      if (a.isExpired == b.isExpired) return 0;
                      return a.isExpired ? 1 : -1;
                    });

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 24.h),
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) => SizedBox(height: 14.h),
                    itemBuilder: (context, index) {
                      final promo = sorted[index];
                      return _PromoCard(
                        promo: promo,
                        isApplied: data.appliedCode == promo.code,
                        currentAmount: currentAmount,
                        onTap: () {
                          onSelect(promo.code);
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─── Promo Card ───────────────────────────────────────────────────────────────

class _PromoCard extends StatelessWidget {
  final AvailablePromoCode promo;
  final double currentAmount;
  final bool isApplied;
  final VoidCallback onTap;

  const _PromoCard({required this.promo, required this.currentAmount, required this.isApplied, required this.onTap});

  static String _discountDisplay(String? raw) {
    if (raw == null) return '';
    if (raw.endsWith('%')) {
      final n = double.tryParse(raw.replaceAll('%', '').trim());
      if (n != null) return '${n % 1 == 0 ? n.toInt() : n}%';
    }
    // Fixed: "₹100.00" → "₹100"
    final numPart = raw.replaceAll('₹', '').trim();
    final n = double.tryParse(numPart);
    if (n != null) return '₹${n % 1 == 0 ? n.toInt() : n}';
    return raw;
  }

  String? _validUntilText() {
    final raw = promo.validUntilFormatted;
    if (raw == null || raw.isEmpty) return null;
    if (raw.toLowerCase().contains('no expiry') || raw.toLowerCase().contains('no_expiry')) return null;
    try {
      final datePart = raw.split(' ')[0];
      final bits = datePart.split('-');
      if (bits.length == 3) {
        final dt = bits[0].length == 4
            ? DateTime(int.parse(bits[0]), int.parse(bits[1]), int.parse(bits[2]))
            : DateTime(int.parse(bits[2]), int.parse(bits[1]), int.parse(bits[0]));
        return DateFormat('dd MMM yyyy').format(dt);
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool isEligible = currentAmount >= promo.minOrderValue;
    final bool isDisabled = promo.isExpired || !isEligible || !promo.isActive;
    final bool isPercentage = (promo.discountType ?? '').toLowerCase() == 'percentage';

    final Color accent = isApplied
        ? kSuccessColor
        : (promo.isExpired || !promo.isActive
            ? kTextHintColor
            : (isEligible ? kPrimaryColor : const Color(0xFFF59E0B)));

    final String discount = _discountDisplay(promo.discountValueText);
    final String? validTill = _validUntilText();
    final bool showTitle = promo.title != null &&
        promo.title!.isNotEmpty &&
        promo.title!.toUpperCase() != promo.code.toUpperCase();

    return Opacity(
      opacity: promo.isExpired ? 0.6 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isApplied
                ? kSuccessColor.withValues(alpha: 0.5)
                : (isDisabled ? kBorderColor : accent.withValues(alpha: 0.18)),
            width: isApplied ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isApplied ? kSuccessColor.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: InkWell(
            onTap: isDisabled || isApplied ? null : onTap,
            borderRadius: BorderRadius.circular(16.r),
            splashColor: accent.withValues(alpha: 0.06),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Main body ──────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 14.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Left: discount badge ──
                      Container(
                        width: 68.w,
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: accent.withValues(alpha: 0.15)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              discount,
                              style: kTextBold(color: accent).copyWith(fontSize: 18.sp, height: 1.1),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              'OFF',
                              style: kTextSemiBold(color: accent.withValues(alpha: 0.7)).copyWith(fontSize: 10.sp, letterSpacing: 1),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(width: 14.w),

                      // ── Right: code + title + desc ──
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Code chip + copy
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: promo.code));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Code copied!', style: kTextNormal(color: kWhiteColor)),
                                    backgroundColor: kPrimaryColor,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 1),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                    margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                                  ),
                                );
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    promo.code,
                                    style: kTextBold(color: accent).copyWith(fontSize: 15.sp, letterSpacing: 0.8),
                                  ),
                                  SizedBox(width: 6.w),
                                  Icon(Icons.copy_rounded, size: 13.sp, color: accent.withValues(alpha: 0.6)),
                                ],
                              ),
                            ),

                            if (showTitle) ...[
                              SizedBox(height: 3.h),
                              Text(
                                promo.title!,
                                style: kTextSemiBold(color: isDisabled ? kTextHintColor : kTextPrimaryColor).copyWith(fontSize: 13.sp),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],

                            if (promo.description != null && promo.description!.isNotEmpty) ...[
                              SizedBox(height: 3.h),
                              Text(
                                promo.description!,
                                style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 11.5.sp),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Ineligibility nudge ────────────────────────────────
                if (!isEligible && !promo.isExpired && promo.isActive)
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 13.sp, color: const Color(0xFFF59E0B)),
                          SizedBox(width: 6.w),
                          Text(
                            'Add ₹${(promo.minOrderValue - currentAmount).toInt()} more to unlock',
                            style: kTextSemiBold(color: const Color(0xFFB45309)).copyWith(fontSize: 11.sp),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Footer strip ───────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: kScaffoldColor,
                    border: Border(top: BorderSide(color: kDividerColor, width: 0.8)),
                  ),
                  padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
                  child: Row(
                    children: [
                      // Info tags
                      Expanded(
                        child: Wrap(
                          spacing: 8.w,
                          runSpacing: 4.h,
                          children: [
                            if (promo.minOrderValue > 0)
                              _InfoTag(
                                icon: Icons.shopping_bag_outlined,
                                label: 'Min ₹${promo.minOrderValue.toInt()}',
                              ),
                            if (isPercentage && promo.maxDiscount != null && promo.maxDiscount! > 0)
                              _InfoTag(
                                icon: Icons.savings_outlined,
                                label: 'Upto ₹${promo.maxDiscount!.toInt()} off',
                              ),
                            if (validTill != null)
                              _InfoTag(
                                icon: Icons.calendar_today_outlined,
                                label: promo.isExpiringSoon ? 'Ends $validTill' : 'Till $validTill',
                                color: promo.isExpiringSoon ? const Color(0xFFF59E0B) : kTextHintColor,
                              ),
                            if (promo.isExpired)
                              _InfoTag(icon: Icons.block_rounded, label: 'EXPIRED', color: kErrorColor),
                            if (!promo.isExpired && promo.isExpiringSoon && validTill == null)
                              _InfoTag(icon: Icons.bolt_rounded, label: 'Ends soon', color: const Color(0xFFF59E0B)),
                          ],
                        ),
                      ),

                      SizedBox(width: 10.w),

                      // Apply button
                      _ApplyButton(
                        isApplied: isApplied,
                        isDisabled: isDisabled,
                        isExpired: promo.isExpired,
                        isEligible: isEligible,
                        onTap: onTap,
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

// ─── Info tag (footer strip) ──────────────────────────────────────────────────

class _InfoTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoTag({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? kTextHintColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11.sp, color: c),
        SizedBox(width: 3.w),
        Text(label, style: kTextNormal0(color: c).copyWith(fontSize: 11.sp)),
      ],
    );
  }
}

// ─── Apply button ─────────────────────────────────────────────────────────────

class _ApplyButton extends StatelessWidget {
  final bool isApplied;
  final bool isDisabled;
  final bool isExpired;
  final bool isEligible;
  final VoidCallback onTap;

  const _ApplyButton({required this.isApplied, required this.isDisabled, required this.isExpired, required this.isEligible, required this.onTap});

  @override
  Widget build(BuildContext context) {
    String label;
    Color bg;
    Color textColor;

    if (isApplied) {
      label = '✓ Applied';
      bg = kSuccessColor;
      textColor = kWhiteColor;
    } else if (isExpired) {
      label = 'Expired';
      bg = kScaffoldColor;
      textColor = kTextHintColor;
    } else if (!isEligible) {
      label = 'Locked';
      bg = kScaffoldColor;
      textColor = kTextHintColor;
    } else {
      label = 'Apply';
      bg = kPrimaryColor;
      textColor = kWhiteColor;
    }

    return GestureDetector(
      onTap: isDisabled || isApplied ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24.r),
          border: isDisabled && !isApplied ? Border.all(color: kBorderColor) : null,
          boxShadow: isDisabled || isApplied
              ? null
              : [BoxShadow(color: kPrimaryColor.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Text(
          label,
          style: kTextSemiBold(color: textColor).copyWith(fontSize: 13.sp),
        ),
      ),
    );
  }
}

// ─── Promo Shimmer ────────────────────────────────────────────────────────────

class _PromoShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 24.h),
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFEEEEEE),
        highlightColor: const Color(0xFFF8F8F8),
        child: Column(
          children: List.generate(3, (i) => _ShimmerCard(i: i)),
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final int i;
  const _ShimmerCard({required this.i});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 14.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Discount badge placeholder
                Container(
                  width: 68.w,
                  height: 58.h,
                  decoration: BoxDecoration(
                    color: kWhiteColor,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Code line
                      Container(width: 120.w, height: 14.h, color: kWhiteColor),
                      SizedBox(height: 8.h),
                      // Title line
                      Container(width: double.infinity, height: 11.h, color: kWhiteColor),
                      SizedBox(height: 6.h),
                      Container(width: (i % 2 == 0 ? 160.w : 120.w), height: 10.h, color: kWhiteColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Footer strip
          Container(
            height: 36.h,
            decoration: BoxDecoration(
              color: kWhiteColor,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16.r)),
            ),
          ),
        ],
      ),
    );
  }
}

