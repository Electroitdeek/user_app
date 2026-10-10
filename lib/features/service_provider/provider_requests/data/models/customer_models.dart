class UserInfoModel {
  final int? id;
  final String name;
  final String? mobileNumber;
  final String? email;
  final String? gender;
  final String? dateOfBirth;
  final String? bloodGroup;
  final String? profileImageUrl;

  const UserInfoModel({
    this.id,
    required this.name,
    this.mobileNumber,
    this.email,
    this.gender,
    this.dateOfBirth,
    this.bloodGroup,
    this.profileImageUrl,
  });

  factory UserInfoModel.fromJson(Map<String, dynamic> json) => UserInfoModel(
        id: json['id'] as int?,
        name: json['name'] as String? ?? '',
        mobileNumber: json['mobile_number'] as String?,
        email: json['email'] as String?,
        gender: json['gender'] as String?,
        dateOfBirth: json['date_of_birth'] as String?,
        bloodGroup: json['blood_group'] as String?,
        profileImageUrl: json['profile_image_url'] as String?,
      );
}

class CustomerProfileModel {
  final int? id;
  final String fullName;
  final UserInfoModel? user;

  const CustomerProfileModel({
    this.id,
    required this.fullName,
    this.user,
  });

  factory CustomerProfileModel.fromJson(Map<String, dynamic> json) =>
      CustomerProfileModel(
        id: json['id'] as int?,
        fullName: json['full_name'] as String? ?? '',
        user: json['user'] != null
            ? UserInfoModel.fromJson(json['user'] as Map<String, dynamic>)
            : null,
      );
}

class FamilyMemberModel {
  final int? id;
  final int? customerProfileId;
  final String fullName;
  final String? relationship;
  final String? gender;
  final String? dateOfBirth;
  final String? bloodGroup;
  final String? mobileNumber;
  final String? createdAt;

  const FamilyMemberModel({
    this.id,
    this.customerProfileId,
    required this.fullName,
    this.relationship,
    this.gender,
    this.dateOfBirth,
    this.bloodGroup,
    this.mobileNumber,
    this.createdAt,
  });

  factory FamilyMemberModel.fromJson(Map<String, dynamic> json) =>
      FamilyMemberModel(
        id: json['id'] as int?,
        customerProfileId: json['customer_profile_id'] as int?,
        fullName: json['full_name'] as String? ?? '',
        relationship: json['relationship'] as String?,
        gender: json['gender'] as String?,
        dateOfBirth: json['date_of_birth'] as String?,
        bloodGroup: json['blood_group'] as String?,
        mobileNumber: json['mobile_number'] as String?,
        createdAt: json['created_at'] as String?,
      );
}

class CustomerAddressModel {
  final String fullAddress;
  final String? area;
  final String city;
  final String? state;
  final String? pinCode;
  final double? latitude;
  final double? longitude;

  const CustomerAddressModel({
    required this.fullAddress,
    this.area,
    required this.city,
    this.state,
    this.pinCode,
    this.latitude,
    this.longitude,
  });

  factory CustomerAddressModel.fromJson(Map<String, dynamic> json) =>
      CustomerAddressModel(
        fullAddress: json['full_address'] as String? ?? '',
        area: json['area'] as String?,
        city: json['city'] as String? ?? '',
        state: json['state'] as String?,
        pinCode: json['pin_code'] as String?,
        latitude: double.tryParse(json['latitude']?.toString() ?? ''),
        longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      );
}
