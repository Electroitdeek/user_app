import 'sub_block_model.dart';

class BookingModel {
  final int id;
  final String bookingNumber;
  final String bookingStatus;
  final List<SubBlock> subBlocks;
  final String? providerName;

  const BookingModel({
    required this.id,
    required this.bookingNumber,
    required this.bookingStatus,
    required this.subBlocks,
    this.providerName,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final providerData = json['service_provider'] as Map<String, dynamic>?;
    return BookingModel(
      id: json['id'] as int? ?? 0,
      bookingNumber: json['booking_number'] as String? ?? '',
      bookingStatus: json['booking_status'] as String? ?? '',
      subBlocks: SubBlock.listFromJson(json['sub_blocks'] as List<dynamic>? ?? []),
      providerName: providerData?['full_name'] as String? ??
          json['provider_name'] as String?,
    );
  }
}
