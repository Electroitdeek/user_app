import 'package:adhisaat_health_care/features/user/service_booking/model/service_category_model.dart';

class ProcedureModel {
  final int id;
  final int cityAdminId;
  final int serviceCategoryId;
  final int? serviceSubcategoryId;
  final String name;
  final String slug;
  final String? description;
  final String type;
  final bool genderPreference;
  final String? image;
  final int displayOrder;
  final bool isActive;
  final bool isEmergency;
  final double gstPercentage;
  final String? categoryName;
  final String? subcategoryName;
  final String? iconImageUrl;
  final List<RateCardModel> rateCards;

  ProcedureModel({
    required this.id,
    required this.cityAdminId,
    required this.serviceCategoryId,
    this.serviceSubcategoryId,
    required this.name,
    required this.slug,
    this.description,
    required this.type,
    required this.genderPreference,
    this.image,
    required this.displayOrder,
    required this.isActive,
    required this.isEmergency,
    required this.gstPercentage,
    this.categoryName,
    this.subcategoryName,
    this.iconImageUrl,
    this.rateCards = const [],
  });

  factory ProcedureModel.fromJson(Map<String, dynamic> json) {
    return ProcedureModel(
      id: json['id'] as int,
      cityAdminId: json['city_admin_id'] as int,
      serviceCategoryId: json['service_category_id'] as int,
      serviceSubcategoryId: json['service_subcategory_id'] as int?,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      type: json['type'] as String,
      genderPreference: json['gender_preference'] == true || json['gender_preference'] == 1,
      image: json['image'] as String?,
      displayOrder: json['display_order'] as int,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      isEmergency: json['is_emergency'] == 1 || json['is_emergency'] == true,
      gstPercentage: (json['gst_percentage'] as num?)?.toDouble() ?? 0.0,
      categoryName: json['category_name'] as String?,
      subcategoryName: json['subcategory_name'] as String?,
      iconImageUrl: json['icon_image_url'] as String?,
      rateCards: (json['rate_cards'] as List<dynamic>?)
              ?.map((e) => RateCardModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class ProcedureResponse {
  final bool status;
  final String message;
  final int proceduresCount;
  final List<ProcedureModel> data;

  ProcedureResponse({
    required this.status,
    required this.message,
    required this.proceduresCount,
    required this.data,
  });

  factory ProcedureResponse.fromJson(Map<String, dynamic> json) {
    return ProcedureResponse(
      status: json['status'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      proceduresCount: json['procedures_count'] as int? ?? 0,
      data: (json['data'] as List<dynamic>?)
              ?.map((e) => ProcedureModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
