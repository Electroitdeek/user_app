part of 'manage_categories_bloc.dart';

abstract class ManageCategoriesState {}

class ManageCategoriesInitial extends ManageCategoriesState {}

class ManageCategoriesLoading extends ManageCategoriesState {}

class ManageCategoriesLoaded extends ManageCategoriesState {
  final List<ProviderCategoryItem> categories;
  final List<ServiceCategoryModel> dropdownCategories;
  final bool isActionLoading; // true during delete / save API call
  final String? successMessage;
  final Set<int> pendingAddIds; // selected in add-sheet but not yet saved

  ManageCategoriesLoaded({
    required this.categories,
    this.dropdownCategories = const [],
    this.isActionLoading = false,
    this.successMessage,
    this.pendingAddIds = const {},
  });

  // Group by parent category name for section display
  Map<String, List<ProviderCategoryItem>> get grouped {
    final map = <String, List<ProviderCategoryItem>>{};
    for (final item in categories) {
      final parent = item.service.category?.categoryName ?? 'Other';
      map.putIfAbsent(parent, () => []).add(item);
    }
    return map;
  }

  // IDs already added (to exclude from add sheet)
  Set<int> get existingCategoryIds => categories.map((c) => c.serviceCategoryId).toSet();

  ManageCategoriesLoaded copyWith({
    List<ProviderCategoryItem>? categories,
    List<ServiceCategoryModel>? dropdownCategories,
    bool? isActionLoading,
    String? successMessage,
    Set<int>? pendingAddIds,
    bool clearMessage = false,
  }) => ManageCategoriesLoaded(
    categories: categories ?? this.categories,
    dropdownCategories: dropdownCategories ?? this.dropdownCategories,
    isActionLoading: isActionLoading ?? this.isActionLoading,
    successMessage: clearMessage ? null : (successMessage ?? this.successMessage),
    pendingAddIds: pendingAddIds ?? this.pendingAddIds,
  );
}

class ManageCategoriesError extends ManageCategoriesState {
  final String message;

  ManageCategoriesError(this.message);
}

class DeleteCategoriesError extends ManageCategoriesState {
  final String message;

  DeleteCategoriesError(this.message);
}
