part of 'registration_fee_payment_bloc.dart';

abstract class RegistrationFeePaymentState extends Equatable {
  const RegistrationFeePaymentState();

  @override
  List<Object?> get props => [];
}

class RegistrationFeePaymentInitial extends RegistrationFeePaymentState {}

class RegistrationFeePaymentLoading extends RegistrationFeePaymentState {}

class RegistrationFeePaymentInitiated extends RegistrationFeePaymentState {
  final Map<String, dynamic> razorpayOptions;
  const RegistrationFeePaymentInitiated(this.razorpayOptions);

  @override
  List<Object?> get props => [razorpayOptions];
}

class RegistrationFeePaymentSuccess extends RegistrationFeePaymentState {}

class RegistrationFeePaymentError extends RegistrationFeePaymentState {
  final String message;
  const RegistrationFeePaymentError(this.message);

  @override
  List<Object?> get props => [message];
}
