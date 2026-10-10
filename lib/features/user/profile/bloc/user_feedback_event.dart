part of 'user_feedback_bloc.dart';

abstract class UserFeedbackEvent {}

class FetchUserFeedback extends UserFeedbackEvent {}

class SubmitUserFeedback extends UserFeedbackEvent {
  final int rating;
  final String feedbackType;
  final String feedbackText;

  SubmitUserFeedback({
    required this.rating,
    required this.feedbackType,
    required this.feedbackText,
  });
}
