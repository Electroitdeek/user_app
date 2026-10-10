part of 'categories_bloc.dart';

sealed class CategoriesState {}

final class CategoriesInitial extends CategoriesState {}
final class CategoriesLoading extends CategoriesState {}
final class CategoriesLoaded extends CategoriesState {
  final List<ServiceCategory> services;

  CategoriesLoaded(this.services);

}
final class CategoriesError extends CategoriesState {
  final String message;

  CategoriesError(this.message);
}
