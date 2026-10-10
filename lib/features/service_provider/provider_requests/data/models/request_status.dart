import 'package:flutter/material.dart';

enum RequestStatus {
  searching,
  pending,
  upcoming,
  accepted,
  partiallyAccepted,
  inProgress,
  completed,
  cancelled,
  expired,
  standby,
  unknown;

  static RequestStatus fromString(String? value) => switch (value?.toLowerCase()) {
    'searching' => searching,
    'pending' => pending,
    'upcoming' => upcoming,
    'accepted' => accepted,
    'partially_accepted' => partiallyAccepted,
    'in_progress' || 'confirmed' => inProgress,
    'completed' => completed,
    'cancelled' => cancelled,
    'expired' => expired,
    'standby' => standby,
    _ => unknown,
  };

  String get label => switch (this) {
    searching => 'Searching',
    pending => 'Pending',
    upcoming => 'Upcoming',
    accepted => 'Accepted',
    partiallyAccepted => 'Partial',
    inProgress => 'In Progress',
    completed => 'Completed',
    cancelled => 'Cancelled',
    expired => 'Expired',
    standby => 'Standby',
    unknown => 'Unknown',
  };

  String get shortLabel => switch (this) {
    completed => 'Done',
    inProgress => 'Active',
    cancelled => 'Cancelled',
    standby => 'Standby',
    _ => 'Pending',
  };

  Color get color => switch (this) {
    searching || pending => const Color(0xFF2563EB),
    upcoming || accepted => const Color(0xFF0891B2),
    partiallyAccepted => const Color(0xFFD97706),
    inProgress => const Color(0xFF0891B2),
    completed => const Color(0xFF16A34A),
    cancelled => const Color(0xFFDC2626),
    expired => const Color(0xFFDC2626),
    standby => const Color(0xFFD97706),
    unknown => const Color(0xFF6B7280),
  };

  Color get bgColor => switch (this) {
    searching || pending => const Color(0xFFEFF6FF),
    upcoming || accepted => const Color(0xFFECFEFF),
    partiallyAccepted => const Color(0xFFFFFBEB),
    inProgress => const Color(0xFFE0F2FE),
    completed => const Color(0xFFF0FDF4),
    cancelled => const Color(0xFFFEF2F2),
    expired => const Color(0xFFFEF2F2),
    standby => const Color(0xFFFFFBEB),
    unknown => const Color(0xFFF9FAFB),
  };

  bool get isNew => this == searching || this == pending || this == standby;
  bool get isActive => this == inProgress;
  bool get isPartiallyAccepted => this == partiallyAccepted;
}
