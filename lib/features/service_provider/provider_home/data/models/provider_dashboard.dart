import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/data/models/dropdown_response_model.dart';
import 'package:adhisaat_health_care/data/models/provider_models/bank_detail_model.dart';

class ProviderDashboard {
  final int documents;
  final int categories;
  final BookingStats booking;
  final DashboardEarnings earnings;
  final List<DynamicDocumentType> documentsNotUploaded;
  final BankDetail? bankDetail;

  ProviderDashboard({
    required this.documents,
    required this.categories,
    required this.booking,
    required this.earnings,
    required this.documentsNotUploaded,
    this.bankDetail,
  });

  factory ProviderDashboard.fromJson(Map<String, dynamic> json) {
    return ProviderDashboard(
      documents: NumberUtils.toInt(json['documents']),
      categories: NumberUtils.toInt(json['categories']),
      booking: BookingStats.fromJson(json['booking'] ?? {}),
      earnings: DashboardEarnings.fromJson(json['earnings'] ?? {}),
      documentsNotUploaded: (json['documents_not_uploaded'] as List?)
              ?.map((e) => DynamicDocumentType.fromJson(e))
              .toList() ??
          [],
      bankDetail: json['bank_detail'] != null && json['bank_detail'] is Map
          ? BankDetail.fromJson(json['bank_detail'])
          : null,
    );
  }
}

class BookingStats {
  final int total;
  final int accepted;
  final int inProgress;
  final int upcoming;
  final int completed;
  final int cancelled;

  BookingStats({
    required this.total,
    required this.accepted,
    required this.inProgress,
    required this.upcoming,
    required this.completed,
    required this.cancelled,
  });

  factory BookingStats.fromJson(Map<String, dynamic> json) {
    return BookingStats(
      total: NumberUtils.toInt(json['total']),
      accepted: NumberUtils.toInt(json['accepted']),
      inProgress: NumberUtils.toInt(json['in_progress']),
      upcoming: NumberUtils.toInt(json['upcoming']),
      completed: NumberUtils.toInt(json['completed']),
      cancelled: NumberUtils.toInt(json['cancelled']),
    );
  }
}

class DashboardEarnings {
  final double today;
  final double weekly;
  final double monthly;
  final double total;

  DashboardEarnings({
    required this.today,
    required this.weekly,
    required this.monthly,
    required this.total,
  });

  factory DashboardEarnings.fromJson(Map<String, dynamic> json) {
    return DashboardEarnings(
      today: NumberUtils.toDouble(json['today']),
      weekly: NumberUtils.toDouble(json['weekly']),
      monthly: NumberUtils.toDouble(json['monthly']),
      total: NumberUtils.toDouble(json['total']),
    );
  }
}
