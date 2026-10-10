import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/models/provider_service_request_model.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/models/sub_block_model.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/widgets/request_schedule_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ─── Acceptance mode ──────────────────────────────────────────────────────────

enum _FullDayMode { full, dayOnly, nightOnly, custom, firstHalf, secondHalf }

// ─── Quadrant (stage 2 multi-select: half × shift) ────────────────────────────

enum _Quadrant { firstDay, firstNight, secondDay, secondNight }

// ─── Date entry (one row in the matrix) ──────────────────────────────────────

class _DateEntry {
  final String date;
  final SubBlock? day;
  final SubBlock? night;
  const _DateEntry(this.date, {this.day, this.night});
}

// ─── FullDayBookingSheet ──────────────────────────────────────────────────────

class FullDayBookingSheet extends StatefulWidget {
  final ProviderServiceRequestModel request;
  final void Function(List<int> selectedIds) onAccept;
  final int stage;

  const FullDayBookingSheet({super.key, required this.request, required this.onAccept, this.stage = 1});

  static Future<void> show({
    required BuildContext context,
    required ProviderServiceRequestModel request,
    required void Function(List<int> selectedIds) onAccept,
    int? stage,
  }) {
    final effectiveStage = stage ?? request.requestStage;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      useSafeArea: true,
      builder: (_) => FullDayBookingSheet(request: request, onAccept: onAccept, stage: effectiveStage),
    );
  }

  @override
  State<FullDayBookingSheet> createState() => _FullDayBookingSheetState();
}

class _FullDayBookingSheetState extends State<FullDayBookingSheet> {
  _FullDayMode _mode = _FullDayMode.full;
  final Set<int> _selectedDayIds = {};
  final Set<int> _selectedNightIds = {};
  // Stage 2 multi-select quadrants — pre-selected to whole booking by default.
  final Set<_Quadrant> _selectedQuadrants = {};

  @override
  void initState() {
    super.initState();
    if (widget.stage == 3) {
      _mode = _FullDayMode.custom;
      // sets stay empty — provider selects shifts manually
    }
  }

  static const _greyText = Color(0xFF6B7280);
  static const _greyBg = Color(0xFFF7F8FC);
  static const _greyBorder = Color(0xFFE5E7EB);
  static const _dayColor = Color(0xFFD97706);
  static const _nightColor = Color(0xFF6366F1);
  static const _fullDayColor = Color(0xFF7C3AED);

  // ── Data ────────────────────────────────────────────────────────────────────

  List<SubBlock> get _availableBlocks =>
      widget.request.subBlocks.where((b) => b.status.toLowerCase() == 'pending').toList();

  List<SubBlock> get _dayBlocks =>
      _availableBlocks.where((b) => b.isDayShift).toList();

  List<SubBlock> get _nightBlocks =>
      _availableBlocks.where((b) => b.isNightShift).toList();

  List<_DateEntry> get _dateEntries {
    final map = <String, _DateEntry>{};
    for (final b in _availableBlocks) {
      final date = b.scheduledDate;
      final e = map[date] ?? _DateEntry(date);
      map[date] = b.isDayShift
          ? _DateEntry(date, day: b, night: e.night)
          : _DateEntry(date, day: e.day, night: b);
    }
    final entries = map.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }

  double _payout(Iterable<SubBlock> blocks) =>
      blocks.fold(0.0, (s, b) => s + b.providerPayout);

  double get _dayPayout => _payout(_dayBlocks);
  double get _nightPayout => _payout(_nightBlocks);
  double get _totalPayout => _dayPayout + _nightPayout;

  // ── Half helpers (stage 2) ─────────────────────────────────────────────────

  List<_DateEntry> get _firstHalfEntries {
    final e = _dateEntries;
    return e.take(e.length ~/ 2).toList();
  }

  List<_DateEntry> get _secondHalfEntries {
    final e = _dateEntries;
    return e.skip(e.length ~/ 2).toList();
  }

  List<int> _idsForEntries(List<_DateEntry> entries) => entries
      .expand((e) => [if (e.day != null) e.day!.id, if (e.night != null) e.night!.id])
      .toList();

  // ── Quadrant helpers (stage 2) ──────────────────────────────────────────────

