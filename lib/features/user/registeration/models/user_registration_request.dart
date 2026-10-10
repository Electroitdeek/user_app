import 'package:dio/dio.dart';

class UserRegistrationRequest {
  final int? userId;
  final String? name,
      mobileNumber,
      whatsapp,
      email,
      dob,
      gender,
      bloodGroup,
      aadharNo,
      panNo,
      lat,
      long,
      referralCode,
      referredBy;
  final String? emergencyName,
      emergencyNumber,
      addressType,
      address,
      area,
      city,
      state,
      pinCode;
  final String? termAndCondition;
  final String? profileImagePath;
  final String? password;

  UserRegistrationRequest({
    this.userId,
    this.name,
    this.mobileNumber,
    this.whatsapp,
    this.email,
    this.dob,
    this.gender,
    this.bloodGroup,
    this.emergencyName,
    this.emergencyNumber,
    this.addressType,
    this.address,
    this.area,
    this.city,
    this.state,
    this.pinCode,
    this.termAndCondition,
    this.aadharNo,
    this.panNo,
    this.lat,
    this.long,
    this.referralCode,
    this.referredBy,
    this.profileImagePath,
    this.password,
  });

  /// Same body the website sends to `POST /api/users/register`.
  Map<String, dynamic> toJson() {
    String? optional(String? value) {
      final trimmed = value?.trim() ?? '';
      return trimmed.isEmpty ? null : trimmed;
    }

    return {
      'name': optional(name) ?? '',
      'mobile': optional(mobileNumber) ?? '',
      if (optional(whatsapp) != null) 'whatsapp': optional(whatsapp),
      if (optional(email) != null) 'email': optional(email),
      'password': password ?? '',
      if (optional(gender) != null) 'gender': optional(gender),
      if (optional(dob) != null) 'dateOfBirth': optional(dob),
      if (optional(bloodGroup) != null) 'bloodGroup': optional(bloodGroup),
      'aadhaarNumber': optional(aadharNo) ?? '',
      if (optional(emergencyName) != null) 'emergencyContactName': optional(emergencyName),
      if (optional(emergencyNumber) != null) 'emergencyContactNumber': optional(emergencyNumber),
      'fullAddress': optional(address) ?? '',
      if (optional(area) != null) 'area': optional(area),
      'city': optional(city) ?? '',
      'state': optional(state) ?? '',
      'pincode': optional(pinCode) ?? '',
      'addressType': optional(addressType) ?? 'home',
      'latitude': double.tryParse(lat ?? '') ?? 0,
      'longitude': double.tryParse(long ?? '') ?? 0,
      'termsAccepted': true,
      'role': 'CUSTOMER',
    };
  }

  Future<FormData> toFormData() async {
    final map = toJson();
    // Remove the string path so it doesn't conflict with the file upload
    if (map.containsKey('profile_image')) {
      map.remove('profile_image');
    }
    final fd = FormData.fromMap(map);
    if (profileImagePath != null) {
      fd.files.add(MapEntry(
        'profile_image',
        await MultipartFile.fromFile(
          profileImagePath!,
          filename: profileImagePath!.split('/').last,
        ),
      ));
    }
    return fd;
  }
}
