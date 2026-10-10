import 'package:intl/intl.dart';

class AppDateFormatter {
  AppDateFormatter._(); // private constructor

  // ─── Core parser (handles all API formats) ────────────────────────────────

  /// Tries multiple formats:
  ///  1. ISO 8601 — "2026-03-15T18:07:28.000000Z" / "2026-03-15 23:36:57"
  ///  2. dd-MM-yyyy HH:mm:ss
  ///  3. dd-MM-yyyy HH:mm — "15-03-2026 18:06"
  ///  4. dd-MM-yyyy        — "15-03-2026"
  ///  5. dd/MM/yyyy        — "15/03/2026"
  static DateTime? _tryParseDate(String s) {
    if (s.isEmpty) return null;
    // 1. Standard ISO / space-separated ISO
    try { return DateTime.parse(s).toLocal(); } catch (_) {}
    // 2. dd-MM-yyyy HH:mm:ss
    try { return DateFormat('dd-MM-yyyy HH:mm:ss').parseLoose(s).toLocal(); } catch (_) {}
    // 3. dd-MM-yyyy HH:mm
    try { return DateFormat('dd-MM-yyyy HH:mm').parseLoose(s).toLocal(); } catch (_) {}
    // 4. dd-MM-yyyy HH:mm a
    try { return DateFormat('dd-MM-yyyy HH:mm a').parseLoose(s).toLocal(); } catch (_) {}
    // 5. dd-MM-yyyy
    try { return DateFormat('dd-MM-yyyy').parseLoose(s).toLocal(); } catch (_) {}
    // 6. dd/MM/yyyy
    try { return DateFormat('dd/MM/yyyy').parseLoose(s).toLocal(); } catch (_) {}
    return null;
  }

  // ─── Date Formatters ───────────────────────────────────────────────────────

  /// Output: "15 Jan 2026"
  static String dateOnly(DateTime date) => DateFormat('dd-MMM-yyyy').format(date);

  /// Output: "15 Jan 2026, 08:00 AM"
  static String dateWithTime(DateTime date) =>
      DateFormat('dd MMM yyyy, hh:mm a').format(date);

  /// Safe parser from any API date/datetime string → "15 Jan 2026"
  static String dateFromApi(String dateString) {
    final dt = _tryParseDate(dateString);
    return dt != null ? dateOnly(dt) : dateString;
  }

  /// "Thu, 22 May 2026"
  static String dateWithWeekday(String dateString) {
    final dt = _tryParseDate(dateString);
    return dt != null ? DateFormat('EEE, dd MMM yyyy').format(dt) : dateString;
  }

  /// Safe parser with time → "15 Jan 2026, 08:00 AM"
  static String fromApiDateTime(String dateString) {
    final dt = _tryParseDate(dateString);
    return dt != null ? dateWithTime(dt) : dateString;
  }

  /// Formats start date and time for ongoing/completed sessions.
  /// Output example: "27 Aug 2026, 10:55 PM"
  static String formatSessionDateTime({
    String? actualDateTime,
    String? actualDate,
    String? scheduledDate,
    String? scheduledTime,
  }) {
    // 1. Try parsing full actual datetime if provided
    if (actualDateTime != null &&
        actualDateTime.trim().isNotEmpty &&
        actualDateTime != '-' &&
        actualDateTime != '—') {
      final trimmed = actualDateTime.trim();
      final dt = _tryParseDate(trimmed);
      if (dt != null && dt.year > 2000) {
        return dateWithTime(dt);
      }
      final timeStr = formatTimeString(trimmed);
      final dateStr = (actualDate != null &&
              actualDate.isNotEmpty &&
              actualDate != '-' &&
              actualDate != '—')
          ? dateShort(actualDate)
          : (scheduledDate != null && scheduledDate.isNotEmpty)
              ? dateShort(scheduledDate)
              : '';
      if (dateStr.isNotEmpty && timeStr.isNotEmpty) {
        return '$dateStr, $timeStr';
      }
      if (timeStr.isNotEmpty) return timeStr;
    }

    // 2. Fall back to scheduled date + scheduled time
    final sDate = (scheduledDate != null && scheduledDate.isNotEmpty)
        ? dateShort(scheduledDate)
        : '';
    final sTime = (scheduledTime != null && scheduledTime.isNotEmpty)
        ? formatTimeString(scheduledTime)
        : '';

    if (sDate.isNotEmpty && sTime.isNotEmpty) {
      return '$sDate, $sTime';
    }
    if (sTime.isNotEmpty) return sTime;
    if (sDate.isNotEmpty) return sDate;
    return '—';
  }