  List<SubBlock> _quadrantBlocks(_Quadrant q) {
    final entries = (q == _Quadrant.firstDay || q == _Quadrant.firstNight)
        ? _firstHalfEntries
        : _secondHalfEntries;
    final isDay = q == _Quadrant.firstDay || q == _Quadrant.secondDay;
    return entries.map((e) => isDay ? e.day : e.night).whereType<SubBlock>().toList();
  }

  List<int> _quadrantIds(_Quadrant q) => _quadrantBlocks(q).map((b) => b.id).toList();

  double _quadrantPayout(_Quadrant q) =>
      _quadrantBlocks(q).fold(0.0, (s, b) => s + b.providerPayout);

  String _quadrantDateRange(_Quadrant q) {
    final entries = (q == _Quadrant.firstDay || q == _Quadrant.firstNight)
        ? _firstHalfEntries
        : _secondHalfEntries;
    if (entries.isEmpty) return '';
    final start = AppDateFormatter.dayMonthOnly(entries.first.date);
    final end = AppDateFormatter.dayMonthOnly(entries.last.date);
    return start == end ? start : '$start – $end';
  }

  List<int> get _effectiveIds {
    if (widget.stage == 2) {
      return _selectedQuadrants.expand(_quadrantIds).toSet().toList();
    }
    return switch (_mode) {
      _FullDayMode.full => _availableBlocks.map((b) => b.id).toList(),
      _FullDayMode.dayOnly => _dayBlocks.map((b) => b.id).toList(),
      _FullDayMode.nightOnly => _nightBlocks.map((b) => b.id).toList(),
      _FullDayMode.custom => [..._selectedDayIds, ..._selectedNightIds],
      _FullDayMode.firstHalf => _idsForEntries(_firstHalfEntries),
      _FullDayMode.secondHalf => _idsForEntries(_secondHalfEntries),
    };
  }

  Set<SubBlock> get _selectedBlocks {
    final ids = Set<int>.from(_effectiveIds);
    return _availableBlocks.where((b) => ids.contains(b.id)).toSet();
  }

  int get _selDayCount => _selectedBlocks.where((b) => b.isDayShift).length;
  int get _selNightCount => _selectedBlocks.where((b) => b.isNightShift).length;
  double get _selPayout => _selectedBlocks.fold(0.0, (s, b) => s + b.providerPayout);

  bool get _canAccept => _effectiveIds.isNotEmpty;

  // ── Actions ──────────────────────────────────────────────────────────────────

  void _selectMode(_FullDayMode mode) {
    HapticFeedback.selectionClick();
    setState(() {
      _mode = mode;
      if (mode == _FullDayMode.custom) {
        _selectedDayIds..clear()..addAll(_dayBlocks.map((b) => b.id));
        _selectedNightIds..clear()..addAll(_nightBlocks.map((b) => b.id));
      }
    });
  }

