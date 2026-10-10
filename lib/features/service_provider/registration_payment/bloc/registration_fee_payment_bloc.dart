import 'dart:async';

import 'package:adhisaat_health_care/core/storage/local_storage_service.dart';
import 'package:adhisaat_health_care/data/repositories/provider_repository.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'registration_fee_payment_event.dart';
part 'registration_fee_payment_state.dart';

class RegistrationFeePaymentBloc extends Bloc<RegistrationFeePaymentEvent, RegistrationFeePaymentState> {
  final ProviderRepository _repository;

  double _amount = 0.0;
  String _orderId = '';

  RegistrationFeePaymentBloc(this._repository) : super(RegistrationFeePaymentInitial()) {
    on<InitiateRegistrationFeePaymentEvent>(_onInitiate);
    on<RazorpayRegistrationSuccessEvent>(_onSuccess);
    on<RazorpayRegistrationFailureEvent>(_onFailure);
  }

  Future<void> _onInitiate(
    InitiateRegistrationFeePaymentEvent event,
    Emitter<RegistrationFeePaymentState> emit,
  ) async {
    emit(RegistrationFeePaymentLoading());
    try {
      _amount = event.amount;
      final order = await _repository.initiateRegistrationFeePayment(amount: event.amount);
      _orderId = order.razorpayOrderId;

      final storage = locator<LocalStorageService>();
      final userProfile = await storage.getUserProfile();

      final options = {
        'key': order.razorpayKey,
        'amount': order.amount,
        'currency': order.currency,
        'order_id': order.razorpayOrderId,
        'name': 'Adhisaat Health Care',
        'description': 'Registration Fee Payment',
        'prefill': {
          'contact': userProfile?['mobile_number'] ?? '',
          'email': (userProfile?['email'] != null && userProfile?['email'].toString().isNotEmpty == true)
              ? userProfile!['email'].toString()
              : '',
        },
        'theme': {'color': '#2D62ED'},
      };

      emit(RegistrationFeePaymentInitiated(options));
    } catch (e) {
      emit(RegistrationFeePaymentError(e.toString()));
    }
  }

  Future<void> _onSuccess(
    RazorpayRegistrationSuccessEvent event,
    Emitter<RegistrationFeePaymentState> emit,
  ) async {
    emit(RegistrationFeePaymentLoading());
    try {
      final success = await _repository.verifyRegistrationFeePayment(
        amount: _amount,
        razorpayPaymentId: event.paymentId,
        razorpayOrderId: event.orderId.isEmpty ? _orderId : event.orderId,
        razorpaySignature: event.signature,
      );

      if (success) {
        emit(RegistrationFeePaymentSuccess());
      } else {
        emit(const RegistrationFeePaymentError('Payment verification failed'));
      }
    } catch (e) {
      emit(RegistrationFeePaymentError(e.toString()));
    }
  }

  void _onFailure(RazorpayRegistrationFailureEvent event, Emitter<RegistrationFeePaymentState> emit) {
    emit(RegistrationFeePaymentError(event.message ?? 'Payment failed'));
  }
}
