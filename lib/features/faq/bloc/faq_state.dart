import 'package:equatable/equatable.dart';
import '../../../data/models/faq_model.dart';

abstract class FaqState extends Equatable {
  const FaqState();

  @override
  List<Object?> get props => [];
}

class FaqInitial extends FaqState {}

class FaqLoading extends FaqState {}

class FaqLoaded extends FaqState {
  final List<FaqData> faqs;
  final Map<String, String> categories;

  const FaqLoaded({required this.faqs, required this.categories});

  @override
  List<Object?> get props => [faqs, categories];
}

class FaqError extends FaqState {
  final String message;

  const FaqError(this.message);

  @override
  List<Object?> get props => [message];
}
