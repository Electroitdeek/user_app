import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/service_category_repository.dart';
import '../model/service_category_model.dart';

part 'service_category_event.dart';
part 'service_category_state.dart';

class ServiceCategoryBloc
    extends Bloc<ServiceCategoryEvent, ServiceCategoryState> {
  final ServiceCategoryRepository _repository;

  ServiceCategoryBloc(this._repository) : super(ServiceCategoryInitial()) {
    on<LoadServiceCategories>(_onLoad);
  }

  Future<void> _onLoad(
    LoadServiceCategories event,
    Emitter<ServiceCategoryState> emit,
  ) async {
    if (!event.isSilent || state is! ServiceCategoryLoaded) {
      emit(ServiceCategoryLoading());
    }

    try {
      final categories = await _repository.getServiceCategories(
        isEmergency: event.isEmergency,
        cityAdminId: event.cityAdminId,
      );
      emit(ServiceCategoryLoaded(categories));
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('city_admin_id') || errorStr.contains('422')) {
        emit(ServiceCategoryError('city_admin_id_required'));
      } else {
        if (!event.isSilent || state is! ServiceCategoryLoaded) {
          emit(ServiceCategoryError(errorStr));
        }
      }
    }
  }
}
