class ProviderCategoryItem {
  final int id;
  final int serviceProviderId;
  final int serviceId;
  final bool isPrimary;
  final String createdAt;
  final ProviderServiceItem service;

  const ProviderCategoryItem({
    required this.id,
    required this.serviceProviderId,
    required this.serviceId,
    required this.isPrimary,
    required this.createdAt,
    required this.service,
  });

  // Compatibility getters for UI/Bloc
  ProviderCategoryDetail get serviceCategory => ProviderCategoryDetail(
        id: service.category?.id ?? 0,
        categoryName: service.category?.categoryName ?? service.name,
        iconImageUrl: service.category?.iconImageUrl ?? service.image,
        isActive: service.isActive,
        isEmergency: service.isEmergency,
        fullCategoryName: service.category?.categoryName ?? service.name,
        description: service.category?.description,
        parentCategory: service.category?.parentCategory,
      );

  int get serviceCategoryId => serviceId;

  factory ProviderCategoryItem.fromJson(Map<String, dynamic> json) =>
      ProviderCategoryItem(
        id: json['id'] ?? 0,
        serviceProviderId: json['service_provider_id'] ?? 0,
        serviceId: json['service_id'] ?? 0,
        isPrimary: json['is_primary'] == true || json['is_primary'] == 1,
        createdAt: json['created_at'] ?? '',
        service: ProviderServiceItem.fromJson(json['service'] as Map<String, dynamic>? ?? {}),
      );
}

class ProviderServiceItem {
  final int id;
  final String name;
  final String? image;
  final String? iconImageUrl;
  final String? description;
  final bool isActive;
  final bool isEmergency;
  final ProviderCategoryDetail? category;

  const ProviderServiceItem({
    required this.id,
    required this.name,
    this.image,
    this.iconImageUrl,
    this.description,
    required this.isActive,
    required this.isEmergency,
    this.category,
  });

  factory ProviderServiceItem.fromJson(Map<String, dynamic> json) =>
      ProviderServiceItem(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        image: json['image'],
        iconImageUrl: json['icon_image_url']?.toString(),
        description: json['description']?.toString(),
        isActive: json['is_active'] == true || json['is_active'] == 1,
        isEmergency: json['is_emergency'] == true || json['is_emergency'] == 1,
        category: json['category'] != null
            ? ProviderCategoryDetail.fromJson(json['category'] as Map<String, dynamic>)
            : null,
      );
}

class ProviderCategoryDetail {
  final int id;
  final String categoryName;
  final String? iconImageUrl;
  final String? description;
  final bool isActive;
  final bool isEmergency;
  final String fullCategoryName;
  final ProviderParentCategory? parentCategory;

  const ProviderCategoryDetail({
    required this.id,
    required this.categoryName,
    this.iconImageUrl,
    this.description,
    required this.isActive,
    required this.isEmergency,
    required this.fullCategoryName,
    this.parentCategory,
  });

  factory ProviderCategoryDetail.fromJson(Map<String, dynamic> json) =>
      ProviderCategoryDetail(
        id: json['id'] ?? 0,
        categoryName: json['category_name'] ?? '',
        iconImageUrl: json['icon_image_url'],
        description: json['description']?.toString(),
        isActive: json['is_active'] == true || json['is_active'] == 1,
        isEmergency: json['is_emergency'] == true || json['is_emergency'] == 1,
        fullCategoryName: json['full_category_name'] ?? '',
        parentCategory: json['parent_category'] != null
            ? ProviderParentCategory.fromJson(json['parent_category'] as Map<String, dynamic>)
            : null,
      );
}

class ProviderParentCategory {
  final int id;
  final String categoryName;
  final String? iconImageUrl;
  final bool isEmergency;

  const ProviderParentCategory({
    required this.id,
    required this.categoryName,
    this.iconImageUrl,
    required this.isEmergency,
  });

  factory ProviderParentCategory.fromJson(Map<String, dynamic> json) =>
      ProviderParentCategory(
        id: json['id'] ?? 0,
        categoryName: json['category_name'] ?? '',
        iconImageUrl: json['icon_image_url'],
        isEmergency: json['is_emergency'] == true || json['is_emergency'] == 1,
      );
}
