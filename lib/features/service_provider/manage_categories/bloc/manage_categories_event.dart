part of 'manage_categories_bloc.dart';

abstract class ManageCategoriesEvent {}

/// Load provider's current categories from /provider/categories
class LoadProviderCategories extends ManageCategoriesEvent {}

/// Delete multiple categories (sub-services) by their serviceCategoryIds
class DeleteProviderCategory extends ManageCategoriesEvent {
  final List<int> serviceCategoryIds;
  DeleteProviderCategory({required this.serviceCategoryIds});
}

/// Add new categories via /provider/category-save
class AddProviderCategories extends ManageCategoriesEvent {
  final List<int> newCategoryIds;
  AddProviderCategories(this.newCategoryIds);
}

/// Toggle selection in the add-category bottom sheet
class ToggleAddSelection extends ManageCategoriesEvent {
  final int categoryId;
  ToggleAddSelection(this.categoryId);
}

class ToggleMultipleAddSelection extends ManageCategoriesEvent {
  final List<int> categoryIds;
  final bool select;
  ToggleMultipleAddSelection(this.categoryIds, this.select);
}

class ClearAddSelection extends ManageCategoriesEvent {}
