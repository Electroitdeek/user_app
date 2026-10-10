import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/api/api_endpoints.dart';
import 'package:adhisaat_health_care/core/storage/local_storage_service.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../user/service_booking/model/service_category_model.dart';
import '../model/provider_category_model.dart';

part 'manage_categories_event.dart';
part 'manage_categories_state.dart';

class ManageCategoriesBloc extends Bloc<ManageCategoriesEvent, ManageCategoriesState> {
  final ApiClient _api;

  ManageCategoriesBloc(this._api) : super(ManageCategoriesInitial()) {
    on<LoadProviderCategories>(_onLoad);
    on<DeleteProviderCategory>(_onDelete);
    on<AddProviderCategories>(_onAdd);
    on<ToggleAddSelection>(_onToggleAdd);
    on<ToggleMultipleAddSelection>(_onToggleMultipleAdd);
    on<ClearAddSelection>(_onClearAdd);
  }

  // ── Load ───────────────────────────────────────────────────────
  Future<void> _onLoad(LoadProviderCategories e, Emitter emit) async {
    emit(ManageCategoriesLoading());
    try {
      final response = await _api.get(
        ApiEndpoints.getProviderCategories,
        query: {'exclude_man_machine_services': '1'},
      );
      final list = (response['data'] as List<dynamic>? ?? [])
          .map((j) => ProviderCategoryItem.fromJson(j as Map<String, dynamic>))
          .toList();

      final rawCategories = response['categories'] as List<dynamic>? ?? [];
      final List<ServiceCategoryModel> flattenedServices = [];
      for (final catJson in rawCategories) {
        final categoryName = catJson['category_name']?.toString() ?? 'Other';
        final parentIconUrl = catJson['icon_image_url']?.toString();
        final parentDescription = catJson['description']?.toString();
        final services = catJson['services'] as List<dynamic>? ?? [];
        for (final serviceJson in services) {
          final serviceMap = Map<String, dynamic>.from(serviceJson);
          serviceMap['category'] = {'category_name': categoryName, 'description': parentDescription};
          // Keep each sub-service's own icon; fall back to the parent category icon only when missing.
          final ownIcon = serviceMap['icon_image_url']?.toString();
          if ((ownIcon == null || ownIcon.isEmpty) && parentIconUrl != null) {
            serviceMap['icon_image_url'] = parentIconUrl;
          }
          flattenedServices.add(ServiceCategoryModel.fromJson(serviceMap));
        }
      }

      emit(ManageCategoriesLoaded(categories: list, dropdownCategories: flattenedServices));
    } catch (e) {
      emit(ManageCategoriesError(e.toString()));
    }
  }

  // ── Delete ─────────────────────────────────────────────────────
  Future<void> _onDelete(DeleteProviderCategory e, Emitter emit) async {
    if (state is! ManageCategoriesLoaded) return;
    final s = state as ManageCategoriesLoaded;

    // Optimistic removal
    final updated = s.categories.where((c) => !e.serviceCategoryIds.contains(c.serviceCategoryId)).toList();
    emit(s.copyWith(categories: updated, isActionLoading: true));

    try {
      final result = await _api.postMultipart(ApiEndpoints.deleteCategory, {
        'service_ids[]': e.serviceCategoryIds,
      });

      if (result['status'] == false) {
        emit(DeleteCategoriesError(result['message'] ?? 'Failed to delete service'));
        emit(ManageCategoriesLoaded(categories: s.categories));
      } else {
        // Fetch fresh list from server directly to sync state
        final response = await _api.get(
          ApiEndpoints.getProviderCategories,
          query: {'exclude_man_machine_services': '1'},
        );
        final list = (response['data'] as List<dynamic>? ?? [])
            .map((j) => ProviderCategoryItem.fromJson(j as Map<String, dynamic>))
            .toList();

        emit(s.copyWith(categories: list, isActionLoading: false, successMessage: 'Service removed successfully'));
      }
    } catch (err) {
      // Rollback
      emit(s.copyWith(isActionLoading: false));
      kPrint('Failed to delete: $err');
      emit(DeleteCategoriesError('Failed to delete service'));
      emit(ManageCategoriesLoaded(categories: s.categories));
    }
  }

  Future<void> _onAdd(AddProviderCategories e, Emitter emit) async {
    if (state is! ManageCategoriesLoaded) return;
    final s = state as ManageCategoriesLoaded;
    emit(s.copyWith(isActionLoading: true, pendingAddIds: {}));
    try {
      final storage = locator<LocalStorageService>();
      final spId = storage.serviceProvideUserId ?? 0;
      final allIds = {...s.existingCategoryIds, ...e.newCategoryIds};
      await _api.post(ApiEndpoints.saveCategory, {
        'service_provider_id': spId,
        'services': allIds.map((id) => {'service_id': id}).toList(),
      });

      // Emit success message
      emit(s.copyWith(isActionLoading: false, successMessage: "Enrolled successfully..."));

      // Trigger standard reload to refresh the list with shimmer
      add(LoadProviderCategories());
    } catch (err) {
      emit(s.copyWith(isActionLoading: false));
      emit(ManageCategoriesError('Failed to add: $err'));
    }
  }

  // ── Toggle add-sheet selection ─────────────────────────────────
  void _onToggleAdd(ToggleAddSelection e, Emitter emit) {
    if (state is! ManageCategoriesLoaded) return;
    final s = state as ManageCategoriesLoaded;
    final set = Set<int>.from(s.pendingAddIds);
    set.contains(e.categoryId) ? set.remove(e.categoryId) : set.add(e.categoryId);
    emit(s.copyWith(pendingAddIds: set, clearMessage: true));
  }

  void _onClearAdd(ClearAddSelection e, Emitter emit) {
    if (state is! ManageCategoriesLoaded) return;
    emit((state as ManageCategoriesLoaded).copyWith(pendingAddIds: {}, clearMessage: true));
  }

  void _onToggleMultipleAdd(ToggleMultipleAddSelection e, Emitter emit) {
    if (state is! ManageCategoriesLoaded) return;
    final s = state as ManageCategoriesLoaded;
    final set = Set<int>.from(s.pendingAddIds);
    if (e.select) {
      set.addAll(e.categoryIds);
    } else {
      set.removeAll(e.categoryIds);
    }
    emit(s.copyWith(pendingAddIds: set, clearMessage: true));
  }
}
