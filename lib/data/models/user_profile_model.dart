import 'package:adhisaat_health_care/features/service_provider/provider_home/data/models/service_provider_models.dart';

import '../../features/auth/auth_wrapper/data/role_enums.dart';

class UserProfileModel {
  final int id;
  final String name;
  final String mobileNumber;
  final String? whatsappNumber;
  final String email;
  final String? emailVerifiedAt;
  final String userType;
  final bool isActive;
  final bool isVerified;
  final bool isBlocked;
  final String? gender;
  final String? dateOfBirth;
  final String? bloodGroup;
  final bool isDonor;
  final String? profileImage;
  final String? lastLoginAt;
  final String? aadharNo;
  final String? aadharFilePath;
  final String? panNumber;
  final String? panFilePath;
  final String? aadharVerified;
  final String? panVerified;
  final String? referralCode;
  final int? referredById;
  final String? source;
  final String? walletAmount;
  final String? bonusWalletAmount;
  final String? deletedAt;
  final String createdAt;
  final String updatedAt;
  final String? createdAtFormatted;
  final String primaryRole;
  final String? profileImageUrl;
  final String? aadharFilePathUrl;
  final String? panFilePathUrl;
  final String? dateOfBirthText;
  final List<UserRoleModel> roles;
  final ServiceProviderProfile? serviceProviderProfile;
  final CustomerProfile? customerProfile;
  final UserRole userRole;

  final double totalWalletBalance;

  // Stats (optional — returned by some profile endpoints)
  final int? totalBookings;
  final int? completedBookings;
  final int? cancelledBookings;

