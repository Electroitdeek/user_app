import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_edge_insets.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/theme/screen_dimensions.dart';
import '../../../../../core/utils/message_service.dart';
import '../../../../../core/utils/number_utils.dart';
import '../../../../../data/providers/system_settings_provider.dart';
import '../../../../../shared/widgets/common/app_cached_image.dart';
import '../../model/booking_model.dart';
import '../../model/service_category_model.dart';
import '../service_booking_flow.dart';
import '../widgets/booking_schedule_sheet.dart';
import '../widgets/custom_time_picker_sheet.dart';
import '../widgets/date_picker_sheet.dart';
import '../widgets/package_picker_sheet.dart';
import '../widgets/service_description_sheet.dart';

class Step2DateDurationPage extends ConsumerStatefulWidget {
  final BookingRequest request;
  final ValueChanged<BookingRequest> onUpdate;

  const Step2DateDurationPage({super.key, required this.request, required this.onUpdate});

  @override
  ConsumerState<Step2DateDurationPage> createState() => _Step2DateDurationPageState();
}

class _Step2DateDurationPageState extends ConsumerState<Step2DateDurationPage> {
  // ── Home Visit ───────────────────────────────────────────────────────
  DateTime _startDate = DateTime.now();
  int _durationHours = 2;
  String _selectedTimeOfDay = 'Morning';
  String? _selectedTimeSlot;
  String _selectedShiftType = 'day';

  // Extra date picked via "More" picker — shown in chip row
  DateTime? _customPickedDate;

  // ── Long Duration ─────────────────────────────────────────────────────────
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  String _longDurationShiftType = 'day';
  bool _shiftTypeChosen = false;

  // For Full Day: 'morning' (day cycle) | 'evening' (night cycle) | null = not chosen
  String? _fullDayStartCycle;
  bool _fullDayPickerExpanded = false;
  int? _selectedPackageId;
  String? _autoDateMessage;

  // ── Multi-Day Hourly ────────────────────────────────────────────────
  bool _isMultiDayMode = false;
  DateTime? _multiDayStart;
  DateTime? _multiDayEnd;

  // ── Subscription Plan ──────────────────────────────────────────────
  String _subscriptionPlan = 'daily'; // 'daily', 'weekly', 'alternate'
  List<int> _selectedWeekdays = [DateTime.now().weekday]; // 1=Mon, 7=Sun
  List<String> _activeScheduledDates = [];
  bool _isManualSchedule = false;

  bool get _isLongDuration => widget.request.bookingType == 'long_duration';

  bool get _isProcedural => widget.request.bookingType == 'procedural';

  /// True when enough config exists to show date/schedule section.
  bool get _isShiftFullyConfigured {
    if (!_shiftTypeChosen) return false;
    if (_longDurationShiftType == '24_hours' && _fullDayStartCycle == null) return false;
    return true;
  }

  /// Maps full-day cycle choice to the underlying shift used for cutoff logic.
  String get _effectiveShiftForFullDay => _fullDayStartCycle == 'evening' ? 'night' : 'day';

  int get _rangeDaysCount {
    if (_rangeStart == null || _rangeEnd == null) return 0;
    return _rangeEnd!.difference(_rangeStart!).inDays + 1;
  }

  bool get _isMultiDayProcedural => _isProcedural && _isMultiDayMode;

  RateCardModel? get _rateCard => widget.request.serviceType?.rateCard;

  double get _gstPercentage => widget.request.serviceType?.gstPercentage ?? 0;

  /// Maps internal shift type key to the API package shift_type value.
  String _toPackageShiftType(String shiftType) {
    switch (shiftType) {
      case 'day':
        return 'day_shift';
      case 'night':
        return 'night_shift';
      case '24_hours':
        return 'full_day';
      default:
        return shiftType;
    }
  }

  /// Packages filtered by the currently selected shift type.
  List<RateCardPackageModel> get _filteredPackages {
    final packages = _rateCard?.packages ?? [];
    if (packages.isEmpty) return [];
    final apiShiftType = _toPackageShiftType(_longDurationShiftType);
    return packages.where((p) => p.shiftType == apiShiftType).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  RateCardPackageModel? get _selectedPackage {
    if (_selectedPackageId == null) return null;
    final packages = _rateCard?.packages ?? [];
    try {
      return packages.firstWhere((p) => p.id == _selectedPackageId);
    } catch (_) {
      return null;
    }
  }

  int get _durationDays {
    if (_rangeStart == null) return 0;
    // If the user hasn't picked an end date yet, treat as single day
    // so the price bar shows a sensible default rather than "–".
    if (_rangeEnd == null) return 1;
    return _rangeEnd!.difference(_rangeStart!).inDays + 1;
  }

  // ── Prices ───────────────────────────────────────────────────────────
  double get _homeVisitTotal {
    if (_rateCard == null) return 0;
    // Base price is per-day.
    return _rateCard!.basePrice + (_durationHours * _rateCard!.pricePerHour);
  }

  double get _dayCareRawTotal {
    final scheduledDays = _activeScheduledDates.length;
    if (_rateCard == null || scheduledDays == 0) return 0;
    final dailyRate = _longDurationShiftType == 'night'
        ? _rateCard!.pricePerNight
        : (_longDurationShiftType == '24_hours' ? _rateCard!.pricePerFullDay : _rateCard!.pricePerDay);
    return scheduledDays * dailyRate;
  }

  double get _dayCareTotal {
    final scheduledDays = _activeScheduledDates.length;
    if (_selectedPackage != null && scheduledDays > 0) {
      // Per-day rate from package × actual scheduled days
      final perDay = _selectedPackage!.price / _selectedPackage!.duration;
      return perDay * scheduledDays;
    }
    return _dayCareRawTotal;
  }

  /// Savings amount vs paying daily rate for scheduled days (0 if no package).
  double get _packageSavingsAmount {
    if (_selectedPackage == null) return 0;
    final raw = _dayCareRawTotal;
    return (raw - _dayCareTotal).clamp(0, double.infinity);
  }

  /// Savings percent vs daily rate × scheduled days (0 if no package or no savings).
  double get _packageSavingsPercent {
    if (_selectedPackage == null) return 0;
    final raw = _dayCareRawTotal;
    if (raw <= 0) return 0;
    return (_packageSavingsAmount / raw * 100).clamp(0, 100);
  }

  double get _multiDayHourlyTotal {
    if (_rateCard == null || _activeScheduledDates.isEmpty) return 0;
    final scheduledDays = _activeScheduledDates.length;
    // Formula: (Base Price * Days) + (Price Per Hour * Hours * Days)
    return (_rateCard!.basePrice * scheduledDays) + (_rateCard!.pricePerHour * _durationHours * scheduledDays);
  }

  double get _estimatedTotal {
    if (_isMultiDayProcedural) return _multiDayHourlyTotal;
    return _isLongDuration ? _dayCareTotal : _homeVisitTotal;
  }

  String get _estimatedTotalFormatted => NumberUtils.formatCurrency(_estimatedTotal);

  String get _durationSectionTitle {
    final unit = _rateCard?.unitType?.toLowerCase();
    final qtyMin = _rateCard?.qtyInMin;
    final suffix = qtyMin != null ? ' ($qtyMin min)' : '';
    if (unit == 'session') {
      return '${_isMultiDayMode ? 'Sessions per Day' : 'Sessions'}$suffix';
    } else if (unit == 'hour') {
      return '${_isMultiDayMode ? 'Hours per Day' : 'Duration'}$suffix';
    }
    return '${_isMultiDayMode ? 'Hours per Day' : 'Duration'}$suffix';
  }

  // ── Hour options ─────────────────────────────────────────────────────
  static const _hourOptions = [1, 2, 3, 4, 6, 8];

  List<int> get _effectiveHourOptions {
    if (_rateCard?.pricePerHour == 0) return [1];
    return _hourOptions;
  }

  double _priceForHours(int h) {
    if (_rateCard == null) return 0;
    return _rateCard!.basePrice + (h * _rateCard!.pricePerHour);
  }

  // Format 24-h slot string for display: '13:00' → '01:00 PM'
  String _formatSlot24To12(String slot) {
    try {
      final parts = slot.split(':');
      final h = int.parse(parts[0]);
      final m = parts[1];
      final period = h < 12 ? 'AM' : 'PM';
      final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '${displayH.toString().padLeft(2, '0')}:$m $period';
    } catch (_) {
      return slot;
    }
  }

  int get _proceduralBufferHours => ref.read(proceduralBufferHoursProvider);

  DateTime get _longDurationMinStartDate {
    final buffer = ref.read(longDurationBufferHoursProvider);
    if (!_shiftTypeChosen) {
      return DateUtils.dateOnly(DateTime.now().add(Duration(hours: buffer)));
    }
    final settings = ref.read(systemSettingsProvider).value?.data ?? [];
    final dayStart = settings
        .firstWhere((e) => e.settingKey == 'day_shift_start_time', orElse: () => settings.first)
        .settingValue;
    final nightStart = settings
        .firstWhere((e) => e.settingKey == 'night_shift_start_time', orElse: () => settings.first)
        .settingValue;
    final effectiveShift = _longDurationShiftType == '24_hours'
        ? _effectiveShiftForFullDay
        : _longDurationShiftType;
    return _computeEarliestValidDateForShift(effectiveShift, dayStart, nightStart, buffer).date;
  }

  // Minimum allowed slot: now + buffer hours (for today only)
  bool _isSlotAvailable(String slot) {
    if (!_isTodaySelected()) return true;

    final now = DateTime.now();
    final parts = slot.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);

    final slotDateTime = DateTime(now.year, now.month, now.day, h, m);
    final earliestAllowed = now.add(Duration(hours: _proceduralBufferHours));

    return slotDateTime.isAfter(earliestAllowed) || slotDateTime.isAtSameMomentAs(earliestAllowed);
  }

  int get _minHourForToday => DateTime.now().hour + _proceduralBufferHours;

  bool _isTodaySelected() {
    final dateToCheck = _isMultiDayMode ? _multiDayStart : _startDate;
    if (dateToCheck == null) return false;
    return _isSameDay(dateToCheck, DateTime.now());
  }

  // 30-min gap slots for Morning/Afternoon/Evening (used in single-day hourly)
  static const _morningSlots = [
    '06:00',
    '06:30',
    '07:00',
    '07:30',
    '08:00',
    '08:30',
    '09:00',
    '09:30',
    '10:00',
    '10:30',
    '11:00',
    '11:30',
  ];
  static const _afternoonSlots = [
    '12:00',
    '12:30',
    '13:00',
    '13:30',
    '14:00',
    '14:30',
    '15:00',
    '15:30',
    '16:00',
    '16:30',
    '17:00',
    '17:30',
  ];
  static const _eveningSlots = [
    '18:00',
    '18:30',
    '19:00',
    '19:30',
    '20:00',
    '20:30',
    '21:00',
    '21:30',
    '22:00',
    '22:30',
    '23:00',
    '23:30',
  ];

  List<String> _getSlotsForPeriod(String period) {
    final slots = period == 'Morning'
        ? _morningSlots
        : period == 'Afternoon'
        ? _afternoonSlots
        : _eveningSlots;
    return slots.where((s) => _isSlotAvailable(s)).toList();
  }

