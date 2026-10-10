part of 'booking_detail_bloc.dart';

abstract class BookingDetailState {}

class BookingDetailInitial extends BookingDetailState {}

class BookingDetailLoading extends BookingDetailState {}

class BookingDetailRefreshing extends BookingDetailState {
  final BookingDetailModel model;
  BookingDetailRefreshing({required this.model});
}

class BookingDetailLoaded extends BookingDetailState {
  final BookingDetailModel model;
  BookingDetailLoaded({required this.model});
}

class BookingDetailError extends BookingDetailState {
  final String message;
  BookingDetailError(this.message);
}

class BookingDetailCancelling extends BookingDetailState {
  final BookingDetailModel model;
  BookingDetailCancelling({required this.model});
}

class BookingDetailCancelled extends BookingDetailState {}

class BookingDetailSubBlocksCancelled extends BookingDetailState {
  final BookingDetailModel model;
  BookingDetailSubBlocksCancelled({required this.model});
}
