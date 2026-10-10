
/// Model for a single service category from the API.
class ServiceCategoryModel {
  final int id;
  final String categoryName;
  final String categorySlug;
  final int? parentCategoryId;
  final String? description;
  final String? iconUrl;
  final String? iconImageUrl;
  final bool isActive;
  final int displayOrder;
  final String fullCategoryName;
  final String? fullCategoryDescription;
  final double gstPercentage;
  final List<RateCardModel> rateCards;
  final int? cityAdminId;

  const ServiceCategoryModel({
    required this.id,
    required this.categoryName,
    required this.categorySlug,
    this.parentCategoryId,
    this.description,
    this.iconUrl,
    this.iconImageUrl,
    required this.isActive,
    required this.displayOrder,
    required this.fullCategoryName,
    this.fullCategoryDescription,
    this.gstPercentage = 0,
    this.rateCards = const [],
    this.cityAdminId,
  });

  factory ServiceCategoryModel.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>?;
    final parentName = category?['category_name']?.toString();
    final name = json['category_name']?.toString() ?? json['name']?.toString() ?? '';

    // Robust double parsing for gst_percentage
    double parseGst(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    return ServiceCategoryModel(
      id: json['id'] is int ? json['id'] : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      categoryName: name,
      categorySlug: json['category_slug']?.toString() ?? json['slug']?.toString() ?? '',
      parentCategoryId: json['parent_category_id'] is int?
          ? json['parent_category_id']
          : (json['parent_id'] is int? ? json['parent_id'] : int.tryParse(json['parent_id']?.toString() ?? '')),
      description: json['description']?.toString(),
      iconUrl: json['icon_url']?.toString() ?? json['image']?.toString(),
      iconImageUrl: json['icon_image_url']?.toString() ?? json['image']?.toString(),
      isActive: json['is_active'] == true || json['is_active'] == 1 || json['is_active'] == '1' || json['is_active']?.toString() == 'true',
      displayOrder: int.tryParse(json['display_order']?.toString() ?? '') ?? 0,
      fullCategoryName: parentName ?? '',
      fullCategoryDescription: category?['description']?.toString(),
      gstPercentage: parseGst(json['gst_percentage']),
      cityAdminId: json['city_admin_id'] is int
          ? json['city_admin_id']
          : int.tryParse(json['city_admin_id']?.toString() ?? ''),
      rateCards: (json['rate_cards'] as List<dynamic>?)
              ?.map((e) => RateCardModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category_name': categoryName,
    'category_slug': categorySlug,
    'parent_category_id': parentCategoryId,
    'description': description,
    'icon_url': iconUrl,
    'icon_image_url': iconImageUrl,
    'is_active': isActive,
    'display_order': displayOrder,
    'full_category_name': fullCategoryName,
    'gst_percentage': gstPercentage,
    'city_admin_id': cityAdminId,
    'rate_cards': rateCards.map((e) => e.toJson()).toList(),
  };
}

/// Model for a Rate Card representing pricing details of a subcategory.
class RateCardModel {
  final int id;
  final int? serviceCategoryId;
  final int? serviceSubcategoryId;
  final int? serviceId;
  final int? cityAdminId;
  final String city;
  final String bookingType; // 'procedural' | 'long_duration'
  final double basePrice;
  final double pricePerHour;
  final double pricePerDay;
  final double pricePerHourNight;
  final double proceduralDiscountPercentage;
  final double pricePerNight;
  final double pricePerFullDay;
  final double pricePerKm;
  final List<RateCardPackageModel> packages;
  final String? unitType;
  final int? qtyInMin;

  const RateCardModel({
    required this.id,
    this.serviceCategoryId,
    this.serviceSubcategoryId,
    this.serviceId,
    this.cityAdminId,
    required this.city,
    required this.bookingType,
    required this.basePrice,
    required this.pricePerHour,
    required this.pricePerDay,
    required this.pricePerHourNight,
    required this.proceduralDiscountPercentage,
    required this.pricePerNight,
    required this.pricePerFullDay,
    required this.pricePerKm,
    this.packages = const [],
    this.unitType,
    this.qtyInMin,
  });

  factory RateCardModel.fromJson(Map<String, dynamic> json) {
    double p(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    int? parseInt(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      return null;
    }

    return RateCardModel(
      id: json['id'] is int ? json['id'] : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      serviceCategoryId: parseInt(json['service_category_id']),
      serviceSubcategoryId: parseInt(json['service_subcategory_id']),
      serviceId: parseInt(json['service_id']),
      cityAdminId: parseInt(json['city_admin_id']),
      city: json['city'] as String? ?? '',
      bookingType: json['booking_type'] as String? ?? 'procedural',
      basePrice: p(json['base_price']),
      pricePerHour: p(json['price_per_hour']),
      pricePerDay: p(json['price_per_day']),
      pricePerHourNight: p(json['price_per_hour_night']),
      proceduralDiscountPercentage: p(json['procedural_discount_percentage']),
      pricePerNight: p(json['price_per_night']),
      pricePerFullDay: p(json['price_per_full_day']),
      pricePerKm: p(json['price_per_km']),
      packages: (json['packages'] as List<dynamic>?)
              ?.map((e) => RateCardPackageModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      unitType: json['unit_type'] as String?,
      qtyInMin: parseInt(json['qty_in_min']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'service_category_id': serviceCategoryId,
    'service_subcategory_id': serviceSubcategoryId,
    'service_id': serviceId,
    'city_admin_id': cityAdminId,
    'city': city,
    'booking_type': bookingType,
    'base_price': basePrice,
    'price_per_hour': pricePerHour,
    'price_per_day': pricePerDay,
    'price_per_hour_night': pricePerHourNight,
    'procedural_discount_percentage': proceduralDiscountPercentage,
    'price_per_night': pricePerNight,
    'price_per_full_day': pricePerFullDay,
    'price_per_km': pricePerKm,
    'packages': packages.map((e) => e.toJson()).toList(),
    'unit_type': unitType,
    'qty_in_min': qtyInMin,
  };
}

/// Model for a rate card package (pre-defined duration bundles with discounts).
class RateCardPackageModel {
  final int id;
  final int rateCardId;
  final String shiftType;       // e.g. 'day_shift', 'night_shift', '24_hours'
  final String durationType;    // e.g. 'days', 'hours'
  final int duration;           // e.g. 7, 14, 30
  final double actualPrice;
  final double discountPercentage;
  final double price;           // final discounted price
  final String? description;
  final int sortOrder;

  const RateCardPackageModel({
    required this.id,
    required this.rateCardId,
    required this.shiftType,
    required this.durationType,
    required this.duration,
    required this.actualPrice,
    required this.discountPercentage,
    required this.price,
    this.description,
    this.sortOrder = 0,
  });

  factory RateCardPackageModel.fromJson(Map<String, dynamic> json) {
    return RateCardPackageModel(
      id: json['id'] as int,
      rateCardId: (json['rate_card_id'] as num?)?.toInt() ?? 0,
      shiftType: json['shift_type']?.toString() ?? '',
      durationType: json['duration_type']?.toString() ?? 'days',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      actualPrice: double.tryParse(json['actual_price']?.toString() ?? '') ?? 0.0,
      discountPercentage: double.tryParse(json['discount_percentage']?.toString() ?? '') ?? 0.0,
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0.0,
      description: json['description']?.toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'rate_card_id': rateCardId,
    'shift_type': shiftType,
    'duration_type': durationType,
    'duration': duration,
    'actual_price': actualPrice,
    'discount_percentage': discountPercentage,
    'price': price,
    'description': description,
    'sort_order': sortOrder,
  };
}

/// Level-3 service item nested inside a SubCategoryDataModel.
class ServiceItemModel {
  final int id;
  final String name;
  final String? description;
  final String? iconImageUrl;
  final List<RateCardModel> rateCards;
  final double gstPercentage;

  const ServiceItemModel({
    required this.id,
    required this.name,
    this.description,
    this.iconImageUrl,
    this.rateCards = const [],
    this.gstPercentage = 0,
  });

  factory ServiceItemModel.fromJson(Map<String, dynamic> json) {
    double p(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }
    return ServiceItemModel(
      id: json['id'] is int ? json['id'] : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      iconImageUrl: json['icon_image_url']?.toString(),
      gstPercentage: p(json['gst_percentage']),
      rateCards: (json['rate_cards'] as List<dynamic>?)
              ?.map((e) => RateCardModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// Level-2 subcategory from /get-sub-categories API.
/// If [services] is non-empty → accordion with Level-3 items.
/// If [services] is empty → direct selectable service card.
class SubCategoryDataModel {
  final int id;
  final String name;
  final String? description;
  final String? iconImageUrl;
  final String? typeLabel;
  final List<ServiceItemModel> services;
  final List<RateCardModel> rateCards;
  final int displayOrder;
  final double gstPercentage;

  const SubCategoryDataModel({
    required this.id,
    required this.name,
    this.description,
    this.iconImageUrl,
    this.typeLabel,
    this.services = const [],
    this.rateCards = const [],
    this.displayOrder = 0,
    this.gstPercentage = 0,
  });

  bool get hasServices => services.isNotEmpty;

  factory SubCategoryDataModel.fromJson(Map<String, dynamic> json) {
    double p(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }
    return SubCategoryDataModel(
      id: json['id'] is int ? json['id'] : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      iconImageUrl: json['icon_image_url']?.toString(),
      typeLabel: json['type_label']?.toString(),
      displayOrder: int.tryParse(json['display_order']?.toString() ?? '') ?? 0,
      gstPercentage: p(json['gst_percentage']),
      services: (json['services'] as List<dynamic>?)
              ?.map((e) => ServiceItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      rateCards: (json['rate_cards'] as List<dynamic>?)
              ?.map((e) => RateCardModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// Response wrapper for /get-sub-categories API.
class SubCategoriesApiResponse {
  final bool status;
  final String message;
  final List<SubCategoryDataModel> data;

  const SubCategoriesApiResponse({
    required this.status,
    required this.message,
    this.data = const [],
  });

  factory SubCategoriesApiResponse.fromJson(Map<String, dynamic> json) {
    return SubCategoriesApiResponse(
      status: json['status'] as bool? ?? false,
      message: json['message']?.toString() ?? '',
      data: (json['data'] as List<dynamic>?)
              ?.map((e) => SubCategoryDataModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// Top-level response wrapper for the categories list API.
class ServiceCategoriesResponse {
  final bool status;
  final int categoriesCount;
  final List<ServiceCategoryModel> data;
  final String message;

  const ServiceCategoriesResponse({
    required this.status,
    required this.categoriesCount,
    required this.data,
    required this.message,
  });

  factory ServiceCategoriesResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['data'] as List<dynamic>? ?? [];
    return ServiceCategoriesResponse(
      status: json['status'] as bool? ?? false,
      categoriesCount: (json['categories_count'] as num?)?.toInt() ?? 0,
      data: rawList
          .map((e) => ServiceCategoryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      message: json['message']?.toString() ?? '',
    );
  }
}