  List<String> get _singleDayPeriodSlots => _getSlotsForPeriod(_selectedTimeOfDay);

  bool _isPeriodDisabled(String period) {
    return _getSlotsForPeriod(period).isEmpty;
  }

  // ── Quick date chips ─────────────────────────────────────────────────
  // 5 quick dates; if user picked a custom date, inject it into the list
  List<DateTime> get _quickDates => List.generate(7, (i) => DateTime.now().add(Duration(days: i)));

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _chipTopLabel(DateTime d, int i) {
    if (i == 0) return 'Today';
    if (i == 1) return 'Tomorrow';
    return '${d.day}';
  }

  String? _chipBottomLabel(DateTime d, int i) {
    if (i == 0 || i == 1) return DateFormat('dd MMM').format(d);
    return DateFormat('E').format(d);
  }

  // ── API time mapping ─────────────────────────────────────────────────
  // Slots are already 24-hour strings — pass through directly.
  String get _mappedStartTime {
    return _selectedTimeSlot ?? (_selectedShiftType == 'night' ? '21:00' : '09:00');
  }

  DateTime _getNearestValidProceduralDate() {
    final today = DateUtils.dateOnly(DateTime.now());
    bool todayHasSlots = false;
    final buffer = ref.read(proceduralBufferHoursProvider);
    for (final period in ['Morning', 'Afternoon', 'Evening']) {
      final slots = period == 'Morning'
          ? _morningSlots
          : period == 'Afternoon'
          ? _afternoonSlots
          : _eveningSlots;
      final availableSlots = slots.where((slot) {
        final now = DateTime.now();
        final parts = slot.split(':');
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);

        final slotDateTime = DateTime(now.year, now.month, now.day, h, m);
        final earliestAllowed = now.add(Duration(hours: buffer));

        return slotDateTime.isAfter(earliestAllowed) || slotDateTime.isAtSameMomentAs(earliestAllowed);
      }).toList();

      if (availableSlots.isNotEmpty) {
        todayHasSlots = true;
        break;
      }
    }
    return todayHasSlots ? today : today.add(const Duration(days: 1));
  }

  // ── initState ────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    final today = DateUtils.dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final DateTime initialStart;

    if (widget.request.startDate != null) {
      initialStart = DateUtils.dateOnly(widget.request.startDate!);
    } else {
      if (_isProcedural) {
        initialStart = _getNearestValidProceduralDate();
      } else {
        initialStart = tomorrow;
      }
    }

    _startDate = initialStart;
    _rangeStart = initialStart;
    _multiDayStart = initialStart;

    if (widget.request.durationHours != null) {
      _durationHours = widget.request.durationHours!;
    }
    if (_rateCard?.pricePerHour == 0) {
      _durationHours = 1;
    }

    if (widget.request.durationDays != null) {
      _rangeEnd = initialStart.add(Duration(days: widget.request.durationDays! - 1));
      _multiDayEnd = _rangeEnd;
    } else {
      // Default 1-day span (inclusive of start day).
      _rangeEnd = initialStart;
      _multiDayEnd = _rangeEnd;
    }

    if (widget.request.shiftType != null) {
      _selectedShiftType = widget.request.shiftType!;
    }

    // Sync initial scheduled dates + auto-select best package
    _syncScheduledDates();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isLongDuration) {
        _autoSelectNearestSlot();
      } else {
        _autoSelectLongDurationShift();
      }
    });
  }

  void _autoSelectLongDurationShift() {
    if (_rateCard == null || _shiftTypeChosen) return;

    final isDayDisabled = (_rateCard!.pricePerDay) <= 0;
    final isNightDisabled = (_rateCard!.pricePerNight) <= 0;
    final isFullDayDisabled = (_rateCard!.pricePerFullDay) <= 0;

    int disabledCount = (isDayDisabled ? 1 : 0) + (isNightDisabled ? 1 : 0) + (isFullDayDisabled ? 1 : 0);

    if (disabledCount == 2) {
      String autoShift = '';
      if (!isDayDisabled) {
        autoShift = 'day';
      } else if (!isNightDisabled) {
        autoShift = 'night';
      } else if (!isFullDayDisabled) {
        autoShift = '24_hours';
      }

      if (autoShift.isNotEmpty) {
        final settings = ref.read(systemSettingsProvider).value?.data ?? [];
        final dayStart = settings.isNotEmpty
            ? settings
                  .firstWhere((e) => e.settingKey == 'day_shift_start_time', orElse: () => settings.first)
                  .settingValue
            : '08:00';
        final nightStart = settings.isNotEmpty
            ? settings
                  .firstWhere((e) => e.settingKey == 'night_shift_start_time', orElse: () => settings.first)
                  .settingValue
            : '20:00';
        final buffer = ref.read(longDurationBufferHoursProvider);

        _handleShiftTypeChanged(autoShift, dayStart, nightStart, buffer);
      }
    }
  }

  void _autoSelectNearestSlot() {
    String? foundPeriod;
    String? foundSlot;

    // Check each period in order to find the first one with available slots
    for (final period in ['Morning', 'Afternoon', 'Evening']) {
      final slots = _getSlotsForPeriod(period);
      if (slots.isNotEmpty) {
        foundPeriod = period;
        foundSlot = slots.first;
        break;
      }
    }

    if (foundPeriod != null) {
      setState(() {
        _selectedTimeOfDay = foundPeriod!;
        _selectedShiftType = foundPeriod == 'Evening' ? 'night' : 'day';
        _selectedTimeSlot = foundSlot;
      });
    }
  }

  String _formatShiftTime(String? timeStr) {
    if (timeStr == null || !timeStr.contains(':')) return '';
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final dt = DateTime(2024, 1, 1, hour, minute);
      return DateFormat('hh:mm a').format(dt).toUpperCase();
    } catch (_) {
      return '';
    }
  }

  /// Returns the earliest valid start date for a given shift type.
  /// Also signals whether the date had to be moved to tomorrow (for the info banner).
  ({DateTime date, bool movedToTomorrow}) _computeEarliestValidDateForShift(
    String shiftType,
    String dayShiftStart,
    String nightShiftStart,
    int bufferHours,
  ) {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final tomorrow = today.add(const Duration(days: 1));
    final nowFrac = now.hour + now.minute / 60.0;

    double cutoff(String timeStr) {
      final parts = timeStr.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      return h + m / 60.0 - bufferHours;
    }

    final dayCutoff = cutoff(dayShiftStart);
    final nightCutoff = cutoff(nightShiftStart);

    if (shiftType == 'day') {
      return nowFrac <= dayCutoff
          ? (date: today, movedToTomorrow: false)
          : (date: tomorrow, movedToTomorrow: true);
    }
    if (shiftType == 'night') {
      return nowFrac <= nightCutoff
          ? (date: today, movedToTomorrow: false)
          : (date: tomorrow, movedToTomorrow: true);
    }
    // '24_hours': use day if available, then night, then tomorrow
    if (nowFrac <= dayCutoff || nowFrac <= nightCutoff) {
      return (date: today, movedToTomorrow: false);
    }
    return (date: tomorrow, movedToTomorrow: true);
  }

  // When user switches date, re-auto-select if slots become invalid
  void _onDateSelected(DateTime d) {
    setState(() {
      _startDate = d;
      _customPickedDate = null; // reset custom — handled below in _pickDate
      _syncScheduledDates();
    });
    // Re-validate current slot
    _revalidateSlot();
  }

  void _revalidateSlot() {
    // If current slot is null or no longer available (e.g. date changed to today)
    if (_selectedTimeSlot == null || !_singleDayPeriodSlots.contains(_selectedTimeSlot)) {
      _autoSelectNearestSlot();
    }
  }

  // Home visit "More" date picker
  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showSingleDatePickerSheet(
      context,
      title: 'Select Date',
      firstDay: today,
      lastDay: today.add(const Duration(days: 90)),
      initialDate: _startDate,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _customPickedDate = picked;
        _syncScheduledDates();
      });
      _revalidateSlot();
    }
  }

  Future<void> _pickLongDurationStartDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final minStartDate = _longDurationMinStartDate;
    final safeInitial = (_rangeStart != null && !_rangeStart!.isBefore(minStartDate)) ? _rangeStart : minStartDate;
    final picked = await showSingleDatePickerSheet(
      context,
      title: 'Select Start Date',
      firstDay: minStartDate,
      lastDay: today.add(const Duration(days: 90)),
      initialDate: safeInitial,
    );
    if (picked != null) {
      setState(() {
        _rangeStart = picked;
        if (_rangeEnd != null && _rangeEnd!.isBefore(_rangeStart!)) _rangeEnd = null;
        _isManualSchedule = false;
        _syncScheduledDates();
      });
    }
  }

  Future<void> _pickLongDurationEndDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final firstDate = _rangeStart ?? tomorrow;
    final safeEnd = (_rangeEnd != null && !_rangeEnd!.isBefore(firstDate)) ? _rangeEnd : null;
    final picked = await showSingleDatePickerSheet(
      context,
      title: 'Select End Date',
      firstDay: firstDate,
      lastDay: today.add(const Duration(days: 90)),
      initialDate: safeEnd,
    );
    if (picked != null) {
      setState(() {
        _rangeEnd = picked;
        _isManualSchedule = false;
        final days = _rangeStart != null ? _rangeEnd!.difference(_rangeStart!).inDays + 1 : 0;
        if (days <= 13 && _subscriptionPlan == 'weekly') {
          _subscriptionPlan = 'daily';
        }
        _syncScheduledDates();
      });
    }
  }

  Future<void> _pickMultiDayStartDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final minStartDate = DateUtils.dateOnly(DateTime.now().add(Duration(hours: _proceduralBufferHours)));
    final picked = await showSingleDatePickerSheet(
      context,
      title: 'Select Start Date',
      firstDay: minStartDate,
      lastDay: today.add(const Duration(days: 90)),
      initialDate: _multiDayStart,
    );
    if (picked != null) {
      setState(() {
        _multiDayStart = picked;
        if (_multiDayEnd != null && _multiDayEnd!.isBefore(picked)) _multiDayEnd = null;
        _isManualSchedule = false;
        _syncScheduledDates();
      });
    }
  }

  Future<void> _pickMultiDayEndDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final firstDate = (_multiDayStart ?? tomorrow).add(const Duration(days: 1));
    final safeEnd = (_multiDayEnd != null && !_multiDayEnd!.isBefore(firstDate)) ? _multiDayEnd : null;
    final picked = await showSingleDatePickerSheet(
      context,
      title: 'Select End Date',
      firstDay: firstDate,
      lastDay: today.add(const Duration(days: 90)),
      initialDate: safeEnd,
    );
    if (picked != null) {
      setState(() {
        _multiDayEnd = picked;
        _isManualSchedule = false;
        _syncScheduledDates();
      });
    }
  }

  Future<void> _openCustomTimePicker() async {
    final result = await showCustomTimePickerSheet(
      context,
      initialSlot: _selectedTimeSlot,
      isToday: _isTodaySelected(),
      minHour: _minHourForToday,
    );
    if (result != null) {
      setState(() => _selectedTimeSlot = result);
    }
  }

  List<String> _computeScheduledDates(DateTime start, DateTime end) {
    final dates = <String>[];
    DateTime current = DateUtils.dateOnly(start);
    final endDay = DateUtils.dateOnly(end);
    int index = 0;
    while (!current.isAfter(endDay)) {
      bool shouldAdd = false;
      if (_subscriptionPlan == 'daily') {
        shouldAdd = true;
      } else if (_subscriptionPlan == 'alternate') {
        shouldAdd = index % 2 == 0;
      } else if (_subscriptionPlan == 'weekly') {
        shouldAdd = _selectedWeekdays.contains(current.weekday);
      }

      if (shouldAdd) {
        dates.add(DateFormat('yyyy-MM-dd').format(current));
      }
      current = current.add(const Duration(days: 1));
      index++;
    }
    return dates;
  }

  void _syncScheduledDates() {
    if (_isManualSchedule) return;

    // Reset alternate plan if fewer than 4 days (alternate needs at least 2 slots)
    final effectiveDays = _isMultiDayMode
        ? (_multiDayStart != null && _multiDayEnd != null
              ? _multiDayEnd!.difference(_multiDayStart!).inDays + 1
              : 0)
        : _rangeDaysCount;
    if (_subscriptionPlan == 'alternate' && effectiveDays < 3) {
      _subscriptionPlan = 'daily';
    }

    final start = _isMultiDayMode ? _multiDayStart : (_isLongDuration ? _rangeStart : _startDate);
    final end = _isMultiDayMode ? _multiDayEnd : (_isLongDuration ? _rangeEnd : null);

    if (start == null || (end == null && !_isLongDuration && !_isMultiDayMode)) {
      if (start != null) {
        _activeScheduledDates = [DateFormat('yyyy-MM-dd').format(start)];
      } else {
        _activeScheduledDates = [];
      }
      return;
    }

    if (end == null) {
      _activeScheduledDates = [DateFormat('yyyy-MM-dd').format(start)];
      return;
    }

    _activeScheduledDates = _computeScheduledDates(start, end);
    if (_isLongDuration) _autoSelectBestPackage();
  }

  void _autoSelectBestPackage() {
    final days = _activeScheduledDates.length;
    final eligible = _filteredPackages.where((p) => p.duration <= days).toList();
    if (eligible.isEmpty) {
      _selectedPackageId = null;
      return;
    }
    final best = eligible.reduce((a, b) => a.duration > b.duration ? a : b);
    _selectedPackageId = best.id;
  }

  void _showPackageBottomSheet() {
    showPackagePickerSheet(
      context,
      scheduledDays: _activeScheduledDates.length,
      packages: _filteredPackages,
      selectedPackageId: _selectedPackageId,
      startDate: _rangeStart,
      onApplyPackage: (pkg) {
        setState(() {
          _selectedPackageId = pkg.id;
          if (_rangeStart != null) {
            _rangeEnd = _rangeStart!.add(Duration(days: pkg.duration - 1));
          }
          _syncScheduledDates();
        });
      },
      onChanged: (id) {
        if (id == null) {
          setState(() {
            _selectedPackageId = null;
          });
        }
      },
    );
  }

  void _next() {
    // Handle multi-day hourly bookings
    if (_isMultiDayProcedural) {
      if (_multiDayStart == null || _multiDayEnd == null) {
        MessageService.showWarning('Please select both start and end dates');
        return;
      }
      if (_selectedTimeSlot == null) {
        MessageService.showWarning('Please select a start time');
        return;
      }

      final startTime = _selectedTimeSlot!;

      // For weekly/alternate, use first/last scheduled date — not the calendar range.
      final useScheduledBounds = _subscriptionPlan != 'daily' && _activeScheduledDates.isNotEmpty;
      final effectiveStartDate = useScheduledBounds ? DateTime.parse(_activeScheduledDates.first) : _multiDayStart;
      final effectiveEndDate = useScheduledBounds ? DateTime.parse(_activeScheduledDates.last) : _multiDayEnd;
      final effectiveDurationDays = useScheduledBounds
          ? _activeScheduledDates.length
          : _multiDayEnd!.difference(_multiDayStart!).inDays + 1;

      // Calculate end time by adding duration to start time
      String? endTime;
      try {
        final parts = startTime.split(':');
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final qtyMin = _rateCard?.qtyInMin;
        final totalMinutes = h * 60 + m + (qtyMin != null ? _durationHours * qtyMin : _durationHours * 60);
        final endH = (totalMinutes ~/ 60) % 24;
        final endMin = totalMinutes % 60;
        endTime = '${endH.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}';
      } catch (_) {
        endTime = null;
      }

      widget.onUpdate(
        widget.request.copyWith(
          startDate: effectiveStartDate,
          endDate: effectiveEndDate,
          durationDays: effectiveDurationDays,
          durationHours: _durationHours,
          estimatedPrice: _estimatedTotal,
          shiftType: _selectedShiftType,
          startTime: startTime,
          endTime: endTime,
          serviceMode: 'home_visit',
          gstPercentage: _gstPercentage,
          alternateDays: _subscriptionPlan == 'alternate',
          scheduledDates: _activeScheduledDates,
        ),
      );
      Navigator.of(context).pushNamed(BookingRoutes.address);
      return;
    }

    // Require end date for long duration (minimum 1 day)
    if (_isLongDuration && _rangeEnd == null) {
      MessageService.showWarning('Please select an end date to continue');
      return;
    }

    // Block if user cleared all scheduled dates from View Schedule
    if (_isLongDuration && _activeScheduledDates.isEmpty) {
      MessageService.showWarning('Please select at least one service day to continue');
      return;
    }

    // If user never picked an end date, fall back to start date (1-day booking).
    final effectiveEnd = _isLongDuration ? (_rangeEnd ?? _rangeStart) : null;
    final effectiveDays = (effectiveEnd != null && _rangeStart != null)
        ? effectiveEnd.difference(_rangeStart!).inDays + 1
        : 1;

    // Shift times from settings
    final settingsResponse = ref.read(systemSettingsProvider).value;
    final settings = settingsResponse?.data;
    final dayShiftStart =
        settings
            ?.firstWhere((e) => e.settingKey == 'day_shift_start_time', orElse: () => settings[0])
            .settingValue ??
        '08:00';
    final nightShiftStart =
        settings
            ?.firstWhere((e) => e.settingKey == 'night_shift_start_time', orElse: () => settings[0])
            .settingValue ??
        '20:00';

    String startTime = _mappedStartTime;
    String? endTime;
    String? serviceStartShift;
    String shiftType = _isLongDuration ? _longDurationShiftType : _selectedShiftType;
    DateTime finalEndDate = _isLongDuration ? (effectiveEnd ?? _rangeStart!) : _startDate;

    if (_isLongDuration) {
      if (shiftType == 'day') {
        startTime = dayShiftStart;
        endTime = nightShiftStart;
        serviceStartShift = 'day';
      } else if (shiftType == 'night') {
        startTime = nightShiftStart;
        endTime = dayShiftStart;
        serviceStartShift = 'night';
      } else {
        // full_day: use cycle explicitly chosen by user
        final usesNight = _fullDayStartCycle == 'evening';
        startTime = usesNight ? nightShiftStart : dayShiftStart;
        serviceStartShift = usesNight ? 'night' : 'day';
        endTime = startTime; // 24h cycle: ends at same time next day
      }
    } else {
      // Hourly care: calculate end time by adding duration to start time
      try {
        final parts = startTime.split(':');
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final qtyMin = _rateCard?.qtyInMin;
        final totalMinutes = h * 60 + m + (qtyMin != null ? _durationHours * qtyMin : _durationHours * 60);

        // Rollover check
        if (totalMinutes >= 24 * 60) {
          finalEndDate = _startDate.add(const Duration(days: 1));
        }

        final endH = (totalMinutes ~/ 60) % 24;
        final endMin = totalMinutes % 60;
        endTime = '${endH.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}';
      } catch (_) {
        endTime = null;
      }
    }

    final serviceMode = /*(effectiveDays > 1) ? 'live_in' : */ 'home_visit';

    // For weekly/alternate long-duration, use first/last scheduled date — not the calendar range.
    final useScheduledBounds = _isLongDuration && _subscriptionPlan != 'daily' && _activeScheduledDates.isNotEmpty;
    final effectiveStartDate = useScheduledBounds
        ? DateTime.parse(_activeScheduledDates.first)
        : (_isLongDuration ? _rangeStart : _startDate);
    final effectiveEndDate = useScheduledBounds ? DateTime.parse(_activeScheduledDates.last) : finalEndDate;

    // copyWith(field: null) won't clear existing values — copyWith uses `??`.
    // Mutate directly so nulls propagate correctly.
    if (_isLongDuration && _selectedPackageId == null) {
      widget.request.selectedPackageId = null;
    }
    if (!_isLongDuration) {
      // Procedural booking — clear any stale long-duration or multi-day values.
      widget.request.durationDays = null;
      widget.request.selectedPackageId = null;
    }
    widget.onUpdate(
      widget.request.copyWith(
        startDate: effectiveStartDate,
        endDate: effectiveEndDate,
        durationHours: _isLongDuration ? null : _durationHours,
        durationDays: _isLongDuration ? effectiveDays : null,
        estimatedPrice: _estimatedTotal,
        shiftType: shiftType,
        serviceStartShift: serviceStartShift,
        startTime: startTime,
        endTime: endTime,
        serviceMode: serviceMode,
        selectedPackageId: _isLongDuration ? _selectedPackageId : null,
        gstPercentage: _gstPercentage,
        alternateDays: _isLongDuration ? (_subscriptionPlan == 'alternate') : false,
        scheduledDates: _activeScheduledDates,
      ),
    );
    Navigator.of(context).pushNamed(BookingRoutes.address);
  }

  Widget _buildProceduralBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── PILL TOGGLE ─────────────────────────────────────────────
        Padding(
          padding: AppPadding.sHorizontal,
          child: Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12.r)),
            child: Row(
              children: [
                _TogglePill(
                  label: 'Single Day',
                  icon: Icons.today_rounded,
                  isActive: !_isMultiDayMode,
                  onTap: () => setState(() {
                    _isMultiDayMode = false;
                    _startDate = _getNearestValidProceduralDate();
                    _syncScheduledDates();
                    _autoSelectNearestSlot();
                  }),
                ),
                SizedBox(width: 4.w),
                _TogglePill(
                  label: 'Multiple Days',
                  icon: Icons.date_range_rounded,
                  isActive: _isMultiDayMode,
                  onTap: () => setState(() {
                    _isMultiDayMode = true;
                    _multiDayStart = _getNearestValidProceduralDate();
                    _multiDayEnd = _multiDayStart!.add(const Duration(days: 29));
                    _syncScheduledDates();
                    _autoSelectNearestSlot();
                  }),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 20.h),

        // ── BODY CONTENT ────────────────────────────────────────────
        _isMultiDayProcedural ? _buildProceduralMultiDayBody() : _buildProceduralSingleDayBody(),
      ],
    );
  }

  // State for expandable time slots
  bool _showAllSlots = false;
  static const int _maxVisibleSlotRows = 2; // ~10 slots visible initially

  Widget _buildProceduralMultiDayBody() {
    final multiDayCount = _multiDayStart != null && _multiDayEnd != null
        ? _multiDayEnd!.difference(_multiDayStart!).inDays + 1
        : 0;

    final currentPeriodSlots = _getSlotsForPeriod(_selectedTimeOfDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── DATE & PLAN SELECTION CONTAINER ──────────────────────────
        Padding(
          padding: AppPadding.sHorizontal,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 4.w),
            decoration: BoxDecoration(
              color: kWhiteColor,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: kBorderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── SELECT DATES ────────────────────────────────────────────
                const _SectionHeader(label: 'Select Dates'),
                SizedBox(height: 12.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child: Row(
                    children: [
                      // Start date card
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickMultiDayStartDate,
                          child: _DateCard(
                            label: 'Start Date',
                            date: _multiDayStart,
                            icon: Icons.calendar_month,
                            color: kPrimaryColor,
                          ),
                        ),
                      ),
                      // Arrow connector
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        child: Column(
                          children: [
                            if (multiDayCount > 0)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: kPrimaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                child: Text(
                                  '$multiDayCount ${multiDayCount == 1 ? 'day' : 'days'}',
                                  style: kTextSemiBold0(color: kPrimaryColor).copyWith(fontSize: 10.sp),
                                ),
                              )
                            else
                              Icon(Icons.arrow_forward_rounded, color: kTextHintColor, size: 20.sp),
                          ],
                        ),
                      ),
                      // End date card
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickMultiDayEndDate,
                          child: _DateCard(
                            label: 'End Date',
                            date: _multiDayEnd,
                            icon: Icons.calendar_month,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── SUBSCRIPTION PLAN ────────────────────────────────────────
                if (_multiDayStart != null && _multiDayEnd != null && multiDayCount > 1) ...[
                  SizedBox(height: 20.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Divider(color: kBorderColor, height: 1),
                  ),
                  SizedBox(height: 20.h),
                  const _SectionHeader(label: 'Selected Plan', subHeading: 'Get service on selected day(s)'),
                  SizedBox(height: 12.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Row(
                      children: [
                        _PlanPill(
                          label: 'Daily',
                          isActive: _subscriptionPlan == 'daily',
                          onTap: () => setState(() {
                            _subscriptionPlan = 'daily';
                            _isManualSchedule = false;
                            _syncScheduledDates();
                          }),
                        ),
                        SizedBox(width: 8.w),
                        _PlanPill(
                          label: 'Alternate',
                          isActive: _subscriptionPlan == 'alternate',
                          disabled: multiDayCount < 3,
                          disabledMessage: 'Select at least 3 days to use Alternate plan',
                          onTap: () => setState(() {
                            _subscriptionPlan = 'alternate';
                            _isManualSchedule = false;
                            _syncScheduledDates();
                          }),
                        ),
                        if (multiDayCount >= 14) ...[
                          SizedBox(width: 8.w),
                          _PlanPill(
                            label: 'Weekly',
                            isActive: _subscriptionPlan == 'weekly',
                            onTap: () => setState(() {
                              _subscriptionPlan = 'weekly';
                              _isManualSchedule = false;
                              if (_selectedWeekdays.isEmpty) {
                                _selectedWeekdays = [DateTime.now().weekday];
                              }
                              _syncScheduledDates();
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_subscriptionPlan == 'weekly') ...[
                    SizedBox(height: 20.h),
                    const _SectionHeader(
                      label: 'Select day(s) for Service',
                      subHeading: 'Get service on below day(s) every week',
                    ),
                    SizedBox(height: 12.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      child: _buildWeekdaySelector(),
                    ),
                  ],
                  SizedBox(height: 20.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${_activeScheduledDates.length} service days scheduled',
                            style: kTextMedium(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                          ),
                        ),
                        GestureDetector(
                          onTap: _showScheduleBottomSheet,
                          child: Row(
                            children: [
                              Text(
                                'View Schedule',
                                style: kTextBold(color: kPrimaryColor).copyWith(fontSize: 12.sp),
                              ),
                              Icon(Icons.keyboard_arrow_right_rounded, color: kPrimaryColor, size: 18.sp),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        SizedBox(height: 15.h),
        // ── DURATION (HOURS PER DAY) ────────────────────────────────
        _SectionHeader(label: _durationSectionTitle),
        SizedBox(height: 10.h),
        _ScrollFadeWrapper(
          child: _HourChipRow(
            hourOptions: _effectiveHourOptions,
            selected: _effectiveHourOptions.contains(_durationHours) ? _durationHours : 1,
            priceFor: _priceForHours,
            onSelect: (h) => setState(() => _durationHours = h),
            unitType: _rateCard?.unitType,
          ),
        ),
        SizedBox(height: 24.h),

        // ── PREFERRED TIME + SLOTS (contained) ─────────────────────
        _buildPreferredTimeContainer(
          slots: currentPeriodSlots,
          selectedSlot: _selectedTimeSlot,
          onSelect: (slot) => setState(() => _selectedTimeSlot = slot),
        ),
        SizedBox(height: 24.h),

        // ── BOOKING SUMMARY ─────────────────────────────────────────
        if (multiDayCount > 0 && _selectedTimeSlot != null)
          Padding(
            padding: AppPadding.sHorizontal,
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kPrimaryColor.withValues(alpha: 0.06), kPrimaryColor.withValues(alpha: 0.02)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: kPrimaryColor.withValues(alpha: 0.15)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.summarize_outlined, size: 16.sp, color: kPrimaryColor),
                      SizedBox(width: 6.w),
                      Text('Booking Summary', style: kTextSemiBold(color: kPrimaryColor)),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _SummaryRow(
                    label: 'Duration',
                    value: () {
                      final days = _activeScheduledDates.isNotEmpty ? _activeScheduledDates.length : multiDayCount;
                      final unit = _rateCard?.unitType;
                      return unit != null
                          ? '$days days, $_durationHours $unit/day'
                          : '$days days, $_durationHours hrs/day';
                    }(),
                  ),
                  SizedBox(height: 6.h),
                  _SummaryRow(
                    label: _rateCard?.unitType != null ? 'Total ${_rateCard!.unitType}s' : 'Total Hours',
                    value: () {
                      final days = _activeScheduledDates.isNotEmpty ? _activeScheduledDates.length : multiDayCount;
                      final unit = _rateCard?.unitType;
                      return unit != null ? '${_durationHours * days} ${unit}s' : '${_durationHours * days} hrs';
                    }(),
                  ),
                  SizedBox(height: 6.h),
                  _SummaryRow(label: 'Start Time', value: _formatSlot24To12(_selectedTimeSlot!)),
                  SizedBox(height: 6.h),
                  Divider(color: kPrimaryColor.withValues(alpha: 0.1)),
                  SizedBox(height: 4.h),
                  _SummaryRow(
                    label: 'Estimated Price',
                    value: NumberUtils.formatCurrency(_multiDayHourlyTotal, decimalDigits: 0),
                    isBold: true,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPreferredTimeContainer({
    required List<String> slots,
    required String? selectedSlot,
    required ValueChanged<String> onSelect,
  }) {
    return Padding(
      padding: AppPadding.sHorizontal,
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: kBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Preferred Time', style: kTextBold()),
            SizedBox(height: 12.h),
            // Period tabs
            Row(
              children: [
                _PeriodTab(
                  label: 'Morning',
                  icon: Icons.wb_sunny_outlined,
                  subtitle: '6 AM - 12 PM',
                  isSelected: _selectedTimeOfDay == 'Morning',
                  isDisabled: _isPeriodDisabled('Morning'),
                  onTap: () => setState(() {
                    _selectedTimeOfDay = 'Morning';
                    _selectedShiftType = 'day';
                    _selectedTimeSlot = null;
                    _showAllSlots = false;
                  }),
                ),
                SizedBox(width: 6.w),
                _PeriodTab(
                  label: 'Afternoon',
                  icon: Icons.wb_twilight_rounded,
                  subtitle: '12 PM - 6 PM',
                  isSelected: _selectedTimeOfDay == 'Afternoon',
                  isDisabled: _isPeriodDisabled('Afternoon'),
                  onTap: () => setState(() {
                    _selectedTimeOfDay = 'Afternoon';
                    _selectedShiftType = 'day';
                    _selectedTimeSlot = null;
                    _showAllSlots = false;
                  }),
                ),
                SizedBox(width: 6.w),
                _PeriodTab(
                  label: 'Evening',
                  icon: Icons.nights_stay_outlined,
                  subtitle: '6 PM - 12 AM',
                  isSelected: _selectedTimeOfDay == 'Evening',
                  isDisabled: _isPeriodDisabled('Evening'),
                  onTap: () => setState(() {
                    _selectedTimeOfDay = 'Evening';
                    _selectedShiftType = 'night';
                    _selectedTimeSlot = null;
                    _showAllSlots = false;
                  }),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Divider(color: kBorderColor, height: 1),
            SizedBox(height: 14.h),
            // Time slots (no extra horizontal padding — container handles it)
            _buildExpandableTimeSlotsInline(slots: slots, selectedSlot: selectedSlot, onSelect: onSelect),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableTimeSlotsInline({
    required List<String> slots,
    required String? selectedSlot,
    required ValueChanged<String> onSelect,
  }) {
    final slotsPerRow = 4;
    final maxInitial = slotsPerRow * _maxVisibleSlotRows;
    final showMore = slots.length > maxInitial && !_showAllSlots;
    final visibleSlots = showMore ? slots.sublist(0, maxInitial) : slots;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('Select Time', style: kTextNormal(color: kTextSecondaryColor)),
                if (selectedSlot != null) ...[
                  SizedBox(width: 8.w),
                  Text(
                    '(${_formatSlot24To12(selectedSlot)})',
                    style: kTextMedium(color: kPrimaryColor).copyWith(fontSize: 10.sp),
                  ),
                ],
              ],
            ),
            GestureDetector(
              onTap: _openCustomTimePicker,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_rounded, color: kPrimaryColor, size: 13.sp),
                    SizedBox(width: 4.w),
                    Text(
                      'Custom',
                      style: kTextMedium(color: kPrimaryColor).copyWith(fontSize: 11.sp),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        if (slots.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20.h),
            child: Center(
              child: Text(
                'No slots available for this period today.',
                style: kTextMedium(color: kTextHintColor).copyWith(fontSize: 12.sp),
              ),
            ),
          )
        else ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleSlots.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8.h,
              crossAxisSpacing: 8.w,
              childAspectRatio: 2.1,
            ),
            itemBuilder: (context, index) {
              final slot = visibleSlots[index];
              final isSelected = selectedSlot == slot;
              return GestureDetector(
                onTap: () => onSelect(slot),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? kPrimaryColor : kWhiteColor,
                    border: Border.all(
                      color: isSelected ? kPrimaryColor : kBorderColor,
                      width: isSelected ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: kPrimaryColor.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    _formatSlot24To12(slot),
                    style: kTextMedium(
                      color: isSelected ? kWhiteColor : kTextPrimaryColor,
                    ).copyWith(fontSize: 10.5.sp),
                  ),
                ),
              );
            },
          ),
          if (showMore) ...[
            SizedBox(height: 8.h),
            GestureDetector(
              onTap: () => setState(() => _showAllSlots = true),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Show more slots',
                    style: kTextMedium(color: kPrimaryColor).copyWith(fontSize: 12.sp),
                  ),
                  SizedBox(width: 4.w),
                  Icon(Icons.keyboard_arrow_down_rounded, color: kPrimaryColor, size: 18.sp),
                ],
              ),
            ),
          ],
          if (_showAllSlots && slots.length > maxInitial) ...[
            SizedBox(height: 8.h),
            GestureDetector(
              onTap: () => setState(() => _showAllSlots = false),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Show less',
                    style: kTextMedium(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                  ),
                  SizedBox(width: 4.w),
                  Icon(Icons.keyboard_arrow_up_rounded, color: kTextSecondaryColor, size: 18.sp),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildProceduralSingleDayBody() {
    final quickDates = _quickDates;
    final bool customIsOutside =
        _customPickedDate != null && quickDates.every((d) => !_isSameDay(d, _customPickedDate!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. SELECT DATE ──────────────────────────────────────
        _SectionHeader(label: 'Select Date'),
        SizedBox(height: 10.h),
        _ScrollFadeWrapper(
          child: _DateChipRow(
            quickDates: quickDates,
            customDate: customIsOutside ? _customPickedDate : null,
            selected: _startDate,
            isSameDay: _isSameDay,
            topLabel: _chipTopLabel,
            bottomLabel: _chipBottomLabel,
            onSelect: _onDateSelected,
            onPickMore: _pickDate,
          ),
        ),
        SizedBox(height: 24.h),

        // ── 2. DURATION ─────────────────────────────────────────
        _SectionHeader(label: _durationSectionTitle),
        SizedBox(height: 10.h),
        _ScrollFadeWrapper(
          child: _HourChipRow(
            hourOptions: _effectiveHourOptions,
            selected: _effectiveHourOptions.contains(_durationHours) ? _durationHours : 1,
            priceFor: _priceForHours,
            onSelect: (h) => setState(() => _durationHours = h),
            unitType: _rateCard?.unitType,
          ),
        ),
        SizedBox(height: 24.h),

        // ── 3. PREFERRED TIME + SLOTS (contained) ────────────────
        _buildPreferredTimeContainer(
          slots: _singleDayPeriodSlots,
          selectedSlot: _selectedTimeSlot,
          onSelect: (v) => setState(() => _selectedTimeSlot = v),
        ),
        SizedBox(height: 24.h),
      ],
    );
  }

  // ── LONG DURATION BODY ─────────────────────────────────────────────────────

  Widget _buildShiftTypeSelector() {
    final settingsResponse = ref.watch(systemSettingsProvider);
    return settingsResponse.when(
      data: (response) {
        final settings = response.data;
        final dayStart = settings
            .firstWhere((e) => e.settingKey == 'day_shift_start_time', orElse: () => settings[0])
            .settingValue;
        final nightStart = settings
            .firstWhere((e) => e.settingKey == 'night_shift_start_time', orElse: () => settings[0])
            .settingValue;
        final buffer = ref.read(longDurationBufferHoursProvider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _ShiftTypeRow(
              selected: _shiftTypeChosen ? _longDurationShiftType : '',
              onChanged: (v) {
                _handleShiftTypeChanged(v, dayStart, nightStart, buffer);
              },
              dayTime: '${_formatShiftTime(dayStart)} - ${_formatShiftTime(nightStart)}',
              nightTime: '${_formatShiftTime(nightStart)} - ${_formatShiftTime(dayStart)}',
              isDayDisabled: (_rateCard?.pricePerDay ?? 0) <= 0,
              isNightDisabled: (_rateCard?.pricePerNight ?? 0) <= 0,
              isFullDayDisabled: (_rateCard?.pricePerFullDay ?? 0) <= 0,
            ),
            // Full Day cycle picker — animated inline section
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: (_shiftTypeChosen && _longDurationShiftType == '24_hours')
                  ? _buildFullDayStartPicker(dayShiftStart: dayStart, nightShiftStart: nightStart)
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  void _handleShiftTypeChanged(String v, String dayStart, String nightStart, int buffer) {
    setState(() {
      _shiftTypeChosen = true;
      _longDurationShiftType = v;
      _selectedPackageId = null;
      _fullDayStartCycle = null;
      _autoDateMessage = null;
      _fullDayPickerExpanded = v == '24_hours';
      if (v == '24_hours') _rangeStart = null; // reset so cycle choice always auto-picks fresh

      if (v != '24_hours') {
        // Day/Night: auto-select date immediately
        final autoDate = _computeEarliestValidDateForShift(v, dayStart, nightStart, buffer);
        _rangeStart = autoDate.date;
        _autoDateMessage = autoDate.movedToTomorrow
            ? "Today's slot unavailable. Next available date selected automatically."
            : null;
        if (_rangeEnd != null && _rangeEnd!.isBefore(_rangeStart!)) _rangeEnd = null;
        final newPkgs = (_rateCard?.packages ?? []).where((p) => p.shiftType == _toPackageShiftType(v)).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        if (_rangeEnd == null && newPkgs.isNotEmpty) {
          _rangeEnd = _rangeStart!.add(Duration(days: newPkgs.first.duration - 1));
        }
        _isManualSchedule = false;
        _syncScheduledDates();
        _autoSelectBestPackage();
      }
      // Full Day: wait for morning/evening selection — handled in _runFullDayAutoDate
    });
  }

  void _runFullDayAutoDate() {
    if (_fullDayStartCycle == null) return;
    final settings = ref.read(systemSettingsProvider).value?.data ?? [];
    final dayStart =
        settings
            .firstWhere((e) => e.settingKey == 'day_shift_start_time', orElse: () => settings.first)
            .settingValue;
    final nightStart =
        settings
            .firstWhere((e) => e.settingKey == 'night_shift_start_time', orElse: () => settings.first)
            .settingValue;
    final buffer = ref.read(longDurationBufferHoursProvider);

    final minDate = _computeEarliestValidDateForShift(_effectiveShiftForFullDay, dayStart, nightStart, buffer);

    // Only override _rangeStart if user has no date yet OR their date is before the minimum valid date.
    // If user already picked a future date that's still valid, keep it.
    final needsDateUpdate = _rangeStart == null || _rangeStart!.isBefore(minDate.date);
    if (needsDateUpdate) {
      _rangeStart = minDate.date;
      _autoDateMessage = minDate.movedToTomorrow
          ? "Today's slot unavailable. Next available date selected automatically."
          : null;
    } else {
      _autoDateMessage = null;
    }

    if (_rangeEnd != null && _rangeEnd!.isBefore(_rangeStart!)) _rangeEnd = null;

    final newPkgs =
        (_rateCard?.packages ?? []).where((p) => p.shiftType == _toPackageShiftType('24_hours')).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (_rangeEnd == null && newPkgs.isNotEmpty) {
      _rangeEnd = _rangeStart!.add(Duration(days: newPkgs.first.duration - 1));
    }
    _isManualSchedule = false;
    _syncScheduledDates();
    _autoSelectBestPackage();
  }

  Widget _buildFullDayStartPicker({required String dayShiftStart, required String nightShiftStart}) {
    // Collapsed summary shown after selection
    if (!_fullDayPickerExpanded && _fullDayStartCycle != null) {
      final isEvening = _fullDayStartCycle == 'evening';
      final label = isEvening ? 'Evening Start' : 'Morning Start';
      final timeRange = isEvening
          ? '${_formatShiftTime(nightShiftStart)} → Next Day ${_formatShiftTime(nightShiftStart)}'
          : '${_formatShiftTime(dayShiftStart)} → Next Day ${_formatShiftTime(dayShiftStart)}';
      final icon = isEvening ? Icons.nights_stay_outlined : Icons.wb_sunny_outlined;
      final accent = isEvening ? const Color(0xFF6366F1) : const Color(0xFFF59E0B);

      return Padding(
        padding: EdgeInsets.only(top: 14.h, left: 8.w, right: 8.w),
        child: GestureDetector(
          onTap: () => setState(() => _fullDayPickerExpanded = true),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: kPrimaryColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16.sp, color: accent),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: kTextSemiBold(color: kPrimaryColor).copyWith(fontSize: 13.sp),
                      ),
                      Text(
                        timeRange,
                        style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    'Change',
                    style: kTextMedium(color: kPrimaryColor).copyWith(fontSize: 11.sp),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Expanded picker
    return Padding(
      padding: EdgeInsets.only(top: 16.h, left: 12.w, right: 12.w),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -9.h,
            right: 40.w,
            child: CustomPaint(
              size: Size(18.w, 9.h),
              painter: _UpArrowPainter(fillColor: kWhiteColor, borderColor: kBorderColor),
            ),
          ),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: kWhiteColor,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: kBorderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('When should the 24-hour care begin?', style: kTextBold())),
                    if (_fullDayStartCycle != null)
                      GestureDetector(
                        onTap: () => setState(() => _fullDayPickerExpanded = false),
                        child: Icon(Icons.close_rounded, size: 18.sp, color: kTextSecondaryColor),
                      ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  'Select when the healthcare partner should begin the 24-hour care cycle.',
                  style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                ),
                SizedBox(height: 14.h),
                _buildCycleOption(
                  label: 'Morning Start',
                  timeRange: '${_formatShiftTime(dayShiftStart)} → Next Day ${_formatShiftTime(dayShiftStart)}',
                  icon: Icons.wb_sunny_outlined,
                  accentColor: const Color(0xFFF59E0B),
                  value: 'morning',
                ),
                SizedBox(height: 10.h),
                _buildCycleOption(
                  label: 'Evening Start',
                  timeRange:
                      '${_formatShiftTime(nightShiftStart)} → Next Day ${_formatShiftTime(nightShiftStart)}',
                  icon: Icons.nights_stay_outlined,
                  accentColor: const Color(0xFF6366F1),
                  value: 'evening',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleOption({
    required String label,
    required String timeRange,
    required IconData icon,
    required Color accentColor,
    required String value,
  }) {
    final isSelected = _fullDayStartCycle == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _fullDayStartCycle = value;
          _fullDayPickerExpanded = false;
          _runFullDayAutoDate();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor.withValues(alpha: 0.05) : kWhiteColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: isSelected ? kPrimaryColor : kBorderColor, width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: (isSelected ? kPrimaryColor : accentColor).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(icon, size: 18.sp, color: isSelected ? kPrimaryColor : accentColor),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: kTextSemiBold(color: isSelected ? kPrimaryColor : kTextPrimaryColor)),
                  SizedBox(height: 2.h),
                  Text(
                    timeRange,
                    style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: EdgeInsets.all(4.w),
                decoration: const BoxDecoration(color: kPrimaryColor, shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, color: kWhiteColor, size: 12.sp),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLongDurationBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: 'Shift Type'),
        SizedBox(height: 10.h),
        _shiftTypeChosen ? _buildShiftTypeSelector() : _AttentionPulse(child: _buildShiftTypeSelector()),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: _autoDateMessage != null && _isShiftFullyConfigured
              ? Padding(
                  padding: EdgeInsets.only(top: 8.h, left: 16.w, right: 16.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 13.sp,
                        color: kSecondaryColor.withValues(alpha: 0.75),
                      ),
                      SizedBox(width: 5.w),
                      Flexible(
                        child: Text(
                          _autoDateMessage!,
                          style: kTextNormal0(
                            color: kSecondaryColor.withValues(alpha: 0.75),
                          ).copyWith(fontSize: 11.sp),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 20),
          child: _shiftTypeChosen
              ? const SizedBox.shrink()
              : Padding(
                  padding: EdgeInsets.only(top: 10.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app_rounded, size: 13.sp, color: kPrimaryColor.withValues(alpha: 0.55)),
                      SizedBox(width: 5.w),
                      Text(
                        'Tap a shift to get started',
                        style: kTextNormal0(
                          color: kPrimaryColor.withValues(alpha: 0.55),
                        ).copyWith(fontSize: 11.sp),
                      ),
                    ],
                  ),
                ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          child: _isShiftFullyConfigured
              ? _buildPostShiftContent()
              : ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: IgnorePointer(child: Opacity(opacity: 0.55, child: _buildPostShiftContent())),
                ),
        ),
      ],
    );
  }

  Widget _buildPostShiftContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20.h),

        // ── DATE & PLAN SELECTION CONTAINER ──────────────────────────
        Padding(
          padding: AppPadding.sHorizontal,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 4.w),
            decoration: BoxDecoration(
              color: kWhiteColor,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: kBorderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Date Selection ───────────────────────────────────────
                const _SectionHeader(label: 'Select Dates'),
                SizedBox(height: 12.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickLongDurationStartDate,
                          child: _DateCard(
                            label: 'Start Date',
                            date: _rangeStart,
                            icon: Icons.calendar_month,
                            color: kPrimaryColor,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        child: Column(
                          children: [
                            if (_durationDays > 0)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: kPrimaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                child: Text(
                                  '$_durationDays ${_durationDays == 1 ? 'day' : 'days'}',
                                  style: kTextSemiBold0(color: kPrimaryColor).copyWith(fontSize: 10.sp),
                                ),
                              )
                            else
                              Icon(Icons.arrow_forward_rounded, color: kTextHintColor, size: 20.sp),
                          ],
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickLongDurationEndDate,
                          child: _DateCard(
                            label: 'End Date',
                            date: _rangeEnd,
                            icon: Icons.calendar_month,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_rangeStart != null && _rangeEnd != null && _durationDays > 1) ...[
                  SizedBox(height: 20.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Divider(color: kBorderColor, height: 1),
                  ),
                  SizedBox(height: 20.h),
                  const _SectionHeader(label: 'Selected Plan', subHeading: 'Get service on selected day(s)'),
                  SizedBox(height: 12.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Row(
                      children: [
                        _PlanPill(
                          label: 'Daily',
                          isActive: _subscriptionPlan == 'daily',
                          onTap: () => setState(() {
                            _subscriptionPlan = 'daily';
                            _isManualSchedule = false;
                            _syncScheduledDates();
                          }),
                        ),
                        SizedBox(width: 8.w),
                        _PlanPill(
                          label: 'Alternate',
                          isActive: _subscriptionPlan == 'alternate',
                          disabled: _rangeDaysCount < 3,
                          disabledMessage: 'Select at least 3 days to use Alternate plan',
                          onTap: () => setState(() {
                            _subscriptionPlan = 'alternate';
                            _isManualSchedule = false;
                            _syncScheduledDates();
                          }),
                        ),
                        if (_rangeDaysCount > 13) ...[
                          SizedBox(width: 8.w),
                          _PlanPill(
                            label: 'Weekly',
                            isActive: _subscriptionPlan == 'weekly',
                            onTap: () => setState(() {
                              _subscriptionPlan = 'weekly';
                              _isManualSchedule = false;
                              if (_selectedWeekdays.isEmpty) {
                                _selectedWeekdays = [DateTime.now().weekday];
                              }
                              _syncScheduledDates();
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_subscriptionPlan == 'weekly') ...[
                    SizedBox(height: 20.h),
                    const _SectionHeader(
                      label: 'Select day(s) for Service',
                      subHeading: 'Get service on below day(s) every week',
                    ),
                    SizedBox(height: 12.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      child: _buildWeekdaySelector(),
                    ),
                  ],
                  SizedBox(height: 20.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${_activeScheduledDates.length} service days scheduled',
                            style: kTextMedium(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                          ),
                        ),
                        GestureDetector(
                          onTap: _showScheduleBottomSheet,
                          child: Row(
                            children: [
                              Text('View Schedule', style: kTextBold0(color: kPrimaryColor)),
                              Icon(Icons.keyboard_arrow_right_rounded, color: kPrimaryColor, size: 18.sp),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        SizedBox(height: 16.h),

        // ── Applied Package ───────────────────────────────────────────────
        if (_filteredPackages.isNotEmpty) ...[_buildAppliedPackageSection(), SizedBox(height: 8.h)],

        AppSpacing.xlVertical,
      ],
    );
  }

  Widget _buildAppliedPackageSection() {
    final pkg = _selectedPackage;
    final hasPackage = pkg != null;
    final scheduledDays = _activeScheduledDates.length;

    // Check if package upsell banner should be shown for any next available offer package
    String? packageUpsellText;
    if (_filteredPackages.isNotEmpty) {
      final sortedPackages = [..._filteredPackages]..sort((a, b) => a.duration.compareTo(b.duration));

      RateCardPackageModel? nextPkg;
      for (final p in sortedPackages) {
        if (p.duration > scheduledDays && p.discountPercentage > 0) {
          nextPkg = p;
          break;
        }
      }

      if (nextPkg == null && scheduledDays == 0) {
        nextPkg = sortedPackages.where((p) => p.discountPercentage > 0).firstOrNull;
      }

      if (nextPkg != null && nextPkg.discountPercentage > 0) {
        final discountStr = nextPkg.discountPercentage.truncateToDouble() == nextPkg.discountPercentage
            ? nextPkg.discountPercentage.toStringAsFixed(0)
            : cleanDecimal(nextPkg.discountPercentage);

        final additionalDays = nextPkg.duration - scheduledDays;
        if (scheduledDays <= 0) {
          packageUpsellText = 'Book for ${nextPkg.duration} days or more & get Flat $discountStr% OFF.';
        } else if (additionalDays > 0) {
          packageUpsellText = 'Choose $additionalDays more ${additionalDays == 1 ? 'day' : 'days'} to get Flat $discountStr% OFF.';
        }
      }
    }

    return Padding(
      padding: AppPadding.sHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Applied package card (tappable)
          GestureDetector(
            onTap: _showPackageBottomSheet,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: hasPackage ? kPrimaryColor.withValues(alpha: 0.04) : kWhiteColor,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: hasPackage ? kPrimaryColor.withValues(alpha: 0.4) : kBorderColor,
                  width: hasPackage ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: hasPackage ? kPrimaryColor.withValues(alpha: 0.1) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      hasPackage ? Icons.local_offer_rounded : Icons.local_offer_outlined,
                      color: hasPackage ? kPrimaryColor : kTextSecondaryColor,
                      size: 18.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: hasPackage
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('${pkg.duration}-Day Package', style: kTextSemiBold(color: kPrimaryColor)),
                                  SizedBox(width: 6.w),
                                  if (pkg.discountPercentage > 0)
                                    Flexible(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                                        decoration: BoxDecoration(
                                          color: kSuccessColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4.r),
                                        ),
                                        child: Text(
                                          '${pkg.discountPercentage.truncateToDouble() == pkg.discountPercentage ? pkg.discountPercentage.toStringAsFixed(0) : cleanDecimal(pkg.discountPercentage)}% off',
                                          style: kTextSemiBold0(color: kSuccessColor).copyWith(fontSize: 10.sp),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 2.h),
                              Row(
                                children: [
                                  Text(
                                    NumberUtils.formatCurrency(pkg.price, decimalDigits: 0),
                                    style: kTextBold(color: kPrimaryColor),
                                  ),
                                  if (pkg.discountPercentage > 0) ...[
                                    SizedBox(width: 6.w),
                                    Text(
                                      NumberUtils.formatCurrency(pkg.actualPrice, decimalDigits: 0),
                                      style: kTextNormal0(color: kTextHintColor).copyWith(
                                        decoration: TextDecoration.lineThrough,
                                        decorationColor: kTextHintColor,
                                        fontSize: 11.sp,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('No package applied', style: kTextSemiBold()),
                              SizedBox(height: 2.h),
                              Text(
                                scheduledDays > 0
                                    ? 'Tap to browse packages for $scheduledDays days'
                                    : 'Choose dates to see available packages',
                                style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                              ),
                            ],
                          ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: kTextHintColor, size: 20.sp),
                ],
              ),
            ),
          ),

          // 7-day package discount offer banner container below package card
          if (packageUpsellText != null) ...[
            SizedBox(height: 10.h),
            GestureDetector(
              onTap: _showPackageBottomSheet,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: kPrimaryColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.stars_rounded, color: kPrimaryColor, size: 18.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        packageUpsellText,
                        style: kTextSemiBold0(color: kPrimaryColor).copyWith(fontSize: 12.sp),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Promo code hint
          if (scheduledDays > 0) ...[
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: kSuccessColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: kSuccessColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_offer_outlined, color: kSuccessColor, size: 16.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: kTextNormal0(color: kTextPrimaryColor).copyWith(height: 1.4),
                        children: [
                          TextSpan(text: 'Get an '),
                          TextSpan(
                            text: ' additional discount',
                            style: kTextBold(color: kSuccessColor),
                          ),
                          TextSpan(text: ' by applying a '),
                          TextSpan(
                            text: 'promo code',
                            style: kTextBold(color: kSuccessColor),
                          ),
                          TextSpan(text: ' at the time of payment.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeekdaySelector() {
    final days = [(1, 'Mo'), (2, 'Tu'), (3, 'We'), (4, 'Th'), (5, 'Fr'), (6, 'Sa'), (7, 'Su')];

    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: days.map((day) {
        final isSelected = _selectedWeekdays.contains(day.$1);
        return GestureDetector(
          onTap: () {
            setState(() {
              _isManualSchedule = false;
              if (isSelected) {
                if (_selectedWeekdays.length > 1) {
                  _selectedWeekdays.remove(day.$1);
                }
              } else {
                _selectedWeekdays.add(day.$1);
              }
              _syncScheduledDates();
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: isSelected ? kPrimaryColor : kWhiteColor,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: isSelected ? kPrimaryColor : kBorderColor),
            ),
            child: Text(
              day.$2,
              style: kTextSemiBold(color: isSelected ? kWhiteColor : kTextPrimaryColor).copyWith(fontSize: 12.sp),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showScheduleBottomSheet() {
    BookingScheduleSheet.show(
      context: context,
      scheduledDates: _activeScheduledDates,
      isMultiDayMode: _isMultiDayMode,
      selectedTimeSlot: _selectedTimeSlot,
      formatSlot: _formatSlot24To12,
      onDatesChanged: (updated) {
        setState(() {
          _activeScheduledDates
            ..clear()
            ..addAll(updated);
          _isManualSchedule = true;
          if (_isLongDuration) _autoSelectBestPackage();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final multiDayCount = _multiDayStart != null && _multiDayEnd != null
        ? _multiDayEnd!.difference(_multiDayStart!).inDays + 1
        : null;

    return BookingStepScaffold(
      title: _isLongDuration ? 'Long Duration' : 'Procedure',
      currentStep: 2,
      totalSteps: 4,
      body: SingleChildScrollView(
        padding: AppPadding.only(left: 0, right: 0, top: 12, bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ServiceHeader(service: widget.request.serviceType),
            SizedBox(height: 16.h),
            _isLongDuration ? _buildLongDurationBody() : _buildProceduralBody(),
          ],
        ),
      ),
      bottomBar: (_isLongDuration && !_isShiftFullyConfigured)
          ? null
          : _StickyPriceBar(
              estimatedTotal: _estimatedTotalFormatted,
              actualTotal: _isLongDuration
                  ? ((_selectedPackage != null && _packageSavingsAmount > 0)
                      ? NumberUtils.formatCurrency(_estimatedTotal + _packageSavingsAmount)
                      : null)
                  : (_rateCard != null && _rateCard!.proceduralDiscountPercentage > 0
                      ? () {
                          final pct = _rateCard!.proceduralDiscountPercentage;
                          final originalTotal = (pct > 0 && pct < 100)
                              ? (_estimatedTotal / (1 - pct / 100))
                              : _estimatedTotal;
                          return NumberUtils.formatCurrency(originalTotal);
                        }()
                      : null),
              hasRateCard: _rateCard != null,
              dayCount: _isLongDuration
                  ? _activeScheduledDates.length
                  : (_isMultiDayProcedural ? multiDayCount : null),
              gstPercentage: _gstPercentage,
              isPackageSelected: _isLongDuration && _selectedPackage != null,
              packageLabel: _isLongDuration && _selectedPackage != null
                  ? '${_activeScheduledDates.length} day${_activeScheduledDates.length != 1 ? 's' : ''}'
                  : null,
              packageSavingsPercent: _isLongDuration ? _packageSavingsPercent : 0,
              packageSavingsAmount: _isLongDuration ? _packageSavingsAmount : 0,
              proceduralDiscountPercent: _isLongDuration ? 0 : (_rateCard?.proceduralDiscountPercentage ?? 0),
              onContinue: _next,
              basePrice: _rateCard?.basePrice,
              pricePerHour: _rateCard?.pricePerHour,
              durationHours: _isLongDuration ? null : _durationHours,
              scheduledDays: _isMultiDayProcedural
                  ? (_activeScheduledDates.isEmpty ? (multiDayCount ?? 0) : _activeScheduledDates.length)
                  : null,
              isMultiDayProcedural: _isMultiDayProcedural,
              isLongDuration: _isLongDuration,
              unitType: _rateCard?.unitType,
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scroll fade wrapper — shows right-edge gradient to hint scrollability
// ─────────────────────────────────────────────────────────────────────────────
class _ScrollFadeWrapper extends StatelessWidget {
  final Widget child;

  const _ScrollFadeWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.white, Colors.white, Colors.white.withValues(alpha: .7)],
        stops: const [0.0, 0.82, 1.0],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final String? subHeading;

  const _SectionHeader({required this.label, this.subHeading});

  @override
  Widget build(BuildContext context) => Padding(
    padding: AppPadding.only(left: 12, right: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: kTextBold()),
        if (subHeading != null) ...[
          SizedBox(height: 2.h),
          Text(
            subHeading!,
            style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
          ),
        ],
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Service header — service image + name shown at top of step
// ─────────────────────────────────────────────────────────────────────────────
class _ServiceHeader extends StatelessWidget {
  final ServiceType? service;

  const _ServiceHeader({required this.service});

  @override
  Widget build(BuildContext context) {
    if (service == null) return const SizedBox.shrink();
    final s = service!;
    final hasDescription = s.description.isNotEmpty;
    return Padding(
      padding: AppPadding.sHorizontal,
      child: GestureDetector(
        onTap: hasDescription
            ? () => showServiceDescriptionSheet(
                context,
                name: s.name,
                iconUrl: s.iconUrl,
                fallbackIcon: s.icon,
                htmlDescription: s.description,
              )
            : null,
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [kPrimaryColor.withValues(alpha: 0.06), kAccentColor.withValues(alpha: 0.06)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: kPrimaryColor.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: kAccentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: s.iconUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10.r),
                        child: AppCachedImage(
                          imageUrl: s.iconUrl,
                          fit: BoxFit.cover,
                          errorWidgetBuilder: Icon(s.icon, color: kPrimaryColor, size: 22.sp),
                        ),
                      )
                    : Icon(s.icon, color: kPrimaryColor, size: 22.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.name,
                      style: kTextBold1(color: kPrimaryColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (s.description.isNotEmpty) ...[
                      SizedBox(height: 3.h),
                      Text(
                        _cleanDescription(s.description),
                        style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 11.5.sp),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Text(
                            'View details',
                            style: kTextSemiBold0(color: kPrimaryColor).copyWith(fontSize: 11.sp),
                          ),
                          Icon(Icons.chevron_right_rounded, color: kPrimaryColor, size: 14.sp),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _cleanDescription(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date chip row — quickDates + optional customDate chip + More picker
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
class _DateChipRow extends StatelessWidget {
  final List<DateTime> quickDates;
  final DateTime? customDate; // date picked via "More" that is outside quickDates
  final DateTime selected;
  final bool Function(DateTime, DateTime) isSameDay;
  final String Function(DateTime, int) topLabel;
  final String? Function(DateTime, int) bottomLabel;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPickMore;

  const _DateChipRow({
    required this.quickDates,
    required this.customDate,
    required this.selected,
    required this.isSameDay,
    required this.topLabel,
    required this.bottomLabel,
    required this.onSelect,
    required this.onPickMore,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(left: 12.w, right: 32.w), // extra right for fade
        children: [
          // Quick date chips
          ...List.generate(quickDates.length, (i) {
            final d = quickDates[i];
            final sel = isSameDay(d, selected);
            return _Chip(
              isSelected: sel,
              onTap: () => onSelect(d),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(topLabel(d, i), style: kTextSemiBold(color: sel ? kPrimaryColor : kTextPrimaryColor)),
                  if (bottomLabel(d, i) != null) ...[
                    SizedBox(height: 2.h),
                    Flexible(
                      child: Text(
                        bottomLabel(d, i)!,
                        style: kTextNormal0(color: sel ? kPrimaryColor : kTextSecondaryColor),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),

          // Custom picked date chip (shown when outside quickDates)
          if (customDate != null) ...[
            _Chip(
              isSelected: isSameDay(customDate!, selected),
              onTap: () => onSelect(customDate!),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${customDate!.day}',
                    style: kTextSemiBold(
                      color: isSameDay(customDate!, selected) ? kPrimaryColor : kTextPrimaryColor,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    DateFormat('MMM yyyy').format(customDate!),
                    style: kTextNormal0(
                      color: isSameDay(customDate!, selected) ? kPrimaryColor : kTextSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // More chip
          _Chip(
            isSelected: false,
            isDashed: true,
            onTap: onPickMore,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_month_rounded, size: 18.sp, color: kTextSecondaryColor),
                SizedBox(height: 2.h),
                Text('More', style: kTextNormal0(color: kTextSecondaryColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hour chip row
// ─────────────────────────────────────────────────────────────────────────────
class _HourChipRow extends StatelessWidget {
  final List<int> hourOptions;
  final int selected;
  final double Function(int) priceFor;
  final ValueChanged<int> onSelect;
  final String? unitType;

  const _HourChipRow({
    required this.hourOptions,
    required this.selected,
    required this.priceFor,
    required this.onSelect,
    this.unitType,
  });

  String _label(int h) {
    if (unitType != null) return '$h $unitType';
    return h == 1 ? '60 min' : '$h hrs';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(left: 12.w, right: 32.w),
        children: hourOptions.map((h) {
          final sel = h == selected;
          final price = priceFor(h);
          return _Chip(
            isSelected: sel,
            onTap: () => onSelect(h),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_label(h), style: kTextBold(color: sel ? kPrimaryColor : kTextPrimaryColor)),
                if (price > 0) ...[
                  SizedBox(height: 3.h),
                  Text(
                    NumberUtils.formatCurrency(price),
                    style: kTextSemiBold0(color: sel ? kPrimaryColor : kTextSecondaryColor),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tooltip up-arrow painter — triangle pointing upward with border + fill
// ─────────────────────────────────────────────────────────────────────────────
class _UpArrowPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;

  const _UpArrowPainter({required this.fillColor, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Attention pulse wrapper — pulses until user taps
// ─────────────────────────────────────────────────────────────────────────────
class _AttentionPulse extends StatefulWidget {
  final Widget child;

  const _AttentionPulse({required this.child});

  @override
  State<_AttentionPulse> createState() => _AttentionPulseState();
}

class _AttentionPulseState extends State<_AttentionPulse> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.015,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _glow = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.scale(
        scale: _scale.value,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            boxShadow: [
              BoxShadow(
                color: kPrimaryColor.withValues(alpha: 0.18 * _glow.value),
                blurRadius: 14 * _glow.value,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shift type selector for Long Duration (Day / Night / 24 Hours)
// ─────────────────────────────────────────────────────────────────────────────
class _ShiftTypeRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final String dayTime;
  final String nightTime;
  final bool isDayDisabled;
  final bool isNightDisabled;
  final bool isFullDayDisabled;

  const _ShiftTypeRow({
    required this.selected,
    required this.onChanged,
    required this.dayTime,
    required this.nightTime,
    this.isDayDisabled = false,
    this.isNightDisabled = false,
    this.isFullDayDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      ('day', Icons.wb_sunny_rounded, 'Day Shift', dayTime, isDayDisabled, kAccentColor),
      ('night', Icons.nightlight_round, 'Night Shift', nightTime, isNightDisabled, kPrimaryColor),
      ('24_hours', Icons.access_time_filled_rounded, 'Full Day', '24 Hours', isFullDayDisabled, kSecondaryColor),
    ];

    return Padding(
      padding: AppPadding.symmetric(h: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: options.asMap().entries.map((e) {
            final i = e.key;
            final key = e.value.$1;
            final icon = e.value.$2;
            final label = e.value.$3;
            final time = e.value.$4;
            final disabled = e.value.$5;
            final accent = e.value.$6;
            final sel = selected == key;
            final isLast = i == options.length - 1;

            return Expanded(
              child: GestureDetector(
                onTap: disabled ? null : () => onChanged(key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: EdgeInsets.only(right: isLast ? 0 : 8.w),
                  padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
                  decoration: BoxDecoration(
                    color: disabled
                        ? const Color(0xFFF5F5F5)
                        : sel
                        ? accent.withValues(alpha: 0.10)
                        : accent.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: disabled
                          ? kDividerColor
                          : sel
                          ? accent
                          : accent.withValues(alpha: 0.30),
                      width: sel ? 1.8 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(6.w),
                        decoration: BoxDecoration(
                          color: disabled ? Colors.transparent : accent.withValues(alpha: sel ? 0.15 : 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 16.sp, color: disabled ? kTextHintColor : accent),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: kTextSemiBold0(
                          color: disabled
                              ? kTextHintColor
                              : sel
                              ? accent
                              : kTextPrimaryColor,
                        ).copyWith(fontSize: 11.sp),
                      ),
                      if (time.isNotEmpty) ...[
                        SizedBox(height: 1.h),
                        FittedBox(
                          child: Text(
                            time,
                            style: kTextNormal0(
                              color: disabled
                                  ? kTextHintColor.withValues(alpha: 0.6)
                                  : sel
                                  ? accent.withValues(alpha: 0.8)
                                  : kTextSecondaryColor.withValues(alpha: 0.75),
                            ).copyWith(fontSize: 9.5.sp),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic chip
// ─────────────────────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final bool isSelected;
  final bool isDashed;
  final VoidCallback onTap;
  final Widget child;

  const _Chip({required this.isSelected, required this.onTap, required this.child, this.isDashed = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: EdgeInsets.only(right: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor.withValues(alpha: 0.08) : kWhiteColor,
          borderRadius: BorderRadius.circular(12.r),
          border: isDashed
              ? Border.all(color: kBorderColor, style: BorderStyle.solid)
              : Border.all(color: isSelected ? kPrimaryColor : kBorderColor, width: isSelected ? 1.8 : 1),
        ),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky price bar
// ─────────────────────────────────────────────────────────────────────────────
class _StickyPriceBar extends StatelessWidget {
  final String estimatedTotal;
  final String? actualTotal;
  final bool hasRateCard;
  final int? dayCount;
  final double gstPercentage;
  final bool isPackageSelected;
  final String? packageLabel;
  final double packageSavingsPercent;
  final double packageSavingsAmount;
  final double proceduralDiscountPercent;
  final VoidCallback onContinue;
  final double? basePrice;
  final double? pricePerHour;
  final int? durationHours;
  final int? scheduledDays;
  final bool isMultiDayProcedural;
  final bool isLongDuration;
  final String? unitType;

  const _StickyPriceBar({
    required this.estimatedTotal,
    this.actualTotal,
    required this.hasRateCard,
    required this.onContinue,
    this.dayCount,
    this.gstPercentage = 0,
    this.isPackageSelected = false,
    this.packageLabel,
    this.packageSavingsPercent = 0,
    this.packageSavingsAmount = 0,
    this.proceduralDiscountPercent = 0,
    this.basePrice,
    this.pricePerHour,
    this.durationHours,
    this.scheduledDays,
    this.isMultiDayProcedural = false,
    this.isLongDuration = false,
    this.unitType,
  });

  @override
  Widget build(BuildContext context) {
    final showPrice = hasRateCard && (dayCount == null || dayCount! > 0);
    final gstLabel = gstPercentage > 0
        ? '+ ${gstPercentage.toStringAsFixed(gstPercentage.truncateToDouble() == gstPercentage ? 0 : 1)}% GST'
        : '';

    // Compute duration line for hourly bookings
    String? durationLine;

    final bp = basePrice ?? 0.0;
    final hrs = durationHours ?? 0;

    if (!isLongDuration && bp > 0) {
      if (isMultiDayProcedural && scheduledDays != null && scheduledDays! > 0 && hrs > 0) {
        final days = scheduledDays!;
        durationLine = unitType != null
            ? '$days ${days == 1 ? 'day' : 'days'} · $hrs $unitType/day'
            : '$days ${days == 1 ? 'day' : 'days'} · ${hrs}h/day';
      } else if (!isMultiDayProcedural && hrs > 0) {
        durationLine = unitType != null ? '$hrs $unitType' : '${hrs == 1 ? '60 min' : '${hrs}h'} session';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      padding: AppPadding.only(left: 20, right: 20, top: 10, bottom: 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Label / duration line
                  if (isPackageSelected && packageLabel != null)
                    Text(packageLabel!, style: kTextSemiBold())
                  else if (durationLine != null)
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 12.sp, color: kTextSecondaryColor),
                        SizedBox(width: 4.w),
                        Text(
                          durationLine,
                          style: kTextSemiBold(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                        ),
                      ],
                    )
                  else
                    Text(dayCount != null ? 'Duration' : 'Estimated Price', style: kTextSemiBold()),

                  // Breakdown or fallback sub-label
                  // if (breakdownLine != null) ...[
                  //   SizedBox(height: 1.h),
                  //   Row(
                  //     children: [
                  //       Text(
                  //         breakdownLine,
                  //         style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
                  //         maxLines: 1,
                  //         overflow: TextOverflow.ellipsis,
                  //       ),
                  //       SizedBox(width: 4.w),
                  //       Text(
                  //         '=',
                  //         style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
                  //       ),
                  //     ],
                  //   ),
                  // ] else 
                  if (!isPackageSelected && dayCount != null && dayCount! > 0)
                    Text(
                      'Price for $dayCount ${dayCount == 1 ? 'day' : 'days'}.',
                      style: kTextNormal0(color: kTextSecondaryColor),
                    ),

                  SizedBox(height: 2.h),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    runSpacing: 2.h,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                        child: Text(
                          showPrice ? estimatedTotal : '–',
                          key: ValueKey(estimatedTotal),
                          style: kTextBold1(color: kPrimaryColor),
                        ),
                      ),
                      if (showPrice && actualTotal != null) ...[
                        SizedBox(width: 6.w),
                        Padding(
                          padding: EdgeInsets.only(bottom: 2.h),
                          child: Text(
                            actualTotal!,
                            style: kTextNormal0(color: kTextHintColor).copyWith(
                              fontSize: 12.sp,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: kTextHintColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (showPrice)
                    Text(
                      gstLabel,
                      style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 10.sp, height: 1.1),
                    ),
                  if (isPackageSelected && packageSavingsPercent > 0) ...[
                    SizedBox(height: 3.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: kSuccessColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        '${cleanDecimal(packageSavingsPercent)}% off · save ${NumberUtils.formatCurrency(packageSavingsAmount, decimalDigits: 0)}',
                        style: kTextSemiBold0(color: kSuccessColor).copyWith(fontSize: 10.sp),
                      ),
                    ),
                  ] else if (!isLongDuration && proceduralDiscountPercent > 0) ...[
                    SizedBox(height: 3.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: kSuccessColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        '${cleanDecimal(proceduralDiscountPercent)}% off',
                        style: kTextSemiBold0(color: kSuccessColor).copyWith(fontSize: 10.sp),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 16.w),
            SizedBox(
              height: AppButtonHeight.l,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: kWhiteColor,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.l),
                  padding: AppPadding.lHorizontal,
                  elevation: 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Continue', style: kTextBold(color: kWhiteColor)),
                    SizedBox(width: 8.w),
                    Icon(Icons.arrow_forward_rounded, size: 18.sp),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toggle pill for Single Day / Multiple Days
// ─────────────────────────────────────────────────────────────────────────────
class _TogglePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _TogglePill({required this.label, required this.icon, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: isActive ? kWhiteColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10.r),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16.sp, color: isActive ? kPrimaryColor : kTextSecondaryColor),
              SizedBox(width: 6.w),
              Text(
                label,
                style: kTextSemiBold(
                  color: isActive ? kPrimaryColor : kTextSecondaryColor,
                ).copyWith(fontSize: 13.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date card for multi-day picker (start/end)
// ─────────────────────────────────────────────────────────────────────────────
class _DateCard extends StatelessWidget {
  final String label;
  final DateTime? date;
  final IconData icon;
  final Color color;

  const _DateCard({required this.label, required this.date, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final hasDate = date != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: hasDate ? color.withValues(alpha: 0.06) : kWhiteColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: hasDate ? color.withValues(alpha: 0.3) : kBorderColor, width: hasDate ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14.sp, color: hasDate ? color : kTextHintColor),
              SizedBox(width: 4.w),
              Expanded(
                child: Text(
                  label,
                  style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            hasDate ? DateFormat('dd MMM, yyyy').format(date!) : 'Select',
            style: kTextBold(color: hasDate ? kTextPrimaryColor : kTextHintColor).copyWith(fontSize: 14.sp),
          ),
          if (hasDate) ...[
            SizedBox(height: 2.h),
            Text(
              DateFormat('EEEE').format(date!),
              style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 10.sp),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Period tab with icon (Morning/Afternoon/Evening)
// ─────────────────────────────────────────────────────────────────────────────
class _PeriodTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final String subtitle;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;

  const _PeriodTab({
    required this.label,
    required this.icon,
    required this.subtitle,
    required this.isSelected,
    this.isDisabled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(vertical: 7.h, horizontal: 4.w),
          decoration: BoxDecoration(
            color: isDisabled
                ? const Color(0xFFF3F4F6).withValues(alpha: 0.5)
                : (isSelected ? kPrimaryColor.withValues(alpha: 0.08) : const Color(0xFFF9FAFB)),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: isDisabled
                  ? kBorderColor.withValues(alpha: 0.5)
                  : (isSelected ? kPrimaryColor : kBorderColor),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 15.sp,
                color: isDisabled
                    ? kTextHintColor.withValues(alpha: 0.5)
                    : (isSelected ? kPrimaryColor : kTextSecondaryColor),
              ),
              SizedBox(height: 2.h),
              Text(
                label,
                style: kTextSemiBold0(
                  color: isDisabled
                      ? kTextHintColor.withValues(alpha: 0.5)
                      : (isSelected ? kPrimaryColor : kTextPrimaryColor),
                ).copyWith(fontSize: 11.sp),
              ),
              Text(
                subtitle,
                style: kTextNormal0(
                  color: isDisabled
                      ? kTextHintColor.withValues(alpha: 0.3)
                      : (isSelected ? kPrimaryColor.withValues(alpha: 0.7) : kTextHintColor),
                ).copyWith(fontSize: 8.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary row for booking summary card
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _SummaryRow({required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
        ),
        Text(
          value,
          style: isBold
              ? kTextBold(color: kPrimaryColor)
              : kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 12.sp),
        ),
      ],
    );
  }
}

class _PlanPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool disabled;
  final String? disabledMessage;
  final VoidCallback onTap;

  const _PlanPill({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.disabled = false,
    this.disabledMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: disabled
            ? (disabledMessage != null ? () => MessageService.showWarning(disabledMessage!) : null)
            : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(vertical: 10.h),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: disabled ? const Color(0xFFF3F4F6) : (isActive ? kPrimaryColor : kWhiteColor),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: disabled ? kBorderColor : (isActive ? kPrimaryColor : kBorderColor)),
          ),
          child: Text(
            label,
            style: kTextSemiBold(
              color: disabled ? kTextHintColor : (isActive ? kWhiteColor : kTextPrimaryColor),
            ).copyWith(fontSize: 13.sp),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
