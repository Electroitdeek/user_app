// ─────────────────────────────────────────────────
//  Nearby Provider Model – from findNearbyProviders API
// ─────────────────────────────────────────────────

class NearbyProviderModel {
  final int id;
  final int userId;
  final String fullName;
  final String? about;
  final String? highestQualification;
  final String? totalExperience;
  final String rating;
  final int totalRatings;
  final int totalJobsCompleted;
  final bool isAvailable;
  final bool isActive;
  final String verificationStatus;
  final DistanceInfo? distanceKm;
  final String? providerServices;
  final List<ProviderServiceCategory> services;
  final ProviderUser? user;

  NearbyProviderModel({
    required this.id,
    required this.userId,
    required this.fullName,
    this.about,
    this.highestQualification,
    this.totalExperience,
    required this.rating,
    required this.totalRatings,
    required this.totalJobsCompleted,
    required this.isAvailable,
    required this.isActive,
    required this.verificationStatus,
    this.distanceKm,
    this.providerServices,
    required this.services,
    this.user,
  });

  factory NearbyProviderModel.fromJson(Map<String, dynamic> json) {
    return NearbyProviderModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      fullName: json['full_name'] ?? '',
      about: json['about'],
      highestQualification: json['highest_qualification'],
      totalExperience: json['total_experience_text'] ?? json['total_experience'],
      rating: (json['rating'] ?? '0.0').toString(),
      totalRatings: json['total_ratings'] ?? 0,
      totalJobsCompleted: json['total_jobs_completed'] ?? 0,
      isAvailable: json['is_available'] == true,
      isActive: json['is_active'] == true,
      verificationStatus: json['verification_status'] ?? '',
      distanceKm: json['distance_km'] != null
          ? DistanceInfo.fromJson(json['distance_km'] as Map<String, dynamic>)
          : null,
      providerServices: json['provider_services'],
      services: (json['services'] as List<dynamic>? ?? [])
          .map((e) => ProviderServiceCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
      user: json['user'] != null ? ProviderUser.fromJson(json['user']) : null,
    );
  }

  // Helpers
  double get ratingDouble => double.tryParse(rating) ?? 0.0;
  String get initials {
    final nameToUse = user?.name ?? fullName;
    final parts = nameToUse.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return 'P';
  }

  String get experienceLabel => totalExperience ?? '';
  String get distanceLabel => distanceKm?.distanceText ?? '';
  String get durationLabel => distanceKm?.durationText ?? '';
}

class DistanceInfo {
  final double distanceKm;
  final int durationMinutes;
  final String distanceText;
  final String durationText;
  final String source;

  DistanceInfo({
    required this.distanceKm,
    required this.durationMinutes,
    required this.distanceText,
    required this.durationText,
    required this.source,
  });

  factory DistanceInfo.fromJson(Map<String, dynamic> json) {
    return DistanceInfo(
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      durationMinutes: json['duration_minutes'] ?? 0,
      distanceText: json['distance_text'] ?? '',
      durationText: json['duration_text'] ?? '',
      source: json['source'] ?? '',
    );
  }
}

class ProviderServiceCategory {
  final int id;
  final String categoryName;
  final String categorySlug;
  final String? description;
  final String fullCategoryName;

  ProviderServiceCategory({
    required this.id,
    required this.categoryName,
    required this.categorySlug,
    this.description,
    required this.fullCategoryName,
  });

  factory ProviderServiceCategory.fromJson(Map<String, dynamic> json) {
    return ProviderServiceCategory(
      id: json['id'] ?? 0,
      categoryName: json['category_name'] ?? '',
      categorySlug: json['category_slug'] ?? '',
      description: json['description'],
      fullCategoryName: json['full_category_name'] ?? json['category_name'] ?? '',
    );
  }
}

// ─── API response wrapper ────────────────────────
class NearbyProvidersResponse {
  final bool success;
  final List<NearbyProviderModel> providers;
  final int totalFound;
  final String searchRadiusKm;

  NearbyProvidersResponse({
    required this.success,
    required this.providers,
    required this.totalFound,
    required this.searchRadiusKm,
  });

  factory NearbyProvidersResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return NearbyProvidersResponse(
      success: json['success'] == true,
      providers: (data['providers'] as List<dynamic>? ?? [])
          .map((e) => NearbyProviderModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalFound: data['total_found'] ?? 0,
      searchRadiusKm: (data['search_radius_km'] ?? '10').toString(),
    );
  }
}

class ProviderUser {
  final int id;
  final String name;
  final String? mobileNumber;
  final String? email;
  final String? profileImage;
  final String? profileImageUrl;
  final String? primaryRole;

  ProviderUser({
    required this.id,
    required this.name,
    this.mobileNumber,
    this.email,
    this.profileImage,
    this.profileImageUrl,
    this.primaryRole,
  });

  factory ProviderUser.fromJson(Map<String, dynamic> json) {
    return ProviderUser(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      mobileNumber: json['mobile_number'],
      email: json['email'],
      profileImage: json['profile_image'],
      profileImageUrl: json['profile_image_url'],
      primaryRole: json['primary_role'],
    );
  }
}

