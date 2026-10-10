import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/service_category_repository.dart';
import '../model/service_category_model.dart';

abstract class SubCategoryEvent {}

class LoadSubCategories extends SubCategoryEvent {
  final int parentId;
  LoadSubCategories(this.parentId);
}

abstract class SubCategoryState {}

class SubCategoryInitial extends SubCategoryState {}

class SubCategoryLoading extends SubCategoryState {}

class SubCategoryLoaded extends SubCategoryState {
  final List<SubCategoryDataModel> items;
  SubCategoryLoaded(this.items);
}

class SubCategoryError extends SubCategoryState {
  final String message;
  SubCategoryError(this.message);
}

class SubCategoryBloc extends Bloc<SubCategoryEvent, SubCategoryState> {
  final ServiceCategoryRepository _repository;

  SubCategoryBloc(this._repository) : super(SubCategoryInitial()) {
    on<LoadSubCategories>(_onLoad);
  }

  Future<void> _onLoad(
    LoadSubCategories event,
    Emitter<SubCategoryState> emit,
  ) async {
    emit(SubCategoryLoading());
    try {
      final items = await _repository.getSubCategoriesV2(
        serviceCategoryId: event.parentId,
      );
      emit(SubCategoryLoaded(items));
    } catch (e) {
      emit(SubCategoryError(e.toString()));
    }
  }
}
