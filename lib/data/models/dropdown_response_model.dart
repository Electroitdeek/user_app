class DropdownResponse {
  final bool status;
  final DropdownData data;
  final String message;

  DropdownResponse({required this.status, required this.data, required this.message});

  factory DropdownResponse.fromJson(Map<String, dynamic> json) {
    return DropdownResponse(
      status: json['status'] ?? false,
      data: DropdownData.fromJson(json['data'] ?? {}),
      message: json['message'] ?? "",
    );
  }
}

class DropdownData {
  final List<ServiceCategory> serviceCategories;
  final List<HierarchyCategory> serviceHierarchy;
  final int serviceCategoryCount;
  final Map<String, String> documentTypes;
  final Map<String, String> bloodGroups;
  final Map<String, String> dutyTypes;
  final Map<String, String> genders;
  final Map<String, String> totalExperience;
  final Map<String, String> verificationStatus;
  final Map<String, String> consentTypes;
  final Map<String, String> serviceTypes;
  final Map<String, String> serviceModes;
  final Map<String, String> shiftTypes;
  final List<DynamicDocumentType> dynamicDocumentTypes;

  DropdownData({
    required this.serviceCategories,
    required this.serviceHierarchy,
    required this.serviceCategoryCount,
    required this.documentTypes,
    required this.bloodGroups,
    required this.dutyTypes,
    required this.genders,
    required this.totalExperience,
    required this.verificationStatus,
    required this.consentTypes,
    required this.serviceTypes,
    required this.serviceModes,
    required this.shiftTypes,
    required this.dynamicDocumentTypes,
  });

  factory DropdownData.fromJson(Map<String, dynamic> json) {
    return DropdownData(
      serviceCategories: (json['service_category'] as List? ?? [])
          .map((item) => ServiceCategory.fromJson(item))
          .toList(),
      serviceHierarchy: (json['service_hierarchy'] as List? ?? [])
          .map((item) => HierarchyCategory.fromJson(item))
          .toList(),
      serviceCategoryCount: json['service_category_count'] ?? 0,
      documentTypes: Map<String, String>.from(json['documentType'] ?? {}),
      bloodGroups: Map<String, String>.from(json['bloodGroups'] ?? {}),
      dutyTypes: Map<String, String>.from(json['dutyTypes'] ?? {}),
      genders: Map<String, String>.from(json['genders'] ?? {}),
      totalExperience: Map<String, String>.from(json['totalExperience'] ?? {}),
      verificationStatus: Map<String, String>.from(json['verificationStatus'] ?? {}),
      consentTypes: Map<String, String>.from(json['consentTypes'] ?? {}),
      serviceTypes: Map<String, String>.from(json['serviceTypes'] ?? {}),
      serviceModes: Map<String, String>.from(json['serviceModes'] ?? {}),
      shiftTypes: Map<String, String>.from(json['shiftTypes'] ?? {}),
      dynamicDocumentTypes: (json['dynamicDocumentType'] as List? ?? [])
          .map((item) => DynamicDocumentType.fromJson(item))
          .toList(),
    );
  }
}

class ServiceCategory {
  final int id;
  final int? cityAdminId;
  final String categoryName;
  final String? serviceLevel;
  final String? categorySlug;
  final String? description;
  final String? iconUrl;
  final bool isActive;
  final bool isEmergency;
  final String gstPercentage;
  final int displayOrder;
  final String? iconImageUrl;
  final String gstPercentageDisplay;
  final String? isEmergencyText;
  final List<Service> services;
  final String? type;
  final int? parentId;

  // Legacy fields for backward compatibility if needed
  final String? parentCategoryName;
  final String? fullCategoryName;

  ServiceCategory({
    required this.id,
    this.cityAdminId,
    required this.categoryName,
    this.serviceLevel,
    this.categorySlug,
    this.description,
    this.iconUrl,
    this.isActive = true,
    this.isEmergency = false,
    this.gstPercentage = "0.00",
    this.displayOrder = 0,
    this.iconImageUrl,
    this.gstPercentageDisplay = "0.00%",
    this.isEmergencyText,
    this.services = const [],
    this.parentCategoryName,
    this.fullCategoryName,
    this.type,
    this.parentId,
  });

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    return ServiceCategory(
      id: json['id'],
      cityAdminId: json['city_admin_id'],
      categoryName: json['category_name'] ?? "",
      serviceLevel: json['service_level'],
      categorySlug: json['category_slug'],
      description: json['description'],
      iconUrl: json['icon_url'],
      isActive: json['is_active'] == true || json['is_active'] == 1,
      isEmergency: json['is_emergency'] == true || json['is_emergency'] == 1,
      gstPercentage: json['gst_percentage']?.toString() ?? "0.00",
      displayOrder: json['display_order'] ?? 0,
      iconImageUrl: json['icon_image_url'],
      gstPercentageDisplay: json['gst_percentage_display'] ?? "0.00%",
      isEmergencyText: json['is_emergency_text'],
      services: (json['services'] as List? ?? []).map((i) => Service.fromJson(i)).toList(),
      parentCategoryName: json['parent_category_name'] ?? json['category_name'] ?? '',
      fullCategoryName: json['full_category_name'] ?? json['category_name'] ?? "",
      type: json['type'],
      parentId: json['parent_id'],
    );
  }
}

