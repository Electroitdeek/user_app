import 'package:adhisaat_health_care/data/repositories/dropdown_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dropdown_event.dart';
import 'dropdown_state.dart';

class DropdownBloc extends Bloc<DropdownEvent, DropdownState> {
  final DropdownRepository _repository;

  DropdownBloc(this._repository) : super(DropdownInitial()) {
    on<FetchDropdownData>((event, emit) async {
      emit(DropdownLoading());
      try {
        final data = await _repository.getDropdownData();
        emit(DropdownLoaded(data));
      } catch (e) {
        emit(DropdownError(e.toString()));
      }
    });
  }
}
