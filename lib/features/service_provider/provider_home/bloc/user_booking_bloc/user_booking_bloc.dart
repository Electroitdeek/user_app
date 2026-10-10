import 'package:adhisaat_health_care/features/service_provider/provider_home/bloc/user_booking_bloc/user_booking_event.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_home/bloc/user_booking_bloc/user_booking_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/booking.dart';
import '../../data/models/provider.dart';

class UserBookingBloc extends Bloc<UserBookingEvent, UserBookingState> {
  UserBookingBloc() : super(UserBookingInitial()) {
    on<BookingConfirmedEvent>(_onBookingConfirmed);
    on<ProviderAcceptedEvent>(_onProviderAccepted);
    on<ServiceCompletedEvent>(_onServiceCompleted);
  }

  Future<void> _onBookingConfirmed(BookingConfirmedEvent event, Emitter<UserBookingState> emit) async {
    final booking = Booking.fromJson(event.bookingData);
    emit(BookingConfirmed(booking: booking));
  }

  Future<void> _onProviderAccepted(ProviderAcceptedEvent event, Emitter<UserBookingState> emit) async {
    final provider = Provider.fromJson(event.providerData);
    emit(ProviderAssigned(provider: provider));
  }

  Future<void> _onServiceCompleted(ServiceCompletedEvent event, Emitter<UserBookingState> emit) async {
    emit(ServiceCompleted(bookingId: event.bookingId));
  }
}
