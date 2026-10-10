part of 'feedback_bloc.dart';

abstract class FeedbackEvent {}

class FetchFeedback extends FeedbackEvent {}

class SubmitFeedback extends FeedbackEvent {
  final int rating;
  final String feedbackType;
  final String feedbackText;

  SubmitFeedback({
    required this.rating,
    required this.feedbackType,
    required this.feedbackText,
  });
}
