part of 'registration_fee_payment_bloc.dart';

abstract class RegistrationFeePaymentEvent extends Equatable {
  const RegistrationFeePaymentEvent();

  @override
  List<Object?> get props => [];
}

class InitiateRegistrationFeePaymentEvent extends RegistrationFeePaymentEvent {
  final double amount;
  const InitiateRegistrationFeePaymentEvent(this.amount);

  @override
  List<Object?> get props => [amount];
}

class RazorpayRegistrationSuccessEvent extends RegistrationFeePaymentEvent {
  final String paymentId;
  final String orderId;
  final String signature;

  const RazorpayRegistrationSuccessEvent({
    required this.paymentId,
    required this.orderId,
    required this.signature,
  });

  @override
  List<Object?> get props => [paymentId, orderId, signature];
}

class RazorpayRegistrationFailureEvent extends RegistrationFeePaymentEvent {
  final String? message;
  const RazorpayRegistrationFailureEvent(this.message);

  @override
  List<Object?> get props => [message];
}
