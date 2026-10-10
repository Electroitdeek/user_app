abstract class UserBookingEvent {}

class BookingConfirmedEvent extends UserBookingEvent {
  final Map<String, dynamic> bookingData;
  BookingConfirmedEvent({required this.bookingData});
}

class ProviderAcceptedEvent extends UserBookingEvent {
  final Map<String, dynamic> providerData;
  ProviderAcceptedEvent({required this.providerData});
}

class ServiceCompletedEvent extends UserBookingEvent {
  final String bookingId;
  ServiceCompletedEvent({required this.bookingId});
}