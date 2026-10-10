import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/repositories/provider_repository.dart';
import '../data/model/feedback_model.dart';

part 'feedback_event.dart';
part 'feedback_state.dart';

class FeedbackBloc extends Bloc<FeedbackEvent, FeedbackState> {
  final ProviderRepository repository;

  FeedbackBloc({required this.repository}) : super(FeedbackInitial()) {
    on<FetchFeedback>(_onFetchFeedback);
    on<SubmitFeedback>(_onSubmitFeedback);
  }

  Future<void> _onFetchFeedback(FetchFeedback event, Emitter<FeedbackState> emit) async {
    emit(FeedbackLoading());
    try {
      final response = await repository.getAppFeedback();
      if (response.status) {
        emit(FeedbackLoaded(response.data.isNotEmpty ? response.data.first : null));
      } else {
        emit(FeedbackError(response.message));
      }
    } catch (e) {
      emit(FeedbackError(e.toString()));
    }
  }

  Future<void> _onSubmitFeedback(SubmitFeedback event, Emitter<FeedbackState> emit) async {
    emit(FeedbackSubmitLoading());
    try {
      final success = await repository.saveAppFeedback(
        rating: event.rating,
        feedbackType: event.feedbackType,
        feedbackText: event.feedbackText,
      );
      if (success) {
        emit(FeedbackSubmitSuccess());
        add(FetchFeedback());
      } else {
        emit(FeedbackSubmitError('Failed to submit feedback'));
      }
    } catch (e) {
      emit(FeedbackSubmitError(e.toString()));
    }
  }
}
