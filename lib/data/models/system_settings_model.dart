class SystemSettingsResponse {
  final bool status;
  final List<SystemSetting> data;
  final CompanyData? companyData;
  final String message;

  SystemSettingsResponse({required this.status, required this.data, required this.message, this.companyData});

  factory SystemSettingsResponse.fromJson(Map<String, dynamic> json) {
    final status = json['status'] ?? false;
    return SystemSettingsResponse(
      status: status,
      data: (json['data'] as List?)?.map((x) => SystemSetting.fromJson(x)).toList() ?? [],
      message: status ? json['message'] ?? '' : '',
      companyData: json['company_data'] != null ? CompanyData.fromJson(json['company_data']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'status': status, 'data': data.map((x) => x.toJson()).toList(), 'message': message, 'company_data': companyData?.toJson()};
  }
}

class CompanyData {
  final int id;
  final String companyName;
  final String? companyTagline;
  final String companyEmail;
  final String companyPhoneNumber;
  final String? companyAddress;
  final String? companyGst;
  final String? website;
  final String? companyLogo;
  final String? upiId;
  final String? favicon;
  final String? invoiceSignature;
  final String? mapUrl;
  final String? copyright;
  final String? footerText;
  final String? socialMediaLink;
  final String? googleTagManager;
  final String? googleAnalytics;
  final String? facebookPixel;
  final String? metaTitle;
  final String? metaKeys;
  final String? metaDescription;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double? walletAddMoneyBonusPercentage;
  final double? perBookingBonusAdjustmentPercentage;
  final double? customerReferralRewardAmount;
  final double? providerReferralRewardAmount;

  CompanyData({
    required this.id,
    required this.companyName,
    this.companyTagline,
    required this.companyEmail,
    required this.companyPhoneNumber,
    this.companyAddress,
    this.companyGst,
    this.website,
    this.companyLogo,
    this.upiId,
    this.favicon,
    this.invoiceSignature,
    this.mapUrl,
    this.copyright,
    this.footerText,
    this.socialMediaLink,
    this.googleTagManager,
    this.googleAnalytics,
    this.facebookPixel,
    this.metaTitle,
    this.metaKeys,
    this.metaDescription,
    this.createdAt,
    this.updatedAt,
    this.walletAddMoneyBonusPercentage,
    this.perBookingBonusAdjustmentPercentage,
    this.customerReferralRewardAmount,
    this.providerReferralRewardAmount,
  });

  factory CompanyData.fromJson(Map<String, dynamic> json) {
    return CompanyData(
      id: json['id'] ?? 0,
      companyName: json['company_name'] ?? '',
      companyTagline: json['company_tagline'],
      companyEmail: json['company_email'] ?? '',
      companyPhoneNumber: json['company_phone_number'] ?? '',
      companyAddress: json['company_address'],
      companyGst: json['company_gst'],
      website: json['website'],
      companyLogo: json['company_logo'],
      upiId: json['upi_id'],
      favicon: json['favicon'],
      invoiceSignature: json['invoice_signature'],
      mapUrl: json['map_url'],
      copyright: json['copy_right'],
      footerText: json['footer_text'],
      socialMediaLink: json['social_media_link'],
      googleTagManager: json['google_tag_manager'],
      googleAnalytics: json['google_analytics'],
      facebookPixel: json['facebook_pixel'],
      metaTitle: json['meta_title'],
      metaKeys: json['meta_keys'],
      metaDescription: json['meta_description'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      walletAddMoneyBonusPercentage:
          (json['wallet_add_money_bonus_percentage'] != null && double.tryParse(json['wallet_add_money_bonus_percentage'].toString()) != 0)
          ? double.tryParse(json['wallet_add_money_bonus_percentage'].toString())
          : null,
      perBookingBonusAdjustmentPercentage:
          (json['per_booking_bonus_adjustment_percentage'] != null &&
              double.tryParse(json['per_booking_bonus_adjustment_percentage'].toString()) != 0)
          ? double.tryParse(json['per_booking_bonus_adjustment_percentage'].toString())
          : null,
      customerReferralRewardAmount: (json['customer_referral_reward_amount'] != null)
          ? double.tryParse(json['customer_referral_reward_amount'].toString())
          : null,
      providerReferralRewardAmount: (json['provider_referral_reward_amount'] != null)
          ? double.tryParse(json['provider_referral_reward_amount'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_name': companyName,
      'company_tagline': companyTagline,
      'company_email': companyEmail,
      'company_phone_number': companyPhoneNumber,
      'company_address': companyAddress,
      'company_gst': companyGst,
      'website': website,
      'company_logo': companyLogo,
      'upi_id': upiId,
      'favicon': favicon,
      'invoice_signature': invoiceSignature,
      'map_url': mapUrl,
      'copy_right': copyright,
      'footer_text': footerText,
      'social_media_link': socialMediaLink,
      'google_tag_manager': googleTagManager,
      'google_analytics': googleAnalytics,
      'facebook_pixel': facebookPixel,
      'meta_title': metaTitle,
      'meta_keys': metaKeys,
      'meta_description': metaDescription,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'wallet_add_money_bonus_percentage': walletAddMoneyBonusPercentage,
      'per_booking_bonus_adjustment_percentage': perBookingBonusAdjustmentPercentage,
      'customer_referral_reward_amount': customerReferralRewardAmount,
      'provider_referral_reward_amount': providerReferralRewardAmount,
    };
  }
}

class SystemSetting {
  final int id;
  final String settingKey;
  final String settingValue;
  final String settingType;
  final String description;
  final bool isPublic;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SystemSetting({
    required this.id,
    required this.settingKey,
    required this.settingValue,
    required this.settingType,
    required this.description,
    required this.isPublic,
    this.createdAt,
    this.updatedAt,
  });

  factory SystemSetting.fromJson(Map<String, dynamic> json) {
    return SystemSetting(
      id: json['id'] ?? 0,
      settingKey: json['setting_key'] ?? '',
      settingValue: json['setting_value']?.toString() ?? '',
      settingType: json['setting_type'] ?? '',
      description: json['description'] ?? '',
      isPublic: (json['is_public'] is int) ? (json['is_public'] == 1) : (json['is_public'] ?? false),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'setting_key': settingKey,
      'setting_value': settingValue,
      'setting_type': settingType,
      'description': description,
      'is_public': isPublic,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
