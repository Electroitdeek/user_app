part of 'booking_detail_bloc.dart';

abstract class BookingDetailEvent {}

class LoadBookingDetail extends BookingDetailEvent {
  final int requestId;
  LoadBookingDetail(this.requestId);
}

class RefreshBookingDetail extends BookingDetailEvent {}

class CancelBookingDetail extends BookingDetailEvent {
  final String? reason;
  CancelBookingDetail({this.reason});
}

class CancelUnpaidBookingDetail extends BookingDetailEvent {}

class CancelWithSubBlocks extends BookingDetailEvent {
  final List<int> subBlockIds;
  final String? reason;
  CancelWithSubBlocks({required this.subBlockIds, this.reason});
}
