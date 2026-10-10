import '../../data/models/booking.dart';
import '../../data/models/provider.dart';

abstract class UserBookingState {}

class UserBookingInitial extends UserBookingState {}

class BookingConfirmed extends UserBookingState {
  final Booking booking;

  BookingConfirmed({required this.booking});
}

class ProviderAssigned extends UserBookingState {
  final Provider provider;

  ProviderAssigned({required this.provider});
}

class ServiceCompleted extends UserBookingState {
  final String bookingId;

  ServiceCompleted({required this.bookingId});
}