  /// Output: "2000-01-01" (API format)
  static String dateForApi(String dateString) {
    final dt = _tryParseDate(dateString);
    if (dt == null) return dateString;
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  static DateTime dateFromString(String dateString) =>
      _tryParseDate(dateString) ?? DateTime.now();

  // ─── Time Formatters ───────────────────────────────────────────────────────

  /// Output: "8:30 AM"
  static String timeOnly(DateTime date) =>
      DateFormat('h:mm a').format(date);

  /// Parses a full ISO datetime string → "8:30 AM"
  static String timeFromApi(String dateString) {
    final dt = _tryParseDate(dateString);
    if (dt != null) return timeOnly(dt);
    return _parseTimeString(dateString);
  }

  /// Parses a time-only string like "08:30:00" or "08:30" → "8:30 AM"
  static String formatTimeString(String timeStr) {
    if (timeStr.isEmpty || timeStr == '—') return timeStr;
    final dt = _tryParseDate(timeStr);
    if (dt != null) return timeOnly(dt);
    return _parseTimeString(timeStr);
  }

  /// Internal: parse "HH:mm:ss" or "HH:mm" → "8:30 AM"
  static String _parseTimeString(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final dt = DateTime(2000, 1, 1, hour, minute);
        return DateFormat('h:mm a').format(dt);
      }
    } catch (_) {}
    return timeStr;
  }

  // ─── Smart / Relative Formatters ──────────────────────────────────────────

  /// "Today", "Yesterday", "Tomorrow", or "15 Jan 2026"
  static String smartDate(String dateString) {
    final date = _tryParseDate(dateString);
    if (date == null) return dateString;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (d == today.add(const Duration(days: 1))) return 'Tomorrow';
    return dateOnly(date);
  }

  /// "Today at 8:30 AM", "Yesterday at 6:00 PM", "15 Jan 2026 at 8:30 AM"
  static String smartDateTime(String dateString) {
    final date = _tryParseDate(dateString);
    if (date == null) return dateString;
    return '${smartDate(dateString)} at ${timeOnly(date)}';
  }

  /// Timeline display: "15 Mar 2026 · 08:30 AM"
  static String timelineDateTime(String dateString) {
    final date = _tryParseDate(dateString);
    if (date == null) return dateString;
    return '${DateFormat('dd MMM yyyy').format(date)} · ${DateFormat('hh:mm a').format(date)}';
  }

  /// Relative time: "Just now", "5 min ago", "2 hrs ago", "3 days ago"
  static String relativeTime(String dateString) {
    final date = _tryParseDate(dateString);
    if (date == null) return dateString;
    final diff = DateTime.now().difference(date);
    if (diff.isNegative) return timelineDateTime(dateString);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr${diff.inHours > 1 ? 's' : ''} ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    return timelineDateTime(dateString);
  }

  // ─── Additional display formatters ────────────────────────────────────────

  /// "15 Jan 2026"
  static String dateShort(String dateString) {
    final dt = _tryParseDate(dateString);
    return dt != null ? DateFormat('dd MMM yyyy').format(dt) : dateString;
  }

  /// "15 Jan 2026, 8:00 AM" (no leading zeros)
  static String dateTimeShort(String dateString) {
    final dt = _tryParseDate(dateString);
    return dt != null ? DateFormat('d MMM yyyy, h:mm a').format(dt) : dateString;
  }

  /// "Mon" — short weekday from date string
  static String weekdayShort(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    final dt = _tryParseDate(dateString);
    return dt != null ? DateFormat('EEE').format(dt) : '';
  }

  /// "Monday" — full weekday from date string
  static String weekdayFull(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '—';
    final dt = _tryParseDate(dateString);
    return dt != null ? DateFormat('EEEE').format(dt) : '—';
  }

  /// "15" — day number only
  static String dayNum(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '—';
    final dt = _tryParseDate(dateString);
    return dt != null ? DateFormat('d').format(dt) : '—';
  }

  /// "15\nJan" — day and short month on two lines
  static String dayMonthNewline(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '—';
    final dt = _tryParseDate(dateString);
    return dt != null ? DateFormat('d\nMMM').format(dt) : '—';
  }

  /// "15 Jan 2026" — short day and month with year
  static String dayMonthShort(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '—';
    final dt = _tryParseDate(dateString);
    return dt != null ? DateFormat('dd MMM yyyy').format(dt) : '—';
  }

  /// "15 Jan" — short day and month, no year
  static String dayMonthOnly(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '—';
    final dt = _tryParseDate(dateString);
    return dt != null ? DateFormat('dd MMM').format(dt) : '—';
  }

  /// "15 Jan 2026 -- 20 Jan 2026" — short date range with year
  static String dateRangeShort(String? start, String? end) {
    if (start == null || start.isEmpty) return '—';
    if (end == null || end.isEmpty || start == end) return dayMonthShort(start);
    return '${dayMonthShort(start)} - ${dayMonthShort(end)}';
  }

  /// "Jan 2026" — short month and year
  static String monthYearShort(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '—';
    final dt = _tryParseDate(dateString);
    return dt != null ? DateFormat('MMM yyyy').format(dt) : '—';
  }

  /// "January 2026" — full month and year
  static String monthYearFull(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '—';
    final dt = _tryParseDate(dateString);
    return dt != null ? DateFormat('MMMM yyyy').format(dt) : '—';
  }

  /// Formats a shift time range.
  /// Shows "Next Day" when: [isFullDay] is true, start==end, or end time hour < start time hour (crosses midnight).
  /// [compact] uses shorter "+1" suffix instead of "Next Day" prefix — fits in tight layouts.
  static String shiftTimeRange(String? startTime, String? endTime, {bool isFullDay = false, bool compact = false}) {
    final start = formatTimeString(startTime ?? '');
    final end = formatTimeString(endTime ?? '');
    if (start.isEmpty && end.isEmpty) return '—';
    final sameTime = startTime != null && startTime == endTime && startTime.isNotEmpty;
    final crossesMidnight = () {
      if (startTime == null || endTime == null) return false;
      final sh = int.tryParse(startTime.split(':').first) ?? 0;
      final eh = int.tryParse(endTime.split(':').first) ?? 0;
      return sh > eh;
    }();
    final nextDay = isFullDay || sameTime || crossesMidnight;
    if (!nextDay) return '$start – $end';
    return compact ? '$start – $end (+1)' : '$start → Next Day $end';
  }

  /// "25 yrs" — age from date-of-birth string
  static String ageYears(String? dob) {
    if (dob == null || dob.isEmpty) return '—';
    final d = _tryParseDate(dob);
    if (d == null) return '—';
    final now = DateTime.now();
    int age = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
    return '$age yrs';
  }
}