  UserProfileModel({
    required this.id,
    required this.name,
    required this.mobileNumber,
    this.whatsappNumber,
    required this.email,
    this.emailVerifiedAt,
    required this.userType,
    required this.isActive,
    required this.isVerified,
    required this.isBlocked,
    this.gender,
    this.dateOfBirth,
    this.bloodGroup,
    required this.isDonor,
    this.profileImage,
    this.lastLoginAt,
    this.aadharNo,
    this.aadharFilePath,
    this.panNumber,
    this.panFilePath,
    this.aadharVerified,
    this.panVerified,
    this.referralCode,
    this.referredById,
    this.source,
    this.walletAmount,
    this.bonusWalletAmount,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
    this.createdAtFormatted,
    required this.primaryRole,
    this.profileImageUrl,
    this.aadharFilePathUrl,
    this.panFilePathUrl,
    this.dateOfBirthText,
    required this.roles,
    this.serviceProviderProfile,
    this.customerProfile,
    required this.userRole,
    this.totalWalletBalance = 0.0,
    this.totalBookings,
    this.completedBookings,
    this.cancelledBookings,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    try {
      return UserProfileModel(
        id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
        name: json['name'] ?? '',
        mobileNumber: json['mobile_number'] ?? '',
        whatsappNumber: json['whatsapp_number'],
        email: json['email'] ?? '',
        emailVerifiedAt: json['email_verified_at'],
        userType: json['user_type'] ?? '',
        isActive: json['is_active'] == true || json['is_active'] == 1,
        isVerified: json['is_verified'] == true || json['is_verified'] == 1,
        isBlocked: json['is_blocked'] == true || json['is_blocked'] == 1,
        gender: json['gender'],
        dateOfBirth: json['date_of_birth'],
        bloodGroup: json['blood_group'],
        isDonor: json['is_donor'] == true || json['is_donor'] == 1,
        profileImage: json['profile_image'] ?? json['profile_photo'],
        lastLoginAt: json['last_login_at'],
        aadharNo: json['aadhar_no'],
        aadharFilePath: json['aadhar_file_path'],
        panNumber: json['pan_number'],
        panFilePath: json['pan_file_path'],
        aadharVerified: json['aadhar_verified'],
        panVerified: json['pan_verified'],
        referralCode: json['referral_code']?.toString(),
        referredById: int.tryParse(json['referred_by_id']?.toString() ?? ''),
        source: json['source'],
        walletAmount: json['wallet_amount']?.toString(),
        bonusWalletAmount: json['bonus_wallet_amount']?.toString(),
        deletedAt: json['deleted_at'],
        createdAt: json['created_at'] ?? '',
        updatedAt: json['updated_at'] ?? '',
        createdAtFormatted: json['created_at_formatted'],
        primaryRole: json['primary_role'] ?? '',
        profileImageUrl: json['profile_image_url'] ?? json['profile_image'] ?? json['profile_photo'],
        aadharFilePathUrl: json['aadhar_file_path_url'],
        panFilePathUrl: json['pan_file_path_url'],
        dateOfBirthText: json['date_of_birth_text'],
        roles:
            (json['roles'] as List<dynamic>?)
                ?.map((e) => UserRoleModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        serviceProviderProfile: json['service_provider_profile'] != null
            ? ServiceProviderProfile.fromJson(json['service_provider_profile'])
            : null,
        customerProfile: json['customer_profile'] != null
            ? CustomerProfile.fromJson(json['customer_profile'])
            : null,
        // Derive role from the roles list, NOT user_type.
        // user_type is the "primary" server-side label and can be 'service_provider'
        // even when the user also holds the customer role. The roles array is the
        // authoritative source of every role the user actually has.
        userRole: ((json['roles'] as List<dynamic>?)
                    ?.any((r) => (r as Map<String, dynamic>)['name'] == 'service_provider') ??
                false)
            ? UserRole.provider
            : UserRole.patient,
        totalWalletBalance: (json['total_wallet_balance'] as num?)?.toDouble() ?? 0.0,
        totalBookings: int.tryParse(json['total_bookings']?.toString() ?? ''),
        completedBookings: int.tryParse(json['completed_bookings']?.toString() ?? ''),
        cancelledBookings: int.tryParse(json['cancelled_bookings']?.toString() ?? ''),
      );
    } catch (e) {
      throw e.toString();
    }
  }

  UserProfileModel copyWith({
    int? id,
    String? name,
    String? mobileNumber,
    String? whatsappNumber,
    String? email,
    String? emailVerifiedAt,
    String? userType,
    bool? isActive,
    bool? isVerified,
    bool? isBlocked,
    String? gender,
    String? dateOfBirth,
    String? bloodGroup,
    bool? isDonor,
    String? profileImage,
    String? lastLoginAt,
    String? aadharNo,
    String? aadharFilePath,
    String? panNumber,
    String? panFilePath,
    String? aadharVerified,
    String? panVerified,
    String? referralCode,
    int? referredById,
    String? source,
    String? walletAmount,
    String? bonusWalletAmount,
    String? deletedAt,
    String? createdAt,
    String? updatedAt,
    String? createdAtFormatted,
    String? primaryRole,
    String? profileImageUrl,
    String? aadharFilePathUrl,
    String? panFilePathUrl,
    String? dateOfBirthText,
    List<UserRoleModel>? roles,
    ServiceProviderProfile? serviceProviderProfile,
    CustomerProfile? customerProfile,
    UserRole? userRole,
    double? totalWalletBalance,
    int? totalBookings,
    int? completedBookings,
    int? cancelledBookings,
  }) {
    return UserProfileModel(
      // ...existing fields...
      id: id ?? this.id,
      name: name ?? this.name,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email ?? this.email,
      userType: userType ?? this.userType,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      isBlocked: isBlocked ?? this.isBlocked,
      isDonor: isDonor ?? this.isDonor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      primaryRole: primaryRole ?? this.primaryRole,
      roles: roles ?? this.roles,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      profileImage: profileImage ?? this.profileImage,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      aadharNo: aadharNo ?? this.aadharNo,
      aadharFilePath: aadharFilePath ?? this.aadharFilePath,
      panNumber: panNumber ?? this.panNumber,
      panFilePath: panFilePath ?? this.panFilePath,
      aadharVerified: aadharVerified ?? this.aadharVerified,
      panVerified: panVerified ?? this.panVerified,
      referralCode: referralCode ?? this.referralCode,
      referredById: referredById ?? this.referredById,
      source: source ?? this.source,
      walletAmount: walletAmount ?? this.walletAmount,
      bonusWalletAmount: bonusWalletAmount ?? this.bonusWalletAmount,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAtFormatted: createdAtFormatted ?? this.createdAtFormatted,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      aadharFilePathUrl: aadharFilePathUrl ?? this.aadharFilePathUrl,
      panFilePathUrl: panFilePathUrl ?? this.panFilePathUrl,
      dateOfBirthText: dateOfBirthText ?? this.dateOfBirthText,
      serviceProviderProfile: serviceProviderProfile ?? this.serviceProviderProfile,
      customerProfile: customerProfile ?? this.customerProfile,
      userRole: userRole ?? this.userRole,
      totalWalletBalance: totalWalletBalance ?? this.totalWalletBalance,
      totalBookings: totalBookings ?? this.totalBookings,
      completedBookings: completedBookings ?? this.completedBookings,
      cancelledBookings: cancelledBookings ?? this.cancelledBookings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile_number': mobileNumber,
      'whatsapp_number': whatsappNumber,
      'email': email,
      'email_verified_at': emailVerifiedAt,
      'user_type': userType,
      'is_active': isActive,
      'is_verified': isVerified,
      'is_blocked': isBlocked,
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'blood_group': bloodGroup,
      'is_donor': isDonor,
      'profile_image': profileImage,
      'last_login_at': lastLoginAt,
      'aadhar_no': aadharNo,
      'aadhar_file_path': aadharFilePath,
      'aadhar_verified': aadharVerified,
      'pan_number': panNumber,
      'pan_file_path': panFilePath,
      'pan_verified': panVerified,
      'referral_code': referralCode,
      'referred_by_id': referredById,
      'source': source,
      'wallet_amount': walletAmount,
      'bonus_wallet_amount': bonusWalletAmount,
      'deleted_at': deletedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'created_at_formatted': createdAtFormatted,
      'primary_role': primaryRole,
      'profile_image_url': profileImageUrl,
      'aadhar_file_path_url': aadharFilePathUrl,
      'pan_file_path_url': panFilePathUrl,
      'date_of_birth_text': dateOfBirthText,
      'roles': roles.map((e) => e.toJson()).toList(),
      'service_provider_profile': serviceProviderProfile?.toJson(),
      'customer_profile': customerProfile?.toJson(),
      'total_wallet_balance': totalWalletBalance,
      'total_bookings': totalBookings,
      'completed_bookings': completedBookings,
      'cancelled_bookings': cancelledBookings,
    };
  }

  // ── Convenience getters (mirrors the flat UserProfile API) ──────────────────

  /// Alias for [profileImageUrl].
  String? get profilePhoto => profileImageUrl;

  /// Role names as a flat list of strings (e.g. `['customer', 'service_provider']`).
  List<String> get roleNames => roles.map((r) => r.name).toList();

  /// True when the user's roles list contains 'service_provider'.
  bool get hasProviderRole => roleNames.contains('service_provider');

  /// True when the user's roles list contains 'customer'.
  bool get hasCustomerRole => roleNames.contains('customer');

  /// Default/first address from customer_profile.
  CustomerAddress? get _defaultAddress => customerProfile?.defaultAddress;

  String? get fullAddress => _defaultAddress?.fullAddress;

  String? get area => _defaultAddress?.area;

  String? get city => _defaultAddress?.city;

  // ignore: override_on_non_overriding_member
  String? get state => _defaultAddress?.state;

  String? get pinCode => _defaultAddress?.pinCode;

  String? get addressType => _defaultAddress?.addressType;

  String? get latitude => _defaultAddress?.latitude;

  String? get longitude => _defaultAddress?.longitude;

  /// Emergency contact flattened from customer_profile.
  String? get emergencyContactName => customerProfile?.emergencyContactName;

  String? get emergencyContactNumber => customerProfile?.emergencyContactNumber;

  /// Formatted address string (e.g. for display).
  String get formattedAddress {
    final addr = _defaultAddress;
    if (addr == null) return '—';
    return addr.formattedAddress;
  }

  /// Two-letter initials from [displayName].
  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
  }

  /// Display name for the user, falling back to customerProfile or 'User' if name is empty.
  String get displayName {
    if (name.trim().isNotEmpty) return name;
    if (customerProfile != null && customerProfile!.fullName != null && customerProfile!.fullName!.trim().isNotEmpty) {
      return customerProfile!.fullName!;
    }
    return 'User';
  }

  /// Capitalised gender string, e.g. "Male".
  String get displayGender {
    if (gender == null || gender!.isEmpty) return '—';
    return gender![0].toUpperCase() + gender!.substring(1);
  }
}

class CustomerProfile {
  int? id;
  int? userId;
  String? fullName;
  String? emergencyContactName;
  String? emergencyContactNumber;
  String? createdAt;
  String? updatedAt;
  String? appFeedback;
  List<CustomerAddress> customerAddress;