  void _onAccept() {
    if (!_canAccept) return;
    HapticFeedback.mediumImpact();
    final ids = _effectiveIds;
    final idSet = Set<int>.from(ids);
    final selected = _availableBlocks.where((b) => idSet.contains(b.id)).toList();
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
          Navigator.pop(context); // pop FullDayBookingSheet
          widget.onAccept(ids);
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.97,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 28, offset: const Offset(0, -6))],
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
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stage 3: skip mode cards, show custom matrix directly
                      if (widget.stage == 3)
                        _buildCustomMatrix()
                      else ...[
                        _buildModeSelector(),
                        // Stage 1 & 2: full schedule timetable
                        if (widget.stage == 1 || widget.stage == 2) ...[
                          SizedBox(height: 20.h),
                          _buildReadonlyTimetable(),
                        ],
                        // Stage 3+ (non-stage-3): custom matrix when custom mode selected
                        if (widget.stage != 1 && widget.stage != 2 && _mode == _FullDayMode.custom) ...[
                          SizedBox(height: 22.h),
                          _buildCustomMatrix(),
                        ],
                      ],
                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Handle ───────────────────────────────────────────────────────────────────

  Widget _buildHandle() => Center(
        child: Container(
          margin: EdgeInsets.only(top: 8.h, bottom: 4.h),
          width: 36.w,
          height: 4.h,
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2.r)),
        ),
      );

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final r = widget.request;
    final totalShifts = r.subBlocks.length;
    final days = r.durationDays ?? _dateEntries.length;
    final dateRange = '${AppDateFormatter.dayMonthShort(r.startDate)} → ${AppDateFormatter.dayMonthShort(r.endDate)}';

    // Extract day/night timing from first blocks
    final dayStart = _dayBlocks.isNotEmpty ? _dayBlocks.first.startLabel : '9:00 AM';
    final dayEnd = _dayBlocks.isNotEmpty ? _dayBlocks.first.endLabel : '9:00 PM';
    final nightStart = _nightBlocks.isNotEmpty ? _nightBlocks.first.startLabel : '9:00 PM';
    final nightEnd = _nightBlocks.isNotEmpty ? _nightBlocks.first.endLabel : '9:00 AM';

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge + total pill on same row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Badge
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: _fullDayColor.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: _fullDayColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.brightness_4_rounded, size: 10.sp, color: _fullDayColor),
                      SizedBox(width: 4.w),
                      Flexible(
                        child: Text(
                          'FULL DAY',
                          style: kTextBold0(color: _fullDayColor).copyWith(fontSize: 10.sp, letterSpacing: 0.4),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 5.w),
                      Flexible(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(color: _fullDayColor, borderRadius: BorderRadius.circular(8.r)),
                          child: Text(
                            '$days D • $totalShifts Shift',
                            style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w700, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              // Total payout compact
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: kSuccessColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: kSuccessColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(NumberUtils.formatCurrency(_totalPayout), style: kTextBold1(color: const Color(0xFF15803D))),
                    SizedBox(width: 3.w),
                    Text('total', style: kTextNormal0(color: const Color(0xFF16A34A)).copyWith(fontSize: 9.sp)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 7.h),
          // Service name + date
          Text(r.serviceCategoryName, style: kTextBold2().copyWith(fontSize: 16.sp), overflow: TextOverflow.ellipsis),
          SizedBox(height: 2.h),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 10.sp, color: _greyText),
              SizedBox(width: 3.w),
              Expanded(
                child: Text(dateRange, style: kTextNormal0(color: _greyText).copyWith(fontSize: 11.sp)),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          // Shift timing chips (compact)
          Row(
            children: [
              Expanded(
                child: _shiftTimingChip(
                  icon: Icons.wb_sunny_rounded,
                  label: '$dayStart – $dayEnd',
                  payout: _dayBlocks.isNotEmpty ? NumberUtils.formatCurrency(_dayBlocks.first.providerPayout) : null,
                  fg: _dayColor,
                  bg: const Color(0xFFFFFBEB),
                  border: const Color(0xFFFDE68A),
                ),
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: _shiftTimingChip(
                  icon: Icons.nightlight_rounded,
                  label: '$nightStart – $nightEnd',
                  payout: _nightBlocks.isNotEmpty ? NumberUtils.formatCurrency(_nightBlocks.first.providerPayout) : null,
                  fg: _nightColor,
                  bg: const Color(0xFFF5F3FF),
                  border: const Color(0xFFDDD6FE),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shiftTimingChip({
    required IconData icon,
    required String label,
    required String? payout,
    required Color fg,
    required Color bg,
    required Color border,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 11.sp, color: fg),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: kTextMedium(color: fg).copyWith(fontSize: 10.sp), overflow: TextOverflow.ellipsis),
                if (payout != null)
                  Text('$payout / shift', style: kTextSemiBold0(color: fg).copyWith(fontSize: 9.sp)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode selector ─────────────────────────────────────────────────────────────

  Widget _buildModeSelector() {
    if (widget.stage == 2) return _buildQuadrantSelector();

    // Stage 1: only the full-booking option.
    if (widget.stage == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Booking Coverage', style: kTextSemiBold1()),
          SizedBox(height: 2.h),
          Text('Accept the complete schedule', style: kTextNormal0(color: _greyText)),
          SizedBox(height: 12.h),
          _buildFullBookingCard(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Coverage', style: kTextSemiBold1()),
        SizedBox(height: 2.h),
        Text('Choose which shifts to accept', style: kTextNormal0(color: _greyText)),
        SizedBox(height: 10.h),
        _modeCard(
          mode: _FullDayMode.full,
          icon: Icons.brightness_4_rounded,
          label: 'Accept Full Booking',
          subtitle: '${_dayBlocks.length} Day + ${_nightBlocks.length} Night Shifts',
          payout: _totalPayout,
          accent: kSuccessColor,
        ),
        SizedBox(height: 8.h),
        _modeCard(
          mode: _FullDayMode.dayOnly,
          icon: Icons.wb_sunny_rounded,
          label: 'Day Shifts Only',
          subtitle: '${_dayBlocks.length} shifts  •  9:00 AM – 9:00 PM',
          payout: _dayPayout,
          accent: _dayColor,
        ),
        SizedBox(height: 10.h),
        _modeCard(
          mode: _FullDayMode.nightOnly,
          icon: Icons.nightlight_rounded,
          label: 'Night Shifts Only',
          subtitle: '${_nightBlocks.length} shifts  •  9:00 PM – 9:00 AM',
          payout: _nightPayout,
          accent: _nightColor,
        ),
        // Custom option only for stage 3+
        if (widget.stage != 1) ...[
          SizedBox(height: 10.h),
          _modeCard(
            mode: _FullDayMode.custom,
            icon: Icons.tune_rounded,
            label: 'Choose Custom Shifts',
            subtitle: 'Select specific day and night shifts per date',
            payout: null,
            accent: kPrimaryColor,
          ),
        ],
      ],
    );
  }

  // ── Full booking hero card (stage 1) ─────────────────────────────────────────

  Widget _buildFullBookingCard() {
    const accent = kSuccessColor;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.10), accent.withValues(alpha: 0.04)],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 12.h),
            child: Row(
              children: [
                Container(
                  width: 46.w,
                  height: 46.w,
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(13.r)),
                  child: Icon(Icons.brightness_4_rounded, color: Colors.white, size: 24.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Accept Full Booking', style: kTextBold2(color: const Color(0xFF15803D))),
                      SizedBox(height: 3.h),
                      Text(
                        '${_dayBlocks.length} Day  +  ${_nightBlocks.length} Night Shifts',
                        style: kTextNormal0(color: _greyText).copyWith(fontSize: 11.5.sp),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(Icons.check_circle_rounded, color: accent, size: 26.sp),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: accent.withValues(alpha: 0.18)),
          // Earnings row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
            child: Row(
              children: [
                Icon(Icons.payments_rounded, size: 15.sp, color: accent),
                SizedBox(width: 6.w),
                Text('Total earnings', style: kTextMedium(color: _greyText).copyWith(fontSize: 12.sp)),
                const Spacer(),
                Text(
                  NumberUtils.formatCurrency(_totalPayout),
                  style: kTextBold2(color: const Color(0xFF15803D)).copyWith(fontSize: 18.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Quadrant selector (stage 2: half × shift, multi-select) ──────────────────

  Widget _buildQuadrantSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Shifts', style: kTextSemiBold1()),
        SizedBox(height: 2.h),
        Text('Pick any combination — you can select all four', style: kTextNormal0(color: _greyText)),
        SizedBox(height: 12.h),
        _quadrantCard(_Quadrant.firstDay, 'First Half', 'Day Shifts', Icons.wb_sunny_rounded, _dayColor),
        SizedBox(height: 10.h),
        _quadrantCard(_Quadrant.firstNight, 'First Half', 'Night Shifts', Icons.nightlight_rounded, _nightColor),
        SizedBox(height: 10.h),
        _quadrantCard(_Quadrant.secondDay, 'Second Half', 'Day Shifts', Icons.wb_sunny_rounded, _dayColor),
        SizedBox(height: 10.h),
        _quadrantCard(_Quadrant.secondNight, 'Second Half', 'Night Shifts', Icons.nightlight_rounded, _nightColor),
      ],
    );
  }

  Widget _quadrantCard(_Quadrant q, String half, String shift, IconData icon, Color accent) {
    final selected = _selectedQuadrants.contains(q);
    final count = _quadrantIds(q).length;
    final payout = _quadrantPayout(q);
    final dateRange = _quadrantDateRange(q);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (selected) {
            _selectedQuadrants.remove(q);
          } else {
            _selectedQuadrants.add(q);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: selected ? accent : _greyBorder, width: selected ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: selected ? accent.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.03),
              blurRadius: selected ? 12 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: selected ? accent : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: selected ? Colors.white : Colors.grey.shade500, size: 20.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(half, style: kTextNormal0(color: _greyText).copyWith(fontSize: 11.sp)),
                  Text(shift, style: kTextSemiBold1(color: selected ? accent : Colors.black87)),
                  SizedBox(height: 3.h),
                  if (dateRange.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 10.sp, color: _greyText),
                        SizedBox(width: 3.w),
                        Flexible(
                          child: Text(
                            dateRange,
                            style: kTextNormal0(color: _greyText).copyWith(fontSize: 10.5.sp),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  Text('$count shifts', style: kTextNormal0(color: _greyText).copyWith(fontSize: 11.sp)),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(NumberUtils.formatCurrency(payout), style: kTextBold1(color: selected ? kSuccessColor : Colors.grey.shade700)),
                Text('earnings', style: kTextNormal0(color: Colors.grey.shade400).copyWith(fontSize: 10.sp)),
              ],
            ),
            SizedBox(width: 8.w),
            // Square check (multi-select)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22.w,
              height: 22.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6.r),
                color: selected ? accent : Colors.transparent,
                border: Border.all(color: selected ? accent : Colors.grey.shade300, width: 2),
              ),
              child: selected ? Icon(Icons.check, size: 13.sp, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Readonly timetable (stage 1) ──────────────────────────────────────────────

  Widget _buildReadonlyTimetable() {
    final entries = _dateEntries;
    final showDay = _mode != _FullDayMode.nightOnly;
    final showNight = _mode != _FullDayMode.dayOnly;

    // Stage 2: per-cell active state follows the selected quadrants.
    final stage2 = widget.stage == 2;
    final firstHalfDates = stage2 ? _firstHalfEntries.map((e) => e.date).toSet() : <String>{};
    bool dayOn(_DateEntry e) {
      if (!stage2) return showDay;
      final inFirst = firstHalfDates.contains(e.date);
      return _selectedQuadrants.contains(inFirst ? _Quadrant.firstDay : _Quadrant.secondDay);
    }
    bool nightOn(_DateEntry e) {
      if (!stage2) return showNight;
      final inFirst = firstHalfDates.contains(e.date);
      return _selectedQuadrants.contains(inFirst ? _Quadrant.firstNight : _Quadrant.secondNight);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month_rounded, size: 14.sp, color: kPrimaryColor),
            SizedBox(width: 6.w),
            Text('Full Schedule', style: kTextSemiBold1()),
            const Spacer(),
            Text(
              '${entries.length} Days',
              style: kTextNormal0(color: _greyText).copyWith(fontSize: 11.sp),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        // Column headers
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: _greyBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10.r)),
            border: Border.all(color: _greyBorder),
          ),
          child: Row(
            children: [
              Expanded(flex: 4, child: Text('Date', style: kTextSemiBold0(color: _greyText).copyWith(fontSize: 11.sp))),
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wb_sunny_rounded, size: 10.sp, color: showDay ? _dayColor : _greyText),
                    SizedBox(width: 2.w),
                    Text('Day', style: kTextSemiBold0(color: showDay ? _dayColor : _greyText).copyWith(fontSize: 10.sp)),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.nightlight_rounded, size: 10.sp, color: showNight ? _nightColor : _greyText),
                    SizedBox(width: 2.w),
                    Text('Night', style: kTextSemiBold0(color: showNight ? _nightColor : _greyText).copyWith(fontSize: 10.sp)),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Date rows (capped at 7 then "show more")
        Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: _greyBorder),
              right: BorderSide(color: _greyBorder),
              bottom: BorderSide(color: _greyBorder),
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(10.r)),
          ),
          child: Column(
            children: entries.asMap().entries.map((e) {
              final isLast = e.key == entries.length - 1;
              final entry = e.value;
              final dOn = dayOn(entry);
              final nOn = nightOn(entry);
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: isLast ? BorderRadius.vertical(bottom: Radius.circular(10.r)) : null,
                  border: isLast ? null : Border(bottom: BorderSide(color: _greyBorder.withValues(alpha: 0.5))),
                ),
                child: Row(
                  children: [
                    // Date
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppDateFormatter.dayMonthShort(entry.date),
                            style: kTextSemiBold().copyWith(fontSize: 11.sp),
                          ),
                          Text(
                            AppDateFormatter.weekdayShort(entry.date),
                            style: kTextNormal0(color: _greyText).copyWith(fontSize: 9.sp),
                          ),
                        ],
                      ),
                    ),
                    // Day shift indicator
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: entry.day != null
                            ? Container(
                                width: 28.w,
                                height: 22.h,
                                decoration: BoxDecoration(
                                  color: dOn ? _dayColor.withValues(alpha: 0.12) : _greyBorder,
                                  borderRadius: BorderRadius.circular(5.r),
                                ),
                                child: Icon(
                                  Icons.wb_sunny_rounded,
                                  size: 12.sp,
                                  color: dOn ? _dayColor : _greyText.withValues(alpha: 0.3),
                                ),
                              )
                            : Icon(Icons.remove, size: 10.sp, color: _greyBorder),
                      ),
                    ),
                    // Night shift indicator
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: entry.night != null
                            ? Container(
                                width: 28.w,
                                height: 22.h,
                                decoration: BoxDecoration(
                                  color: nOn ? _nightColor.withValues(alpha: 0.12) : _greyBorder,
                                  borderRadius: BorderRadius.circular(5.r),
                                ),
                                child: Icon(
                                  Icons.nightlight_rounded,
                                  size: 12.sp,
                                  color: nOn ? _nightColor : _greyText.withValues(alpha: 0.3),
                                ),
                              )
                            : Icon(Icons.remove, size: 10.sp, color: _greyBorder),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _modeCard({
    required _FullDayMode mode,
    required IconData icon,
    required String label,
    required String subtitle,
    required double? payout,
    required Color accent,
  }) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => _selectMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: selected ? accent : _greyBorder, width: selected ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: selected ? accent.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.03),
              blurRadius: selected ? 12 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: selected ? accent : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: selected ? Colors.white : Colors.grey.shade500, size: 20.sp),
            ),
            SizedBox(width: 12.w),
            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: kTextSemiBold1(color: selected ? accent : Colors.black87)),
                  SizedBox(height: 2.h),
                  Text(subtitle, style: kTextNormal0(color: _greyText).copyWith(fontSize: 11.sp)),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            // Payout or chevron
            if (payout != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(NumberUtils.formatCurrency(payout), style: kTextBold1(color: selected ? kSuccessColor : Colors.grey.shade700)),
                  Text('earnings', style: kTextNormal0(color: Colors.grey.shade400).copyWith(fontSize: 10.sp)),
                ],
              )
            else
              Icon(Icons.chevron_right_rounded, size: 20.sp, color: selected ? accent : _greyText),
            SizedBox(width: 8.w),
            // Radio
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22.w,
              height: 22.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? accent : Colors.transparent,
                border: Border.all(color: selected ? accent : Colors.grey.shade300, width: 2),
              ),
              child: selected ? Icon(Icons.check, size: 13.sp, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Custom matrix ─────────────────────────────────────────────────────────────

  Widget _buildCustomMatrix() {
    final entries = _dateEntries;
    final allSelected = _selectedDayIds.length == _dayBlocks.length && _selectedNightIds.length == _nightBlocks.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Matrix header row
        Row(
          children: [
            Icon(Icons.tune_rounded, size: 14.sp, color: kPrimaryColor),
            SizedBox(width: 6.w),
            Text('Custom Schedule', style: kTextSemiBold1()),
            const Spacer(),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  if (allSelected) {
                    _selectedDayIds.clear();
                    _selectedNightIds.clear();
                  } else {
                    _selectedDayIds.addAll(_dayBlocks.map((b) => b.id));
                    _selectedNightIds.addAll(_nightBlocks.map((b) => b.id));
                  }
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  allSelected ? 'Deselect All' : 'Select All',
                  style: kTextMedium(color: kPrimaryColor).copyWith(fontSize: 12.sp),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        // Column headers
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
          decoration: BoxDecoration(
            color: _greyBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
            border: Border.all(color: _greyBorder),
          ),
          child: Row(
            children: [
              Expanded(flex: 5, child: Text('Date', style: kTextSemiBold0(color: _greyText))),
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wb_sunny_rounded, size: 11.sp, color: _dayColor),
                    SizedBox(width: 3.w),
                    Text('Day', style: kTextSemiBold0(color: _dayColor)),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.nightlight_rounded, size: 11.sp, color: _nightColor),
                    SizedBox(width: 3.w),
                    Text('Night', style: kTextSemiBold0(color: _nightColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Rows
        Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: _greyBorder),
              right: BorderSide(color: _greyBorder),
              bottom: BorderSide(color: _greyBorder),
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12.r)),
          ),
          child: Column(
            children: entries.asMap().entries.map((e) {
              return _buildMatrixRow(e.value, isLast: e.key == entries.length - 1);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMatrixRow(_DateEntry entry, {required bool isLast}) {
    final daySelected = entry.day != null && _selectedDayIds.contains(entry.day!.id);
    final nightSelected = entry.night != null && _selectedNightIds.contains(entry.night!.id);
    final anySelected = daySelected || nightSelected;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: anySelected ? const Color(0xFFF0F4FF) : Colors.white,
        borderRadius: isLast ? BorderRadius.vertical(bottom: Radius.circular(12.r)) : null,
        border: isLast ? null : Border(bottom: BorderSide(color: _greyBorder.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          // Date
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppDateFormatter.dayMonthShort(entry.date),
                  style: kTextSemiBold().copyWith(fontSize: 12.sp, color: anySelected ? kPrimaryColor : Colors.black87),
                ),
                Text(
                  AppDateFormatter.weekdayShort(entry.date),
                  style: kTextNormal0(color: _greyText).copyWith(fontSize: 10.sp),
                ),
              ],
            ),
          ),
          // Day shift cell
          Expanded(
            flex: 3,
            child: Center(
              child: _shiftToggle(
                block: entry.day,
                selected: daySelected,
                color: _dayColor,
                onTap: entry.day == null
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (daySelected) {
                            _selectedDayIds.remove(entry.day!.id);
                          } else {
                            _selectedDayIds.add(entry.day!.id);
                          }
                        });
                      },
              ),
            ),
          ),
          // Night shift cell
          Expanded(
            flex: 3,
            child: Center(
              child: _shiftToggle(
                block: entry.night,
                selected: nightSelected,
                color: _nightColor,
                onTap: entry.night == null
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (nightSelected) {
                            _selectedNightIds.remove(entry.night!.id);
                          } else {
                            _selectedNightIds.add(entry.night!.id);
                          }
                        });
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shiftToggle({
    required SubBlock? block,
    required bool selected,
    required Color color,
    required VoidCallback? onTap,
  }) {
    if (block == null) {
      return Container(
        width: 30.w,
        height: 30.w,
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8.r)),
        child: Icon(Icons.remove, size: 12.sp, color: Colors.grey.shade300),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 30.w,
        height: 30.w,
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: selected ? color : Colors.grey.shade300, width: selected ? 0 : 1.5),
          boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6)] : null,
        ),
        child: selected ? Icon(Icons.check, size: 16.sp, color: Colors.white) : null,
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    final dayCount = _selDayCount;
    final nightCount = _selNightCount;
    final totalCount = dayCount + nightCount;
    final payout = _selPayout;

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Accept CTA
            SizedBox(
              width: double.infinity,
              height: 46.h,
              child: ElevatedButton.icon(
                onPressed: _canAccept ? _onAccept : null,
                icon: Icon(Icons.check_circle_rounded, size: 20.sp, color: Colors.white),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _canAccept
                        ? 'Accept $totalCount Shifts  •  ${NumberUtils.formatCurrency(payout)}'
                        : 'Select Shifts to Accept',
                    style: kTextBold1(color: Colors.white),
                    maxLines: 1,
                  ),
                ),
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
}
