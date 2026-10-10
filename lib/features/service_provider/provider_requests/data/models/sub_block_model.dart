import 'package:adhisaat_health_care/core/utils/date_utils.dart';

enum SubBlockStatus {
  pending,
  assigned,
  inProgress,
  completed,
  cancelled;

  static SubBlockStatus fromString(String? value) => switch (value?.toLowerCase()) {
    'pending' => pending,
    'assigned' => assigned,
    'in_progress' => inProgress,
    'completed' => completed,
    'cancelled' => cancelled,
    _ => pending,
  };
}

class SubBlock {
  final int id;
  final int? bookingId;
  final int? serviceProviderId;
  final String scheduledDate;
  final String scheduledStartTime;
  final String scheduledEndTime;
  final double providerPayout;
  final double blockAmount;
  final String status;
  final int requestStage;
  final String paymentStatus;
  final String? cancelledBy;
  final String? cancelledAt;
  final String? shiftType;

  bool get isAssigned => serviceProviderId != null;
  bool get isPending => bookingId == null;

  bool get isDayShift {
    if (shiftType != null) return shiftType!.toLowerCase() == 'day';
    final h = int.tryParse(scheduledStartTime.split(':').first) ?? 0;
    return h >= 6 && h < 18;
  }

  bool get isNightShift => !isDayShift;

  const SubBlock({
    required this.id,
    this.bookingId,
    this.serviceProviderId,
    required this.scheduledDate,
    required this.scheduledStartTime,
    required this.scheduledEndTime,
    required this.providerPayout,
    required this.blockAmount,
    required this.status,
    required this.requestStage,
    this.paymentStatus = 'pending',
    this.cancelledBy,
    this.cancelledAt,
    this.shiftType,
  });

  factory SubBlock.fromJson(Map<String, dynamic> json) => SubBlock(
        id: (json['id'] as num?)?.toInt() ?? 0,
        bookingId: (json['booking_id'] as num?)?.toInt(),
        serviceProviderId: (json['service_provider_id'] as num?)?.toInt(),
        scheduledDate: json['scheduled_date'] as String? ?? '',
        scheduledStartTime: json['scheduled_start_time'] as String? ?? '',
        scheduledEndTime: json['scheduled_end_time'] as String? ?? '',
        providerPayout: double.tryParse(json['provider_payout']?.toString() ?? '0') ?? 0,
        blockAmount: double.tryParse(json['block_amount']?.toString() ?? '0') ?? 0,
        status: json['status'] as String? ?? 'pending',
        requestStage: (json['request_stage'] as num?)?.toInt() ?? 1,
        paymentStatus: json['payment_status'] as String? ?? 'pending',
        cancelledBy: json['cancelled_by'] as String?,
        cancelledAt: json['cancelled_at'] as String?,
        shiftType: json['shift_type'] as String?,
      );

  static List<SubBlock> listFromJson(List<dynamic> list) =>
      list.map((e) => SubBlock.fromJson(e as Map<String, dynamic>)).toList();

  DateTime? get parsedDate {
    try {
      return DateTime.parse(scheduledDate);
    } catch (_) {
      return null;
    }
  }

  bool get isFullDay =>
      scheduledStartTime.isNotEmpty &&
      scheduledStartTime == scheduledEndTime;

  SubBlockStatus get blockStatus => SubBlockStatus.fromString(status);

  DateTime? get scheduledStartDateTime {
    final date = parsedDate;
    if (date == null) return null;
    final parts = scheduledStartTime.split(':');
    if (parts.isEmpty) return null;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return DateTime(date.year, date.month, date.day, h, m);
  }

  bool isReadyToStart({int minutesBefore = 30}) {
    if (blockStatus != SubBlockStatus.assigned) return false;
    final startDt = scheduledStartDateTime;
    if (startDt == null) return false;
    return DateTime.now().isAfter(startDt.subtract(Duration(minutes: minutesBefore)));
  }

  String get dayAbbr => AppDateFormatter.weekdayShort(scheduledDate);
  String get dateLabel => AppDateFormatter.dayMonthShort(scheduledDate);
  String get monthLabel => AppDateFormatter.monthYearShort(scheduledDate);
  String get startLabel => AppDateFormatter.formatTimeString(scheduledStartTime);
  String get endLabel => AppDateFormatter.formatTimeString(scheduledEndTime);
  String get timeRange => AppDateFormatter.shiftTimeRange(
        scheduledStartTime, scheduledEndTime,
        isFullDay: isFullDay,
      );
}
