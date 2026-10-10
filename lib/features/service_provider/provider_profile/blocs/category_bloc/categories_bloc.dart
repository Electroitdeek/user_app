import 'package:adhisaat_health_care/data/repositories/provider_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../provider_home/data/models/service_provider_models.dart';

part 'categories_event.dart';
part 'categories_state.dart';

class CategoriesBloc extends Bloc<CategoriesEvent, CategoriesState> {
  final ProviderRepository repository;

  CategoriesBloc({required this.repository}) : super(CategoriesInitial()) {
    on<LoadCategories>(_onLoadCategories);
    // on<SaveCategories>(_onSaveCategories);
    // on<DeleteCategory>(_onDeleteCategory);
  }

  Future<void> _onLoadCategories(LoadCategories event, Emitter<CategoriesState> emit) async {
    emit(CategoriesLoading());
    try {
      final profile = await repository.getProfile();
      emit(CategoriesLoaded((profile.serviceProviderProfile?.services) ?? []));
    } catch (e) {
      emit(CategoriesError(e.toString()));
    }
  }

  // Future<void> _onSaveCategories(SaveCategories event, Emitter<CategoriesState> emit) async {
  //   final currentState = state;
  //   if (currentState is CategoriesLoaded) {
  //     emit(CategoriesSaving(currentState.categories));
  //   }
  //
  //   try {
  //     await repository.saveCategories(serviceProviderId: event.serviceProviderId, categoryIds: event.categoryIds);
  //
  //     final profile = await repository.getProfile();
  //     emit(CategoriesSaveSuccess(profile.services ?? []));
  //     emit(CategoriesLoaded(profile.services ?? []));
  //   } catch (e) {
  //     if (currentState is CategoriesLoaded) {
  //       emit(CategoriesError(e.toString()));
  //       emit(CategoriesLoaded(currentState.categories));
  //     } else {
  //       emit(CategoriesError(e.toString()));
  //     }
  //   }
  // }

  // Future<void> _onDeleteCategory(DeleteCategory event, Emitter<CategoriesState> emit) async {
  //   final currentState = state;
  //   if (currentState is CategoriesLoaded) {
  //     emit(CategoryDeleting(currentState.categories));
  //   }
  //
  //   try {
  //     await repository.deleteCategory(event.categoryId);
  //
  //     final profile = await repository.getProfile();
  //     emit(CategoryDeleteSuccess(profile.services ?? []));
  //     emit(CategoriesLoaded(profile.services ?? []));
  //   } catch (e) {
  //     if (currentState is CategoriesLoaded) {
  //       emit(CategoriesError(e.toString()));
  //       emit(CategoriesLoaded(currentState.categories));
  //     } else {
  //       emit(CategoriesError(e.toString()));
  //     }
  //   }
  // }
}
