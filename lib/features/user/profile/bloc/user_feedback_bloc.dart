import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/user_profile_repository.dart';
import '../../../../features/service_provider/feedback/data/model/feedback_model.dart';

part 'user_feedback_event.dart';
part 'user_feedback_state.dart';

class UserFeedbackBloc extends Bloc<UserFeedbackEvent, UserFeedbackState> {
  final UserProfileRepository repository;

  UserFeedbackBloc({required this.repository}) : super(UserFeedbackInitial()) {
    on<FetchUserFeedback>(_onFetchFeedback);
    on<SubmitUserFeedback>(_onSubmitFeedback);
  }

  Future<void> _onFetchFeedback(FetchUserFeedback event, Emitter<UserFeedbackState> emit) async {
    emit(UserFeedbackLoading());
    try {
      final response = await repository.getAppFeedback();
      if (response.status) {
        emit(UserFeedbackLoaded(response.data.isNotEmpty ? response.data.first : null));
      } else {
        emit(UserFeedbackError(response.message));
      }
    } catch (e) {
      emit(UserFeedbackError(e.toString()));
    }
  }

  Future<void> _onSubmitFeedback(SubmitUserFeedback event, Emitter<UserFeedbackState> emit) async {
    emit(UserFeedbackSubmitLoading());
    try {
      final success = await repository.saveAppFeedback(
        rating: event.rating,
        feedbackType: event.feedbackType,
        feedbackText: event.feedbackText,
      );
      if (success) {
        emit(UserFeedbackSubmitSuccess());
        add(FetchUserFeedback());
      } else {
        emit(UserFeedbackSubmitError('Failed to submit feedback'));
      }
    } catch (e) {
      emit(UserFeedbackSubmitError(e.toString()));
    }
  }
}
