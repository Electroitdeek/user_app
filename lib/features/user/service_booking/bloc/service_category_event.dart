part of 'service_category_bloc.dart';

abstract class ServiceCategoryEvent {}

class LoadServiceCategories extends ServiceCategoryEvent {
  final bool? isEmergency;
  final bool isSilent;
  final bool useCacheFirst;
  final int? cityAdminId;

  LoadServiceCategories({
    this.isSilent = false,
    this.useCacheFirst = false,
    this.isEmergency,
    this.cityAdminId,
  });
}
