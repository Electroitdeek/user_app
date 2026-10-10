// ==================== USER ROLE ====================
class UserRoleModel {
  final int id;
  final String name;
  final String label;
  final String? description;
  final String roleType;
  final bool isActive;
  final String guardName;
  final String createdAt;
  final String updatedAt;
  final RolePivot pivot;

  UserRoleModel({
    required this.id,
    required this.name,
    required this.label,
    this.description,
    required this.roleType,
    required this.isActive,
    required this.guardName,
    required this.createdAt,
    required this.updatedAt,
    required this.pivot,
  });

  factory UserRoleModel.fromJson(Map<String, dynamic> json) {
    return UserRoleModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name'] ?? '',
      label: json['label'] ?? '',
      description: json['description'],
      roleType: json['role_type'] ?? '',
      isActive: json['is_active'] == true || json['is_active'] == 1,
      guardName: json['guard_name'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      pivot: RolePivot.fromJson(json['pivot'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'label': label,
      'description': description,
      'role_type': roleType,
      'is_active': isActive,
      'guard_name': guardName,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'pivot': pivot.toJson(),
    };
  }
}

class RolePivot {
  final String modelType;
  final int modelId;
  final int roleId;

  RolePivot({required this.modelType, required this.modelId, required this.roleId});

  factory RolePivot.fromJson(Map<String, dynamic> json) {
    return RolePivot(
      modelType: json['model_type'] ?? '',
      modelId: int.tryParse(json['model_id']?.toString() ?? '') ?? 0,
      roleId: int.tryParse(json['role_id']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'model_type': modelType, 'model_id': modelId, 'role_id': roleId};
  }
}

// ==================== SERVICE PROVIDER PROFILE ====================
class ServiceProviderProfile {
  final int id;
  final int userId;
  final int? cityAdminId;
  final String fullName;
  final String? about;
  final String? highestQualification;
  final String? professionalRegistrationNumber;
  final String? councilBoardName;
  final String? totalExperience;
  final String? previousWorkplace;
  final String? dutyType;
  final String? preferredWorkingArea;
  final String verificationStatus;
  final String? adminRemarks;
  final bool isActive;
  final bool isAvailable;
  final bool isStandby;
  final bool isBlocked;
  final String? blockedReason;
  final String? blockedTillDate;
  final String rating;
  final int totalRatings;
  final int totalJobsCompleted;
  final String? acceptanceRate;
  final bool agreementSigned;
  final String? agreementFile;
  final String? checklistFile;
  final int? interviewChecklistId;
  final String? agreementSignedAt;
  final String? agreementExpiresAt;
  final String? currentLatitude;
  final String? currentLongitude;
  final String? lastLocationUpdate;
  final String createdAt;
  final String updatedAt;
  final String? verifiedAt;
  final String verificationStatusLabel;
  final String providerServices;
  final String verificationStatusLabelText;
  final String? totalExperienceText;
  final String? dutyTypeText;
  final String? agreementSignedAtFormatted;
  final String? agreementExpiresAtFormatted;
  final List<ServiceCategory> services;
  final List<ProviderDocument> documents;
  final List<ProviderAddress> addresses;
  final List<ProviderSkill> skills;
  final List<ProviderBadge> badges;
  final bool isRegistrationFeePaid;
  final String registrationFee;
  final String? registrationFeePaidAt;
  final String? razorpayPaymentId;
  final String? referralCode;
  final int? referredById;
  final String? referralRewardAmount;
  final int isReferralRewardPaid;

  ServiceProviderProfile({
    required this.id,
    required this.userId,
    this.cityAdminId,
    required this.fullName,
    this.about,
    this.highestQualification,
    this.professionalRegistrationNumber,
    this.councilBoardName,
    this.totalExperience,
    this.previousWorkplace,
    this.dutyType,
    this.preferredWorkingArea,
    required this.verificationStatus,
    this.adminRemarks,
    required this.isActive,
    required this.isAvailable,
    this.isStandby = false,
    required this.isBlocked,
    this.blockedReason,
    this.blockedTillDate,
    required this.rating,
    required this.totalRatings,
    required this.totalJobsCompleted,
    this.acceptanceRate,
    required this.agreementSigned,
    this.agreementFile,
    this.checklistFile,
    this.interviewChecklistId,
    this.agreementSignedAt,
    this.agreementExpiresAt,
    this.currentLatitude,
    this.currentLongitude,
    this.lastLocationUpdate,
    required this.createdAt,
    required this.updatedAt,
    this.verifiedAt,
    required this.verificationStatusLabel,
    required this.providerServices,
    required this.verificationStatusLabelText,
    this.totalExperienceText,
    this.dutyTypeText,
    this.agreementSignedAtFormatted,
    this.agreementExpiresAtFormatted,
    required this.services,
    required this.documents,
    required this.addresses,
    required this.skills,
    required this.badges,
    required this.isRegistrationFeePaid,
    required this.registrationFee,
    this.registrationFeePaidAt,
    this.razorpayPaymentId,
    this.referralCode,
    this.referredById,
    this.referralRewardAmount,
    required this.isReferralRewardPaid,
  });

  factory ServiceProviderProfile.fromJson(Map<String, dynamic> json) {
    try {
      return ServiceProviderProfile(
        id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
        userId: int.tryParse(json['user_id']?.toString() ?? '') ?? 0,
        cityAdminId: int.tryParse(json['city_admin_id']?.toString() ?? ''),
        fullName: json['full_name'] ?? '',
        about: json['about'],
        highestQualification: json['highest_qualification'],
        professionalRegistrationNumber: json['professional_registration_number'],
        councilBoardName: json['council_board_name'],
        totalExperience: json['total_experience'],
        previousWorkplace: json['previous_workplace'],
        dutyType: json['duty_type'],
        preferredWorkingArea: json['preferred_working_area'],
        verificationStatus: json['verification_status'] ?? 'pending',
        adminRemarks: json['admin_remarks'],
        isActive: json['is_active']?.toString() == '1' || json['is_active'] == true || json['is_active'] == 1,
        isAvailable: json['is_available']?.toString() == '1' || json['is_available'] == true || json['is_available'] == 1,
        isStandby: json['is_standby']?.toString() == '1' || json['is_standby'] == true || json['is_standby'] == 1,
        isBlocked: json['is_blocked']?.toString() == '1' || json['is_blocked'] == true || json['is_blocked'] == 1,
        blockedReason: json['blocked_reason'],
        blockedTillDate: json['blocked_till_date'],
        rating: json['rating']?.toString() ?? '0.00',
        totalRatings: int.tryParse(json['total_ratings']?.toString() ?? '') ?? 0,
        totalJobsCompleted: int.tryParse(json['total_jobs_completed']?.toString() ?? '') ?? 0,
        acceptanceRate: json['acceptance_rate']?.toString(),
        agreementSigned: json['agreement_signed']?.toString() == '1' ||
            json['agreement_signed'] == true ||
            json['agreement_signed'] == 1,
        agreementFile: json['agreement_file'],
        checklistFile: json['checklist_file'],
        interviewChecklistId: int.tryParse(json['interview_checklist_id']?.toString() ?? ''),
        agreementSignedAt: json['agreement_signed_at'],
        agreementExpiresAt: json['agreement_expires_at'],
        currentLatitude: json['current_latitude'],
        currentLongitude: json['current_longitude'],
        lastLocationUpdate: json['last_location_update'],
        createdAt: json['created_at'] ?? '',
        updatedAt: json['updated_at'] ?? '',
        verifiedAt: json['verified_at'],
        verificationStatusLabel: json['verification_status_label'] ?? '',
        providerServices: json['provider_services'] ?? '',
        verificationStatusLabelText: json['verification_status_label_text'] ?? '',
        totalExperienceText: json['total_experience_text'],
        dutyTypeText: json['duty_type_text'],
        agreementSignedAtFormatted: json['agreement_signed_at_formatted'],
        agreementExpiresAtFormatted: json['agreement_expires_at_formatted'],
        services:
            (json['services'] as List<dynamic>?)
                ?.map((e) => ServiceCategory.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        documents:
            (json['service_provider_documents'] as List<dynamic>?)
                ?.map((e) => ProviderDocument.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        addresses:
            (json['service_provider_addresses'] as List<dynamic>?)
                ?.map((e) => ProviderAddress.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        skills:
            (json['service_provider_skills'] as List<dynamic>?)
                ?.map((e) => ProviderSkill.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        badges:
            (json['badges'] as List<dynamic>?)
                ?.map((e) => ProviderBadge.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        isRegistrationFeePaid: json['is_registration_fee_paid']?.toString() == '1' ||
            json['is_registration_fee_paid'] == true ||
            json['is_registration_fee_paid'] == 1,
        registrationFee: json['registration_fee']?.toString() ?? '0',
        registrationFeePaidAt: json['registration_fee_paid_at'],
        razorpayPaymentId: json['razorpay_payment_id'],
        referralCode: json['referral_code'],
        referredById: int.tryParse(json['referred_by_id']?.toString() ?? ''),
        referralRewardAmount: json['referral_reward_amount']?.toString(),
        isReferralRewardPaid: int.tryParse(json['is_referral_reward_paid']?.toString() ?? '') ?? 0,
      );
    } catch (e) {
      throw e.toString();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'city_admin_id': cityAdminId,
      'full_name': fullName,
      'about': about,
      'highest_qualification': highestQualification,
      'professional_registration_number': professionalRegistrationNumber,
      'council_board_name': councilBoardName,
      'total_experience': totalExperience,
      'previous_workplace': previousWorkplace,
      'duty_type': dutyType,
      'preferred_working_area': preferredWorkingArea,
      'verification_status': verificationStatus,
      'admin_remarks': adminRemarks,
      'is_active': isActive,
      'is_available': isAvailable,
      'is_standby': isStandby,
      'is_blocked': isBlocked,
      'blocked_reason': blockedReason,
      'blocked_till_date': blockedTillDate,
      'rating': rating,
      'total_ratings': totalRatings,
      'total_jobs_completed': totalJobsCompleted,
      'acceptance_rate': acceptanceRate,
      'agreement_signed': agreementSigned,
      'agreement_file': agreementFile,
      'checklist_file': checklistFile,
      'interview_checklist_id': interviewChecklistId,
      'agreement_signed_at': agreementSignedAt,
      'agreement_expires_at': agreementExpiresAt,
      'current_latitude': currentLatitude,
      'current_longitude': currentLongitude,
      'last_location_update': lastLocationUpdate,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'verified_at': verifiedAt,
      'verification_status_label': verificationStatusLabel,
      'provider_services': providerServices,
      'verification_status_label_text': verificationStatusLabelText,
      'total_experience_text': totalExperienceText,
      'duty_type_text': dutyTypeText,
      'agreement_signed_at_formatted': agreementSignedAtFormatted,
      'agreement_expires_at_formatted': agreementExpiresAtFormatted,
      'services': services.map((e) => e.toJson()).toList(),
      'service_provider_documents': documents.map((e) => e.toJson()).toList(),
      'service_provider_addresses': addresses.map((e) => e.toJson()).toList(),
      'service_provider_skills': skills.map((e) => e.toJson()).toList(),
      'badges': badges.map((e) => e.toJson()).toList(),
      'is_registration_fee_paid': isRegistrationFeePaid,
      'registration_fee': registrationFee,
      'registration_fee_paid_at': registrationFeePaidAt,
      'razorpay_payment_id': razorpayPaymentId,
      'referral_code': referralCode,
      'referred_by_id': referredById,
      'referral_reward_amount': referralRewardAmount,
      'is_referral_reward_paid': isReferralRewardPaid,
    };
  }

  // Utility getters
  // double get ratingValue => double.tryParse(rating) ?? 0.0;

  bool get isPending => verificationStatus.toLowerCase() == 'pending';

  bool get isApproved => verificationStatus.toLowerCase() == 'approved';

  bool get isRejected => verificationStatus.toLowerCase() == 'rejected';

  String? get primaryAddress => addresses.isNotEmpty ? addresses.first.fullAddress : null;

  List<String> get serviceNames => services.map((e) => e.categoryName).toList();
}

// ==================== SERVICE CATEGORY ====================
class ServiceCategory {
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
  final ServicePivot pivot;
  final ParentCategory? parentCategory;

  ServiceCategory({
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
    required this.pivot,
    this.parentCategory,
  });

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    return ServiceCategory(
      id: json['id'] ?? 0,
      // 'category_name' for category endpoints; 'name' for service endpoints
      categoryName: json['category_name'] ?? json['name'] ?? '',
      categorySlug: json['category_slug'] ?? json['slug'] ?? '',
      parentCategoryId: json['parent_category_id'] ?? json['service_category_id'],
      description: json['description'],
      iconUrl: json['icon_url'] ?? json['image'],
      iconImageUrl: json['icon_image_url'],
      isActive: json['is_active'] == true || json['is_active'] == 1,
      displayOrder: json['display_order'] ?? 0,
      fullCategoryName: json['full_category_name'] ?? json['name'] ?? '',
      pivot: ServicePivot.fromJson(json['pivot'] ?? {}),
      parentCategory: json['parent_category'] != null ? ParentCategory.fromJson(json['parent_category']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
      'pivot': pivot.toJson(),
      'parent_category': parentCategory?.toJson(),
    };
  }
}

class ServicePivot {
  final int serviceProviderId;
  final int serviceCategoryId;
  final bool isPrimary;

  ServicePivot({required this.serviceProviderId, required this.serviceCategoryId, required this.isPrimary});

  factory ServicePivot.fromJson(Map<String, dynamic> json) {
    return ServicePivot(
      serviceProviderId: json['service_provider_id'] ?? 0,
      // 'service_category_id' for category pivot; 'service_id' for service pivot
      serviceCategoryId: json['service_category_id'] ?? json['service_id'] ?? 0,
      isPrimary: json['is_primary'] == true || json['is_primary'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'service_provider_id': serviceProviderId,
      'service_category_id': serviceCategoryId,
      'is_primary': isPrimary,
    };
  }
}

class ParentCategory {
  final int id;
  final String categoryName;
  final String categorySlug;
  final int? parentCategoryId;
  final String? description;
  final String? iconUrl;
  final bool isActive;
  final int displayOrder;
  final String fullCategoryName;

  ParentCategory({
    required this.id,
    required this.categoryName,
    required this.categorySlug,
    this.parentCategoryId,
    this.description,
    this.iconUrl,
    required this.isActive,
    required this.displayOrder,
    required this.fullCategoryName,
  });

  factory ParentCategory.fromJson(Map<String, dynamic> json) {
    return ParentCategory(
      id: json['id'] ?? 0,
      categoryName: json['category_name'] ?? '',
      categorySlug: json['category_slug'] ?? '',
      parentCategoryId: json['parent_category_id'],
      description: json['description'],
      iconUrl: json['icon_url'],
      isActive: json['is_active'] == true || json['is_active'] == 1,
      displayOrder: json['display_order'] ?? 0,
      fullCategoryName: json['full_category_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_name': categoryName,
      'category_slug': categorySlug,
      'parent_category_id': parentCategoryId,
      'description': description,
      'icon_url': iconUrl,
      'is_active': isActive,
      'display_order': displayOrder,
      'full_category_name': fullCategoryName,
    };
  }
}

// ==================== PROVIDER DOCUMENT ====================
class ProviderDocument {
  final int id;
  final int serviceProviderId;
  final String documentType;
  final String? documentName;
  final String? documentNumber;
  final String filePath;
  final String? fileUrl;
  final String? issueDate;
  final String? expiryDate;
  final String? verificationStatus;
  final String? verificationStatusLabel;
  final String? issueDateText;
  final String? expiryDateText;
  final String createdAt;
  final String updatedAt;

  ProviderDocument({
    required this.id,
    required this.serviceProviderId,
    required this.documentType,
    this.documentName,
    this.documentNumber,
    required this.filePath,
    this.fileUrl,
    this.issueDate,
    this.expiryDate,
    this.verificationStatus,
    this.verificationStatusLabel,
    this.issueDateText,
    this.expiryDateText,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProviderDocument.fromJson(Map<String, dynamic> json) {
    return ProviderDocument(
      id: json['id'] ?? 0,
      serviceProviderId: json['service_provider_id'] ?? 0,
      documentType: json['document_type'] ?? '',
      documentName: json['document_name'],
      documentNumber: json['document_number'],
      filePath: json['document_path'] ?? json['file_path'] ?? '',
      fileUrl: json['document_path_url'] ?? json['file_url'],
      issueDate: json['issue_date'],
      expiryDate: json['expiry_date'],
      verificationStatus: json['verification_status'],
      verificationStatusLabel: json['verification_status_label'],
      issueDateText: json['issue_date_text'],
      expiryDateText: json['expiry_date_text'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service_provider_id': serviceProviderId,
      'document_type': documentType,
      'document_name': documentName,
      'document_number': documentNumber,
      'document_path': filePath,
      'document_path_url': fileUrl,
      'issue_date': issueDate,
      'expiry_date': expiryDate,
      'verification_status': verificationStatus,
      'verification_status_label': verificationStatusLabel,
      'issue_date_text': issueDateText,
      'expiry_date_text': expiryDateText,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

// ==================== PROVIDER ADDRESS ====================
class ProviderAddress {
  final int id;
  final int serviceProviderId;
  final int? cityAdminId;
  final String fullAddress;
  final String? area;
  final String? city;
  final String? state;
  final String? pinCode;
  final String? latitude;
  final String? longitude;
  final String createdAt;
  final String updatedAt;

  ProviderAddress({
    required this.id,
    required this.serviceProviderId,
    this.cityAdminId,
    required this.fullAddress,
    this.area,
    this.city,
    this.state,
    this.pinCode,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProviderAddress.fromJson(Map<String, dynamic> json) {
    return ProviderAddress(
      id: json['id'] ?? 0,
      serviceProviderId: json['service_provider_id'] ?? 0,
      cityAdminId: int.tryParse(json['city_admin_id']?.toString() ?? ''),
      fullAddress: json['full_address'] ?? '',
      area: json['area'],
      city: json['city'],
      state: json['state'],
      pinCode: json['pin_code'],
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service_provider_id': serviceProviderId,
      'city_admin_id': cityAdminId,
      'full_address': fullAddress,
      'area': area,
      'city': city,
      'state': state,
      'pin_code': pinCode,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  String get formattedAddress {
    final parts = <String>[];
    if (area?.isNotEmpty ?? false) parts.add(area!);
    if (city?.isNotEmpty ?? false) parts.add(city!);
    if (state?.isNotEmpty ?? false) parts.add(state!);
    if (pinCode?.isNotEmpty ?? false) parts.add(pinCode!);
    return parts.isEmpty ? fullAddress : parts.join(', ');
  }
}

// ==================== PROVIDER SKILL ====================
class ProviderSkill {
  final int id;
  final int serviceProviderId;
  final String skillName;
  final String createdAt;

  ProviderSkill({
    required this.id,
    required this.serviceProviderId,
    required this.skillName,
    required this.createdAt,
  });

  factory ProviderSkill.fromJson(Map<String, dynamic> json) {
    return ProviderSkill(
      id: json['id'] ?? 0,
      serviceProviderId: json['service_provider_id'] ?? 0,
      skillName: json['skill_name'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'service_provider_id': serviceProviderId, 'skill_name': skillName, 'created_at': createdAt};
  }
}

// ==================== PROVIDER BADGE ====================
class ProviderBadge {
  final int id;
  final String badgeName;
  final String? badgeDescription;
  final String? badgeIconUrl;
  final String criteriaType;
  final int criteriaValue;
  final bool isActive;
  final String createdAt;
  final String criteriaTypeText;
  final BadgePivot pivot;

  ProviderBadge({
    required this.id,
    required this.badgeName,
    this.badgeDescription,
    this.badgeIconUrl,
    required this.criteriaType,
    required this.criteriaValue,
    required this.isActive,
    required this.createdAt,
    required this.criteriaTypeText,
    required this.pivot,
  });

  factory ProviderBadge.fromJson(Map<String, dynamic> json) {
    return ProviderBadge(
      id: json['id'] ?? 0,
      badgeName: json['badge_name'] ?? '',
      badgeDescription: json['badge_description'],
      badgeIconUrl: json['badge_icon_url'],
      criteriaType: json['criteria_type'] ?? '',
      criteriaValue: json['criteria_value'] ?? 0,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      createdAt: json['created_at'] ?? '',
      criteriaTypeText: json['criteria_type_text'] ?? '',
      pivot: BadgePivot.fromJson(json['pivot'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'badge_name': badgeName,
      'badge_description': badgeDescription,
      'badge_icon_url': badgeIconUrl,
      'criteria_type': criteriaType,
      'criteria_value': criteriaValue,
      'is_active': isActive,
      'created_at': createdAt,
      'criteria_type_text': criteriaTypeText,
      'pivot': pivot.toJson(),
    };
  }
}

class BadgePivot {
  final int serviceProviderId;
  final int providerBadgeId;
  final String awardedAt;

  BadgePivot({required this.serviceProviderId, required this.providerBadgeId, required this.awardedAt});

  factory BadgePivot.fromJson(Map<String, dynamic> json) {
    return BadgePivot(
      serviceProviderId: json['service_provider_id'] ?? 0,
      providerBadgeId: json['provider_badge_id'] ?? 0,
      awardedAt: json['awarded_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'service_provider_id': serviceProviderId,
      'provider_badge_id': providerBadgeId,
      'awarded_at': awardedAt,
    };
  }
}
