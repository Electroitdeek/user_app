import 'dart:async';

import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/shared/utils/consent_helper.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/services/launch_url_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../data/models/provider_service_request_model.dart';
import '../data/models/sub_block_model.dart';

// ─── RequestScheduleBottomSheet ─────────────────────────────────────────────

class RequestScheduleBottomSheet extends StatefulWidget {
  final ProviderServiceRequestModel request;
  final List<SubBlock> blocks;
  final int stage;
  final void Function(List<int> selectedIds) onAccept;

  const RequestScheduleBottomSheet({
    super.key,
    required this.request,
    required this.blocks,
    required this.stage,
    required this.onAccept,
  });

  static Future<void> show({
    required BuildContext context,
    required ProviderServiceRequestModel request,
    required void Function(List<int> selectedIds) onAccept,
    int? overrideStage,
  }) {
    final blocks = request.subBlocks;
    var stage = overrideStage ?? request.requestStage;
    final availableBlocks = blocks.where((b) => !b.isAssigned).toList();
    if ((stage == 2 || stage == 3) && availableBlocks.length <= 1) stage = 1;

    // ── Single-session fast path: skip schedule view → direct confirmation ──
    if (availableBlocks.length == 1 && stage == 1) {
      final block = availableBlocks.first;
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
        builder: (_) => BookingConfirmationSheet(
          selected: [block],
          payout: block.providerPayout,
          request: request,
          onConfirm: () => onAccept([block.id]),
        ),
      );
    }

    // ── Multi-session / staged: full schedule selection ──────────────────────
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      useSafeArea: true,
      builder: (_) =>
          RequestScheduleBottomSheet(request: request, blocks: blocks, stage: stage, onAccept: onAccept),
    );
  }

  @override
  State<RequestScheduleBottomSheet> createState() => _RequestScheduleBottomSheetState();
}

