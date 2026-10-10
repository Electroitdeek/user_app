part of 'service_category_bloc.dart';

abstract class ServiceCategoryState {}

class ServiceCategoryInitial extends ServiceCategoryState {}

class ServiceCategoryLoading extends ServiceCategoryState {}

class ServiceCategoryLoaded extends ServiceCategoryState {
  final List<ServiceCategoryModel> categories;
  ServiceCategoryLoaded(this.categories);
}

class ServiceCategoryError extends ServiceCategoryState {
  final String message;
  ServiceCategoryError(this.message);
}
