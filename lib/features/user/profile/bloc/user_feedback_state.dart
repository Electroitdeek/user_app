part of 'user_feedback_bloc.dart';

abstract class UserFeedbackState {}

class UserFeedbackInitial extends UserFeedbackState {}

class UserFeedbackLoading extends UserFeedbackState {}

class UserFeedbackLoaded extends UserFeedbackState {
  final FeedbackModel? feedback;
  UserFeedbackLoaded(this.feedback);
}

class UserFeedbackError extends UserFeedbackState {
  final String message;
  UserFeedbackError(this.message);
}

class UserFeedbackSubmitLoading extends UserFeedbackState {}

class UserFeedbackSubmitSuccess extends UserFeedbackState {}

class UserFeedbackSubmitError extends UserFeedbackState {
  final String message;
  UserFeedbackSubmitError(this.message);
}