class _RequestScheduleBottomSheetState extends State<RequestScheduleBottomSheet>
    with SingleTickerProviderStateMixin {
  // Stage 2 selection: 1=first half, 2=second half
  int _selectedHalf = 0;

  // Stage 3 selection: custom date ids
  final Set<int> _selectedIds = {};

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    // Stage 1 and 4 auto-select all available blocks
    if (widget.stage == 1 || widget.stage == 4) {
      _selectedIds.addAll(widget.blocks.where((b) => !b.isAssigned).map((b) => b.id));
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ─── computed properties ─────────────────────────────────────────────────

  List<int> get _effectiveIds {
    switch (widget.stage) {
      case 1:
        return widget.blocks.map((b) => b.id).toList();
      case 2:
        if (_selectedHalf == 0) return [];
        final available = widget.blocks.where((b) => !b.isAssigned).toList();
        final half = available.length ~/ 2;
        return _selectedHalf == 1
            ? available.take(half).map((b) => b.id).toList()
            : available.skip(half).map((b) => b.id).toList();
      case 3:
        return _selectedIds.toList();
      case 4:
        return widget.blocks.where((b) => !b.isAssigned).map((b) => b.id).toList();
      default:
        return widget.blocks.map((b) => b.id).toList();
    }
  }

  double get _selectedPayout {
    final ids = Set<int>.from(_effectiveIds);
    return widget.blocks.where((b) => ids.contains(b.id)).fold(0.0, (s, b) => s + b.providerPayout);
  }

  bool get _canAccept {
    switch (widget.stage) {
      case 2:
        return _selectedHalf != 0;
      case 3:
        return _selectedIds.isNotEmpty;
      default:
        return true;
    }
  }

  Color get _stageAccent {
    switch (widget.stage) {
      case 1:
        return kSuccessColor;
      case 2:
        return kPrimaryColor;
      case 3:
        return kSecondaryColor;
      case 4:
        return kAccentColor;
      default:
        return kPrimaryColor;
    }
  }

  String get _stageHeading {
    switch (widget.stage) {
      case 1:
        return 'FULL BOOKING';
      case 2:
        return 'CHOOSE YOUR PERIOD';
      case 3:
        return 'SELECT YOUR DATES';
      case 4:
        return 'LAST SLOTS REMAINING';
      default:
        return 'SELECT SCHEDULE';
    }
  }

  // ─── helpers ─────────────────────────────────────────────────────────────

  void _onAcceptTap() {
    final ids = _effectiveIds;
    if (ids.isEmpty) return;
    HapticFeedback.mediumImpact();
    _showConfirmation(ids);
  }

  void _showConfirmation(List<int> ids) {
    final ids0 = Set<int>.from(ids);
    final selected = widget.blocks.where((b) => ids0.contains(b.id)).toList();
    final payout = selected.fold(0.0, (s, b) => s + b.providerPayout);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => BookingConfirmationSheet(
        selected: selected,
        payout: payout,
        request: widget.request,
        onConfirm: () {
          // BookingConfirmationSheet already pops itself in the button handler
          Navigator.pop(context); // pop RequestScheduleBottomSheet
          widget.onAccept(ids);
        },
      ),
    );
  }

  // ─── build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => _buildSheet(scrollCtrl),
    );
  }

  Widget _buildSheet(ScrollController scrollCtrl) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 28, offset: const Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHandle(),
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
                child: _buildStageContent(),
              ),
            ),
            _buildActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() => Center(
    child: Container(
      margin: EdgeInsets.only(top: 12.h, bottom: 6.h),
      width: 40.w,
      height: 4.h,
      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2.r)),
    ),
  );

  Widget _buildHeader() {
    final r = widget.request;
    final perDay = widget.blocks.isNotEmpty ? widget.blocks.first.providerPayout : 0.0;
    final shiftLabel = r.formattedShiftType;
    final hasShift = r.shiftType != null;

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 14.h),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: _stageAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        _stageHeading,
                        style: kTextBold0(color: _stageAccent).copyWith(letterSpacing: 0.6),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(r.serviceCategoryName, style: kTextBold2(), overflow: TextOverflow.ellipsis),
                    SizedBox(height: 6.h),
                    if (hasShift) ...[
                      Row(
                        children: [
                          Icon(
                            shiftLabel == 'Night' ? Icons.nightlight_round : Icons.wb_sunny_outlined,
                            size: 12.sp,
                            color: kPrimaryColor,
                          ),
                          SizedBox(width: 4.w),
                          Text(shiftLabel, style: kTextSemiBold0(color: kPrimaryColor)),
                        ],
                      ),
                      SizedBox(height: 4.h),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              _buildEarningsPill(perDay),
            ],
          ),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 12.sp, color: Colors.grey.shade500),
              SizedBox(width: 5.w),
              Expanded(
                child: Text(
                  '${widget.blocks.length} sessions  •  '
                  '${AppDateFormatter.dayMonthShort(r.startDate)} – ${AppDateFormatter.dayMonthShort(r.endDate)}',
                  style: kTextNormal0(color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsPill(double perDay) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16A34A), Color(0xFF15803D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(color: kSuccessColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(NumberUtils.formatCurrency(perDay), style: kTextBold1(color: Colors.white)),
          Text(
            'per day',
            style: kTextNormal0(color: Colors.white70).copyWith(fontSize: 10.sp),
          ),
        ],
      ),
    );
  }

  // ─── stage content ───────────────────────────────────────────────────────

  Widget _buildStageContent() {
    switch (widget.stage) {
      case 1:
        return _buildStage1();
      case 2:
        return _buildStage2();
      case 3:
        return _buildStage3();
      case 4:
        return _buildStage4();
      default:
        return _buildStage1();
    }
  }

  // Stage 1 — full booking commitment summary
  Widget _buildStage1() {
    final r = widget.request;
    final blocks = widget.blocks;
    final totalSessions = blocks.length;
    final totalPayout = blocks.fold(0.0, (s, b) => s + b.providerPayout);
    final perSession = blocks.isNotEmpty ? blocks.first.providerPayout : 0.0;
    final startLabel = AppDateFormatter.dayMonthShort(r.startDate);
    final endLabel = AppDateFormatter.dayMonthShort(r.endDate);
    final durationDays = r.durationDays ?? totalSessions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Commitment header ──
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: kSuccessColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(Icons.check_circle_rounded, color: kSuccessColor, size: 18.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Full Booking', style: kTextSemiBold1()),
                  Text(
                    'You\'re committing to the entire schedule',
                    style: kTextNormal0(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),

        // ── Date range + stats card ──
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: Column(
            children: [
              // Date range
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'START',
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(startLabel, style: kTextSemiBold1()),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Icon(Icons.arrow_forward_rounded, size: 14.sp, color: Colors.grey.shade400),
                      SizedBox(height: 2.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          '$durationDays Days',
                          style: kTextSemiBold0(color: kPrimaryColor).copyWith(fontSize: 11.sp),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'END',
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(endLabel, style: kTextSemiBold1()),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Divider(height: 1, color: const Color(0xFFBAE6FD)),
              SizedBox(height: 12.h),

              // Stats row
              Row(
                children: [
                  _statCell(Icons.event_repeat_rounded, '$totalSessions', 'Sessions', kPrimaryColor),
                  _vDivider(),
                  _statCell(Icons.wb_sunny_outlined, '$durationDays', 'Days', Colors.orange.shade600),
                  _vDivider(),
                  _statCell(
                    Icons.account_balance_wallet_outlined,
                    NumberUtils.formatCurrency(perSession),
                    '/session',
                    kSuccessColor,
                  ),
                ],
              ),
              SizedBox(height: 14.h),

              // Total payout
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 16.sp),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text('Total Booking Payout', style: kTextSemiBold1(color: Colors.white)),
                    ),
                    Text(NumberUtils.formatCurrency(totalPayout), style: kTextBold2(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 14.h),

        // ── Commitment notice ──
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16.sp, color: Colors.amber.shade700),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'Accepting commits you to all $totalSessions sessions across $durationDays days. Cancellations may incur penalties.',
                  style: kTextNormal(color: Colors.amber.shade900).copyWith(fontSize: 12.sp, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20.h),
        _sectionHeader(
          Icons.calendar_month_rounded,
          kSuccessColor,
          'Full Schedule',
          'View all sessions you are committing to',
        ),
        SizedBox(height: 12.h),
        _fullTimeline(blocks, accent: kSuccessColor, compact: true),
      ],
    );
  }

  Widget _statCell(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(height: 4.h),
          Text(value, style: kTextBold1(color: color)),
          Text(
            label,
            style: kTextNormal0(color: Colors.grey.shade500).copyWith(fontSize: 10.sp),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 40.h, color: Colors.grey.shade200);

  // Stage 2 — first/second half selection
  Widget _buildStage2() {
    final available = widget.blocks.where((b) => !b.isAssigned).toList();
    final half = available.length ~/ 2;
    final firstBlocks = available.take(half).toList();
    final secondBlocks = available.skip(half).toList();
    final firstPayout = firstBlocks.fold(0.0, (s, b) => s + b.providerPayout);
    final secondPayout = secondBlocks.fold(0.0, (s, b) => s + b.providerPayout);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          Icons.call_split_rounded,
          kPrimaryColor,
          'Split Booking',
          'Select either the first or second half of the schedule',
        ),
        SizedBox(height: 16.h),
        _halfSelectionCard(1, firstBlocks, firstPayout),
        SizedBox(height: 12.h),
        _halfSelectionCard(2, secondBlocks, secondPayout),
        SizedBox(height: 20.h),
        if (_selectedHalf != 0) ...[
          _sectionHeader(Icons.list_alt_rounded, kPrimaryColor, 'Selected Schedule', ''),
          SizedBox(height: 12.h),
          _fullTimeline(_selectedHalf == 1 ? firstBlocks : secondBlocks, accent: kPrimaryColor, compact: true),
        ],
      ],
    );
  }

  Widget _halfSelectionCard(int half, List<SubBlock> blocks, double payout) {
    final isSelected = _selectedHalf == half;
    final label = half == 1 ? 'First Half' : 'Second Half';
    final icon = half == 1 ? Icons.looks_one_rounded : Icons.looks_two_rounded;
    final start = blocks.isNotEmpty ? blocks.first.dateLabel : '—';
    final end = blocks.isNotEmpty ? blocks.last.dateLabel : '—';

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedHalf = isSelected ? 0 : half);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: isSelected ? kPrimaryColor : Colors.grey.shade200, width: isSelected ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: isSelected ? kPrimaryColor.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSelected ? 14 : 6,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46.w,
              height: 46.w,
              decoration: BoxDecoration(
                color: isSelected ? kPrimaryColor : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade500, size: 22.sp),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: kTextSemiBold1(color: isSelected ? kPrimaryColor : Colors.grey.shade800)),
                  SizedBox(height: 3.h),
                  Text(
                    '$start – $end  •  ${blocks.length} session',
                    style: kTextNormal0(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  NumberUtils.formatCurrency(payout),
                  style: kTextBold1(color: isSelected ? kSuccessColor : Colors.grey.shade700),
                ),
                Text(
                  'earnings',
                  style: kTextNormal0(color: Colors.grey.shade400).copyWith(fontSize: 10.sp),
                ),
              ],
            ),
            SizedBox(width: 10.w),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22.w,
              height: 22.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? kPrimaryColor : Colors.transparent,
                border: Border.all(color: isSelected ? kPrimaryColor : Colors.grey.shade300, width: 2),
              ),
              child: isSelected ? Icon(Icons.check, size: 13.sp, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }

  // Stage 3 — multi-date calendar grid
  Widget _buildStage3() {
    final available = widget.blocks.where((b) => !b.isAssigned).toList();
    final allSelected = _selectedIds.length == available.length;
    final selPayout = _selectedIds.isNotEmpty
        ? widget.blocks.where((b) => _selectedIds.contains(b.id)).fold(0.0, (s, b) => s + b.providerPayout)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          Icons.edit_calendar_rounded,
          kSecondaryColor,
          'Custom Selection',
          'Tap each date you are available for',
        ),
        SizedBox(height: 8.h),
        // Select all row
        Row(
          children: [
            Text(
              '${_selectedIds.length} of ${available.length} selected',
              style: kTextMedium(color: Colors.grey.shade700),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  if (allSelected) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds.addAll(available.map((b) => b.id));
                  }
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: allSelected ? kSecondaryColor : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  allSelected ? 'Deselect All' : 'Select All',
                  style: kTextMedium(
                    color: allSelected ? Colors.white : Colors.grey.shade700,
                  ).copyWith(fontSize: 12.sp),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        // Date grid — group by month
        ...() {
          final grouped = <String, List<SubBlock>>{};
          for (final b in available) {
            grouped.putIfAbsent(b.monthLabel, () => []).add(b);
          }
          return grouped.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 10.h, top: 4.h),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: kSecondaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      entry.key,
                      style: kTextSemiBold0(color: kSecondaryColor).copyWith(letterSpacing: 0.4),
                    ),
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6.h,
                    crossAxisSpacing: 4.w,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: entry.value.length,
                  itemBuilder: (_, i) => _dateCell(entry.value[i]),
                ),
                SizedBox(height: 12.h),
              ],
            );
          });
        }(),
        // Selection summary
        if (_selectedIds.isNotEmpty)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: kSecondaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: kSecondaryColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.event_available_rounded, color: kSecondaryColor, size: 20.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text('${_selectedIds.length} days selected', style: kTextMedium(color: kSecondaryColor)),
                ),
                Text(NumberUtils.formatCurrency(selPayout), style: kTextBold1(color: kSuccessColor)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dateCell(SubBlock b) {
    final isSelected = _selectedIds.contains(b.id);
    final day = b.parsedDate?.day ?? 0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (isSelected) {
            _selectedIds.remove(b.id);
          } else {
            _selectedIds.add(b.id);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected ? kSecondaryColor : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: isSelected ? kSecondaryColor : Colors.grey.shade200),
          boxShadow: isSelected
              ? [BoxShadow(color: kSecondaryColor.withValues(alpha: 0.25), blurRadius: 6)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              b.dayAbbr,
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white70 : Colors.grey.shade400,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              '$day',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Stage 4 — urgent last slots
  Widget _buildStage4() {
    final available = widget.blocks.where((b) => !b.isAssigned).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Urgency banner
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: kAccentColor.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: kAccentColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              ScaleTransition(
                scale: Tween<double>(
                  begin: 0.9,
                  end: 1.1,
                ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
                child: Icon(Icons.alarm_rounded, color: kAccentColor, size: 24.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Last Slots Remaining!', style: kTextSemiBold1(color: kAccentColor)),
                    SizedBox(height: 2.h),
                    Text(
                      '${available.length} sessions need urgent fill',
                      style: kTextNormal0(color: Colors.orange.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        _fullTimeline(available, accent: kAccentColor),
      ],
    );
  }

  // ─── timeline helper ─────────────────────────────────────────────────────

  Widget _fullTimeline(List<SubBlock> blocks, {required Color accent, bool compact = false}) {
    if (blocks.isEmpty) return const SizedBox.shrink();

    final grouped = <String, List<SubBlock>>{};
    for (final b in blocks) {
      grouped.putIfAbsent(b.monthLabel, () => []).add(b);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(entry.key, style: kTextSemiBold0(color: accent).copyWith(letterSpacing: 0.4)),
              ),
            ),
            ...entry.value.asMap().entries.map((e) {
              final b = e.value;
              final isLast = e.key == entry.value.length - 1;
              return _timelineRow(b, accent: accent, isLast: isLast, compact: compact);
            }),
            SizedBox(height: 8.h),
          ],
        );
      }).toList(),
    );
  }

  Widget _timelineRow(SubBlock b, {required Color accent, required bool isLast, bool compact = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20.w,
            child: Column(
              children: [
                SizedBox(height: 5.h),
                Container(
                  width: 9.w,
                  height: 9.w,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                ),
                if (!isLast) Expanded(child: Container(width: 1.5, color: accent.withValues(alpha: 0.2))),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: compact ? 8.h : 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${b.dayAbbr}, ${b.dateLabel}',
                    style: kTextSemiBold(color: Colors.grey.shade800).copyWith(fontSize: compact ? 12.sp : 13.sp),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    b.timeRange,
                    style: kTextNormal0(color: Colors.grey.shade500).copyWith(fontSize: 11.sp),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 2.h),
            child: Text(
              NumberUtils.formatCurrency(b.providerPayout),
              style: kTextSemiBold(color: kSuccessColor).copyWith(fontSize: compact ? 12.sp : 13.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, Color color, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, color: color, size: 18.sp),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: kTextSemiBold1()),
              if (subtitle.isNotEmpty) Text(subtitle, style: kTextNormal0(color: Colors.grey.shade500)),
            ],
          ),
        ),
      ],
    );
  }

  // ─── action bar ──────────────────────────────────────────────────────────

  Widget _buildActionBar() {
    final count = _effectiveIds.length;
    final payout = _selectedPayout;

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Live earnings bar
            if (count > 0)
              Container(
                margin: EdgeInsets.only(bottom: 10.h),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FFF4),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, color: const Color(0xFF16A34A), size: 18.sp),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        '$count days selected',
                        style: kTextMedium(color: const Color(0xFF15803D)).copyWith(fontSize: 13.sp),
                      ),
                    ),
                    Text(
                      '${NumberUtils.formatCurrency(count > 0 ? payout / count : 0)}/day',
                      style: kTextNormal0(color: const Color(0xFF16A34A)),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      '→',
                      style: TextStyle(color: const Color(0xFF16A34A), fontSize: 13.sp),
                    ),
                    SizedBox(width: 6.w),
                    Text(NumberUtils.formatCurrency(payout), style: kTextBold1(color: const Color(0xFF15803D))),
                  ],
                ),
              )
            else if (widget.stage == 2 || widget.stage == 3)
              Container(
                margin: EdgeInsets.only(bottom: 10.h),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade500, size: 18.sp),
                    SizedBox(width: 10.w),
                    Text(
                      widget.stage == 2 ? 'Select a half to see earnings' : 'Tap dates to calculate earnings',
                      style: kTextNormal(color: Colors.grey.shade500).copyWith(fontSize: 13.sp),
                    ),
                  ],
                ),
              ),
            // CTA button
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton.icon(
                onPressed: _canAccept ? _onAcceptTap : null,
                icon: Icon(Icons.check_circle_rounded, size: 20.sp, color: Colors.white),
                label: Text(_ctaLabel, style: kTextBold1(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canAccept ? kSuccessColor : Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                  elevation: _canAccept ? 3 : 0,
                  shadowColor: kSuccessColor.withValues(alpha: 0.35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _ctaLabel {
    if (!_canAccept) {
      return widget.stage == 2 ? 'Select a Period First' : 'Select Dates First';
    }
    final c = _effectiveIds.length;
    final p = _selectedPayout;
    if (c == widget.blocks.length && widget.stage == 1) {
      return 'Accept Full Booking  •  ${NumberUtils.formatCurrency(p)}';
    }
    if (widget.stage == 4) return 'Accept Remaining $c Slots  •  ${NumberUtils.formatCurrency(p)}';
    return 'Accept $c Days  •  ${NumberUtils.formatCurrency(p)}';
  }
}

// ─── Confirmation Sheet ───────────────────────────────────────────────────────

class BookingConfirmationSheet extends StatefulWidget {
  final List<SubBlock> selected;
  final double payout;
  final ProviderServiceRequestModel request;
  final VoidCallback onConfirm;

  const BookingConfirmationSheet({
    super.key,
    required this.selected,
    required this.payout,
    required this.request,
    required this.onConfirm,
  });

  @override
  State<BookingConfirmationSheet> createState() => BookingConfirmationSheetState();
}

class BookingConfirmationSheetState extends State<BookingConfirmationSheet> {
  bool _agreed = false;
  bool _submitting = false;

  late final TapGestureRecognizer _termsRecognizer = TapGestureRecognizer()
    ..onTap = () => ConsentHelper.show(
          context: context,
          consentType: 'booking_acceptance',
          viewOnly: true,
        );

  late final TapGestureRecognizer _confirmRecognizer = TapGestureRecognizer()
    ..onTap = () => setState(() => _agreed = !_agreed);

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _confirmRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final first = widget.selected.isNotEmpty ? widget.selected.first : null;
    final last = widget.selected.isNotEmpty ? widget.selected.last : null;
    final startTime = r.startTime ?? '';
    final endTime = r.endTime ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle + close ──
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 0),
            child: Row(
              children: [
                SizedBox(width: 32.w),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, size: 16.sp, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable content ──
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(color: kSuccessColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(Icons.task_alt_rounded, color: kSuccessColor, size: 28.sp),
                  ),
                  SizedBox(height: 12.h),
                  Text('Confirm Booking', style: kTextBold2()),
                  SizedBox(height: 4.h),
                  Text('Review the details before accepting', style: kTextNormal(color: Colors.grey.shade500)),
                  SizedBox(height: 20.h),
                  // Summary card
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Column(
                      children: [
                        _row(
                          Icons.calendar_today,
                          'Date${(first != null && last != null && first.dateLabel != last.dateLabel) ? 's' : ''}',
                          first == null
                              ? '—'
                              : (last != null && first.dateLabel != last.dateLabel)
                              ? '${first.dateLabel} – ${last.dateLabel}'
                              : first.dateLabel,
                        ),
                        _divider(),
                        _row(
                          Icons.event_repeat_rounded,
                          'Sessions',
                          '${widget.selected.length} ${widget.selected.length == 1 ? 'session' : 'sessions'}',
                        ),
                        _divider(),
                        _shiftRow(r, startTime, endTime),
                        _divider(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _row(
                                Icons.social_distance_outlined,
                                'Distance',
                                '${r.distanceKm.toStringAsFixed(2)} km away',
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => LaunchUrlService.launchGoogleMaps(r.serviceLatitude, r.serviceLongitude),
                              icon: Icon(Icons.map_outlined, size: 14.sp, color: kPrimaryColor),
                              label: Text(
                                'Preview Location',
                                style: kTextSemiBold().copyWith(
                                  color: kPrimaryColor,
                                  fontSize: 12.sp,
                                  decoration: TextDecoration.underline,
                                  decorationColor: kPrimaryColor,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                        if ((r.familyMember?.fullName ?? r.customerName).isNotEmpty) ...[
                          _divider(),
                          _row(Icons.person_rounded, 'Patient', r.familyMember?.fullName ?? r.customerName),
                        ],
                        SizedBox(height: 14.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(6.w),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: Colors.white,
                                  size: 16.sp,
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Text('Booking Payout', style: kTextSemiBold1(color: Colors.white)),
                              ),
                              Text(
                                NumberUtils.formatCurrency(widget.payout),
                                style: kTextBold2(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14.h),
                  // Terms checkbox
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _agreed = !_agreed),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 22.w,
                          height: 22.w,
                          decoration: BoxDecoration(
                            color: _agreed ? kSuccessColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(6.r),
                            border: Border.all(color: _agreed ? kSuccessColor : Colors.grey.shade400, width: 1.5),
                          ),
                          child: _agreed ? Icon(Icons.check, size: 13.sp, color: Colors.white) : null,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'I confirm my availability for these dates and ',
                                style: kTextNormal(color: Colors.grey.shade700),
                                recognizer: _confirmRecognizer,
                              ),
                              TextSpan(
                                text: 'agree to terms & conditions.',
                                style: kTextMedium(color: kPrimaryColor).copyWith(
                                  decoration: TextDecoration.underline,
                                  decorationColor: kPrimaryColor,
                                ),
                                recognizer: _termsRecognizer,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Sticky confirm button ──
          Container(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade100)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton(
                    onPressed: (_agreed && !_submitting)
                        ? () {
                            setState(() => _submitting = true);
                            Navigator.pop(context);
                            widget.onConfirm();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_agreed && !_submitting) ? kSuccessColor : Colors.grey.shade300,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      elevation: (_agreed && !_submitting) ? 3 : 0,
                      shadowColor: kSuccessColor.withValues(alpha: 0.35),
                    ),
                    child: _submitting
                        ? SizedBox(
                            width: 20.sp,
                            height: 20.sp,
                            child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Confirm & Accept Booking', style: kTextBold1(color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shiftRow(ProviderServiceRequestModel r, String startTime, String endTime) {
    // For full-day requests, derive actual shift type from selected blocks
    if (r.isFullDayShift && widget.selected.isNotEmpty) {
      final hasDayShifts = widget.selected.any((b) => b.isDayShift);
      final hasNightShifts = widget.selected.any((b) => b.isNightShift);

      if (hasDayShifts && hasNightShifts) {
        return _row(Icons.brightness_4_rounded, 'Shift & Hours', 'Day & Night Shifts');
      } else if (hasDayShifts) {
        final b = widget.selected.firstWhere((b) => b.isDayShift);
        return _row(Icons.wb_sunny_outlined, 'Shift & Hours', 'Day Shift  ·  ${b.startLabel} – ${b.endLabel}');
      } else {
        final b = widget.selected.firstWhere((b) => b.isNightShift);
        return _row(
          Icons.nightlight_round,
          'Shift & Hours',
          'Night Shift  ·  ${b.startLabel} → Next Day ${b.endLabel}',
        );
      }
    }

    final isNight = r.shiftType == 'night';
    final icon = isNight ? Icons.nightlight_round : Icons.wb_sunny_outlined;
    final timeStr = AppDateFormatter.shiftTimeRange(startTime, endTime, isFullDay: r.isFullDayShift);
    final value = r.shiftTypeLabel.isNotEmpty ? '${r.shiftTypeLabel}  ·  $timeStr' : timeStr;
    return _row(icon, 'Shift & Hours', value);
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: EdgeInsets.symmetric(vertical: 8.h),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15.sp, color: kPrimaryColor),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: kTextNormal(color: Colors.grey.shade600)),
              SizedBox(height: 2.h),
              Text(value, style: kTextSemiBold()),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _divider() => Divider(height: 1, color: const Color(0xFFBAE6FD));
}
