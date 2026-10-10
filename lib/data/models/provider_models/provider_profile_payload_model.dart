class ProviderProfileModel {
  final String? name;
  final String? mobileNumber;
  final String? whatsappNumber;
  final String? email;
  final String? dateOfBirth;
  final String? bloodGroup;
  final String? highestQualification;
  final String? professionalRegistrationNumber;
  final String? councilBoardName;
  final String? totalExperience;
  final String? previousWorkplace;
  final List<String>? dutyType;
  final String? preferredWorkingArea;
  final String? gender;
  final String? profileImageUrl;
  final String? about;
  final String? aadharNo;
  final String? panNumber;
  final String? aadharFilePath;
  final String? panFilePath;
  final List<ServiceCategory>? services;

  ProviderProfileModel({
    this.name,
    this.mobileNumber,
    this.whatsappNumber,
    this.email,
    this.dateOfBirth,
    this.bloodGroup,
    this.highestQualification,
    this.professionalRegistrationNumber,
    this.councilBoardName,
    this.totalExperience,
    this.previousWorkplace,
    this.dutyType,
    this.preferredWorkingArea,
    this.gender,
    this.profileImageUrl,
    this.about,
    this.aadharNo,
    this.panNumber,
    this.aadharFilePath,
    this.panFilePath,
    this.services,
  });

  factory ProviderProfileModel.fromJson(Map<String, dynamic> json) {
    return ProviderProfileModel(
      name: json['name'],
      mobileNumber: json['mobile_number'],
      whatsappNumber: json['whatsapp_number'],
      email: json['email'],
      dateOfBirth: json['date_of_birth'],
      bloodGroup: json['blood_group'],
      highestQualification: json['highest_qualification'],
      professionalRegistrationNumber: json['professional_registration_number'],
      councilBoardName: json['council_board_name'],
      totalExperience: json['total_experience'],
      previousWorkplace: json['previous_workplace'],
      dutyType: json['duty_type'] != null ? List<String>.from(json['duty_type']) : null,
      preferredWorkingArea: json['preferred_working_area'],
      gender: json['gender'],
      profileImageUrl: json['profile_image_url'],
      about: json['about'],
      aadharNo: json['aadhar_no'],
      panNumber: json['pan_number'],
      aadharFilePath: json['aadhar_file_path'],
      panFilePath: json['pan_file_path'],
      services: json['services'] != null
          ? (json['services'] as List).map((e) => ServiceCategory.fromJson(e)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mobile_number': mobileNumber,
      'whatsapp_number': whatsappNumber,
      'email': email,
      'date_of_birth': dateOfBirth,
      'blood_group': bloodGroup,
      'highest_qualification': highestQualification,
      'professional_registration_number': professionalRegistrationNumber,
      'council_board_name': councilBoardName,
      'total_experience': totalExperience,
      'previous_workplace': previousWorkplace,
      'duty_type': dutyType,
      'preferred_working_area': preferredWorkingArea,
      'gender': gender,
      'about': about,
      'aadhar_no': aadharNo,
      'pan_number': panNumber,
    };
  }

  ProviderProfileModel copyWith({
    String? name,
    String? mobileNumber,
    String? whatsappNumber,
    String? email,
    String? dateOfBirth,
    String? bloodGroup,
    String? highestQualification,
    String? professionalRegistrationNumber,
    String? councilBoardName,
    String? totalExperience,
    String? previousWorkplace,
    List<String>? dutyType,
    String? preferredWorkingArea,
    String? gender,
    String? profileImageUrl,
    String? about,
    String? aadharNo,
    String? panNumber,
    String? aadharFilePath,
    String? panFilePath,
    List<ServiceCategory>? services,
  }) {
    return ProviderProfileModel(
      name: name ?? this.name,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      email: email ?? this.email,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      highestQualification: highestQualification ?? this.highestQualification,
      professionalRegistrationNumber: professionalRegistrationNumber ?? this.professionalRegistrationNumber,
      councilBoardName: councilBoardName ?? this.councilBoardName,
      totalExperience: totalExperience ?? this.totalExperience,
      previousWorkplace: previousWorkplace ?? this.previousWorkplace,
      dutyType: dutyType ?? this.dutyType,
      preferredWorkingArea: preferredWorkingArea ?? this.preferredWorkingArea,
      gender: gender ?? this.gender,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      about: about ?? this.about,
      aadharNo: aadharNo ?? this.aadharNo,
      panNumber: panNumber ?? this.panNumber,
      aadharFilePath: aadharFilePath ?? this.aadharFilePath,
      panFilePath: panFilePath ?? this.panFilePath,
      services: services ?? this.services,
    );
  }
}

class ServiceCategory {
  final int id;
  final String categoryName;
  final String categorySlug;
  final int? parentCategoryId;
  final String? description;
  final String? iconUrl;
  final bool isActive;
  final int displayOrder;
  final String fullCategoryName;
  final Pivot? pivot;
  final ParentCategory? parentCategory;

  ServiceCategory({
    required this.id,
    required this.categoryName,
    required this.categorySlug,
    this.parentCategoryId,
    this.description,
    this.iconUrl,
    required this.isActive,
    required this.displayOrder,
    required this.fullCategoryName,
    this.pivot,
    this.parentCategory,
  });

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    return ServiceCategory(
      id: json['id'],
      categoryName: json['category_name'],
      categorySlug: json['category_slug'],
      parentCategoryId: json['parent_category_id'],
      description: json['description'],
      iconUrl: json['icon_url'],
      isActive: json['is_active'] ?? true,
      displayOrder: json['display_order'] ?? 0,
      fullCategoryName: json['full_category_name'] ?? '',
      pivot: json['pivot'] != null ? Pivot.fromJson(json['pivot']) : null,
      parentCategory: json['parent_category'] != null
          ? ParentCategory.fromJson(json['parent_category'])
          : null,
    );
  }
}

class Pivot {
  final int serviceProviderId;
  final int serviceCategoryId;
  final int isPrimary;

  Pivot({
    required this.serviceProviderId,
    required this.serviceCategoryId,
    required this.isPrimary,
  });

  factory Pivot.fromJson(Map<String, dynamic> json) {
    return Pivot(
      serviceProviderId: json['service_provider_id'],
      serviceCategoryId: json['service_category_id'],
      isPrimary: json['is_primary'] ?? 0,
    );
  }
}

class ParentCategory {
  final int id;
  final String categoryName;
  final String categorySlug;
  final String fullCategoryName;

  ParentCategory({
    required this.id,
    required this.categoryName,
    required this.categorySlug,
    required this.fullCategoryName,
  });

  factory ParentCategory.fromJson(Map<String, dynamic> json) {
    return ParentCategory(
      id: json['id'],
      categoryName: json['category_name'],
      categorySlug: json['category_slug'],
      fullCategoryName: json['full_category_name'] ?? '',
    );
  }
}