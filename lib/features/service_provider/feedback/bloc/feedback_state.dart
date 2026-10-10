part of 'feedback_bloc.dart';

abstract class FeedbackState {}

class FeedbackInitial extends FeedbackState {}

class FeedbackLoading extends FeedbackState {}

class FeedbackLoaded extends FeedbackState {
  final FeedbackModel? feedback;
  FeedbackLoaded(this.feedback);
}

class FeedbackError extends FeedbackState {
  final String message;
  FeedbackError(this.message);
}

class FeedbackSubmitLoading extends FeedbackState {}

class FeedbackSubmitSuccess extends FeedbackState {}

class FeedbackSubmitError extends FeedbackState {
  final String message;
  FeedbackSubmitError(this.message);
}
