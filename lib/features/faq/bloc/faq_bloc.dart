import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/faq_repository.dart';
import 'faq_event.dart';
import 'faq_state.dart';

class FaqBloc extends Bloc<FaqEvent, FaqState> {
  final FaqRepository _repository;

  FaqBloc(this._repository) : super(FaqInitial()) {
    on<FetchFaqsEvent>(_onFetchFaqs);
  }

  Future<void> _onFetchFaqs(FetchFaqsEvent event, Emitter<FaqState> emit) async {
    emit(FaqLoading());
    try {
      final response = await _repository.getFaqs();
      if (response.success) {
        emit(FaqLoaded(
          faqs: response.data,
          categories: response.faqCategories,
        ));
      } else {
        emit(FaqError(response.message));
      }
    } catch (e) {
      emit(FaqError(e.toString()));
    }
  }
}