  CustomerProfile({
    this.id,
    this.userId,
    this.fullName,
    this.emergencyContactName,
    this.emergencyContactNumber,
    this.createdAt,
    this.updatedAt,
    this.appFeedback,
    this.customerAddress = const [],
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      id: int.tryParse(json['id']?.toString() ?? ''),
      userId: int.tryParse(json['user_id']?.toString() ?? ''),
      fullName: json['full_name'],
      emergencyContactName: json['emergency_contact_name'],
      emergencyContactNumber: json['emergency_contact_number'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      appFeedback: json['app_feedback'],
      customerAddress:
          (json['customer_address'] as List<dynamic>?)
              ?.map((e) => CustomerAddress.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Returns the default address, or the first address if none is marked default.
  CustomerAddress? get defaultAddress {
    if (customerAddress.isEmpty) return null;
    return customerAddress.firstWhere((a) => a.isDefault == true, orElse: () => customerAddress.first);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_number': emergencyContactNumber,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'app_feedback': appFeedback,
      'customer_address': customerAddress.map((e) => e.toJson()).toList(),
    };
  }
}

class CustomerAddress {
  final int? id;
  final int? customerProfileId;
  final String? addressType;
  final String? fullAddress;
  final String? area;
  final String? city;
  final String? state;
  final String? pinCode;
  final String? latitude;
  final String? longitude;
  final bool? isDefault;
  final String? deletedAt;
  final String? createdAt;
  final String? updatedAt;

  const CustomerAddress({
    this.id,
    this.customerProfileId,
    this.addressType,
    this.fullAddress,
    this.area,
    this.city,
    this.state,
    this.pinCode,
    this.latitude,
    this.longitude,
    this.isDefault,
    this.deletedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory CustomerAddress.fromJson(Map<String, dynamic> json) {
    return CustomerAddress(
      id: int.tryParse(json['id']?.toString() ?? ''),
      customerProfileId: int.tryParse(json['customer_profile_id']?.toString() ?? ''),
      addressType: json['address_type'] as String?,
      fullAddress: json['full_address'] as String?,
      area: json['area'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      pinCode: json['pin_code'] as String?,
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
      isDefault: json['is_default'] == true || json['is_default'] == 1,
      deletedAt: json['deleted_at'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_profile_id': customerProfileId,
      'address_type': addressType,
      'full_address': fullAddress,
      'area': area,
      'city': city,
      'state': state,
      'pin_code': pinCode,
      'latitude': latitude,
      'longitude': longitude,
      'is_default': isDefault,
      'deleted_at': deletedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  String get formattedAddress {
    final parts = [fullAddress, area, city, state, pinCode].where((e) => e != null && e.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.join(', ') : '—';
  }
}