class Service {
  final int id;
  final int cityAdminId;
  final int serviceCategoryId;
  final int? serviceSubcategoryId;
  final String name;
  final String slug;
  final String? description;
  final String type;
  final String? image;
  final String? iconImageUrl;
  final int displayOrder;
  final bool isActive;
  final bool isEmergency;
  final String gstPercentage;
  final String createdAt;
  final String updatedAt;
  final String gstPercentageDisplay;

  Service({
    required this.id,
    required this.cityAdminId,
    required this.serviceCategoryId,
    this.serviceSubcategoryId,
    required this.name,
    required this.slug,
    this.description,
    required this.type,
    this.image,
    this.iconImageUrl,
    required this.displayOrder,
    required this.isActive,
    required this.isEmergency,
    required this.gstPercentage,
    required this.createdAt,
    required this.updatedAt,
    required this.gstPercentageDisplay,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'],
      cityAdminId: json['city_admin_id'],
      serviceCategoryId: json['service_category_id'],
      serviceSubcategoryId: json['service_subcategory_id'],
      name: json['name'] ?? "",
      slug: json['slug'] ?? "",
      description: json['description'],
      type: json['type'] ?? "",
      image: json['image'],
      iconImageUrl: json['icon_image_url'],
      displayOrder: json['display_order'] ?? 0,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      isEmergency: json['is_emergency'] == 1 || json['is_emergency'] == true,
      gstPercentage: json['gst_percentage']?.toString() ?? "0",
      createdAt: json['created_at'] ?? "",
      updatedAt: json['updated_at'] ?? "",
      gstPercentageDisplay: json['gst_percentage_display'] ?? "",
    );
  }
}

class HierarchyCategory {
  final int id;
  final int cityAdminId;
  final String categoryName;
  final String serviceLevel;
  final String categorySlug;
  final String? description;
  final String? iconUrl;
  final bool isActive;
  final bool isEmergency;
  final String gstPercentage;
  final int displayOrder;
  final String? iconImageUrl;
  final String gstPercentageDisplay;
  final String isEmergencyText;
  final List<HierarchySubcategory> subcategories;
  final List<Service> directProcedures;

  HierarchyCategory({
    required this.id,
    required this.cityAdminId,
    required this.categoryName,
    required this.serviceLevel,
    required this.categorySlug,
    this.description,
    this.iconUrl,
    required this.isActive,
    required this.isEmergency,
    required this.gstPercentage,
    required this.displayOrder,
    this.iconImageUrl,
    required this.gstPercentageDisplay,
    required this.isEmergencyText,
    required this.subcategories,
    required this.directProcedures,
  });

  factory HierarchyCategory.fromJson(Map<String, dynamic> json) {
    return HierarchyCategory(
      id: json['id'],
      cityAdminId: json['city_admin_id'],
      categoryName: json['category_name'] ?? "",
      serviceLevel: json['service_level'] ?? "",
      categorySlug: json['category_slug'] ?? "",
      description: json['description'],
      iconUrl: json['icon_url'],
      isActive: json['is_active'] == true || json['is_active'] == 1,
      isEmergency: json['is_emergency'] == true || json['is_emergency'] == 1,
      gstPercentage: json['gst_percentage']?.toString() ?? "0.00",
      displayOrder: json['display_order'] ?? 0,
      iconImageUrl: json['icon_image_url'],
      gstPercentageDisplay: json['gst_percentage_display'] ?? "0.00%",
      isEmergencyText: json['is_emergency_text'] ?? "",
      subcategories: (json['subcategories'] as List? ?? []).map((i) => HierarchySubcategory.fromJson(i)).toList(),
      directProcedures: (json['direct_procedures'] as List? ?? []).map((i) => Service.fromJson(i)).toList(),
    );
  }
}

class HierarchySubcategory {
  final int id;
  final int cityAdminId;
  final int serviceCategoryId;
  final String name;
  final String slug;
  final String? description;
  final String? image;
  final int displayOrder;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  final List<Service> procedures;

  HierarchySubcategory({
    required this.id,
    required this.cityAdminId,
    required this.serviceCategoryId,
    required this.name,
    required this.slug,
    this.description,
    this.image,
    required this.displayOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.procedures,
  });

  factory HierarchySubcategory.fromJson(Map<String, dynamic> json) {
    return HierarchySubcategory(
      id: json['id'],
      cityAdminId: json['city_admin_id'],
      serviceCategoryId: json['service_category_id'],
      name: json['name'] ?? "",
      slug: json['slug'] ?? "",
      description: json['description'],
      image: json['image'],
      displayOrder: json['display_order'] ?? 0,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      createdAt: json['created_at'] ?? "",
      updatedAt: json['updated_at'] ?? "",
      procedures: (json['procedures'] as List? ?? []).map((i) => Service.fromJson(i)).toList(),
    );
  }
}

class DynamicDocumentType {
  final int id;
  final String key;
  final String name;
  final bool isRequired;
  final bool isActive;
  final String? sampleFile;
  final String? sampleFileUrl;

  DynamicDocumentType({
    required this.id,
    required this.key,
    required this.name,
    required this.isRequired,
    required this.isActive,
    this.sampleFile,
    this.sampleFileUrl,
  });

  factory DynamicDocumentType.fromJson(Map<String, dynamic> json) {
    return DynamicDocumentType(
      id: json['id'] ?? 0,
      key: json['key'] ?? "",
      name: json['name'] ?? "",
      isRequired: json['is_required'] == true || json['is_required'] == 1,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      sampleFile: json['sample_file'],
      sampleFileUrl: json['sample_file_url'],
    );
  }
}
